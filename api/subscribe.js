// Vercel serverless function: proxy waitlist signups into Brevo,
// then fire a server-side Meta Conversions API "Lead" event so the
// Pixel attributes the conversion even when iOS / Safari kill the
// browser-side network call.
//
// Env vars expected:
//   BREVO_API_KEY            — secret Brevo API key
//   BREVO_LIST_ID            — numeric list id (default: 3 = Pick1 Waitlist)
//   META_PIXEL_ID            — Meta Pixel ID (also pasted into index.html meta tag)
//   META_CAPI_ACCESS_TOKEN   — Conversions API access token (Events Manager → Settings)
//   META_TEST_EVENT_CODE     — optional, only set while validating in Events Manager

const crypto = require('crypto');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  const apiKey = process.env.BREVO_API_KEY;
  const listId = parseInt(process.env.BREVO_LIST_ID || '3', 10);

  if (!apiKey) {
    return res.status(500).json({ error: 'server_misconfigured' });
  }

  // Vercel may not auto-parse JSON for some runtimes; handle both
  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch { body = {}; }
  }
  const {
    email,
    name,
    phone,
    eventId,
    fbp,
    fbc,
    utm,
    eventSourceUrl,
    userAgent,
  } = body || {};

  if (!email || typeof email !== 'string' || !email.includes('@')) {
    return res.status(400).json({ error: 'invalid_email' });
  }

  const attributes = {};
  if (name && typeof name === 'string') attributes.FIRSTNAME = name.trim().slice(0, 80);
  // Brevo's standard SMS attribute holds the E.164 phone number.
  // We use the same number for WhatsApp follow-up at launch.
  if (phone && typeof phone === 'string') {
    attributes.SMS = phone;
    attributes.WHATSAPP = phone;
  }
  // Persist UTM attribution on the contact so we can segment campaigns later.
  if (utm && typeof utm === 'object') {
    if (utm.utm_source)   attributes.UTM_SOURCE   = String(utm.utm_source).slice(0, 80);
    if (utm.utm_medium)   attributes.UTM_MEDIUM   = String(utm.utm_medium).slice(0, 80);
    if (utm.utm_campaign) attributes.UTM_CAMPAIGN = String(utm.utm_campaign).slice(0, 120);
    if (utm.utm_content)  attributes.UTM_CONTENT  = String(utm.utm_content).slice(0, 120);
    if (utm.utm_term)     attributes.UTM_TERM     = String(utm.utm_term).slice(0, 120);
  }

  try {
    const resp = await fetch('https://api.brevo.com/v3/contacts', {
      method: 'POST',
      headers: {
        'api-key': apiKey,
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        email,
        attributes,
        listIds: [listId],
        updateEnabled: true, // upsert: don't error on duplicate
      }),
    });

    // Brevo returns 201 (created) or 204 (updated). Both are success.
    if (resp.ok || resp.status === 204) {
      const clientIp = getClientIp(req);
      // Fire-and-forget welcome email + CAPI Lead event in parallel. We don't
      // block the user-facing response on either — the contact is already saved.
      sendWelcomeEmail({ email, name }).catch(err => {
        console.error('welcome_email_failed', err);
      });
      sendMetaLeadEvent({
        email, name, phone, eventId, fbp, fbc,
        eventSourceUrl, userAgent, clientIp,
      }).catch(err => {
        console.error('meta_capi_failed', err);
      });
      return res.status(200).json({ ok: true });
    }

    // Surface a generic message; log details server-side.
    const detail = await resp.text();
    console.error('brevo_error', resp.status, detail);
    return res.status(502).json({ error: 'upstream_error' });
  } catch (err) {
    console.error('brevo_fetch_error', err);
    return res.status(500).json({ error: 'fetch_failed' });
  }
};

// ── Meta Conversions API ──────────────────────────────────────────────────
// Server-side Lead event paired with the browser Pixel via shared eventId.
// Meta merges the two into a single conversion (no double counting). Hashed
// PII follows Meta's required SHA-256 + lowercase + trim normalization.

function getClientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (xff) return String(xff).split(',')[0].trim();
  return req.headers['x-real-ip'] || req.socket?.remoteAddress || '';
}

function sha256Hex(input) {
  return crypto.createHash('sha256').update(input).digest('hex');
}

function hashEmail(email) {
  return sha256Hex(String(email).trim().toLowerCase());
}

