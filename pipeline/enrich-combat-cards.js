// Enrich existing UFC picks with tale-of-the-tape facts + structured data.
// No AI — pure ESPN data. Run: railway run --service worker node enrich-combat-cards.js
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const combat = require('./combat');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY);
const todayISO = () => new Date().toISOString().slice(0, 10);

(async () => {
  const card = await combat.fetchUpcomingCard();
  const byId = new Map(card.fights.map((f) => [`ufc-${f.fightId}`, f]));

  const { data: picks, error } = await supabase.from('picks')
    .select('id, game_id, home_team, away_team').eq('league', 'UFC').gte('game_date', todayISO());
  if (error) { console.error(error.message); process.exit(1); }
  console.log(`Enriching ${picks.length} UFC picks…`);

  let done = 0;
  for (const p of picks) {
    const fight = byId.get(p.game_id)
      || card.fights.find((f) => [f.a.name, f.b.name].includes(p.home_team) || [f.a.name, f.b.name].includes(p.away_team));
    if (!fight) { console.log(`  ⚠️  no card match for ${p.home_team} vs ${p.away_team}`); continue; }
    const tot = await combat.buildTaleOfTape(fight);
    const facts = combat.combatComparisonFacts(tot);
    if (!facts.length) { console.log(`  ⚠️  no tale data for ${p.home_team} vs ${p.away_team}`); continue; }
    const { error: ue } = await supabase.from('picks')
      .update({ matchup_facts: facts, tale_of_tape: tot }).eq('id', p.id);
    if (ue) { console.log(`  ✗ ${p.home_team}: ${ue.message}`); continue; }
    done++;
    console.log(`  ✅ ${p.home_team} vs ${p.away_team} — ${facts.length} facts + tale of tape`);
  }
  console.log(`\nEnriched ${done}/${picks.length} picks.`);
})().catch((e) => { console.error(e); process.exit(1); });
