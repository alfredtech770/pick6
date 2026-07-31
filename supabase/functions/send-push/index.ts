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
const LOC: Record<string, Locales> = {
  result_win: {
    en: { t: "💰 CALLED IT.", b: "{team} {score} — your pick cashed at +{pct}% 📈" },
    fr: { t: "💰 DANS LE MILLE.", b: "{team} {score} — ton pari passe à +{pct}% 📈" },
    es: { t: "💰 LO CLAVASTE.", b: "{team} {score} — tu pick ganó a +{pct}% 📈" },
    de: { t: "💰 GENAU SO.", b: "{team} {score} — dein Tipp bringt +{pct}% 📈" },
    it: { t: "💰 AZZECCATO.", b: "{team} {score} — il tuo pronostico paga +{pct}% 📈" },
    pt: { t: "💰 ACERTASTE EM CHEIO.", b: "{team} {score} — o teu palpite pagou +{pct}% 📈" },
    ar: { t: "💰 توقّع صحيح!", b: "{team} {score} — تذكرتك ربحت +{pct}٪ 📈" },
  },
  result_loss: {
    en: { t: "{score} — final", b: "That one got away. Tomorrow's board is already loading 👀" },
    fr: { t: "{score} — terminé", b: "Celui-là s'est échappé. Le programme de demain charge déjà 👀" },
    es: { t: "{score} — final", b: "Ese se escapó. El cartel de mañana ya se está cargando 👀" },
    de: { t: "{score} — Schluss", b: "Der ist weg. Das Board für morgen lädt schon 👀" },
    it: { t: "{score} — finale", b: "Quello è sfuggito. Il programma di domani è già in arrivo 👀" },
    pt: { t: "{score} — final", b: "Esse fugiu. O quadro de amanhã já está a carregar 👀" },
    ar: { t: "{score} — انتهت", b: "هذه فاتت. لوحة الغد قيد التحميل بالفعل 👀" },
  },
  goal_fav: {
    en: { t: "⚡ {score}!", b: "{team} strikes in your game. Your pick's looking 🔥" },
    fr: { t: "⚡ {score} !", b: "{team} marque dans ton match. Ton pari est en feu 🔥" },
    es: { t: "⚡ ¡{score}!", b: "{team} marca en tu partido. Tu pick va 🔥" },
    de: { t: "⚡ {score}!", b: "{team} trifft in deinem Spiel. Dein Tipp läuft 🔥" },
    it: { t: "⚡ {score}!", b: "{team} segna nella tua partita. Il tuo pronostico vola 🔥" },
    pt: { t: "⚡ {score}!", b: "{team} marca no teu jogo. O teu palpite está 🔥" },
    ar: { t: "⚡ {score}!", b: "{team} يسجّل في مباراتك. توقّعك مشتعل 🔥" },
  },
  pick_drop: {
    en: { t: "🎯 Today's #1 lock is in", b: "{team} at {conf}% confidence. Tap to see your pick." },
    fr: { t: "🎯 Le top pari du jour est là", b: "{team} à {conf}% de confiance. Touche pour voir ton pari." },
    es: { t: "🎯 El pick #1 de hoy ya está", b: "{team} con {conf}% de confianza. Toca para verlo." },
    de: { t: "🎯 Der Top-Tipp des Tages ist da", b: "{team} mit {conf}% Konfidenz. Tippen zum Ansehen." },
    it: { t: "🎯 Il pronostico n.1 di oggi è qui", b: "{team} al {conf}% di fiducia. Tocca per vederlo." },
    pt: { t: "🎯 O palpite n.º 1 de hoje chegou", b: "{team} com {conf}% de confiança. Toca para ver." },
    ar: { t: "🎯 أقوى توقّع لليوم وصل", b: "{team} بثقة {conf}٪. اضغط لرؤيته." },
  },
  recap: {
    en: { t: "📊 Yesterday: {wins}/{games} hit", b: "Riding them all = +{pct}%. Today's picks are live 👀" },
    fr: { t: "📊 Hier : {wins}/{games} réussis", b: "Tout miser = +{pct}%. Les paris du jour sont là 👀" },
    es: { t: "📊 Ayer: {wins}/{games} acertados", b: "Apostarlos todos = +{pct}%. Los picks de hoy ya están 👀" },
    de: { t: "📊 Gestern: {wins}/{games} getroffen", b: "Alle tippen = +{pct}%. Die heutigen Tipps sind live 👀" },
    it: { t: "📊 Ieri: {wins}/{games} indovinati", b: "Puntarli tutti = +{pct}%. I pronostici di oggi sono live 👀" },
    pt: { t: "📊 Ontem: {wins}/{games} certos", b: "Apostar em todos = +{pct}%. Os palpites de hoje estão live 👀" },
    ar: { t: "📊 أمس: {wins}/{games} صحيحة", b: "لو راهنت على الكل = +{pct}٪. توقّعات اليوم جاهزة 👀" },
  },
  free_recap: {
    en: { t: "🔒 You missed {ret} yesterday", b: "Members went {w}-{l}. Don't miss today →" },
    fr: { t: "🔒 Tu as raté {ret} hier", b: "Les membres : {w}-{l}. Ne rate pas aujourd'hui →" },
    es: { t: "🔒 Te perdiste {ret} ayer", b: "Los miembros: {w}-{l}. No te pierdas hoy →" },
    de: { t: "🔒 Du hast gestern {ret} verpasst", b: "Mitglieder: {w}-{l}. Verpass heute nicht →" },
    it: { t: "🔒 Ti sei perso {ret} ieri", b: "I membri: {w}-{l}. Non perderti oggi →" },
    pt: { t: "🔒 Perdeste {ret} ontem", b: "Membros: {w}-{l}. Não percas hoje →" },
    ar: { t: "🔒 فاتك {ret} أمس", b: "الأعضاء: {w}-{l}. لا تفوّت اليوم ←" },
  },
  free_recap_b: {
    en: { t: "📈 Members crushed it: {w}-{l}", b: "$100 a pick = {ret} yesterday. Get today's board →" },
    fr: { t: "📈 Les membres ont cartonné : {w}-{l}", b: "100 $ par pick = {ret} hier. Prends le programme du jour →" },
    es: { t: "📈 Los miembros arrasaron: {w}-{l}", b: "$100 por pick = {ret} ayer. Consigue el cartel de hoy →" },
    de: { t: "📈 Mitglieder räumten ab: {w}-{l}", b: "100 $ pro Pick = {ret} gestern. Hol dir das heutige Board →" },
    it: { t: "📈 I membri hanno dominato: {w}-{l}", b: "100 $ a pick = {ret} ieri. Prendi il programma di oggi →" },
    pt: { t: "📈 Os membros arrasaram: {w}-{l}", b: "$100 por pick = {ret} ontem. Recebe o cartaz de hoje →" },
    ar: { t: "📈 الأعضاء تألقوا: {w}-{l}", b: "100$ لكل اختيار = {ret} أمس. احصل على قائمة اليوم ←" },
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
    args: Record<string, unknown> | undefined, data: Record<string, unknown> | undefined;
  try {
    ({ key, title, body, prefKey, userIds, freeOnly, args, data } = await req.json());
    if (!key && (!title || !body)) throw new Error("need key or title+body");
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, SERVICE_KEY);
  let query = supabase.from("device_tokens").select("token, environment, prefs, locale, user_id, platform");
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
  if (tokens.length === 0) return Response.json({ sent: 0, reason: "no tokens" });

  const sound = key === "result_win" ? "win.caf" : "default";
  // Android has no bundled win.caf; fall back to the default channel sound.
  const androidSound = "default";

  // Resolve the per-device copy + A/B arm ONCE, transport-independent.
  function resolve(t: any): { tTitle: string; tBody: string; label: string | null } {
    if (!key) return { tTitle: title ?? "", tBody: body ?? "", label: null };
    const v = pickVariant(t.user_id ?? null, key);
    const c = render(v.locKey, t.locale ?? "en", args ?? {});
    if (c) return { tTitle: c.t, tBody: c.b, label: v.label };
    return { tTitle: title ?? key, tBody: body ?? "", label: v.label };
  }

  const android = (tokens as any[]).filter((t) => t.platform === "android");
  const apple = (tokens as any[]).filter((t) => t.platform !== "android");

  let sent = 0, failed = 0;
  const dead: string[] = [];
  const logRows: any[] = [];
  const loggedUsers = new Set<string>();
  function logIfKeyed(t: any, label: string | null) {
    if (key && t.user_id && !loggedUsers.has(t.user_id)) {
      loggedUsers.add(t.user_id);
      logRows.push({ user_id: t.user_id, base_key: key, variant: label, locale: t.locale ?? "en" });
    }
  }

  // ── APNs fan-out ──────────────────────────────────────────────────────
  if (apnsReady && apple.length) {
    const jwt = await apnsJwt();
    for (const t of apple) {
      const { tTitle, tBody, label } = resolve(t);
      const stamp = key ? { campaign: key, ...(label ? { variant: label } : {}) } : {};
      const aps = { aps: { alert: { title: tTitle, body: tBody }, sound }, ...(data ?? {}), ...stamp };
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

  // ── FCM v1 fan-out (Android) ──────────────────────────────────────────
  if (sa && android.length) {
    try {
      const accessToken = await fcmAccessToken(sa);
      for (const t of android) {
        const { tTitle, tBody, label } = resolve(t);
        // FCM data values must be strings.
        const stamp: Record<string, string> = {};
        for (const [k, v] of Object.entries(data ?? {})) stamp[k] = String(v);
        if (key) { stamp.campaign = key; if (label) stamp.variant = label; }
        const res = await sendFcm(sa.project_id, accessToken, t.token, {
          title: tTitle, body: tBody, sound: androidSound, data: stamp,
        });
        if (res.ok) { sent++; logIfKeyed(t, label); }
        else {
          failed++;
          // 404 UNREGISTERED / 400 INVALID_ARGUMENT on the token ⇒ prune it.
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
  return Response.json({ sent, failed, pruned: dead.length, logged: logRows.length, apple: apple.length, android: android.length });
});