function hashPhone(phone) {
  // Meta wants digits only, no '+', for hashed phone (E.164 minus the plus).
  const digits = String(phone).replace(/\D+/g, '');
  if (!digits) return '';
  return sha256Hex(digits);
}

function hashName(name) {
  if (!name) return '';
  return sha256Hex(String(name).trim().toLowerCase());
}

async function sendMetaLeadEvent({
  email, name, phone, eventId, fbp, fbc,
  eventSourceUrl, userAgent, clientIp,
}) {
  const pixelId = process.env.META_PIXEL_ID;
  const token = process.env.META_CAPI_ACCESS_TOKEN;
  if (!pixelId || !token) return; // CAPI not configured — silently skip.

  const firstName = (name || '').trim().split(/\s+/)[0] || '';

  const userData = {
    em: [hashEmail(email)],
  };
  if (phone) userData.ph = [hashPhone(phone)];
  if (firstName) userData.fn = [hashName(firstName)];
  if (fbp) userData.fbp = fbp;
  if (fbc) userData.fbc = fbc;
  if (clientIp) userData.client_ip_address = clientIp;
  if (userAgent) userData.client_user_agent = userAgent;

  const payload = {
    data: [{
      event_name: 'Lead',
      event_time: Math.floor(Date.now() / 1000),
      event_id: eventId || `lead_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`,
      action_source: 'website',
      event_source_url: eventSourceUrl || 'https://pick1.live/',
      user_data: userData,
      custom_data: {
        content_name: 'Pick1 Waitlist',
        content_category: 'waitlist_signup',
      },
    }],
  };
  if (process.env.META_TEST_EVENT_CODE) {
    payload.test_event_code = process.env.META_TEST_EVENT_CODE;
  }

  const url = `https://graph.facebook.com/v19.0/${encodeURIComponent(pixelId)}/events?access_token=${encodeURIComponent(token)}`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });
  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`meta_capi_${resp.status}: ${detail}`);
  }
}

async function sendWelcomeEmail({ email, name }) {
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) return;

  const firstName = (name || '').trim().split(/\s+/)[0] || 'there';
  const safeName = escapeHtml(firstName).toUpperCase();

  const subject = "You're in. Tomorrow's AI pick lands at 9am ET.";
  const previewText = "Free, daily, publicly logged. Plus 1 week free when we launch end of May.";
  const html = welcomeEmailHtml({ name: safeName, previewText });
  const textBody = welcomeEmailText({ name: firstName });

  const resp = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': apiKey,
      'accept': 'application/json',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      sender: { name: 'Pick1', email: 'admin@pick1.live' },
      to: [{ email, name: name || undefined }],
      subject,
      htmlContent: html,
      textContent: textBody,
      tags: ['waitlist-welcome'],
    }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`brevo_smtp_${resp.status}: ${detail}`);
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

function welcomeEmailText({ name }) {
  return [
    `You're in, ${name}.`,
    '',
    "Your first AI pick lands tomorrow at 9am ET — Pick1's highest-confidence",
    'call across 9 sports, delivered to your inbox. Free, daily, publicly logged.',
    '',
    'What happens next:',
    "01. Tomorrow 9am ET: your first pick lands.",
    "02. Every morning: a new pick + yesterday's result (wins AND misses).",
    "03. End of May: app launches with unlimited picks + your 1 week free.",
    '',
    "While you're waiting:",
    '· Methodology: https://pick1.live/methodology',
    '· How we compare to Kalshi/Polymarket: https://pick1.live/blog/kalshi-polymarket-sports',
    '',
    '— Pick1',
    'pick1.live',
  ].join('\n');
}

