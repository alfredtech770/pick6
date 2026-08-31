// images.js — server-side crest/headshot capture.
//
// The app resolved logos client-side (per-device ESPN/TheSportsDB search),
// which is slow and gets rate-limited on a real phone — so obscure teams
// (UCL qualifiers, KBO/NPB, associate cricket) showed the colored-shield
// placeholder "a lot". This module resolves each entity's real image ONCE,
// server-side, verifies it actually loads, and writes it to
// picks.home_logo / away_logo. The app reads those columns first
// (TeamLogoStore), so every pick paints its real image instantly with no
// client search.
//
// Two entity kinds, resolved differently:
//   TEAM_SPORTS   → club crest.    ESPN team search → TheSportsDB searchteams
//   PLAYER_SPORTS → athlete photo. ESPN search/v2 → headshot, then
//                    TheSportsDB searchplayers (cutout → thumb)
//
// Not covered on purpose: golf and F1. Their picks are "<event> vs Field" —
// neither column holds a person or a club, so there is nothing to resolve.
//
// National teams (World Cup soccer, international cricket) are intentionally
// LEFT for the app's country-flag path — a stored crest is harmless there
// (the app's wcFlagCode check wins first) so we still resolve them; it just
// isn't the primary visual.

// `football` (NFL) was missing from all three maps, so every NFL pick was
// skipped by enrichImages and painted the placeholder shield — 7 of 7 NFL
// picks had no crest. It is a team sport like the rest and belongs here.
// Verified identifiers: ESPN search returns sport `football` for NFL teams;
// TheSportsDB returns strSport `American Football` (not `Football`, which is
// soccer there — getting this wrong silently matches nothing).
//
// `rugby` and `afl` were missing for the same reason and with the same result:
// every rugby/AFL pick was skipped here and painted the placeholder. They are
// now covered as a fallback only — espnfixtures.js attaches the crest the
// scoreboard ships with the fixture, so this path is left to handle the clubs
// ESPN has no crest for at all (Bayonne, for one).
const TEAM_SPORTS = new Set(['soccer', 'basketball', 'baseball', 'hockey', 'cricket', 'football', 'rugby', 'afl']);
const ESPN_SPORT = { soccer: 'soccer', basketball: 'basketball', baseball: 'baseball', hockey: 'hockey', cricket: 'cricket', football: 'football', rugby: 'rugby', afl: 'australian-football' };
const SDB_SPORT = { soccer: 'Soccer', basketball: 'Basketball', baseball: 'Baseball', hockey: 'Ice Hockey', cricket: 'Cricket', football: 'American Football', rugby: 'Rugby', afl: 'Australian Football' };

// Individual sports: the pick's "teams" are two athletes, so we resolve a
// headshot instead of a crest. The strSport value here is load-bearing —
// TheSportsDB's player search is fuzzy and will happily return a completely
// different athlete: searching "Ben Shelton" (tennis) returns the WWE
// wrestler "Shelton Benjamin" under strSport 'Fighting'. Filtering on the
// expected sport is what stops a wrestler's photo appearing on a tennis pick.
const PLAYER_SPORTS = { tennis: 'Tennis', combat: 'Fighting' };

// How many entities to resolve at once. The old code was strictly
// sequential with a 2.5s sleep per lookup, so a 20-team slate could outlast
// the pipeline run and silently finish with most crests unresolved. A small
// pool keeps us polite to TheSportsDB's free tier while finishing in a
// fraction of the time.
const RESOLVE_CONCURRENCY = 3;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ESPN started returning 403 to server-side callers. Once we have seen it,
// stop asking for the rest of the run — otherwise every single team pays two
// doomed round trips before falling through to TheSportsDB.
let espnBlocked = false;

async function getJSON(url, timeoutMs = 10000) {
  try {
    const ctl = AbortSignal.timeout(timeoutMs);
    const r = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' }, signal: ctl });
    if (!r.ok) return { __status: r.status };
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
  if (espnBlocked) return null;
  const d = await getJSON(`https://site.api.espn.com/apis/search/v2?query=${encodeURIComponent(name)}&limit=8`);
  if (d?.__status === 403) { espnBlocked = true; return null; }
  if (!d || d.__status) return null;
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
      if (d?.__status) d = null;              // HTTP error — treat as a miss and retry
      if (!d) await sleep(1500);              // free-tier rate-limit backoff
    }
    const teams = d?.teams || [];
    const sameSport = teams.find((t) => t.strSport === SDB_SPORT[sport]);
    // Only fall back to teams[0] when the sport is unknown to us; otherwise a
    // wrong-sport club is a wrong crest, which is worse than no crest.
    const chosen = sameSport || (SDB_SPORT[sport] ? null : teams[0]);
    const badge = chosen?.strBadge || chosen?.strTeamBadge;
    if (badge) return badge;
  }
  return null;
}

// Athlete headshot. Strictly sport-filtered — see the PLAYER_SPORTS note.
async function sportsDBPlayer(sport, name) {
  const want = PLAYER_SPORTS[sport];
  if (!want) return null;
  let d = null;
  for (let i = 0; i < 3 && !d; i++) {
    d = await getJSON(`https://www.thesportsdb.com/api/v1/json/3/searchplayers.php?p=${encodeURIComponent(name)}`);
    if (d?.__status) d = null;
    if (!d) await sleep(1500);
  }
  const match = (d?.player || []).find((p) => p.strSport === want);
  if (!match) return null;
  // Cutout is the transparent-background portrait the app's card wants;
  // strThumb is a photo crop and is the acceptable second choice.
  return match.strCutout || match.strThumb || null;
}

