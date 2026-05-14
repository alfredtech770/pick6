#!/usr/bin/env node
//
// Daily content generator — renders all branded social tiles from a
// single daily-data JSON in ~30 seconds. The whole point: turn 2 hours
// of manual Figma work into a one-command pipeline.
//
// USAGE
//   node scripts/render-daily-content.js [YYYY-MM-DD]
//
// If no date arg is given, uses today (in ET).
//
// INPUTS
//   data/daily/<date>.json — schema in data/daily/SCHEMA.md
//   scripts/templates/*.html — placeholder templates using {{key}} syntax
//
// OUTPUTS
//   assets/ad-creative/v3/daily/<date>/<template>.png — one PNG per template
//   assets/ad-creative/v3/daily/<date>/captions.md — paste-ready captions
//
// HOW IT WORKS
//   1. Reads the day's JSON
//   2. For each template, fills {{placeholders}} from the JSON
//   3. Writes the filled HTML to /tmp
//   4. Runs headless Chrome to screenshot it at the right size
//   5. Generates a captions.md alongside the PNGs
//
// REQUIREMENTS
//   - macOS with Google Chrome at the standard install path (adjust
//     CHROME_PATH below for Linux/CI)
//   - Node.js 18+ (uses fs.promises and string replaceAll)

'use strict';
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ── Config ───────────────────────────────────────────────────────────────
const CHROME_PATH = process.env.CHROME_PATH
  || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const REPO_ROOT = path.resolve(__dirname, '..');
const TEMPLATE_DIR = path.join(REPO_ROOT, 'scripts', 'templates');
const DATA_DIR = path.join(REPO_ROOT, 'data', 'daily');
const OUT_BASE = path.join(REPO_ROOT, 'assets', 'ad-creative', 'v3', 'daily');

// Each template knows its render dimensions + a function that returns the
// caption block for that template. Keeps the templates dumb and the
// captions/dimensions colocated with the renderer.
const TEMPLATES = [
  {
    name: 'confidence',
    width: 1080, height: 1080,
    caption: (d) => `Tonight's pick is locked.\n\n🎯 ${d.pick.matchup} ${d.pick.line} — ${d.pick.confidence}% AI confidence.\n\nResult posted tomorrow — win or lose. Track every Pick1 call live at pick1.live/tracker\n\n#${d.pick.sport.toLowerCase()} #sportsbetting #aiprediction #picksdaily #sportstok`,
  },
  {
    name: 'result',
    width: 1080, height: 1080,
    caption: (d) => `Yesterday's call. Logged before tip-off.\n\nPre-game: ${d.yesterday.pick} @ ${d.yesterday.confidence}% AI confidence.\nResult: ${d.yesterday.result_score}. ${d.yesterday.verdict === 'win' ? '✅ Covered' : '❌ Missed'}\n\nEvery Pick1 prediction sits in our public ledger — pick1.live/tracker\n\n#receipts #sportsbettingtips #aibetting #picksdaily`,
  },
  {
    name: 'streak',
    width: 1080, height: 1080,
    caption: (d) => `Pick1 is ${d.streak.wins}-${d.streak.losses} in the last ${d.streak.window_days} days.\n\n${d.streak.win_rate}% win rate · ${d.streak.avg_confidence}% avg confidence · CLV ${d.streak.clv > 0 ? '+' : ''}${d.streak.clv}%\n\nReceipts at pick1.live/tracker — every call wins AND misses, public, no edits.\n\n#sportsbettingtips #picksdaily #aibetting #receipts`,
  },
  {
    name: 'ai-vs-vegas',
    width: 1080, height: 1080,
    caption: (d) => `Vegas vs Pick1 — tonight's edge.\n\nVegas consensus: ${d.pick.vegas_implied}%\nPick1 model: ${d.pick.confidence}%\nGap: ${d.pick.confidence - d.pick.vegas_implied > 0 ? '+' : ''}${d.pick.confidence - d.pick.vegas_implied} pts\n\n${d.pick.matchup} · ${d.pick.line} · tip-off ${d.pick.tip_time}\n\nResult tomorrow — pick1.live/tracker\n\n#sportsbetting #ai #aitech #picksdaily`,
  },
  {
    name: 'lineup',
    width: 1080, height: 1080,
    caption: (d) => `Tonight's full slate.\n\n${d.games.map(g => `${g.time} · ${g.matchup} · ${g.line}${g.is_pick ? ' 🎯 PICK1' : ''}`).join('\n')}\n\nOnly one of these gets the Pick1 call. The highest-confidence one.\n\npick1.live for tonight's pick.\n\n#sportsbetting #picksdaily #parlay`,
  },
  {
    name: 'sweeps-reminder',
    width: 1080, height: 1080,
    caption: (d) => `${d.sweeps.days_left} days left to enter.\n\n🏆 Win 2 FIFA World Cup tickets + Lifetime Pick1 Pro\n$1,499 prize value · Free to enter · Drawn live May 31\n\nLink in bio → pick1.live\n\n#fifaworldcup #worldcup2026 #sweepstakes #freegiveaway #sportstok`,
  },
];

// ── Helpers ──────────────────────────────────────────────────────────────

/** Naïvely deep-flatten an object to dot-notation keys. So:
 *    flatten({ pick: { matchup: "DEN @ MIN" } })
 *    → { "pick.matchup": "DEN @ MIN" }
 * Templates use `{{pick.matchup}}` syntax, which keeps the placeholders
 * readable but works against an arbitrarily-nested JSON schema. */
