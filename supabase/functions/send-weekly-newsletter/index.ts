// Pick1 — weekly newsletter. Runs Mondays 15:00 UTC via pg_cron.
// Pulls the last 7 days + all-time record straight from the picks table,
// plus the top wins of the week, and sends to email_preferences.newsletter = true.
// Exactly-once per user per ISO week via email_log. Dormant until RESEND_API_KEY is set.
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const FROM = Deno.env.get("EMAIL_FROM") ?? "Pick1 <hello@pick1.live>";
const APP_URL = "https://pick1.live";

const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const esc = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

type PickRow = {
  league: string; game_date: string; home_team: string; away_team: string;
  pick: string; probability: number; result: string;
};

function isoWeek(d: Date): string {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const start = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((+t - +start) / 86400000 + 1) / 7);
  return `${t.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}
const matchup = (p: PickRow): string =>
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

function newsletterHtml(stats: {
  w7: number; l7: number; wAll: number; lAll: number;
  leagues: { league: string; w: number; l: number }[];
  topWins: PickRow[];
}, unsubUrl: string): string {
  const pct = (w: number, l: number) => (w + l ? Math.round((w / (w + l)) * 100) : 0);
  const stat = (label: string, value: string, sub: string) => `
    <td width="50%" bgcolor="#16181c" align="center" style="background-color:#16181c;border:1px solid #22252b;padding:18px 8px;">
      <div style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:34px;color:#d4ff3a;">${value}</div>
      <div style="font-family:Archivo,Arial,sans-serif;font-size:11px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;color:#b9b7b0;padding-top:6px;">${label}</div>
      <div style="font-family:Archivo,Arial,sans-serif;font-size:11px;color:#6e6f75;padding-top:2px;">${sub}</div>
    </td>`;
  const leagueRows = stats.leagues.map((r) => `<tr>
      <td style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:14px;color:#f5f3ee;padding:9px 0;border-bottom:1px solid #22252b;">${esc(r.league)}</td>
      <td align="right" style="font-family:Archivo,Arial,sans-serif;font-size:13px;font-weight:700;color:#b9b7b0;padding:9px 0;border-bottom:1px solid #22252b;">${r.w}&#8211;${r.l}</td>
      <td align="right" width="64" style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:15px;color:#d4ff3a;padding:9px 0;border-bottom:1px solid #22252b;">${pct(r.w, r.l)}%</td>
    </tr>`).join("");
  const winRows = stats.topWins.map((p) => `<tr>
      <td style="padding:8px 0;border-bottom:1px solid #22252b;">
        <span style="font-family:Archivo,Arial,sans-serif;font-size:13px;color:#b9b7b0;">${esc(matchup(p))}</span><br>
        <span style="font-family:Anton,'Arial Black',Impact,sans-serif;font-size:15px;color:#f5f3ee;text-transform:uppercase;">${esc(p.pick)}</span>
        <span style="font-family:Archivo,Arial,sans-serif;font-size:12px;font-weight:700;color:#4ade80;">&nbsp;&nbsp;WIN &middot; ${p.probability}%</span>
      </td>
    </tr>`).join("");
  return layout({
    preheader: `This week: ${stats.w7}-${stats.l7}. All-time: ${pct(stats.wAll, stats.lAll)}% win rate. Every result logged.`,
    badge: "WEEKLY RECAP",
    headlineTop: "THE LEDGER",
    headlineLime: "DOESN&#8217;T LIE.",
    bodyHtml: `
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:14px 0 0;"><tr>
        ${stat("THIS WEEK", `${stats.w7}&#8211;${stats.l7}`, `${pct(stats.w7, stats.l7)}% win rate`)}
        ${stat("ALL-TIME", `${pct(stats.wAll, stats.lAll)}%`, `${stats.wAll}&#8211;${stats.lAll} record`)}
      </tr></table>
      ${stats.leagues.length ? `<p style="margin:22px 0 4px;font-family:Archivo,Arial,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#d4ff3a;">BY LEAGUE</p>
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">${leagueRows}</table>` : ""}
      ${stats.topWins.length ? `<p style="margin:22px 0 4px;font-family:Archivo,Arial,sans-serif;font-size:13px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#d4ff3a;">WINS LOGGED THIS WEEK</p>
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">${winRows}</table>` : ""}`,
    cta: { label: "See Every Pick", url: APP_URL },
    footerExtra: ` <a href="${unsubUrl}" style="color:#6e6f75;text-decoration:underline;">Unsubscribe from the newsletter</a>.`,
  });
}

async function confirmedUsers(): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) throw error;
    for (const u of data.users) if (u.email && u.email_confirmed_at) out.set(u.id, u.email);
    if (data.users.length < 1000) break;
  }
  return out;
}

// PostgREST caps an unbounded select at 1000 rows. The settled-picks table
// and email_preferences (6,981 rows on 2026-09-17) are both past that, so
// each is read in pages; the original version would have computed the
// all-time record from the first thousand picks and mailed the first
// thousand people, reporting success either way.
const PAGE = 1000;
async function allPages<T>(build: (from: number, to: number) => any): Promise<T[]> {
  const out: T[] = [];
  for (let from = 0; ; from += PAGE) {
    const { data, error } = await build(from, from + PAGE - 1);
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
      return Response.json({ skipped: "RESEND_API_KEY not set; newsletter dormant" });
    }
    const now = new Date();
    const weekKey = isoWeek(now);
    const since = new Date(now.getTime() - 7 * 86400000).toISOString().slice(0, 10);

    const all = await allPages<PickRow>((from, to) => db.from("picks")
      .select("league, game_date, home_team, away_team, pick, probability, result")
      .in("result", ["win", "loss"])
      .order("game_date", { ascending: true }).order("id", { ascending: true })
      .range(from, to));
    if (all.length === 0) return Response.json({ skipped: "no settled picks yet" });

    const wAll = all.filter((p) => p.result === "win").length;
    const lAll = all.length - wAll;
    const last7 = all.filter((p) => p.game_date >= since);
    const w7 = last7.filter((p) => p.result === "win").length;
    const l7 = last7.length - w7;

    const byLeague = new Map<string, { w: number; l: number }>();
    for (const p of all) {
      const cur = byLeague.get(p.league) ?? { w: 0, l: 0 };
      p.result === "win" ? cur.w++ : cur.l++;
      byLeague.set(p.league, cur);
    }
    const leagues = [...byLeague.entries()]
      .map(([league, r]) => ({ league, ...r }))
      .sort((a, b) => b.w + b.l - (a.w + a.l))
      .slice(0, 5);
    const topWins = last7
      .filter((p) => p.result === "win")
      .sort((a, b) => b.probability - a.probability)
      .slice(0, 3);

    const prefs = await allPages<{ user_id: string; unsubscribe_token: string }>((from, to) =>
      db.from("email_preferences").select("user_id, unsubscribe_token").eq("newsletter", true)
        .order("user_id", { ascending: true }).range(from, to));
    if (prefs.length === 0) return Response.json({ skipped: "no newsletter subscribers" });

    const emails = await confirmedUsers();
    const withEmail = prefs.filter((p) => emails.has(p.user_id));
    const claimed = await claimAll(withEmail.map((p) => p.user_id), "newsletter", weekKey);
    const subject = last7.length ? `The week, logged: ${w7}-${l7}` : `Pick1 weekly: ${wAll}-${lAll} all-time`;
    const items: Outgoing[] = [];
    for (const pref of withEmail) {
      const logId = claimed.get(pref.user_id);
      if (!logId) continue; // already sent this week
      const unsubUrl = `${SUPABASE_URL}/functions/v1/email-unsubscribe?token=${pref.unsubscribe_token}&list=newsletter`;
      items.push({ logId, email: {
        from: FROM, to: [emails.get(pref.user_id)!], subject,
        html: newsletterHtml({ w7, l7, wAll, lAll, leagues, topWins }, unsubUrl),
        headers: { "List-Unsubscribe": `<${unsubUrl}>`, "List-Unsubscribe-Post": "List-Unsubscribe=One-Click" },
      } });
    }
    const { sent, failed } = await sendBatched(items);
    return Response.json({ sent, failed, week: weekKey, record7d: `${w7}-${l7}` });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