// ESPN's own athlete headshot, resolved through the same search/v2 endpoint
// combat.js uses for fighter ids. TheSportsDB alone left every UFC pick with
// no image at all and covered only the top of a tennis draw; ESPN has the
// full UFC roster and the ranked half of the ATP tour.
//
// The uid carries the athlete id as "s:<sport>~a:<id>", which is the only
// place in the payload it appears in a stable form.
const ESPN_HEADSHOT_PATH = { tennis: 'tennis', combat: 'mma' };

async function espnHeadshot(sport, name, plain = false) {
  const path = ESPN_HEADSHOT_PATH[sport];
  if (!path || espnBlocked) return null;
  const q = plain
    ? name.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    : name;
  const d = await getJSON(
    `https://site.web.api.espn.com/apis/search/v2?query=${encodeURIComponent(q)}&limit=8`);
  if (!d || d.__status === 403) { if (d?.__status === 403) espnBlocked = true; return null; }
  for (const group of d.results || []) {
    if (group.type !== 'player') continue;
    for (const c of group.contents || []) {
      // Only accept a hit whose own description names the right sport: a
      // search for a tennis player will otherwise return a footballer with
      // the same surname, and a wrong face is worse than no face.
      const desc = String(c.description || '').toLowerCase();
      const wantDesc = sport === 'combat' ? 'mma' : 'tennis';
      if (!desc.includes(wantDesc)) continue;
      const id = String(c.uid || '').match(/a:(\d+)/)?.[1];
      if (!id) continue;
      return `https://a.espncdn.com/i/headshots/${path}/players/full/${id}.png`;
    }
  }
  // ESPN indexes some names without their diacritics, so an accented query
  // can come back empty where the plain form matches. Tried once, and only
  // when the accented form found nobody at all — not when it found the right
  // athlete who simply has no photo on file.
  if (!plain && name !== name.normalize('NFD').replace(/[\u0300-\u036f]/g, '')) {
    return espnHeadshot(sport, name, true);
  }
  return null;
}

async function resolveCrest(sport, name) {
  if (PLAYER_SPORTS[sport]) {
    // ESPN first: its headshots are transparent cutouts at a consistent crop,
    // which is what the card is designed around.
    let u = await espnHeadshot(sport, name);
    if (await loads(u)) return u;
    const p = await sportsDBPlayer(sport, name);
    return (await loads(p)) ? p : null;
  }
  let u = await espnLogo(sport, name);
  if (await loads(u)) return u;
  u = await sportsDBLogo(sport, name);
  if (await loads(u)) return u;
  return null;
}

// Resolve a list of entities with bounded concurrency, preserving the
// "resolve each name once" guarantee the caller relies on.
async function resolveAll(entities, onResolved) {
  let cursor = 0;
  const workers = Array.from({ length: Math.min(RESOLVE_CONCURRENCY, entities.length) }, async () => {
    while (cursor < entities.length) {
      const { sport, name } = entities[cursor++];
      const u = await resolveCrest(sport, name).catch(() => null);
      if (u) onResolved(`${sport}|${name}`, u);
    }
  });
  await Promise.all(workers);
}

/// Fill picks.home_logo / away_logo for every pick in the given date range
/// that's still missing an image — club crests for team sports, athlete
/// headshots for individual ones. Idempotent: only touches empty columns,
/// resolves each (sport|name) once per run.
async function enrichImages(supabase, log, err, { sinceDaysAgo = 1 } = {}) {
  try {
    espnBlocked = false;   // re-probe ESPN once per run
    const since = new Date(Date.now() - sinceDaysAgo * 864e5).toISOString().slice(0, 10);
    const wanted = [...TEAM_SPORTS, ...Object.keys(PLAYER_SPORTS)];
    const { data: picks, error } = await supabase
      .from('picks')
      .select('id, sport, home_team, away_team, home_logo, away_logo')
      .gte('game_date', since)
      .in('sport', wanted);
    if (error) { err('enrichImages fetch:', error.message); return; }
    if (!picks?.length) return;

    // Distinct entities still missing an image.
    const need = new Map();   // "sport|name" -> {sport,name}
    for (const p of picks) {
      if ((!p.home_logo) && p.home_team && p.home_team.toLowerCase() !== 'field')
        need.set(`${p.sport}|${p.home_team}`, { sport: p.sport, name: p.home_team });
      if ((!p.away_logo) && p.away_team && p.away_team.toLowerCase() !== 'field')
        need.set(`${p.sport}|${p.away_team}`, { sport: p.sport, name: p.away_team });
    }
    if (!need.size) { log('Images: all crests/headshots already captured.'); return; }

    log(`Images: resolving ${need.size} entit(y|ies) across ${new Set([...need.values()].map((e) => e.sport)).size} sport(s)…`);
    const urlFor = new Map();
    await resolveAll([...need.values()], (k, u) => urlFor.set(k, u));
    const hit = urlFor.size;

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
    const missed = [...need.values()].filter((e) => !urlFor.has(`${e.sport}|${e.name}`));
    log(`Images: captured ${hit}/${need.size}, updated ${updated} pick row(s)${espnBlocked ? ' [ESPN blocked — TheSportsDB only]' : ''}.`);
    // Name the misses: a persistent miss is usually a naming mismatch we can
    // fix with an alias, and silence here is how the placeholder shield
    // quietly became normal.
    if (missed.length) log(`Images: unresolved → ${missed.map((e) => `${e.sport}:${e.name}`).join(', ')}`);
  } catch (e) {
    err('enrichImages failed:', e.message);
  }
}

module.exports = { enrichImages, resolveCrest };
