// lifecycle-push — retention + recovery messaging for Pick1.
//
// Runs hourly from pg_cron. Resolves five time-sensitive segments and delivers
// each over push via `send-push` in literal mode, stamping campaign/variant into
// the payload so the app's notification_opened event keeps full attribution
// (Analytics.swift reads userInfo["campaign"] / ["variant"]).
//
//   day1_return              installed ~1 day ago, never came back, still free
//   trial_ending             trial ends in ~1 day, auto-renew ON  (will be charged)
//   trial_ending_cancelled   trial ends in ~1 day, auto-renew OFF (already opted out)
//   payment_failed           card declined — in grace period or billing retry
//   renewal_off_save         paying subscriber turned auto-renew off, expires soon
//
// EMAIL FALLBACK. Roughly 30% of the two recovery segments have no device token
// and are unreachable by push — a third of the highest-value audience there is.
// Those users get a branded transactional email via Resend instead, localised
// from their App Store storefront (device locale is unavailable precisely
// because they have no device row). Email is used ONLY for the two billing
// segments: those are genuine transactional notices about an account the user
// pays for. day1_return is marketing and is deliberately push-only — sending it
// by email would need consent and an unsubscribe path via email_preferences.
//
// Why these moments. Day 1 retention is 20.67% against a Sports-app peer median
// of 26.04%. 484 of 551 weekly subscriptions died at exactly 3.0 days — at the
// trial wall, never reaching a first payment. And 102 of 573 subscriptions
// (17.6%) died on a failed charge rather than a decision, which is money that
// was already won and then dropped. All are cheaper to fix than to re-buy.
//
// De-dupe. Push uses push_log (user_id, base_key); email uses the email_log
// (user_id, email_type, dedupe_key) unique constraint claimed before send, the
// same exactly-once pattern as send-welcome-email. The email dedupe_key is
// `<original_transaction_id>:<expires_date>`, so a user gets at most one notice
// per subscription period — a repeat failure next period is a new, real event.
//
// COPY RULE: no performance or returns claims. Recent picks run ~50% (34W-33L
// over the last 7 days), and Pick1's Meta-ads position depends on not reading
// as a sportsbook. Copy references access and billing state only — never
// win rates, profit, or implied outcomes.
//
// POST body (all optional):
//   { dryRun: true }                → resolve + preview everything, send nothing
//   { only: ["payment_failed"] }    → run just these segments
//   { skip: ["trial_ending"] }      → run everything except these
//   { ignoreQuietHours: true }      → bypass the local-time gate (testing)
import { createClient } from "npm:@supabase/supabase-js@2";

// AUTH: deployed with verify_jwt=true, so Supabase's gateway rejects anything
// without a valid project JWT before this code runs. That gateway IS the auth
// boundary — the same posture as the sibling cron functions in this project
// (send-welcome-email / send-daily-pick / send-weekly-newsletter), all of
// which pg_cron calls with the anon key.
//
// Why not a shared secret: edge-function secrets can't be set through the
// Supabase MCP, so the scheduler has no way to learn one. The exposure is
// acceptable here because both the copy and the recipient list are computed
// server-side — a caller controls neither — and de-dupe means no user can be
// messaged twice however often this is invoked.
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
// Shared with send-welcome-email and the apple-notifications founder alerts.
// While unset, every email path here reports `skipped` and sends nothing.
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const EMAIL_FROM = Deno.env.get("EMAIL_FROM") ?? "Pick1 <hello@pick1.live>";
// Deep link straight into the user's Apple subscription management screen —
// the only place a payment method or auto-renew setting can actually be changed.
const APPLE_SUBS_URL = "https://apps.apple.com/account/subscriptions";

type Copy = { t: string; b: string };
type Locales = Record<string, Copy>;

