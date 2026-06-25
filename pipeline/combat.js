// combat.js — GROUNDED UFC/MMA data layer
// ════════════════════════════════════════════════════════════════════
// Why this exists
// ───────────────
// The old combat path generated fight breakdowns in pure "research mode":
// the model wrote confident prose from its training memory with a handful
// of web searches it couldn't possibly spread across a 13-fight card. The
// result was confabulation — invented debut statuses ("Pulyaev's UFC
// debut" when he's 4 fights in), invented methods of victory ("Donchenko
// beat Morono via grappling/top control" when that fight had ZERO
// takedowns), invented betting lines and poll percentages. A single bad
// breakdown cost a partnership.
//
// This module replaces memory with FACTS. Everything the model is allowed
// to assert about a fighter's record, recent results, and how those
// fights actually went is fetched here from ESPN's MMA API and handed to
// the model as ground truth. ESPN exposes, per fighter per fight:
// win/loss, opponent, date, takedowns landed, control time, knockdowns,
// submissions, and full strike counts — enough to describe any recent
// fight accurately instead of guessing.
//
// Data source: ESPN public MMA API (same infra we already use for logos).
//   - scoreboard   → the upcoming event + its fight card + records
//   - search/v2    → fighter name → athlete id
//   - eventlog     → a fighter's fights (→ UFC fight count, recent results)
//   - competition + statistics → real per-fight method signals (TD/control)
//
// No API key, public endpoints. Fighters ESPN doesn't carry (obscure
// regional debutants) come back with history:null — the generation layer
// is told to treat those as "limited data" and stay general rather than
// invent, and the verification pass drops anything unsupported.

const UA = 'curl/8.4.0';
const SCOREBOARD = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard';
const SEARCH = 'https://site.api.espn.com/apis/search/v2';
const CORE = 'https://sports.core.api.espn.com/v2/sports/mma';

// ── tiny fetch helper: JSON, UA header, one retry, soft-fail to null ──
async function getJSON(url) {
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const r = await fetch(url, { headers: { 'User-Agent': UA } });
      if (!r.ok) { if (attempt) return null; continue; }
      return await r.json();
    } catch {
      if (attempt) return null;
    }
  }
  return null;
}

// Resolve "http://...athletes/12345?lang=.." → "12345"
const idFromRef = (ref) => (ref || '').match(/athletes\/(\d+)/)?.[1] || null;

// ════════════════════════════════════════════════════════════════════
// 1. The card — upcoming UFC event + every fight + current records
// ════════════════════════════════════════════════════════════════════
async function fetchUpcomingCard() {
  const d = await getJSON(SCOREBOARD);
  const ev = d?.events?.[0];
  if (!ev) return null;
  const fights = (ev.competitions || []).map((c) => {
    const cs = c.competitors || [];
    const side = (i) => ({
      name: cs[i]?.athlete?.fullName || cs[i]?.athlete?.displayName || `Fighter ${i + 1}`,
      record: (cs[i]?.records || [])[0]?.summary || null,
    });
    return {
      fightId: c.id,
      cardSegment: c.cardSegment?.title || null,   // "Main Card" / "Prelims"
      weightClass: c.type?.text || c.note || null,
      a: side(0),
      b: side(1),
    };
  });
  return { eventId: ev.id, eventName: ev.name, eventDate: ev.date, fights };
}

// ════════════════════════════════════════════════════════════════════
// 2. Fighter id resolution (cached) — name → ESPN athlete id
// ════════════════════════════════════════════════════════════════════
const idCache = new Map();
async function resolveFighterId(name) {
  if (idCache.has(name)) return idCache.get(name);
  const d = await getJSON(`${SEARCH}?query=${encodeURIComponent(name)}&limit=8`);
  let id = null;
  for (const group of d?.results || []) {
    for (const c of group.contents || []) {
      const uid = (c.uid || '').toLowerCase();
      // mma athlete uids look like "s:3301~a:4339488"
      if (uid.includes('~a:') && (c.sport === 'mma' || uid.includes('3301'))) {
        id = uid.match(/~a:(\d+)/)?.[1] || c.id || null;
        break;
      }
    }
    if (id) break;
  }
  idCache.set(name, id);
  return id;
}

// ════════════════════════════════════════════════════════════════════
// 3. Fighter history — UFC fight count + recent results WITH real stats
// ════════════════════════════════════════════════════════════════════
// Pulls the fighter's event log, then for the most recent `n` *completed*
// fights resolves: opponent, win/loss, date, and the grappling/striking
// signals that let the model describe the fight truthfully (takedowns,
// control time, knockdowns, submissions, significant strikes).

function readStat(cats, name) {
  for (const c of cats || []) {
    for (const s of c.stats || []) {
      if (s.name === name) return s;
    }
  }
  return null;
}

