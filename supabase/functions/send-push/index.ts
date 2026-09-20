// send-push — APNs (iOS) + FCM v1 (Android) sender for Pick1 push.
//
// POST { key, args?, prefKey?, userIds?, freeOnly?, data? }  (localized)
// POST { title, body, prefKey?, userIds?, data? }            (literal)
// Per-device language from device_tokens.locale. Copy lives here so it's
// tunable without an app build. `freeOnly:true` targets non-entitled users.
//
// Delivery splits on device_tokens.platform: 'android' rows go out over the
// FCM v1 HTTP API (project pick1-7684d) with a service-account bearer token;
// everything else goes over APNs HTTP/2. Both share the same copy, A/B, dead-
// token pruning and push_log attribution.
//
// A/B: keys in AB_VARIANTS render one of N sibling copies chosen by a STABLE
// hash of user_id. Every keyed send is logged to push_log; and the chosen
// campaign(key)+variant are stamped into the push payload so the app can log
// the OPEN with attribution (notification_opened event).
//
// ---------------------------------------------------------------------------
// DELIVERY POLICY, added 2026-09-02. Read this before adding a key.
//
// Measured over the preceding 30 days: 93,099 pushes went to 1,687 people,
// 55 each, roughly two a day. 152 of those people had opened the app in that
// month. 91.3% of every push sent went to a phone that was already dormant.
// There was no cap, no activity filter and no quiet hours, and each settled
// pick fired its own notification, so a single user received 19 "you won" and
// 17 "you lost" a month about games they had never looked at.
//
// That does not build retention, it trains people to swipe the app's
// notifications away, and iOS demotes senders nobody engages with. Three
// gates now stand between a caller and a device, in this order:
//
//   1. TIER          what the notification is worth interrupting someone for.
//   2. ALLOWANCE     how dormant the device is, which caps how often it may
//                    be interrupted at all.
//   3. QUIET HOURS   whether it is a civil hour where that person lives. A
//                    push that fails this is PARKED, not dropped, because
//                    dropping it removes whole timezones from the product.
//
// `critical` skips 1 and 2 but not 3. Everything else earns its send.
// ---------------------------------------------------------------------------
import { createClient } from "npm:@supabase/supabase-js@2";

const TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "S33MH59G79";
const KEY_ID = Deno.env.get("APNS_KEY_ID");
const APNS_KEY_P8 = Deno.env.get("APNS_AUTH_KEY");
const BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "com.pick1.app";
const HOST_PROD = "https://api.push.apple.com";
const HOST_SANDBOX = "https://api.sandbox.push.apple.com";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ALT_KEY = Deno.env.get("PUSH_ALT_AUTH");
// Firebase service-account JSON (client_email, private_key, project_id …) for
// project pick1-7684d — set via `supabase secrets set FCM_SERVICE_ACCOUNT=…`.
const FCM_SA_RAW = Deno.env.get("FCM_SERVICE_ACCOUNT");

