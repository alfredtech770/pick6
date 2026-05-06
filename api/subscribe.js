// Vercel serverless function: proxy waitlist signups into Brevo.
// Front-end POSTs { email, name, phone } to /api/subscribe, this
// function calls Brevo with the secret API key (set in Vercel env vars).
//
// Env vars expected:
//   BREVO_API_KEY  — secret API key
//   BREVO_LIST_ID  — numeric list id (default: 3 = Pick1 Waitlist)

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
  const { email, name, phone } = body || {};

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
      // Fire-and-forget welcome email. Don't block the response on it —
      // if SMTP is slow or fails, the contact is still saved.
      sendWelcomeEmail({ email, name }).catch(err => {
        console.error('welcome_email_failed', err);
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

async function sendWelcomeEmail({ email, name }) {
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) return;

  const firstName = (name || '').trim().split(/\s+/)[0] || 'there';
  const safeName = escapeHtml(firstName).toUpperCase();

  const subject = "You're in. Your free week is locked.";
  const previewText = "Your code arrives via WhatsApp the moment Pick1 launches.";
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
    'Pick1 launches soon. When we go live, your first week is free —',
    "and we'll send your redemption code straight to your WhatsApp.",
    '',
    'What happens next:',
    '01. We finish the AI — final calibration across all 9 sports.',
    '02. Beta opens to first 100 — we WhatsApp you a head-start link.',
    '03. Public launch — your free-week code lands the same day.',
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
<title>You're in. Your free week is locked.</title>
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
        <p style="margin:0 0 22px 0;font-size:15px;line-height:1.55;color:#b8bcc1;">Pick1 launches soon. When we go live, your <strong style="color:#fff;">first week is free</strong> — and we'll send your redemption code straight to your WhatsApp.</p>
        <div style="background:#d4ff3a;color:#0a0b0d;border-radius:14px;padding:18px 20px;margin:18px 0 26px 0;">
          <div style="font-family:'JetBrains Mono','Courier New',monospace;font-size:10px;letter-spacing:0.2em;text-transform:uppercase;font-weight:700;opacity:0.7;">🎁 Your reward</div>
          <div style="font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:24px;letter-spacing:-0.02em;margin-top:4px;">7 DAYS FREE</div>
          <div style="font-size:12px;opacity:0.85;margin-top:2px;">Redeemable at launch via WhatsApp code</div>
        </div>
        <h2 style="margin:28px 0 14px 0;font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:18px;letter-spacing:-0.01em;color:#fff;">WHAT HAPPENS NEXT.</h2>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
          <tr><td valign="top" style="padding:8px 0;"><span style="font-family:'JetBrains Mono','Courier New',monospace;font-weight:700;color:#d4ff3a;font-size:13px;width:32px;display:inline-block;">01</span><strong style="color:#fff;font-size:14px;">We're finishing the AI</strong><div style="font-size:13px;color:#9095a0;margin-top:3px;">Final calibration across all 9 sports — NBA, NFL, EPL, MLB, UFC, NHL, F1, tennis, cricket.</div></td></tr>
          <tr><td valign="top" style="padding:8px 0;"><span style="font-family:'JetBrains Mono','Courier New',monospace;font-weight:700;color:#d4ff3a;font-size:13px;width:32px;display:inline-block;">02</span><strong style="color:#fff;font-size:14px;">Beta opens to first 100</strong><div style="font-size:13px;color:#9095a0;margin-top:3px;">A week before public launch — we'll WhatsApp you a head-start link.</div></td></tr>
          <tr><td valign="top" style="padding:8px 0;"><span style="font-family:'JetBrains Mono','Courier New',monospace;font-weight:700;color:#d4ff3a;font-size:13px;width:32px;display:inline-block;">03</span><strong style="color:#fff;font-size:14px;">Public launch</strong><div style="font-size:13px;color:#9095a0;margin-top:3px;">Your free-week code lands the same day. Use it across every sport.</div></td></tr>
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
