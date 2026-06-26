// Pick6 AI Prediction Pipeline
// ─────────────────────────────────────────────────────────────────
// Pulls upcoming games from sportsdata.io / Ergast / web search,
// asks Claude Opus 4.7 for calibrated picks, writes them to
// Supabase, and grades completed picks against final scores.
//
// Coverage: 8 sports, the biggest live league per sport.
// Secondary / minor leagues will be added later (NCAAB, EuroLeague,
// La Liga, KBO, Bellator, BBL, KHL, etc.).
//
//   basketball  NBA   sportsdata.io (research fallback)
//   hockey      NHL   sportsdata.io (research fallback)
//   football    NFL   sportsdata.io (research fallback)
//   baseball    MLB   sportsdata.io (research fallback)
//   soccer      EPL   sportsdata.io (research fallback)
//   combat      UFC   sportsdata.io (research fallback)
//   f1          F1    Ergast API / jolpi.ca (free)
//   cricket     IPL   Claude `web_search` (no public schedule API)
//
// Add a new league by appending to the LEAGUES registry below.

require('dotenv').config();

const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const cron = require('node-cron');
const axios = require('axios');
// `ws` is required as the realtime transport on Node < 22.
// Without it, @supabase/realtime-js throws on createClient() and
// crashes the worker on boot.
const ws = require('ws');
const combat = require('./combat');   // grounded UFC/MMA path (ESPN-sourced facts + verification)

// ─── Config ────────────────────────────────────────────────────
const ANTHROPIC_MODEL = 'claude-opus-4-7';
const TZ = 'America/New_York';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
  // SDK auto-retries 408/409/429/5xx with exponential backoff.
  // Lowered from 4 → 2: with adaptive thinking + web_search a single
  // failed retry can cost ~$0.50–$1.50, so 4 retries means a single
  // hung daily run can compound to $6+. Two is enough for transient
  // 429s; persistent failures should fail loudly, not silently retry.
  maxRetries: 2,
  // Per-request timeout — defaults to 10 min in the SDK, which means
  // a hung stream can hold a cron tick open and pile up. Two minutes
  // is well over the realistic p99 for a single-league pick run.
  timeout: 120_000,
});

// ─── Daily web_search budget ─────────────────────────────────────────
// Cost ceiling for the agentic web_search tool across one UTC day.
// Each search ≈ $0.01 and each thinking-step around a search can add
// $0.05-$0.15. With 8 leagues × research mode + hourly backfill the
// worst-case fan-out is large; this is a hard guardrail.
//
// Counter is in-memory (per-process), reset on midnight UTC. For a
// single Railway worker that's sufficient; multi-worker deployments
// would need a Supabase counter table.
const WEB_SEARCH_DAILY_LIMIT = Number(process.env.WEB_SEARCH_DAILY_LIMIT || 200);
let webSearchUses = 0;
let webSearchBudgetDate = new Date().toISOString().slice(0, 10);

function checkWebSearchBudget(expectedUses = 1) {
  const today = new Date().toISOString().slice(0, 10);
  if (today !== webSearchBudgetDate) {
    webSearchBudgetDate = today;
    webSearchUses = 0;
  }
  if (webSearchUses + expectedUses > WEB_SEARCH_DAILY_LIMIT) {
    return false;
  }
  webSearchUses += expectedUses;
  return true;
}

// Daily Claude token-cost ceiling. Trips the breaker before runaway prompts
// can burn the budget. Counts ACTUAL post-call token spend at Opus 4.7 rates
// ($5/M input, $25/M output, $1.25/M cache_read, $6.25/M cache_write).
const CLAUDE_DAILY_COST_LIMIT_USD = Number(process.env.CLAUDE_DAILY_COST_LIMIT_USD || 25);
let claudeCostUsd = 0;
let claudeCostDate = new Date().toISOString().slice(0, 10);

function trackClaudeCost(usage) {
  const today = new Date().toISOString().slice(0, 10);
  if (today !== claudeCostDate) { claudeCostDate = today; claudeCostUsd = 0; }
  const inputCost = (usage.input_tokens || 0) / 1_000_000 * 5;
  const outputCost = (usage.output_tokens || 0) / 1_000_000 * 25;
  const cacheReadCost = (usage.cache_read_input_tokens || 0) / 1_000_000 * 1.25;
  const cacheWriteCost = (usage.cache_creation_input_tokens || 0) / 1_000_000 * 6.25;
  const total = inputCost + outputCost + cacheReadCost + cacheWriteCost;
  claudeCostUsd += total;
  return { spent: claudeCostUsd, callCost: total };
}

function claudeBudgetExceeded() {
  const today = new Date().toISOString().slice(0, 10);
  if (today !== claudeCostDate) return false;  // new day — reset on next track
  return claudeCostUsd >= CLAUDE_DAILY_COST_LIMIT_USD;
}

// Resend-based alert wrapper. Used by runPipeline so any pipeline crash
// emails admin within seconds — silent failure was the prior failure mode.
async function sendAlert(subject, body) {
  const key = process.env.RESEND_API_KEY;
  const to  = process.env.ALERT_EMAIL || 'ethan@milam.app';
  const from = process.env.RESEND_FROM || 'Pick1 Alerts <admin@pick1.live>';
  if (!key) { err('Cannot send alert — RESEND_API_KEY not set'); return; }
  try {
    await axios.post('https://api.resend.com/emails',
      { from, to: [to], subject: `[Pick1 Pipeline] ${subject}`, text: body },
      { headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' }, timeout: 10000 });
    log(`📧 Alert sent: ${subject}`);
  } catch (e) {
    err('Alert send failed:', e.message);
  }
}

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY,
  {
    // Realtime requires a WebSocket constructor on Node — the `ws`
    // package supplies it. Required since @supabase/realtime-js bumped
    // its WebSocketFactory to throw on Node < 22 with no transport.
    realtime: { transport: ws },
  },
);

// ─── Date / log helpers ────────────────────────────────────────
function todayISO() {
  return new Date().toLocaleDateString('en-CA', { timeZone: TZ });
}
function daysAgoISO(n) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - n);
  return d.toLocaleDateString('en-CA', { timeZone: TZ });
}
function log(...a) { console.log(`[${new Date().toISOString()}]`, ...a); }
function err(...a) { console.error(`[${new Date().toISOString()}] ERROR`, ...a); }

// ════════════════════════════════════════════════════════════════
// SOURCES
// ════════════════════════════════════════════════════════════════

// sportsdata.io — used for the four major US team leagues + soccer + MMA.
// With no SPORTSDATA_KEY set the integration is disabled: every fetcher
// returns empty, pick generation falls through to Claude research mode,
// and the live-score / grading ticks become no-ops instead of 403 spam.
async function sdFetch(path) {
  if (!process.env.SPORTSDATA_KEY) return [];
  try {
    const res = await axios.get(`https://api.sportsdata.io/v3/${path}`, {
      headers: { 'Ocp-Apim-Subscription-Key': process.env.SPORTSDATA_KEY },
      timeout: 15000,
    });
    return Array.isArray(res.data) ? res.data : (res.data ? [res.data] : []);
  } catch (e) {
    err(`sportsdata.io ${path} failed:`, e.message);
    return [];
  }
}

const fetchNBA = () => sdFetch(`nba/scores/json/GamesByDate/${todayISO()}`);
const fetchNHL = () => sdFetch(`nhl/scores/json/GamesByDate/${todayISO()}`);
const fetchNFL = () => sdFetch(`nfl/scores/json/GamesByDate/${todayISO()}`);
const fetchMLB = () => sdFetch(`mlb/scores/json/GamesByDate/${todayISO()}`);
const fetchEPL = () => sdFetch(`soccer/scores/json/GamesByDate/EPL/${todayISO()}`);

// MMA: sportsdata.io exposes fights by date. Each row is one bout.
const fetchUFC = () => sdFetch(`mma/scores/json/FightsByDate/${todayISO()}`);

// F1: Ergast API (now hosted at jolpi.ca after Ergast deprecated their
// domain in 2024). Pulls next race within a 3-day window. Free, no auth.
async function fetchF1() {
  try {
    const res = await axios.get('https://api.jolpi.ca/ergast/f1/current.json', { timeout: 15000 });
    const races = res.data?.MRData?.RaceTable?.Races || [];
    const now = new Date();
    // 21 days: always surface the NEXT Grand Prix as an upcoming pick
    // (with its real race date) instead of only race-weekend coverage.
    const window = 21 * 24 * 60 * 60 * 1000;
    return races.filter((r) => {
      const t = new Date(`${r.date}T${r.time || '14:00:00Z'}`).getTime() - now.getTime();
      return t >= 0 && t <= window;
    });
  } catch (e) {
    err('Ergast F1 fetch failed:', e.message);
    return [];
  }
}

// ════════════════════════════════════════════════════════════════
// LEAGUE REGISTRY
// ════════════════════════════════════════════════════════════════
// Each league defines:
//   sport             — canonical sport name written into picks.sport
//   promptMode        — 'team' | 'race' | 'research'
//   fetcher           — async () returning raw events (or null in research mode)
//   normalizer        — (raw) → { game_id, home_team, away_team, status, ... }
//   notes             — sport-specific context fed to the model
//   researchFallback  — if true and the primary fetcher returns no scheduled
//                       games (e.g. sportsdata.io 403 / 404), fall through
//                       to Claude `web_search` research mode for the day.
//                       This is what keeps NBA/NHL/MLB usable without paying
//                       for the missing sportsdata.io subscription tiers.
//   liveFetcher       — optional separate fetcher for in-play scores; defaults to fetcher

