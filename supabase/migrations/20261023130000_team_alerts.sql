-- Applied 2026-10-23 via MCP. Followed-team alerts + server-pushed Live Activities.
create table if not exists public.favorite_teams (
  user_id uuid not null references auth.users(id) on delete cascade,
  team text not null,
  sport text not null default '',
  created_at timestamptz not null default now(),
  primary key (user_id, team)
);
alter table public.favorite_teams enable row level security;
create policy favorite_teams_own on public.favorite_teams for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.game_alert_state (
  event_key text primary key, state text not null, home_score integer, away_score integer,
  detail text, sent jsonb not null default '{}'::jsonb, updated_at timestamptz not null default now()
);
alter table public.game_alert_state enable row level security;   -- service role only

alter table public.live_activity_tokens add column if not exists pick_side text;
alter table public.live_activity_tokens add column if not exists environment text not null default 'production';
alter table public.live_activity_tokens add column if not exists updated_at timestamptz not null default now();
alter table public.live_activity_tokens drop constraint if exists live_activity_tokens_pkey;
alter table public.live_activity_tokens add primary key (token);

-- Cron auth: a Vault secret 'team_alerts_cron', read by the job and checked by
-- the function through team_alerts_secret() (service_role only). The other
-- jobs only carry the anon key, which must not be enough to fire alerts.
-- pg_cron 'pick1-team-alerts' runs every minute, POST /functions/v1/team-alerts
-- with header x-cron-secret.

-- 2026-10-23, separate migration picks_no_grade_before_kickoff: BEFORE UPDATE
-- trigger picks_block_early_grade keeps a pending pick pending if it is set to
-- win/loss before its game_date (ET) or within 75 minutes of start_time.

-- 2026-10-23, migration affiliate_partners: licensed bookmakers per market
-- (id, name, markets text[], affiliate_url, logo_url, licence, enabled, sort).
-- Public SELECT only for enabled rows with an https link. Seeded disabled:
-- winamax-fr, betclic-fr, unibet-fr, pmu-fr (ANJ), fanduel-us, bet365-on.
