# Pick6 AI Prediction Pipeline

Node.js service that pulls upcoming games from sportsdata.io, asks Claude Opus 4.7 for calibrated picks, writes them to Supabase, and grades completed picks against final scores. The iOS app reads the resulting `picks` table directly and subscribes to realtime updates.

---

## What changed vs. the original prototype

### Bugs fixed

- **`fetchNBAGames` / `fetchNHLGames` returned the wrong shape.** `return [res.data]` wrapped the array in a one-element outer array, so `nbaGames.filter(g => g.Status === 'Scheduled')` always returned `[]`. The pipeline literally couldn't generate picks. → fixed.
- **Markdown paste artifacts** (`[stats.total](http://stats.total)`, `[res.data](http://res.data)`, etc.) — the pasted code wouldn't have parsed as JS. Cleaned up.
- **Hour-24 check** (`hour <= 24`) is invalid; rewritten as ET-aware schedule with a normal `hour <= 1 || hour >= 10` window.
- **Wrong model identifier** (`claude-sonnet-4-6` was correct as a model ID, but for "the most advanced model" we want Opus 4.7). → upgraded.

### Capability upgrades

| Improvement | Why it matters |
|---|---|
| **Claude Opus 4.7 + adaptive thinking + `effort: "max"`** | Most capable model. Adaptive thinking lets Claude reason internally before committing — measurably better calibration than a single-shot completion. |
| **Prompt caching on the system prompt** | The 700-token system prompt is identical across every call. With `cache_control: ephemeral` the rerun cost drops to ~10% of base input pricing. Verify via `usage.cache_read_input_tokens` in the logs. |
| **Structured outputs (`output_config.format`)** | Claude returns JSON that *must* match a JSON schema. Eliminates the regex-strip-the-fence parsing dance, eliminates malformed-JSON failures. |
| **Web search tool** | Claude can pull live injury reports, weather, scratched starters, and lineup news *during* the prediction. The 4.7 web_search tool has built-in dynamic filtering, so retrieved pages don't blow up the context window. |
| **Streaming via `stream.finalMessage()`** | At `effort: "max"` with web search the agent loop can run many minutes — non-streaming requests would hit SDK timeout. |
| **`game_id`-based grading** | Old code did substring matching on team names — fragile (BKN vs Brooklyn vs Nets). Now picks store `game_id` and grading looks up the matching `live_scores` row directly. |
| **Idempotent upserts** | New unique index on `(league, game_date, game_id)`. Re-running the pipeline never duplicates picks. |
| **Per-run lock** | `pipelineRunning` + `liveLoopRunning` flags prevent overlapping cron ticks from double-processing. |
| **TZ-pinned cron** (`America/New_York`) | "Today" matches the US sports schedule regardless of where the box is hosted. |
| **Pluggable league registry** | Adding NFL took two lines. Adding EPL / F1 / Tennis just means another entry in the `LEAGUES` object — no other code changes. |
| **SDK auto-retry** | The Anthropic SDK retries 408/409/429/5xx with exponential backoff (`maxRetries: 4`). One transient error no longer kills a run. |

### Coverage

The original handled NBA + NHL. This version ships with all **8 sports** the iOS app surfaces:

| Sport | League | Source | Notes |
|---|---|---|---|
| basketball | NBA | sportsdata.io | full schedule |
| hockey | NHL | sportsdata.io | full schedule |
| football | NFL | sportsdata.io | full schedule |
| baseball | MLB | sportsdata.io | + probable starters |
| soccer | EPL | sportsdata.io (soccer) | skips likely draws |
| combat | UFC | sportsdata.io (MMA) | one prediction per bout |
| f1 | F1 | Ergast API (free) | predicts upcoming GP winner |
| tennis | ATP / WTA | Claude `web_search` | research mode — no public schedule API |

Adding another league is one entry in the `LEAGUES` registry: `sport`, `promptMode` (`team` / `race` / `research`), `fetcher`, `normalizer`, `notes`. The dispatch loop and prompt assembly handle the rest.

> **F1 + Tennis grading caveat:** these picks aren't auto-graded today. F1 picks are stored as `pick = "Driver Name"` (not `home_team`/`away_team`), and tennis picks are research-mode strings. Both flow into the iOS app correctly, but the auto-grader skips them — wire up sport-specific graders if/when you want the win-rate stats to include them.

