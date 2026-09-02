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
// THERE IS NO LOSING-DAY RECAP. That is a decision, not an oversight. The
// obligation Pick1 takes on is to PUBLISH its losses, and it does, in the
// app, on every settled pick, permanently. Pushing them is a different
// thing: nobody opens "yesterday was down 8%", and a notification is not
// where an audit trail belongs. So on a bad day the product says nothing at
// all, which is the only version of "stay positive" that does not require
// lying.
const LOC: Record<string, Locales> = {
  result_win: {
    en: { t: "💰 CALLED IT", b: "{team} {score} · +{pct}%" },
    fr: { t: "💰 DANS LE MILLE", b: "{team} {score} · +{pct}%" },
    es: { t: "💰 LO CLAVASTE", b: "{team} {score} · +{pct}%" },
    de: { t: "💰 GENAU SO", b: "{team} {score} · +{pct}%" },
    it: { t: "💰 AZZECCATO", b: "{team} {score} · +{pct}%" },
    pt: { t: "💰 EM CHEIO", b: "{team} {score} · +{pct}%" },
    ar: { t: "💰 توقّع صحيح", b: "{team} {score} · +{pct}٪" },
  },
  result_loss: {
    en: { t: "{score} — final", b: "Not this one. Tomorrow's board is up." },
    fr: { t: "{score} — terminé", b: "Pas celui-là. Le tableau de demain arrive." },
    es: { t: "{score} — final", b: "Este no. El cartel de mañana ya viene." },
    de: { t: "{score} — Schluss", b: "Nicht dieser. Das Board für morgen kommt." },
    it: { t: "{score} — finale", b: "Non questo. Il programma di domani arriva." },
    pt: { t: "{score} — final", b: "Este não. O quadro de amanhã já vem." },
    ar: { t: "{score} — انتهت", b: "ليس هذه. لوحة الغد قادمة." },
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
    en: { t: "🎯 Today's #1: {team}", b: "Called at {conf}%." },
    fr: { t: "🎯 Le n°1 du jour : {team}", b: "Annoncé à {conf}%." },
    es: { t: "🎯 El n.º1 de hoy: {team}", b: "Anunciado al {conf}%." },
    de: { t: "🎯 Nr. 1 heute: {team}", b: "Mit {conf}% angesagt." },
    it: { t: "🎯 Il n.1 di oggi: {team}", b: "Dato al {conf}%." },
    pt: { t: "🎯 O n.º1 de hoje: {team}", b: "Indicado a {conf}%." },
    ar: { t: "🎯 رقم 1 اليوم: {team}", b: "بثقة {conf}٪." },
  },
  // NEW. Only when the board really carries a pick paying +100% or better,
  // which measured out at about one day in three. Rare enough to be news.
  big_odds: {
    en: { t: "🚀 +{pct}% on the board today", b: "{team}, called at {conf}%." },
    fr: { t: "🚀 +{pct}% au tableau aujourd'hui", b: "{team}, annoncé à {conf}%." },
    es: { t: "🚀 +{pct}% en el cartel de hoy", b: "{team}, anunciado al {conf}%." },
    de: { t: "🚀 +{pct}% heute auf dem Board", b: "{team}, mit {conf}% angesagt." },
    it: { t: "🚀 +{pct}% sul programma di oggi", b: "{team}, dato al {conf}%." },
    pt: { t: "🚀 +{pct}% no quadro de hoje", b: "{team}, indicado a {conf}%." },
    ar: { t: "🚀 +{pct}٪ على لوحة اليوم", b: "{team}، بثقة {conf}٪." },
  },
  recap: {
    en: { t: "💰 $100 a pick = +${net}", b: "{wins}/{games} yesterday." },
    fr: { t: "💰 100 $ par pari = +{net} $", b: "{wins}/{games} hier." },
    es: { t: "💰 $100 por pick = +${net}", b: "{wins}/{games} ayer." },
    de: { t: "💰 100 $ pro Tipp = +{net} $", b: "{wins}/{games} gestern." },
    it: { t: "💰 100 $ a pronostico = +{net} $", b: "{wins}/{games} ieri." },
    pt: { t: "💰 $100 por palpite = +${net}", b: "{wins}/{games} ontem." },
    ar: { t: "💰 100$ لكل توقّع = +{net}$", b: "{wins}/{games} أمس." },
  },
  // NEW. Consecutive profitable days from the graded record. When the run
  // breaks the notification simply stops; the streak is never rounded up.
  hot_streak: {
    en: { t: "🔥 {days} winning days in a row", b: "{wins}/{games} yesterday. Today is up." },
    fr: { t: "🔥 {days} jours gagnants d'affilée", b: "{wins}/{games} hier. Le jour est lancé." },
    es: { t: "🔥 {days} días ganadores seguidos", b: "{wins}/{games} ayer. Hoy ya está." },
    de: { t: "🔥 {days} Gewinntage in Folge", b: "{wins}/{games} gestern. Heute ist offen." },
    it: { t: "🔥 {days} giorni vincenti di fila", b: "{wins}/{games} ieri. Oggi è aperto." },
    pt: { t: "🔥 {days} dias a ganhar seguidos", b: "{wins}/{games} ontem. Hoje já está." },
    ar: { t: "🔥 {days} أيام رابحة تواليًا", b: "{wins}/{games} أمس. اليوم مفتوح." },
  },
  free_recap: {
    en: { t: "🔒 You missed +${net} yesterday", b: "Members went {w}-{l}." },
    fr: { t: "🔒 Tu as raté +{net} $ hier", b: "Les membres : {w}-{l}." },
    es: { t: "🔒 Te perdiste +${net} ayer", b: "Los miembros: {w}-{l}." },
    de: { t: "🔒 Du hast +{net} $ verpasst", b: "Mitglieder: {w}-{l}." },
    it: { t: "🔒 Ti sei perso +{net} $ ieri", b: "I membri: {w}-{l}." },
    pt: { t: "🔒 Perdeste +${net} ontem", b: "Membros: {w}-{l}." },
    ar: { t: "🔒 فاتك +{net}$ أمس", b: "الأعضاء: {w}-{l}." },
  },
  free_recap_b: {
    en: { t: "📈 Members: {w}-{l} yesterday", b: "$100 a pick = +${net}." },
    fr: { t: "📈 Les membres : {w}-{l} hier", b: "100 $ par pari = +{net} $." },
    es: { t: "📈 Miembros: {w}-{l} ayer", b: "$100 por pick = +${net}." },
    de: { t: "📈 Mitglieder: {w}-{l} gestern", b: "100 $ pro Tipp = +{net} $." },
    it: { t: "📈 Membri: {w}-{l} ieri", b: "100 $ a pronostico = +{net} $." },
    pt: { t: "📈 Membros: {w}-{l} ontem", b: "$100 por palpite = +${net}." },
    ar: { t: "📈 الأعضاء: {w}-{l} أمس", b: "100$ لكل توقّع = +{net}$." },
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
  result_loss: "personal",
  goal_fav: "personal",

  pick_drop: "daily",
  recap: "daily",
  hot_streak: "daily",
  big_odds: "daily",
  free_recap: "daily",
  free_recap_b: "daily",
  day1_return: "daily",
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
  if (days <= 14) return { perDay: 2, perWeek: 10 };
  if (days <= 45) return { perDay: 1, perWeek: 2 };
  return { perDay: 0, perWeek: 0 };
}

// Rough UTC offset per app language. device_tokens carries no timezone, so
// each language takes the offset of its dominant storefront. Same table as
// lifecycle-push, kept in step by hand; it only decides "night or not", and
// being an hour out never changes that answer.
const TZ_OFFSET: Record<string, number> = {
  en: -5, es: -6, fr: 1, pt: -3, de: 1, it: 1, ar: 1,
};
const QUIET_START = 9;  // nothing before 09:00 local
const QUIET_END = 21;   // nothing at 21:00 local or later

function localHour(locale: string | null, at: Date = new Date()): number {
  const lang = (locale || "en").slice(0, 2).toLowerCase();
  return (at.getUTCHours() + (TZ_OFFSET[lang] ?? 0) + 24) % 24;
}
const inSendWindow = (locale: string | null, at: Date = new Date()) => {
  const h = localHour(locale, at);
  return h >= QUIET_START && h < QUIET_END;
};

/// The next instant that is QUIET_START local time for this locale.
///
/// pick_drop leaves the pipeline at a fixed UTC hour, which is the middle of
/// the night on the US west coast. Before this, those users were simply being
/// woken up; the alternative of refusing to send would have removed them from
/// the product. Parking the send until morning is the only option that keeps
/// both the user and the notification.
function nextSendWindow(locale: string | null, from: Date = new Date()): Date {
  for (let h = 0; h <= 24; h++) {
    const t = new Date(from.getTime() + h * 3600e3);
    if (inSendWindow(locale, t)) return t;
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
const MIN_GAP_HOURS = 4;

function fill(tpl: string, args: Record<string, unknown>): string {
  return tpl.replace(/\{(\w+)\}/g, (_, k) => (args[k] !== undefined ? String(args[k]) : `{${k}}`));
}
function render(locKey: string, locale: string, args: Record<string, unknown>): Copy | null {
  const entry = LOC[locKey];
  if (!entry) return null;
  const lang = (locale || "en").slice(0, 2).toLowerCase();
  const copy = entry[lang] ?? entry.en;
  return { t: fill(copy.t, args), b: fill(copy.b, args) };
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
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
  title: string; body: string; sound: string; data: Record<string, string>;
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
          notification: { sound: msg.sound, channel_id: "pick1_alerts", default_sound: msg.sound === "default" },
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
    prefKey: string | undefined, userIds: string[] | undefined, freeOnly: boolean | undefined,
    args: Record<string, unknown> | undefined, data: Record<string, unknown> | undefined,
    drain: boolean | undefined, dryRun: boolean | undefined,
    ttlHours: number | undefined;
  try {
    ({ key, title, body, prefKey, userIds, freeOnly, args, data,
       drain, dryRun, ttlHours } = await req.json());
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
    const sound = k === "result_win" ? "win.caf" : "default";
    const androidSound = "default";

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
    const logRows: any[] = [];
    const loggedUsers = new Set<string>();
    function logIfKeyed(t: any, label: string | null) {
      if (k && t.user_id && !loggedUsers.has(t.user_id)) {
        loggedUsers.add(t.user_id);
        logRows.push({ user_id: t.user_id, base_key: k, variant: label, locale: t.locale ?? "en" });
      }
    }

    if (apnsReady && apple.length) {
      const jwt = await apnsJwt();
      for (const t of apple) {
        const { tTitle, tBody, label } = resolve(t);
        const stamp = k ? { campaign: k, ...(label ? { variant: label } : {}) } : {};
        const aps = { aps: { alert: { title: tTitle, body: tBody }, sound }, ...d, ...stamp };
        const host = t.environment === "sandbox" ? HOST_SANDBOX : HOST_PROD;
        const res = await sendApns(host, t.token, jwt, aps);
        if (res.ok) { sent++; logIfKeyed(t, label); }
        else {
          failed++;
          if (res.status === 410 || res.body.includes("BadDeviceToken") || res.body.includes("Unregistered")) dead.push(t.token);
          else console.error(`apns ${res.status}: ${res.body.slice(0, 160)}`);
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
            title: tTitle, body: tBody, sound: androidSound, data: stamp,
          });
          if (res.ok) { sent++; logIfKeyed(t, label); }
          else {
            failed++;
            if (res.status === 404 || res.body.includes("UNREGISTERED") || res.body.includes("registration-token-not-registered")) dead.push(t.token);
            else console.error(`fcm ${res.status}: ${res.body.slice(0, 200)}`);
          }
        }
      } catch (e) {
        console.error(`fcm setup failed: ${String(e).slice(0, 200)}`);
        failed += android.length;
      }
    }

    if (dead.length) await supabase.from("device_tokens").delete().in("token", dead);
    if (logRows.length) { try { await supabase.from("push_log").insert(logRows); } catch (_e) { /* non-fatal */ } }
    return { sent, failed, pruned: dead.length };
  }

  /// Every device for a set of users, so the drain can reach them again.
  async function tokensFor(ids: string[]) {
    if (!ids.length) return [];
    const { data: rows } = await supabase.from("device_tokens")
      .select("token, environment, prefs, locale, user_id, platform, last_seen_at").in("user_id", ids);
    return rows ?? [];
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
      const ok = toks.filter((t: any) => inSendWindow(t.locale));
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

  if (!key && (!title || !body)) return new Response("need key or title+body", { status: 400 });

  // -- Live send ---------------------------------------------------------

  let query = supabase.from("device_tokens")
    .select("token, environment, prefs, locale, user_id, platform, last_seen_at");
  if (Array.isArray(userIds) && userIds.length) query = query.in("user_id", userIds);
  const { data: rows, error } = await query;
  if (error) return Response.json({ error: error.message }, { status: 500 });

  let tokens = rows ?? [];
  if (prefKey) tokens = tokens.filter((t: any) => t.prefs?.[prefKey] !== false);

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
  const counts = new Map<string, { day: number; week: number; last: string | null }>();
  if (tier !== "critical") {
    const ids = [...new Set(tokens.map((t: any) => t.user_id).filter(Boolean))];
    const weekAgo = new Date(Date.now() - 7 * 86400e3).toISOString();
    const dayAgo = new Date(Date.now() - 86400e3).toISOString();
    for (let i = 0; i < ids.length; i += 500) {
      const { data: hist } = await supabase.from("push_log")
        .select("user_id, sent_at").in("user_id", ids.slice(i, i + 500)).gte("sent_at", weekAgo);
      for (const h of hist ?? []) {
        const c = counts.get(h.user_id) ?? { day: 0, week: 0, last: null };
        c.week++;
        if (h.sent_at >= dayAgo) c.day++;
        if (!c.last || h.sent_at > c.last) c.last = h.sent_at;
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
      const c = counts.get(t.user_id) ?? { day: 0, week: 0, last: null };
      if (c.day >= a.perDay || c.week >= a.perWeek) { skipped.capped++; continue; }
      if (c.last) {
        const gap = new Date(Date.parse(c.last) + MIN_GAP_HOURS * 3600e3);
        if (gap > earliest) earliest = gap;
      }
    }
    if (earliest <= nowTs && inSendWindow(t.locale)) now.push(t);
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
        send_after: nextSendWindow(t.locale, t._after ?? new Date()).toISOString(),
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
