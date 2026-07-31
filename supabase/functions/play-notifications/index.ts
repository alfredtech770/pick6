// play-notifications — Google Play Real-time Developer Notifications (RTDN)
// webhook, delivered via Pub/Sub push. The Android twin of apple-notifications.
//
// Pub/Sub POSTs { message: { data: <base64 DeveloperNotification>, ... } } on
// every subscription/one-time lifecycle event. We decode it, re-fetch the
// authoritative state from the Play Developer API (so a forged push can never
// grant entitlement), and upsert public.subscriptions — the same table iOS
// feeds, so send-push's freeOnly filter and the app's entitlement check treat
// both platforms identically.
//
// Secret: PLAY_SERVICE_ACCOUNT (falls back to FCM_SERVICE_ACCOUNT). Optional
// PLAY_PUBSUB_SECRET — if set, the push subscription must call
// ?secret=<value> or the request is rejected.
import { createClient } from "npm:@supabase/supabase-js@2";

const PACKAGE = "com.pick1.app";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SA_RAW = Deno.env.get("PLAY_SERVICE_ACCOUNT") ?? Deno.env.get("FCM_SERVICE_ACCOUNT");
const PUBSUB_SECRET = Deno.env.get("PLAY_PUBSUB_SECRET");
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const ALERT_TO = Deno.env.get("ALERT_EMAIL") ?? "ethan@milam.app";
const ALERT_FROM = Deno.env.get("EMAIL_FROM") ?? "Pick1 <hello@pick1.live>";
const DAY_MS = 24 * 60 * 60 * 1000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type SA = { client_email: string; private_key: string; token_uri?: string };

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
function b64decode(s: string): string {
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/"));
  return new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
}

