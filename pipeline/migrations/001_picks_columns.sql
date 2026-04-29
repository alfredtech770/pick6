-- 001_picks_columns.sql
-- Adds the columns the new pipeline writes:
--   game_id     — links a pick to its live_scores row for reliable grading
--                 (replaces the old fuzzy team-name matching)
--   key_factor  — short tagline shown in the iOS pick card
--
-- Also adds a unique constraint so the pipeline can safely upsert
-- without duplicating picks when a cron run overlaps a manual run.
--
-- Run this once against your Supabase database:
--   psql "$DATABASE_URL" -f 001_picks_columns.sql
-- or paste into the SQL editor in the Supabase dashboard.

ALTER TABLE public.picks
  ADD COLUMN IF NOT EXISTS game_id    text,
  ADD COLUMN IF NOT EXISTS key_factor text;

CREATE INDEX IF NOT EXISTS picks_game_id_idx ON public.picks (game_id);

-- One pick per (league, game_date, game_id). Re-running the pipeline
-- on the same day for the same game becomes an idempotent upsert.
ALTER TABLE public.picks
  DROP CONSTRAINT IF EXISTS picks_league_date_game_unique;
ALTER TABLE public.picks
  ADD CONSTRAINT picks_league_date_game_unique
  UNIQUE (league, game_date, game_id);

-- performance_snapshots — used by savePerformanceSnapshot().
-- Create if missing.
CREATE TABLE IF NOT EXISTS public.performance_snapshots (
  league             text NOT NULL,
  snapshot_date      date NOT NULL,
  total_picks        integer,
  wins               integer,
  losses             integer,
  win_rate           numeric,
  high_conf_win_rate numeric,
  med_conf_win_rate  numeric,
  recent_win_rate    numeric,
  PRIMARY KEY (league, snapshot_date)
);

-- live_scores — make sure game_id is the upsert key.
ALTER TABLE public.live_scores
  DROP CONSTRAINT IF EXISTS live_scores_game_id_unique;
ALTER TABLE public.live_scores
  ADD CONSTRAINT live_scores_game_id_unique UNIQUE (game_id);