const LOC: Record<string, Locales> = {
  // ── Day 1: you installed, you never came back ──────────────────────────
  day1_return: {
    en: { t: "You left a pick on the table 🎯", b: "Your free pick of the day is waiting. Takes 10 seconds →" },
    fr: { t: "Tu as laissé un pari de côté 🎯", b: "Ton pari gratuit du jour t'attend. 10 secondes →" },
    es: { t: "Dejaste un pick sin ver 🎯", b: "Tu pick gratis del día te espera. 10 segundos →" },
    de: { t: "Da wartet noch ein Tipp 🎯", b: "Dein kostenloser Tipp des Tages wartet. 10 Sekunden →" },
    it: { t: "Hai lasciato un pronostico lì 🎯", b: "Il tuo pronostico gratuito del giorno ti aspetta. 10 secondi →" },
    pt: { t: "Deixaste um palpite por ver 🎯", b: "O teu palpite grátis do dia está à espera. 10 segundos →" },
    ar: { t: "تركت توقّعاً بانتظارك 🎯", b: "توقّعك المجاني لليوم في انتظارك. 10 ثوانٍ ←" },
  },
  // A/B arm B — model/authority framing rather than loss framing.
  day1_return_b: {
    en: { t: "🤖 Today's numbers are in", b: "The model's top free pick is ready. Tap to see it." },
    fr: { t: "🤖 Les chiffres du jour sont là", b: "Le meilleur pari gratuit du modèle est prêt. Touche pour voir." },
    es: { t: "🤖 Los números de hoy ya están", b: "El mejor pick gratis del modelo está listo. Toca para verlo." },
    de: { t: "🤖 Die Zahlen für heute sind da", b: "Der beste kostenlose Tipp des Modells ist bereit. Tippen zum Ansehen." },
    it: { t: "🤖 I numeri di oggi sono pronti", b: "Il miglior pronostico gratuito del modello è pronto. Tocca per vederlo." },
    pt: { t: "🤖 Os números de hoje chegaram", b: "O melhor palpite grátis do modelo está pronto. Toca para ver." },
    ar: { t: "🤖 أرقام اليوم جاهزة", b: "أفضل توقّع مجاني من النموذج جاهز. اضغط لرؤيته." },
  },
  // ── Trial ending, auto-renew ON ────────────────────────────────────────
  // Deliberately says nothing about billing or price. The goal is to get one
  // more session in before the decision point, not to prompt a cancel.
  trial_ending: {
    en: { t: "1 day left of unlimited picks", b: "After tomorrow you're back to 1 pick per sport. Use it while it's open →" },
    fr: { t: "Plus qu'un jour en illimité", b: "Demain tu repasses à 1 pari par sport. Profites-en →" },
    es: { t: "Queda 1 día de picks ilimitados", b: "Mañana vuelves a 1 pick por deporte. Aprovéchalo →" },
    de: { t: "Noch 1 Tag unbegrenzte Tipps", b: "Ab morgen wieder 1 Tipp pro Sportart. Nutze ihn →" },
    it: { t: "Resta 1 giorno di pronostici illimitati", b: "Da domani torni a 1 pronostico per sport. Approfittane →" },
    pt: { t: "Falta 1 dia de palpites ilimitados", b: "Amanhã voltas a 1 palpite por desporto. Aproveita →" },
    ar: { t: "يوم واحد متبقٍ من التوقّعات غير المحدودة", b: "غداً تعود إلى توقّع واحد لكل رياضة. استفد الآن ←" },
  },
  // ── Trial ending, auto-renew already OFF ───────────────────────────────
  // These users have already opted out, so there is no conversion left to
  // lose — this is the one segment where a direct save message is pure upside.
  trial_ending_cancelled: {
    en: { t: "Your Pro access ends tomorrow", b: "Every pick, every sport — back to 1 a day after that. Keep it →" },
    fr: { t: "Ton accès Pro se termine demain", b: "Tous les paris, tous les sports — puis 1 par jour. Garde-le →" },
    es: { t: "Tu acceso Pro termina mañana", b: "Todos los picks, todos los deportes — luego 1 al día. Consérvalo →" },
    de: { t: "Dein Pro-Zugang endet morgen", b: "Alle Tipps, alle Sportarten — danach 1 pro Tag. Behalte ihn →" },
    it: { t: "Il tuo accesso Pro finisce domani", b: "Tutti i pronostici, tutti gli sport — poi 1 al giorno. Mantienilo →" },
    pt: { t: "O teu acesso Pro acaba amanhã", b: "Todos os palpites, todos os desportos — depois 1 por dia. Mantém-no →" },
    ar: { t: "ينتهي وصولك إلى Pro غداً", b: "كل التوقّعات في كل الرياضات — ثم واحد يومياً. احتفظ به ←" },
  },
  // ── Card declined ──────────────────────────────────────────────────────
  // The other half of Billing Grace Period: Apple keeps retrying and the user
  // keeps access, but nobody tells them the card failed. Wording is true for
  // both in_grace_period (access continues) and in_billing_retry (it has
  // lapsed), so it never asserts an access state it can't guarantee.
  payment_failed: {
    en: { t: "⚠️ Your payment didn't go through", b: "Update your payment method to keep Pro →" },
    fr: { t: "⚠️ Ton paiement n'est pas passé", b: "Mets à jour ton moyen de paiement pour garder Pro →" },
    es: { t: "⚠️ Tu pago no se procesó", b: "Actualiza tu método de pago para mantener Pro →" },
    de: { t: "⚠️ Deine Zahlung ist fehlgeschlagen", b: "Aktualisiere deine Zahlungsmethode, um Pro zu behalten →" },
    it: { t: "⚠️ Il tuo pagamento non è andato a buon fine", b: "Aggiorna il metodo di pagamento per mantenere Pro →" },
    pt: { t: "⚠️ O teu pagamento não foi processado", b: "Atualiza o teu método de pagamento para manteres o Pro →" },
    ar: { t: "⚠️ لم تتم عملية الدفع", b: "حدّث طريقة الدفع للحفاظ على Pro ←" },
  },
  // ── Paying subscriber switched auto-renew off ──────────────────────────
  // Still entitled, still paying, already decided to leave. The warmest save
  // target there is, and until now nothing reached them before expiry.
  renewal_off_save: {
    en: { t: "Your Pro plan ends in a day", b: "Turn renewal back on to keep every pick, every sport →" },
    fr: { t: "Ton abonnement Pro se termine demain", b: "Réactive le renouvellement pour garder tous les paris →" },
    es: { t: "Tu plan Pro termina mañana", b: "Reactiva la renovación para mantener todos los picks →" },
    de: { t: "Dein Pro-Abo endet morgen", b: "Verlängerung wieder aktivieren, um alle Tipps zu behalten →" },
    it: { t: "Il tuo piano Pro finisce domani", b: "Riattiva il rinnovo per mantenere tutti i pronostici →" },
    pt: { t: "O teu plano Pro acaba amanhã", b: "Reativa a renovação para manteres todos os palpites →" },
    ar: { t: "تنتهي خطة Pro غداً", b: "أعد تفعيل التجديد للاحتفاظ بكل التوقّعات ←" },
  },
};