let cachedTok: { token: string; exp: number } | null = null;
async function playToken(sa: SA): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedTok && cachedTok.exp - now > 60) return cachedTok.token;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const tokenUri = sa.token_uri || "https://oauth2.googleapis.com/token";
  const head = b64urlStr(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64urlStr(JSON.stringify({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: tokenUri, iat: now, exp: now + 3600,
  }));
  const input = `${head}.${claims}`;
  const sig = new Uint8Array(
    await crypto.subtle.sign({ name: "RSASSA-PKCS1-v1_5" }, key, new TextEncoder().encode(input)),
  );
  const r = await fetch(tokenUri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${input}.${b64url(sig)}`,
  });
  const j = await r.json();
  if (!r.ok || !j.access_token) throw new Error(`play token ${r.status}`);
  cachedTok = { token: j.access_token, exp: now + (j.expires_in ?? 3600) };
  return cachedTok.token;
}

const SUB_STATE: Record<string, string> = {
  SUBSCRIPTION_STATE_ACTIVE: "active",
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: "in_grace_period",
  SUBSCRIPTION_STATE_ON_HOLD: "in_billing_retry",
  SUBSCRIPTION_STATE_PAUSED: "paused",
  SUBSCRIPTION_STATE_CANCELED: "canceled",
  SUBSCRIPTION_STATE_EXPIRED: "expired",
  SUBSCRIPTION_STATE_PENDING: "pending",
};
const SUB_NOTIF: Record<number, string> = {
  1: "RECOVERED", 2: "RENEWED", 3: "CANCELED", 4: "PURCHASED", 5: "ON_HOLD",
  6: "IN_GRACE_PERIOD", 7: "RESTARTED", 8: "PRICE_CHANGE_CONFIRMED", 9: "DEFERRED",
  10: "PAUSED", 11: "PAUSE_SCHEDULE_CHANGED", 12: "REVOKED", 13: "EXPIRED",
};

function subRowFromV2(token: string, v2: any, notifType: string) {
  const line = (v2.lineItems ?? [])[0] ?? {};
  const expiry = (v2.lineItems ?? []).map((l: any) => l.expiryTime).filter(Boolean).sort().pop() ?? null;
  const obf = v2.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  const userId = obf && UUID_RE.test(obf) ? obf : null;
  const autoRenew = line.autoRenewingPlan?.autoRenewEnabled ?? null;
  const state = v2.subscriptionState as string | undefined;
  const revoked = notifType === "REVOKED";
  return {
    original_transaction_id: token,
    user_id: userId,
    product_id: line.productId ?? null,
    status: revoked ? "revoked" : (state && SUB_STATE[state]) ?? "active",
    environment: v2.testPurchase ? "Sandbox" : "Production",
    auto_renew_status: typeof autoRenew === "boolean" ? autoRenew : null,
    auto_renew_product_id: line.productId ?? null,
    purchase_date: v2.startTime ?? null,
    expires_date: expiry,
    revocation_date: revoked ? new Date().toISOString() : null,
    is_trial: !!line.offerDetails?.offerId?.toString().toLowerCase().includes("trial"),
    last_transaction_id: v2.latestOrderId ?? null,
    last_notification_type: `PLAY_${notifType}`,
    signed_date: new Date().toISOString(),
    raw: { play: v2 },
  };
}

async function fetchSubscription(tok: string, token: string): Promise<any> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;
  const r = await fetch(url, { headers: { authorization: `Bearer ${tok}` } });
  const j = await r.json();
  if (!r.ok) throw new Error(`subv2 ${r.status}: ${JSON.stringify(j).slice(0, 200)}`);
  return j;
}
async function fetchProduct(tok: string, productId: string, token: string): Promise<any> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`;
  const r = await fetch(url, { headers: { authorization: `Bearer ${tok}` } });
  const j = await r.json();
  if (!r.ok) throw new Error(`product ${r.status}: ${JSON.stringify(j).slice(0, 200)}`);
  return j;
}

async function alertFounder(subject: string, lines: [string, string][]): Promise<void> {
  if (!RESEND_KEY) return;
  const esc = (s: string) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const trs = lines.map(([k, v]) =>
    `<tr><td style="padding:5px 18px 5px 0;color:#8a8f98;font:13px Arial;">${esc(k)}</td>` +
    `<td style="padding:5px 0;color:#f5f3ee;font:bold 13px Arial;">${esc(v)}</td></tr>`).join("");
  const html = `<div style="background:#0a0b0d;padding:24px;"><div style="max-width:480px;margin:0 auto;background:#101114;border:1px solid #22252b;border-radius:12px;padding:26px;">` +
    `<div style="font:bold 21px Arial;color:#f5f3ee;margin-bottom:16px;">${esc(subject)}</div>` +
    `<table>${trs}</table><div style="margin-top:18px;font:11px Arial;color:#6e6f75;">Pick1 · Google Play RTDN</div></div></div>`;
  try {
    await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from: ALERT_FROM, to: [ALERT_TO], subject, html }),
    });
  } catch (_e) { /* mail failure must not fail the 200 we owe Pub/Sub */ }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (PUBSUB_SECRET) {
    const u = new URL(req.url);
    if (u.searchParams.get("secret") !== PUBSUB_SECRET) return new Response("Forbidden", { status: 403 });
  }
  if (!SA_RAW) return new Response("OK", { status: 200 }); // ack; nothing we can do yet

  let notif: any;
  try {
    const body = await req.json();
    const data = body?.message?.data;
    if (!data) return new Response("OK", { status: 200 }); // malformed → ack, don't retry
    notif = JSON.parse(b64decode(data));
  } catch {
    return new Response("OK", { status: 200 });
  }

  if (notif.testNotification) {
    console.log("play RTDN test notification received");
    return new Response("OK", { status: 200 });
  }
  if (notif.packageName && notif.packageName !== PACKAGE) {
    console.warn("package mismatch:", notif.packageName);
    return new Response("OK", { status: 200 });
  }

  let sa: SA;
  try { sa = JSON.parse(SA_RAW) as SA; } catch { return new Response("OK", { status: 200 }); }
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, SERVICE_KEY);

  try {
    const tok = await playToken(sa);
    let row: Record<string, unknown> | null = null;

    if (notif.subscriptionNotification) {
      const sn = notif.subscriptionNotification;
      const notifType = SUB_NOTIF[sn.notificationType] ?? String(sn.notificationType);
      const v2 = await fetchSubscription(tok, sn.purchaseToken);
      row = subRowFromV2(sn.purchaseToken, v2, notifType);
      if (notifType === "PURCHASED") {
        const isProd = row.environment === "Production";
        await alertFounder(isProd ? "🎉 New Pick1 subscription (Android)" : "🎉 New Pick1 sub (Android) [TEST]", [
          ["Plan", String(row.product_id ?? "—")],
          ["Renews", String(row.expires_date ?? "—")],
          ["Environment", String(row.environment)],
          ["User", String(row.user_id ?? "(unmapped)")],
        ]);
      }
    } else if (notif.oneTimeProductNotification) {
      const on = notif.oneTimeProductNotification;
      const p = await fetchProduct(tok, on.sku, on.purchaseToken);
      const buyMs = p.purchaseTimeMillis ? Number(p.purchaseTimeMillis) : Date.now();
      const obf = p.obfuscatedExternalAccountId;
      row = {
        original_transaction_id: on.purchaseToken,
        user_id: obf && UUID_RE.test(obf) ? obf : null,
        product_id: on.sku,
        status: p.purchaseState === 0 ? "active" : "expired",
        environment: p.purchaseType === 0 ? "Sandbox" : "Production",
        purchase_date: new Date(buyMs).toISOString(),
        expires_date: new Date(buyMs + DAY_MS).toISOString(),
        revocation_date: null,
        is_trial: false,
        last_transaction_id: p.orderId ?? null,
        last_notification_type: "PLAY_ONETIME",
        signed_date: new Date().toISOString(),
        raw: { play: p },
      };
    } else if (notif.voidedPurchaseNotification) {
      const vn = notif.voidedPurchaseNotification;
      row = {
        original_transaction_id: vn.purchaseToken,
        status: "refunded",
        revocation_date: new Date().toISOString(),
        last_notification_type: "PLAY_VOIDED",
        signed_date: new Date().toISOString(),
        raw: { voided: vn },
      };
      await alertFounder("🔴 Pick1 — refund/void (Android)", [["Order", String(vn.orderId ?? "—")]]);
    }

    if (row) {
      const upsertRow: Record<string, unknown> = { ...row };
      if (upsertRow.user_id == null) delete upsertRow.user_id;
      const { error } = await supabase.from("subscriptions").upsert(upsertRow, { onConflict: "original_transaction_id" });
      if (error) console.error("upsert failed:", error.message);
      else console.log(`stored ${row.last_notification_type} otxn=${row.original_transaction_id} status=${row.status}`);
    }
  } catch (e) {
    console.error("play-notifications:", (e as Error).message);
    // Return 200 anyway: Pub/Sub retries on non-2xx, and a transient Play API
    // blip shouldn't cause an infinite redelivery storm.
  }
  return new Response("OK", { status: 200 });
});
