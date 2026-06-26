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

// ════════════════════════════════════════════════════════════════════
// 5. GROUNDED GENERATION — write picks that may only assert fetched facts
// ════════════════════════════════════════════════════════════════════
// The model is handed the ground truth and told, in no uncertain terms,
// that it may not state anything outside it. The two failure modes that
// cost the partnership are called out by name:
//   • experience/debut: derive ONLY from recent[]. Non-empty recent →
//     the fighter is NOT debuting. Never call anyone a debutant/newcomer
//     unless recent is empty AND loggedFights is 0.
//   • method of victory: describe a past fight ONLY from its stats. If
//     takedownsLanded is 0 and controlTime ~0, it was NOT a grappling
//     win — do not say "top control"/"grappling dominance".
// web_search is permitted for ONE thing only: the current betting line.

function fightToContext(f) {
  const side = (s) => {
    if (!s.recent || !s.recent.length) {
      return `${s.name} (record ${s.record || 'unknown'}) — NO fight history available on file. Treat as LIMITED DATA: do not assert experience level, debut status, or any past-fight specifics.`;
    }
    const lines = s.recent.map((r) => {
      const td = r.takedownsLanded != null ? `${r.takedownsLanded} TD landed` : 'TD n/a';
      const ctrl = r.controlTime ? `${r.controlTime} control` : 'no control';
      const grappled = (r.takedownsLanded === 0 && (!r.controlTime || r.controlTime === '0:00'));
      return `   • ${r.date} ${r.win ? 'WON' : 'LOST'} vs ${r.opponent} — ${td}, ${ctrl}, ${r.knockdowns ?? 0} KD, ${r.submissions ?? 0} sub, ${r.sigStrikesLanded ?? '?'} sig strikes${grappled ? ' [STAND-UP FIGHT: no takedowns, no control]' : ''}`;
    });
    return `${s.name} (record ${s.record || 'unknown'}, ${s.recent.length}+ fights on file → EXPERIENCED, not a debutant):\n${lines.join('\n')}`;
  };
  return `FIGHT: ${f.a.name} vs ${f.b.name}${f.weightClass ? ` (${f.weightClass})` : ''}${f.cardSegment ? ` — ${f.cardSegment}` : ''}\nA) ${side(f.a)}\nB) ${side(f.b)}`;
}

const GROUNDED_SYSTEM = `You are the combat-sports prediction engine for Pick1. You are writing fight breakdowns that a professional MMA analyst will read. Accuracy is the ONLY thing that matters — a single invented fact loses the partnership.

ABSOLUTE RULES:
1. You may ONLY state facts that appear in the GROUND TRUTH provided for each fight. Records, experience, and past-fight specifics come from there and NOWHERE ELSE.
2. EXPERIENCE/DEBUT: If a fighter has fights listed on file, they are EXPERIENCED — never call them a debutant, newcomer, or inexperienced. Only call someone a debutant if their ground truth explicitly says NO fight history available.
3. METHOD OF VICTORY: Describe a past fight ONLY from its stats. If a fight is tagged [STAND-UP FIGHT: no takedowns, no control], you MUST NOT describe it as a grappling win, top control, or wrestling dominance — it was decided on the feet. If takedowns landed > 0 and control time is meaningful, grappling framing is fair.
4. NO INVENTED NUMBERS: Never state a betting line, Tapology/poll percentage, or model number unless you found it THIS run via web_search and you name the source. Otherwise omit it.
5. For a LIMITED DATA fighter (no history on file), keep the breakdown general and cautious — physical/contextual reasoning only, no fabricated specifics.

Use web_search for ONE purpose only: the current betting line for the picked fighter (market_odds + odds_source). Null both if not found. Do NOT web_search for records or fight history — use the ground truth.

Pick the stronger fighter in each fight with an honest, calibrated probability (integer 55-97). Reasoning = 2-3 sentences built strictly from the ground truth. key_factor = the single biggest grounded reason. matchup_facts = 3-5 {label,value} pairs taken straight from the ground truth.`;