function welcomeEmailHtml({ name, previewText }) {
  return `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>You're in. Tomorrow's AI pick lands at 9am ET.</title>
</head>
<body style="margin:0;padding:0;background:#0a0b0d;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#f6f7f8;-webkit-font-smoothing:antialiased;">
<div style="display:none;max-height:0;overflow:hidden;color:transparent;">${escapeHtml(previewText)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#0a0b0d;">
  <tr><td align="center" style="padding:40px 20px;">
    <table role="presentation" width="560" cellpadding="0" cellspacing="0" style="max-width:560px;width:100%;">
      <tr><td style="padding:0 0 28px 0;">
        <span style="font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:22px;letter-spacing:-0.02em;color:#fff;">PICK<span style="background:#d4ff3a;color:#0a0b0d;padding:1px 8px;border-radius:6px;margin-left:2px;">1</span></span>
      </td></tr>
      <tr><td style="background:#111317;border:1px solid #1a1d22;border-radius:18px;padding:36px 32px;">
        <div style="font-family:'JetBrains Mono','Courier New',monospace;font-size:11px;letter-spacing:0.18em;color:#d4ff3a;text-transform:uppercase;margin-bottom:14px;">● You're on the list</div>
        <h1 style="margin:0 0 14px 0;font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:38px;line-height:1.05;letter-spacing:-0.025em;color:#fff;">YOU'RE <span style="color:#d4ff3a;">IN</span>,<br/>${name}.</h1>
        <p style="margin:0 0 22px 0;font-size:15px;line-height:1.55;color:#b8bcc1;">Your first AI pick lands <strong style="color:#fff;">tomorrow at 9am ET</strong> — Pick1's highest-confidence call across 9 sports, delivered to your inbox. Free, daily, publicly logged. Plus 1 week of full access free when we launch end of May.</p>
        <div style="background:#d4ff3a;color:#0a0b0d;border-radius:14px;padding:18px 20px;margin:18px 0 26px 0;">
          <div style="font-family:'JetBrains Mono','Courier New',monospace;font-size:10px;letter-spacing:0.2em;text-transform:uppercase;font-weight:700;opacity:0.7;">📨 Starting tomorrow</div>
          <div style="font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:24px;letter-spacing:-0.02em;margin-top:4px;">DAILY AI PICK · 9AM ET</div>
          <div style="font-size:12px;opacity:0.85;margin-top:2px;">Free · No card · Unsubscribe anytime</div>
        </div>
        <h2 style="margin:28px 0 14px 0;font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:18px;letter-spacing:-0.01em;color:#fff;">WHAT HAPPENS NEXT.</h2>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          <tr><td valign="top" style="padding:8px 0;"><span style="font-family:'JetBrains Mono','Courier New',monospace;font-weight:700;color:#d4ff3a;font-size:13px;width:32px;display:inline-block;">01</span><strong style="color:#fff;font-size:14px;">Tomorrow 9am ET: your first pick lands</strong><div style="font-size:13px;color:#9095a0;margin-top:3px;">The model's highest-confidence call across 9 sports — NBA, NFL, EPL, MLB, UFC, NHL, F1, tennis, cricket.</div></td></tr>
          <tr><td valign="top" style="padding:8px 0;"><span style="font-family:'JetBrains Mono','Courier New',monospace;font-weight:700;color:#d4ff3a;font-size:13px;width:32px;display:inline-block;">02</span><strong style="color:#fff;font-size:14px;">Every morning: new pick + yesterday's result</strong><div style="font-size:13px;color:#9095a0;margin-top:3px;">Wins AND misses, publicly logged. Track the model in real time.</div></td></tr>
          <tr><td valign="top" style="padding:8px 0;"><span style="font-family:'JetBrains Mono','Courier New',monospace;font-weight:700;color:#d4ff3a;font-size:13px;width:32px;display:inline-block;">03</span><strong style="color:#fff;font-size:14px;">End of May: app launches + 1 week free</strong><div style="font-size:13px;color:#9095a0;margin-top:3px;">Unlimited picks across all 9 sports, live tracking, full ledger.</div></td></tr>
        </table>
        <div style="height:1px;background:#1a1d22;margin:28px 0 22px 0;"></div>
        <p style="margin:0;font-size:13px;color:#9095a0;line-height:1.55;">While you're waiting, see what we're building:</p>
        <ul style="margin:8px 0 0 0;padding-left:18px;font-size:13px;color:#b8bcc1;line-height:1.7;">
          <li><a href="https://pick1.live/methodology" style="color:#d4ff3a;text-decoration:none;">How the model is calibrated</a> (reliability diagrams + CLV)</li>
          <li><a href="https://pick1.live/blog/kalshi-polymarket-sports" style="color:#d4ff3a;text-decoration:none;">Why Kalshi/Polymarket don't work for sports</a></li>
        </ul>
      </td></tr>
      <tr><td style="padding:24px 4px 0 4px;font-size:12px;color:#666b73;line-height:1.6;">
        <strong style="color:#9095a0;">Pick1</strong> · AI sports prediction engine<br/>
        You're getting this because you joined the waitlist at pick1.live. <a href="{{ unsubscribe }}" style="color:#9095a0;text-decoration:underline;">Unsubscribe</a>.
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;
}
