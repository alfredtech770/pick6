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
