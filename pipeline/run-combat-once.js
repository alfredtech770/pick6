// One-off: generate + verify grounded UFC picks for the upcoming card.
// Run via `railway run --service worker node run-combat-once.js` so it
// inherits ANTHROPIC_API_KEY + SUPABASE creds. Prints for inspection and
// writes /tmp/combat_picks.json. Pass --insert to upsert into `picks`.
require('dotenv').config();
const fs = require('fs');
const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const combat = require('./combat');

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY);
const MODEL = 'claude-opus-4-7';
const todayISO = () => new Date().toISOString().slice(0, 10);

// Same schema the pipeline uses, trimmed to combat-relevant fields.
const PICK_SCHEMA = {
  type: 'object',
  properties: {
    picks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          game_id: { type: 'string' },
          game_date: { type: 'string', description: 'YYYY-MM-DD of the event (ET).' },
          home_team: { type: 'string' },
          away_team: { type: 'string' },
          pick: { type: 'string', description: 'Must equal home_team or away_team.' },
          probability: { type: 'integer', description: '55-97' },
          confidence: { type: 'string', enum: ['***', '**', '*'] },
          reasoning: { type: 'string' },
          key_factor: { type: 'string' },
          matchup_facts: {
            type: 'array',
            items: { type: 'object', properties: { label: { type: 'string' }, value: { type: 'string' } }, required: ['label', 'value'], additionalProperties: false },
          },
          market_odds: { type: ['number', 'null'] },
          odds_source: { type: ['string', 'null'] },
        },
        required: ['game_id', 'game_date', 'home_team', 'away_team', 'pick', 'probability', 'confidence', 'reasoning', 'key_factor', 'matchup_facts', 'market_odds', 'odds_source'],
        additionalProperties: false,
      },
    },
  },
  required: ['picks'],
  additionalProperties: false,
};

(async () => {
  console.log('Building ground truth from ESPN…');
  const gt = await combat.buildCardGroundTruth();
  if (!gt || !gt.fights?.length) { console.error('No card found.'); process.exit(1); }
  const eventDate = (gt.event.date || '').slice(0, 10);
  console.log(`\n${gt.event.name} — ${eventDate} — ${gt.fights.length} fights\n`);

  let draft = await combat.generateGroundedCombatPicks({ anthropic, model: MODEL, groundTruth: gt, schema: PICK_SCHEMA });
  draft = await combat.verifyGroundedCombatPicks({ anthropic, model: MODEL, picks: draft, groundTruth: gt });

  // Stamp ids/dates.
  const byName = new Map();
  for (const f of gt.fights) { byName.set(f.a.name, f); byName.set(f.b.name, f); }
  for (const p of draft) {
    const f = byName.get(p.home_team) || byName.get(p.away_team);
    if (f) p.game_id = `ufc-${f.fightId}`;
    p.game_date = eventDate;
  }

  console.log('\n══════════ GENERATED + VERIFIED PICKS ══════════\n');
  for (const p of draft) {
    console.log(`🥊 ${p.pick}  (${p.probability}% ${p.confidence})  — ${p.home_team} vs ${p.away_team}`);
    console.log(`   key: ${p.key_factor}`);
    console.log(`   ${p.reasoning}`);
    console.log(`   facts: ${(p.matchup_facts || []).map((m) => `${m.label}: ${m.value}`).join(' | ')}`);
    if (p.market_odds) console.log(`   odds: ${p.market_odds} (${p.odds_source})`);
    console.log();
  }
  fs.writeFileSync('/tmp/combat_picks.json', JSON.stringify(draft, null, 2));
  console.log(`Wrote ${draft.length} picks → /tmp/combat_picks.json`);

  if (process.argv.includes('--insert')) {
    const rows = draft.map((p) => ({
      sport: 'combat', league: 'UFC',
      game_date: (/^\d{4}-\d{2}-\d{2}$/.test(p.game_date) && p.game_date >= todayISO()) ? p.game_date : todayISO(),
      game_id: p.game_id, home_team: p.home_team, away_team: p.away_team, pick: p.pick,
      probability: p.probability, confidence: p.confidence, reasoning: p.reasoning, key_factor: p.key_factor,
      matchup_facts: Array.isArray(p.matchup_facts) ? p.matchup_facts : [],
      market_odds: (typeof p.market_odds === 'number' && p.market_odds >= 1.01 && p.market_odds <= 25) ? p.market_odds : null,
      odds_source: (typeof p.odds_source === 'string' && p.odds_source.trim()) ? p.odds_source.trim() : null,
      predicted_score: null, field_odds: null, result: 'pending',
    }));
    const { error } = await supabase.from('picks').upsert(rows, { onConflict: 'league,game_date,game_id' });
    if (error) { console.error('INSERT FAILED:', error.message); process.exit(1); }
    console.log(`\n✅ Inserted/updated ${rows.length} UFC picks into the live table.`);
  } else {
    console.log('\n(dry run — pass --insert to write to the DB)');
  }
})().catch((e) => { console.error(e); process.exit(1); });