// ── Email copy (the two billing segments only) ─────────────────────────────
type EmailCopy = { subject: string; badge: string; h1: string; h2: string; p1: string; p2: string; cta: string; why: string };

const EMAIL_LOC: Record<string, Record<string, EmailCopy>> = {
  payment_failed: {
    en: { subject: "Your Pick1 payment didn't go through", badge: "BILLING &middot; ACTION NEEDED", h1: "YOUR PAYMENT", h2: "DIDN'T GO THROUGH.",
      p1: "Your card was declined, so your Pick1 Pro subscription couldn't renew.",
      p2: "Apple will keep retrying for a short while. Updating your payment method now is the quickest way to stop your access lapsing.",
      cta: "Update Payment Method", why: "You're receiving this because you have a Pick1 subscription." },
    fr: { subject: "Ton paiement Pick1 n'est pas passé", badge: "FACTURATION &middot; ACTION REQUISE", h1: "TON PAIEMENT", h2: "N'EST PAS PASS&Eacute;.",
      p1: "Ta carte a été refusée, ton abonnement Pick1 Pro n'a donc pas pu être renouvelé.",
      p2: "Apple va réessayer pendant quelque temps. Mettre à jour ton moyen de paiement maintenant est le plus rapide pour ne pas perdre ton accès.",
      cta: "Mettre à jour le paiement", why: "Tu reçois cet e-mail parce que tu as un abonnement Pick1." },
    es: { subject: "Tu pago de Pick1 no se procesó", badge: "FACTURACI&Oacute;N &middot; ACCI&Oacute;N NECESARIA", h1: "TU PAGO", h2: "NO SE PROCES&Oacute;.",
      p1: "Tu tarjeta fue rechazada, así que tu suscripción Pick1 Pro no pudo renovarse.",
      p2: "Apple seguirá intentándolo durante un tiempo. Actualizar tu método de pago ahora es lo más rápido para no perder tu acceso.",
      cta: "Actualizar método de pago", why: "Recibes este correo porque tienes una suscripción a Pick1." },
    pt: { subject: "O teu pagamento Pick1 não foi processado", badge: "FATURA&Ccedil;&Atilde;O &middot; A&Ccedil;&Atilde;O NECESS&Aacute;RIA", h1: "O TEU PAGAMENTO", h2: "N&Atilde;O FOI PROCESSADO.",
      p1: "O teu cartão foi recusado, por isso a tua subscrição Pick1 Pro não pôde ser renovada.",
      p2: "A Apple vai continuar a tentar durante algum tempo. Atualizar o teu método de pagamento agora é o mais rápido para não perderes o acesso.",
      cta: "Atualizar pagamento", why: "Recebes este e-mail porque tens uma subscrição Pick1." },
    de: { subject: "Deine Pick1-Zahlung ist fehlgeschlagen", badge: "ABRECHNUNG &middot; AKTION ERFORDERLICH", h1: "DEINE ZAHLUNG", h2: "IST FEHLGESCHLAGEN.",
      p1: "Deine Karte wurde abgelehnt, daher konnte dein Pick1-Pro-Abo nicht verlängert werden.",
      p2: "Apple versucht es noch eine Weile erneut. Deine Zahlungsmethode jetzt zu aktualisieren ist der schnellste Weg, deinen Zugang zu behalten.",
      cta: "Zahlungsmethode aktualisieren", why: "Du erhältst diese E-Mail, weil du ein Pick1-Abo hast." },
    it: { subject: "Il tuo pagamento Pick1 non è andato a buon fine", badge: "FATTURAZIONE &middot; AZIONE RICHIESTA", h1: "IL TUO PAGAMENTO", h2: "NON &Egrave; RIUSCITO.",
      p1: "La tua carta è stata rifiutata, quindi il tuo abbonamento Pick1 Pro non è stato rinnovato.",
      p2: "Apple continuerà a riprovare per un po'. Aggiornare il metodo di pagamento ora è il modo più rapido per non perdere l'accesso.",
      cta: "Aggiorna il pagamento", why: "Ricevi questa email perché hai un abbonamento Pick1." },
    ar: { subject: "لم تتم عملية الدفع في Pick1", badge: "الفوترة &middot; مطلوب إجراء", h1: "لم تتم", h2: "عملية الدفع.",
      p1: "تم رفض بطاقتك، لذلك تعذّر تجديد اشتراكك في Pick1 Pro.",
      p2: "ستواصل Apple المحاولة لفترة قصيرة. تحديث طريقة الدفع الآن هو أسرع وسيلة للحفاظ على وصولك.",
      cta: "تحديث طريقة الدفع", why: "تصلك هذه الرسالة لأن لديك اشتراكاً في Pick1." },
  },
  renewal_off_save: {
    en: { subject: "Your Pick1 Pro plan ends tomorrow", badge: "SUBSCRIPTION &middot; ENDING", h1: "YOUR PRO PLAN", h2: "ENDS TOMORROW.",
      p1: "Auto-renewal is switched off, so your Pick1 Pro access ends when the current period runs out.",
      p2: "After that you drop back to one free pick per sport per day. Turning renewal back on keeps every pick across every sport.",
      cta: "Turn Renewal Back On", why: "You're receiving this because you have a Pick1 subscription." },
    fr: { subject: "Ton abonnement Pick1 Pro se termine demain", badge: "ABONNEMENT &middot; FIN PROCHE", h1: "TON ABONNEMENT PRO", h2: "SE TERMINE DEMAIN.",
      p1: "Le renouvellement automatique est désactivé, ton accès Pick1 Pro se termine donc à la fin de la période en cours.",
      p2: "Ensuite tu repasses à un pari gratuit par sport et par jour. Réactiver le renouvellement te garde tous les paris, tous les sports.",
      cta: "Réactiver le renouvellement", why: "Tu reçois cet e-mail parce que tu as un abonnement Pick1." },
    es: { subject: "Tu plan Pick1 Pro termina mañana", badge: "SUSCRIPCI&Oacute;N &middot; FINALIZANDO", h1: "TU PLAN PRO", h2: "TERMINA MA&Ntilde;ANA.",
      p1: "La renovación automática está desactivada, así que tu acceso Pick1 Pro termina al acabar el periodo actual.",
      p2: "Después vuelves a un pick gratis por deporte al día. Reactivar la renovación mantiene todos los picks de todos los deportes.",
      cta: "Reactivar la renovación", why: "Recibes este correo porque tienes una suscripción a Pick1." },
    pt: { subject: "O teu plano Pick1 Pro acaba amanhã", badge: "SUBSCRI&Ccedil;&Atilde;O &middot; A TERMINAR", h1: "O TEU PLANO PRO", h2: "ACABA AMANH&Atilde;.",
      p1: "A renovação automática está desativada, por isso o teu acesso Pick1 Pro termina no fim do período atual.",
      p2: "Depois voltas a um palpite grátis por desporto por dia. Reativar a renovação mantém todos os palpites em todos os desportos.",
      cta: "Reativar a renovação", why: "Recebes este e-mail porque tens uma subscrição Pick1." },
    de: { subject: "Dein Pick1-Pro-Abo endet morgen", badge: "ABO &middot; ENDET", h1: "DEIN PRO-ABO", h2: "ENDET MORGEN.",
      p1: "Die automatische Verlängerung ist deaktiviert, dein Pick1-Pro-Zugang endet also mit dem laufenden Zeitraum.",
      p2: "Danach bekommst du wieder einen kostenlosen Tipp pro Sportart und Tag. Mit reaktivierter Verlängerung behältst du alle Tipps.",
      cta: "Verlängerung aktivieren", why: "Du erhältst diese E-Mail, weil du ein Pick1-Abo hast." },
    it: { subject: "Il tuo piano Pick1 Pro finisce domani", badge: "ABBONAMENTO &middot; IN SCADENZA", h1: "IL TUO PIANO PRO", h2: "FINISCE DOMANI.",
      p1: "Il rinnovo automatico è disattivato, quindi il tuo accesso Pick1 Pro finisce al termine del periodo corrente.",
      p2: "Dopo torni a un pronostico gratuito per sport al giorno. Riattivare il rinnovo ti mantiene tutti i pronostici, tutti gli sport.",
      cta: "Riattiva il rinnovo", why: "Ricevi questa email perché hai un abbonamento Pick1." },
    ar: { subject: "تنتهي خطة Pick1 Pro غداً", badge: "الاشتراك &middot; ينتهي", h1: "خطة Pro", h2: "تنتهي غداً.",
      p1: "التجديد التلقائي مُعطَّل، لذلك ينتهي وصولك إلى Pick1 Pro بانتهاء الفترة الحالية.",
      p2: "بعد ذلك تعود إلى توقّع مجاني واحد لكل رياضة يومياً. إعادة تفعيل التجديد تُبقي لك كل التوقّعات في كل الرياضات.",
      cta: "إعادة تفعيل التجديد", why: "تصلك هذه الرسالة لأن لديك اشتراكاً في Pick1." },
  },
};