type Copy = { t: string; b: string };
type Locales = Record<string, Copy>;
// Copy. Deliberately short: iOS truncates a lock-screen title around 35
// characters and a body around 110, so anything past that is written for
// nobody. Every number below is computed from the graded record before the
// send, never asserted.
//
// THERE IS NO LOSING NOTIFICATION OF ANY KIND. That is a decision, not an
// oversight. The obligation Pick1 takes on is to PUBLISH its losses, and it
// does, in the app, on every settled pick, permanently. Pushing them is a
// different thing: nobody opens "yesterday was down 8%", and a notification
// is not where an audit trail belongs. So on a bad day the product says
// nothing at all, which is the only version of "stay positive" that does not
// require lying.
const LOC: Record<string, Locales> = {
  // Every dollar figure below is the SAME published record the app shows,
  // priced at a flat $100 a pick. The stake stays in the copy on purpose:
  // "+$2,891" with no basis is a returns claim that gets an app pulled, and
  // "+$2,891 on $100 a pick" is an arithmetic statement about a ledger
  // anyone can open and check.
  result_win: {
    en: { t: "🤑 +${won}, called it", b: "{team} {score}" },
    fr: { t: "🤑 +{won} $, dans le mille", b: "{team} {score}" },
    es: { t: "🤑 +${won}, lo clavaste", b: "{team} {score}" },
    de: { t: "🤑 +{won} $, genau so", b: "{team} {score}" },
    it: { t: "🤑 +{won} $, azzeccato", b: "{team} {score}" },
    pt: { t: "🤑 +${won}, em cheio", b: "{team} {score}" },
    ar: { t: "🤑 +{won}$، توقّع صحيح", b: "{team} {score}" },
  },
  // The one notification that carries a figure the reader can check against
  // their own money, because it IS their own: the stake they entered on this
  // pick and the price they entered with. Everything else in this file is
  // priced at a flat $100 so the number means the same thing to everyone;
  // here the whole point is that it does not. Sent only to someone who
  // tracked the pick before it settled, never to a favouriter, never on a
  // loss, and never without the stake in the body, which is what keeps it a
  // statement about their ledger rather than a claim about the product.
  result_win_stake: {
    en: { t: "🤑 You made +${won} on {team}", b: "Your ${stake} tracked came in. {score}" },
    fr: { t: "🤑 +{won} $ gagnés sur {team}", b: "Tes {stake} $ suivis sont passés. {score}" },
    es: { t: "🤑 Ganaste +${won} con {team}", b: "Tus ${stake} seguidos entraron. {score}" },
    de: { t: "🤑 +{won} $ mit {team}", b: "Deine {stake} $ sind aufgegangen. {score}" },
    it: { t: "🤑 +{won} $ con {team}", b: "I tuoi {stake} $ seguiti sono passati. {score}" },
    pt: { t: "🤑 Ganhaste +${won} com {team}", b: "Os teus ${stake} seguidos entraram. {score}" },
    ar: { t: "🤑 ربحت +{won}$ مع {team}", b: "{stake}$ التي تابعتها نجحت. {score}" },
  },
  // A game the user starred is kicking off. Every sport, one per game, and
  // the only notification in the set that arrives before anything happens,
  // which is the point: it is the one that gets the app opened while the
  // game is still worth watching. No figure, no claim, just the fixture.
  fav_start: {
    en: { t: "🏟️ {team} is starting", b: "Your game is underway. AI call: {pick}." },
    fr: { t: "🏟️ {team} commence", b: "Ton match démarre. Pronostic IA : {pick}." },
    es: { t: "🏟️ Empieza {team}", b: "Tu partido arranca. Pronóstico IA: {pick}." },
    de: { t: "🏟️ {team} beginnt", b: "Dein Spiel läuft. KI-Tipp: {pick}." },
    it: { t: "🏟️ {team} inizia", b: "La tua partita è iniziata. Pronostico IA: {pick}." },
    pt: { t: "🏟️ {team} vai começar", b: "O teu jogo arrancou. Palpite IA: {pick}." },
    ar: { t: "🏟️ {team} تبدأ الآن", b: "مباراتك انطلقت. توقّع الذكاء الاصطناعي: {pick}." },
  },
  // The day's #1 pick, to everyone. Two moments a broadcast is worth
  // making about a game most people have not starred: when it kicks off
  // (there is still a game to watch) and when it lands (the call they saw
  // this morning came in). A losing #1 sends nothing, same rule as above.
  top_start: {
    en: { t: "🔔 Today's #1 is starting", b: "{team}. AI call: {pick}, at {conf}%." },
    fr: { t: "🔔 Le n°1 du jour commence", b: "{team}. Pronostic IA : {pick}, à {conf}%." },
    es: { t: "🔔 Empieza el n.º1 de hoy", b: "{team}. Pronóstico IA: {pick}, al {conf}%." },
    de: { t: "🔔 Die Nr. 1 von heute beginnt", b: "{team}. KI-Tipp: {pick}, mit {conf}%." },
    it: { t: "🔔 Il n.1 di oggi inizia", b: "{team}. Pronostico IA: {pick}, al {conf}%." },
    pt: { t: "🔔 O n.º1 de hoje vai começar", b: "{team}. Palpite IA: {pick}, a {conf}%." },
    ar: { t: "🔔 رقم 1 اليوم يبدأ الآن", b: "{team}. توقّع الذكاء الاصطناعي: {pick}، بثقة {conf}٪." },
  },
  top_result: {
    en: { t: "🤑 Today's #1 came in: {pick}", b: "{team} {score}. +${won} on $100 tracked." },
    fr: { t: "🤑 Le n°1 du jour est passé : {pick}", b: "{team} {score}. +{won} $ sur 100 $ suivis." },
    es: { t: "🤑 El n.º1 de hoy entró: {pick}", b: "{team} {score}. +${won} sobre $100 seguidos." },
    de: { t: "🤑 Die Nr. 1 von heute ist aufgegangen: {pick}", b: "{team} {score}. +{won} $ auf 100 $ verfolgt." },
    it: { t: "🤑 Il n.1 di oggi è passato: {pick}", b: "{team} {score}. +{won} $ su 100 $ seguiti." },
    pt: { t: "🤑 O n.º1 de hoje entrou: {pick}", b: "{team} {score}. +${won} sobre $100 seguidos." },
    ar: { t: "🤑 رقم 1 اليوم نجح: {pick}", b: "{team} {score}. +{won}$ على 100$ متابَعة." },
  },
  // EVERY settled win, to everyone, as it settles (2026-09-20). The flat
  // $100 basis is what makes one figure comparable across readers; the
  // people who tracked this pick get their own number instead, and are
  // excluded from this send so nobody hears about the same game twice.
  //
  // The daily allowance is what makes "every win" safe: roughly 22 picks
  // land a day and a reader can take 5, so the pipeline sends them biggest
  // price first and the cap keeps the rest. Losses still send nothing.
  win_all: {
    en: { t: "🏆 {team} came in: +${payout}", b: "{score} · on $100 tracked. Called at {conf}%." },
    fr: { t: "🏆 {team} est passé : +{payout} $", b: "{score} · sur 100 $ suivis. Annoncé à {conf}%." },
    es: { t: "🏆 {team} entró: +${payout}", b: "{score} · sobre $100 seguidos. Anunciado al {conf}%." },
    de: { t: "🏆 {team} ist aufgegangen: +{payout} $", b: "{score} · auf 100 $ verfolgt. Mit {conf}% getippt." },
    it: { t: "🏆 {team} è passato: +{payout} $", b: "{score} · su 100 $ seguiti. Dato al {conf}%." },
    pt: { t: "🏆 {team} entrou: +${payout}", b: "{score} · sobre $100 seguidos. Indicado a {conf}%." },
    ar: { t: "🏆 {team} نجح: +{payout}$", b: "{score} · على 100$ متابَعة. بثقة {conf}٪." },
  },
  // The biggest price on the board, shortly before it starts. The only
  // forward-looking money line in the set, so it is the one that has to be
  // read hardest: it states what the market pays IF the call lands, on the
  // same $100 basis as everything else, and it never tells anyone to bet.
  // Pick1 takes no bets; the price belongs to a sportsbook, not to us.
  // Default sound on purpose: the cash register rings when money actually
  // lands, not when a game is about to start.
  value_soon: {
    en: { t: "💸 +${payout} on {team}", b: "Starts in {mins} min. Called at {conf}%, on $100 tracked." },
    fr: { t: "💸 +{payout} $ sur {team}", b: "Commence dans {mins} min. Annoncé à {conf}%, sur 100 $ suivis." },
    es: { t: "💸 +${payout} con {team}", b: "Empieza en {mins} min. Anunciado al {conf}%, sobre $100 seguidos." },
    de: { t: "💸 +{payout} $ mit {team}", b: "Beginnt in {mins} Min. Mit {conf}% getippt, auf 100 $ verfolgt." },
    it: { t: "💸 +{payout} $ su {team}", b: "Inizia tra {mins} min. Dato al {conf}%, su 100 $ seguiti." },
    pt: { t: "💸 +${payout} com {team}", b: "Começa em {mins} min. Indicado a {conf}%, sobre $100 seguidos." },
    ar: { t: "💸 +{payout}$ على {team}", b: "تبدأ خلال {mins} دقيقة. بثقة {conf}٪، على 100$ متابَعة." },
  },
  goal_fav: {
    en: { t: "⚡ {score}", b: "{team} scores in your game." },
    fr: { t: "⚡ {score}", b: "{team} marque dans ton match." },
    es: { t: "⚡ {score}", b: "{team} marca en tu partido." },
    de: { t: "⚡ {score}", b: "{team} trifft in deinem Spiel." },
    it: { t: "⚡ {score}", b: "{team} segna nella tua partita." },
    pt: { t: "⚡ {score}", b: "{team} marca no teu jogo." },
    ar: { t: "⚡ {score}", b: "{team} يسجّل في مباراتك." },
  },
  pick_drop: {
    en: { t: "🎯 Today's #1: {team}", b: "Called at {conf}% · +${payout} on $100." },
    fr: { t: "🎯 Le n°1 du jour : {team}", b: "Annoncé à {conf}% · +{payout} $ sur 100 $." },
    es: { t: "🎯 El n.º1 de hoy: {team}", b: "Anunciado al {conf}% · +${payout} sobre $100." },
    de: { t: "🎯 Nr. 1 heute: {team}", b: "Mit {conf}% angesagt · +{payout} $ auf 100 $." },
    it: { t: "🎯 Il n.1 di oggi: {team}", b: "Dato al {conf}% · +{payout} $ su 100 $." },
    pt: { t: "🎯 O n.º1 de hoje: {team}", b: "Indicado a {conf}% · +${payout} sobre $100." },
    ar: { t: "🎯 رقم 1 اليوم: {team}", b: "بثقة {conf}٪ · +{payout}$ على 100$." },
  },
  // Only when the board really carries a pick paying +100% or better, which
  // measured out at about one day in three. Rare enough to be news.
  big_odds: {
    en: { t: "💸 Up to +${payout} today", b: "{team}, called at {conf}%. On $100." },
    fr: { t: "💸 Jusqu'à +{payout} $ aujourd'hui", b: "{team}, annoncé à {conf}%. Sur 100 $." },
    es: { t: "💸 Hasta +${payout} hoy", b: "{team}, anunciado al {conf}%. Sobre $100." },
    de: { t: "💸 Bis zu +{payout} $ heute", b: "{team}, mit {conf}% angesagt. Auf 100 $." },
    it: { t: "💸 Fino a +{payout} $ oggi", b: "{team}, dato al {conf}%. Su 100 $." },
    pt: { t: "💸 Até +${payout} hoje", b: "{team}, indicado a {conf}%. Sobre $100." },
    ar: { t: "💸 حتى +{payout}$ اليوم", b: "{team}، بثقة {conf}٪. على 100$." },
  },
  recap: {
    en: { t: "💰 +${net} yesterday", b: "{wins} of {games} landed. On $100 a pick." },
    fr: { t: "💰 +{net} $ hier", b: "{wins} matchs sur {games} passés. Sur 100 $ par pari." },
    es: { t: "💰 +${net} ayer", b: "{wins} de {games} entraron. Sobre $100 por pick." },
    de: { t: "💰 +{net} $ gestern", b: "{wins} von {games} aufgegangen. Auf 100 $ pro Tipp." },
    it: { t: "💰 +{net} $ ieri", b: "{wins} su {games} passati. Su 100 $ a pronostico." },
    pt: { t: "💰 +${net} ontem", b: "{wins} de {games} entraram. Sobre $100 por palpite." },
    ar: { t: "💰 +{net}$ أمس", b: "{wins} من {games} نجحت. على 100$ لكل توقّع." },
  },
  // Consecutive profitable days from the graded record. When the run breaks
  // the notification simply stops; the streak is never rounded up.
  hot_streak: {
    en: { t: "🔥 {days} winning days in a row", b: "+${net} yesterday on $100 a pick. {wins} of {games} landed." },
    fr: { t: "🔥 {days} jours gagnants d'affilée", b: "+{net} $ hier sur 100 $ par pari. {wins} sur {games} passés." },
    es: { t: "🔥 {days} días ganadores seguidos", b: "+${net} ayer sobre $100 por pick. {wins} de {games} entraron." },
    de: { t: "🔥 {days} Gewinntage in Folge", b: "+{net} $ gestern auf 100 $ pro Tipp. {wins} von {games}." },
    it: { t: "🔥 {days} giorni vincenti di fila", b: "+{net} $ ieri su 100 $ a pronostico. {wins} su {games}." },
    pt: { t: "🔥 {days} dias a ganhar seguidos", b: "+${net} ontem sobre $100 por palpite. {wins} de {games}." },
    ar: { t: "🔥 {days} أيام رابحة تواليًا", b: "+{net}$ أمس على 100$ لكل توقّع. {wins} من {games}." },
  },
  free_recap: {
    en: { t: "💰 You missed +${net} yesterday", b: "Members went {w}-{l} on $100 a pick." },
    fr: { t: "💰 Tu as raté +{net} $ hier", b: "Les membres : {w}-{l} sur 100 $ par pari." },
    es: { t: "💰 Te perdiste +${net} ayer", b: "Los miembros: {w}-{l} sobre $100 por pick." },
    de: { t: "💰 Du hast +{net} $ verpasst", b: "Mitglieder: {w}-{l} auf 100 $ pro Tipp." },
    it: { t: "💰 Ti sei perso +{net} $ ieri", b: "I membri: {w}-{l} su 100 $ a pronostico." },
    pt: { t: "💰 Perdeste +${net} ontem", b: "Membros: {w}-{l} sobre $100 por palpite." },
    ar: { t: "💰 فاتك +{net}$ أمس", b: "الأعضاء: {w}-{l} على 100$ لكل توقّع." },
  },
  free_recap_b: {
    en: { t: "📈 Members went {w}-{l} yesterday", b: "$100 a pick = +${net}." },
    fr: { t: "📈 Les membres : {w}-{l} hier", b: "100 $ par pari = +{net} $." },
    es: { t: "📈 Miembros: {w}-{l} ayer", b: "$100 por pick = +${net}." },
    de: { t: "📈 Mitglieder: {w}-{l} gestern", b: "100 $ pro Tipp = +{net} $." },
    it: { t: "📈 Membri: {w}-{l} ieri", b: "100 $ a pronostico = +{net} $." },
    pt: { t: "📈 Membros: {w}-{l} ontem", b: "$100 por palpite = +${net}." },
    ar: { t: "📈 الأعضاء: {w}-{l} أمس", b: "100$ لكل توقّع = +{net}$." },
  },
  // The down-day filler.
  //
  // `recap` is suppressed whenever the day finished net negative, which is
  // most of the time, and the product then said nothing at all on four days
  // in seven. This names ONE pick that actually won, with its own price and
  // stake basis, and makes no claim about the day it came from. That is the
  // whole line: a true statement about a single result, never a performance
  // figure dressed up as one.
  top_win: {
    en: { t: "🏆 {team} came in yesterday", b: "+${payout} on $100 tracked." },
    fr: { t: "🏆 {team} est passé hier", b: "+{payout} $ sur 100 $ suivis." },
    es: { t: "🏆 {team} entró ayer", b: "+${payout} sobre $100 seguidos." },
    de: { t: "🏆 {team} ist gestern aufgegangen", b: "+{payout} $ auf 100 $ verfolgt." },
    it: { t: "🏆 {team} è passato ieri", b: "+{payout} $ su 100 $ seguiti." },
    pt: { t: "🏆 {team} entrou ontem", b: "+${payout} sobre $100 seguidos." },
    ar: { t: "🏆 {team} نجح أمس", b: "+{payout}$ على 100$ متابَعة." },
  },
  // Weekly, free tier only. A week of the published record is a bigger,
  // harder number to shrug off than a single day, and it only goes out on a
  // week the record actually finished up.
  week_missed: {
    en: { t: "💵 You missed +${net} this week", b: "Members went {w}-{l} over 7 days, on $100 a pick." },
    fr: { t: "💵 Tu as raté +{net} $ cette semaine", b: "Les membres : {w}-{l} sur 7 jours, sur 100 $ par pari." },
    es: { t: "💵 Te perdiste +${net} esta semana", b: "Los miembros: {w}-{l} en 7 días, sobre $100 por pick." },
    de: { t: "💵 Diese Woche: +{net} $ verpasst", b: "Mitglieder: {w}-{l} in 7 Tagen, auf 100 $ pro Tipp." },
    it: { t: "💵 +{net} $ persi questa settimana", b: "I membri: {w}-{l} in 7 giorni, su 100 $ a pronostico." },
    pt: { t: "💵 Perdeste +${net} esta semana", b: "Membros: {w}-{l} em 7 dias, sobre $100 por palpite." },
    ar: { t: "💵 فاتك +{net}$ هذا الأسبوع", b: "الأعضاء: {w}-{l} في 7 أيام، على 100$ لكل توقّع." },
  },
};