function flatten(obj, prefix = '') {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      Object.assign(out, flatten(v, key));
    } else if (Array.isArray(v)) {
      // For arrays (e.g. games list), expose indexed access:
      //    games[0].matchup → games.0.matchup
      v.forEach((item, i) => {
        if (item && typeof item === 'object') {
          Object.assign(out, flatten(item, `${key}.${i}`));
        } else {
          out[`${key}.${i}`] = item;
        }
      });
      // Also expose the array length for conditional logic in templates.
      out[`${key}.length`] = v.length;
    } else {
      out[key] = v;
    }
  }
  return out;
}

/** Replace every `{{key}}` token in a string with the matching flat value.
 * Missing keys are replaced with empty string so a malformed template
 * doesn't render `{{undefined}}` to the user. */
function fillTemplate(html, flatData) {
  return html.replace(/\{\{([^}]+)\}\}/g, (match, key) => {
    const k = key.trim();
    return Object.prototype.hasOwnProperty.call(flatData, k)
      ? String(flatData[k])
      : '';
  });
}

/** Conditional include: keep block between `{{#if key}}...{{/if}}` only
 * when flatData[key] is truthy. Lets templates branch on data presence
 * without spawning a full templating engine. */
function applyConditionals(html, flatData) {
  return html.replace(
    /\{\{#if ([^}]+)\}\}([\s\S]*?)\{\{\/if\}\}/g,
    (_, key, block) => {
      const k = key.trim();
      return flatData[k] ? block : '';
    }
  );
}

/** Render one HTML file to a PNG screenshot at the given dimensions. */
function renderToPng({ html, width, height, outPath }) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const tmpHtmlPath = path.join(
    require('os').tmpdir(),
    `render-${Date.now()}-${Math.random().toString(36).slice(2)}.html`,
  );
  fs.writeFileSync(tmpHtmlPath, html, 'utf8');
  // Use the file:// URL form for the Chrome --screenshot flag — Chrome
  // can't read stdin or piped HTML.
  try {
    execSync(
      `"${CHROME_PATH}" --headless --disable-gpu --no-sandbox --hide-scrollbars --window-size=${width},${height} --screenshot="${outPath}" "file://${tmpHtmlPath}"`,
      { stdio: ['ignore', 'ignore', 'pipe'] },
    );
  } finally {
    // Always clean up the tmp file, even on render failure.
    fs.unlinkSync(tmpHtmlPath);
  }
}

// ── Main ─────────────────────────────────────────────────────────────────

function main() {
  const date = process.argv[2] || new Date().toISOString().slice(0, 10);
  const dataPath = path.join(DATA_DIR, `${date}.json`);
  if (!fs.existsSync(dataPath)) {
    console.error(`✗ No data file found at ${dataPath}`);
    console.error(`  Create one based on data/daily/SCHEMA.md, or copy a previous day's file.`);
    process.exit(1);
  }

  const rawData = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  const flatData = flatten(rawData);
  const outDir = path.join(OUT_BASE, date);
  fs.mkdirSync(outDir, { recursive: true });

  console.log(`▶ Rendering Pick1 daily content for ${date}`);
  console.log(`  data:    ${dataPath}`);
  console.log(`  output:  ${outDir}`);
  console.log('');

  const captions = [];
  const tStart = Date.now();

  for (const tpl of TEMPLATES) {
    const tplPath = path.join(TEMPLATE_DIR, `${tpl.name}.html`);
    if (!fs.existsSync(tplPath)) {
      console.warn(`  ⚠ template missing: ${tpl.name}.html — skipping`);
      continue;
    }
    const t0 = Date.now();
    const raw = fs.readFileSync(tplPath, 'utf8');
    // Apply conditionals first so {{key}} replacements don't fire inside
    // blocks that are about to be stripped.
    const withConditionals = applyConditionals(raw, flatData);
    const filled = fillTemplate(withConditionals, flatData);
    const outPath = path.join(outDir, `${tpl.name}.png`);
    try {
      renderToPng({
        html: filled,
        width: tpl.width,
        height: tpl.height,
        outPath,
      });
      const ms = Date.now() - t0;
      console.log(`  ✓ ${tpl.name.padEnd(20)} → ${path.relative(REPO_ROOT, outPath)}  (${ms}ms)`);
      captions.push({ name: tpl.name, png: path.basename(outPath), caption: tpl.caption(rawData) });
    } catch (err) {
      console.error(`  ✗ ${tpl.name} render failed:`, err.message);
    }
  }

  // Write captions.md alongside the PNGs so the user can copy-paste them
  // straight into IG/X/etc. without context-switching.
  const captionsPath = path.join(outDir, 'captions.md');
  const captionsMd = [
    `# Pick1 daily content — ${date}`,
    '',
    `Generated ${new Date().toISOString()}. ${captions.length} pieces.`,
    '',
    '---',
    '',
    captions.map(({ name, png, caption }) => [
      `## ${name} — \`${png}\``,
      '',
      '```',
      caption,
      '```',
      '',
    ].join('\n')).join('\n---\n\n'),
  ].join('\n');
  fs.writeFileSync(captionsPath, captionsMd, 'utf8');
  console.log(`  ✓ captions          → ${path.relative(REPO_ROOT, captionsPath)}`);

  const totalMs = Date.now() - tStart;
  console.log('');
  console.log(`✓ Done in ${(totalMs / 1000).toFixed(1)}s — ${captions.length} pieces ready`);
}

if (require.main === module) main();
