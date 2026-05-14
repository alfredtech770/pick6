// GET /api/leaderboard?limit=20
//
// Public endpoint that returns the top referrers on the Pick1 waitlist.
// Powers the /leaderboard.html page — drives competitive sharing during
// the launch sweepstakes ("oh, I could be #1 on the leaderboard if I
// share my link more").
//
// Backed by public.get_top_referrers() RPC (see migrations/003_leaderboard.sql).
// Returns anonymized data — first name + first 3 chars of email hash —
// so users can recognize themselves but PII never leaks.
//
// Edge-cached at Vercel for 60s so the leaderboard page doesn't slam
// Supabase even at 1000+ concurrent viewers. stale-while-revalidate keeps
// the response snappy even when the cache is refreshing.

module.exports = async (req, res) => {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'method_not_allowed' });
  }

  // Parse optional limit query param — defensive cap at 50.
  const rawLimit = parseInt(req.query?.limit ?? '20', 10);
  const limit = Number.isFinite(rawLimit) && rawLimit > 0 && rawLimit <= 50
    ? rawLimit
    : 20;

  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    // Fail soft — frontend just shows "leaderboard coming soon"
    return res.status(200).json({ leaderboard: [], cached: false });
  }

  try {
    const resp = await fetch(
      `${SUPABASE_URL}/rest/v1/rpc/get_top_referrers`,
      {
        method: 'POST',
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
          'content-type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({ p_limit: limit }),
      }
    );

    if (!resp.ok) {
      const detail = await resp.text();
      console.error('leaderboard_rpc_failed', resp.status, detail);
      return res.status(200).json({ leaderboard: [], cached: false });
    }

    const rows = await resp.json();
    if (!Array.isArray(rows)) {
      return res.status(200).json({ leaderboard: [], cached: false });
    }

    // Edge cache for 60s, SWR for 120s. Most page loads will hit the cache.
    res.setHeader(
      'Cache-Control',
      'public, max-age=60, s-maxage=60, stale-while-revalidate=120'
    );
    return res.status(200).json({
      leaderboard: rows,
      cached: true,
    });
  } catch (err) {
    console.error('leaderboard_fetch_error', err);
    return res.status(200).json({ leaderboard: [], cached: false });
  }
};
