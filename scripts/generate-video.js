#!/usr/bin/env node
//
// AI video generator — programmatic alternative to Higgsfield.
//
// Uses Replicate.com's API (https://replicate.com/docs/reference/http)
// to generate cinematic video clips from text prompts. Same outputs as
// Higgsfield, but scriptable + ~10x cheaper.
//
// MODELS USED (all available on Replicate, 2026):
//   - kling-v2.0       — best quality, ~$0.40/video, 5 sec, 720p
//   - luma-ray-2       — fastest, ~$0.20/video, 5 sec, 720p
//   - hunyuan-video    — open-source, ~$0.10/video, slower
//
// USAGE
//   REPLICATE_API_TOKEN=r8_xxx node scripts/generate-video.js prompts.json
//
// INPUT (prompts.json)
//   [
//     {
//       "name": "the-ledger",
//       "prompt": "Cinematic close-up of an old leather-bound ledger...",
//       "duration": 5,
//       "aspect_ratio": "9:16"
//     },
//     ...
//   ]
//
// OUTPUT
//   assets/ad-creative/v3/video/<name>.mp4 — one MP4 per prompt
//
// COST
//   ~$0.10-$0.40 per video. 30 videos = $3-12 total.
//   Compare to Higgsfield: $29/mo for ~100 generations.
//
// SETUP (one-time)
//   1. Sign up at replicate.com (free, no card required to start)
//   2. Add $10 credit (covers ~30-100 videos depending on model)
//   3. Copy API token from replicate.com/account/api-tokens
//   4. Run: export REPLICATE_API_TOKEN=r8_xxx
//   5. Run this script

'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');

const TOKEN = process.env.REPLICATE_API_TOKEN;
if (!TOKEN) {
  console.error('✗ REPLICATE_API_TOKEN not set. Run: export REPLICATE_API_TOKEN=r8_xxx');
  console.error('  Get one at: https://replicate.com/account/api-tokens');
  process.exit(1);
}

const REPO_ROOT = path.resolve(__dirname, '..');
const OUT_DIR = path.join(REPO_ROOT, 'assets', 'ad-creative', 'v3', 'video');
fs.mkdirSync(OUT_DIR, { recursive: true });

// Default model — change here to switch between providers. Pinning the
// version SHA so the output is reproducible — Replicate models can change
// behavior on version bumps.
const MODEL = {
  // Kling v2.0 — highest cinematic quality. Try this first.
  // To switch to faster/cheaper: swap to "luma/ray-2" or "tencent/hunyuan-video".
  owner: 'kwaivgi',
  name:  'kling-v2.0',
  // Version SHA — update from https://replicate.com/kwaivgi/kling-v2.0/versions if needed
  version: null, // null = latest
};