const AB_VARIANTS: Record<string, string[]> = { free_recap: ["free_recap", "free_recap_b"] };
const LABELS = ["A", "B", "C", "D"];
function pickVariant(userId: string | null, base: string): { locKey: string; label: string | null } {
  const variants = AB_VARIANTS[base];
  if (!variants) return { locKey: base, label: null };
  let h = 2166136261;
  const s = userId || "anon";
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  const idx = h % variants.length;
  return { locKey: variants[idx], label: LABELS[idx] ?? String(idx) };
}

// -- Delivery policy --------------------------------------------------------

type Tier = "critical" | "personal" | "daily";

/// What each key is worth interrupting someone for.
///
///  critical  a state the user has money in and can act on: a failed card, a
///            trial about to convert. Never capped, never withheld from a
///            dormant device. Total volume is around 80 sends a month, so it
///            costs nothing and missing one costs a subscription.
///  personal  about something this person chose: a pick they tracked, a team
///            they favourited. Worth a slot even from a quiet week.
///  daily     the product's own drumbeat. Valuable, but only to someone still
///            opening the app, and only once a day.
const TIER: Record<string, Tier> = {
  payment_failed: "critical",
  trial_ending: "critical",
  trial_ending_cancelled: "critical",
  renewal_off_save: "critical",
  billing_retry: "critical",

  result_win: "personal",
  result_win_stake: "personal",
  goal_fav: "personal",
  fav_start: "personal",

  pick_drop: "daily",
  recap: "daily",
  hot_streak: "daily",
  big_odds: "daily",
  free_recap: "daily",
  free_recap_b: "daily",
  week_missed: "daily",
  top_win: "daily",
  day1_return: "daily",
  top_start: "daily",
  win_all: "daily",
  value_soon: "daily",
  top_result: "daily",
};
const tierOf = (key: string | undefined): Tier => (key && TIER[key]) || "daily";

