// Vercel scheduled function — fires daily at 09:00 ET (13:00 UTC during
// EDT — see vercel.json cron expression). Queries Supabase for today's
// highest-confidence pick written by the Railway pipeline, formats it
// into a branded email, and sends to the entire Pick1 waitlist via
// Resend's Broadcasts API.
//
// Migrated from Brevo (suspended us) → Resend, which doesn't flag
// predictions/forecasting content via aggressive compliance bots.
//
// Env vars expected on Vercel (all required):
//   SUPABASE_URL                  — e.g. https://jisbgspvllgwtfgoeihx.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY     — service-role JWT (NOT the anon key)
//                                   (read-only for picks table is enough; the
//                                   service-role key bypasses RLS the same way
//                                   the Railway pipeline does)
//   RESEND_API_KEY                — Resend API key (re_xxx)
//   RESEND_AUDIENCE_ID            — uuid of the Pick1 Waitlist audience
//   RESEND_FROM                   — verified from address, default:
//                                   "Pick1 <admin@pick1.live>"
//   CRON_SECRET                   — random string; Vercel injects it as a Bearer
//                                   token in the cron-trigger header. Reject
//                                   requests without it so the endpoint can't
//                                   be invoked by random visitors.

const RESEND_API = 'https://api.resend.com';
const DEFAULT_FROM = 'Pick1 <admin@pick1.live>';

