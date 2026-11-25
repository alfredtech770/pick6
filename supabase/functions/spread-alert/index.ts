// spread-alert: Spread (spreadbets.xyz) tells a trader a pick was graded or their account moved.
// Spread has no app, so when the trader also uses PICK1 with the same email, the alert goes to their
// phone through send-push as a literal send with campaign "spread_bet" (a personal tier key there, so
// it never spends the daily pick budget). Anyone without a PICK1 account, or with Spread switched off
// in affiliate_partners (row 'spread'), gets nothing: Spread still shows the alert on its own site.
//
// POST { email, title, body, url }  with header x-spread-secret: SPREAD_ALERT_SECRET
import { createClient } from "jsr:@supabase/supabase-js@2";

const SECRET = Deno.env.get("SPREAD_ALERT_SECRET") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

function same(a: string, b: string) {
  if (!a || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("POST only", { status: 405 });
  if (!SECRET || !same(req.headers.get("x-spread-secret") ?? "", SECRET)) return new Response("unauthorized", { status: 401 });
  const { email, title, body, url } = await req.json().catch(() => ({}));
  if (typeof email !== "string" || typeof title !== "string" || typeof body !== "string") return Response.json({ error: "need email, title, body" }, { status: 400 });

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
  const { data: sw } = await supabase.from("affiliate_partners").select("enabled").eq("id", "spread").maybeSingle();
  if (sw && sw.enabled === false) return Response.json({ sent: 0, reason: "spread off" });
  const { data: uid, error } = await supabase.rpc("spread_alert_user", { p_email: email });
  if (error) return Response.json({ sent: 0, error: error.message }, { status: 500 });
  if (!uid) return Response.json({ sent: 0, reason: "no pick1 user" });

  const r = await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${SERVICE_KEY}` },
    body: JSON.stringify({
      title: `Spread: ${title}`.slice(0, 80), body: body.slice(0, 200), userIds: [uid], includeDormant: true,
      data: { campaign: "spread_bet", ...(typeof url === "string" && url.startsWith("https://spreadbets.xyz/") ? { url } : {}) },
    }),
  });
  const out = await r.json().catch(() => ({}));
  return Response.json({ sent: out.sent ?? 0, detail: out });
});