/// How much attention a device has earned, from how recently it was opened.
///
/// Not a cliff. Someone who drifted off for three weeks is worth two
/// notifications that week, not seven and not zero: enough to come back for,
/// few enough that ignoring them is not a decision to mute the app. Past six
/// weeks of silence the honest read is that push is not the channel any more,
/// and the win-back emails take over.
function allowance(lastSeenAt: string | null): { perDay: number; perWeek: number } {
  if (!lastSeenAt) return { perDay: 0, perWeek: 0 };
  const days = (Date.now() - Date.parse(lastSeenAt)) / 86400e3;
  // BROADCAST stays at 3 a day. It went to 5 for a day on 2026-09-16 and came
  // back on the 17th, on the numbers: broadcast keys open at 0.8–1.5%, the
  // personal keys at 9–12%, and iOS demotes senders nobody opens. The cap was
  // never the binding constraint anyway (the measured fortnight ran ~2.2 a
  // day against a ceiling of 3, because SUPPLY runs out first), so the extra
  // two slots bought nothing today and loosened the guard-rail for whoever
  // adds a broadcast key tomorrow. The "five a day" Ethan asked for lives in
  // PERSONAL_BONUS_PER_DAY instead, where it is earned by following a game.
  //
  // The dormant tiers are deliberately untouched. 1,598 of 2,454 devices
  // have been dark for six weeks, and pushing them is precisely what got the
  // sender demoted before. Volume comes from the people who are still here,
  // never from waking the ones who left.
  //
  // Raised again to 5/day on 2026-09-17. Measured over the previous week an
  // active user actually received 1 to 2 a day, never more than 4, so the
  // 3/day ceiling was never what stood between the product and its users;
  // the ceiling still has to be above what the pipeline can now produce
  // (pick_drop, big_odds, recap or top_win, top_start, top_result,
  // week_missed on Mondays) or the later, better ones get parked.
  if (days <= 14) return { perDay: 5, perWeek: 25 };
  if (days <= 45) return { perDay: 1, perWeek: 2 };
  return { perDay: 0, perWeek: 0 };
}

/// Extra daily headroom for `personal` notifications, on top of `perDay`.
///
/// A goal in a match you starred is not the same interruption as the app's
/// own drumbeat: you asked for it, by name, for that game. Measured over the
/// fortnight the two personal keys had open rates of 9.1% (`result_win`) and
/// 12.5% (`goal_fav`) against 0.8–1.5% for every broadcast key, which is the
/// whole argument for spending the volume here rather than on more broadcast.
///
/// So a device that has favourited a busy night can take up to five
/// broadcast sends AND five personal ones. Someone who favourites nothing
/// still sees the old ceiling, which is the correct answer: notifications
/// should follow what a person actually chose to follow.
const PERSONAL_BONUS_PER_DAY = 5;

// Rough UTC offset per app language, the FALLBACK when a device has not
// told us where it is. Each language takes the offset of its dominant
// storefront. It only decides "night or not", and being an hour out never
// changes that answer.
//
// Being SEVEN hours out does. An English-language phone in Paris is read as
// New York, so everything fired between 02:00 and 14:00 UTC is parked and
// released at 14:20, and the owner reports that the app sends nothing. That
// was 82 of the 1,478 devices active in the last 45 days on 2026-09-20,
// including the founder's, which is how it was found.
//
// `device_tokens.utc_offset_minutes` overrides the guess whenever it is set.
// Nothing populates it from the app yet, so it stays null for most rows and
// the table below still decides; it can be set per device today and the app
// can start reporting the real zone in a later build.
const TZ_OFFSET: Record<string, number> = {
  en: -5, es: -6, fr: 1, pt: -3, de: 1, it: 1, ar: 1,
};
function offsetHours(t: any): number {
  const mins = t?.utc_offset_minutes;
  if (typeof mins === "number" && Number.isFinite(mins)) return mins / 60;
  const lang = (t?.locale || "en").slice(0, 2).toLowerCase();
  return TZ_OFFSET[lang] ?? 0;
}
// 08:00 to 23:00 local since 2026-09-20, widened from 09:00 to 21:00.
//
// The old window was set when the product only ever sent a morning pick and
// an evening recap. It now sends results as games settle, and sport happens
// at night: a game ending at 22:30 local was parked until 09:00 the next
// morning, so "you made $83" arrived eleven hours late, which is a different
// and much weaker message. Over the previous week 56% of Spanish-locale
// sends and 42% of English ones were parked.
//
// 23:00 is still civil for a sports app, and the daily allowance, not the
// window, is what protects people from volume.
const QUIET_START = 8;
const QUIET_END = 23;