// App Store storefront → language. Used only for the email fallback, where the
// device locale is by definition unavailable (no device_tokens row exists).
const STOREFRONT_LANG: Record<string, string> = {
  FRA: "fr", BEL: "fr", LUX: "fr", MCO: "fr", CHE: "fr", MAR: "fr", TUN: "fr", DZA: "fr", CIV: "fr", SEN: "fr",
  MEX: "es", ESP: "es", COL: "es", CHL: "es", ARG: "es", ECU: "es", PER: "es", HND: "es", DOM: "es",
  GTM: "es", CRI: "es", PAN: "es", URY: "es", PRY: "es", BOL: "es", VEN: "es", SLV: "es", NIC: "es",
  BRA: "pt", PRT: "pt",
  DEU: "de", AUT: "de",
  ITA: "it",
  SAU: "ar", ARE: "ar", EGY: "ar", QAT: "ar", KWT: "ar", BHR: "ar", OMN: "ar", JOR: "ar", LBN: "ar",
};
const langForStorefront = (sf: string | null): string => (sf && STOREFRONT_LANG[sf]) || "en";

// Only day1_return is split; every other segment is too low-volume to A/B
// meaningfully (single-digit to low-double-digit) and would just add noise.
const AB_VARIANTS: Record<string, string[]> = { day1_return: ["day1_return", "day1_return_b"] };
const LABELS = ["A", "B", "C", "D"];

