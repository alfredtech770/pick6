// soccer.js — GROUNDED soccer data layer (Summer Cup / World Cup first)
// ════════════════════════════════════════════════════════════════════
// Same lesson as combat: the research-mode model can confabulate group
// standings, scorelines, and betting lines. This module replaces those
// with REAL data from ESPN's World Cup feed — group, position, points,
// W-D-L record, goals for/against, and recent form (last 5). The picks'
// matchup facts are rebuilt from this so nothing on the card is invented.
//
// Source: ESPN public soccer API, competition slug `fifa.world`.
//   - /standings → group, rank, points, played, W-D-L, GF, GA per team
//   - /scoreboard → per-team `form` (e.g. "WWDWL") when the team is in
//     a recent/visible fixture
// No API key. National-team names are matched on a normalized key.

const UA = 'curl/8.4.0';
const SB = 'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard';
const STAND = 'https://site.api.espn.com/apis/v2/sports/soccer/fifa.world/standings';

async function getJSON(url) {
  for (let i = 0; i < 2; i++) {
    try { const r = await fetch(url, { headers: { 'User-Agent': UA } }); if (r.ok) return await r.json(); }
    catch { if (i) return null; }
  }
  return null;
}

function normKey(name) {
  return (name || '')
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')   // strip accents
    .replace(/\bcabo verde\b/, 'cape verde')            // feed name drift
    .replace(/\bkorea republic\b/, 'south korea')
    .replace(/\busa\b/, 'united states')
    .replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
}

const stat = (entry, name) => {
  const s = (entry.stats || []).find((x) => x.name === name);
  return s ? s.displayValue : null;
};

// Map normalized team name → standings row.
async function fetchStandings() {
  const d = await getJSON(STAND);
  const map = new Map();
  for (const group of d?.children || []) {
    const groupName = group.name || group.abbreviation || '';
    for (const e of group.standings?.entries || []) {
      const name = e.team?.displayName || e.team?.name;
      if (!name) continue;
      map.set(normKey(name), {
        team: name,
        group: groupName,
        rank: stat(e, 'rank'),
        points: stat(e, 'points'),
        played: stat(e, 'gamesPlayed'),
        wins: stat(e, 'wins'),
        draws: stat(e, 'ties'),
        losses: stat(e, 'losses'),
        gf: stat(e, 'pointsFor'),
        ga: stat(e, 'pointsAgainst'),
      });
    }
  }
  return map;
}

// Map normalized team name → recent form string ("WWDWL").
async function fetchForm() {
  const d = await getJSON(SB);
  const map = new Map();
  for (const ev of d?.events || []) {
    for (const c of ev.competitions?.[0]?.competitors || []) {
      const name = c.team?.displayName || c.team?.name;
      if (name && c.form) map.set(normKey(name), c.form);
    }
  }
  return map;
}

const ord = (n) => { const i = parseInt(n, 10); return Number.isNaN(i) ? n : `${i}${['th', 'st', 'nd', 'rd'][(i % 100 > 10 && i % 100 < 14) ? 0 : (i % 10)] || 'th'}`; };
const spacedForm = (f) => (f || '').split('').join(' ');

// Per-team grounded profile for the FORM GUIDE side-by-side.
function teamProfile(name, standings, forms) {
  const s = standings.get(normKey(name));
  if (!s) return { name, found: false };
  return {
    name, found: true,
    group: s.group, position: s.rank ? ord(s.rank) : null, points: s.points,
    record: (s.wins != null) ? `${s.wins}-${s.draws}-${s.losses}` : null,
    goalsFor: s.gf, goalsAgainst: s.ga, played: s.played,
    form: forms.get(normKey(name)) || null,
  };
}

async function buildSoccerComparison(homeTeam, awayTeam) {
  const [standings, forms] = await Promise.all([fetchStandings(), fetchForm()]);
  const home = teamProfile(homeTeam, standings, forms);
  const away = teamProfile(awayTeam, standings, forms);
  if (!home.found && !away.found) return null;
  return { home, away, competition: home.group || away.group || 'Group Stage' };
}

// Grounded matchup facts (single-column list) — replaces model facts.
function soccerComparisonFacts(comp) {
  if (!comp) return [];
  const { home: h, away: a } = comp;
  const rows = [];
  const both = (label, hv, av) => { if (hv != null || av != null) rows.push({ label, value: `${h.name} ${hv ?? '—'} · ${a.name} ${av ?? '—'}` }); };
  if ((h.position || a.position) && (h.group || a.group)) {
    rows.push({ label: 'Group standing', value: `${h.name} ${h.position ?? '—'} · ${a.name} ${a.position ?? '—'}` });
  }
  both('Points', h.points, a.points);
  both('Record (W-D-L)', h.record, a.record);
  if (h.goalsFor != null || a.goalsFor != null) {
    rows.push({ label: 'Goals (GF-GA)', value: `${h.name} ${h.goalsFor ?? '—'}-${h.goalsAgainst ?? '—'} · ${a.name} ${a.goalsFor ?? '—'}-${a.goalsAgainst ?? '—'}` });
  }
  if (h.form || a.form) {
    rows.push({ label: 'Recent form', value: `${h.name} ${spacedForm(h.form) || '—'} · ${a.name} ${spacedForm(a.form) || '—'}` });
  }
  return rows.slice(0, 6);
}

// Enrich a batch of picks in one shot: fetch standings + form ONCE, then
// rebuild each pick's matchup_facts from grounded data. Returns the picks
// with `matchup_facts` (and a structured `soccer_comparison`) replaced
// where ESPN has both teams; untouched otherwise.
async function enrichPicks(picks) {
  if (!picks?.length) return picks || [];
  const [standings, forms] = await Promise.all([fetchStandings(), fetchForm()]);
  for (const p of picks) {
    const home = teamProfile(p.home_team, standings, forms);
    const away = teamProfile(p.away_team, standings, forms);
    if (!home.found && !away.found) continue;
    const comp = { home, away, competition: home.group || away.group || 'Group Stage' };
    const facts = soccerComparisonFacts(comp);
    if (facts.length) { p.matchup_facts = facts; p.soccer_comparison = comp; }
  }
  return picks;
}

module.exports = { fetchStandings, fetchForm, buildSoccerComparison, soccerComparisonFacts, teamProfile, enrichPicks };

// CLI test: `node soccer.js test "Spain" "Uruguay"`
if (require.main === module && process.argv[2] === 'test') {
  (async () => {
    const comp = await buildSoccerComparison(process.argv[3] || 'Spain', process.argv[4] || 'Uruguay');
    console.log(JSON.stringify(comp, null, 1));
    console.log('\nFACTS:');
    for (const f of soccerComparisonFacts(comp)) console.log('  ' + f.label + ': ' + f.value);
  })().catch((e) => { console.error(e); process.exit(1); });
}