module.exports = async (req, res) => {
  // Vercel Cron sends `Authorization: Bearer <CRON_SECRET>` on scheduled
  // invocations. Allow manual invocation only when running locally.
  const expected = process.env.CRON_SECRET;
  const auth = req.headers.authorization || '';
  const isCronRequest = expected && auth === `Bearer ${expected}`;
  const isLocal = process.env.NODE_ENV === 'development' || process.env.VERCEL_ENV === 'development';
  if (!isCronRequest && !isLocal) {
    return res.status(401).json({ error: 'unauthorized' });
  }

  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const RESEND_KEY   = process.env.RESEND_API_KEY;
  const AUDIENCE_ID  = process.env.RESEND_AUDIENCE_ID;
  const FROM         = process.env.RESEND_FROM || DEFAULT_FROM;

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).json({ error: 'supabase_not_configured' });
  }
  if (!RESEND_KEY || !AUDIENCE_ID) {
    return res.status(500).json({ error: 'resend_not_configured' });
  }

  // ── Test / preview modes (manual invocation only) ─────────────────
  // ?test=1            — use a synthetic pick (skips Supabase entirely;
  //                      proves the Resend send works end-to-end)
  // ?latest=1          — fetch the most recent pending pick regardless
  //                      of date (useful before pipeline writes today's)
  // ?to=email@x.com    — send a single test email to a specific address
  //                      via /emails instead of the full broadcast (best
  //                      to validate before blasting the waitlist)
  const isTest   = req.query?.test === '1' || req.query?.test === 'true';
  const isLatest = req.query?.latest === '1' || req.query?.latest === 'true';
  const testTo   = req.query?.to || null;

  try {
    const today = new Date().toISOString().slice(0, 10);
    let pick;
    let yesterdayPick = null;

    if (isTest) {
      // ── Synthetic pick — validates Resend send without Supabase ─────
      pick = {
        sport: 'basketball',
        league: 'NBA',
        home_team: 'Celtics',
        away_team: 'Lakers',
        pick: 'Celtics −6.5',
        probability: 84,
        confidence: '***',
        reasoning: 'TEST SEND — synthetic pick to validate email infrastructure. The model has Boston winning by 7+ tonight based on rest, home advantage, and recent defensive efficiency. Replace with real Railway pipeline output in production.',
        key_factor: 'Test send — Boston rest advantage',
        game_date: today,
      };
    } else {
      // ── Fetch from Supabase ──────────────────────────────────────
      // Default: today's highest-confidence pending pick.
      // ?latest=1: most recent pending pick across all dates.
      const dateFilter = isLatest ? '' : `&game_date=eq.${today}`;
      const orderClause = isLatest
        ? '&order=game_date.desc,probability.desc'
        : '&order=probability.desc';

      const pickUrl = `${SUPABASE_URL}/rest/v1/picks`
        + `?result=eq.pending`
        + dateFilter
        + `&select=sport,league,home_team,away_team,pick,probability,confidence,reasoning,key_factor,game_date`
        + orderClause
        + `&limit=1`;

      const pickResp = await fetch(pickUrl, {
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
          Accept: 'application/json',
        },
      });

      if (!pickResp.ok) {
        const detail = await pickResp.text();
        console.error('supabase_fetch_error', pickResp.status, detail);
        return res.status(502).json({ error: 'supabase_fetch_failed', detail });
      }

      const picks = await pickResp.json();
      if (!Array.isArray(picks) || picks.length === 0) {
        console.log('daily-pick: no pending picks for', today, '— skipping send');
        return res.status(200).json({ ok: true, skipped: 'no_picks_today', date: today, mode: isLatest ? 'latest' : 'today' });
      }
      pick = picks[0];

      // ── Optional: yesterday's result for the receipts angle ──────
      // Surface the previous day's pick + outcome alongside today's
      // call. Builds trust and the "we publish wins AND misses" brand.
      const yesterday = new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
      try {
        const yUrl = `${SUPABASE_URL}/rest/v1/picks`
          + `?game_date=eq.${yesterday}`
          + `&result=in.(win,loss,push)`
          + `&select=league,home_team,away_team,pick,probability,result`
          + `&order=probability.desc`
          + `&limit=1`;
        const yResp = await fetch(yUrl, {
          headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}`, Accept: 'application/json' },
        });
        if (yResp.ok) {
          const yPicks = await yResp.json();
          if (yPicks.length) yesterdayPick = yPicks[0];
        }
      } catch (e) {
        // Non-fatal — just skip the yesterday section in the email.
        console.warn('yesterday_fetch_warn', e?.message);
      }
    }

    // ── Build email content ───────────────────────────────────────
    const subject = `Today's pick: ${pick.pick} (${pick.probability}% confidence)`;
    const previewText = `${pick.league} · ${pick.home_team} vs ${pick.away_team} · ${pick.key_factor || ''}`.slice(0, 140);
    const html = dailyEmailHtml({ pick, yesterdayPick, previewText });
    const text = dailyEmailText({ pick, yesterdayPick });

    // ── Send via Resend ────────────────────────────────────────────
    // Two modes:
    // (1) ?to=email@x.com — POST /emails (single recipient, transactional);
    //     ideal for validating the rendering before blasting the audience.
    // (2) default — POST /broadcasts (create draft) then POST /broadcasts/:id/send
    //     to fan out to the entire Pick1 Waitlist audience.
    let result, mode;
    if (testTo) {
      const r = await fetch(`${RESEND_API}/emails`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_KEY}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          from: FROM,
          to: [testTo],
          subject,
          html,
          text,
          tags: [{ name: 'category', value: 'daily_pick_test' }],
        }),
      });
      if (!r.ok) {
        const detail = await r.text();
        console.error('resend_emails_error', r.status, detail);
        return res.status(502).json({ error: 'resend_send_failed', detail });
      }
      result = await r.json();
      mode = 'emails_single';
    } else {
      // Step 1: create the broadcast as a draft.
      const createResp = await fetch(`${RESEND_API}/broadcasts`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_KEY}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          audience_id: AUDIENCE_ID,
          from: FROM,
          subject,
          html,
          text,
          name: `Daily AI Pick — ${today} — ${pick.league} ${pick.pick}`,
          preview_text: previewText,
        }),
      });
      if (!createResp.ok) {
        const detail = await createResp.text();
        console.error('resend_broadcast_create_error', createResp.status, detail);
        return res.status(502).json({ error: 'resend_send_failed', detail });
      }
      const created = await createResp.json();
      const broadcastId = created?.id;
      if (!broadcastId) {
        return res.status(502).json({ error: 'resend_broadcast_no_id', detail: created });
      }

      // Step 2: send the broadcast. Omitting scheduled_at = send immediately.
      const sendResp = await fetch(`${RESEND_API}/broadcasts/${broadcastId}/send`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_KEY}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({}),
      });
      if (!sendResp.ok) {
        const detail = await sendResp.text();
        console.error('resend_broadcast_send_error', sendResp.status, detail);
        return res.status(502).json({
          error: 'resend_send_failed',
          detail,
          broadcastId, // surface so we can manually retry from the dashboard
        });
      }
      result = { ...created, ...(await sendResp.json()) };
      mode = 'broadcast_audience';
    }

    console.log('daily-pick sent:', { mode, result, pick: pick.pick, prob: pick.probability });
    return res.status(200).json({
      ok: true,
      mode,
      isTest,
      sent: { ...result, league: pick.league, pick: pick.pick, probability: pick.probability },
    });
  } catch (err) {
    console.error('daily-pick_fatal', err);
    return res.status(500).json({ error: 'fatal', detail: err?.message });
  }
};

