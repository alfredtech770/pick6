// Pick1 — daily pick email. Runs once a day at 19:00 UTC via pg_cron
// (pipeline writes picks ~17:00-18:00 UTC). Picks THE one pick of the day
// (highest confidence, then highest probability) and sends it to everyone
// with email_preferences.daily_pick = true. Exactly-once per user per day
// via the email_log unique constraint. Dormant until RESEND_API_KEY is set.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const FROM = Deno.env.get("EMAIL_FROM") ?? "Pick1 <hello@pick1.live>";
const APP_URL = "https://pick1.live";

const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

type Pick1Row = {
  sport: string; league: string; game_date: string;
  home_team: string; away_team: string; pick: string;
  probability: number; confidence: string;
  reasoning: string | null; key_factor: string | null; odds: number | null;
};

const confRank = (c: string): number => {
  const k = (c ?? "").toLowerCase();
  if (k === "***" || k === "high") return 3;
  if (k === "**" || k === "medium") return 2;
  if (k === "*" || k === "low") return 1;
  return 0;
};
const confLabel = (c: string): string => {
  const r = confRank(c);
  return r === 3 ? "HIGH CONFIDENCE" : r === 2 ? "MEDIUM CONFIDENCE" : "LOW CONFIDENCE";
};
const matchup = (p: Pick1Row): string =>
  p.away_team && p.away_team.toLowerCase() !== "field"
    ? `${p.away_team} @ ${p.home_team}`
    : p.home_team;

function layout(o: {
  preheader: string; badge: string; headlineTop: string; headlineLime: string;
  bodyHtml: string; cta?: { label: string; url: string }; footerExtra?: string;
}): string {
  return `<!doctype html>
<html lang="en" dir="ltr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark only">
  <title>Pick1</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Anton&family=Archivo:wght@400;700&display=swap" rel="stylesheet">
</head>
<body style="margin:0;padding:0;background-color:#0a0b0d;" bgcolor="#0a0b0d">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;visibility:hidden;opacity:0;color:transparent;height:0;width:0;">${esc(o.preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#0a0b0d" style="background-color:#0a0b0d;">
    <tr><td align="center" style="padding:32px 16px 48px;">
      <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px;max-width:100%;">
        <tr><td style="padding:0 0 20px;">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
            <td style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:26px;letter-spacing:0.04em;color:#f5f3ee;padding-right:8px;">PICK</td>
            <td><table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
              <td bgcolor="#d4ff3a" align="center" valign="middle" style="background-color:#d4ff3a;width:30px;height:30px;border-radius:50%;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:18px;line-height:30px;color:#0a0b0d;mso-line-height-rule:exactly;">1</td>
            </tr></table></td>
          </tr></table>
        </td></tr>
        <tr><td bgcolor="#d4ff3a" style="background-color:#d4ff3a;height:4px;line-height:4px;font-size:4px;">&nbsp;</td></tr>
        <tr><td bgcolor="#101114" style="background-color:#101114;border:1px solid #22252b;border-top:0;padding:36px 32px;">
          <span style="display:inline-block;border:1px solid #d4ff3a;color:#d4ff3a;font-family:Archivo,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;padding:6px 12px;">${o.badge}</span>
          <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:42px;line-height:1.05;color:#f5f3ee;text-transform:uppercase;padding:22px 0 6px;">${o.headlineTop}<br><span style="color:#d4ff3a;">${o.headlineLime}</span></div>
          ${o.bodyHtml}
          ${o.cta ? `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:26px 0 4px;"><tr>
            <td bgcolor="#d4ff3a" style="background-color:#d4ff3a;border-radius:4px;">
              <a href="${o.cta.url}" style="display:inline-block;font-family:Anton,'Arial Black',Impact,sans-serif;font-size:17px;letter-spacing:0.06em;text-transform:uppercase;color:#0a0b0d;text-decoration:none;padding:14px 30px;">${o.cta.label}</a>
            </td></tr></table>` : ""}
        </td></tr>
        <tr><td style="padding:22px 8px 0;">
          <p style="margin:0;font-family:'Archivo Narrow','Arial Narrow',Arial,sans-serif;font-size:10px;font-weight:700;letter-spacing:0.22em;text-transform:uppercase;color:#6e6f75;">PICK<span style="color:#d4ff3a;">1</span>&nbsp;&middot;&nbsp;EVERY PICK, PUBLICLY LOGGED</p>
          <p style="margin:10px 0 0;font-family:Archivo,Arial,sans-serif;font-size:11px;line-height:1.6;color:#6e6f75;">AI predictions for information &amp; entertainment. Not betting advice.${o.footerExtra ?? ""}</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function dailyPickHtml(p: Pick1Row, unsubUrl: string): string {
  const game = esc(matchup(p));
  const reasoning = p.reasoning ? esc(p.reasoning.length > 320 ? p.reasoning.slice(0, 317) + "..." : p.reasoning) : null;
  return layout({
    preheader: `${matchup(p)}. Our pick: ${p.pick} (${p.probability}%).`,
    badge: `TODAY&#8217;S PICK &middot; ${esc(p.league)}`,
    headlineTop: "ONE PICK.",
    headlineLime: "TODAY.",
    bodyHtml: `
      <p style="margin:14px 0 14px;font-family:Archivo,Arial,sans-serif;font-size:15px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:#b9b7b0;">${game}</p>
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
        <td bgcolor="#16181c" align="center" style="background-color:#16181c;border:1px solid #d4ff3a;padding:22px 16px;">
          <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:32px;line-height:1.1;color:#d4ff3a;text-transform:uppercase;">${esc(p.pick)}</div>
          <div style="font-family:Archivo,Arial,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;color:#f5f3ee;padding-top:10px;">${p.probability}% PROBABILITY &middot; ${confLabel(p.confidence)}</div>
        </td>
      </tr></table>
      ${p.key_factor ? `<p style="margin:18px 0 0;font-family:Archivo,Arial,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#d4ff3a;">KEY FACTOR</p>
      <p style="margin:6px 0 0;font-family:Archivo,Arial,sans-serif;font-size:15px;line-height:1.7;color:#f5f3ee;">${esc(p.key_factor)}</p>` : ""}
      ${reasoning ? `<p style="margin:16px 0 0;font-family:Archivo,Arial,sans-serif;font-size:14px;line-height:1.7;color:#b9b7b0;">${reasoning}</p>` : ""}`,
    cta: { label: "View Full Analysis", url: APP_URL },
    footerExtra: ` <a href="${unsubUrl}" style="color:#6e6f75;text-decoration:underline;">Stop daily pick emails</a>.`,
  });
}

