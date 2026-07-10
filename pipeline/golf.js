// golf.js — GROUNDED golf data layer (ESPN PGA Tour)
// ════════════════════════════════════════════════════════════════════
// A golf pick is a predicted tournament winner from a field — same shape
// as F1. This grounds the facts in ESPN's PGA feed: the tournament, the
// full field, and (when the event is underway) the live leaderboard —
// each player's position and score to par. Replaces model guesses about
// who's in form / leading with the real board.
//
// Player world ranking + multi-event form aren't exposed cleanly without
// per-athlete lookups, so v1 grounds tournament/field/leaderboard facts
// (the high-value, unambiguous ones) and leaves deeper history for later.

const UA = 'curl/8.4.0';
const SB = 'https://site.api.espn.com/apis/site/v2/sports/golf/pga/scoreboard';

async function getJSON(url) {
  for (let i = 0; i < 2; i++) {
    try { const r = await fetch(url, { headers: { 'User-Agent': UA } }); if (r.ok) return await r.json(); }
    catch { if (i) return null; }
  }
  return null;
}
function normKey(name) {
  return (name || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
}

// The current / next PGA tournament(s) with field + live board.
async function fetchTournaments() {
  const d = await getJSON(SB);
  const out = [];
  for (const e of d?.events || []) {
    const comp = e.competitions?.[0] || {};
    const state = e.status?.type?.state || 'pre';   // pre | in | post
    const players = (comp.competitors || []).map((c) => ({
      name: c.athlete?.displayName || c.athlete?.fullName,
      position: c.order != null ? Number(c.order) : null,
      score: c.score != null ? String(c.score) : null,
    })).filter((p) => p.name);
    out.push({ id: e.id, name: e.name, date: e.date, end_date: e.endDate, state, players });
  }
  return out;
}

function ord(n) { const i = parseInt(n, 10); return Number.isNaN(i) ? `${n}` : `${i}${['th','st','nd','rd'][(i%100>10&&i%100<14)?0:(i%10)]||'th'}`; }
function fmtScore(s) {
  if (s == null || s === '') return null;
  if (s === '0' || s === 'E') return 'E';
  return /^-/.test(String(s)) ? String(s) : `+${String(s).replace('+','')}`;
}

function findTournament(name, tournaments) {
  const k = normKey(name);
  return tournaments.find((t) => normKey(t.name) === k)
    || tournaments.find((t) => normKey(t.name).includes(k) || k.includes(normKey(t.name)))
    || (tournaments.length === 1 ? tournaments[0] : null);
}

// Grounded facts for a golf pick (the picked golfer in their tournament).
function golfFacts(playerName, tournament) {
  if (!tournament) return [];
  const rows = [];
  const me = (tournament.players || []).find((p) => normKey(p.name) === normKey(playerName));
  const leader = (tournament.players || []).find((p) => p.position === 1) || (tournament.players || [])[0];

  if (tournament.state === 'in' && me && me.position != null) {
    rows.push({ label: 'Current position', value: me.position === 1 ? `Leading at ${fmtScore(me.score) ?? '—'}` : `${ord(me.position)} at ${fmtScore(me.score) ?? '—'}` });
    if (leader && me.position !== 1) rows.push({ label: 'Leader', value: `${leader.name} at ${fmtScore(leader.score) ?? '—'}` });
  } else if (me) {
    rows.push({ label: 'Status', value: tournament.state === 'pre' ? 'In the field (not yet started)' : 'In the field' });
  }
  if (tournament.players?.length) rows.push({ label: 'Field', value: `${tournament.players.length} players` });
  rows.push({ label: 'Event', value: tournament.name });
  return rows.slice(0, 5);
}

async function enrichPicks(picks) {
  if (!picks?.length) return picks || [];
  const tournaments = await fetchTournaments();
  for (const p of picks) {
    const t = findTournament(p.home_team, tournaments);
    const facts = golfFacts(p.pick, t);   // p.pick = predicted golfer
    if (facts.length) p.matchup_facts = facts;
  }
  return picks;
}

module.exports = { fetchTournaments, findTournament, golfFacts, enrichPicks };

// CLI: node golf.js test "Scottie Scheffler"
if (require.main === module && process.argv[2] === 'test') {
  (async () => {
    const ts = await fetchTournaments();
    console.log('tournaments:', ts.map((t) => `${t.name} [${t.state}, ${t.players.length}]`).join(' | '));
    const who = process.argv[3] || ts[0]?.players?.[0]?.name;
    console.log('\nFACTS for', who);
    for (const f of golfFacts(who, ts[0])) console.log('  ' + f.label + ': ' + f.value);
  })().catch((e) => { console.error(e); process.exit(1); });
}