const LEAGUES = {
  // ─── Team sports — picks are home_team or away_team ────────────
  NBA: {
    sport: 'basketball', promptMode: 'team', fetcher: fetchNBA, researchFallback: true,
    notes: 'Home teams win ~58% in the NBA. Watch for back-to-backs and load management on stars.',
    normalizer: (g) => ({
      game_id: g.GameID?.toString(),
      home_team: g.HomeTeamName || g.HomeTeam,
      away_team: g.AwayTeamName || g.AwayTeam,
      home_record: `${g.HomeTeamWins ?? 0}-${g.HomeTeamLosses ?? 0}`,
      away_record: `${g.AwayTeamWins ?? 0}-${g.AwayTeamLosses ?? 0}`,
      start_time: g.DateTime,
      status: g.Status,
      venue: g.Stadium?.Name ?? null,
    }),
  },
  NHL: {
    sport: 'hockey', promptMode: 'team', fetcher: fetchNHL, researchFallback: true,
    notes: 'Home teams win ~55% in the NHL. Goalie matchups can swing odds 5–8 points.',
    normalizer: (g) => ({
      game_id: g.GameID?.toString(),
      home_team: g.HomeTeamName || g.HomeTeam,
      away_team: g.AwayTeamName || g.AwayTeam,
      start_time: g.DateTime,
      status: g.Status,
    }),
  },
  NFL: {
    sport: 'football', promptMode: 'team', fetcher: fetchNFL, researchFallback: true,
    notes: 'Home teams win ~57% in the NFL. Weather (wind > 15mph, sub-freezing temps) materially shifts totals; check it.',
    normalizer: (g) => ({
      game_id: g.GameID?.toString(),
      home_team: g.HomeTeamName || g.HomeTeam,
      away_team: g.AwayTeamName || g.AwayTeam,
      start_time: g.DateTime,
      status: g.Status,
      venue: g.StadiumDetails?.Name ?? null,
    }),
  },
  MLB: {
    sport: 'baseball', promptMode: 'team', fetcher: fetchMLB, researchFallback: true,
    notes: 'Home teams win ~54% in MLB. Starting pitcher matchup is the dominant variable — verify probable starters.',
    normalizer: (g) => ({
      game_id: g.GameID?.toString(),
      home_team: g.HomeTeamName || g.HomeTeam,
      away_team: g.AwayTeamName || g.AwayTeam,
      home_starter: g.HomeTeamProbablePitcherName ?? null,
      away_starter: g.AwayTeamProbablePitcherName ?? null,
      start_time: g.DateTime,
      status: g.Status,
    }),
  },
  EPL: {
    sport: 'soccer', promptMode: 'team', fetcher: fetchEPL, researchFallback: true,
    notes: 'Home teams win ~46% in the EPL, draws ~25%, away wins ~29%. SKIP games where you expect a draw — only return picks where one side is clearly favored.',
    normalizer: (g) => ({
      game_id: g.GameId?.toString(),
      home_team: g.HomeTeamName,
      away_team: g.AwayTeamName,
      start_time: g.DateTime,
      status: g.Status,
    }),
  },

  // ─── Combat — multiple bouts per card; one pick per bout ───────
  // DISABLED 2026-06-25: the research-mode model was confabulating fighter
  // records, debut status, betting lines, and methods of victory (a single
  // bad breakdown cost a partnership). Stays off until the grounded combat
  // path (real fighter data + verification pass) is built and validated.
  UFC: {
    enabled: true,         // re-enabled 2026-06-25 after grounded sample verified on-device
    combatGrounded: true,  // route through combat.js (ESPN facts + verification), NOT research mode
    sport: 'combat', promptMode: 'team', fetcher: fetchUFC, researchFallback: true,
    notes: 'Treat each fight as an independent prediction. Reach, age, fight IQ, recent form, layoff length, and weight cuts all matter. Skip prelims or matchups with sparse data.',
    normalizer: (f) => ({
      game_id: f.FightId?.toString(),
      home_team: f.Fighters?.[0]?.Name ?? 'Fighter A',  // fighter A
      away_team: f.Fighters?.[1]?.Name ?? 'Fighter B',  // fighter B
      weight_class: f.WeightClass,
      title_fight: !!f.TitleFight,
      start_time: f.DateTime || f.Day,
      status: f.Status,
    }),
  },

  // ─── F1 — predicting race winner; "Field" stands in for losers ─
  F1: {
    sport: 'f1', promptMode: 'race', fetcher: fetchF1,
    notes: 'Predict the RACE WINNER for the upcoming Grand Prix. Use qualifying results + recent form + circuit history. Wet-race forecasts swing this dramatically — check weather.',
    normalizer: (r) => ({
      game_id: `${r.season}-${r.round}`,
      home_team: `${r.raceName}`,             // e.g. "Monaco Grand Prix"
      away_team: 'Field',                      // pick = predicted winner
      season: r.season,
      round: r.round,
      circuit: r.Circuit?.circuitName,
      start_time: `${r.date}T${r.time || '14:00:00Z'}`,
      status: 'Scheduled',
    }),
  },

  // ─── Cricket (IPL) — research mode; Claude web-searches today's slate
  IPL: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'Indian Premier League season runs Mar–May. Use web_search to find today\'s IPL fixtures (and any notable T20I/Test internationals). Surface 1–4 picks per match day. Pick is the team to win the match.',
  },

  // 2026 World Cup — branded "Summer Football" in the app (App Review
  // 5.2.1 IP caution; never surface FIFA marks in user-visible strings).
  // Research mode covers today's AND tomorrow's fixtures (ET) so the
  // Summer Football hub always previews the next slate a day ahead.
  // game_date carries each match's REAL ET date, not the run date.
  WC: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'International national-team summer tournament 2026, hosted in North America (group stage June, knockouts through mid-July). Use web_search to confirm fixtures. Pick is the match result (team to win, or draw when genuinely strongest).',
  },

  // ── Expanded coverage (research-mode; web_search finds fixtures) ──
  // Each runs in the daily 5am pass and returns [] cleanly off-season.
  LALIGA: { sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'La Liga — Spanish first division (Aug–May). Pick the match result; draw allowed.' },
  SERIEA: { sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Serie A — Italian first division (Aug–May). Pick the match result; draw allowed.' },
  BUNDESLIGA: { sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Bundesliga — German first division (Aug–May). Pick the match result; draw allowed.' },
  LIGUE1: { sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Ligue 1 — French first division (Aug–May). Pick the match result; draw allowed.' },
  UCL: { sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'UEFA Champions League — European club competition (Sep–May). Pick the match result; draw allowed in group stage.' },
  MLS: { sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Major League Soccer — US/Canada top flight (Feb–Oct). Pick the match result; draw allowed.' },
  LIGAMX: { sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Liga MX — Mexican top flight. Pick the match result; draw allowed.' },
  WNBA: { sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'WNBA — women\'s pro basketball (May–Sep). Pick the game winner.' },
  EUROLEAGUE: { sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'EuroLeague — top European club basketball (Oct–May). Pick the game winner.' },
  NCAAB: { sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'NCAA Division I men\'s basketball (Nov–Apr). Pick the game winner.' },
  KBO: { sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'KBO — Korean pro baseball (Mar–Oct). Pick the game winner.' },
  NPB: { sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'NPB — Japanese pro baseball (Mar–Oct). Pick the game winner.' },
  NASCAR: { sport: 'f1', promptMode: 'research', fetcher: null,
    notes: 'NASCAR Cup Series (Feb–Nov). Use web_search to find the next race. Pick the race winner; populate field_odds with the top contenders\' win/podium probabilities.' },
};

// ════════════════════════════════════════════════════════════════
// LEARNING SYSTEM — performance feedback into the prompt
// ════════════════════════════════════════════════════════════════

async function getPerformanceStats(league, days = 30) {
  const since = daysAgoISO(days);
  const { data, error } = await supabase
    .from('picks')
    .select('probability, result, game_date')
    .eq('league', league)
    .neq('result', 'pending')
    .gte('game_date', since);

  if (error) { err('Performance fetch failed:', error.message); return null; }
  if (!data?.length) return null;

  const total = data.length;
  const wins = data.filter((p) => p.result === 'win').length;
  const losses = data.filter((p) => p.result === 'loss').length;
  const winRate = +((wins / total) * 100).toFixed(1);

  const tier = (lo, hi = 101) => {
    const slice = data.filter((p) => p.probability >= lo && p.probability < hi);
    if (!slice.length) return null;
    const w = slice.filter((p) => p.result === 'win').length;
    return { total: slice.length, winRate: +((w / slice.length) * 100).toFixed(1) };
  };
  const avg = (xs) => (xs.length ? +(xs.reduce((a, b) => a + b, 0) / xs.length).toFixed(1) : null);

  return {
    league, days, total, wins, losses, winRate,
    high: tier(80),
    medium: tier(65, 80),
    avgProbOnWins: avg(data.filter((p) => p.result === 'win').map((p) => p.probability)),
    avgProbOnLosses: avg(data.filter((p) => p.result === 'loss').map((p) => p.probability)),
  };
}

function performanceContext(stats30, stats7) {
  if (!stats30 || stats30.total < 5) {
    return 'No meaningful track record yet for this league — this is the early-calibration window. Surface picks normally so we can build a track record. Aim for a mix of high-confidence (80%+) and modest-edge (55–70%) picks across the slate.';
  }
  const lines = [
    'Your historical performance for this league:',
    `- Last 30 days: ${stats30.wins}W / ${stats30.losses}L (${stats30.winRate}% win rate, n=${stats30.total})`,
    stats7 && `- Last 7 days: ${stats7.wins}W / ${stats7.losses}L (${stats7.winRate}% win rate, n=${stats7.total})`,
    stats30.high && `- 80%+ confidence picks: ${stats30.high.winRate}% win rate (n=${stats30.high.total})`,
    stats30.medium && `- 65–79% confidence picks: ${stats30.medium.winRate}% win rate (n=${stats30.medium.total})`,
    stats30.avgProbOnWins != null && `- Avg stated probability on wins: ${stats30.avgProbOnWins}%`,
    stats30.avgProbOnLosses != null && `- Avg stated probability on losses: ${stats30.avgProbOnLosses}%`,
  ].filter(Boolean);

  const adj = [];
  if (stats30.winRate < 60) adj.push('Recent win rate is below 60% — be MORE SELECTIVE. Skip coin flips.');
  else if (stats30.winRate >= 75) adj.push('Win rate is strong; maintain standards.');
  if (stats30.high && stats30.high.winRate < 70) adj.push(`Your 80%+ picks only hit ${stats30.high.winRate}% — you are OVERCONFIDENT. Lower probabilities on picks you'd rate 80%+.`);
  if (stats7 && stats7.total >= 5 && stats7.winRate < 50) adj.push(`Cold streak this week (${stats7.winRate}%). Be extra conservative today.`);
  if (adj.length) {
    lines.push('', 'Calibration adjustments to apply:');
    adj.forEach((a) => lines.push(`- ${a}`));
  }
  return lines.join('\n');
}

// ════════════════════════════════════════════════════════════════
// CLAUDE — pick generation
// ════════════════════════════════════════════════════════════════

const SYSTEM_PROMPT = `You are the prediction engine behind Pick6, a premium sports prediction app. Users open the app every day expecting picks. Your job is to surface the BEST matchups available — not to return an empty list.

Required reasoning before committing to a pick:
1. Recent form, records, and head-to-head history.
2. Sport-specific context (home advantage, weather, fatigue, surface, circuit, weight class…).
3. Personnel: injuries, scratches, rest, probable starters/lineups. USE web_search to verify late-breaking news.
4. Calibration: if you say 70%, you should win 70% of the time long-run.

Hard rules:
- For ANY league with multiple matchups today, you MUST return AT LEAST ONE pick — pick the strongest opportunity even if your edge is modest.
- Aim for 2–4 picks per league when the slate is full (5+ games). Be selective but not silent.
- Probability floor is 55%. Anything 55%+ is fair game for a pick.
- Singles only — no parlays, no multi-leg.
- The "pick" field MUST be one of {home_team, away_team} from the input. Casing/whitespace can vary slightly but the team must clearly match.
- Probability is an integer 55–97.
- Confidence: "***" for 75%+, "**" for 65–74%, "*" for 55–64%.
- Reasoning: 2–3 punchy sentences explaining WHY.
- Key factor: the single biggest reason in 6–10 words.
- Matchup facts: 3–5 short {label, value} pairs of REAL, current supporting data (recent form, head-to-head, key injury, a decisive stat) verified via web_search. These power the in-app MATCHUP card, so they must be factual and specific — NEVER invented. Omit any fact you can't confirm rather than guessing; tailor labels to the sport.

For SOCCER (EPL): if every realistic outcome is a draw, you may skip — but on most matchdays at least one fixture has a side worth backing.
For COMBAT (UFC): treat each fight as independent. The main card almost always has at least one decisive matchup.
For F1: home_team is the race name, away_team is "Field"; "pick" is the predicted winning driver's full name (NOT one of home_team/away_team — for F1 only, return the driver's name as the pick).
For TENNIS: research today's slate via web_search; surface the strongest match-ups with clear edges (top seeds vs lower-ranked, ranking gaps, surface specialists).`;

const PICK_SCHEMA = {
  type: 'object',
  properties: {
    picks: {
      type: 'array',
      description: 'Array of picks for today. SHOULD contain at least 1 pick whenever multiple matchups exist; empty only if the slate is genuinely empty or every game is a true coin-flip.',
      items: {
        type: 'object',
        properties: {
          game_id: { type: 'string' },
          game_date: {
            type: 'string',
            description: 'The calendar date the match is actually played, in US Eastern Time, formatted YYYY-MM-DD. For a normal daily slate this is today\'s date; for leagues whose prompt covers future fixtures (e.g. tournament previews) use each match\'s real date.',
          },
          field_odds: {
            type: ['array', 'null'],
            description: 'RACE EVENTS ONLY (F1, NASCAR): the top 8-10 drivers ranked by win chance, each with their win and podium probabilities as integer percents. Use real grid/championship form + any market odds you can find. Null for non-race sports.',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string', description: 'Driver full name' },
                win: { type: 'number', description: 'Win probability %, 0-100' },
                podium: { type: 'number', description: 'Podium (top-3) probability %, 0-100' },
              },
              required: ['name', 'win', 'podium'],
              additionalProperties: false,
            },
          },
          predicted_score: {
            type: ['string', 'null'],
            description: 'Your single most-likely FINAL SCORE for this matchup, formatted "<home>-<away>" from the home team\'s perspective (e.g. "2-1" for soccer, "112-104" for NBA, "5-3" for MLB). Null for events where a score makes no sense (fights, races).',
          },
          market_odds: {
            type: ['number', 'null'],
            description: 'REAL current decimal odds for the PICKED outcome, found via web_search on Polymarket or a major sportsbook (DraftKings, FanDuel, bet365…). E.g. a -150 favorite is 1.67; Polymarket 60c is 1.0/0.60 ≈ 1.67. Must come from an actual market quote — null if you cannot find one. Never derive it from your own probability.',
          },
          odds_source: {
            type: ['string', 'null'],
            description: 'Name of the market the odds came from, e.g. "Polymarket", "DraftKings". Null when market_odds is null.',
          },
          home_team: { type: 'string' },
          away_team: { type: 'string' },
          pick: { type: 'string', description: 'The team/fighter/driver picked. For team sports must equal home_team or away_team. For F1, the driver name.' },
          probability: {
            type: 'integer',
            description: 'Integer 55-97. 55-64 is a slight edge, 65-74 is a strong lean, 75-89 is high confidence, 90+ is overwhelming.',
          },
          confidence: { type: 'string', enum: ['***', '**', '*'] },
          reasoning: { type: 'string' },
          key_factor: { type: 'string' },
          matchup_facts: {
            type: 'array',
            description:
              'REQUIRED. 3-5 short, REAL, current supporting facts for this matchup, verified via web_search — never invented. Each is a {label, value} pair shown on the detail page MATCHUP card. Tailor to the sport: e.g. team sports → "Recent form" (last 5 W/L), "Head-to-head" (recent meetings), "Key injury", "Home/away split", a decisive team stat; combat → "Reach", "Recent form", "Finish rate", "Layoff"; F1 → "Grid/qualifying", "Track record", "Recent results"; tennis → "Surface form", "H2H", "Ranking gap". Keep value under ~40 chars. If you cannot confirm a fact via web_search, omit it rather than guess.',
            items: {
              type: 'object',
              properties: {
                label: { type: 'string', description: 'Short fact label, e.g. "Recent form", "Head-to-head", "Key injury".' },
                value: { type: 'string', description: 'The concise factual value, e.g. "W-W-L-W-D", "LAL won 3 of last 5".' },
              },
              required: ['label', 'value'],
              additionalProperties: false,
            },
          },
        },
        required: ['game_id', 'game_date', 'home_team', 'away_team', 'pick', 'probability', 'confidence', 'reasoning', 'key_factor', 'matchup_facts', 'market_odds', 'odds_source', 'predicted_score', 'field_odds'],
        additionalProperties: false,
      },
    },
  },
  required: ['picks'],
  additionalProperties: false,
};

function buildUserPrompt(league, games, stats30, stats7, forceResearch = false, excludeMatchups = []) {
  const cfg = LEAGUES[league];
  const useResearch = cfg.promptMode === 'research' || forceResearch;
  const header = [
    `League: ${league}`,
    `Date: ${todayISO()}`,
    `Sport context: ${cfg.notes}`,
    '',
    performanceContext(stats30, stats7),
    '',
  ];
  if (useResearch) {
    // Tennis-style instructions tailored to the league when invoked as
    // a fallback for a team sport.
    const sportPlural = league === 'IPL' ? 'IPL cricket fixtures (and any notable T20I/Test internationals)'
      : league === 'NBA' ? 'NBA games'
      : league === 'NHL' ? 'NHL games'
      : league === 'NFL' ? 'NFL games'
      : league === 'MLB' ? 'MLB games'
      : league === 'EPL' ? 'EPL fixtures'
      : league === 'UFC' ? 'UFC fights'
      : league === 'WC' ? '2026 World Cup tournament matches'
      : `${league} matches`;
    // Event-based leagues preview ahead so the app can always show the
    // NEXT event with its real date: tournaments a day ahead, UFC the
    // next card (within 14 days), F1 the next Grand Prix (21 days).
    const searchTarget =
      league === 'WC' ? `today's and tomorrow's ${sportPlural}`
      : league === 'UFC' ? 'the next upcoming UFC event within the next 14 days (today included) — cover its main-card fights'
      : league === 'F1' ? 'the next upcoming Grand Prix within the next 21 days (today included)'
      : `today's ${sportPlural}`;
    return [
      ...header,
      `MODE: research. There is no curated feed available for ${league} today. Use web_search to find ${searchTarget}, then return a pick for EVERY matchup you can confirm in that window — full coverage, not just the best games. For each game pick the stronger side with your honest calibrated probability. Use the structured output schema. Empty array is only correct if literally zero games are scheduled in that window.`,
      'Set game_date on every pick to the REAL calendar date (US Eastern Time) the match is played, formatted YYYY-MM-DD.',
      'For each pick also look up the CURRENT market odds for the picked outcome (Polymarket or a major sportsbook) and report them as decimal odds in market_odds with the source name in odds_source; null both if no real quote is found.',
      ...(excludeMatchups.length
        ? [`Already covered — do NOT return picks for these matchups: ${excludeMatchups.join('; ')}.`]
        : []),
      'For each pick, populate game_id with a stable identifier you derive from the date and matchup',
      `(e.g. "${league.toLowerCase()}-${todayISO()}-${'home-vs-away'}"), and home_team/away_team with the team or player names exactly as they appear in the source. Do NOT invent matchups — if you can\'t confirm a matchup via web_search, skip it.`,
    ].join('\n');
  }
  return [
    ...header,
    `Today's ${cfg.promptMode === 'race' ? 'upcoming race(s)' : 'scheduled events'} for ${league}:`,
    JSON.stringify(games, null, 2),
    '',
    'Return your picks via the structured output schema. Use web_search to verify late-breaking injury news, scratched starters, weather, or qualifying results.',
    'Set game_date on every pick to the REAL calendar date (US Eastern Time) the event is played — for future events (e.g. an upcoming Grand Prix) use the event\'s date from the feed above, formatted YYYY-MM-DD.',
    'For each pick also look up the CURRENT market odds for the picked outcome (Polymarket or a major sportsbook) and report them as decimal odds in market_odds with the source name in odds_source; null both if no real quote is found.',
  ].join('\n');
}

async function getClaudePicks(league, games, { forceResearch = false } = {}) {
  const cfg = LEAGUES[league];
  const useResearch = cfg.promptMode === 'research' || forceResearch;

  if (claudeBudgetExceeded()) {
    log(`🛑 Skipping ${league} pick gen: daily Claude cost ceiling ($${CLAUDE_DAILY_COST_LIMIT_USD}) reached. Spent $${claudeCostUsd.toFixed(2)} today.`);
    return [];
  }

  // Budget check — research mode + forceResearch both fan out web_search
  // calls. Reserve a generous slice (10 searches) per league pick run,
  // and bail if we can't afford it. Pure feed-mode pick runs still hit
  // web_search for late-breaking news but at much lower volume; charge
  // them 3 against the budget.
  const expectedSearches = useResearch ? 10 : 3;
  if (!checkWebSearchBudget(expectedSearches)) {
    log(`💸 Skipping ${league} pick gen: daily web_search budget reached (${webSearchUses}/${WEB_SEARCH_DAILY_LIMIT}).`);
    return [];
  }

  const stats30 = await getPerformanceStats(league, 30);
  const stats7 = await getPerformanceStats(league, 7);

  // Research mode has no feed-side dedup (the feed path filters by
  // game_id before prompting) — so tell the model which matchups are
  // already covered today, or a re-run would duplicate/overwrite them.
  let excludeMatchups = [];
  if (useResearch) {
    // gte (not eq): tournament leagues carry future-dated picks; a
    // re-run must not regenerate tomorrow's already-covered fixtures.
    const { data: existing } = await supabase
      .from('picks')
      .select('home_team,away_team')
      .eq('league', league)
      .gte('game_date', todayISO());
    excludeMatchups = (existing || []).map((p) => `${p.away_team} @ ${p.home_team}`);
  }
  const userPrompt = buildUserPrompt(league, games, stats30, stats7, forceResearch, excludeMatchups);

  // max_tokens=32000 + effort=high: gives the agentic web_search loop
  // enough headroom to think AND emit the final JSON. effort=max +
  // 16k was burning all output on reasoning, leaving no text block.
  const stream = anthropic.messages.stream({
    model: ANTHROPIC_MODEL,
    max_tokens: 32000,
    thinking: { type: 'adaptive' },
    output_config: {
      effort: 'high',
      format: { type: 'json_schema', schema: PICK_SCHEMA },
    },
    tools: [
      { type: 'web_search_20260209', name: 'web_search' },
    ],
    system: [
      { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
    ],
    messages: [{ role: 'user', content: userPrompt }],
  });

  let final;
  try {
    final = await stream.finalMessage();
  } catch (e) {
    err(`Claude (${league}) failed:`, e.message);
    return [];
  }

  const u = final.usage;
  log(`Claude ${league} usage: in=${u.input_tokens} out=${u.output_tokens} cache_read=${u.cache_read_input_tokens || 0} cache_write=${u.cache_creation_input_tokens || 0}`);
  const { spent, callCost } = trackClaudeCost(u);
  log(`💰 Claude cost this call: $${callCost.toFixed(3)} | today: $${spent.toFixed(2)}/${CLAUDE_DAILY_COST_LIMIT_USD}`);

  const text = final.content.find((b) => b.type === 'text')?.text;
  if (!text) {
    const blockTypes = final.content.map((b) => b.type).join(',');
    err(`Claude ${league}: no text block. stop_reason=${final.stop_reason} blocks=[${blockTypes}]`);
    return [];
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (e) {
    err(`Claude ${league}: JSON parse failed:`, e.message);
    return [];
  }

  // Validate. The schema can't constrain probability to 65-97
  // (Anthropic structured outputs don't support min/max), so we
  // enforce it here. The pick must equal one of the matchup names,
  // but with case-insensitive + trimmed comparison so a tiny
  // whitespace/case difference doesn't drop the entire response.
  // F1 race-mode picks are exempt — the pick is a driver name.
  const norm = (s) => (typeof s === 'string' ? s.trim().toLowerCase() : '');
  const dropped = [];
  const picks = (parsed.picks || []).filter((p) => {
    if (typeof p.probability !== 'number' || p.probability < 55 || p.probability > 97) {
      dropped.push(`bad_prob(${p.probability})`); return false;
    }
    if (!p.pick || typeof p.pick !== 'string') {
      dropped.push('no_pick'); return false;
    }
    if (cfg.promptMode === 'race') return true;
    const pickN = norm(p.pick);
    const homeN = norm(p.home_team);
    const awayN = norm(p.away_team);
    if (pickN === homeN || pickN === awayN) return true;
    // Allow partial match (covers "Nets" ⊂ "Brooklyn Nets", etc.)
    if (homeN && (pickN.includes(homeN) || homeN.includes(pickN))) return true;
    if (awayN && (pickN.includes(awayN) || awayN.includes(pickN))) return true;
    dropped.push(`pick_mismatch(${p.pick}|${p.home_team}|${p.away_team})`);
    return false;
  });
  if (dropped.length) {
    log(`Claude ${league}: dropped ${dropped.length} picks: ${dropped.slice(0, 5).join(' ')}`);
  }

  log(`Generated ${picks.length} picks for ${league}${useResearch ? ' (research mode)' : ''}.`);
  return picks;
}

// ════════════════════════════════════════════════════════════════
// SUPABASE — write picks + scores, grade results
// ════════════════════════════════════════════════════════════════

async function savePicks(league, picks) {
  if (!picks.length) return;
  const sport = LEAGUES[league].sport;
  const fallbackDate = todayISO();
  // The model reports each match's real ET date (tournament previews
  // can cover tomorrow's fixtures). Trust it only when well-formed and
  // today-or-future; anything else falls back to the run date.
  const pickDate = (p) =>
    (typeof p.game_date === 'string'
      && /^\d{4}-\d{2}-\d{2}$/.test(p.game_date)
      && p.game_date >= fallbackDate)
      ? p.game_date : fallbackDate;

  const rows = picks.map((p) => ({
    sport,
    league,
    game_date: pickDate(p),
    game_id: p.game_id,
    home_team: p.home_team,
    away_team: p.away_team,
    pick: p.pick,
    probability: p.probability,
    confidence: p.confidence,
    reasoning: p.reasoning,
    key_factor: p.key_factor,
    // Phase 2: real, web-search-backed supporting facts → MATCHUP card.
    // Default to [] so a model that omits the field never nulls the
    // NOT NULL column.
    matchup_facts: Array.isArray(p.matchup_facts) ? p.matchup_facts : [],
    // Real market odds for the picked outcome (Polymarket / books),
    // sanity-banded: decimal odds outside 1.01–25 are junk quotes.
    market_odds: (typeof p.market_odds === 'number'
      && p.market_odds >= 1.01 && p.market_odds <= 25)
      ? p.market_odds : null,
    odds_source: (typeof p.odds_source === 'string' && p.odds_source.trim())
      ? p.odds_source.trim() : null,
    // "<home>-<away>" only; anything else (prose, ranges) is dropped.
    predicted_score: (typeof p.predicted_score === 'string'
      && /^\d{1,3}-\d{1,3}$/.test(p.predicted_score.trim()))
      ? p.predicted_score.trim() : null,
    field_odds: Array.isArray(p.field_odds)
      ? p.field_odds
          .filter((d) => d && typeof d.name === 'string'
            && typeof d.win === 'number' && typeof d.podium === 'number')
          .map((d) => ({ name: d.name.trim(),
                         win: Math.max(0, Math.min(100, Math.round(d.win))),
                         podium: Math.max(0, Math.min(100, Math.round(d.podium))) }))
          .slice(0, 12)
      : null,
    // Structured tale-of-the-tape for combat (physicals + career stats);
    // null for every other sport.
    tale_of_tape: p.tale_of_tape || null,
    result: 'pending',
  }));

  const { error } = await supabase
    .from('picks')
    .upsert(rows, { onConflict: 'league,game_date,game_id' });

  if (error) err('Save picks failed:', error.message);
  else picks.forEach((p) => log(`✅ ${p.confidence} ${p.pick} (${p.probability}%) — ${p.home_team} vs ${p.away_team}`));
}

async function upsertLiveScores(league, games) {
  if (!games?.length) return;
  const cfg = LEAGUES[league];
  const sport = cfg.sport;

  // Live-score upsert only makes sense for sports where we get a
  // structured feed (i.e. not research mode).
  if (cfg.promptMode === 'research') return;

  const rows = games.map((g) => {
    if (cfg.promptMode === 'race') {
      // F1: no in-progress score updates from Ergast.
      return null;
    }
    // Team sports + UFC.
    const norm = cfg.normalizer ? cfg.normalizer(g) : g;
    return {
      game_id: norm.game_id,
      sport,
      league,
      home_team: norm.home_team,
      away_team: norm.away_team,
      home_score: g.HomeTeamScore ?? null,
      away_score: g.AwayTeamScore ?? null,
      status: g.Status,
      quarter: g.Quarter?.toString() ?? null,
      start_time: norm.start_time,
      updated_at: new Date().toISOString(),
    };
  }).filter(Boolean);

  if (!rows.length) return;
  const { error } = await supabase.from('live_scores').upsert(rows, { onConflict: 'game_id' });
  if (error) err('Score upsert failed:', error.message);
}

const FINAL_STATUSES = new Set(['Final', 'F', 'FT', 'closed', 'Final OT', 'Final SO', 'F/OT', 'F/SO']);

/// AI-free score audit. Previously used Claude web_search to fill in
/// missing final scores at ~$0.05-$0.15/game — a runaway cost vector.
/// Now we rely exclusively on sportsdata.io's live polling: if a final
/// score never lands in live_scores, the pick stays ungraded. That's
/// acceptable: missing one day's grades is cheaper than a $50 blowout.
async function backfillMissingScores() {
  const finalsArr = [...FINAL_STATUSES];
  const { data: missing, error } = await supabase
    .from('live_scores')
    .select('game_id')
    .in('status', finalsArr)
    .or('home_score.is.null,away_score.is.null');
  if (error) { err('Backfill scan failed:', error.message); return 0; }
  const n = missing?.length || 0;
  if (n) log(`ℹ️ ${n} final-status game(s) missing scores — waiting on sportsdata.io to repopulate (no Claude backfill).`);
  return 0;
}

/// Lenient string match used when comparing pick text to team text.
/// Same algorithm as the pick-validator: trim+lowercase, then exact or
/// substring-either-way (e.g. "Cavaliers" matches "Cleveland Cavaliers").
function teamsMatch(pick, team) {
  if (!pick || !team) return false;
  const a = String(pick).trim().toLowerCase();
  const b = String(team).trim().toLowerCase();
  if (a === b) return true;
  if (a.includes(b) || b.includes(a)) return true;
  return false;
}

async function gradePicks() {
  const { data: pending, error: e1 } = await supabase
    .from('picks')
    .select('id, game_id, pick, home_team, away_team, sport')
    .eq('result', 'pending');
  if (e1) { err('Pending picks fetch failed:', e1.message); return; }
  if (!pending?.length) return;

  const gameIds = [...new Set(pending.map((p) => p.game_id).filter(Boolean))];
  if (!gameIds.length) {
    err('Skipping grading — no picks have game_id (legacy rows).');
    return;
  }

  const { data: scores, error: e2 } = await supabase
    .from('live_scores')
    .select('game_id, home_team, home_score, away_score, status')
    .in('game_id', gameIds);
  if (e2) { err('Scores fetch failed:', e2.message); return; }

  const byGameId = new Map(scores.map((s) => [s.game_id, s]));
  let graded = 0;
  for (const pick of pending) {
    const score = byGameId.get(pick.game_id);
    if (!score || !FINAL_STATUSES.has(score.status)) continue;
    if (score.home_score == null || score.away_score == null) continue;

    // F1 / non-team picks: pick is a driver name, not home/away.
    // We can grade with lenient string matching on team names.
    const matchesHome = teamsMatch(pick.pick, pick.home_team);
    const matchesAway = teamsMatch(pick.pick, pick.away_team);
    if (!matchesHome && !matchesAway) continue;

    const homeWon = score.home_score > score.away_score;
    const pickedHome = matchesHome;
    const won = pickedHome === homeWon;

    const { error: e3 } = await supabase
      .from('picks')
      .update({
        result: won ? 'win' : 'loss',
        home_score: score.home_score,
        away_score: score.away_score,
      })
      .eq('id', pick.id);
    if (e3) { err(`Grade update failed for pick ${pick.id}:`, e3.message); continue; }
    log(`${won ? '✅ WIN' : '❌ LOSS'}: ${pick.pick} (${score.home_score}-${score.away_score})`);
    graded++;
  }
  if (graded) log(`Graded ${graded} picks.`);
  return graded;
}

// gradePicksViaResearch was removed: it used Claude web_search to grade
// pending picks lacking a live_scores row. That hourly Claude burst was
// a runaway cost vector. Grading now happens exclusively from sportsdata.io
// final scores via gradePicks() — picks without a final score stay pending.

// ════════════════════════════════════════════════════════════════
// PERFORMANCE SNAPSHOTS
// ════════════════════════════════════════════════════════════════

async function savePerformanceSnapshot() {
  const date = todayISO();
  for (const league of Object.keys(LEAGUES)) {
    const stats = await getPerformanceStats(league, 30);
    if (!stats) continue;
    const { error } = await supabase.from('performance_snapshots').upsert(
      {
        league,
        snapshot_date: date,
        total_picks: stats.total,
        wins: stats.wins,
        losses: stats.losses,
        win_rate: stats.winRate,
        high_conf_win_rate: stats.high?.winRate ?? null,
        med_conf_win_rate: stats.medium?.winRate ?? null,
        recent_win_rate: null,
      },
      { onConflict: 'league,snapshot_date' },
    );
    if (error) err(`Snapshot upsert failed (${league}):`, error.message);
    else log(`📈 Snapshot ${league}: ${stats.winRate}% (${stats.total} picks)`);
  }
}

// ════════════════════════════════════════════════════════════════
// PIPELINE — fetch, predict, save
// ════════════════════════════════════════════════════════════════

let pipelineRunning = false;

async function runPipeline() {
  if (pipelineRunning) { log('Pipeline already running — skipping this tick.'); return; }
  pipelineRunning = true;
  log('▶ Pipeline run starting');
  const startedAt = new Date();
  try {
    // Grade yesterday's settled games FIRST so today's pick generation
    // sees the freshest performance stats. AI-free — uses whatever
    // sportsdata.io live polling has dropped into live_scores overnight.
    await gradePicks();

    for (const [league, cfg] of Object.entries(LEAGUES)) {
      if (cfg.enabled === false) { log(`⏸️  ${league} is disabled — skipping pick generation.`); continue; }

      // GROUNDED COMBAT PATH — facts come from ESPN, not the model's memory.
      // Build per-fight ground truth → constrained generation → verification
      // pass → save. Bypasses the research-mode flow that confabulated.
      if (cfg.combatGrounded) {
        if (claudeBudgetExceeded()) { log(`🛑 ${league}: Claude cost ceiling reached — skipping.`); continue; }
        if (!checkWebSearchBudget(15)) { log(`💸 ${league}: web_search budget reached — skipping.`); continue; }
        const gt = await combat.buildCardGroundTruth();
        if (!gt || !gt.fights?.length) { log(`${league}: no upcoming card on ESPN — skipping.`); continue; }
        const eventDate = (gt.event.date || '').slice(0, 10);
        // De-dup: skip the whole event if we've already saved its fights.
        const { data: existing } = await supabase.from('picks')
          .select('game_id').eq('league', 'UFC').gte('game_date', todayISO());
        const seen = new Set((existing || []).map((p) => p.game_id));
        gt.fights = gt.fights.filter((f) => !seen.has(`ufc-${f.fightId}`));
        if (!gt.fights.length) { log(`${league}: upcoming card already covered.`); continue; }
        log(`Analyzing ${gt.fights.length} ${league} fights (grounded: ${gt.event.name})…`);
        let draft = await combat.generateGroundedCombatPicks({ anthropic, model: ANTHROPIC_MODEL, groundTruth: gt, schema: PICK_SCHEMA, log });
        draft = await combat.verifyGroundedCombatPicks({ anthropic, model: ANTHROPIC_MODEL, picks: draft, groundTruth: gt, log });
        // Stamp deterministic ids/dates so dedup + scheduling work.
        const fightByName = new Map();
        for (const f of gt.fights) { fightByName.set(f.a.name, f); fightByName.set(f.b.name, f); }
        for (const p of draft) {
          const f = fightByName.get(p.home_team) || fightByName.get(p.away_team);
          if (f) {
            p.game_id = `ufc-${f.fightId}`;
            // Tale of the tape (ESPN physicals + career stats) → structured
            // field for the app's side-by-side section AND a clean,
            // guaranteed-accurate set of MATCHUP facts (replaces the
            // model's facts, which the reasoning text already covers).
            try {
              const tot = await combat.buildTaleOfTape(f);
              const facts = combat.combatComparisonFacts(tot);
              if (facts.length) { p.matchup_facts = facts; p.tale_of_tape = tot; }
            } catch (e) { log(`   tale-of-tape failed for ${p.home_team}: ${e.message}`); }
          }
          p.game_date = eventDate;
          p.predicted_score = null; p.field_odds = null;
        }
        await savePicks('UFC', draft);
        continue;
      }

      // 1. Pull events from primary source.
      const raw = cfg.fetcher ? await cfg.fetcher() : [];

      // 2. Refresh live scores for sports that return them.
      await upsertLiveScores(league, raw);

      // 3. Decide path: primary mode, race mode, or research mode.
      let games = [];
      let forceResearch = false;

      if (cfg.promptMode === 'research') {
        // Always research mode (e.g. ATP/Tennis).
        forceResearch = true;
      } else {
        const scheduled = raw.filter((g) => (g.Status || 'Scheduled') === 'Scheduled');
        if (scheduled.length) {
          // Primary path: we have scheduled events from the feed.
          games = scheduled.map(cfg.normalizer);
          // De-dup against already-saved picks, today OR future —
          // event leagues (F1) carry future-dated picks that must not
          // regenerate on every run.
          const { data: existing } = await supabase
            .from('picks')
            .select('game_id')
            .eq('league', league)
            .gte('game_date', todayISO());
          const seen = new Set((existing || []).map((p) => p.game_id));
          games = games.filter((g) => !seen.has(g.game_id));
          if (!games.length) {
            log(`${league}: all ${scheduled.length} scheduled events already covered.`);
            continue;
          }
        } else if (cfg.researchFallback) {
          // Primary feed returned nothing (404, 403, or empty). Fall
          // through to Claude web_search research mode.
          log(`${league}: primary feed empty, falling back to Anthropic research mode.`);
          forceResearch = true;
        } else {
          // No primary games + no fallback configured → skip league.
          continue;
        }
      }

      // 4. Ask Claude.
      log(`Analyzing ${forceResearch ? `today's ${league} slate (research)` : `${games.length} ${league} event(s)`}…`);
      const picks = await getClaudePicks(league, games, { forceResearch });
      await savePicks(league, picks);
    }

    // Second grade pass: catches anything sportsdata.io flipped to Final
    // while the per-league loop was running.
    await gradePicks();
  } catch (e) {
    err('Pipeline crashed:', e.stack || e.message);
    await sendAlert('Pipeline run FAILED',
      `Started: ${startedAt.toISOString()}\nFailed at: ${new Date().toISOString()}\nError: ${e.message}\n\nStack:\n${e.stack}`);
  } finally {
    pipelineRunning = false;
    log('■ Pipeline run complete');
  }
}

// ════════════════════════════════════════════════════════════════
// LIVE LOOP — refresh scores + grade pending picks during games
// ════════════════════════════════════════════════════════════════

let liveLoopRunning = false;

// Cache of leagues with games scheduled today — refreshed at the top of
// every hour to skip empty leagues entirely. Cuts sportsdata.io API
// volume by ~50-70% on typical days when only 2-3 of 6 leagues are active.
let leaguesWithGamesToday = null;
let leaguesCacheDate = null;

async function refreshActiveLeaguesCache() {
  const today = todayISO();
  if (leaguesCacheDate === today && leaguesWithGamesToday !== null) return leaguesWithGamesToday;
  const active = new Set();
  for (const [league, cfg] of Object.entries(LEAGUES)) {
    if (cfg.enabled === false) continue;
    if (cfg.promptMode === 'research' || !cfg.fetcher) continue;
    try {
      const raw = await cfg.fetcher();
      if (raw?.length) active.add(league);
    } catch {}
  }
  leaguesWithGamesToday = active;
  leaguesCacheDate = today;
  log(`Active leagues today (${today}): ${[...active].join(', ') || 'none'}`);
  return active;
}

// ── ESPN public scoreboard (free, keyless) ─────────────────────
// Replaces sportsdata.io (subscription lapsed) as the live-score
// source. One endpoint shape covers every league we run. Events are
// matched to OUR picks by team-name pair and upserted under the
// pick's game_id, so the app's pick→live_scores join works unchanged
// and hourly grading picks finals up automatically.
const ESPN_PATHS = {
  NBA: 'basketball/nba',
  NFL: 'football/nfl',
  MLB: 'baseball/mlb',
  NHL: 'hockey/nhl',
  EPL: 'soccer/eng.1',
  WC:  'soccer/fifa.world',
  LALIGA: 'soccer/esp.1',
  SERIEA: 'soccer/ita.1',
  BUNDESLIGA: 'soccer/ger.1',
  LIGUE1: 'soccer/fra.1',
  UCL: 'soccer/uefa.champions',
  MLS: 'soccer/usa.1',
  LIGAMX: 'soccer/mex.1',
  WNBA: 'basketball/wnba',
  NCAAB: 'basketball/mens-college-basketball',
  NASCAR: 'racing/nascar-premier',
  UFC: 'mma/ufc',
  F1:  'racing/f1',
};

function normName(n) {
  return (n || '').toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
}
function teamsMatch(a, b) {
  const na = normName(a), nb = normName(b);
  if (!na || !nb) return false;
  if (na.includes(nb) || nb.includes(na)) return true;
  // Last word (nickname) match: "los angeles dodgers" vs "dodgers".
  const la = na.split(' ').pop(), lb = nb.split(' ').pop();
  return la.length > 3 && la === lb;
}

async function espnScoreboard(league) {
  const path = ESPN_PATHS[league];
  if (!path) return [];
  // Today AND yesterday (ET): the default scoreboard drops finished
  // games at midnight, which would leave last night's finals ungraded.
  const tomorrow = (() => { const d = new Date(); d.setUTCDate(d.getUTCDate() + 1);
    return d.toLocaleDateString('en-CA', { timeZone: TZ }); })();
  const dates = [daysAgoISO(1), todayISO(), tomorrow].map((d) => d.replace(/-/g, ''));
  const events = [];
  for (const d of dates) {
    try {
      const res = await axios.get(
        `https://site.api.espn.com/apis/site/v2/sports/${path}/scoreboard?dates=${d}`,
        { timeout: 15000 },
      );
      events.push(...(res.data?.events || []));
    } catch (e) {
      err(`ESPN scoreboard ${league} ${d} failed:`, e.message);
    }
  }
  {
    return events.map((ev) => {
      const comp = ev.competitions?.[0];
      const cs = comp?.competitors || [];
      const home = cs.find((c) => c.homeAway === 'home');
      const away = cs.find((c) => c.homeAway === 'away');
      const st = ev.status?.type || {};
      const logoOf = (c) => c?.team?.logo
        || (c?.team?.logos && c.team.logos[0]?.href) || null;
      return {
        homeName: home?.team?.displayName || home?.athlete?.displayName || '',
        awayName: away?.team?.displayName || away?.athlete?.displayName || '',
        homeLogo: logoOf(home),
        awayLogo: logoOf(away),
        homeScore: home?.score != null ? Number(home.score) : null,
        awayScore: away?.score != null ? Number(away.score) : null,
        state: st.state || 'pre',             // pre | in | post
        detail: st.shortDetail || st.description || '',
        period: ev.status?.period ?? null,
        startTime: ev.date || null,
      };
    });
  }
}

// Profit % a pick would return on a unit stake — mirrors the app's
// Pick.potentialReturnPercent so the "you won +X%" push matches what the
// user sees in-app. Real market odds when present, else implied from the
// AI's confidence.
function payoutPct(p) {
  let dec;
  if (p.market_odds && p.market_odds > 1) dec = p.market_odds;
  else {
    const prob = Math.max(0.40, Math.min(0.90, (p.probability || 50) / 100));
    dec = Math.max(1.20, 1 / prob);
  }
  return Math.round((dec - 1) * 100);
}

// Fire a push via the send-push Edge Function. Fully guarded — a push
// failure (or APNS not configured yet) must never disrupt the live tick.
// Pass a payload object: { key, args, prefKey, userIds?, data? } for
// server-localized copy (preferred), or { title, body, prefKey } for a
// literal one-off. send-push renders `key` in each device's own language.
async function sendPush(payload) {
  try {
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY;
    if (!url || !key) return;
    const r = await fetch(`${url}/functions/v1/send-push`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (!r.ok) err(`send-push ${r.status}: ${(await r.text()).slice(0, 140)}`);
  } catch (e) {
    err('sendPush failed:', e.message);
  }
}

// Push a Live Activity (lock-screen / Dynamic Island) update via the
// push-live-activity Edge Function. Guarded — never disrupts the live tick.
async function pushLiveActivity(gameId, contentState, event) {
  try {
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY;
    if (!url || !key) return;
    const r = await fetch(`${url}/functions/v1/push-live-activity`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ gameId, contentState, event }),
    });
    if (!r.ok) err(`push-live-activity ${r.status}: ${(await r.text()).slice(0, 120)}`);
  } catch (e) {
    err('pushLiveActivity failed:', e.message);
  }
}

// Daily "today's #1 lock is in" push — fires after the 5am pick run.
// Sends the single highest-confidence pick of the day to everyone
// opted into 'picks'. Localized server-side by send-push.
async function sendDailyPickDrop() {
  try {
    const today = daysAgoISO(0);
    const { data: picks } = await supabase
      .from('picks')
      .select('pick, probability')
      .eq('game_date', today)
      .order('probability', { ascending: false })
      .limit(1);
    if (!picks || !picks.length) return;
    const top = picks[0];
    await sendPush({ key: 'pick_drop', prefKey: 'picks',
      args: { team: top.pick, conf: Math.round(top.probability || 0) } });
    log(`Push: pick_drop sent (${top.pick})`);
  } catch (e) { err('sendDailyPickDrop failed:', e.message); }
}

// Daily recap push — "you went X/Y, riding them all = +Z%". Only fires
// on net-positive days (the hook is the upside); silent on flat/down
// days so it never reads as a downer.
async function sendDailyRecap() {
  try {
    const y = daysAgoISO(1);
    const { data: picks } = await supabase
      .from('picks')
      .select('result, probability, market_odds')
      .eq('game_date', y)
      .in('result', ['win', 'loss']);
    if (!picks || !picks.length) return;
    const wins = picks.filter((p) => p.result === 'win').length;
    const games = picks.length;
    let units = 0;
    for (const p of picks) units += p.result === 'win' ? payoutPct(p) / 100 : -1;
    const roi = Math.round((units / games) * 100);
    if (roi <= 0) return;   // only hype profitable days
    await sendPush({ key: 'recap', prefKey: 'results', args: { wins, games, pct: roi } });
    log(`Push: recap sent (${wins}/${games}, +${roi}%)`);
  } catch (e) { err('sendDailyRecap failed:', e.message); }
}

async function liveTick() {
  if (liveLoopRunning) return;
  liveLoopRunning = true;
  try {
    // Pending picks from the last 3 days through tomorrow — covers
    // in-play games, ungraded finals, and tonight's event previews.
    const { data: picks, error } = await supabase
      .from('picks')
      .select('game_id, league, sport, home_team, away_team, game_date, pick, probability, market_odds')
      .eq('result', 'pending')
      .gte('game_date', daysAgoISO(3));
    if (error || !picks?.length) return;

    // Prior scores so we can detect *changes* and only push on real events
    // (a goal, or a game going final) — not every 2-minute poll.
    const gameIds = picks.map((p) => p.game_id).filter(Boolean);
    const prevById = {};
    if (gameIds.length) {
      const { data: prev } = await supabase
        .from('live_scores')
        .select('game_id, home_score, away_score, status')
        .in('game_id', gameIds);
      for (const r of prev || []) prevById[r.game_id] = r;
    }
    // Sports where each score is a discrete event worth a "they scored!"
    // push. High-frequency sports (basketball/baseball/football) only push
    // on final, to avoid spamming.
    const GOAL_SPORTS = new Set(['soccer', 'hockey']);
    const pushEvents = [];
    const laEvents = [];   // Live Activity (Apple Sports card) updates

    const byLeague = {};
    for (const p of picks) (byLeague[p.league] ||= []).push(p);
    const logoUpdates = [];

    for (const [league, leaguePicks] of Object.entries(byLeague)) {
      if (!ESPN_PATHS[league]) continue;
      const events = await espnScoreboard(league);
      if (!events.length) continue;

      const rows = [];
      for (const p of leaguePicks) {
        const ev = events.find((e) =>
          (teamsMatch(e.homeName, p.home_team) && teamsMatch(e.awayName, p.away_team)) ||
          (teamsMatch(e.homeName, p.away_team) && teamsMatch(e.awayName, p.home_team)));
        if (!ev || !p.game_id) continue;
        // Orient scores to OUR home/away columns (ESPN's home side may
        // be flipped relative to the pick row).
        const flipped = !teamsMatch(ev.homeName, p.home_team);
        const status = ev.state === 'post' ? 'Final'
          : ev.state === 'in' ? 'InProgress'
          : 'Scheduled';
        // Capture the real ESPN crest URLs (oriented to our columns)
        // so the app never needs a hardcoded team→logo map.
        const homeLogo = flipped ? ev.awayLogo : ev.homeLogo;
        const awayLogo = flipped ? ev.homeLogo : ev.awayLogo;
        if (homeLogo || awayLogo) {
          logoUpdates.push({ id: p.game_id, home_logo: homeLogo, away_logo: awayLogo,
                             pick_id: p.id });
        }
        const homeScore = flipped ? ev.awayScore : ev.homeScore;
        const awayScore = flipped ? ev.homeScore : ev.awayScore;
        rows.push({
          game_id: p.game_id,
          sport: p.sport,
          league,
          home_team: p.home_team,
          away_team: p.away_team,
          home_score: homeScore,
          away_score: awayScore,
          status,
          quarter: ev.period != null ? String(ev.period) : null,
          start_time: ev.startTime,
          updated_at: new Date().toISOString(),
        });

        // ── Per-game push automations (only on real events) ──────────
        const prev = prevById[p.game_id];
        const score = `${p.home_team} ${homeScore ?? 0}–${awayScore ?? 0} ${p.away_team}`;
        if (prev) {
          const scoreChanged =
            String(prev.home_score) !== String(homeScore) ||
            String(prev.away_score) !== String(awayScore);
          const scoreShort = `${homeScore ?? 0}–${awayScore ?? 0}`;

          // ── Live Activity (lock-screen / Dynamic Island) update ──
          // Pushed to the activity tokens for this game so the card
          // refreshes in the background, Apple Sports style.
          {
            const pl = (p.pick || '').toLowerCase();
            const pHome = p.home_team && pl.includes(p.home_team.toLowerCase());
            const pAway = p.away_team && pl.includes(p.away_team.toLowerCase());
            const hitting = pHome ? (homeScore ?? 0) >= (awayScore ?? 0)
                          : pAway ? (awayScore ?? 0) >= (homeScore ?? 0) : false;
            const isFinal = status === 'Final';
            const laState = {
              homeScore: homeScore ?? 0,
              awayScore: awayScore ?? 0,
              statusLine: isFinal ? 'FINAL' : (ev.period != null ? `LIVE · ${ev.period}` : 'LIVE'),
              pickHitting: hitting,
              isFinal,
            };
            if (isFinal && prev.status !== 'Final') {
              laEvents.push({ gameId: p.game_id, contentState: laState, event: 'end' });
            } else if (status === 'InProgress' && scoreChanged) {
              laEvents.push({ gameId: p.game_id, contentState: laState, event: 'update' });
            }
          }

          if (status === 'Final' && prev.status !== 'Final') {
            // Final whistle — celebrate a win, soft re-hook on a loss.
            // win/loss is the same for everyone (the AI's pick is global),
            // so this is per-game, not per-user.
            const homeWon = (homeScore ?? 0) > (awayScore ?? 0);
            const awayWon = (awayScore ?? 0) > (homeScore ?? 0);
            const pl = (p.pick || '').toLowerCase();
            let pickWon = null;
            if (pl.includes('draw')) pickWon = !homeWon && !awayWon;
            else if (p.home_team && pl.includes(p.home_team.toLowerCase())) pickWon = homeWon;
            else if (p.away_team && pl.includes(p.away_team.toLowerCase())) pickWon = awayWon;
            if (pickWon === true) {
              pushEvents.push({ key: 'result_win', prefKey: 'results',
                args: { team: p.pick, score: scoreShort, pct: payoutPct(p) } });
            } else if (pickWon === false) {
              pushEvents.push({ key: 'result_loss', prefKey: 'results',
                args: { score: scoreShort } });
            }
            // pickWon === null (couldn't map the pick to a side) → no push.
          } else if (status === 'InProgress' && scoreChanged && GOAL_SPORTS.has(p.sport)) {
            // A goal in a low-scoring sport — "as they score". Whichever
            // side's tally went up is the scorer. NOTE: still goes to all
            // 'live'-opted users; favorite-only targeting needs the
            // favorites→DB sync (separate follow-up) to pass userIds.
            const homeScored = String(prev.home_score) !== String(homeScore);
            const scorer = homeScored ? p.home_team : p.away_team;
            // favOnly → delivered only to users who favorited this game.
            pushEvents.push({ key: 'goal_fav', prefKey: 'live',
              favOnly: true, gameId: p.game_id,
              args: { score: scoreShort, team: scorer, league } });
          }
        }
      }
      if (rows.length) {
        const { error: e2 } = await supabase
          .from('live_scores')
          .upsert(rows, { onConflict: 'game_id' });
        if (e2) err(`live_scores upsert (${league}) failed:`, e2.message);
        else log(`ESPN ${league}: ${rows.length} score row(s) refreshed`);
      }
    }
    // Deliver Live Activity updates (no-op per game if nobody's tracking it).
    for (const la of laEvents) {
      await pushLiveActivity(la.gameId, la.contentState, la.event);
    }
    if (laEvents.length) log(`Live Activity: ${laEvents.length} update(s) pushed`);

    // Deliver any per-game pushes collected above (goals + finals).
    for (const ev of pushEvents) {
      if (ev.favOnly) {
        // Goal alerts go ONLY to users who favorited this game.
        const { data: favs } = await supabase
          .from('user_favorites').select('user_id').eq('game_id', ev.gameId);
        const userIds = (favs || []).map((f) => f.user_id);
        if (!userIds.length) continue;   // nobody favorited it → skip
        await sendPush({ key: ev.key, args: ev.args, prefKey: ev.prefKey, userIds });
      } else {
        await sendPush(ev);
      }
    }
    if (pushEvents.length) log(`Push: ${pushEvents.length} game event(s) sent`);
    // Write captured crest URLs onto the pick rows (one update each;
    // only the logo columns, so scores/results are untouched).
    for (const u of logoUpdates) {
      await supabase.from('picks')
        .update({ home_logo: u.home_logo, away_logo: u.away_logo })
        .eq('id', u.pick_id);
    }
    if (logoUpdates.length) log(`Crest URLs set on ${logoUpdates.length} pick(s)`);
  } catch (e) {
    err('Live tick crashed:', e.message);
  } finally {
    liveLoopRunning = false;
  }
}

/// Hourly grading tick — AI-free. Just runs gradePicks() against the
/// live_scores rows that sportsdata.io polling has populated. Cheap,
/// deterministic, no Claude in the loop.
let gradeLoopRunning = false;
async function gradeAndBackfillTick() {
  if (gradeLoopRunning) return;
  gradeLoopRunning = true;
  try {
    await gradePicks();
  } catch (e) {
    err('Grade tick crashed:', e.message);
  } finally {
    gradeLoopRunning = false;
  }
}

// ════════════════════════════════════════════════════════════════
// HEALTHCHECK HTTP ENDPOINT
// ════════════════════════════════════════════════════════════════
// Exposes GET /healthz on PORT (Railway auto-detects). Returns 200 if a
// pick was created in the last 36 hours (allowing a generous slack for
// weekend gaps or single missed runs), 503 otherwise. Wire UptimeRobot
// (free) → email alert on 503 to catch silent pipeline death within minutes.
const http = require('http');
const HEALTHZ_PORT = Number(process.env.PORT || 3000);

http.createServer(async (req, res) => {
  if (req.url !== '/healthz' && req.url !== '/') {
    res.writeHead(404); res.end('not found'); return;
  }
  try {
    const { data, error } = await supabase
      .from('picks')
      .select('created_at')
      .order('created_at', { ascending: false })
      .limit(1);
    if (error) throw error;
    const latest = data?.[0]?.created_at ? new Date(data[0].created_at) : null;
    const ageHours = latest ? (Date.now() - latest.getTime()) / 3_600_000 : Infinity;
    const ok = ageHours < 36;
    res.writeHead(ok ? 200 : 503, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok,
      latest_pick_at: latest?.toISOString() || null,
      age_hours: ageHours === Infinity ? null : +ageHours.toFixed(2),
      claude_cost_today_usd: +claudeCostUsd.toFixed(2),
      web_search_uses_today: webSearchUses,
    }));
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: e.message }));
  }
}).listen(HEALTHZ_PORT, () => {
  log(`🩺 Healthcheck listening on :${HEALTHZ_PORT}/healthz`);
});