// A daily email is for people still using the product. Everyone confirmed
// gets the Monday newsletter; the daily pick goes only to accounts that
// signed in within ACTIVE_DAYS (1,791 of 7,369 on 2026-09-17). Mailing
// the other 5,500 dormant addresses every day would burn most of the
// Resend quota on people who left, and unopened mail plus complaints from
// them is exactly what gets a sending domain filtered for everyone else.
const ACTIVE_DAYS = Number(Deno.env.get("DAILY_PICK_ACTIVE_DAYS") ?? "30");

async function confirmedUsers(): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  const cutoff = Date.now() - ACTIVE_DAYS * 86400e3;
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    for (const u of data.users) {
      if (!u.email || !u.email_confirmed_at) continue;
      if (!u.last_sign_in_at || Date.parse(u.last_sign_in_at) < cutoff) continue;
      out.set(u.id, u.email);
    }
    if (data.users.length < 1000) break;
  }
  return out;
}

// email_preferences holds one row per confirmed user (6,981 on 2026-09-17,
// kept in step by the email_preferences_on_signup trigger). PostgREST caps
// an unbounded select at 1000 rows, so this reads in pages: the original
// version would have mailed the first thousand people and reported success.
const PAGE = 1000;
async function subscribers(flag: string): Promise<{ user_id: string; unsubscribe_token: string }[]> {
  const out: { user_id: string; unsubscribe_token: string }[] = [];
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await db.from("email_preferences")
      .select("user_id, unsubscribe_token").eq(flag, true)
      .order("user_id", { ascending: true }).range(from, from + PAGE - 1);
    if (error) throw error;
    out.push(...(data ?? []));
    if (!data || data.length < PAGE) break;
  }
  return out;
}


