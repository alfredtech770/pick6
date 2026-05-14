// Vercel serverless function: proxy waitlist signups into Resend,
// then fire a server-side Meta Conversions API "Lead" event so the
// Pixel attributes the conversion even when iOS / Safari kill the
// browser-side network call.
//
// Resend was chosen over Brevo (which suspended us with no warning)
// because their AUP doesn't flag predictions/forecasting content,
// they have first-class Audiences + Broadcasts APIs, and the migration
// is essentially endpoint-for-endpoint.
//
// Env vars expected:
//   RESEND_API_KEY            — secret Resend API key (re_xxx)
//   RESEND_AUDIENCE_ID        — uuid of the Pick1 Waitlist audience
//   RESEND_FROM               — verified from address, default:
//                               "Pick1 <admin@pick1.live>"
//   META_PIXEL_ID             — Meta Pixel ID (also pasted into index.html meta tag)
//   META_CAPI_ACCESS_TOKEN    — Conversions API access token (Events Manager → Settings)
//   META_TEST_EVENT_CODE      — optional, only set while validating in Events Manager

const crypto = require('crypto');

const RESEND_API = 'https://api.resend.com';
const DEFAULT_FROM = 'Pick1 <admin@pick1.live>';

// ─── In-memory rate limiter ──────────────────────────────────────────
// Simple sliding-window per-IP cap. Vercel keeps the function warm for
// some minutes between invocations, which is good enough to throttle
// scripted floods. Real production hardening should add a Redis/Upstash
// store so multiple cold lambdas share a counter — file this as v2.
const RATE_LIMIT_WINDOW_MS = 60_000;   // 1 minute
const RATE_LIMIT_MAX       = 5;        // 5 signups per IP per minute
const rateLog = new Map();             // ip → [timestamps]

function rateLimitExceeded(ip) {
  if (!ip) return false;               // unknown IP → don't block
  const now = Date.now();
  const window = (rateLog.get(ip) || []).filter(t => now - t < RATE_LIMIT_WINDOW_MS);
  if (window.length >= RATE_LIMIT_MAX) {
    rateLog.set(ip, window);
    return true;
  }
  window.push(now);
  rateLog.set(ip, window);
  // Cheap GC: keep the map from growing unbounded across cold starts.
  if (rateLog.size > 5000) {
    const cutoff = now - RATE_LIMIT_WINDOW_MS;
    for (const [k, v] of rateLog.entries()) {
      const fresh = v.filter(t => t >= cutoff);
      if (fresh.length === 0) rateLog.delete(k);
      else rateLog.set(k, fresh);
    }
  }
  return false;
}

// Allowlist for the public Origin header. Anything else is rejected to
// stop scripted abuse from arbitrary domains (the rate limiter still
// catches direct curl traffic). Keep this in sync with the actual
// hosting domains.
const ALLOWED_ORIGINS = new Set([
  'https://pick1.live',
  'https://www.pick1.live',
  'https://pick1.app',
  'https://www.pick1.app',
]);

