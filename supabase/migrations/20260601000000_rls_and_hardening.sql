-- Pick1 pipeline hardening migration
-- 1. Enable RLS on data tables (read-only via anon, writes only via service_role)
-- 2. Add audit columns to picks for debugging bad picks

ALTER TABLE public.picks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.performance_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "picks_select_anon" ON public.picks;
CREATE POLICY "picks_select_anon" ON public.picks
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "live_scores_select_anon" ON public.live_scores;
CREATE POLICY "live_scores_select_anon" ON public.live_scores
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "performance_snapshots_select_anon" ON public.performance_snapshots;
CREATE POLICY "performance_snapshots_select_anon" ON public.performance_snapshots
  FOR SELECT TO anon, authenticated USING (true);

ALTER TABLE public.picks
  ADD COLUMN IF NOT EXISTS claude_usage jsonb,
  ADD COLUMN IF NOT EXISTS pipeline_run_id text;

CREATE INDEX IF NOT EXISTS picks_created_at_desc_idx ON public.picks (created_at DESC);
CREATE INDEX IF NOT EXISTS picks_pipeline_run_id_idx ON public.picks (pipeline_run_id) WHERE pipeline_run_id IS NOT NULL;
