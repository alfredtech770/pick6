# Pick1 — Meta Ads Launch Playbook

Pasteable Day-1 setup. Follow top-down. Each section maps 1:1 to a screen in Meta Ads Manager.

---

## 0. Prereqs (do these first)

- [ ] Business Manager created at [business.facebook.com](https://business.facebook.com)
- [ ] Ad Account created, payment method added
- [ ] Pixel created in Events Manager → ID copied
- [ ] CAPI access token generated → pasted into Vercel as `META_CAPI_ACCESS_TOKEN`
- [ ] Pixel ID pasted into Vercel as `META_PIXEL_ID` AND into the `<meta name="meta-pixel-id" content="">` tags in `index.html` + `launch/thanks.html`
- [ ] Domain `pick1.live` verified in Business Settings → Brand Safety → Domains (use meta-tag method)
- [ ] Aggregated Event Measurement: `Lead` set as priority #1 event for `pick1.live`
- [ ] Test Events fired from a private window — `Lead` shows green "Deduplicated" badge

If any of these are unchecked, **do not launch ads yet.** Iterate plumbing first; CPL will be 2–3× otherwise.

---

## 1. Special Ad Category declaration

**Do NOT** declare Pick1 as a Special Ad Category. Pick1 is an AI sports analysis tool — not gambling, not credit, not housing, not employment, not social issues.

If Meta auto-flags it during review and forces the gambling category: comply, document the appeal, and re-submit. But never volunteer the flag — it severely limits targeting (no age <18 exclusion control, no detailed interest targeting, no lookalikes).

---

## 2. Campaign structure

Three campaigns, one purpose each. Don't merge; isolate signal.

### Campaign 1 — `LEAD-US-broad-{YYYYMMDD}`
- **Objective:** Leads
- **Conversion location:** Website
- **Performance goal:** Maximize number of conversions
- **Conversion event:** Lead
- **Bid strategy:** Highest volume (default — let Meta learn)
- **Budget:** $30/day campaign-level (CBO off — set at ad-set level)
- **Schedule:** Run continuously, no end date, day-parted only after Week 2
- **Attribution:** 7-day click, 1-day view (default)

### Campaign 2 — `LEAD-US-interest-{YYYYMMDD}`
- Same objective + bid strategy as Campaign 1
- **Budget:** $30/day
- Used for interest-based testing (Tier 2 below)

### Campaign 3 — `LEAD-US-retargeting-{YYYYMMDD}` *(launch in Week 2 once Pixel data accumulates)*
- Same objective
- **Budget:** $20/day
- Targets warm audience: site visitors who didn't sign up

**Total Day-1 spend: $60/day = $420/week.** Don't go higher until you have 50+ Leads recorded — Meta's learning phase needs the volume to stabilize.

---

## 3. Audiences

### Tier 1 — Broad (Campaign 1)
Let Meta's algorithm find your buyers. This consistently outperforms manual targeting in 2025+.

- **Locations:** United States
- **Age:** 25–45
- **Gender:** All
- **Languages:** English (All)
- **Detailed targeting:** *Leave empty.* No interests, no behaviors. The Pixel will learn from your conversions.
- **Detailed targeting expansion:** ON
- **Advantage+ audience:** ON

### Tier 2 — Interest stack (Campaign 2)
Two ad sets, each with a single themed audience. Don't combine all interests into one — Meta will overweight whichever is largest.

**Ad set 2A — Sports fans**
- Same geo/age/lang as Tier 1
- **Detailed targeting (interest):** NBA, NFL, MLB, English Premier League, UFC, ESPN, Bleacher Report, The Athletic
- **Audience size target:** 8M–25M

**Ad set 2B — DFS / sports analytics interest**
- Same geo/age/lang as Tier 1
- **Detailed targeting (interest):** DraftKings, FanDuel, fantasy sports, sports analytics, Action Network, sabermetrics
- *Note:* "DraftKings" / "FanDuel" as **interest categories** is fine — that's audience signal, not Meta declaring you a gambling product. Different system.

### Tier 3 — Lookalike (add Week 3+)
Skip until you have 100+ waitlist signups. Then create:
- **Source:** Custom Audience from Pixel — `Lead` event in last 30 days
- **Country:** United States
- **Size:** 1% (most similar)
- Run as a third ad set in Campaign 1, separate from broad

### Retargeting (Campaign 3, Week 2+)
Two audiences, each 30-day window:
- **R1:** All site visitors → exclude `Lead` event firers
- **R2:** Visitors who hit `/launch/thanks` (signed up) → for future referral / app-install push

---

## 4. Placements

**Advantage+ Placements** (Meta's auto-placement). Don't manually pick.

Exception: if after 14 days Reels alone is delivering >50% of conversions at a CPL <60% of the average, split it into a dedicated ad set with Reels-only placement and increase budget there.

---

## 5. Ad copy — 8 variants

Each ad gets: Primary Text, Headline, Description, CTA. Format below pastes directly into the Meta ad creator.

Naming: `Pick1-{theme}-{format}-v{n}`

### Variant A1 — `Pick1-9sports-static-v1` (cold, broad, lead)
**Primary Text:**
> AI that predicts every game across 9 sports — NBA, NFL, EPL, MLB, UFC, NHL, F1, tennis, cricket. Confidence scores 0–100% on every call. Public accuracy ledger — every prediction logged, no cherry-picking.
>
> Pick1 launches soon. Get your first week free.

**Headline:** AI sports predictions, publicly logged
**Description:** 1 week free at launch. No card required.
**CTA button:** Sign Up

### Variant A2 — `Pick1-receipts-static-v1`
**Primary Text:**
> Most prediction "experts" delete their misses. We don't. Pick1 publishes every AI prediction — correct or wrong — to a timestamped public ledger you can audit.
>
> 9 sports. AI confidence scores. No hyped "sure things." First week free at launch.

**Headline:** Predictions with receipts
**Description:** Public accuracy ledger across 9 sports
**CTA button:** Sign Up

### Variant A3 — `Pick1-vsKalshi-static-v1` (compliance-strong)
**Primary Text:**
> Kalshi and Polymarket built prediction markets for politics and economics. We built one for sports.
>
> AI-trained model across 1.2M historical games, confidence scores 0–100%, every prediction publicly logged. Like a Bloomberg terminal for sports forecasting.

**Headline:** A prediction market built for sports
**Description:** AI predictions across 9 sports — 1 week free
**CTA button:** Sign Up

### Variant A4 — `Pick1-NFL-static-v1` (sport-specific, NFL angle)
**Primary Text:**
> The NFL's most accurate AI prediction model. Trained on every game since 2018, recalibrated daily, every call timestamped to a public ledger.
>
> Get the model's pick on every game — first week free at launch.

**Headline:** AI predictions for every NFL game
**Description:** 1 week free at launch. No spam.
**CTA button:** Sign Up

### Variant A5 — `Pick1-NBA-static-v1` (sport-specific)
Same template as A4, swap NFL → NBA. Headline: `AI predictions for every NBA game`.

### Variant V1 — `Pick1-9sports-video-v1` (15-sec UGC vertical)
**Primary Text:**
> 9 sports. One AI. Every prediction publicly logged.
>
> Pick1 trains a forecasting model across NBA, NFL, EPL, MLB, UFC, NHL, F1, tennis, and cricket — and publishes every call to a public ledger you can audit. No cherry-picking, no "today's sure thing."
>
> Launching soon. First week's on us.

**Headline:** AI predictions, publicly logged
**Description:** 1 week free at launch
**CTA button:** Sign Up

### Variant V2 — `Pick1-vsTipster-video-v1` (15-sec, problem/solution)
**Primary Text:**
> Tipsters delete their misses. The AI doesn't.
>
> Pick1 publishes every prediction — correct or incorrect — to a public timestamped ledger. Across 9 sports. With confidence scores. So you can actually evaluate whether the model works.
>
> Get 1 week free at launch.

**Headline:** Every prediction. Publicly logged.
**Description:** AI sports forecasting across 9 sports
**CTA button:** Sign Up

### Variant V3 — `Pick1-founder-video-v1` (UGC founder VO, 30 sec)
Founder talks to camera explaining the "every prediction logged" principle. Production brief in §7 below.

### Loading order
- **Day 1:** Run V1 + A1 + A2 + A3 in Campaign 1 (Tier 1 broad)
- **Day 1:** Run V2 + A4 + A5 in Campaign 2 Ad Set 2A
- **Day 1:** Run A2 + A3 in Campaign 2 Ad Set 2B
- **Day 7:** Pause anything with frequency >2.5 or CTR <0.7%
- **Day 7:** Add V3 (founder video) once it's filmed

---

## 6. Compliance copy don'ts

When writing or revising any new ad in the future, never use:

- "Bet" / "betting" / "bettor" / "bookmaker" / "sportsbook"
- "Odds" / "stake" / "wager" / "wagering" / "parlay"
- "Cashed" / "cash out" / "win big" / "easy money"
- "Lock" / "today's lock" / "+EV" / "free play"
- "Guaranteed wins" / "100% accurate" / "never lose"
- "21+" / "Gambling problem? Call ..." (these are sportsbook disclosures)

Replacements that read clean:
- bet → predict / forecast / analyze
- odds → confidence / probability / market line
- bettor → analyst / sports fan
- cashed → correct / verified
- lock → high-confidence prediction
- sportsbook → market / efficient markets

---

## 7. Creative briefs (deliverables for designer / video)

### Static images — 4 needed
All in **1:1 (1080×1080)** + **4:5 (1080×1350)** at minimum. Add **9:16 (1080×1920)** for Reels/Stories.

**S1 — "9 sports grid"**
- Dark Pick1 background (`#0a0b0d`), lime accent (`#d4ff3a`)
- 3×3 grid of sport icons: NBA, NFL, EPL, MLB, UFC, NHL, F1, tennis, cricket
- Center overlay: "ONE AI · NINE SPORTS" in Archivo 900
- Footer text: "Predictions with receipts." in lime
- Small wordmark bottom-right

**S2 — "Public ledger"**
- Same background palette
- Mock the receipt component from the homepage (the 3 verified prediction cards)
- Big headline: "EVERY PREDICTION LOGGED."
- Subtext: "No hyped 'sure things.' Just receipts."

**S3 — "Confidence dial"**
- Hero card from the homepage repurposed: AI Confidence ring at 84%, single sport prediction
- Headline overlay: "AI THAT SHOWS ITS WORK"
- Subtext: "Confidence scored. Live tracked. Publicly logged."

**S4 — "Vs tipster"**
- Side-by-side: "Random Tipster" (only their wins) vs "Pick1" (all calls, including misses)
- Headline: "ONE PUBLISHES EVERYTHING."
- Subtext: "Pick1 logs every miss. So you can trust the wins."

### Videos — 3 needed

**V1 — 15-sec montage (script + b-roll)**
- 0:00–0:02: Pick1 wordmark, "ONE AI" headline
- 0:02–0:08: Quick cuts — NBA arena, NFL stadium, F1 pit lane, EPL crowd, UFC octagon (use stock if needed)
- 0:08–0:11: Hero card mockup with confidence dial filling to 84%
- 0:11–0:14: Receipt cards stacking up with "VERIFIED ✓" stamps
- 0:14–0:15: CTA card: "1 WEEK FREE AT LAUNCH"
- VO: optional. If included, founder voice. Sound design + on-screen text-only also works.

**V2 — 15-sec problem/solution**
- 0:00–0:04: Screenshot of a tipster Telegram channel showing only wins
- 0:04–0:08: Reveal: same tipster's deleted "L" messages
- 0:08–0:12: Pick1 receipt cards — "every miss logged" receipts highlighted
- 0:12–0:15: CTA: "PREDICTIONS WITH RECEIPTS"

**V3 — 30-sec founder UGC** *(film when ready)*
- Vertical 9:16, talking to camera, no production
- Script:
  > "The reason every sports tipster on the internet looks profitable is they delete the losers. We're building Pick1 differently. Our AI makes a prediction on every game in 9 sports — and we publish every single one, correct or wrong, to a public ledger. So you can actually see whether the model works. We launch soon. First week's free."

---

## 8. Naming conventions

Stick to these so reporting stays clean:

| Level | Format | Example |
|---|---|---|
| Campaign | `{OBJ}-{GEO}-{theme}-{YYYYMMDD}` | `LEAD-US-broad-20260510` |
| Ad set | `{audience}-{geo}-{age}-{placement}` | `broad-US-25to45-advantage` |
| Ad | `{concept}-{format}-v{n}` | `9sports-carousel-v1` |

When you duplicate an ad set for testing, append `-test{X}`: e.g. `broad-US-25to45-advantage-testB`.

---

## 9. Optimization rules (Day 7 review checklist)

Run this every Monday morning for the first 4 weeks.

| Signal | Action |
|---|---|
| Ad CPL > $20 | Pause ad |
| Ad CPL < $3 | Duplicate ad set, 2× budget |
| Ad CPL $3–10 | Hold, let learning continue |
| Ad CTR < 0.7% | Refresh creative within 7 days |
| Ad frequency > 2.5 | Refresh creative or expand audience |
| Ad set learning phase >14 days | Audience is too narrow — broaden |
| Account-level CPL > target after 50 conversions | Pause all, revisit creative + landing |

**Target CPL for Pick1 waitlist:** $4–$8 in week 1, $3–$5 by week 4 once Pixel learns.

**Don't** edit ads in active learning phase. Editing resets learning. If you must change copy, duplicate the ad and pause the old one.

---

## 10. Day-1 launch sequence

1. Verify Pixel + CAPI in Events Manager Test Events (green Deduplicated badge)
2. Open Ads Manager → Create Campaign 1 (`LEAD-US-broad-{YYYYMMDD}`) per §2
3. Build Ad Set: Tier 1 broad audience per §3
4. Upload S1 + S2 + V1, paste copy from A1, A2, A3 + V1 per §5
5. Save as Draft, do NOT click Publish yet
6. Repeat for Campaign 2 (Ad Set 2A: V2 + A4 + A5; Ad Set 2B: A2 + A3)
7. Final review: copy reads, no betting language, names follow §8 convention
8. **Click Publish on Campaign 1 only.** Wait 24h. Watch CPL.
9. If Campaign 1 CPL < $10 after 24h, Publish Campaign 2.
10. Day 7: run §9 checklist.

---

## 11. What to do if Meta rejects an ad

- Open the rejection email/notification — read the specific reason
- If "Personal Attributes" → wording suggests we're addressing the user as a "gambler" or similar. Soften copy.
- If "Gambling and Gaming" → that's the big one. Quote the rejection back to me and I'll rewrite the ad copy.
- If "Misleading claims" → usually triggered by % accuracy claims. Soften: "AI-trained model" not "65% hit rate."
- **Always file an appeal** if you believe the rejection is wrong — appeals are reviewed by humans and reverse ~40% of automated rejections.

If 3+ ads get rejected in the same week: stop, do a full copy review, don't keep submitting (account-level reputation degrades).

---

## 12. Open questions to resolve before launch

- [ ] **Geo expansion:** Start US-only. Add UK + CA + AU at Week 3 if CPL stays <$8. India for cricket interest at Week 6+.
- [ ] **Special Ad Category appeal text:** Pre-draft a 200-word appeal explaining Pick1 is forecasting/analysis, citing the public ledger and FAQ. Have it ready in case Meta forces the category on first review.
- [ ] **Founder video (V3):** Film when ready. Replaces V1 as best-performer in 80% of cases.
- [ ] **CRM follow-up:** Brevo welcome email is wired. Add a 3-email pre-launch sequence (Day 0, Day 7, Day 14) to keep waitlist warm.
