// Ground existing World Cup picks: replace model matchup_facts with
// ESPN-sourced standings/form facts. No AI. Run via railway run.
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const soccer = require('./soccer');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY);
const todayISO = () => new Date().toISOString().slice(0, 10);

(async () => {
  const { data: picks, error } = await supabase.from('picks')
    .select('id, home_team, away_team').eq('league', 'WC').gte('game_date', todayISO());
  if (error) { console.error(error.message); process.exit(1); }
  const enriched = await soccer.enrichPicks(picks.map((p) => ({ ...p })));
  let done = 0;
  for (const p of enriched) {
    if (!p.soccer_comparison) { console.log(`  ⚠️  no ESPN match: ${p.home_team} v ${p.away_team}`); continue; }
    const { error: ue } = await supabase.from('picks')
      .update({ matchup_facts: p.matchup_facts, soccer_comparison: p.soccer_comparison }).eq('id', p.id);
    if (ue) { console.log(`  ✗ ${p.home_team}: ${ue.message}`); continue; }
    done++;
    console.log(`  ✅ ${p.home_team} v ${p.away_team}: ${p.matchup_facts.length} grounded facts`);
  }
  console.log(`\nGrounded ${done}/${picks.length} World Cup picks.`);
})().catch((e) => { console.error(e); process.exit(1); });
