-- RLS hardening for read-only public tables.
--
-- The Pick1 iOS app ships the Supabase anon key (Apple Sign In + email
-- OTP is the authenticated user path). Without RLS enabled, ANY client
-- holding the anon key can INSERT / UPDATE / DELETE rows in any
-- public-schema table by default. This migration locks the three
-- pipeline-owned tables down to:
--
--   • SELECT  → anyone (anon or authenticated) — these are read-only
--               public feeds (the AI picks of the day, live scores,
--               historical performance snapshots).
--   • INSERT / UPDATE / DELETE → service_role only. The Railway
--               pipeline uses the service-role key and bypasses RLS
--               for writes; the iOS client cannot write to these tables.

-- ─── picks ────────────────────────────────────────────────────────────
alter table if exists public.picks enable row level security;

drop policy if exists picks_select_public on public.picks;
create policy picks_select_public on public.picks
    for select using (true);

-- No insert / update / delete policies → all writes from anon are denied.
-- service_role bypasses RLS automatically.

-- ─── live_scores ──────────────────────────────────────────────────────
alter table if exists public.live_scores enable row level security;

drop policy if exists live_scores_select_public on public.live_scores;
create policy live_scores_select_public on public.live_scores
    for select using (true);

-- ─── performance_snapshots ────────────────────────────────────────────
alter table if exists public.performance_snapshots enable row level security;

drop policy if exists performance_snapshots_select_public on public.performance_snapshots;
create policy performance_snapshots_select_public on public.performance_snapshots
    for select using (true);

-- ─── Verification helper ──────────────────────────────────────────────
-- Run after applying this migration to confirm RLS is on:
--   select tablename, rowsecurity
--   from   pg_tables
--   where  schemaname = 'public'
--     and  tablename in ('picks', 'live_scores', 'performance_snapshots',
--                        'profiles');
-- All four should return rowsecurity = true.

-- ─── Sanity check — anon must NOT be able to write ─────────────────────
-- Manual test from psql connected as anon role:
--   set role anon;
--   insert into public.picks (sport, league) values ('test', 'TEST');
--   -- expected: ERROR:  new row violates row-level security policy
--   reset role;