async function generateGroundedCombatPicks({ anthropic, model, groundTruth, schema, log = console.log }) {
  const fightsCtx = groundTruth.fights.map(fightToContext).join('\n\n');
  const userPrompt = [
    `Event: ${groundTruth.event.name} — ${groundTruth.event.date}`,
    `Set game_date to ${(groundTruth.event.date || '').slice(0, 10)} on every pick.`,
    '',
    'GROUND TRUTH (the ONLY facts you may assert):',
    '',
    fightsCtx,
    '',
    'Return one pick per fight via the schema. home_team/away_team must match the fighter names above exactly. The "pick" must be one of them.',
  ].join('\n');

  const stream = anthropic.messages.stream({
    model,
    max_tokens: 32000,
    thinking: { type: 'adaptive' },
    output_config: { effort: 'high', format: { type: 'json_schema', schema } },
    tools: [{ type: 'web_search_20260209', name: 'web_search' }],
    system: [{ type: 'text', text: GROUNDED_SYSTEM, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: userPrompt }],
  });
  const final = await stream.finalMessage();
  const block = final.content.find((b) => b.type === 'text');
  const picks = block ? JSON.parse(block.text).picks : [];
  log(`🥊 Grounded generation produced ${picks.length} combat picks`);
  return picks;
}

// ════════════════════════════════════════════════════════════════════
// 6. VERIFICATION PASS — fact-check every claim against the ground truth
// ════════════════════════════════════════════════════════════════════
// A second, independent model call whose only job is to REFUTE. It sees
// the ground truth and the draft breakdown and strips/rewrites anything
// the ground truth doesn't support, or drops the pick if its rationale
// collapses. This is the backstop for anything that slips past gen.

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['clean', 'corrected', 'drop'] },
    issues: { type: 'array', items: { type: 'string' }, description: 'Each unsupported/false claim found, quoted.' },
    reasoning: { type: 'string', description: 'Corrected reasoning using only ground-truth facts.' },
    key_factor: { type: 'string' },
    matchup_facts: {
      type: 'array',
      items: { type: 'object', properties: { label: { type: 'string' }, value: { type: 'string' } }, required: ['label', 'value'], additionalProperties: false },
    },
  },
  required: ['verdict', 'issues', 'reasoning', 'key_factor', 'matchup_facts'],
  additionalProperties: false,
};

async function verifyGroundedCombatPicks({ anthropic, model, picks, groundTruth, log = console.log }) {
  const byFight = new Map();
  for (const f of groundTruth.fights) {
    byFight.set(`${f.a.name}|${f.b.name}`, f);
    byFight.set(`${f.b.name}|${f.a.name}`, f);
  }
  const kept = [];
  for (const p of picks) {
    const f = byFight.get(`${p.home_team}|${p.away_team}`);
    if (!f) { kept.push(p); continue; }   // can't map → leave as-is (rare)
    const truth = fightToContext(f);
    const draft = `pick: ${p.pick} (${p.probability}%)\nreasoning: ${p.reasoning}\nkey_factor: ${p.key_factor}\nmatchup_facts: ${JSON.stringify(p.matchup_facts)}`;
    const msg = await anthropic.messages.create({
      model,
      max_tokens: 1500,
      system: 'You are a ruthless MMA fact-checker. The GROUND TRUTH is the only source of truth. Find every claim in the DRAFT that the ground truth does not support — invented records, wrong experience/debut status, grappling claims about stand-up fights, fabricated betting lines or poll numbers. Rewrite reasoning/key_factor/matchup_facts to keep ONLY supported claims. If after removing unsupported claims the pick has no real rationale left, verdict=drop. If you removed/changed anything, verdict=corrected; if it was already fully supported, verdict=clean.',
      output_config: { format: { type: 'json_schema', schema: VERIFY_SCHEMA } },
      messages: [{ role: 'user', content: `GROUND TRUTH:\n${truth}\n\nDRAFT:\n${draft}` }],
    });
    const block = msg.content.find((b) => b.type === 'text');
    const v = block ? JSON.parse(block.text) : null;
    if (!v) { kept.push(p); continue; }
    if (v.verdict === 'drop') { log(`   ✂️  dropped ${p.home_team} vs ${p.away_team}: ${v.issues.join('; ')}`); continue; }
    if (v.verdict === 'corrected') log(`   ✏️  corrected ${p.home_team} vs ${p.away_team}: ${v.issues.join('; ')}`);
    kept.push({ ...p, reasoning: v.reasoning, key_factor: v.key_factor, matchup_facts: v.matchup_facts });
  }
  log(`🔎 Verification: ${kept.length}/${picks.length} combat picks kept`);
  return kept;
}

// ════════════════════════════════════════════════════════════════════
// 7. TALE OF THE TAPE — physicals + career stats for the detail card
// ════════════════════════════════════════════════════════════════════
// ESPN's athlete profile carries the full tale-of-the-tape (height, reach,
// age, stance, weight class, nickname, country) and a career-stats split
// (strikes/min, accuracy, takedown avg/accuracy, sub avg, finish %). All
// of it is real and free. We compute the comparison server-side so the app
// renders a complete fight card without any client-side guessing.

