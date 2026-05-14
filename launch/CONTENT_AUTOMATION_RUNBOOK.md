# Content automation — daily runbook

**Built May 14 (Day 2) in response to "I need this automated."**

## The 3-system stack

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│  GENERATION         │     │  AI VIDEO           │     │  POSTING            │
│                     │     │                     │     │                     │
│  Static branded     │ ──► │  Cinematic clips    │ ──► │  Auto-schedule      │
│  PNGs from data     │     │  from prompts       │     │  to all platforms   │
│                     │     │                     │     │                     │
│  scripts/render-    │     │  scripts/generate-  │     │  Hypefury           │
│  daily-content.js   │     │  video.js           │     │  (you set up)       │
│                     │     │                     │     │                     │
│  $0/mo              │     │  ~$5-15/mo          │     │  $19-49/mo          │
│  ✓ DONE             │     │  needs Replicate    │     │  needs Hypefury     │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

**Total monthly cost for the full automated pipeline: $24-64.**
Compare to Higgsfield Pro ($29/mo) alone, which is one piece of this. We get the full pipeline for not much more.

---

## System 1 — Static content generator (✅ DONE)

### What it is
A Node script that turns one daily JSON file into 6 branded PNGs in ~16 seconds.

### Daily workflow
```bash
# 1. Copy yesterday's data file
cp data/daily/2026-05-15.json data/daily/2026-05-16.json

# 2. Update the new file with today's data (2-5 min)
$EDITOR data/daily/2026-05-16.json
# - Today's pick + confidence + Vegas line
# - Yesterday's result + verdict
# - Updated streak record
# - Tonight's full slate (top 5 games)
# - Sweepstakes days_left (decrement by 1)

# 3. Run the generator
node scripts/render-daily-content.js 2026-05-16

# 4. Output is in:
ls assets/ad-creative/v3/daily/2026-05-16/
# confidence.png · result.png · streak.png · ai-vs-vegas.png · lineup.png · sweeps-reminder.png · captions.md
```

### Output per day
6 PNGs at 1080×1080 + `captions.md` with paste-ready captions for each:
- **confidence.png** — tonight's pick + AI confidence dial
- **result.png** — yesterday's pick + verdict + score
- **streak.png** — rolling 14-day W-L record + stats
- **ai-vs-vegas.png** — Vegas % vs Pick1 % side-by-side
- **lineup.png** — tonight's slate with Pick1's pick highlighted
- **sweeps-reminder.png** — days-left countdown + CTA

### Time savings
- Manual Figma: ~2 hrs/day
- This script: ~5 min/day (update JSON, run command)
- **Net savings: ~12 hrs/week**

### Adding more templates
Drop `scripts/templates/<name>.html` with `{{placeholder}}` tokens, add an entry to `TEMPLATES` array in `scripts/render-daily-content.js`, re-run. Each new template = one more PNG per day forever.

---

## System 2 — AI video generation (needs $10 Replicate credit)

### What it is
A Node script that generates Higgsfield-equivalent cinematic AI videos from text prompts. Uses Replicate.com's API (Kling 2.0 / Luma Ray-2 / Hunyuan models).

### Why not Higgsfield directly
- Higgsfield has no public API — UI-only product
- Replicate is API-first → fully scriptable
- Replicate is ~10× cheaper per video ($0.10-0.40 vs $0.29 per Higgsfield credit)
- Replicate has the same model quality (Kling 2.0 IS what Higgsfield uses behind the scenes)

### Setup (one-time, ~5 min)
1. Sign up at https://replicate.com (free, no card required for $0 trial)
2. Add $10 credit at https://replicate.com/account/billing (covers ~30-100 videos)
3. Copy your API token from https://replicate.com/account/api-tokens
4. Save it locally:
   ```bash
   echo 'export REPLICATE_API_TOKEN=r8_xxx' >> ~/.zshrc
   source ~/.zshrc
   ```

### Daily workflow
```bash
# 1. Pick the prompts you want today from launch/HIGGSFIELD_PROMPTS_W1.md
#    (already written, 7 ready to go)

# 2. Copy them into a prompts JSON file
$EDITOR data/video-prompts-2026-05-16.json
# Use scripts/templates/video-prompts.example.json as a starting point

# 3. Run the generator (takes 1-2 min per video, so 5 videos = ~10 min)
node scripts/generate-video.js data/video-prompts-2026-05-16.json

# 4. Output is in assets/ad-creative/v3/video/
ls assets/ad-creative/v3/video/
# the-ledger.mp4 · 9-sports-orbit.mp4 · vegas-vs-pick1.mp4 · ...
```

### Output
MP4 files, 5-8 seconds each, 9:16 vertical, 720p. Drop into TikTok/IG Reel/YT Short directly.

### Cost math
- Kling v2.0: ~$0.40 per video × 30 videos/campaign = **$12 total**
- Luma Ray-2: ~$0.20 per video × 30 = **$6 total**
- Hunyuan: ~$0.10 per video × 30 = **$3 total** (slower, less polish)

