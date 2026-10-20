// pipeline-watchdog: tells Ethan when Pick1 has stopped producing picks.
//
// WHY. On 2026-10-17 at 11:48 UTC Railway stopped the pipeline container (the
// Hobby subscription lapsed) and nothing said so for three days: no new pick,
// pushes down from ~3,000 a day to 2, 84 paying users with a frozen board. The
// pipeline's own /healthz and its Resend alert both live INSIDE the thing that
// died, so they cannot report its death. This runs on Supabase, next to the
// data, and only asks one question: how old is the newest row in `picks`?
//
// WHEN. pg_cron calls it hourly (job pick1-pipeline-watchdog). It alerts when
// the newest pick is 26 hours old, then again every 12 hours while the outage
// lasts (26h, 38h, 50h ...), so a long outage is not one message that scrolls
// away.
//
// Why 26 and not 18: picks are written once a day by the 5am ET run (05:00 to
// about 06:40 ET), so the gap between the last pick of one run and the first
// of the next is ~22 hours on a HEALTHY day. Measured 20 Sep to 17 Oct: 23 of
// 27 nights had a gap over 18h. An 18h threshold would page Ethan every
// morning. 26h means "this morning's run produced nothing", about 08:40 ET.
//
// WHERE. An HQ inbox item (project pick1) when HQ_URL, HQ_ANON and HQ_KEY are
// set; HQ's own trigger forwards inbox items to Ethan's Telegram. If HQ is not
// configured or the write fails, one plain email via the existing Resend key
// to ALERT_EMAIL. Nothing is ever sent to users.
//
// POST {}                 normal hourly check
// POST { dryRun: true }   report age and what would happen; checks the HQ
//                         login works without writing anything
// POST { force: true }    ignore the 26h/12h slot (still needs a stale board)

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const HQ_URL = Deno.env.get("HQ_URL");
const HQ_ANON = Deno.env.get("HQ_ANON");
const HQ_KEY = Deno.env.get("HQ_KEY");
const HQ_USER = Deno.env.get("HQ_USER") ?? "hq-link@ethan-hq.app";
const RESEND_KEY = Deno.env.get("RESEND_API_KEY");
const ALERT_EMAIL = Deno.env.get("ALERT_EMAIL") ?? "ethan@milam.app";
const ALERT_FROM = Deno.env.get("ALERT_FROM") ?? "Pick1 Alerts <admin@pick1.live>";
const STALE_HOURS = Number(Deno.env.get("WATCHDOG_STALE_HOURS") ?? "26");
const REPEAT_HOURS = 12;

async function rest(path: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  if (!r.ok) throw new Error(`${path}: ${r.status} ${(await r.text()).slice(0, 200)}`);
  return r.json();
}

async function hqToken(): Promise<string> {
  const r = await fetch(`${HQ_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: HQ_ANON!, "Content-Type": "application/json" },
    body: JSON.stringify({ email: HQ_USER, password: HQ_KEY }),
  });
  if (!r.ok) throw new Error(`HQ login ${r.status}`);
  return (await r.json()).access_token;
}

async function hqInbox(id: string, data: Record<string, unknown>) {
  const tok = await hqToken();
  const r = await fetch(`${HQ_URL}/rest/v1/hq_docs?on_conflict=col,id`, {
    method: "POST",
    headers: {
      apikey: HQ_ANON!, Authorization: `Bearer ${tok}`, "Content-Type": "application/json",
      Prefer: "resolution=merge-duplicates",
    },
    body: JSON.stringify({ col: "inbox", id, data }),
  });
  if (!r.ok) throw new Error(`HQ write ${r.status}: ${(await r.text()).slice(0, 200)}`);
}

async function email(subject: string, text: string) {
  if (!RESEND_KEY) throw new Error("RESEND_API_KEY not set");
  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: ALERT_FROM, to: [ALERT_EMAIL], subject, text }),
  });
  if (!r.ok) throw new Error(`Resend ${r.status}: ${(await r.text()).slice(0, 200)}`);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });
  let dryRun = false, force = false;
  try { ({ dryRun = false, force = false } = (await req.json()) ?? {}); } catch { /* cron posts {} */ }

  try {
    const rows = await rest("picks?select=created_at,league&order=created_at.desc&limit=1");
    const last = rows?.[0]?.created_at as string | undefined;
    const ageH = last ? (Date.now() - Date.parse(last)) / 3600e3 : Infinity;
    const stale = ageH >= STALE_HOURS;
    const slot = Number.isFinite(ageH) && Math.floor(ageH) >= STALE_HOURS &&
      (Math.floor(ageH) - STALE_HOURS) % REPEAT_HOURS === 0;
    const report: Record<string, unknown> = {
      lastPick: last ?? null, ageHours: Number.isFinite(ageH) ? +ageH.toFixed(1) : null,
      stale, alertSlot: slot, hqConfigured: !!(HQ_URL && HQ_ANON && HQ_KEY), dryRun,
    };

    if (dryRun) {
      if (report.hqConfigured) {
        try { await hqToken(); report.hqLogin = "ok"; } catch (e) { report.hqLogin = String(e); }
      }
      return Response.json(report);
    }
    if (!stale || !(slot || force)) return Response.json({ ...report, alerted: false });

    const hours = Math.floor(ageH);
    const since = last ? new Date(last).toISOString().slice(0, 16).replace("T", " ") + " UTC" : "never";
    const title = `Pick1 has made no new pick for ${hours} hours`;
    const detail =
      `Last pick ${since}. Paying users see a frozen board and pick pushes stop with it. ` +
      `Check in this order: 1. Railway project reliable-flow, service worker: is a deployment running? ` +
      `(On 17 Oct the container was stopped because the Railway Hobby subscription lapsed.) ` +
      `2. Railway logs for "Claude cost ceiling" or "credit balance" (Anthropic credit or the CLAUDE_DAILY_COST_LIMIT_USD cap). ` +
      `3. Supabase project lgnjawngkiamlngcffrk is not paused for billing.`;

    const sent: string[] = [];
    const errors: string[] = [];
    if (report.hqConfigured) {
      try {
        // One inbox item per outage (keyed by the last pick's day), refreshed
        // on each repeat rather than stacking duplicates.
        const id = `pick1-no-picks-${(last ?? "never").slice(0, 10)}`;
        await hqInbox(id, {
          kind: "blocker", title, detail, status: "open", projectId: "pick1",
          source: "pick1-pipeline-watchdog", createdAt: Date.now(),
        });
        sent.push("hq");
      } catch (e) { errors.push(String(e)); }
    }
    if (!sent.length) {
      try { await email(`[Pick1] ${title}`, detail); sent.push("email"); }
      catch (e) { errors.push(String(e)); }
    }
    return Response.json({ ...report, alerted: sent.length > 0, via: sent, errors });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