/** Fire an HTTPS request and return the response body parsed as JSON. */
function request(method, url, body = null) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = https.request({
      method,
      hostname: u.hostname,
      path: u.pathname + u.search,
      headers: {
        'Authorization': `Token ${TOKEN}`,
        'Content-Type':  'application/json',
        'User-Agent':    'pick1-content-generator/1.0',
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          const parsed = data ? JSON.parse(data) : null;
          if (res.statusCode >= 400) {
            return reject(new Error(`Replicate ${res.statusCode}: ${JSON.stringify(parsed)}`));
          }
          resolve(parsed);
        } catch (err) {
          reject(new Error(`Failed to parse Replicate response (status ${res.statusCode}): ${data.slice(0, 200)}`));
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

/** Download a file from a URL to a local path. */
function download(url, outPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(outPath);
    https.get(url, (res) => {
      // Replicate output URLs sometimes redirect to a CDN — follow once.
      if (res.statusCode === 301 || res.statusCode === 302) {
        file.close();
        fs.unlinkSync(outPath);
        return download(res.headers.location, outPath).then(resolve, reject);
      }
      if (res.statusCode !== 200) {
        file.close();
        fs.unlinkSync(outPath);
        return reject(new Error(`Download failed: ${res.statusCode}`));
      }
      res.pipe(file);
      file.on('finish', () => file.close(resolve));
    }).on('error', reject);
  });
}

/** Generate one video from a prompt. Polls Replicate until done. */
async function generateOne({ name, prompt, duration = 5, aspect_ratio = '9:16' }) {
  console.log(`▶ ${name}`);
  console.log(`  prompt: ${prompt.slice(0, 80)}${prompt.length > 80 ? '…' : ''}`);

  // 1. Create the prediction. Each model has its own input shape — Kling
  //    accepts { prompt, duration, aspect_ratio }. Other models may need
  //    different keys (see replicate.com/<model>/api).
  const predictionUrl = MODEL.version
    ? 'https://api.replicate.com/v1/predictions'
    : `https://api.replicate.com/v1/models/${MODEL.owner}/${MODEL.name}/predictions`;

  const body = MODEL.version
    ? { version: MODEL.version, input: { prompt, duration, aspect_ratio } }
    : { input: { prompt, duration, aspect_ratio } };

  const prediction = await request('POST', predictionUrl, body);
  console.log(`  prediction id: ${prediction.id}`);

  // 2. Poll until the prediction finishes. Replicate has a
  //    "Prefer: wait=N" header for synchronous-style waits up to 60s,
  //    but we poll explicitly here for cross-version compatibility.
  let final = prediction;
  const maxAttempts = 60; // ~10 min cap (60 × 10 sec)
  for (let i = 0; i < maxAttempts; i++) {
    if (final.status === 'succeeded' || final.status === 'failed' || final.status === 'canceled') break;
    await new Promise(r => setTimeout(r, 10_000));
    final = await request('GET', `https://api.replicate.com/v1/predictions/${prediction.id}`);
    if (i % 3 === 0) console.log(`  status: ${final.status}…`);
  }

  if (final.status !== 'succeeded') {
    throw new Error(`Prediction ${final.status}: ${final.error || 'no error message'}`);
  }

  // 3. Download the output MP4. Kling returns a single URL string;
  //    other models may return an array — handle both.
  const outputUrl = Array.isArray(final.output) ? final.output[0] : final.output;
  if (!outputUrl) throw new Error('No output URL in completed prediction');

  const outPath = path.join(OUT_DIR, `${name}.mp4`);
  await download(outputUrl, outPath);
  console.log(`  ✓ saved → ${path.relative(REPO_ROOT, outPath)}`);
  return outPath;
}

async function main() {
  const promptsFile = process.argv[2];
  if (!promptsFile) {
    console.error('Usage: node scripts/generate-video.js <prompts.json>');
    console.error('  See scripts/templates/video-prompts.example.json for shape.');
    process.exit(1);
  }
  const prompts = JSON.parse(fs.readFileSync(promptsFile, 'utf8'));
  if (!Array.isArray(prompts)) {
    console.error('✗ prompts.json must be an array');
    process.exit(1);
  }

  console.log(`Generating ${prompts.length} videos via Replicate (${MODEL.owner}/${MODEL.name})`);
  console.log('');

  const results = [];
  for (const p of prompts) {
    try {
      const outPath = await generateOne(p);
      results.push({ name: p.name, status: 'ok', path: outPath });
    } catch (err) {
      console.error(`  ✗ ${p.name} failed: ${err.message}`);
      results.push({ name: p.name, status: 'failed', error: err.message });
    }
  }

  console.log('');
  const ok = results.filter(r => r.status === 'ok').length;
  console.log(`✓ Done — ${ok}/${results.length} videos generated`);
  if (ok < results.length) {
    console.log('  Failed:');
    results.filter(r => r.status === 'failed').forEach(r => {
      console.log(`    - ${r.name}: ${r.error}`);
    });
  }
}

if (require.main === module) main();