async function careerStats(id) {
  const d = await getJSON(`${CORE}/athletes/${id}/statistics?lang=en&region=us`);
  const cats = d?.splits?.categories;
  if (!cats) return null;
  const v = (n) => { for (const c of cats) for (const s of c.stats || []) if (s.name === n) return s.displayValue; return null; };
  // NOTE: ESPN's koPercentage/tkoPercentage/decisionPercentage are
  // mis-scaled (a heavy finisher reads ~6%), so we deliberately exclude
  // them. The per-minute/accuracy/avg fields below are reliable.
  return {
    strLPM: v('strikeLPM'), strAcc: v('strikeAccuracy'),
    tdAvg: v('takedownAvg'), tdAcc: v('takedownAccuracy'),
    subAvg: v('submissionAvg'),
  };
}

async function fighterTale(name, record = null) {
  const id = await resolveFighterId(name);
  if (!id) return { name, record, id: null };
  const [prof, career] = await Promise.all([
    getJSON(`${CORE}/athletes/${id}?lang=en&region=us`),
    careerStats(id),
  ]);
  const wc = prof?.weightClass;
  return {
    name, id, record,
    nickname: prof?.nickname || null,
    // ESPN reports 0 / empty for fighters it doesn't have physicals on —
    // treat those as missing so the card shows "—", not "0\"".
    height: (prof?.displayHeight && !/^0/.test(prof.displayHeight)) ? prof.displayHeight : null,
    reach: (typeof prof?.reach === 'number' && prof.reach > 0) ? `${prof.reach}"` : null,
    reachNum: (typeof prof?.reach === 'number' && prof.reach > 0) ? prof.reach : null,
    age: prof?.age > 0 ? prof.age : null,
    stance: typeof prof?.stance === 'string' ? prof.stance : (prof?.stance?.text || null),
    weightClass: (typeof wc === 'string' ? wc : wc?.text) || null,
    country: prof?.citizenship || null,
    career: career || null,
  };
}

const last = (n) => (n || '').trim().split(/\s+/).slice(-1)[0];

// Structured side-by-side object stored on the pick (powers the app's
// Tale of the Tape section). home/away match the pick's home_team/away_team.
async function buildTaleOfTape(fight) {
  const [a, b] = await Promise.all([
    fighterTale(fight.a.name, fight.a.record),
    fighterTale(fight.b.name, fight.b.record),
  ]);
  const edges = {};
  if (a.reachNum && b.reachNum && a.reachNum !== b.reachNum) {
    const diff = Math.round((a.reachNum - b.reachNum) * 10) / 10;
    edges.reach = { fighter: diff > 0 ? a.name : b.name, value: `+${Math.abs(diff)}"` };
  }
  if (a.age && b.age && a.age !== b.age) {
    edges.youth = { fighter: a.age < b.age ? a.name : b.name, value: `${Math.abs(a.age - b.age)} yrs younger` };
  }
  return { a, b, edges, weightClass: a.weightClass || b.weightClass || fight.weightClass || null };
}

// Deterministic comparison rows for the existing single-column MATCHUP
// list — the no-build quick win. Each value packs both fighters by last
// name so it stays compact and never fabricated.
function combatComparisonFacts(tot) {
  const { a, b } = tot;
  const la = last(a.name), lb = last(b.name);
  const rows = [];
  const both = (la1, va, vb, label, suffix = '') => {
    if (va == null && vb == null) return;
    rows.push({ label, value: `${la} ${va ?? '—'}${suffix} · ${lb} ${vb ?? '—'}${suffix}` });
  };
  if (a.record || b.record) both(la, a.record, b.record, 'Record');
  both(la, a.reach, b.reach, 'Reach');
  both(la, a.height, b.height, 'Height');
  if (a.age || b.age) both(la, a.age, b.age, 'Age');
  if (a.career?.strLPM || b.career?.strLPM) both(la, a.career?.strLPM, b.career?.strLPM, 'Strikes/min');
  if (a.career?.strAcc || b.career?.strAcc) {
    const pct = (v) => v != null ? `${Math.round(parseFloat(v))}%` : '—';
    rows.push({ label: 'Strike accuracy', value: `${la} ${pct(a.career?.strAcc)} · ${lb} ${pct(b.career?.strAcc)}` });
  }
  if (a.career?.tdAvg || b.career?.tdAvg) both(la, a.career?.tdAvg, b.career?.tdAvg, 'Takedowns/15');
  return rows.slice(0, 7);
}