// ── Email templates ──────────────────────────────────────────────

function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function ringDashOffset(probability) {
  const r = 60;
  const circumference = 2 * Math.PI * r;
  const filled = (probability / 100) * circumference;
  return (circumference - filled).toFixed(1);
}

function dailyEmailText({ pick, yesterdayPick }) {
  const lines = [
    `Today's AI pick — ${pick.league}`,
    '',
    `${pick.pick}`,
    `${pick.home_team} vs ${pick.away_team}`,
    `${pick.probability}% confidence`,
    '',
    pick.key_factor ? `Why: ${pick.key_factor}` : '',
    '',
    pick.reasoning ? pick.reasoning : '',
    '',
  ];
  if (yesterdayPick) {
    lines.push('Yesterday\'s pick:');
    lines.push(`${yesterdayPick.pick} (${yesterdayPick.probability}%) — ${yesterdayPick.result.toUpperCase()}`);
    lines.push('');
  }
  lines.push('Every pick — wins and misses — gets logged publicly.');
  lines.push('Pick1 launches end of May. Waitlist members get 1 week free.');
  lines.push('');
  lines.push('— Pick1');
  lines.push('pick1.live');
  return lines.filter(Boolean).join('\n');
}

function dailyEmailHtml({ pick, yesterdayPick, previewText }) {
  const probability = Math.max(55, Math.min(97, parseInt(pick.probability, 10) || 70));
  const dashoffset = ringDashOffset(probability);
  const isWin = yesterdayPick && yesterdayPick.result === 'win';

  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Today's AI pick — ${escapeHtml(pick.league)}</title>
</head>
<body style="margin:0;padding:0;background:#0a0b0d;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#f6f7f8;-webkit-font-smoothing:antialiased;">
<div style="display:none;max-height:0;overflow:hidden;color:transparent;">${escapeHtml(previewText)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0a0b0d;">
  <tr><td align="center" style="padding:40px 20px;">
    <table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
      <tr><td style="padding:0 0 24px 0;">
        <span style="font-weight:900;font-size:22px;letter-spacing:-0.02em;color:#fff;">PICK<span style="background:#d4ff3a;color:#0a0b0d;padding:1px 8px;border-radius:6px;margin-left:2px;">1</span></span>
        <span style="float:right;font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.18em;color:#d4ff3a;text-transform:uppercase;font-weight:700;padding-top:10px;">TODAY'S TOP PICK</span>
      </td></tr>
      <tr><td style="background:#111317;border:1px solid #1a1d22;border-radius:18px;padding:32px 28px;">
        <div style="font-family:'Courier New',monospace;font-size:11px;letter-spacing:0.18em;color:#9095a0;text-transform:uppercase;margin-bottom:8px;">${escapeHtml(pick.league)} · ${escapeHtml(pick.sport)}</div>
        <h1 style="margin:0 0 4px 0;font-weight:900;font-size:32px;line-height:1.05;letter-spacing:-0.02em;color:#fff;">${escapeHtml(pick.pick)}</h1>
        <div style="font-size:14px;color:#9095a0;margin-bottom:24px;">${escapeHtml(pick.home_team)} vs ${escapeHtml(pick.away_team)}</div>

        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 18px 0;"><tr>
          <td valign="middle" style="width:120px;padding-right:18px;">
            <div style="position:relative;width:110px;height:110px;">
              <svg width="110" height="110" viewBox="0 0 140 140" xmlns="http://www.w3.org/2000/svg" style="transform:rotate(-90deg);">
                <circle cx="70" cy="70" r="60" stroke="rgba(255,255,255,0.08)" stroke-width="10" fill="none"/>
                <circle cx="70" cy="70" r="60" stroke="#d4ff3a" stroke-width="10" fill="none" stroke-linecap="round" stroke-dasharray="${(2*Math.PI*60).toFixed(1)}" stroke-dashoffset="${dashoffset}"/>
              </svg>
              <div style="position:absolute;top:0;left:0;width:110px;height:110px;display:flex;align-items:center;justify-content:center;flex-direction:column;">
                <div style="font-weight:900;font-size:30px;color:#fff;letter-spacing:-1px;line-height:1;">${probability}<span style="color:#d4ff3a;font-size:18px;">%</span></div>
              </div>
            </div>
          </td>
          <td valign="middle">
            <div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.2em;color:#9095a0;text-transform:uppercase;margin-bottom:4px;">AI confidence</div>
            <div style="font-size:14px;color:#b8bcc1;line-height:1.45;font-weight:500;">${escapeHtml(pick.key_factor || 'Highest-confidence call across today\'s slate.')}</div>
          </td>
        </tr></table>

        ${pick.reasoning ? `
        <div style="background:#0a0b0d;border:1px solid #1a1d22;border-radius:12px;padding:14px 16px;margin-top:14px;">
          <div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.2em;color:#9095a0;text-transform:uppercase;margin-bottom:6px;">Why</div>
          <div style="font-size:13px;line-height:1.55;color:#b8bcc1;">${escapeHtml(pick.reasoning)}</div>
        </div>
        ` : ''}

        ${yesterdayPick ? `
        <div style="margin-top:22px;padding-top:18px;border-top:1px solid #1a1d22;">
          <div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.2em;color:#9095a0;text-transform:uppercase;margin-bottom:6px;">Yesterday</div>
          <div style="font-size:14px;color:${isWin ? '#4ade80' : '#ff5a36'};font-weight:800;">
            ${isWin ? '✓ Correct' : (yesterdayPick.result === 'push' ? '↔ Push' : '✕ Missed')}
            <span style="color:#9095a0;font-weight:500;margin-left:8px;">${escapeHtml(yesterdayPick.pick)} (${yesterdayPick.probability}%)</span>
          </div>
        </div>
        ` : ''}
      </td></tr>

      <!-- Sweepstakes CTA — repeated in every daily-pick email until
           May 31 draw. Every subscriber sees it daily. Free distribution. -->
      <tr><td style="padding:18px 0 0 0;">
        <a href="https://gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro?utm_source=resend&utm_medium=daily_pick&utm_campaign=sweeps_launch" style="display:block;text-decoration:none;background:#0a0b0d;border:1.5px solid #d4ff3a;border-radius:12px;padding:14px 18px;">
          <div style="font-family:'Courier New',monospace;font-size:10px;letter-spacing:0.2em;text-transform:uppercase;font-weight:700;color:#d4ff3a;">🏆 Sweepstakes · ends May 31</div>
          <div style="font-weight:900;font-size:16px;letter-spacing:-0.01em;color:#fff;margin-top:4px;line-height:1.3;">Win 2 FIFA World Cup tickets + Lifetime Pro</div>
          <div style="font-size:11px;color:#b8bcc1;margin-top:4px;">$1,499 value · free to enter · <span style="color:#d4ff3a;text-decoration:underline;">enter →</span></div>
        </a>
      </td></tr>

      <tr><td style="padding:18px 4px 0 4px;font-size:12px;color:#666b73;line-height:1.6;">
        Every pick — wins <strong style="color:#9095a0;">and</strong> misses — gets logged publicly. Pick1's app launches end of May. Waitlist members get <strong style="color:#d4ff3a;">1 week free</strong>.<br/><br/>
        <strong style="color:#9095a0;">Pick1</strong> · pick1.live
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;
}
