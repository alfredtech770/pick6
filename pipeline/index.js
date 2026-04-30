// Pick6 AI Prediction Pipeline
// ─────────────────────────────────────────────────────────────────
// Pulls upcoming games from sportsdata.io / Ergast / web search,
// asks Claude Opus 4.7 for calibrated picks, writes them to
// Supabase, and grades completed picks against final scores.
//
// Coverage: 8 sports × ~10 leagues each (F1 = 1) = 71 leagues total.
// Primary leagues run sportsdata.io with research-mode fallback; the
// rest run pure research mode (Claude web_search). Each league is
// processed every cron tick — most return empty during off-season,
// which is a cheap Claude call with no rows written.
//
// Primary leagues (sportsdata.io feeds):
//   basketball  NBA      hockey   NHL      football  NFL
//   baseball    MLB      soccer   EPL      combat    UFC
//   f1          F1 (Ergast / jolpi.ca, free)
//
// Research-mode leagues (per sport, no fetcher):
//   basketball  NCAAB · EuroLeague · WNBA · NBL · CBA · Liga ACB ·
//               BSL · LBA · LNB Pro A
//   football    NCAAF · CFL · UFL · NCAA FCS · ELF · AFL (Aus) ·
//               Arena FB · LFA Brasil · CFB Bowl/CFP
//   baseball    NCAA · NPB · KBO · CPBL · LMB · LIDOM · ABL ·
//               MiLB · Cuban Serie Nacional
//   combat      Bellator · ONE · PFL · Boxing · Cage Warriors ·
//               RIZIN · KSW · K-1 · GLORY
//   soccer      La Liga · Bundesliga · Serie A · Ligue 1 · UCL ·
//               UEL · MLS · Liga MX · Brasileirão
//   cricket     IPL · BBL · PSL · CPL · The Hundred · T20 Blast ·
//               SA20 · ILT20 · MLC · International (Test/ODI/T20I)
//   hockey      KHL · SHL · Liiga · NL · DEL · Czech Extraliga ·
//               AHL · NCAA · IIHF (Worlds/Olympics/U20)
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

  // ════════════════════════════════════════════════════════════════
  // RESEARCH-MODE LEAGUES — Claude web_search drives the slate.
  // No sportsdata.io subscription required. Most are seasonal — they
  // return empty when off-season (cheap Claude call, no picks generated).
  // ════════════════════════════════════════════════════════════════

  // ─── BASKETBALL — 9 more (NBA already above) ─────────────────────
  NCAAB: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'NCAA Division I Men\'s Basketball — peaks during March Madness (Mar–Apr). Use web_search for today\'s games. AP Top 25 + KenPom rankings are key signals.',
  },
  EUROLEAGUE: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'EuroLeague — top European club basketball. Season Sep–Jun, regular season + playoffs. Real Madrid, Olympiacos, Panathinaikos, Fenerbahçe are perennial contenders.',
  },
  WNBA: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'WNBA — primary US women\'s basketball league. Season May–Sep. Use web_search for today\'s games.',
  },
  NBL_AU: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'NBL — Australian National Basketball League. Season Sep–Mar (so off-season Apr–Aug).',
  },
  CBA_CN: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'CBA — Chinese Basketball Association. Season Oct–Apr.',
  },
  LIGA_ACB: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'Liga ACB — top Spanish basketball league. Season Sep–Jun.',
  },
  BSL_TR: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'BSL — Turkish Basketball Süper Lig. Season Sep–May.',
  },
  LBA_IT: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'Lega Basket Serie A — top Italian basketball league. Season Sep–Jun.',
  },
  LNB_FR: {
    sport: 'basketball', promptMode: 'research', fetcher: null,
    notes: 'LNB Pro A (now Betclic Élite) — top French basketball league.',
  },

  // ─── FOOTBALL (American football, 9 more — NFL already above) ────
  NCAAF: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'NCAA Division I FBS Football — College Football. Season Aug–Jan (peak Sep–Dec, bowl games + CFP playoff Dec–Jan).',
  },
  CFL: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'CFL — Canadian Football League. Season Jun–Nov (Grey Cup ~Nov). Note: 12 men, 3 downs, 110-yard field — different strategy than NFL.',
  },
  UFL: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'UFL — United Football League (US spring football, merger of XFL + USFL). Season Mar–Jun.',
  },
  NCAA_FCS: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'NCAA Division I FCS Football — second tier of college football. Smaller schools, FCS Championship Jan.',
  },
  ELF: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'European League of Football — American football across Europe. Season Jun–Sep, championship game Sep.',
  },
  AFL_AU: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'AFL — Australian Football League (Australian Rules football). Season Mar–Sep, Grand Final ~late Sep.',
  },
  ARENA_FB: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'Arena Football League — indoor football. Season May–Aug.',
  },
  LFA_BR: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'Liga BFA / LFA Brasil — Brazilian American football league. Season Apr–Sep.',
  },
  CFB_BOWL: {
    sport: 'football', promptMode: 'research', fetcher: null,
    notes: 'NCAA Bowl Games + College Football Playoff — Dec–Jan only. Includes CFP semifinals, national championship, and ~40 minor bowl games.',
  },

  // ─── BASEBALL — 9 more (MLB already above) ───────────────────────
  NCAA_BSB: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'NCAA Division I Baseball — College World Series in June. Regular season Feb–May.',
  },
  NPB: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'NPB — Nippon Professional Baseball (Japan). Two leagues: Central + Pacific. Season Mar–Oct, Japan Series late Oct.',
  },
  KBO: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'KBO — Korea Baseball Organization. 10 teams. Season Mar–Oct.',
  },
  CPBL: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'CPBL — Chinese Professional Baseball League (Taiwan). Season Mar–Oct.',
  },
  LMB: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'LMB — Liga Mexicana de Béisbol. Season Apr–Sep.',
  },
  LIDOM: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'LIDOM — Dominican Winter League. Season Oct–Jan, Caribbean Series Feb.',
  },
  ABL_AU: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'ABL — Australian Baseball League. Season Nov–Feb.',
  },
  MILB: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'MiLB — Minor League Baseball (Triple-A, Double-A, etc.). Season Apr–Sep. Many MLB call-up signals.',
  },
  CUBAN_BSB: {
    sport: 'baseball', promptMode: 'research', fetcher: null,
    notes: 'Cuban National Series (Serie Nacional). Season Sep–Apr.',
  },

  // ─── COMBAT — 9 more (UFC already above) ─────────────────────────
  BELLATOR: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'Bellator MMA — second-largest MMA promotion in North America (now PFL-owned). One pick per main-card bout. Treat each fight independently.',
  },
  ONE_FC: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'ONE Championship — Asia\'s largest MMA + Muay Thai + kickboxing promotion. Pick winners of main + co-main events.',
  },
  PFL: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'PFL — Professional Fighters League. Regular-season + playoff format with $1M prizes per weight class.',
  },
  BOXING_WBC: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'Boxing — major world title fights (WBC/WBA/IBF/WBO). Pick winners of high-profile cards. Reach + style matchup + recent form.',
  },
  CAGE_WARRIORS: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'Cage Warriors — top European MMA promotion (UFC pipeline).',
  },
  RIZIN: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'RIZIN FF — Japan\'s top MMA promotion. Year-end show is a major event.',
  },
  KSW: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'KSW — Konfrontacja Sztuk Walki, Poland\'s top MMA promotion.',
  },
  K1: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'K-1 — kickboxing organization. Heavyweight + Lightweight Grand Prix tournaments.',
  },
  GLORY: {
    sport: 'combat', promptMode: 'research', fetcher: null,
    notes: 'GLORY Kickboxing — top international kickboxing promotion.',
  },

  // ─── SOCCER — 9 more (EPL already above) ─────────────────────────
  LA_LIGA: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'La Liga (Spain) — Real Madrid, Barcelona, Atlético Madrid lead. Season Aug–May. Skip likely draws.',
  },
  BUNDESLIGA: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Bundesliga (Germany) — Bayern Munich dominant. Season Aug–May (winter break Dec–mid Jan).',
  },
  SERIE_A: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Serie A (Italy) — Juventus, Inter Milan, AC Milan, Napoli, Roma top. Season Aug–May.',
  },
  LIGUE_1: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Ligue 1 (France) — PSG dominant. Season Aug–May.',
  },
  UCL: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'UEFA Champions League — top European club competition. Group stage Sep–Dec, knockouts Feb–May, final ~late May.',
  },
  UEL: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'UEFA Europa League — second-tier European club competition.',
  },
  MLS: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'MLS — Major League Soccer (US/Canada). Season Feb–Dec, MLS Cup playoffs Oct–Dec.',
  },
  LIGA_MX: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Liga MX (Mexico) — split into Apertura (Jul–Dec) + Clausura (Jan–May) tournaments.',
  },
  BRASILEIRAO: {
    sport: 'soccer', promptMode: 'research', fetcher: null,
    notes: 'Brazilian Série A (Brasileirão) — top Brazilian league. Season Apr–Dec.',
  },

  // ─── CRICKET — 9 more (IPL already above) ────────────────────────
  BBL_CRK: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'BBL — Big Bash League (Australia). T20. Season Dec–Jan.',
  },
  PSL_CRK: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'PSL — Pakistan Super League. T20. Season Feb–Mar.',
  },
  CPL_CRK: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'CPL — Caribbean Premier League. T20. Season Aug–Sep.',
  },
  HUNDRED: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'The Hundred — England 100-ball cricket tournament. Season Aug.',
  },
  T20_BLAST: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'Vitality T20 Blast — England county T20 league. Season May–Sep.',
  },
  SA20: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'SA20 — South Africa T20 league. Season Jan–Feb.',
  },
  ILT20: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'ILT20 — International League T20 (UAE). Season Jan–Feb.',
  },
  MLC: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'MLC — Major League Cricket (USA). T20. Season Jul.',
  },
  CRICKET_INTL: {
    sport: 'cricket', promptMode: 'research', fetcher: null,
    notes: 'International cricket — Test, ODI, and T20I matches between national teams. Always check the Future Tours Programme for today\'s fixtures.',
  },

  // ─── HOCKEY — 9 more (NHL already above) ─────────────────────────
  KHL: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'KHL — Kontinental Hockey League (Russia + neighbours). Season Sep–Apr.',
  },
  SHL: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'SHL — Svenska Hockeyligan (Sweden). Season Sep–Apr.',
  },
  LIIGA: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'Liiga — Finnish top hockey league. Season Sep–Apr.',
  },
  NL_CH: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'NL — National League (Switzerland). Season Sep–Apr.',
  },
  DEL: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'DEL — Deutsche Eishockey Liga (Germany). Season Sep–Apr.',
  },
  CZECH_EXTRA: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'Czech Extraliga — top Czech hockey league. Season Sep–Apr.',
  },
  AHL: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'AHL — American Hockey League (top NHL minor league). Season Oct–Apr + Calder Cup.',
  },
  NCAA_HKY: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'NCAA Division I Men\'s Hockey. Season Oct–Apr, Frozen Four early Apr.',
  },
  IIHF: {
    sport: 'hockey', promptMode: 'research', fetcher: null,
    notes: 'IIHF — International Ice Hockey Federation tournaments (World Championship May, Olympics every 4 years, World Juniors Dec/Jan).',
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
    const sportPlural = league === 'IPL' ? 'IPL cricket fixtures (and any notable T20I/Test internationals)'
      : league === 'NBA' ? 'NBA games'
      : league === 'NHL' ? 'NHL games'
      : league === 'NFL' ? 'NFL games'
      : league === 'MLB' ? 'MLB games'
      : league === 'EPL' ? 'EPL fixtures'
      : league === 'UFC' ? 'UFC fights'
      : `${league} matches`;
    return [
      ...header,
      `MODE: research. There is no curated feed available for ${league} today. Use web_search to find today's ${sportPlural}, then return picks for the best matchups (probability ≥55%). Aim for at least 1 pick if any games exist; 2–4 if the slate is full. Use the structured output schema. Empty array is only correct if literally zero games are scheduled today.`,
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

// Pick generation 3× daily, optimized for both European and US slates.
//
// 5am ET (10am UK / 11am CET) — Europe morning window
//   • EPL early Saturday kickoff (12:30 UK = 7:30am ET) — 2.5h lead
//   • La Liga / Bundesliga afternoon (15:00–17:00 CET) — 4h lead
//   • F1 Sunday races (14:00 CET = 8am ET) — 3h lead
//   • MLB matinees (1pm ET) — 8h lead
//   • Tennis Asia/Europe sessions
//
// 12pm ET (5pm UK / 6pm CET) — Europe evening + US start window
//   • EPL evening kickoff (17:30 UK = 12:30pm ET) — 30min lead
//   • Champions League / Europa (20:00 UK = 3pm ET) — 3h lead
//   • MLB day-in-progress + night-game lineups
//   • Early NBA/NHL games (7pm ET) — 7h lead
//
// 7pm ET (midnight UK / 1am CET) — US primetime window
//   • NBA / NHL / MLB primetime (mostly 7-10pm ET)
//   • NFL Sunday / Monday Night (8:20pm ET) — 80min lead
//   • UFC main cards (10pm ET) — 3h lead
//   • West-coast late starts (10pm ET)
cron.schedule('0 5,12,19 * * *', runPipeline, { timezone: TZ });

// Daily performance snapshot at midnight ET (after final games grade)
cron.schedule('0 0 * * *', savePerformanceSnapshot, { timezone: TZ });

runPipeline();

log('⚡ Pick6 AI pipeline online');
log(`   Model:    ${ANTHROPIC_MODEL} (adaptive thinking, max effort)`);
{
  const bySport = Object.values(LEAGUES).reduce((acc, c) => {
    acc[c.sport] = (acc[c.sport] || 0) + 1; return acc;
  }, {});
  const sportSummary = Object.entries(bySport)
    .map(([s, n]) => `${s}(${n})`)
    .join(', ');
  log(`   Coverage: ${Object.keys(LEAGUES).length} leagues — ${sportSummary}`);
}
log(`   Timezone: ${TZ}`);
log('   Live scores: every 60s during game hours');
log('   AI picks:    5am, 12pm, 7pm ET (3× daily, optimized for EU + US slates)');
log('   Snapshot:    midnight ET');

// ─── Boot-time Supabase diagnostic (safe — no secrets logged) ──
(async () => {
  try {
    const url = process.env.SUPABASE_URL || '';
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY || '';
    const urlHost = url.replace(/^https?:\/\//, '').split('/')[0] || '(unset)';
    const keyLen = key.length;
    const keyHead = key.slice(0, 4);
    const keyTail = key.slice(-4);
    let jwtRef = '(not-jwt)';
    let jwtRole = '(not-jwt)';
    try {
      const payload = JSON.parse(Buffer.from(key.split('.')[1], 'base64').toString('utf8'));
      jwtRef = payload.ref || '(no-ref-claim)';
      jwtRole = payload.role || '(no-role-claim)';
    } catch (_) { /* not a JWT */ }
    log(`🔎 Supabase diag: url_host=${urlHost} key_len=${keyLen} key_head=${keyHead} key_tail=${keyTail} jwt_ref=${jwtRef} jwt_role=${jwtRole}`);
    // Live REST round-trip
    const test = await axios.get(`${url}/rest/v1/picks?select=id&limit=1`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
      timeout: 10000,
      validateStatus: () => true,
    });
    log(`🔎 Supabase REST test: status=${test.status} body=${JSON.stringify(test.data).slice(0, 200)}`);
  } catch (e) {
    err('Supabase diag failed:', e.message);
  }
})();