// ════════════════════════════════════════════════════════════════════
// 8. BETTING PROPS — confident, grounded fight outcome predictions
// ════════════════════════════════════════════════════════════════════
// Method (how it ends) + distance (does it reach the judges). Predicted
// from the SAME ground truth — recent finish/durability patterns + career
// rates. Genuine toss-ups return 'unsure' and are never shown. These are
// clearly framed as predictions, not facts.

const PROPS_SCHEMA = {
  type: 'object',
  properties: {
    fights: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          home_team: { type: 'string' },
          away_team: { type: 'string' },
          method: { type: 'string', enum: ['KO/TKO', 'Submission', 'Decision', 'unsure'] },
          method_confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
          distance: { type: 'string', enum: ['Goes the distance', 'Ends inside distance', 'unsure'] },
          distance_confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
        },
        required: ['home_team', 'away_team', 'method', 'method_confidence', 'distance', 'distance_confidence'],
        additionalProperties: false,
      },
    },
  },
  required: ['fights'],
  additionalProperties: false,
};

async function generateCombatProps({ anthropic, model, groundTruth, log = console.log }) {
  const ctx = groundTruth.fights.map(fightToContext).join('\n\n');
  const sys = `You predict HOW each MMA fight most likely ends, using ONLY the provided ground truth: recent results (did each fighter finish opponents or get finished?), control/takedown/strike patterns, and career rates. Two predictions per fight:
- method: KO/TKO, Submission, or Decision. Use 'unsure' for a genuine toss-up.
- distance: "Goes the distance" (reaches the judges) or "Ends inside distance". Use 'unsure' if unclear.
Set confidence honestly. A fighter with no finishes on file and a durable opponent → likely Decision/distance. A heavy finisher vs someone recently KO'd → likely inside distance. Do NOT force a call you can't support — 'unsure' is correct often.`;
  const msg = await anthropic.messages.create({
    model, max_tokens: 4000,
    output_config: { format: { type: 'json_schema', schema: PROPS_SCHEMA } },
    system: sys,
    messages: [{ role: 'user', content: `GROUND TRUTH:\n\n${ctx}\n\nPredict method + distance for every fight.` }],
  });
  const block = msg.content.find((b) => b.type === 'text');
  const out = block ? JSON.parse(block.text).fights : [];
  log(`🎯 Generated outcome props for ${out.length} fights`);
  return out;
}

// Turn one fight's predicted outcome into display props — only the
// confident calls (medium/high); coin-flips are dropped.
function combatPropItems(outcome) {
  if (!outcome) return [];
  const items = [];
  if (outcome.method && outcome.method !== 'unsure' && outcome.method_confidence !== 'low') {
    items.push({ label: 'How it ends', value: outcome.method, hint: `${outcome.method_confidence} confidence` });
  }
  if (outcome.distance && outcome.distance !== 'unsure' && outcome.distance_confidence !== 'low') {
    items.push({ label: 'Rounds', value: outcome.distance, hint: `${outcome.distance_confidence} confidence` });
  }
  return items;
}

// Team sports: confident props derived deterministically from the model's
// projected score (no extra AI). Total + winning margin, framed as
// projections. Returns [] when there's no usable score.
function teamBettingProps({ predictedScore, homeTeam, awayTeam, pick, sport }) {
  if (!predictedScore || !/^\d{1,3}-\d{1,3}$/.test(predictedScore.trim())) return [];
  const [h, a] = predictedScore.trim().split('-').map(Number);
  const total = h + a;
  const margin = Math.abs(h - a);
  const winner = h === a ? null : (h > a ? homeTeam : awayTeam);
  const items = [{ label: 'Projected total', value: `${total}`, hint: totalHint(sport) }];
  if (winner && margin > 0) {
    items.push({ label: 'Winning margin', value: `${winner} by ${margin}`, hint: null });
  }
  return items;
}

function totalHint(sport) {
  switch (sport) {
    case 'basketball': return 'combined points';
    case 'baseball': return 'combined runs';
    case 'hockey': return 'combined goals';
    case 'football': return 'combined points';
    case 'soccer': return 'combined goals';
    default: return 'combined';
  }
}
const shortName = (n) => (n || '').split(/\s+/).slice(-1)[0];

module.exports = {
  fetchUpcomingCard,
  resolveFighterId,
  fighterProfile,
  buildCardGroundTruth,
  fightToContext,
  generateGroundedCombatPicks,
  verifyGroundedCombatPicks,
  fighterTale,
  buildTaleOfTape,
  combatComparisonFacts,
  generateCombatProps,
  combatPropItems,
  teamBettingProps,
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
