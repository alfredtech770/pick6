// Vercel scheduled function — fires daily at 09:00 ET (13:00 UTC during
// EDT — see vercel.json cron expression). Queries Supabase for today's
// highest-confidence pick written by the Railway pipeline, formats it
// into a branded email, and sends to the entire Pick1 waitlist via
// Brevo's email-campaigns API.
//
// Env vars expected on Vercel (all required):
//   SUPABASE_URL                  — e.g. https://jisbgspvllgwtfgoeihx.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY     — service-role JWT (NOT the anon key)
//                                   (read-only for picks table is enough; the
//                                   service-role key bypasses RLS the same way
//                                   the Railway pipeline does)
//   BREVO_API_KEY                 — already set; reused
//   BREVO_LIST_ID                 — numeric list id (default 3 = Pick1 Waitlist)
//   CRON_SECRET                   — random string; Vercel injects it as a Bearer
//                                   token in the cron-trigger header. Reject
//                                   requests without it so the endpoint can't
//                                   be invoked by random visitors.

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
  const BREVO_KEY   = process.env.BREVO_API_KEY;
  const LIST_ID     = parseInt(process.env.BREVO_LIST_ID || '3', 10);

  if (!SUPABASE_URL || !SUPABASE_KEY) {
    return res.status(500).json({ error: 'supabase_not_configured' });
  }
  if (!BREVO_KEY) {
    return res.status(500).json({ error: 'brevo_not_configured' });
  }

  try {
    // ── Fetch today's highest-confidence pick from Supabase ────────
    // The Railway pipeline writes picks with game_date = todayISO() at
    // ~05:00 ET. By 09:00 ET when this cron runs, today's row should
    // already be present. We fetch the single highest-probability pick
    // that hasn't been graded yet.
    const today = new Date().toISOString().slice(0, 10);

    const pickUrl = `${SUPABASE_URL}/rest/v1/picks`
      + `?game_date=eq.${today}`
      + `&result=eq.pending`
      + `&select=sport,league,home_team,away_team,pick,probability,confidence,reasoning,key_factor,game_date`
      + `&order=probability.desc`
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
      return res.status(200).json({ ok: true, skipped: 'no_picks_today', date: today });
    }

    const pick = picks[0];

    // ── Optional: yesterday's result for the receipts angle ──────
    // Surface the previous day's pick + outcome alongside today's
    // call. Builds trust and the "we publish wins AND misses" brand.
    const yesterday = new Date(Date.now() - 24 * 3600 * 1000).toISOString().slice(0, 10);
    let yesterdayPick = null;
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

    // ── Build email content ───────────────────────────────────────
    const subject = `Today's pick: ${pick.pick} (${pick.probability}% confidence)`;
    const previewText = `${pick.league} · ${pick.home_team} vs ${pick.away_team} · ${pick.key_factor || ''}`.slice(0, 140);
    const html = dailyEmailHtml({ pick, yesterdayPick, previewText });
    const text = dailyEmailText({ pick, yesterdayPick });

    // ── Send to the waitlist via Brevo email campaigns API ────────
    // Create + send-now in one shot. Brevo will send to every contact
    // on LIST_ID (the Pick1 Waitlist). Lifetime usage limits apply at
    // the account level but well above our pre-launch volume.
    const campaign = {
      name: `Daily AI Pick — ${today} — ${pick.league} ${pick.pick}`,
      subject,
      sender: { name: 'Pick1', email: 'admin@pick1.live' },
      type: 'classic',
      htmlContent: html,
      textContent: text,
      recipients: { listIds: [LIST_ID] },
      // Send immediately by setting scheduledAt to now + 1 minute. The
      // Brevo "sendNow" endpoint also works but requires a 2-step call.
      scheduledAt: new Date(Date.now() + 60 * 1000).toISOString(),
      tag: 'daily-pick',
    };

    const sendResp = await fetch('https://api.brevo.com/v3/emailCampaigns', {
      method: 'POST',
      headers: {
        'api-key': BREVO_KEY,
        accept: 'application/json',
        'content-type': 'application/json',
      },
      body: JSON.stringify(campaign),
    });

    if (!sendResp.ok) {
      const detail = await sendResp.text();
      console.error('brevo_campaign_error', sendResp.status, detail);
      return res.status(502).json({ error: 'brevo_send_failed', detail });
    }

    const result = await sendResp.json();
    console.log('daily-pick sent:', { campaignId: result.id, pick: pick.pick, prob: pick.probability });
    return res.status(200).json({
      ok: true,
      sent: { campaignId: result.id, league: pick.league, pick: pick.pick, probability: pick.probability },
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

      <tr><td style="padding:18px 4px 0 4px;font-size:12px;color:#666b73;line-height:1.6;">
        Every pick — wins <strong style="color:#9095a0;">and</strong> misses — gets logged publicly. Pick1's app launches end of May. Waitlist members get <strong style="color:#d4ff3a;">1 week free</strong>.<br/><br/>
        <strong style="color:#9095a0;">Pick1</strong> · pick1.live · <a href="{{ unsubscribe }}" style="color:#666b73;text-decoration:underline;">Unsubscribe</a>
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;
}
