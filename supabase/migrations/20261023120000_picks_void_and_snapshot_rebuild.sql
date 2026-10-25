-- Applied 2026-10-23 via MCP. Public record clean-up.
-- A voided pick stays in the table (user_bets cascades on delete) but leaves
-- the public record: anon/authenticated never read it, every win/loss count
-- skips it. result_before_void keeps the original grade, so this is reversible.
alter table public.picks add column if not exists void_reason text;
alter table public.picks add column if not exists result_before_void text;

drop policy if exists picks_read_all on public.picks;
drop policy if exists picks_select_anon on public.picks;
drop policy if exists picks_select_public on public.picks;
drop policy if exists public_read_picks on public.picks;
create policy picks_public_read on public.picks
  for select to anon, authenticated
  using (result is distinct from 'void');

-- Data step (run once, 144 rows): void every pick created after its scheduled
-- start (123, reason published_after_start), both picks of the 3 games called
-- on both sides (6, both_sides_called), and the later copy of 15 games saved
-- twice under two name formats (15, duplicate_game). Original grades are in
-- result_before_void. Before: 1471-985 (59.9%). After: 1378-936 (59.6%).
--   update picks set result_before_void = result, result = 'void', void_reason = '<reason>' where id in (...);

-- performance_snapshots = 30-day record per league as of each date, rebuilt
-- from picks (win/loss only) so the two never disagree. pg_cron
-- 'pick1-performance-snapshots' runs it daily at 05:20 UTC.
-- See refresh_performance_snapshots(p_from date, p_to date) in the database.
