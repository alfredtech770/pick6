-- ─── Top-referrers leaderboard ───────────────────────────────────────────
--
-- Public read-only RPC that returns the top N referrers — anonymized to
-- "First name + first 3 chars of email hash" so we don't leak PII to the
-- public leaderboard page, but referrers can still recognize themselves.
--
-- Drives competitive sharing on pick1.live/leaderboard. Each referral
-- bumps the referrer's count by 1 (driven by upsert_waitlist_signup's
-- existing referral-credit logic from 002_referrals.sql).
--
-- Caching is owned by the API layer (/api/leaderboard caches the response
-- at Vercel's edge for 60s). This function itself is cheap — a single
-- index seek on (referrals_count DESC).
--
-- Safety:
--   - Returns nothing for users with 0 referrals (clutter filter)
--   - Caps at the requested limit
--   - SECURITY DEFINER so it can be called via the public-key flow,
--     but only exposes the small set of anonymized columns below.
CREATE OR REPLACE FUNCTION public.get_top_referrers(
  p_limit integer DEFAULT 20
)
RETURNS TABLE (
  rank             integer,
  display_name     text,
  referrals_count  integer,
  referral_code    text
)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  -- Build the leaderboard rows. The display name is "FirstName ·███" where
  -- ███ is the first 3 chars of MD5(email) — public, anonymized, but
  -- consistent across page loads (so referrers can recognize themselves).
  SELECT
    row_number() OVER (ORDER BY w.referrals_count DESC, w.created_at ASC)::integer AS rank,
    coalesce(w.first_name, 'Member') || ' ·' || substring(md5(w.email) from 1 for 3) AS display_name,
    w.referrals_count::integer AS referrals_count,
    w.referral_code
  FROM public.waitlist_attribution w
  WHERE w.referrals_count > 0
  ORDER BY w.referrals_count DESC, w.created_at ASC
  LIMIT greatest(1, least(p_limit, 100));  -- defensive cap at 100
$$;

-- Grant execute to public so the anon key can call it. The function is
-- SECURITY DEFINER so it runs with the schema-owner's privileges, but
-- only returns the four anonymized columns above — no email leak.
GRANT EXECUTE ON FUNCTION public.get_top_referrers(integer) TO anon, authenticated;
