// Backfill betting_props: combat (method + distance via one grounded call)
// and team sports (deterministic from predicted_score). No team-sport AI.
// Run: railway run --service worker node backfill-props.js
require('dotenv').config();
const Anthropic = require('@anthropic-ai/sdk');
const { createClient } = require('@supabase/supabase-js');
const combat = require('./combat');
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY);
const MODEL = 'claude-opus-4-7';
const todayISO = () => new Date().toISOString().slice(0, 10);

(async () => {
  const teamOnly = process.argv.includes('--team-only');
  // ── Combat ──────────────────────────────────────────────────────
  const gt = teamOnly ? null : await combat.buildCardGroundTruth();
  if (gt?.fights?.length) {
    const outcomes = await combat.generateCombatProps({ anthropic, model: MODEL, groundTruth: gt });
    const byPair = new Map();
    for (const o of outcomes) { byPair.set(`${o.home_team}|${o.away_team}`, o); byPair.set(`${o.away_team}|${o.home_team}`, o); }
    const { data: ufc } = await supabase.from('picks').select('id, home_team, away_team').eq('league', 'UFC').gte('game_date', todayISO());
    for (const p of ufc || []) {
      const o = byPair.get(`${p.home_team}|${p.away_team}`);
      const items = combat.combatPropItems(o);
      await supabase.from('picks').update({ betting_props: items }).eq('id', p.id);
      console.log(`  🥊 ${p.home_team} vs ${p.away_team}: ${items.map((i) => `${i.label}=${i.value}`).join(', ') || '(no confident call)'}`);
    }
  }

  // ── Team sports (deterministic) ─────────────────────────────────
  const { data: team } = await supabase.from('picks')
    .select('id, sport, league, home_team, away_team, pick, predicted_score')
    .gte('game_date', todayISO()).not('predicted_score', 'is', null);
  let teamDone = 0;
  for (const p of team || []) {
    const items = combat.teamBettingProps({ predictedScore: p.predicted_score, homeTeam: p.home_team, awayTeam: p.away_team, pick: p.pick, sport: p.sport });
    if (!items.length) continue;
    await supabase.from('picks').update({ betting_props: items }).eq('id', p.id);
    teamDone++;
    console.log(`  🏟️  ${p.league} ${p.home_team} v ${p.away_team}: ${items.map((i) => `${i.label}=${i.value}`).join(', ')}`);
  }
  console.log(`\nDone. Team picks enriched: ${teamDone}.`);
})().catch((e) => { console.error(e); process.exit(1); });