// ════════════════════════════════════════════════════════════════
// SCHEDULES
// ════════════════════════════════════════════════════════════════

// Live-score refresh — every 5 minutes during the game window. Calls
// sportsdata.io only; no Claude spend. Active-league cache means we
// skip leagues with no games today entirely.
cron.schedule('*/2 * * * *', () => {
  const hour = parseInt(
    new Date().toLocaleTimeString('en-US', { timeZone: TZ, hour12: false, hour: '2-digit' }),
    10,
  );
  // Every 2 min in the game window (10am–1am ET) so live scores feel
  // near-real-time. ESPN's scoreboard is free + keyless, so the only
  // cost is bandwidth — no Claude/paid calls in this loop.
  if (hour >= 10 || hour <= 1) liveTick();
}, { timezone: TZ });

// Grade — once per HOUR during the game window. AI-free: just diffs
// pending picks against the sportsdata.io live_scores table.
cron.schedule('0 * * * *', () => {
  const hour = parseInt(
    new Date().toLocaleTimeString('en-US', { timeZone: TZ, hour12: false, hour: '2-digit' }),
    10,
  );
  if (hour >= 10 || hour <= 1) gradeAndBackfillTick();
}, { timezone: TZ });

// Pick generation — once daily at 5am ET. The ONLY Claude entry point.
// Grades yesterday, then generates today's picks across all leagues.
cron.schedule('0 5 * * *', async () => {
  await runPipeline();
  // Backfill crest URLs immediately so morning cards aren't logoless
  // until the first in-window live tick.
  try { await liveTick(); } catch (e) { err('post-run logo enrich failed:', e.message); }
  // Today's #1 pick is now in the DB — push it out.
  await sendDailyPickDrop();
}, { timezone: TZ });

