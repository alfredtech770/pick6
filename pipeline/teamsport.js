// teamsport.js — GROUNDED data layer for ESPN's major team leagues
// ════════════════════════════════════════════════════════════════════
// One module for baseball / basketball / football / hockey — ESPN's
// standings + scoreboard share a shape across them, so the same code
// grounds MLB, NBA, WNBA, NFL, NHL. Replaces the model's web-searched
// (confabulation-prone) matchup facts with real season data: record,
// win%, streak, run/point differential, home/road splits — plus probable
// starting pitchers for baseball (the dominant variable in a pick).
//
// ESPN does NOT carry KBO / NPB / EuroLeague, so those are intentionally
// absent here and stay on the model path with a limited-data flag.

const UA = 'curl/8.4.0';
const SITE = 'https://site.api.espn.com/apis/site/v2/sports';
const CORE = 'https://site.api.espn.com/apis/v2/sports';

// league code (as used in LEAGUES / picks) → ESPN sport/path
const PATHS = {
  MLB: 'baseball/mlb',
  NBA: 'basketball/nba',
  WNBA: 'basketball/wnba',
  NFL: 'football/nfl',
  NHL: 'hockey/nhl',
};
const isSupported = (league) => !!PATHS[league];

async function getJSON(url) {
  for (let i = 0; i < 2; i++) {
    try { const r = await fetch(url, { headers: { 'User-Agent': UA } }); if (r.ok) return await r.json(); }
    catch { if (i) return null; }
  }
  return null;
}

function normKey(name) {
  return (name || '').toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
}

const num = (entry, name) => {
  const s = (entry.stats || []).find((x) => x.name === name);
  return s ? s.displayValue : null;
};

// normalized team name (+ a few aliases) → standings row
async function fetchStandings(league) {
  const path = PATHS[league];
  if (!path) return new Map();
  const d = await getJSON(`${CORE}/${path}/standings`);
  const map = new Map();
  for (const group of d?.children || []) {
    const division = group.name || '';
    for (const e of group.standings?.entries || []) {
      const name = e.team?.displayName || e.team?.shortDisplayName;
      if (!name) continue;
      const w = num(e, 'wins'), l = num(e, 'losses');
      map.set(normKey(name), {
        team: name, division,
        record: (w != null && l != null) ? `${w}-${l}` : null,
        winPct: num(e, 'winPercent'),
        streak: num(e, 'streak'),
        gamesBehind: num(e, 'gamesBehind'),
        forAvg: num(e, 'avgPointsFor'),
        againstAvg: num(e, 'avgPointsAgainst'),
        diff: num(e, 'differential'),
        homeRec: (num(e, 'homeWins') != null) ? `${num(e, 'homeWins')}-${num(e, 'homeLosses')}` : null,
        roadRec: (num(e, 'roadWins') != null) ? `${num(e, 'roadWins')}-${num(e, 'roadLosses')}` : null,
      });
    }
  }
  return map;
}

// matchup key → { home: pitcher, away: pitcher } for baseball
async function fetchProbables(league) {
  const out = new Map();
  if (league !== 'MLB') return out;
  const d = await getJSON(`${SITE}/${PATHS[league]}/scoreboard`);
  for (const ev of d?.events || []) {
    for (const c of ev.competitions?.[0]?.competitors || []) {
      const team = c.team?.displayName;
      const p = (c.probables || [])[0]?.athlete;
      if (team && p?.displayName) out.set(normKey(team), p.displayName);
    }
  }
  return out;
}

// Scoring label is sport-specific (runs vs points vs goals).
function scoringLabel(league) {
  if (league === 'MLB') return 'Runs/game';
  if (league === 'NHL') return 'Goals/game';
  return 'Points/game';
}

function teamProfile(name, standings, probables) {
  const s = standings.get(normKey(name));
  const pitcher = probables.get(normKey(name)) || null;
  if (!s) return { name, found: false, pitcher };
  return { name, found: true, pitcher, ...s };
}

async function buildComparison(league, homeTeam, awayTeam) {
  const [standings, probables] = await Promise.all([fetchStandings(league), fetchProbables(league)]);
  const home = teamProfile(homeTeam, standings, probables);
  const away = teamProfile(awayTeam, standings, probables);
  if (!home.found && !away.found) return null;
  return { league, home, away };
}

// Grounded single-column matchup facts (replaces model facts).
function comparisonFacts(comp) {
  if (!comp) return [];
  const { home: h, away: a, league } = comp;
  const rows = [];
  const both = (label, hv, av) => { if (hv != null || av != null) rows.push({ label, value: `${h.name} ${hv ?? '—'} · ${a.name} ${av ?? '—'}` }); };
  both('Record', h.record, a.record);
  both('Win %', h.winPct, a.winPct);
  both('Streak', h.streak, a.streak);
  if (h.forAvg || a.forAvg) {
    rows.push({ label: scoringLabel(league), value: `${h.name} ${h.forAvg ?? '—'} (${h.againstAvg ?? '—'} allowed) · ${a.name} ${a.forAvg ?? '—'} (${a.againstAvg ?? '—'})` });
  }
  if (h.homeRec || a.roadRec) {
    rows.push({ label: 'Home / Road', value: `${h.name} ${h.homeRec ?? '—'} home · ${a.name} ${a.roadRec ?? '—'} road` });
  }
  if (h.pitcher || a.pitcher) {
    rows.push({ label: 'Probable SP', value: `${h.name} ${h.pitcher ?? 'TBD'} · ${a.name} ${a.pitcher ?? 'TBD'}` });
  }
  return rows.slice(0, 6);
}

// Batch-enrich picks for a league: fetch once, rebuild facts + store the
// structured comparison (mirrors soccer.enrichPicks).
async function enrichPicks(league, picks) {
  if (!isSupported(league) || !picks?.length) return picks || [];
  const [standings, probables] = await Promise.all([fetchStandings(league), fetchProbables(league)]);
  for (const p of picks) {
    const home = teamProfile(p.home_team, standings, probables);
    const away = teamProfile(p.away_team, standings, probables);
    if (!home.found && !away.found) continue;
    const comp = { league, home, away };
    const facts = comparisonFacts(comp);
    if (facts.length) { p.matchup_facts = facts; p.team_comparison = comp; }
  }
  return picks;
}

module.exports = { isSupported, fetchStandings, fetchProbables, buildComparison, comparisonFacts, enrichPicks, PATHS };

// CLI: node teamsport.js test MLB "New York Yankees" "Boston Red Sox"
if (require.main === module && process.argv[2] === 'test') {
  (async () => {
    const comp = await buildComparison(process.argv[3] || 'MLB', process.argv[4] || 'New York Yankees', process.argv[5] || 'Boston Red Sox');
    console.log(JSON.stringify(comp, null, 1));
    console.log('\nFACTS:');
    for (const f of comparisonFacts(comp)) console.log('  ' + f.label + ': ' + f.value);
  })().catch((e) => { console.error(e); process.exit(1); });
}
