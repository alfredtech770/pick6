# Content automation system — Pick1

A system for producing 30-50 brand-consistent content pieces per day
across all platforms, with a virality QC rubric in front of every
piece. Approved Day 2 (May 14) by Noa.

## The 4-step pipeline

```
1. CONCEPT          →    2. SCORE       →    3. PRODUCE       →    4. POST
   (Claude writes        (rubric         (HTML→PNG or         (Noa runs
   hook + structure)     /50, ≥35        Higgsfield prompt    Higgsfield
                         to ship)        rendering)            + posts)
```

### Step 1 — Concept (Claude)
For each calendar slot: hook (first 70 chars), structure (beats),
caption, hashtags, asset type (static / video / carousel).

### Step 2 — Score (Claude)
Each piece scored against the **Pick1 Virality Rubric** below.
**Anything <35/50 doesn't ship.** Better to post 6 great pieces than
12 mediocre ones.

### Step 3 — Produce
- **Static visuals (carousels, confidence cards, receipts, lineup cards):**
  Claude renders directly via HTML→PNG. Output: `assets/ad-creative/v3/`.
- **AI video b-roll (cinematic, atmospheric, animated):**
  Claude writes a Higgsfield prompt → Noa pastes into
  https://higgsfield.ai/supercomputer, runs, downloads.
- **Founder-led video (talking head, real face):**
  Claude writes the script + shot list → Noa records on phone.

### Step 4 — Post (Noa)
Per the schedule in this doc. Cross-post per platform's spec.

---

## Pick1 Virality Rubric (0-50)

Each piece scored on 5 factors, 0-10 each. **Ship threshold: ≥35.**

| Factor | What it measures | 0 (cut) | 5 (mid) | 10 (max) |
|---|---|---|---|---|
| **HOOK** | First 1.5 sec / first 70 chars | "Welcome to Pick1!" | "Today's pick is..." | "I bet $100 the AI is wrong tonight" |
| **INTERRUPT** | Does it stop the scroll? | Generic stock | Branded but expected | Surprising visual or claim |
| **SHARE** | Why would someone screenshot? | No clear reason | Has stats | Specific $/% numbers, controversy, FOMO |
| **ALGO FIT** | Length + format + sound + hashtag fit | Wrong length, no sound | OK length, generic sound | Trending sound, 30 sec, FYP-tagged |
| **AUTHENTIC** | Doesn't feel like a brand ad | Slick corporate | Polished but cold | Raw, specific, founder voice |

**Sample scores** (already-shipped assets):
- 9-grid Tile #1 "WIN 2 WC tickets" → **42/50** (huge hook, huge interrupt, $1,499 share value, perfect IG square format, slightly corporate but acceptable)
- 9-grid Tile #5 "EVERY CALL LOGGED" → **44/50** (manifesto, brand-defining, contrarian = share-worthy)
- Gleam hero (Feature Media style) → **40/50** (works for the ad target, less viral for organic)
- Tile #4 receipts (Spurs 78.6%) → **45/50** (specific, share-worthy receipts, authentic)

---

## What goes in each piece (the template)

```markdown
### #NN — DATE TIME ET — PLATFORM
**Hook:** [first 70 chars of caption or 1.5sec of video — quoted exactly]
**Structure:** [3-5 bullet beats for video, or layout for static]
**Caption:** [full caption, paste-ready]
**Hashtags:** [10-15 tags, mix of wide/niche]
**Asset:**
  - If static: `assets/ad-creative/v3/<file>.png` (Claude renders)
  - If video: Higgsfield prompt below
  - If founder: shot list + script
**Higgsfield prompt (if video):**
  "..." (copy-paste ready)
**Score:** XX/50 — Hook X, Interrupt X, Share X, Algo X, Authentic X
**Cross-posts:** [list of where this asset also goes]
```

---

## Higgsfield workflow (since you'll be running it)

### Per-prompt protocol
1. Open https://higgsfield.ai/supercomputer
2. Paste the prompt from the day's doc
3. Set parameters:
   - **Duration:** 5-8 sec (Higgsfield's sweet spot for shareability)
   - **Aspect ratio:** 9:16 for TikTok/Reel/Story, 1:1 for IG feed, 16:9 for YouTube/landscape
   - **Style:** "Cinematic" or "Documentary" for receipts content; "Hyperreal" or "Stylized" for atmosphere
4. Generate
5. Download the .mp4
6. Save to: `assets/ad-creative/v3/video/<prompt-id>.mp4`
7. Mark the row "DONE" in the calendar

### Time estimate
~60-90 sec per generation × 30 prompts/week = **30-45 min of batch time**.
Best done in a single session while doing email/admin.

### Higgsfield credit budget
At Higgsfield Pro ($29/mo for ~100 generations), 30 prompts/week = within plan.
If you want more, upgrade to Higgsfield Pro Max ($79/mo, unlimited) for the campaign.

### Optional: I run Higgsfield via Chrome MCP
If you'd prefer me to drive it, I can — but:
- Each download requires your manual approval (safety rule)
- Slower than you batching it yourself
- More error-prone (Chrome MCP has been flaky)
**Recommended: you batch yourself for speed.**

---

## Figma workflow (optional polish layer)

For pieces that need more design than HTML can do (custom layouts,
photo composition, illustration), the workflow:

1. I provide a Figma SPEC: exact colors, fonts, sizes, content
2. You (or a Figma plugin like "AI to Figma") executes the design
3. You export to PNG/MP4
4. Mark as DONE

For Pick1's brand, this should rarely be needed — Anton + Archivo +
JetBrains Mono + 2 brand colors is doable in HTML. Reserve Figma for
the "polished hero" pieces (1-2 per week max).

---

## Cross-post matrix

Every ORIGINAL piece gets cross-posted by default. Workflow:

| Original platform | Auto cross-posts |
|---|---|
| TikTok (9:16) | IG Reel, YouTube Short, Twitter video (centered), Facebook Reel |
| IG feed (1:1) | Threads (auto-toggle), Facebook Page (auto-toggle), Twitter image |
| IG Story | TikTok Story, Snapchat (optional), Facebook Story |
| IG carousel (1:1 × N) | LinkedIn carousel, Twitter thread (1 slide per tweet) |
| Twitter thread | LinkedIn long-form, Substack post, IG carousel |
| Substack post | Twitter thread, LinkedIn long-form, Email blast |

**Net multiplier:** 1 ORIGINAL piece = 4-7 distribution shots.

---

## What's in this week's docs

- `CONTENT_CALENDAR_W1.md` — 5 days (Day 3-7, May 15-19), ~50 pieces
- `HIGGSFIELD_PROMPTS_W1.md` — 30+ copy-paste prompts batched by day
- Static assets: `assets/ad-creative/v3/` — pre-rendered

Next batch (after W1 approval):
- `CONTENT_CALENDAR_W2.md` — Day 8-14 (May 20-26)
- `CONTENT_CALENDAR_W3.md` — Day 15-19 (May 27-31)