function isAllowedOrigin(origin) {
  if (!origin) return true;            // curl / native fetch has no origin → defer to rate limit
  try {
    return ALLOWED_ORIGINS.has(new URL(origin).origin);
  } catch {
    return false;
  }
}

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  const apiKey = process.env.RESEND_API_KEY;
  const audienceId = process.env.RESEND_AUDIENCE_ID;

  if (!apiKey || !audienceId) {
    return res.status(500).json({ error: 'server_misconfigured' });
  }

  // ── Origin check ────────────────────────────────────────────────
  const origin = req.headers.origin || req.headers.referer;
  if (!isAllowedOrigin(origin)) {
    return res.status(403).json({ error: 'forbidden_origin' });
  }

  // ── Rate limit ──────────────────────────────────────────────────
  const clientIp = getClientIp(req);
  if (rateLimitExceeded(clientIp)) {
    res.setHeader('Retry-After', '60');
    return res.status(429).json({ error: 'too_many_requests' });
  }

  // ── Content-Length cap ──────────────────────────────────────────
  // Anything bigger than 2 KB is abuse — legit payloads are <500B.
  const contentLength = parseInt(req.headers['content-length'] || '0', 10);
  if (contentLength > 2048) {
    return res.status(413).json({ error: 'payload_too_large' });
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
    // Referral code captured from `?r=<code>` on the landing page. The
    // frontend stuffs it into a hidden field on the signup form, so it
    // travels with the POST even if the user navigates between page
    // sections before submitting.
    ref,
  } = body || {};

  // Email: must be a sane shape (RFC-light, not a regex novel).
  if (!email
      || typeof email !== 'string'
      || email.length > 254
      || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'invalid_email' });
  }
  // Name and phone are optional but if present must be strings and bounded.
  if (name  && (typeof name  !== 'string' || name.length  > 120)) {
    return res.status(400).json({ error: 'invalid_name' });
  }
  if (phone && (typeof phone !== 'string' || phone.length > 32))  {
    return res.status(400).json({ error: 'invalid_phone' });
  }

  // Split full name into first/last for Resend's audience schema.
  // Resend doesn't have a "custom attributes" surface like Brevo — UTM /
  // phone are stashed in a separate Supabase contacts table downstream
  // (or, for now, captured only via the Meta CAPI payload below).
  const fullName = (name || '').trim();
  const firstName = fullName.split(/\s+/)[0] || '';
  const lastName  = fullName.split(/\s+/).slice(1).join(' ') || '';

  try {
    // ── Upsert contact into Resend audience ─────────────────────────
    // Resend's POST /audiences/:id/contacts creates the contact. If the
    // email already exists in the audience the API returns 422 with an
    // "already exists" error — we treat that as success since the user
    // is already on the list.
    const createResp = await fetch(`${RESEND_API}/audiences/${audienceId}/contacts`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        email,
        first_name: firstName || undefined,
        last_name:  lastName  || undefined,
        unsubscribed: false,
      }),
    });

    // 200/201 = created. 422 with "already exists" message = upsert hit
    // existing row; that's still success from the user's POV.
    let upserted = false;
    if (createResp.ok) {
      upserted = true;
    } else {
      const detail = await createResp.text();
      const alreadyExists =
        createResp.status === 422 &&
        /already exists|duplicate/i.test(detail);
      if (alreadyExists) {
        upserted = true;
        console.log('resend_contact_existing', email);
      } else {
        console.error('resend_contact_error', createResp.status, detail);
        return res.status(502).json({ error: 'upstream_error' });
      }
    }

    if (upserted) {
      // clientIp is already captured at the top of the handler for rate
      // limiting — reuse it for the CAPI Lead event (Meta uses IP for the
      // user_data fingerprint).
      const firstName = (name || '').trim().split(/\s+/)[0] || null;

      // Get the waitlist position + referral code FIRST (synchronously),
      // because the welcome email + thanks page redirect both need to
      // include them. Failure here degrades to "no referral mechanic"
      // but the user is still on the list (Resend + Meta CAPI already ran).
      let referral = null;
      try {
        referral = await upsertWaitlistSignup({
          email, firstName, ref, phone, utm, fbp, fbc,
        });
      } catch (err) {
        console.error('waitlist_rpc_failed', err);
        // Non-fatal — keep going so the user still sees a confirmation.
      }

      // Fire-and-forget welcome email + CAPI Lead event in parallel.
      // We don't block the user-facing response on either — the contact
      // is already saved.
      sendWelcomeEmail({ email, name, referral }).catch(err => {
        console.error('welcome_email_failed', err);
      });
      sendMetaLeadEvent({
        email, name, phone, eventId, fbp, fbc,
        eventSourceUrl, userAgent, clientIp,
      }).catch(err => {
        console.error('meta_capi_failed', err);
      });
      return res.status(200).json({
        ok: true,
        // The SQL proc returns columns prefixed with `out_` because the
        // RETURNS TABLE param names would otherwise collide with the
        // `referral_code` column inside the proc body (ambiguity error)
        // and `position` is a Postgres reserved keyword in this context.
        // The browser-facing API normalizes to clean names here.
        position: referral?.out_queue_position ?? null,
        referralCode: referral?.out_referral_code ?? null,
        isNew: referral?.out_is_new ?? null,
      });
    }
  } catch (err) {
    console.error('resend_fetch_error', err);
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

// ── Waitlist signup RPC (Supabase) ───────────────────────────────────────
// Calls the `upsert_waitlist_signup` stored proc from pipeline/migrations/
// 002_referrals.sql. The proc:
//   1. Returns the existing row if the email is already on the list
//      (idempotent — no double-crediting of referrers).
//   2. Generates a unique `referral_code` of the form "firstname-abcd".
//   3. Atomically assigns a `position` via the `waitlist_position_seq`
//      Postgres sequence (no race conditions under concurrent signups).
//   4. If `ref` was provided, increments the referrer's referrals_count and
//      lifts their position by 100 (POSITION_JUMP_PER_REFERRAL inside the
//      proc).
// Returns: { email, referral_code, position, is_new } or null on failure.
async function upsertWaitlistSignup({
  email, firstName, ref, phone, utm, fbp, fbc,
}) {
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!SUPABASE_URL || !SUPABASE_KEY) return null;

  // Build the UTM jsonb payload only with the keys we care about + sane
  // length limits. Pass null if there's nothing — PostgREST handles it.
  let utmPayload = null;
  if (utm && typeof utm === 'object') {
    const u = {};
    if (utm.utm_source)   u.utm_source   = String(utm.utm_source).slice(0, 80);
    if (utm.utm_medium)   u.utm_medium   = String(utm.utm_medium).slice(0, 80);
    if (utm.utm_campaign) u.utm_campaign = String(utm.utm_campaign).slice(0, 120);
    if (utm.utm_content)  u.utm_content  = String(utm.utm_content).slice(0, 120);
    if (utm.utm_term)     u.utm_term     = String(utm.utm_term).slice(0, 120);
    if (Object.keys(u).length) utmPayload = u;
  }

  const resp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/upsert_waitlist_signup`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: `Bearer ${SUPABASE_KEY}`,
      'content-type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      p_email:            email,
      p_first_name:       firstName || null,
      p_referred_by_code: ref || null,
      p_phone:            phone || null,
      p_utm:              utmPayload,
      p_fbp:              fbp || null,
      p_fbc:              fbc || null,
    }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`supabase_rpc_${resp.status}: ${detail}`);
  }

  // PostgREST returns TABLE-returning RPCs as a JSON array. We expect
  // exactly one row.
  const rows = await resp.json();
  if (!Array.isArray(rows) || rows.length === 0) return null;
  return rows[0]; // { email, referral_code, position, is_new }
}

async function sendWelcomeEmail({ email, name, referral }) {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) return;

  const from = process.env.RESEND_FROM || DEFAULT_FROM;
  const firstName = (name || '').trim().split(/\s+/)[0] || 'there';
  const safeName = escapeHtml(firstName).toUpperCase();

  const subject = "You're in. Tomorrow's AI pick lands at 9am ET.";
  const previewText = "Free, daily, publicly logged. Plus 1 week free when we launch end of May.";
  const html = welcomeEmailHtml({ name: safeName, previewText, referral });
  const textBody = welcomeEmailText({ name: firstName, referral });

  const resp = await fetch(`${RESEND_API}/emails`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject,
      html,
      text: textBody,
      // Resend tags — used for downstream filtering in their dashboard.
      tags: [{ name: 'category', value: 'waitlist_welcome' }],
    }),
  });

  if (!resp.ok) {
    const detail = await resp.text();
    throw new Error(`resend_emails_${resp.status}: ${detail}`);
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, c => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

function welcomeEmailText({ name, referral }) {
  const lines = [
    `You're in, ${name}.`,
    '',
  ];
  if (referral?.position) {
    lines.push(`You're #${referral.position} on the waitlist.`);
    lines.push('');
  }
  lines.push("Your first AI pick lands tomorrow at 9am ET — Pick1's highest-confidence");
  lines.push('call across 9 sports, delivered to your inbox. Free, daily, publicly logged.');
  lines.push('');
  if (referral?.referral_code) {
    lines.push('JUMP THE QUEUE:');
    lines.push('Every friend who signs up via your link moves you up 100 spots.');
    lines.push(`· 3 referrals → 1 month free Pro at launch`);
    lines.push(`· 10 referrals → 1 year free Pro`);
    lines.push(`· 25 referrals → lifetime Pro`);
    lines.push('');
    lines.push(`Your link: https://pick1.live/?r=${referral.referral_code}`);
    lines.push('');
  }
  lines.push('What happens next:');
  lines.push("01. Tomorrow 9am ET: your first pick lands.");
  lines.push("02. Every morning: a new pick + yesterday's result (wins AND misses).");
  lines.push("03. End of May: app launches with unlimited picks + your 1 week free.");
  lines.push('');
  lines.push("While you're waiting:");
  lines.push('· Methodology: https://pick1.live/methodology');
  lines.push('· How we compare to Kalshi/Polymarket: https://pick1.live/blog/kalshi-polymarket-sports');
  lines.push('');
  lines.push('— Pick1');
  lines.push('pick1.live');
  return lines.join('\n');
}