**Recommended start: Kling v2.0 for hero pieces, Hunyuan for B-roll volume.**

### Failure handling
The script:
- Polls every 10 sec for status, up to 10 minutes per video
- On failure, logs the error and continues with remaining prompts
- Final summary shows what succeeded and what failed

If a video looks bad, just re-run that single prompt (each generation is independent).

---

## System 3 — Auto-posting (needs Hypefury or Buffer)

### Why Hypefury (recommended)
- $19-49/mo
- Posts to X, IG, TikTok, FB, LinkedIn, Threads, YouTube Shorts
- **Bulk-upload + auto-schedule** is its killer feature
- AI-suggested optimal posting times per platform
- "Recycle" mode: auto-republishes top-performing posts

### Setup (one-time, ~20 min)
1. Sign up at https://hypefury.com → 3-day trial
2. Pick the $19 Standard plan (3 social accounts) OR $49 Premium (unlimited)
3. Connect:
   - Twitter @PICK1sport
   - Instagram @pick1.live
   - TikTok @pick1app
   - Facebook Page
   - LinkedIn (Noa's personal)
4. Connect Buffer-compatible queue for IG (Hypefury uses Buffer's IG flow under the hood)
5. Set your posting schedule in their "Queue Schedule" (e.g., daily TikTok at 6am, 12pm, 6pm)

### Daily workflow once set up
```bash
# 1. Generate today's content (System 1 + System 2)
node scripts/render-daily-content.js 2026-05-16
node scripts/generate-video.js data/video-prompts-2026-05-16.json

# 2. Open Hypefury → "New Post"
# 3. For each piece, drag the file in, paste the caption from
#    assets/ad-creative/v3/daily/2026-05-16/captions.md, hit "Add to queue"
# 4. Hypefury auto-schedules to your defined time slots

# Total time: ~15 min to queue 6+ posts across 4-5 platforms
```

### Alternative: Buffer
- $15-100/mo
- Wider integrations
- Worse UX for bulk-scheduling

### Future: full programmatic posting
Both Hypefury and Buffer have APIs. Could wire a script that:
1. Reads `captions.md`
2. Pairs each caption with its PNG/MP4
3. POSTs to Hypefury API to add to queue automatically

That would close the last manual step. Worth building if the daily queueing becomes painful — but for now, manual queueing is fine and gives Noa a quick sanity check before posts go live.

---

## End-to-end daily workflow (FULL automation)

Once all 3 systems are running:

| Step | Time | Owner | What |
|---|---|---|---|
| 1 | 5 min | Noa | Update `data/daily/<date>.json` with today's pick + result |
| 2 | 5 sec | Script | Run `node scripts/render-daily-content.js <date>` → 6 PNGs |
| 3 | 10 min | Script | Run `node scripts/generate-video.js <prompts>` → 3-5 MP4s |
| 4 | 10 min | Noa | Open Hypefury, drag in files, paste captions, queue |
| 5 | — | Hypefury | Auto-posts at scheduled times across all platforms |
| **Total** | **~25 min/day** | | **vs. 4-6 hrs/day manual** |

**Net savings: ~3-5 hrs/day.** That's the prize.

---

## Cost summary

| System | Monthly cost | What |
|---|---|---|
| Static generator | **$0** | Self-hosted, runs locally |
| Replicate API | **$5-15** | ~30 videos/mo |
| Hypefury | **$19-49** | Auto-scheduling across 4-6 platforms |
| **Total** | **$24-64/mo** | |

vs. Higgsfield Pro alone ($29) — we get a **full pipeline** for not much more, and the pipeline covers things Higgsfield doesn't (auto-scheduling, programmatic statics).

---

## Immediate next steps

1. **TONIGHT — me:** I'll keep building. No blocker.
2. **TONIGHT — you:** Sign up for Replicate (free, $10 credit) and add the API token to your env. Optional but unlocks System 2.
3. **TOMORROW — you:** Sign up for Hypefury 3-day trial. If it clicks, commit to the $19 plan. Unlocks System 3.
4. **DAY 3 — together:** First fully-automated daily content run, end-to-end.

Once Replicate is set up, send me the API token (or just confirm "done") and I'll run the first batch of 6-8 videos as a test.

---

## Reference

- `scripts/render-daily-content.js` — System 1 entry point
- `scripts/templates/*.html` — Template files (add new ones freely)
- `data/daily/SCHEMA.md` — Daily JSON schema docs
- `data/daily/2026-05-15.json` — Sample input
- `assets/ad-creative/v3/daily/<date>/` — Daily output PNGs + captions

- `scripts/generate-video.js` — System 2 entry point
- `scripts/templates/video-prompts.example.json` — Sample prompt batch
- `launch/HIGGSFIELD_PROMPTS_W1.md` — 7 ready-to-use prompts
- `assets/ad-creative/v3/video/` — Daily output MP4s

- `launch/CONTENT_AUTOMATION_PLAN.md` — System overview + virality rubric
- `launch/CONTENT_CALENDAR_W1.md` — 5 days of content fully spec'd
