// f1.js — GROUNDED F1 data layer (ESPN driver championship)
// ════════════════════════════════════════════════════════════════════
// An F1 pick is a predicted race winner, so the grounded facts are about
// the PICKED DRIVER + the title race: championship position, points, gap
// to the leader, and recent race finishes. All from ESPN's F1 standings
// (each driver row carries per-race finishing positions). Replaces the
// model's web-searched driver claims.

const UA = 'curl/8.4.0';
const STAND = 'https://site.api.espn.com/apis/v2/sports/racing/f1/standings';

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

// Find the driver-standings entries wherever ESPN nests them.
function findEntries(o) {
  if (Array.isArray(o)) { for (const v of o) { const r = findEntries(v); if (r) return r; } return null; }
  if (o && typeof o === 'object') {
    if (o.standings?.entries?.length && o.standings.entries[0].athlete) return o.standings.entries;
    for (const v of Object.values(o)) { const r = findEntries(v); if (r) return r; }
  }
  return null;
}

async function fetchDriverStandings() {
  const d = await getJSON(STAND);
  const entries = findEntries(d) || [];
  const drivers = [];
  for (const e of entries) {
    const name = e.athlete?.displayName;
    if (!name) continue;
    const stats = e.stats || [];
    const get = (n) => stats.find((s) => s.name === n)?.displayValue;
    // Per-race finishes: 3-letter uppercase stat names (AUS, CHN, …), in
    // season order; keep the ones that actually have a result.
    // Per-race finishes: 3-letter race columns whose value is an actual
    // result (a position number or DNF/DSQ) — future/unraced rounds come
    // back blank and must be excluded.
    const races = stats
      .filter((s) => /^[A-Z]{3}$/.test(s.name || '')
        && s.displayValue && /^(\d+|DNF|DSQ|DNS)$/i.test(s.displayValue.trim()))
      .map((s) => ({ race: s.name, pos: s.displayValue.trim() }));
    drivers.push({
      name,
      rank: get('rank'),
      points: get('championshipPts') || get('points'),
      recent: races.slice(-3),
    });
  }
  const byKey = new Map(drivers.map((d) => [normKey(d.name), d]));
  const leader = drivers.find((d) => String(d.rank) === '1') || drivers[0] || null;
  return { byKey, leader };
}

// Grounded facts for an F1 pick (the picked driver).
function f1Facts(driverName, standings) {
  if (!standings) return [];
  const d = standings.byKey.get(normKey(driverName));
  if (!d) return [];
  const rows = [];
  const ord = (n) => { const i = parseInt(n, 10); return Number.isNaN(i) ? n : `${i}${['th','st','nd','rd'][(i%100>10&&i%100<14)?0:(i%10)]||'th'}`; };
  if (d.rank) rows.push({ label: 'Championship', value: `${d.name} — ${ord(d.rank)}, ${d.points ?? '—'} pts` });
  const lead = standings.leader;
  if (lead && String(d.rank) !== '1') {
    const gap = (Number(lead.points) - Number(d.points));
    const gapStr = Number.isFinite(gap) ? `, +${gap} ahead` : '';
    rows.push({ label: 'Title leader', value: `${lead.name} — ${lead.points} pts${gapStr}` });
  }
  // NOTE: ESPN's per-race columns are POINTS scored (incl. sprints), not
  // finishing positions — ambiguous to present, so deliberately omitted.
  return rows.slice(0, 5);
}

async function enrichPicks(picks) {
  if (!picks?.length) return picks || [];
  const standings = await fetchDriverStandings();
  for (const p of picks) {
    const facts = f1Facts(p.pick, standings);   // p.pick = predicted driver
    if (facts.length) p.matchup_facts = facts;
  }
  return picks;
}

module.exports = { fetchDriverStandings, f1Facts, enrichPicks };

// CLI: node f1.js test "Lando Norris"
if (require.main === module && process.argv[2] === 'test') {
  (async () => {
    const s = await fetchDriverStandings();
    console.log('leader:', s.leader?.name, s.leader?.points, 'pts');
    const who = process.argv[3] || s.leader?.name;
    console.log('\nFACTS for', who);
    for (const f of f1Facts(who, s)) console.log('  ' + f.label + ': ' + f.value);
  })().catch((e) => { console.error(e); process.exit(1); });
}
