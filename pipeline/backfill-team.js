// Ground existing MLB/NBA/WNBA/NFL/NHL picks with ESPN season data.
// No AI. Run: railway run --service worker node backfill-team.js
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const teamsport = require('./teamsport');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY);
const todayISO = () => new Date().toISOString().slice(0, 10);

(async () => {
  for (const league of Object.keys(teamsport.PATHS)) {
    const { data: picks, error } = await supabase.from('picks')
      .select('id, home_team, away_team').eq('league', league).gte('game_date', todayISO());
    if (error || !picks?.length) { if (picks?.length) console.error(error?.message); continue; }
    const enriched = await teamsport.enrichPicks(league, picks.map((p) => ({ ...p })));
    let done = 0;
    for (const p of enriched) {
      if (!p.team_comparison) { console.log(`  ⚠️  ${league} no ESPN match: ${p.home_team} v ${p.away_team}`); continue; }
      const { error: ue } = await supabase.from('picks')
        .update({ matchup_facts: p.matchup_facts, team_comparison: p.team_comparison }).eq('id', p.id);
      if (ue) { console.log(`  ✗ ${p.home_team}: ${ue.message}`); continue; }
      done++;
      console.log(`  ✅ ${league} ${p.away_team} @ ${p.home_team}: ${p.matchup_facts.length} grounded facts`);
    }
    if (picks.length) console.log(`  ${league}: grounded ${done}/${picks.length}\n`);
  }
})().catch((e) => { console.error(e); process.exit(1); });
