// GET /api/waitlist-count
//
// Public endpoint that returns the next waitlist position number — used
// by pick1.live to display "Be member #X" social proof above the signup
// form (replaces the originally planned Telegram channel member count).
//
// Why an endpoint instead of calling Supabase directly from the browser:
//   - Keeps the Supabase URL + service-role key server-side
//   - Lets us add edge-level caching (Vercel CDN, 30s) so a million page
//     loads don't slam Supabase
//   - Single place to change the floor/padding logic later
//
// The underlying SQL function `public.get_waitlist_count()` lives in
// pipeline/migrations/002_referrals.sql. It returns
// greatest(real_count + 1, 128) — so the displayed number is
// monotonically non-decreasing and never shows "you'd be #2" on a
// half-empty page.

module.exports = async (req, res) => {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    // Fail soft — frontend just won't show the badge.
    return res.status(200).json({ count: null });
  }

  try {
    const resp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_waitlist_count`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        'content-type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({}), // RPC has no params
    });

    if (!resp.ok) {
      console.error('waitlist_count_rpc_failed', resp.status, await resp.text());
      return res.status(200).json({ count: null });
    }

    // PostgREST returns scalar RPCs as either a bare number or a single-
    // element array depending on driver version — handle both.
    const data = await resp.json();
    const count = Array.isArray(data) ? data[0] : data;
    const num = parseInt(count, 10);
    if (!Number.isFinite(num) || num < 0) {
      return res.status(200).json({ count: null });
    }

    // Cache at the CDN edge for 30s. Page reloads within the window
    // don't re-hit Supabase. Stale-while-revalidate keeps the response
    // fast even when the cache is updating in the background.
    res.setHeader(
      'Cache-Control',
      'public, max-age=30, s-maxage=30, stale-while-revalidate=120'
    );
    return res.status(200).json({ count: num });
  } catch (err) {
    console.error('waitlist_count_fetch_error', err);
    return res.status(200).json({ count: null });
  }
};