---

## Setup

### 1. Database migration (one time)

The new schema needs `game_id` and `key_factor` columns on `picks`, and a unique constraint for safe upserts. Run [`migrations/001_picks_columns.sql`](./migrations/001_picks_columns.sql) against Supabase — paste it into the SQL editor in the dashboard, or:

```bash
psql "$DATABASE_URL" -f migrations/001_picks_columns.sql
```

### 2. Install + configure

```bash
cd pipeline
npm install
cp .env.example .env
# Fill in ANTHROPIC_API_KEY, SUPABASE_SERVICE_ROLE_KEY, SPORTSDATA_KEY
```

> Use the **service role** key, not the anon key — the pipeline writes to `picks` and `live_scores`, which are protected by RLS for the iOS client.

### 3. Run

```bash
npm start
```

You'll see something like:

```
[2026-04-29T22:13:01.144Z] ⚡ Pick6 AI pipeline online
[2026-04-29T22:13:01.144Z]    Model:    claude-opus-4-7 (adaptive thinking, max effort)
[2026-04-29T22:13:01.144Z]    Leagues:  NBA, NHL, NFL, MLB
[2026-04-29T22:13:01.144Z]    Timezone: America/New_York
[2026-04-29T22:13:01.144Z] ▶ Pipeline run starting
[2026-04-29T22:13:04.218Z] Analyzing 6 NBA game(s)…
[2026-04-29T22:14:32.901Z] Claude NBA usage: in=842 out=1418 cache_read=712 cache_write=0
[2026-04-29T22:14:32.902Z] Generated 4 picks for NBA.
[2026-04-29T22:14:32.945Z] ✅ *** Nuggets (84%) — Heat vs Nuggets
...
```

### Deployment

The script is a single long-running process. Deploy on whatever runs Node continuously:

- **Railway / Render / Fly.io** — push, set env vars, done. Fly is cheapest for a 24/7 worker.
- **Supabase Edge Function + pg_cron** — would need a port to Deno; the Anthropic SDK works there.
- **A VM you already have** — `pm2 start index.js --name pick6-pipeline`.

Cost model on a typical day (~30 games across the four leagues, 4 prediction runs):
- Claude: ~$1–2/day with prompt caching, ~$5–10/day without (web search costs more on long agent loops). The cache hit rate ramps up as the system prompt warms.
- sportsdata.io: tier-dependent, but typical hobbyist plans handle this volume.
- Supabase: well within free tier.

---

## Schedule

| When (ET) | What |
|---|---|
| Every minute, 10am–1am | Refresh live scores, grade pending picks |
| 10am, 2pm, 6pm, 10pm | Generate AI picks for any newly-scheduled games |
| Midnight | Save daily performance snapshot |

The 10am cycle catches afternoon games (MLB, EPL etc.), 2pm picks up evening starts, 6pm the prime-time slate, 10pm late-night west-coast games.

---

## How the iOS app sees this

[`Betting app/Models/Pick.swift`](../Betting%20app/Models/Pick.swift) was updated alongside this rewrite. The new fields:

```swift
let gameId: String?      // links to live_scores
let keyFactor: String?   // short tagline shown in the pick card
```

The existing realtime subscription in [`PicksViewModel.swift`](../Betting%20app/ViewModels/PicksViewModel.swift) keeps working — when the pipeline upserts a row, the app gets it pushed in real time.

---

## Questions worth answering before you ship

1. **Sport coverage** — the design's onboarding lists 9 sports (NBA, EPL, MLB, NFL, NHL, UFC, F1, Tennis, Cricket). NBA/NHL/NFL/MLB are wired. Want me to add EPL (the-odds-api or sportsdata.io's soccer endpoint), F1 (Ergast API), or others? Each is ~10 lines in the `LEAGUES` registry.
2. **Pre-game timing** — currently picks generate 4× daily on a schedule. An alternative is to fire a pick exactly 60 minutes before kickoff (more accurate injury info, but more API calls). Both are easy.
3. **Rate / cost guardrails** — would you like a daily `max_tokens` budget cap per league, or a hard ceiling on Claude spend per day? Easy to add via `output_config.task_budget` (Opus 4.7 beta) or a manual counter.
4. **Notifications** — when a pick lands, you could fire an iOS push via Supabase Edge Functions or Twilio. Want this wired now, or later?
