// images.js — server-side crest/headshot capture.
//
// The app resolved logos client-side (per-device ESPN/TheSportsDB search),
// which is slow and gets rate-limited on a real phone — so obscure teams
// (UCL qualifiers, KBO/NPB, associate cricket) showed the colored-shield
// placeholder "a lot". This module resolves each team's real crest ONCE,
// server-side, verifies it actually loads, and writes it to
// picks.home_logo / away_logo. The app reads those columns first
// (TeamLogoStore), so every team paints its real crest instantly with no
// client search.
//
// Source order: ESPN team search (US majors + big soccer) → TheSportsDB
// (broad international: KBO/NPB, UCL minnows, associate cricket). Both are
// the exact hosts the app already hot-links, so no new dependency.
//
// National teams (World Cup soccer, international cricket) are intentionally
// LEFT for the app's country-flag path — a stored crest is harmless there
// (the app's wcFlagCode check wins first) so we still resolve them; it just
// isn't the primary visual.

const TEAM_SPORTS = new Set(['soccer', 'basketball', 'baseball', 'hockey', 'cricket']);
const ESPN_SPORT = { soccer: 'soccer', basketball: 'basketball', baseball: 'baseball', hockey: 'hockey', cricket: 'cricket' };
const SDB_SPORT = { soccer: 'Soccer', basketball: 'Basketball', baseball: 'Baseball', hockey: 'Ice Hockey', cricket: 'Cricket' };

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJSON(url, timeoutMs = 10000) {
  try {
    const ctl = AbortSignal.timeout(timeoutMs);
    const r = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' }, signal: ctl });
    if (!r.ok) return null;
    return await r.json();
  } catch { return null; }
}

// HEAD-ish check: the badge/crest URL actually returns an image.
async function loads(url) {
  if (!url) return false;
  try {
    const r = await fetch(url, { method: 'GET', headers: { 'User-Agent': 'Mozilla/5.0' }, signal: AbortSignal.timeout(8000) });
    if (!r.ok) return false;
    const ct = r.headers.get('content-type') || '';
    return ct.startsWith('image');
  } catch { return false; }
}

async function espnLogo(sport, name) {
  const d = await getJSON(`https://site.api.espn.com/apis/search/v2?query=${encodeURIComponent(name)}&limit=8`);
  if (!d) return null;
  for (const r of d.results || []) {
    for (const c of r.contents || []) {
      if (c.type === 'team' && c.sport === ESPN_SPORT[sport]) {
        const img = c.image;
        const u = typeof img === 'object' ? img?.default : (typeof img === 'string' ? img : null);
        if (u) return u;
      }
    }
  }
  return null;
}

async function sportsDBLogo(sport, name) {
  // Some clubs only match with an "FC"/"FK"/"SC" suffix.
  const variants = sport === 'soccer' ? [name, `${name} FC`, `${name} FK`, `${name} SC`] : [name];
  for (const v of variants) {
    let d = null;
    for (let i = 0; i < 3 && !d; i++) {
      d = await getJSON(`https://www.thesportsdb.com/api/v1/json/3/searchteams.php?t=${encodeURIComponent(v)}`);
      if (!d) await sleep(3000);   // free-tier rate-limit backoff
    }
    await sleep(2500);
    const teams = d?.teams || [];
    const sameSport = teams.find((t) => t.strSport === SDB_SPORT[sport]);
    const any = teams[0];
    const badge = (sameSport || any)?.strBadge || (sameSport || any)?.strTeamBadge;
    if (badge) return badge;
  }
  return null;
}

async function resolveCrest(sport, name) {
  let u = await espnLogo(sport, name);
  if (await loads(u)) return u;
  u = await sportsDBLogo(sport, name);
  if (await loads(u)) return u;
  return null;
}

/// Fill picks.home_logo / away_logo for every team-sport pick in the given
/// date range that's still missing an image. Idempotent: only touches null
/// columns, caches per (sport|name) so each entity resolves once per run.
async function enrichImages(supabase, log, err, { sinceDaysAgo = 1 } = {}) {
  try {
    const since = new Date(Date.now() - sinceDaysAgo * 864e5).toISOString().slice(0, 10);
    const { data: picks, error } = await supabase
      .from('picks')
      .select('id, sport, home_team, away_team, home_logo, away_logo')
      .gte('game_date', since)
      .in('sport', [...TEAM_SPORTS]);
    if (error) { err('enrichImages fetch:', error.message); return; }
    if (!picks?.length) return;

    // Distinct entities still missing a crest.
    const need = new Map();   // "sport|name" -> {sport,name}
    for (const p of picks) {
      if ((!p.home_logo) && p.home_team && p.home_team.toLowerCase() !== 'field')
        need.set(`${p.sport}|${p.home_team}`, { sport: p.sport, name: p.home_team });
      if ((!p.away_logo) && p.away_team && p.away_team.toLowerCase() !== 'field')
        need.set(`${p.sport}|${p.away_team}`, { sport: p.sport, name: p.away_team });
    }
    if (!need.size) { log('Images: all team crests already captured.'); return; }

    log(`Images: resolving ${need.size} team crest(s)…`);
    const urlFor = new Map();
    let hit = 0;
    for (const { sport, name } of need.values()) {
      const u = await resolveCrest(sport, name);
      if (u) { urlFor.set(`${sport}|${name}`, u); hit++; }
    }

    // Write back — set home_logo/away_logo wherever the name matches and
    // the column is still empty.
    let updated = 0;
    for (const p of picks) {
      const patch = {};
      const hu = urlFor.get(`${p.sport}|${p.home_team}`);
      const au = urlFor.get(`${p.sport}|${p.away_team}`);
      if (!p.home_logo && hu) patch.home_logo = hu;
      if (!p.away_logo && au) patch.away_logo = au;
      if (Object.keys(patch).length) {
        const { error: e2 } = await supabase.from('picks').update(patch).eq('id', p.id);
        if (!e2) updated++;
      }
    }
    log(`Images: captured ${hit}/${need.size} crests, updated ${updated} pick row(s).`);
  } catch (e) {
    err('enrichImages failed:', e.message);
  }
}

module.exports = { enrichImages };
