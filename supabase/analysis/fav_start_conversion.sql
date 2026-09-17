-- Did fav_start move conversion? Run this three weeks after the pipeline
-- change ships (2026-09-17 + 21 days = 2026-10-08 at the earliest).
--
-- Compares people who RECEIVED at least one fav_start push against active
-- people who received none, over the same window, on the only outcome that
-- matters: did they reach a PAID period. Correlation only: someone who stars
-- a game was already more engaged. The honest read is the delta between the
-- two groups, not either number on its own.
with window as (
  select now() - interval '21 days' as since
),
exposed as (
  select distinct user_id from push_log, window
  where base_key = 'fav_start' and sent_at >= window.since
),
active as (
  -- Everyone who could have been exposed: opened the app in the window.
  select distinct user_id from device_tokens, window
  where last_seen_at >= window.since
),
paid as (
  select distinct user_id from subscriptions, window
  where environment = 'Production' and is_trial is false
    and purchase_date >= window.since
)
select
  case when e.user_id is not null then 'received fav_start' else 'active, none' end as cohort,
  count(*)                                               as people,
  count(*) filter (where p.user_id is not null)          as reached_paid,
  round(100.0 * count(*) filter (where p.user_id is not null) / count(*), 1) as pct_paid
from active a
left join exposed e on e.user_id = a.user_id
left join paid    p on p.user_id = a.user_id
group by 1 order by 1;

-- Sanity companion: how many fav_start went out at all, and the open rate,
-- so a null result can be told apart from "it never fired".
select count(*) sends, count(distinct user_id) people,
       round(100.0 * count(opened_at) / nullif(count(*), 0), 1) as open_pct
from push_log where base_key = 'fav_start' and sent_at >= now() - interval '21 days';
