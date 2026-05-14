# Daily content data schema

Each day's JSON file in this directory feeds the content generator
(`scripts/render-daily-content.js`). Update one file per day → re-run
the generator → get all 6+ branded PNGs in ~5 seconds.

## File naming

`data/daily/YYYY-MM-DD.json` (US Eastern Time date)

## Schema

```jsonc
{
  // Display date — what shows on the lineup card, etc.
  "date_label": "MAY 15",

  // ── TONIGHT'S PICK (drives confidence-card + ai-vs-vegas + lineup) ──
  "pick": {
    "matchup":        "DEN @ MIN",   // displayed prominently
    "line":           "OVER 224.5",  // bet specification
    "sport":          "NBA",         // used in hashtag generation
    "confidence":     81,            // Pick1 model %
    "vegas_implied":  52,            // Vegas consensus %
    "tip_time":       "8:00 PM ET",
    // Auto-computed/derived edge label and takeaway.
    // If absent, falls back to confidence - vegas_implied.
    "edge_label":     "+29 pts",
    "edge_takeaway":  "Vegas thinks this is a coin flip. Pick1's model disagrees — strongly. We'll log the result tomorrow either way."
  },

  // ── YESTERDAY'S RESULT (drives result.png) ──
  "yesterday": {
    "pick":           "SPURS +5.5",
    "confidence":     78.6,
    "verdict":        "win",         // "win" / "loss" / "push" — controls color
    "verdict_label":  "✓ WIN",       // displayed text
    "result_score":   "126—97",
    "result_detail":  "SPURS COVERED BY 23.5"
  },

  // ── ROLLING STREAK STATS (drives streak.png) ──
  "streak": {
    "window_days":     14,
    "wins":            9,
    "losses":          3,
    "pending":         2,           // optional, hidden if 0
    "win_rate":        75,          // %
    "avg_confidence":  76.4,
    "clv":             3.2,         // numeric (used for sign)
    "clv_label":       "+3.2%"      // displayed string
  },

  // ── TONIGHT'S FULL SLATE (drives lineup.png — first 5 used) ──
  "games": [
    { "time": "8:00P", "matchup": "DEN @ MIN", "line": "over 224.5", "confidence": 81, "is_pick": true },
    { "time": "7:00P", "matchup": "BOS @ MIA", "line": "BOS -3.5",   "confidence": 67, "is_pick": false },
    { "time": "7:30P", "matchup": "PHI @ NYK", "line": "over 218",   "confidence": 62, "is_pick": false },
    { "time": "10:00P","matchup": "LAL @ GSW", "line": "GSW -2.5",   "confidence": 58, "is_pick": false },
    { "time": "10:30P","matchup": "DAL @ LAC", "line": "over 222",   "confidence": 54, "is_pick": false }
  ],

  // ── SWEEPSTAKES (drives sweeps-reminder.png) ──
  "sweeps": {
    "days_left": 17,
    "url":       "https://gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro"
  }
}
```

## Workflow

```bash
# 1. Copy yesterday's file as a starting point
cp data/daily/2026-05-15.json data/daily/2026-05-16.json

# 2. Edit the new file with today's data
$EDITOR data/daily/2026-05-16.json

# 3. Run the generator
node scripts/render-daily-content.js 2026-05-16

# 4. Output lands in assets/ad-creative/v3/daily/2026-05-16/
ls assets/ad-creative/v3/daily/2026-05-16/
# confidence.png · result.png · streak.png · ai-vs-vegas.png · lineup.png · sweeps-reminder.png · captions.md
```

## Time budget

- Update JSON: **2-5 min** (you can pull from Pick1's actual model)
- Run generator: **~5 sec**
- Total: **<10 min/day** for 6 branded social-ready PNGs

vs. doing the same in Figma manually: **2-3 hours/day**.

## How to add a new template

1. Drop `scripts/templates/<name>.html` with `{{placeholder}}` tokens
2. Add an entry to `TEMPLATES` array in `scripts/render-daily-content.js`
   with name, dimensions, and a `caption(d)` function
3. Re-run. Done.
