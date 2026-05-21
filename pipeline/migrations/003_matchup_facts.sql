-- 003_matchup_facts.sql
-- Phase 2: real, web-search-backed supporting facts per pick.
--
-- Adds:
--   matchup_facts — JSONB array of { "label": text, "value": text }
--                   items the pipeline (Claude + web_search) generates
--                   alongside the pick. These render as the MATCHUP card
--                   on the iOS detail page. Examples:
--                     [{"label":"Recent form","value":"W-W-L-W-D"},
--                      {"label":"Head-to-head","value":"LAL won 3 of last 5"},
--                      {"label":"Injury","value":"Star PG out (knee)"}]
--                   Defaults to an empty array so existing rows and the
--                   iOS decoder degrade gracefully (no MATCHUP card shown).
--
-- Run once against Supabase:
--   psql "$DATABASE_URL" -f 003_matchup_facts.sql
-- or paste into the Supabase SQL editor.

ALTER TABLE public.picks
  ADD COLUMN IF NOT EXISTS matchup_facts jsonb NOT NULL DEFAULT '[]'::jsonb;