async function competitorStats(compRef, athleteId) {
  // compRef ends with ".../competitions/<cid>?..." → build the per-competitor stats url
  const base = compRef.split('?')[0];
  const d = await getJSON(`${base}/competitors/${athleteId}/statistics?lang=en&region=us`);
  const cats = d?.splits?.categories;
  if (!cats) return null;
  const num = (n) => { const s = readStat(cats, n); return s ? Number(s.value) : null; };
  const disp = (n) => { const s = readStat(cats, n); return s ? s.displayValue : null; };
  return {
    takedownsLanded: num('takedownsLanded'),
    takedownsAttempted: num('takedownsAttempted'),
    controlTime: disp('timeInControl'),
    knockdowns: num('knockDowns'),
    submissions: num('submissions'),
    sigStrikesLanded: num('sigStrikesLanded'),
  };
}

async function fighterProfile(name, { recent = 3 } = {}) {
  const id = await resolveFighterId(name);
  if (!id) return { name, id: null, history: null, note: 'not found on ESPN' };

  const log = await getJSON(`${CORE}/athletes/${id}/eventlog?limit=40`);
  const items = log?.events?.items || [];

  // Each item: { event{$ref}, competition{$ref}, played(bool) }
  // Count completed UFC fights for debut/experience grounding.
  const completed = [];
  for (const it of items) {
    const compRef = it.competition?.$ref;
    if (!compRef) continue;
    completed.push({ compRef, playedFlag: it.played });
  }

  const results = [];
  let loggedFights = 0;
  for (const { compRef } of completed) {
    const comp = await getJSON(compRef);
    if (!comp) continue;
    const done = comp.status?.$ref ? true : false; // resolve below if needed
    // status is a $ref; fetch only to confirm completion
    const st = comp.status?.$ref ? await getJSON(comp.status.$ref) : comp.status;
    const isPost = st?.type?.state === 'post' || st?.type?.completed === true;
    if (!isPost) continue;                       // skip scheduled/future bouts
    loggedFights++;

    if (results.length >= recent) continue;       // keep counting, but detail only `recent`
    const me = (comp.competitors || []).find((c) => String(c.id) === String(id) || idFromRef(c.athlete?.$ref) === String(id));
    const opp = (comp.competitors || []).find((c) => c !== me);
    let oppName = null;
    if (opp?.athlete?.$ref) {
      const oa = await getJSON(opp.athlete.$ref);
      oppName = oa?.fullName || oa?.displayName || null;
    }
    const stats = me ? await competitorStats(compRef, id) : null;
    const blank = { takedownsLanded: null, takedownsAttempted: null, controlTime: null, knockdowns: null, submissions: null, sigStrikesLanded: null };
    results.push({
      date: (comp.date || '').slice(0, 10),
      opponent: oppName,
      win: me?.winner === true,
      ...blank,
      ...(stats || {}),
    });
  }

  // loggedFights = fights ESPN has on record for this athlete (career, not
  // strictly UFC). Used only to tell "established fighter" from "thin/no
  // record" — never asserted verbatim. The `recent` list is the real
  // experience signal (named opponents the model can cite).
  return { name, id, loggedFights, recent: results, history: results.length ? results : null };
}

// ════════════════════════════════════════════════════════════════════
// 4. Assemble per-fight ground truth for the whole card
// ════════════════════════════════════════════════════════════════════
async function buildCardGroundTruth({ mainCardOnly = false } = {}) {
  const card = await fetchUpcomingCard();
  if (!card) return null;
  let fights = card.fights;
  if (mainCardOnly) fights = fights.filter((f) => /main/i.test(f.cardSegment || ''));

  const out = [];
  for (const f of fights) {
    const [a, b] = await Promise.all([
      fighterProfile(f.a.name),
      fighterProfile(f.b.name),
    ]);
    out.push({
      fightId: f.fightId,
      weightClass: f.weightClass,
      cardSegment: f.cardSegment,
      a: { ...f.a, ...a },
      b: { ...f.b, ...b },
    });
  }
  return { event: { id: card.eventId, name: card.eventName, date: card.eventDate }, fights: out };
}

module.exports = {
  fetchUpcomingCard,
  resolveFighterId,
  fighterProfile,
  buildCardGroundTruth,
};

// ── CLI test: `node combat.js test` ──────────────────────────────────
if (require.main === module && process.argv[2] === 'test') {
  (async () => {
    console.log('Fetching upcoming card…');
    const card = await fetchUpcomingCard();
    console.log(`\n${card.eventName} — ${card.eventDate} — ${card.fights.length} fights\n`);

    // Targeted proof: the two fights the partner flagged.
    const targets = [
      'Nursulton Ruziboev', 'Andrey Pulyaev',  // partner: Pulyaev is NOT a debutant
      'Alex Morono',                            // partner: Donchenko-Morono had 0 takedowns
    ];
    for (const name of targets) {
      const p = await fighterProfile(name, { recent: 5 });
      console.log(`── ${name} — ESPN id ${p.id} — fights on record: ${p.loggedFights}`);
      for (const r of p.recent || []) {
        console.log(`     ${r.date}  ${r.win ? 'W' : 'L'} vs ${r.opponent}  | TD ${r.takedownsLanded}/${r.takedownsAttempted}  ctrl ${r.controlTime}  KD ${r.knockdowns}  sub ${r.submissions}  sigStr ${r.sigStrikesLanded}`);
      }
      console.log();
    }
  })().catch((e) => { console.error(e); process.exit(1); });
}