// Daily performance snapshot at midnight ET (after final games grade).
cron.schedule('0 0 * * *', savePerformanceSnapshot, { timezone: TZ });

// Daily recap push at 9am ET — after the overnight slate has graded,
// before the morning's pick_drop competition. Hypes profitable days.
cron.schedule('0 9 * * *', sendDailyRecap, { timezone: TZ });

// NOTE — we intentionally do NOT run runPipeline() on boot. Every
// Railway redeploy used to fire a full pipeline run, which costs
// ~$2 in Anthropic credits per deploy. After a burst of commits
// that compounded to >$25 in two days. Cron is the only entry
// point now; manual triggering happens via the deploy schedule
// (push a commit at 4:59am ET to get a fresh pipeline at 5am).
//
// Exception: RUN_ON_BOOT=1 forces ONE pipeline run at startup, for
// manually backfilling a day after an outage. Unset the variable
// right after (with skip-deploys) or every restart will burn a run.
if (process.env.RUN_ON_BOOT === '1') {
  log('🔁 RUN_ON_BOOT=1 — running pipeline once at boot (backfill)');
  runPipeline().catch((e) => err('Boot pipeline run failed:', e.message));
}

log('⚡ Pick1 AI pipeline online');
log(`   Model:    ${ANTHROPIC_MODEL} (adaptive thinking, high effort)`);
log(`   Sports:   ${Object.values(LEAGUES).map((c) => c.sport).join(', ')}`);
log(`   Leagues:  ${Object.keys(LEAGUES).join(', ')}`);
log(`   Timezone: ${TZ}`);
log('   Live scores:    every 5min during game hours (sportsdata.io, AI-free, skips empty leagues)');
log('   Grade:          hourly during game hours (sportsdata.io diff, AI-free)');
log('   AI picks:       5am ET ONCE DAILY (the ONLY Claude entry point)');
log(`   Cost ceiling:   $${CLAUDE_DAILY_COST_LIMIT_USD}/day Claude hard cap (breaker trips on overshoot)`);
log('   Boot pipeline:  DISABLED (removed to stop per-deploy Anthropic burn)');
log('   Snapshot:       midnight ET');
log('   Healthcheck:    GET /healthz returns 200 if last pick < 36h old');

// ─── Boot-time Supabase diagnostic (safe — no secrets logged) ──
(async () => {
  try {
    const url = process.env.SUPABASE_URL || '';
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || '';
    const urlHost = url.replace(/^https?:\/\//, '').split('/')[0] || '(unset)';
    const keyLen = key.length;
    // Only log whether the key parses as a JWT and what role it claims.
    // Head/tail previews of a JWT add nothing to debugging but give a
    // log reader real recon (confirms a service-role token is on this
    // machine). Same for the REST body — status is what we need to know.
    let jwtRole = '(not-jwt)';
    try {
      const payload = JSON.parse(Buffer.from(key.split('.')[1], 'base64').toString('utf8'));
      jwtRole = payload.role || '(no-role-claim)';
    } catch (_) { /* not a JWT */ }
    log(`🔎 Supabase diag: url_host=${urlHost} key_len=${keyLen} jwt_role=${jwtRole}`);
    // Live REST round-trip — log status only, never body.
    const test = await axios.get(`${url}/rest/v1/picks?select=id&limit=1`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
      timeout: 10000,
      validateStatus: () => true,
    });
    log(`🔎 Supabase REST test: status=${test.status}`);
  } catch (e) {
    err('Supabase diag failed:', e.message);
  }
})();