// Same stable FNV-1a hash send-push uses, so a given user always lands in the
// same arm across campaigns and re-runs.
function pickVariant(userId: string | null, base: string): { locKey: string; label: string | null } {
  const variants = AB_VARIANTS[base];
  if (!variants) return { locKey: base, label: null };
  let h = 2166136261;
  const s = userId || "anon";
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
  const idx = h % variants.length;
  return { locKey: variants[idx], label: LABELS[idx] ?? String(idx) };
}

function render(locKey: string, locale: string | null): Copy | null {
  const entry = LOC[locKey];
  if (!entry) return null;
  const lang = (locale || "en").slice(0, 2).toLowerCase();
  return entry[lang] ?? entry.en;
}

const esc = (s: string) =>
  s.replace(/&(?![a-zA-Z]+;|#\d+;)/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// Branded transactional email, matching send-welcome-email's dark/lime shell so
// Pick1's mail all looks like one sender. RTL-aware for Arabic.
function emailHtml(c: EmailCopy, lang: string): string {
  const rtl = lang === "ar";
  const dir = rtl ? "rtl" : "ltr";
  const align = rtl ? "right" : "left";
  return `<!doctype html>
<html lang="${lang}" dir="${dir}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark only">
  <title>Pick1</title>
  <link href="https://fonts.googleapis.com/css2?family=Anton&family=Archivo:wght@400;700&display=swap" rel="stylesheet">
</head>
<body style="margin:0;padding:0;background-color:#0a0b0d;" bgcolor="#0a0b0d">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;visibility:hidden;opacity:0;color:transparent;height:0;width:0;">${esc(c.p1)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0a0b0d" style="background-color:#0a0b0d;">
    <tr><td align="center" style="padding:32px 16px 48px;">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px;max-width:100%;" dir="${dir}">
        <tr><td align="${align}" style="padding:0 0 20px;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" dir="ltr"><tr>
            <td style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:26px;letter-spacing:0.04em;color:#f5f3ee;padding-right:8px;">PICK</td>
            <td><table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
              <td bgcolor="#d4ff3a" align="center" valign="middle" style="background-color:#d4ff3a;width:30px;height:30px;border-radius:50%;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:18px;line-height:30px;color:#0a0b0d;mso-line-height-rule:exactly;">1</td>
            </tr></table></td>
          </tr></table>
        </td></tr>
        <tr><td bgcolor="#d4ff3a" style="background-color:#d4ff3a;height:4px;line-height:4px;font-size:4px;">&nbsp;</td></tr>
        <tr><td bgcolor="#101114" align="${align}" style="background-color:#101114;border:1px solid #22252b;border-top:0;padding:36px 32px;">
          <span style="display:inline-block;border:1px solid #d4ff3a;color:#d4ff3a;font-family:Archivo,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;padding:6px 12px;">${c.badge}</span>
          <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:38px;line-height:1.08;color:#f5f3ee;text-transform:uppercase;padding:22px 0 6px;">${c.h1}<br><span style="color:#d4ff3a;">${c.h2}</span></div>
          <p style="margin:14px 0 0;font-family:Archivo,Arial,sans-serif;font-size:16px;line-height:1.7;color:#f5f3ee;">${esc(c.p1)}</p>
          <p style="margin:12px 0 0;font-family:Archivo,Arial,sans-serif;font-size:15px;line-height:1.7;color:#b9b7b0;">${esc(c.p2)}</p>
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:26px 0 4px;"><tr>
            <td bgcolor="#d4ff3a" style="background-color:#d4ff3a;border-radius:4px;">
              <a href="${APPLE_SUBS_URL}" style="display:inline-block;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:17px;letter-spacing:0.06em;text-transform:uppercase;color:#0a0b0d;text-decoration:none;padding:14px 30px;">${esc(c.cta)}</a>
            </td></tr></table>
        </td></tr>
        <tr><td align="${align}" style="padding:22px 8px 0;">
          <p style="margin:0;font-family:'Archivo Narrow','Arial Narrow',Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;color:#6e6f75;">PICK<span style="color:#d4ff3a;">1</span>&nbsp;&middot;&nbsp;EVERY PICK, PUBLICLY LOGGED</p>
          <p style="margin:10px 0 0;font-family:Archivo,Arial,sans-serif;font-size:11px;line-height:1.6;color:#6e6f75;">AI predictions for information &amp; entertainment &#8212; not betting advice. ${esc(c.why)}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// Rough UTC offset per app language, used only to avoid pushing in the middle
// of the night. device_tokens has no timezone column, so this is deliberately
// approximate — each language takes the offset of its dominant storefront.
// Email ignores this entirely: a mail sitting in an inbox overnight is fine.
const TZ_OFFSET: Record<string, number> = {
  en: -5, // USA — 173 subs, the largest storefront
  es: -6, // MEX — 87 subs
  fr: 1,  // FRA — 95 subs
  pt: -3, // BRA
  de: 1,
  it: 1,
  ar: 1,
};
const QUIET_START = 10; // no sends before 10:00 local
const QUIET_END = 20;   // no sends after 20:59 local

function inSendWindow(locale: string | null): boolean {
  const lang = (locale || "en").slice(0, 2).toLowerCase();
  const h = (new Date().getUTCHours() + (TZ_OFFSET[lang] ?? 0) + 24) % 24;
  return h >= QUIET_START && h <= QUIET_END;
}

type Recipient = { userId: string; locale: string | null };
type SubRow = { user_id: string; original_transaction_id: string | null; expires_date: string | null; raw: any };

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  // Auth boundary is the gateway (verify_jwt=true) — see the note at the top.
  // Anything reaching this line already presented a valid project JWT.
  if (!req.headers.get("authorization")) return new Response("Unauthorized", { status: 401 });

  let dryRun = false, only: string[] | undefined, skip: string[] | undefined, ignoreQuietHours = false;
  try {
    const body = await req.json().catch(() => ({}));
    ({ dryRun = false, only, skip, ignoreQuietHours = false } = body ?? {});
  } catch { /* empty body is fine — cron posts {} */ }

  const enabled = (s: string) =>
    (!Array.isArray(only) || only.includes(s)) && (!Array.isArray(skip) || !skip.includes(s));

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });
  const report: Record<string, unknown> = { ranAt: new Date().toISOString(), dryRun };

  // Users who already received a given base_key over push. `sinceDays` scopes
  // the lookup to a rolling window: day 1 and trial are once-ever, but a card
  // can fail again months later, so the recovery segments only suppress recent
  // sends rather than banning the user forever.
  async function alreadySent(baseKeys: string[], sinceDays?: number): Promise<Set<string>> {
    const seen = new Set<string>();
    let q = supabase.from("push_log").select("user_id").in("base_key", baseKeys);
    if (sinceDays) q = q.gte("sent_at", new Date(Date.now() - sinceDays * 86400e3).toISOString());
    const { data, error } = await q;
    if (error) throw new Error(`push_log read failed: ${error.message}`);
    for (const r of data ?? []) if (r.user_id) seen.add(r.user_id);
    return seen;
  }

  // Split a user list into those reachable by push right now and those with no
  // device token at all. Users inside their quiet hours are dropped from both —
  // they are simply picked up by a later hourly run.
  async function splitByReachability(userIds: string[]): Promise<{ push: Recipient[]; noToken: string[] }> {
    if (!userIds.length) return { push: [], noToken: [] };
    const locales = new Map<string, string | null>();
    const { data: toks, error } = await supabase
      .from("device_tokens").select("user_id, locale").in("user_id", userIds);
    if (error) throw new Error(`device_tokens read failed: ${error.message}`);
    for (const t of toks ?? []) if (t.user_id && !locales.has(t.user_id)) locales.set(t.user_id, t.locale);

    const push: Recipient[] = [], noToken: string[] = [];
    for (const id of userIds) {
      if (!locales.has(id)) { noToken.push(id); continue; }
      const locale = locales.get(id) ?? null;
      if (!ignoreQuietHours && !inSendWindow(locale)) continue;
      push.push({ userId: id, locale });
    }
    return { push, noToken };
  }

  // Group recipients by (variant, language) — send-push literal mode sends one
  // title/body per call, so each distinct rendering needs its own call.
  async function dispatch(baseKey: string, recipients: Recipient[], freeOnly: boolean) {
    if (!recipients.length) return { eligible: 0, sent: 0, reason: "no recipients" };
    const groups = new Map<string, { locKey: string; label: string | null; lang: string; ids: string[] }>();
    for (const r of recipients) {
      const v = pickVariant(r.userId, baseKey);
      const lang = (r.locale || "en").slice(0, 2).toLowerCase();
      const gk = `${v.locKey}|${lang}`;
      if (!groups.has(gk)) groups.set(gk, { locKey: v.locKey, label: v.label, lang, ids: [] });
      groups.get(gk)!.ids.push(r.userId);
    }
    if (dryRun) {
      return {
        eligible: recipients.length,
        wouldSend: [...groups.values()].map((g) => ({ variant: g.label ?? "-", lang: g.lang, n: g.ids.length, preview: render(g.locKey, g.lang) })),
      };
    }

    let sent = 0, failed = 0;
    const errors: string[] = [];
    const logRows: any[] = [];
    for (const g of groups.values()) {
      const copy = render(g.locKey, g.lang);
      if (!copy) { errors.push(`no copy for ${g.locKey}/${g.lang}`); continue; }
      const res = await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
        method: "POST",
        headers: { authorization: `Bearer ${SERVICE_KEY}`, "content-type": "application/json" },
        body: JSON.stringify({
          title: copy.t, body: copy.b, userIds: g.ids, freeOnly, prefKey: "lifecycle",
          // Literal mode does not stamp campaign/variant itself, so pass them
          // through `data` — send-push spreads it into the APNs/FCM payload and
          // the app logs notification_opened with this attribution.
          data: { campaign: baseKey, ...(g.label ? { variant: g.label } : {}) },
        }),
      });
      const txt = await res.text();
      if (!res.ok) { failed += g.ids.length; errors.push(`send-push ${res.status}: ${txt.slice(0, 160)}`); continue; }
      let parsed: any = {};
      try { parsed = JSON.parse(txt); } catch { /* ignore */ }
      sent += parsed.sent ?? 0;
      // Log the whole attempted group, not just delivered tokens: send-push
      // reports per-call totals, not per-user. Logging attempts is the safer
      // side of the trade — a user with a dead token is never re-targeted on
      // every subsequent hourly run. Only skipped when the call itself failed.
      for (const id of g.ids) logRows.push({ user_id: id, base_key: baseKey, variant: g.label, locale: g.lang });
    }
    if (logRows.length) {
      const { error } = await supabase.from("push_log").insert(logRows);
      if (error) errors.push(`push_log write failed: ${error.message}`);
    }
    return { eligible: recipients.length, groups: groups.size, sent, failed, logged: logRows.length, ...(errors.length ? { errors } : {}) };
  }

  // Transactional email for push-unreachable subscribers. Claims an email_log
  // row first (unique on user_id+email_type+dedupe_key) so a crash mid-send can
  // never produce a duplicate — the same exactly-once pattern send-welcome-email
  // uses. dedupe_key is the subscription period, so one notice per period.
  async function dispatchEmail(emailType: string, subs: SubRow[]) {
    if (!subs.length) return { eligible: 0, sent: 0, reason: "no recipients" };
    if (!RESEND_KEY) return { eligible: subs.length, sent: 0, skipped: "RESEND_API_KEY not set — email fallback dormant" };

    const ids = subs.map((s) => s.user_id);
    const { data: people, error: peopleErr } = await supabase
      .from("signups").select("id, email").in("id", ids);
    if (peopleErr) throw new Error(`signups read failed: ${peopleErr.message}`);
    const emails = new Map((people ?? []).map((p: any) => [p.id, p.email as string | null]));

    const plan = subs.map((s) => ({
      userId: s.user_id,
      email: emails.get(s.user_id) ?? null,
      lang: langForStorefront(s.raw?.transaction?.storefront ?? null),
      dedupeKey: `${s.original_transaction_id ?? "unknown"}:${s.expires_date ?? "unknown"}`,
    })).filter((p) => !!p.email);

    if (dryRun) {
      const byLang = new Map<string, number>();
      for (const p of plan) byLang.set(p.lang, (byLang.get(p.lang) ?? 0) + 1);
      return {
        eligible: subs.length, withEmail: plan.length,
        wouldSend: [...byLang.entries()].map(([lang, n]) => ({ lang, n, subject: (EMAIL_LOC[emailType][lang] ?? EMAIL_LOC[emailType].en).subject })),
      };
    }

    let sent = 0, failed = 0, alreadyClaimed = 0;
    const errors: string[] = [];
    for (const p of plan) {
      const copy = EMAIL_LOC[emailType]?.[p.lang] ?? EMAIL_LOC[emailType]?.en;
      if (!copy) { errors.push(`no email copy for ${emailType}/${p.lang}`); continue; }
      const { data: claimed, error: claimErr } = await supabase.from("email_log")
        .upsert({ user_id: p.userId, email_type: emailType, dedupe_key: p.dedupeKey, status: "pending" },
          { onConflict: "user_id,email_type,dedupe_key", ignoreDuplicates: true })
        .select("id");
      if (claimErr) { errors.push(`email_log claim failed: ${claimErr.message}`); continue; }
      if (!claimed || claimed.length === 0) { alreadyClaimed++; continue; } // already notified this period
      const logId = claimed[0].id;
      try {
        const r = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify({ from: EMAIL_FROM, to: [p.email], subject: copy.subject, html: emailHtml(copy, p.lang) }),
        });
        if (!r.ok) throw new Error(`Resend ${r.status}: ${(await r.text()).slice(0, 300)}`);
        await supabase.from("email_log").update({ status: "sent", sent_at: new Date().toISOString() }).eq("id", logId);
        sent++;
      } catch (e) {
        await supabase.from("email_log").update({ status: "failed", error: String(e).slice(0, 500) }).eq("id", logId);
        failed++;
      }
    }
    return { eligible: subs.length, withEmail: plan.length, sent, failed, alreadyClaimed, ...(errors.length ? { errors } : {}) };
  }

  // Shared shape for the two billing segments: de-dupe by user, split into
  // push-reachable and email-only, then deliver over both channels.
  async function runRecoverySegment(rows: SubRow[], baseKey: string, sinceDays: number) {
    const sent = await alreadySent([baseKey], sinceDays);
    const byUser = new Map<string, SubRow>();
    for (const r of rows) {
      if (r.user_id && !sent.has(r.user_id) && !byUser.has(r.user_id)) byUser.set(r.user_id, r);
    }
    const { push, noToken } = await splitByReachability([...byUser.keys()]);
    return {
      candidates: byUser.size,
      push: await dispatch(baseKey, push, false),
      email: await dispatchEmail(baseKey, noToken.map((id) => byUser.get(id)!)),
    };
  }

  try {
    const now = Date.now();

    // ── Segment 1: day-1 reactivation ──────────────────────────────────────
    // Installed 18–40h ago and not opened in the last 10h. The 22h eligibility
    // window is wider than the 13h nightly quiet gap on purpose, which
    // guarantees every user gets at least one daylight slot before ageing out.
    // Push-only by design: this is marketing, not a billing notice.
    if (enabled("day1")) {
      const { data: fresh, error } = await supabase
        .from("device_tokens")
        .select("user_id, locale, last_seen_at")
        .gte("created_at", new Date(now - 40 * 3600e3).toISOString())
        .lte("created_at", new Date(now - 18 * 3600e3).toISOString())
        .not("user_id", "is", null);
      if (error) throw new Error(`device_tokens read failed: ${error.message}`);

      const staleCutoff = now - 10 * 3600e3;
      const sent = await alreadySent(["day1_return"]);
      const picked = new Map<string, Recipient>();
      for (const t of fresh ?? []) {
        if (!t.user_id || sent.has(t.user_id) || picked.has(t.user_id)) continue;
        // Already came back? Then day-1 reactivation is the wrong message.
        if (t.last_seen_at && new Date(t.last_seen_at).getTime() > staleCutoff) continue;
        if (!ignoreQuietHours && !inSendWindow(t.locale)) continue;
        picked.set(t.user_id, { userId: t.user_id, locale: t.locale });
      }
      // freeOnly:true — send-push drops anyone who already subscribed.
      report.day1 = { candidates: (fresh ?? []).length, ...(await dispatch("day1_return", [...picked.values()], true)) };
    }

    // ── Segments 2 & 3: trial ending in ~24h ───────────────────────────────
    // Split on auto_renew_status because the groups need opposite copy: ON
    // users still hold the plan and are being reminded what they drop back to;
    // OFF users already cancelled and are being told what they lose.
    const wantEnding = enabled("trial_ending");
    const wantCancelled = enabled("trial_ending_cancelled");
    if (wantEnding || wantCancelled) {
      const { data: trials, error } = await supabase
        .from("subscriptions")
        .select("user_id, auto_renew_status")
        .eq("environment", "Production")
        .eq("is_trial", true)
        .is("revocation_date", null)
        .gte("expires_date", new Date(now + 16 * 3600e3).toISOString())
        .lte("expires_date", new Date(now + 34 * 3600e3).toISOString())
        .not("user_id", "is", null);
      if (error) throw new Error(`subscriptions read failed: ${error.message}`);

      const sent = await alreadySent(["trial_ending", "trial_ending_cancelled"]);
      const autoRenew = new Map<string, boolean | null>();
      for (const s of trials ?? []) {
        if (s.user_id && !sent.has(s.user_id)) autoRenew.set(s.user_id, s.auto_renew_status);
      }
      const { push } = await splitByReachability([...autoRenew.keys()]);
      const renewOn = push.filter((r) => autoRenew.get(r.userId) !== false);
      const renewOff = push.filter((r) => autoRenew.get(r.userId) === false);

      if (wantEnding) report.trial_ending = { candidates: autoRenew.size, ...(await dispatch("trial_ending", renewOn, false)) };
      if (wantCancelled) report.trial_ending_cancelled = await dispatch("trial_ending_cancelled", renewOff, false);
    }

    // ── Segment 4: card declined ───────────────────────────────────────────
    // Written by apple-notifications from DID_FAIL_TO_RENEW: `in_grace_period`
    // when Apple is retrying with access intact, `in_billing_retry` when it
    // isn't. Bounded to the last 21 days so long-dead subscriptions — which
    // need a win-back offer, not a "fix your card" nudge — are left alone.
    if (enabled("payment_failed")) {
      const { data: failing, error } = await supabase
        .from("subscriptions")
        .select("user_id, original_transaction_id, expires_date, raw")
        .eq("environment", "Production")
        .in("status", ["in_grace_period", "in_billing_retry"])
        .is("revocation_date", null)
        .gte("updated_at", new Date(now - 21 * 86400e3).toISOString())
        .not("user_id", "is", null);
      if (error) throw new Error(`subscriptions read failed: ${error.message}`);
      report.payment_failed = await runRecoverySegment((failing ?? []) as SubRow[], "payment_failed", 30);
    }

    // ── Segment 5: auto-renew switched off, expiry imminent ────────────────
    // Still entitled and still paid up, but set to lapse. Targeted 16–48h out
    // so the message lands while the subscription is genuinely about to end
    // rather than days early, when it reads as nagging.
    if (enabled("renewal_off_save")) {
      const { data: lapsing, error } = await supabase
        .from("subscriptions")
        .select("user_id, original_transaction_id, expires_date, raw")
        .eq("environment", "Production")
        .eq("is_trial", false)
        .eq("auto_renew_status", false)
        .is("revocation_date", null)
        .gte("expires_date", new Date(now + 16 * 3600e3).toISOString())
        .lte("expires_date", new Date(now + 48 * 3600e3).toISOString())
        .not("user_id", "is", null);
      if (error) throw new Error(`subscriptions read failed: ${error.message}`);
      report.renewal_off_save = await runRecoverySegment((lapsing ?? []) as SubRow[], "renewal_off_save", 25);
    }

    return Response.json(report);
  } catch (e) {
    console.error("lifecycle-push error:", (e as Error).message);
    return Response.json({ error: (e as Error).message, ...report }, { status: 500 });
  }
});