// ── Delivery ──────────────────────────────────────────────────────────────
//
// One HTTP request per email was fine for seven subscribers and is not for
// seven thousand: at the ~3 sends a second Resend answered on 2026-09-17,
// a full run needs 40 minutes and an edge function is stopped at 400s, so
// the same first few hundred people (by user_id) would get every mailing
// and nobody else ever would. Resend's batch endpoint takes 100 emails per
// call, and the email_log claim is done 500 users at a time, so a run is
// ~150 requests and about a minute. The claim stays exactly-once: rows
// already present for (user, type, key) are skipped by the upsert.
const CLAIM = 500;
const BATCH = 100;

async function claimAll(userIds: string[], emailType: string, dedupeKey: string): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  for (let i = 0; i < userIds.length; i += CLAIM) {
    const rows = userIds.slice(i, i + CLAIM).map((user_id) => ({ user_id, email_type: emailType, dedupe_key: dedupeKey, status: "pending" }));
    const { data, error } = await db.from("email_log")
      .upsert(rows, { onConflict: "user_id,email_type,dedupe_key", ignoreDuplicates: true })
      .select("id, user_id");
    if (error) throw error;
    for (const r of data ?? []) out.set(r.user_id, r.id);
  }
  return out;
}

type Outgoing = { logId: string; email: { from: string; to: string[]; subject: string; html: string; headers: Record<string, string> } };

async function sendBatched(items: Outgoing[]): Promise<{ sent: number; failed: number }> {
  let sent = 0, failed = 0;
  for (let i = 0; i < items.length; i += BATCH) {
    const chunk = items.slice(i, i + BATCH);
    const ids = chunk.map((c) => c.logId);
    try {
      // Resend allows 2 requests a second per account. Every batch call is
      // spaced out, and a 429 is retried once after backing off, because a
      // failed batch marks a hundred people as failed for the day.
      let r: Response | null = null;
      for (let attempt = 0; attempt < 3; attempt++) {
        if (i > 0 || attempt > 0) await new Promise((res) => setTimeout(res, attempt ? 2000 : 600));
        r = await fetch("https://api.resend.com/emails/batch", {
          method: "POST",
          headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
          body: JSON.stringify(chunk.map((c) => c.email)),
        });
        if (r.status !== 429) break;
      }
      if (!r || !r.ok) throw new Error(`Resend ${r?.status}: ${r ? (await r.text()).slice(0, 300) : "no response"}`);
      await db.from("email_log").update({ status: "sent", sent_at: new Date().toISOString() }).in("id", ids);
      sent += chunk.length;
    } catch (e) {
      await db.from("email_log").update({ status: "failed", error: String(e).slice(0, 500) }).in("id", ids);
      failed += chunk.length;
    }
  }
  return { sent, failed };
}

Deno.serve(async (_req: Request) => {
  try {
    if (!RESEND_KEY) {
      return Response.json({ skipped: "RESEND_API_KEY not set; daily pick emails dormant" });
    }
    const today = new Date().toISOString().slice(0, 10);
    const { data: picks, error: pickErr } = await db.from("picks")
      .select("sport, league, game_date, home_team, away_team, pick, probability, confidence, reasoning, key_factor, odds")
      .eq("game_date", today);
    if (pickErr) throw pickErr;
    if (!picks || picks.length === 0) return Response.json({ skipped: `no picks for ${today}` });

    const top = (picks as Pick1Row[]).sort(
      (a, b) => confRank(b.confidence) - confRank(a.confidence) || b.probability - a.probability,
    )[0];

    const prefs = await subscribers("daily_pick");
    if (prefs.length === 0) return Response.json({ skipped: "no daily_pick subscribers" });

    const emails = await confirmedUsers();
    const withEmail = prefs.filter((p) => emails.has(p.user_id));
    const claimed = await claimAll(withEmail.map((p) => p.user_id), "daily_pick", today);
    const items: Outgoing[] = [];
    for (const pref of withEmail) {
      const logId = claimed.get(pref.user_id);
      if (!logId) continue; // already sent today
      const unsubUrl = `${SUPABASE_URL}/functions/v1/email-unsubscribe?token=${pref.unsubscribe_token}&list=daily_pick`;
      items.push({ logId, email: {
        from: FROM, to: [emails.get(pref.user_id)!],
        subject: `Today's Pick: ${top.pick} (${top.probability}%)`,
        html: dailyPickHtml(top, unsubUrl),
        headers: { "List-Unsubscribe": `<${unsubUrl}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" },
      } });
    }
    const { sent, failed } = await sendBatched(items);
    return Response.json({ sent, failed, pick: `${top.league}: ${top.pick}` });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
