// Pick6 AI Prediction Pipeline
// ─────────────────────────────────────────────────────────────────
// Pulls upcoming games from sportsdata.io / Ergast / web search,
// asks Claude Opus 4.7 for calibrated picks, writes them to
// Supabase, and grades completed picks against final scores.
//
// Coverage: 8 sports across 8 leagues
//   basketball  NBA   sportsdata.io
//   hockey      NHL   sportsdata.io
//   football    NFL   sportsdata.io
//   baseball    MLB   sportsdata.io
//   soccer      EPL   sportsdata.io (soccer endpoint)
//   combat      UFC   sportsdata.io (MMA endpoint)
//   f1          F1    Ergast API (free, no auth)
//   tennis      ATP   Claude's web_search tool (no public schedule API)
//
// Add a new league by appending to the LEAGUES registry below.

require('dotenv').config();

const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const cron = require('node-cron');
const axios = require('axios');

// ─── Config ────────────────────────────────────────────────────
const ANTHROPIC_MODEL = 'claude-opus-4-7';
const TZ = 'America/New_York';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
  // SDK auto-retries 408/409/429/5xx with exponential backoff.
  maxRetries: 4,
});
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY,
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
async function sdFetch(path) {
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
    const window = 3 * 24 * 60 * 60 * 1000; // next 72h
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
  UFC: {
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

  // ─── Tennis — research mode; Claude web-searches today's slate ─
  ATP: {
    sport: 'tennis', promptMode: 'research', fetcher: null,
    notes: 'Use web_search to find today\'s notable matches (Grand Slams, ATP/WTA 1000s/500s). Surface 3–8 picks max — quality over quantity.',
  },
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
    return 'No meaningful track record yet for this league. Be conservative — favor higher-confidence picks until calibration is established.';
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

const SYSTEM_PROMPT = `You are the prediction engine behind Pick6, a premium sports prediction app.

Your job: analyze each matchup and return picks ONLY where you have genuine, calibrated edge.

Required reasoning before committing to a pick:
1. Recent form, records, and head-to-head history.
2. Sport-specific context (home advantage, weather, fatigue, surface, circuit, weight class…).
3. Personnel: injuries, scratches, rest, probable starters/lineups. USE web_search to verify late-breaking news.
4. Calibration: if you say 80%, you should win 80% of the time long-run.

Hard rules:
- Only return picks where your true probability is ≥ 65%. Skip coin flips.
- Singles only — no parlays, no multi-leg.
- The "pick" field MUST be EXACTLY one of {home_team, away_team} from the input. Do not invent strings.
- Probability is an integer 65–97.
- Confidence: "***" for 80%+, "**" for 65–79%. Never "*".
- Reasoning: 2–3 punchy sentences explaining WHY.
- Key factor: the single biggest reason in 6–10 words.
- When uncertain, return fewer picks. Skipping is always allowed and often correct.

For SOCCER (EPL): if you expect a draw, do not return a pick for that match.
For COMBAT (UFC): treat each fight as an independent prediction.
For F1: home_team is the race name, away_team is "Field"; "pick" is the predicted winning driver's full name (NOT one of home_team/away_team — for F1 only, return the driver's name as the pick).
For TENNIS: research today's slate via web_search; only surface notable matches with clear edges.`;

const PICK_SCHEMA = {
  type: 'object',
  properties: {
    picks: {
      type: 'array',
      description: 'Array of high-confidence picks. May be empty if no matchup clears the bar.',
      items: {
        type: 'object',
        properties: {
          game_id: { type: 'string' },
          home_team: { type: 'string' },
          away_team: { type: 'string' },
          pick: { type: 'string', description: 'The team/fighter/driver picked. For team sports must equal home_team or away_team. For F1, the driver name.' },
          probability: {
            type: 'integer',
            description: 'Integer 65-97. Below 65 means skip the matchup, do not return a pick.',
          },
          confidence: { type: 'string', enum: ['***', '**'] },
          reasoning: { type: 'string' },
          key_factor: { type: 'string' },
        },
        required: ['game_id', 'home_team', 'away_team', 'pick', 'probability', 'confidence', 'reasoning', 'key_factor'],
        additionalProperties: false,
      },
    },
  },
  required: ['picks'],
  additionalProperties: false,
};

function buildUserPrompt(league, games, stats30, stats7, forceResearch = false) {
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
    const sportPlural = league === 'ATP' ? 'ATP and WTA tournaments'
      : league === 'NBA' ? 'NBA games'
      : league === 'NHL' ? 'NHL games'
      : league === 'NFL' ? 'NFL games'
      : league === 'MLB' ? 'MLB games'
      : league === 'EPL' ? 'EPL fixtures'
      : league === 'UFC' ? 'UFC fights'
      : `${league} matches`;
    return [
      ...header,
      `MODE: research. There is no curated feed available for ${league} today. Use web_search to find today's ${sportPlural}. Predict winners only where you have a clear, justifiable edge (≥65%). Return your picks via the structured output schema.`,
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
  ].join('\n');
}

async function getClaudePicks(league, games, { forceResearch = false } = {}) {
  const cfg = LEAGUES[league];
  const useResearch = cfg.promptMode === 'research' || forceResearch;
  const stats30 = await getPerformanceStats(league, 30);
  const stats7 = await getPerformanceStats(league, 7);
  const userPrompt = buildUserPrompt(league, games, stats30, stats7, forceResearch);

  const stream = anthropic.messages.stream({
    model: ANTHROPIC_MODEL,
    max_tokens: 16000,
    thinking: { type: 'adaptive' },
    output_config: {
      effort: 'max',
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

  const text = final.content.find((b) => b.type === 'text')?.text;
  if (!text) {
    err(`Claude ${league}: no text block in response`);
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
  // enforce it here. For team sports the pick must equal one of the
  // matchup names; F1 + research-mode picks are exempt because the
  // pick is a driver/player name resolved from web search.
  const picks = (parsed.picks || []).filter((p) => {
    if (typeof p.probability !== 'number' || p.probability < 65 || p.probability > 97) return false;
    if (!p.pick || typeof p.pick !== 'string') return false;
    if (cfg.promptMode === 'race') return true;
    if (useResearch) {
      // Research mode — Claude resolved the matchup itself; just
      // require pick to be one of the names it surfaced.
      return p.pick === p.home_team || p.pick === p.away_team;
    }
    return p.pick === p.home_team || p.pick === p.away_team;
  });

  log(`Generated ${picks.length} picks for ${league}${useResearch ? ' (research mode)' : ''}.`);
  return picks;
}

// ════════════════════════════════════════════════════════════════
// SUPABASE — write picks + scores, grade results
// ════════════════════════════════════════════════════════════════

async function savePicks(league, picks) {
  if (!picks.length) return;
  const sport = LEAGUES[league].sport;
  const game_date = todayISO();

  const rows = picks.map((p) => ({
    sport,
    league,
    game_date,
    game_id: p.game_id,
    home_team: p.home_team,
    away_team: p.away_team,
    pick: p.pick,
    probability: p.probability,
    confidence: p.confidence,
    reasoning: p.reasoning,
    key_factor: p.key_factor,
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

    // F1 / tennis / non-team picks: pick is a name, not home/away.
    // Skip auto-grading for these — flag them for manual review or
    // hook up a sport-specific grader later.
    const isHeadToHead = pick.pick === pick.home_team || pick.pick === pick.away_team;
    if (!isHeadToHead) continue;

    const homeWon = score.home_score > score.away_score;
    const pickedHome = pick.pick === pick.home_team;
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
  try {
    for (const [league, cfg] of Object.entries(LEAGUES)) {
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
          // De-dup against today's already-saved picks.
          const { data: existing } = await supabase
            .from('picks')
            .select('game_id')
            .eq('league', league)
            .eq('game_date', todayISO());
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

    await gradePicks();
  } catch (e) {
    err('Pipeline crashed:', e.stack || e.message);
  } finally {
    pipelineRunning = false;
    log('■ Pipeline run complete');
  }
}

// ════════════════════════════════════════════════════════════════
// LIVE LOOP — refresh scores + grade pending picks during games
// ════════════════════════════════════════════════════════════════

let liveLoopRunning = false;

async function liveTick() {
  if (liveLoopRunning) return;
  liveLoopRunning = true;
  try {
    for (const [league, cfg] of Object.entries(LEAGUES)) {
      if (cfg.promptMode === 'research') continue;
      if (!cfg.fetcher) continue;
      const raw = await cfg.fetcher();
      if (raw.length) await upsertLiveScores(league, raw);
    }
    await gradePicks();
  } catch (e) {
    err('Live tick crashed:', e.message);
  } finally {
    liveLoopRunning = false;
  }
}

// ════════════════════════════════════════════════════════════════
// SCHEDULES
// ════════════════════════════════════════════════════════════════

cron.schedule('* * * * *', () => {
  const hour = parseInt(
    new Date().toLocaleTimeString('en-US', { timeZone: TZ, hour12: false, hour: '2-digit' }),
    10,
  );
  // 10am – 1am ET window covers MLB doubleheaders + west-coast late games.
  if (hour >= 10 || hour <= 1) liveTick();
}, { timezone: TZ });

// Pick generation 3× daily — morning, afternoon, night.
// 9am  → catches all afternoon starts (MLB, EPL, NHL day games)
// 3pm  → catches evening starts + late injury/lineup news
// 9pm  → catches west-coast late games + UFC main cards
cron.schedule('0 9,15,21 * * *', runPipeline, { timezone: TZ });

// Daily performance snapshot at midnight ET (after final games grade)
cron.schedule('0 0 * * *', savePerformanceSnapshot, { timezone: TZ });

runPipeline();

log('⚡ Pick6 AI pipeline online');
log(`   Model:    ${ANTHROPIC_MODEL} (adaptive thinking, max effort)`);
log(`   Sports:   ${Object.values(LEAGUES).map((c) => c.sport).join(', ')}`);
log(`   Leagues:  ${Object.keys(LEAGUES).join(', ')}`);
log(`   Timezone: ${TZ}`);
log('   Live scores: every 60s during game hours');
log('   AI picks:    9am, 3pm, 9pm ET (3× daily)');
log('   Snapshot:    midnight ET');