function localHour(t: any, at: Date = new Date()): number {
  return ((at.getUTCHours() + offsetHours(t)) % 24 + 24) % 24;
}
const inSendWindow = (t: any, at: Date = new Date()) => {
  const h = localHour(t, at);
  return h >= QUIET_START && h < QUIET_END;
};

/// The next instant that is QUIET_START local time for this locale.
///
/// pick_drop leaves the pipeline at a fixed UTC hour, which is the middle of
/// the night on the US west coast. Before this, those users were simply being
/// woken up; the alternative of refusing to send would have removed them from
/// the product. Parking the send until morning is the only option that keeps
/// both the user and the notification.
function nextSendWindow(tok: any, from: Date = new Date()): Date {
  for (let h = 0; h <= 24; h++) {
    const at = new Date(from.getTime() + h * 3600e3);
    if (inSendWindow(tok, at)) return at;
  }
  return from;
}

/// Minimum spacing between two non-critical notifications to one person.
///
/// The daily allowance alone does not give this. pick_drop and big_odds both
/// fire from the same pipeline run, seconds apart; an allowance of two a day
/// would happily deliver both at once, which reads as a malfunction and
/// undoes the point of capping at all. Whichever loses the race is parked
/// four hours out instead of dropped, so the second thing still arrives, in
/// the afternoon, where it has the day to itself.
// Two hours since 2026-09-17: at four, only three sends fit between 09:00
// and 21:00 local, which silently capped the day at three whatever the
// allowance said.
const MIN_GAP_HOURS = 2;

/// The same rule for `personal` keys, in minutes rather than hours.
///
/// Four hours cannot coexist with five a day: the send window is 09:00–21:00
/// local, twelve hours, and five sends four hours apart need sixteen. More
/// importantly a four-hour gap is wrong for the thing itself — two goals in
/// a match you starred are twenty minutes apart, and parking the second one
/// until the evening delivers it after the final whistle, which is worse
/// than not sending it. Twenty minutes still collapses a flurry.
const PERSONAL_MIN_GAP_MIN = 20;

// Amounts are grouped in the reader's own language: "+$2,891" in English,
// "+2 891 $" in French. Raw "+$2891" reads like a serial number, which is
// the opposite of what a money notification is for.
const MONEY_ARGS = new Set(["net", "won", "payout", "stake"]);

function fill(tpl: string, args: Record<string, unknown>, lang = "en"): string {
  return tpl.replace(/\{(\w+)\}/g, (_, k) => {
    const v = args[k];
    if (v === undefined) return `{${k}}`;
    if (MONEY_ARGS.has(k) && typeof v === "number" && Number.isFinite(v)) {
      try { return v.toLocaleString(lang); } catch { return String(v); }
    }
    return String(v);
  });
}
function render(locKey: string, locale: string, args: Record<string, unknown>): Copy | null {
  const entry = LOC[locKey];
  if (!entry) return null;
  const lang = (locale || "en").slice(0, 2).toLowerCase();
  const copy = entry[lang] ?? entry.en;
  return { t: fill(copy.t, args, lang), b: fill(copy.b, args, lang) };
}

const TOKEN_COLS = "token, environment, prefs, locale, user_id, platform, last_seen_at, utc_offset_minutes";
const PAGE = 1000;

/// Read device_tokens in full.
///
/// PostgREST caps an unbounded select at 1000 rows and returns them without
/// complaint. device_tokens held 1794, so every broadcast this product ever
/// sent reached at most the first 1000 devices and silently skipped 44% of
/// the install base. Nothing surfaced it: the send reported success for
/// every token it was handed.
async function allDeviceTokens(
  supabase: any, userIds?: string[],
): Promise<{ rows: any[]; error: string | null }> {
  const out: any[] = [];
  for (let from = 0; ; from += PAGE) {
    let q = supabase.from("device_tokens").select(TOKEN_COLS).range(from, from + PAGE - 1);
    if (Array.isArray(userIds) && userIds.length) q = q.in("user_id", userIds);
    const { data, error } = await q;
    if (error) return { rows: out, error: error.message };
    out.push(...(data ?? []));
    if (!data || data.length < PAGE) break;
  }
  return { rows: out, error: null };
}

function pemToDer(pem: string): Uint8Array<ArrayBuffer> {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  // Backed by a plain ArrayBuffer so it satisfies BufferSource under the
  // stricter lib types Deno 2 ships with (ArrayBufferLike is rejected).
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function b64url(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
const b64urlStr = (s: string) => b64url(new TextEncoder().encode(s));

// ── APNs (iOS) ────────────────────────────────────────────────────────────
let cachedApns: { jwt: string; iat: number } | null = null;
async function apnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedApns && now - cachedApns.iat < 3000) return cachedApns.jwt;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(APNS_KEY_P8!),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  const head = b64urlStr(JSON.stringify({ alg: "ES256", kid: KEY_ID }));
  const payload = b64urlStr(JSON.stringify({ iss: TEAM_ID, iat: now }));
  const input = `${head}.${payload}`;
  const sig = new Uint8Array(
    await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input)),
  );
  const jwt = `${input}.${b64url(sig)}`;
  cachedApns = { jwt, iat: now };
  return jwt;
}

async function sendApns(host: string, token: string, jwt: string, payload: unknown) {
  const r = await fetch(`${host}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": BUNDLE_ID,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  return { ok: r.ok, status: r.status, body: r.ok ? "" : await r.text() };
}

// ── FCM v1 (Android) ────────────────────────────────────────────────────────
type FcmSA = { client_email: string; private_key: string; project_id: string; token_uri?: string };
let fcmSA: FcmSA | null = null;
function loadFcmSA(): FcmSA | null {
  if (fcmSA) return fcmSA;
  if (!FCM_SA_RAW) return null;
  try { fcmSA = JSON.parse(FCM_SA_RAW) as FcmSA; return fcmSA; } catch { return null; }
}

// OAuth2 access token for the FCM v1 scope, minted from the service account
// (RS256-signed JWT → googleapis token endpoint). Cached ~55 min.
let cachedFcm: { token: string; exp: number } | null = null;
async function fcmAccessToken(sa: FcmSA): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedFcm && cachedFcm.exp - now > 60) return cachedFcm.token;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const tokenUri = sa.token_uri || "https://oauth2.googleapis.com/token";
  const head = b64urlStr(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64urlStr(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  }));
  const input = `${head}.${claims}`;
  const sig = new Uint8Array(
    await crypto.subtle.sign({ name: "RSASSA-PKCS1-v1_5" }, key, new TextEncoder().encode(input)),
  );
  const assertion = `${input}.${b64url(sig)}`;
  const r = await fetch(tokenUri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${assertion}`,
  });
  const j = await r.json();
  if (!r.ok || !j.access_token) throw new Error(`fcm token ${r.status}: ${JSON.stringify(j).slice(0, 160)}`);
  cachedFcm = { token: j.access_token, exp: now + (j.expires_in ?? 3600) };
  return cachedFcm.token;
}

