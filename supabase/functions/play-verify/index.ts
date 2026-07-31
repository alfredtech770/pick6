// play-verify — validates a Google Play purchase token against the Play
// Developer API and writes the server-authoritative row into public.subscriptions
// (the same table the iOS apple-notifications webhook feeds).
//
// POST { userId?, productId, purchaseToken, isSub }
//   • isSub=true  → purchases.subscriptionsv2.get
//   • isSub=false → purchases.products.get (the 24h Day Pass)
//
// Auth model: the purchaseToken IS the proof (only the buyer's app holds it).
// user_id is taken from Play's obfuscatedExternalAccountId (which the client
// set = Supabase user id at purchase), falling back to the body userId — so a
// forged body can't grant entitlement to someone else.
//
// The Play API is reached with a service-account bearer (androidpublisher
// scope). Secret: PLAY_SERVICE_ACCOUNT (falls back to FCM_SERVICE_ACCOUNT —
// same GCP project pick1-7684d). The SA must be authorized in Play Console →
// Setup → API access with permission to view financial data / manage orders.
import { createClient } from "npm:@supabase/supabase-js@2";

const PACKAGE = "com.pick1.app";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SA_RAW = Deno.env.get("PLAY_SERVICE_ACCOUNT") ?? Deno.env.get("FCM_SERVICE_ACCOUNT");
const DAY_MS = 24 * 60 * 60 * 1000;

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
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
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
  if (!r.ok || !j.access_token) throw new Error(`play token ${r.status}: ${JSON.stringify(j).slice(0, 200)}`);
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

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Build a subscriptions row from a SubscriptionPurchaseV2 payload.
export function subRowFromV2(token: string, productIdHint: string | null, v2: any, notifType?: string) {
  const line = (v2.lineItems ?? [])[0] ?? {};
  const expiry = (v2.lineItems ?? [])
    .map((l: any) => l.expiryTime).filter(Boolean)
    .sort().pop() ?? null;
  const obf = v2.externalAccountIdentifiers?.obfuscatedExternalAccountId;
  const userId = obf && UUID_RE.test(obf) ? obf : null;
  const autoRenew = line.autoRenewingPlan?.autoRenewEnabled ?? null;
  const state = v2.subscriptionState as string | undefined;
  return {
    original_transaction_id: token,
    user_id: userId,
    product_id: line.productId ?? productIdHint ?? null,
    status: (state && SUB_STATE[state]) ?? "active",
    environment: v2.testPurchase ? "Sandbox" : "Production",
    auto_renew_status: typeof autoRenew === "boolean" ? autoRenew : null,
    auto_renew_product_id: line.productId ?? null,
    purchase_date: v2.startTime ?? null,
    expires_date: expiry,
    revocation_date: null as string | null,
    is_trial: !!line.offerDetails?.offerId?.toString().toLowerCase().includes("trial"),
    last_transaction_id: v2.latestOrderId ?? null,
    last_notification_type: notifType ?? "PLAY_VERIFY",
    signed_date: new Date().toISOString(),
    raw: { play: v2 },
  };
}

export function productRow(token: string, productId: string, p: any, notifType?: string) {
  const obf = p.obfuscatedExternalAccountId;
  const userId = obf && UUID_RE.test(obf) ? obf : null;
  const buyMs = p.purchaseTimeMillis ? Number(p.purchaseTimeMillis) : Date.now();
  const purchased = p.purchaseState === 0; // 0 = Purchased
  return {
    original_transaction_id: token,
    user_id: userId,
    product_id: productId,
    status: purchased ? "active" : "expired",
    environment: p.purchaseType === 0 ? "Sandbox" : "Production", // 0 = Test
    auto_renew_status: false,
    purchase_date: new Date(buyMs).toISOString(),
    expires_date: new Date(buyMs + DAY_MS).toISOString(), // Day Pass = 24h
    revocation_date: null as string | null,
    is_trial: false,
    last_transaction_id: p.orderId ?? null,
    last_notification_type: notifType ?? "PLAY_VERIFY_ONETIME",
    signed_date: new Date().toISOString(),
    raw: { play: p },
  };
}

export async function fetchSubscription(tok: string, token: string): Promise<any> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;
  const r = await fetch(url, { headers: { authorization: `Bearer ${tok}` } });
  const j = await r.json();
  if (!r.ok) throw new Error(`subv2 ${r.status}: ${JSON.stringify(j).slice(0, 200)}`);
  return j;
}
export async function fetchProduct(tok: string, productId: string, token: string): Promise<any> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}`;
  const r = await fetch(url, { headers: { authorization: `Bearer ${tok}` } });
  const j = await r.json();
  if (!r.ok) throw new Error(`product ${r.status}: ${JSON.stringify(j).slice(0, 200)}`);
  return j;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  if (!SA_RAW) return Response.json({ skipped: "PLAY_SERVICE_ACCOUNT not set" }, { status: 200 });

  let userId: string | undefined, productId: string | undefined, purchaseToken: string | undefined, isSub: boolean | undefined;
  try {
    ({ userId, productId, purchaseToken, isSub } = await req.json());
    if (!purchaseToken || !productId) throw new Error("need productId + purchaseToken");
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  let sa: SA;
  try { sa = JSON.parse(SA_RAW) as SA; } catch { return Response.json({ error: "bad SA json" }, { status: 500 }); }

  try {
    const tok = await playToken(sa);
    let row: Record<string, unknown>;
    if (isSub) {
      const v2 = await fetchSubscription(tok, purchaseToken);
      row = subRowFromV2(purchaseToken, productId ?? null, v2);
    } else {
      const p = await fetchProduct(tok, productId, purchaseToken);
      row = productRow(purchaseToken, productId, p);
    }
    // Trust Play's account id; fall back to the client-supplied one.
    if (!row.user_id && userId && UUID_RE.test(userId)) row.user_id = userId;

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, SERVICE_KEY);
    const upsertRow: Record<string, unknown> = { ...row };
    if (upsertRow.user_id == null) delete upsertRow.user_id;
    const { error } = await supabase.from("subscriptions").upsert(upsertRow, { onConflict: "original_transaction_id" });
    if (error) return Response.json({ error: error.message }, { status: 500 });

    return Response.json({ ok: true, status: row.status, expires: row.expires_date, user: row.user_id ?? null });
  } catch (e) {
    console.error("play-verify:", (e as Error).message);
    return Response.json({ error: (e as Error).message }, { status: 500 });
  }
});
