// espnfixtures.js — GROUNDED fixtures for rugby and Australian rules
// ════════════════════════════════════════════════════════════════════
// sportsdata.io sells no rugby or AFL tier, so the obvious route for
// these two was research mode: let Claude web_search the fixture list.
// That is the same path that confabulated fight cards for UFC before
// combat.js grounded it — a model asked "what rugby is on this week"
// will happily produce a plausible round that was never scheduled.
//
// ESPN publishes both sports on the same public scoreboard API that
// teamsport.js already uses for MLB/NBA/NFL/NHL, including season
// records and venues. So the fixture list, the team names and the form
// come from the feed, and the model is only asked to judge the games it
// is handed — never to remember what is on.
//
// AFLW and VFL are in the spec but ESPN serves neither (400), so they
// stay uncovered rather than being faked from a search.

const UA = 'curl/8.4.0';
const SITE = 'https://site.api.espn.com/apis/site/v2/sports';

// League code (as written into picks.league) → ESPN scoreboard path.
// The rugby numbers are ESPN's competition ids; they are stable.
const PATHS = {
  AFL:        'australian-football/afl',
  SIXNATIONS: 'rugby/180659',
  TOP14:      'rugby/270559',
  PREMRUGBY:  'rugby/267979',
  URC:        'rugby/270557',
  CHAMPCUP:   'rugby/271937',
  RWC:        'rugby/164205',
  RUGBYCHAMP: 'rugby/244293',
};

const isSupported = (league) => !!PATHS[league];

async function getJSON(url) {
  for (let i = 0; i < 2; i++) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': UA } });
      if (r.ok) return await r.json();
    } catch { /* retry once, then give up quietly */ }
  }
  return null;
}

const yyyymmdd = (d) => d.toISOString().slice(0, 10).replace(/-/g, '');

/// Records come back as a list; the overall one is what the prompt wants.
function recordOf(competitor) {
  const rs = competitor?.records || [];
  const overall = rs.find((r) => r.type === 'total' || r.name === 'overall') || rs[0];
  return overall?.summary || null;
}

/**
 * Upcoming fixtures for one league, as raw rows the registry normalizer
 * can pass straight through.
 *
 * `days` is deliberately wider than the 48h the daily leagues use. Rugby
 * and AFL play weekly, not nightly, so a 2-day window would return an
 * empty slate on five days out of seven and hand the league to the
 * research fallback — the exact expensive path this module exists to
 * avoid.
 */
async function fetchFixtures(league, days = 8) {
  const path = PATHS[league];
  if (!path) return [];

  const now = new Date();
  const end = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
  const url = `${SITE}/${path}/scoreboard?dates=${yyyymmdd(now)}-${yyyymmdd(end)}&limit=100`;

  const data = await getJSON(url);
  const events = data?.events || [];
  const rows = [];

  for (const e of events) {
    const c = e.competitions?.[0];
    if (!c) continue;

    // 'pre' is scheduled; 'in' and 'post' are already running or done.
    const state = c.status?.type?.state;
    if (state !== 'pre') continue;

    const home = c.competitors?.find((t) => t.homeAway === 'home');
    const away = c.competitors?.find((t) => t.homeAway === 'away');
    if (!home || !away) continue;

    // The scoreboard honours the date range loosely, so re-check the
    // window here rather than trusting it.
    const kickoff = new Date(e.date);
    if (!(kickoff >= now && kickoff <= end)) continue;

    rows.push({
      Status: 'Scheduled',
      game_id: `${league.toLowerCase()}-${e.id}`,
      home_team: home.team?.displayName || home.team?.name,
      away_team: away.team?.displayName || away.team?.name,
      home_abbr: home.team?.abbreviation || null,
      away_abbr: away.team?.abbreviation || null,
      home_record: recordOf(home),
      away_record: recordOf(away),
      home_logo: home.team?.logo || null,
      away_logo: away.team?.logo || null,
      venue: c.venue?.fullName || null,
      competition: data?.leagues?.[0]?.name || league,
      start_time: e.date,          // ISO UTC; the writer converts to ET
    });
  }

  // Soonest first, so a capped slate keeps the games nearest to kick-off.
  rows.sort((a, b) => new Date(a.start_time) - new Date(b.start_time));
  return rows;
}

/// No cap here on purpose. index.js de-dupes against picks already saved
/// *after* the fetcher runs, so trimming the list first would hand back
/// the same soonest-N every day, dedupe them all away, and leave the tail
/// of a round permanently unpicked.
const fetcherFor = (league) => () => fetchFixtures(league);

module.exports = { fetchFixtures, fetcherFor, isSupported, PATHS };