function welcomeEmailHtml({ name, previewText, referral }) {
  const positionBlock = referral?.position
    ? `<div style="background:#0a0b0d;border:1px solid #1a1d22;border-radius:12px;padding:16px 20px;margin:0 0 22px 0;text-align:center;">
        <div style="font-family:'JetBrains Mono','Courier New',monospace;font-size:10px;letter-spacing:0.2em;color:#9095a0;text-transform:uppercase;margin-bottom:4px;">Your position</div>
        <div style="font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:32px;color:#d4ff3a;letter-spacing:-0.02em;line-height:1;">#${referral.position}</div>
      </div>`
    : '';
  const referralBlock = referral?.referral_code
    ? `<div style="border:1px solid #d4ff3a;border-radius:14px;padding:18px 20px;margin:18px 0 26px 0;">
        <div style="font-family:'JetBrains Mono','Courier New',monospace;font-size:10px;letter-spacing:0.2em;text-transform:uppercase;font-weight:700;color:#d4ff3a;margin-bottom:6px;">⚡ Jump the queue</div>
        <div style="font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:18px;letter-spacing:-0.01em;margin-bottom:8px;color:#fff;">Every friend = +100 spots</div>
        <div style="font-size:13px;color:#b8bcc1;line-height:1.55;margin-bottom:12px;">
          <strong style="color:#fff;">3 referrals</strong> → 1 month free Pro<br/>
          <strong style="color:#fff;">10 referrals</strong> → 1 year free Pro<br/>
          <strong style="color:#fff;">25 referrals</strong> → lifetime Pro
        </div>
        <div style="background:#0a0b0d;border:1px solid #1a1d22;border-radius:10px;padding:12px 14px;font-family:'JetBrains Mono','Courier New',monospace;font-size:12px;color:#d4ff3a;word-break:break-all;">
          https://pick1.live/?r=${escapeHtml(referral.referral_code)}
        </div>
      </div>`
    : '';

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
        ${positionBlock}
        <div style="background:#d4ff3a;color:#0a0b0d;border-radius:14px;padding:18px 20px;margin:18px 0 18px 0;">
          <div style="font-family:'JetBrains Mono','Courier New',monospace;font-size:10px;letter-spacing:0.2em;text-transform:uppercase;font-weight:700;opacity:0.7;">📨 Starting tomorrow</div>
          <div style="font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:24px;letter-spacing:-0.02em;margin-top:4px;">DAILY AI PICK · 9AM ET</div>
          <div style="font-size:12px;opacity:0.85;margin-top:2px;">Free · No card · Unsubscribe anytime</div>
        </div>
        <!-- Launch sweepstakes CTA — bonus prize hook for every new signup.
             Embedded directly in the welcome flow so it's the second thing
             they see after "you're in". Free distribution at scale. -->
        <a href="https://gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro?utm_source=resend&utm_medium=welcome_email&utm_campaign=sweeps_launch" style="display:block;text-decoration:none;background:#0a0b0d;border:1.5px solid #d4ff3a;border-radius:14px;padding:18px 20px;margin:0 0 26px 0;">
          <div style="font-family:'JetBrains Mono','Courier New',monospace;font-size:10px;letter-spacing:0.2em;text-transform:uppercase;font-weight:700;color:#d4ff3a;">🏆 Launch sweepstakes · ends May 31</div>
          <div style="font-family:'Archivo','Helvetica Neue',Arial,sans-serif;font-weight:900;font-size:20px;letter-spacing:-0.02em;color:#fff;margin-top:6px;line-height:1.2;">Win 2 <span style="color:#d4ff3a;">FIFA World Cup</span> tickets<br/>+ Lifetime Pick1 Pro</div>
          <div style="font-size:12px;color:#b8bcc1;margin-top:6px;line-height:1.5;">$1,499 value · free to enter · drawn live May 31.<br/><span style="color:#d4ff3a;text-decoration:underline;">Enter the sweepstakes →</span></div>
        </a>
        ${referralBlock}
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
        You're getting this because you joined the waitlist at pick1.live.
      </td></tr>
    </table>
  </td></tr>
</table>
</body></html>`;
}