async function sendFcm(projectId: string, accessToken: string, token: string, msg: {
  title: string; body: string; sound: string; channel: string; data: Record<string, string>;
}) {
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: msg.title, body: msg.body },
        data: msg.data,
        android: {
          priority: "high",
          notification: { sound: msg.sound, channel_id: msg.channel, default_sound: msg.sound === "default" },
        },
      },
    }),
  });
  return { ok: r.ok, status: r.status, body: r.ok ? "" : await r.text() };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  const auth = req.headers.get("authorization");
  const okAuth = auth === `Bearer ${SERVICE_KEY}` || (!!ALT_KEY && auth === `Bearer ${ALT_KEY}`);
  if (!okAuth) return new Response("Unauthorized", { status: 401 });

  const apnsReady = !!APNS_KEY_P8 && !!KEY_ID;
  const sa = loadFcmSA();
  if (!apnsReady && !sa) {
    return Response.json({ skipped: "no transport configured (set APNS_AUTH_KEY+APNS_KEY_ID and/or FCM_SERVICE_ACCOUNT)" });
  }

  let key: string | undefined, title: string | undefined, body: string | undefined,
    prefKey: string | undefined, userIds: string[] | undefined,
    excludeUserIds: string[] | undefined, freeOnly: boolean | undefined,
    args: Record<string, unknown> | undefined, data: Record<string, unknown> | undefined,
    drain: boolean | undefined, dryRun: boolean | undefined, validate: boolean | undefined,
    ttlHours: number | undefined;
  try {
    ({ key, title, body, prefKey, userIds, excludeUserIds, freeOnly, args, data,
       drain, dryRun, validate, ttlHours } = await req.json());
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, SERVICE_KEY);

  // Opens are NOT reported here. This function only accepts the service key
  // (see the auth check above), so the app cannot call it, and handing the
  // app a service key to report analytics would be indefensible. Attribution
  // goes through the `mark_push_opened` RPC instead, which runs as the
  // caller's own session and reads auth.uid().

  // -- Transport ---------------------------------------------------------
  //
  // Shared by the live path and the drain, so a parked notification goes out
  // through exactly the same code as a fresh one.
  async function deliver(
    tokens: any[], k: string | undefined, tTitleLit: string | undefined,
    tBodyLit: string | undefined, a: Record<string, unknown>, d: Record<string, unknown>,
  ) {
    // Cha-ching on anything carrying a dollar figure. A distinct sound is
    // the whole point: it has to be recognisable from a pocket, before the
    // screen is even out. Both platforms now: APNs takes a file name, Android
    // takes a channel whose sound was fixed when the channel was created.
    const MONEY_KEYS = new Set(["result_win", "result_win_stake", "win_all", "recap", "hot_streak", "big_odds", "top_result",
                                "free_recap", "free_recap_b", "week_missed",
                                "top_win"]);
    const money = !!k && MONEY_KEYS.has(k);
    const sound = money ? "chaching.caf" : "default";
    // Android names a raw resource, not a file, and the sound is a property
    // of the CHANNEL rather than the message. A channel is immutable once
    // created, so the cha-ching needed its own; pick1_money ships in the app
    // and nothing points at it until a build carrying it is on phones.
    // Safe to switch on now: device_tokens holds zero android rows because
    // the app has never been published.
    const androidSound = money ? "chaching" : "default";
    const androidChannel = money ? "pick1_money" : "pick1_alerts";

    function resolve(t: any): { tTitle: string; tBody: string; label: string | null } {
      if (!k) return { tTitle: tTitleLit ?? "", tBody: tBodyLit ?? "", label: null };
      const v = pickVariant(t.user_id ?? null, k);
      const c = render(v.locKey, t.locale ?? "en", a);
      if (c) return { tTitle: c.t, tBody: c.b, label: v.label };
      return { tTitle: tTitleLit ?? k, tBody: tBodyLit ?? "", label: v.label };
    }

    const android = tokens.filter((t) => t.platform === "android");
    const apple = tokens.filter((t) => t.platform !== "android");

    let sent = 0, failed = 0;
    const dead: string[] = [];
    // Tokens whose stored `environment` was wrong, with the value that
    // actually worked. See the retry below.
    const envFix: { token: string; environment: string }[] = [];
    // Per-token outcome, written back so a device that fails every send is
    // distinguishable from one nobody targeted. Without this, a dead token
    // is invisible: push_log only records successes, so the row simply
    // stops appearing and looks exactly like a quiet week.
    const okTokens: string[] = [];
    const badTokens: string[] = [];
    let lastError = "";
    const logRows: any[] = [];
    const loggedUsers = new Set<string>();
    // Literal sends carry their campaign in `data` (lifecycle-push does
    // this). Logging them here, on successful delivery, is what makes
    // push_log a record of what reached a phone: until 2026-09-17 the
    // caller logged every ATTEMPT instead, so a user this function had
    // gated still acquired a row, and those rows then ate the allowance
    // that should have gone to the morning pick.
    const litKey = !k && typeof d.campaign === "string" && d.campaign ? d.campaign : null;
    const litVariant = litKey && typeof d.variant === "string" ? d.variant : null;
    function logIfKeyed(t: any, label: string | null) {
      const base = k ?? litKey;
      if (base && t.user_id && !loggedUsers.has(t.user_id)) {
        loggedUsers.add(t.user_id);
        logRows.push({ user_id: t.user_id, base_key: base, variant: label ?? litVariant, locale: t.locale ?? "en" });
      }
    }

    if (apnsReady && apple.length) {
      const jwt = await apnsJwt();
      for (const t of apple) {
        const { tTitle, tBody, label } = resolve(t);
        const stamp = k ? { campaign: k, ...(label ? { variant: label } : {}) } : {};
        const aps = { aps: { alert: { title: tTitle, body: tBody }, sound }, ...d, ...stamp };
        const host = t.environment === "sandbox" ? HOST_SANDBOX : HOST_PROD;
        let res = await sendApns(host, t.token, jwt, aps);

        // A token registered against Apple's OTHER environment answers
        // `BadEnvironmentKeyInToken`, and the old code counted that as a
        // plain failure: not delivered, not pruned, not retried, so the
        // device went dark forever while the send reported nothing wrong.
        // Found on 2026-09-20 on a phone running a build straight from
        // Xcode, whose row said `production` while the token was a sandbox
        // one. Retry on the other host, and write the answer back so it
        // costs one failed send in the device's life rather than every one.
        if (!res.ok && res.body.includes("BadEnvironmentKeyInToken")) {
          const other = host === HOST_PROD ? HOST_SANDBOX : HOST_PROD;
          const retry = await sendApns(other, t.token, jwt, aps);
          if (retry.ok) {
            envFix.push({ token: t.token, environment: other === HOST_SANDBOX ? "sandbox" : "production" });
            res = retry;
          }
        }

        if (res.ok) { sent++; okTokens.push(t.token); logIfKeyed(t, label); }
        else {
          failed++;
          lastError = `apns ${res.status}: ${res.body.slice(0, 200)}`;
          if (res.status === 410 || res.body.includes("BadDeviceToken") || res.body.includes("Unregistered")) dead.push(t.token);
          else { badTokens.push(t.token); console.error(lastError); }
        }
      }
    }

    if (sa && android.length) {
      try {
        const accessToken = await fcmAccessToken(sa);
        for (const t of android) {
          const { tTitle, tBody, label } = resolve(t);
          const stamp: Record<string, string> = {};
          for (const [kk, vv] of Object.entries(d)) stamp[kk] = String(vv);
          if (k) { stamp.campaign = k; if (label) stamp.variant = label; }
          const res = await sendFcm(sa.project_id, accessToken, t.token, {
            title: tTitle, body: tBody, sound: androidSound,
            channel: androidChannel, data: stamp,
          });
          if (res.ok) { sent++; okTokens.push(t.token); logIfKeyed(t, label); }
          else {
            failed++;
            lastError = `fcm ${res.status}: ${res.body.slice(0, 200)}`;
            if (res.status === 404 || res.body.includes("UNREGISTERED") || res.body.includes("registration-token-not-registered")) dead.push(t.token);
            else { badTokens.push(t.token); console.error(lastError); }
          }
        }
      } catch (e) {
        console.error(`fcm setup failed: ${String(e).slice(0, 200)}`);
        failed += android.length;
      }
    }

    if (dead.length) await supabase.from("device_tokens").delete().in("token", dead);
    for (const f of envFix) {
      await supabase.from("device_tokens")
        .update({ environment: f.environment }).eq("token", f.token);
    }
    if (envFix.length) console.log(`apns: corrected environment on ${envFix.length} token(s)`);
    if (okTokens.length || badTokens.length) {
      // Chunked: PostgREST puts the array in the request body here, but the
      // function is cheap and a broadcast can carry 1,400 tokens.
      for (let i = 0; i < Math.max(okTokens.length, badTokens.length); i += 500) {
        await supabase.rpc("record_push_result", {
          ok_tokens: okTokens.slice(i, i + 500),
          bad_tokens: badTokens.slice(i, i + 500),
          err: lastError,
        });
      }
    }
    if (logRows.length) { try { await supabase.from("push_log").insert(logRows); } catch (_e) { /* non-fatal */ } }
    return { sent, failed, pruned: dead.length };
  }

  /// Every device for a set of users, so the drain can reach them again.
  async function tokensFor(ids: string[]) {
    if (!ids.length) return [];
    const { rows } = await allDeviceTokens(supabase, ids);
    return rows;
  }

  // -- Drain: notifications parked for a civil hour ----------------------
  //
  // Called hourly by cron via push-drain. A queued row past its expiry is
  // dropped rather than delivered: a pick_drop that arrives after the games
  // have started is worse than no pick_drop.
  if (drain) {
    const nowIso = new Date().toISOString();
    const { data: due } = await supabase.from("push_queue")
      .select("*").is("sent_at", null).lte("send_after", nowIso).limit(500);
    let delivered = 0, expired = 0, groups = 0;
    const doneIds: string[] = [];
    const expiredIds: string[] = [];

    // One transport pass per (key, args) group rather than per row.
    const byShape = new Map<string, any[]>();
    for (const row of due ?? []) {
      if (row.expires_at <= nowIso) { expiredIds.push(row.id); expired++; continue; }
      const shape = `${row.base_key}|${JSON.stringify(row.args)}|${JSON.stringify(row.data)}`;
      const bucket = byShape.get(shape) ?? [];
      if (!byShape.has(shape)) byShape.set(shape, bucket);
      bucket.push(row);
    }
    for (const rows of byShape.values()) {
      groups++;
      const toks = await tokensFor(rows.map((r: any) => r.user_id));
      // Still respect the window: a row can come due while its owner has
      // drifted into another part of the day.
      const ok = toks.filter((t: any) => inSendWindow(t));
      if (!dryRun && ok.length) {
        const r = await deliver(ok, rows[0].base_key, undefined, undefined, rows[0].args ?? {}, rows[0].data ?? {});
        delivered += r.sent;
      }
      for (const row of rows) doneIds.push(row.id);
    }
    if (!dryRun) {
      if (doneIds.length) await supabase.from("push_queue").update({ sent_at: nowIso }).in("id", doneIds);
      if (expiredIds.length) await supabase.from("push_queue").delete().in("id", expiredIds);
    }
    return Response.json({ drained: doneIds.length, delivered, expired, groups, dryRun: !!dryRun });
  }

  // -- Health check ------------------------------------------------------
  //
  // `{"validate": true}` sends a BACKGROUND push (no alert, no sound, no
  // badge) to every live token and reports what Apple says about each one.
  // Nothing appears on anyone's phone. This exists because a token that
  // Apple rejects is otherwise invisible: push_log only records successes,
  // so a dead device is indistinguishable from a quiet week, and one stayed
  // dark for six days before anyone noticed (2026-09-20).
  //
  // Definitively dead tokens (410 / BadDeviceToken / Unregistered) are
  // pruned; everything else is recorded on the row and left alone.
  if (validate) {
    const { rows: all, error: vErr } = await allDeviceTokens(supabase, userIds);
    if (vErr) return Response.json({ error: vErr }, { status: 500 });
    const apple = all.filter((t: any) => t.platform !== "android");
    const byError: Record<string, number> = {};
    const deadV: string[] = [];
    const okV: string[] = [];
    let good = 0, bad = 0;
    if (apnsReady) {
      const jwt = await apnsJwt();
      for (const t of apple) {
        const host = t.environment === "sandbox" ? HOST_SANDBOX : HOST_PROD;
        const payload = { aps: { "content-available": 1 } };
        const r = await fetch(`${host}/3/device/${t.token}`, {
          method: "POST",
          headers: {
            authorization: `bearer ${jwt}`,
            "apns-topic": BUNDLE_ID,
            "apns-push-type": "background",
            "apns-priority": "5",
            "content-type": "application/json",
          },
          body: JSON.stringify(payload),
        });
        if (r.ok) { good++; okV.push(t.token); continue; }
        const txt = await r.text();
        bad++;
        const reason = (txt.match(/"reason"\s*:\s*"([^"]+)"/) || [, `HTTP ${r.status}`])[1];
        byError[reason] = (byError[reason] ?? 0) + 1;
        if (r.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered") deadV.push(t.token);
        else await supabase.rpc("record_push_result", { ok_tokens: [], bad_tokens: [t.token], err: reason });
      }
    }
    if (!dryRun) {
      if (deadV.length) await supabase.from("device_tokens").delete().in("token", deadV);
      for (let i = 0; i < okV.length; i += 500) {
        await supabase.rpc("record_push_result", { ok_tokens: okV.slice(i, i + 500), bad_tokens: [], err: "" });
      }
    }
    return Response.json({ validated: apple.length, ok: good, failed: bad, pruned: dryRun ? 0 : deadV.length, byError });
  }

  if (!key && (!title || !body)) return new Response("need key or title+body", { status: 400 });

  // -- Live send ---------------------------------------------------------

  const { rows, error } = await allDeviceTokens(supabase, userIds);
  if (error) return Response.json({ error }, { status: 500 });

  let tokens = rows;
  if (prefKey) tokens = tokens.filter((t: any) => t.prefs?.[prefKey] !== false);

  // A broadcast about one game must not reach someone who already got the
  // personal version of it. The pipeline sends the tracked-stake copy first
  // and hands those user ids back here.
  if (Array.isArray(excludeUserIds) && excludeUserIds.length) {
    const drop = new Set(excludeUserIds);
    tokens = tokens.filter((t: any) => !t.user_id || !drop.has(t.user_id));
  }

  if (freeOnly) {
    const nowIso = new Date().toISOString();
    const pro = new Set<string>();
    const { data: grants } = await supabase.from("pro_grants").select("user_id, expires_at");
    for (const g of grants ?? []) if (!g.expires_at || g.expires_at > nowIso) pro.add(g.user_id);
    const { data: subs } = await supabase.from("subscriptions").select("user_id, expires_date, revocation_date");
    for (const s of subs ?? []) {
      if (s.user_id && s.expires_date && s.expires_date > nowIso && !s.revocation_date) pro.add(s.user_id);
    }
    tokens = tokens.filter((t: any) => t.user_id && !pro.has(t.user_id));
  }
  if (!tokens.length) return Response.json({ sent: 0, reason: "no tokens" });

  const tier = tierOf(key);
  const skipped = { dormant: 0, capped: 0, queued: 0 };

  // Recent history for everyone in range, read once. `critical` never asks.
  // Broadcast and personal history are counted SEPARATELY, because they are
  // spent from separate budgets (see PERSONAL_BONUS_PER_DAY). Counting them
  // together would mean a busy night of starred games silently eats the
  // day's pick_drop, which is the opposite of the intent: following a game
  // should add notifications, never replace the ones everyone gets.
  type Hist = { day: number; week: number; last: string | null;
                dayP: number; lastP: string | null };
  const blank = (): Hist => ({ day: 0, week: 0, last: null, dayP: 0, lastP: null });
  const counts = new Map<string, Hist>();
  if (tier !== "critical") {
    const ids = [...new Set(tokens.map((t: any) => t.user_id).filter(Boolean))];
    const weekAgo = new Date(Date.now() - 7 * 86400e3).toISOString();
    const dayAgo = new Date(Date.now() - 86400e3).toISOString();
    for (let i = 0; i < ids.length; i += 500) {
      const hist: any[] = [];
      for (let from = 0; ; from += PAGE) {
        const { data: page } = await supabase.from("push_log")
          .select("user_id, sent_at, base_key").in("user_id", ids.slice(i, i + 500))
          .gte("sent_at", weekAgo).range(from, from + PAGE - 1);
        hist.push(...(page ?? []));
        if (!page || page.length < PAGE) break;
      }
      for (const h of hist) {
        const c = counts.get(h.user_id) ?? blank();
        const personal = tierOf(h.base_key) === "personal";
        if (personal) {
          if (h.sent_at >= dayAgo) c.dayP++;
          if (!c.lastP || h.sent_at > c.lastP) c.lastP = h.sent_at;
        } else {
          c.week++;
          if (h.sent_at >= dayAgo) c.day++;
          if (!c.last || h.sent_at > c.last) c.last = h.sent_at;
        }
        counts.set(h.user_id, c);
      }
    }
  }

  const now: any[] = [];
  const later: any[] = [];
  const nowTs = new Date();
  for (const t of tokens as any[]) {
    // The earliest instant this device may be interrupted. Starts at "now"
    // and is pushed out by whichever gate is furthest away.
    let earliest = nowTs;
    if (tier !== "critical") {
      const a = allowance(t.last_seen_at ?? null);
      if (a.perDay === 0) { skipped.dormant++; continue; }
      const c = counts.get(t.user_id) ?? blank();
      if (tier === "personal") {
        // Own budget, own spacing. A starred game is allowed to be noisy on
        // the night it is played and costs the drumbeat nothing.
        if (c.dayP >= PERSONAL_BONUS_PER_DAY) { skipped.capped++; continue; }
        if (c.lastP) {
          const gap = new Date(Date.parse(c.lastP) + PERSONAL_MIN_GAP_MIN * 60e3);
          if (gap > earliest) earliest = gap;
        }
      } else {
        if (c.day >= a.perDay || c.week >= a.perWeek) { skipped.capped++; continue; }
        if (c.last) {
          const gap = new Date(Date.parse(c.last) + MIN_GAP_HOURS * 3600e3);
          if (gap > earliest) earliest = gap;
        }
      }
    }
    if (earliest <= nowTs && inSendWindow(t)) now.push(t);
    else later.push({ ...t, _after: earliest });
  }

  // Park what would land at night, one row per person.
  if (later.length && key && !dryRun) {
    const ttl = (typeof ttlHours === "number" && ttlHours > 0) ? ttlHours : 12;
    const seen = new Set<string>();
    const queueRows: any[] = [];
    for (const t of later) {
      if (!t.user_id || seen.has(t.user_id)) continue;
      seen.add(t.user_id);
      queueRows.push({
        user_id: t.user_id, base_key: key, args: args ?? {}, pref_key: prefKey ?? null,
        free_only: !!freeOnly, data: data ?? {},
        send_after: nextSendWindow(t, t._after ?? new Date()).toISOString(),
        expires_at: new Date(Date.now() + ttl * 3600e3).toISOString(),
      });
    }
    // The unique index that keeps one pending copy per person is PARTIAL
    // (where sent_at is null), and ON CONFLICT cannot target a partial index
    // through PostgREST. So the duplicate check is done here instead: read
    // what is already pending for this key and insert only the rest.
    if (queueRows.length) {
      const { data: pending } = await supabase.from("push_queue")
        .select("user_id").eq("base_key", key).is("sent_at", null)
        .in("user_id", queueRows.map((r) => r.user_id));
      const already = new Set((pending ?? []).map((r: any) => r.user_id));
      const fresh = queueRows.filter((r) => !already.has(r.user_id));
      if (fresh.length) {
        const { error: qe } = await supabase.from("push_queue").insert(fresh);
        if (qe) console.error(`push_queue insert: ${qe.message}`);
        else skipped.queued = fresh.length;
      }
    }
  } else if (later.length) {
    skipped.queued = later.length;
  }

  if (dryRun) {
    return Response.json({
      dryRun: true, key, tier, candidates: tokens.length,
      wouldSend: now.length, ...skipped,
    });
  }

  if (!now.length) return Response.json({ sent: 0, tier, ...skipped, reason: "all gated" });

  const r = await deliver(now, key, title, body, args ?? {}, data ?? {});
  return Response.json({ ...r, tier, candidates: tokens.length, ...skipped });
});
