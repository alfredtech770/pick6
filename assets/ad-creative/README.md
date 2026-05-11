# Pick1 Ad Creative — Round 1

5 static ads, 1080×1080 PNG, ready to upload to Meta Ads Manager.

Built as HTML/CSS → rendered via headless Chrome at exact ad dimensions. To regenerate any of these (e.g. swap "Celtics" for "Lakers"), edit the corresponding `.html` file and run:

```
cd assets/ad-creative
python3 -m http.server 8765 &
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --window-size=1080,1080 --screenshot=png/sX-name.png \
  --virtual-time-budget=5000 http://localhost:8765/sX-name.html
```

---

## Upload order for Campaign 1 (`LEAD-US-broad-20260511`)

Drop all 5 PNGs into the ad set's "Add Media" step. Meta's algorithm will pick the winner within ~72 hours. Each ad gets its own Primary Text + Headline + Description.

---

## S1 — Confidence Dial → `png/s1-confidence-dial.png`

**Hook:** Pure data display. Proves Pick1 has a real model.

**Primary text:**
> Pick1's model gave Boston 84% to cover the spread. Final: Celtics by 11. Every prediction across 9 sports gets logged to a public ledger — wins AND losses. First week's free at launch.

**Headline:** AI predictions, publicly logged
**Description:** 1 week free · No card required
**CTA button:** Sign Up

---

## S2 — Receipt Wall → `png/s2-receipt-wall.png`

**Hook:** Public ledger differentiator. Mixed wins+misses = trust.

**Primary text:**
> Most sports tipsters delete their misses. Pick1 doesn't. Every prediction — correct or wrong — gets timestamped to a public accuracy ledger you can audit. So you can actually evaluate whether the model works.

**Headline:** Predictions with receipts
**Description:** Public accuracy ledger · 9 sports
**CTA button:** Sign Up

---

## S3 — Vegas vs Pick1 → `png/s3-vegas-vs-pick1.png`

**Hook:** Sharper-than-Vegas framing. Sports-analytics dopamine.

**Primary text:**
> Vegas had Boston −3.5. Pick1's model called it at −7 with 73% confidence. Final spread: 11. AI-trained on 1.2M historical games, recalibrated daily. First week free at launch.

**Headline:** Sharper than the line
**Description:** AI sports predictions · 1 week free
**CTA button:** Sign Up

---

## S4 — Nine Sports → `png/s4-nine-sports.png`

**Hook:** Scope. One model, every sport you watch.

**Primary text:**
> One AI model. Every game across 9 sports — NBA, NFL, EPL, MLB, UFC, NHL, F1, tennis, cricket. Confidence scores 0–100% on every prediction. Public accuracy ledger. 1 week free at launch.

**Headline:** AI predictions across 9 sports
**Description:** Like Kalshi or Polymarket — but for sports
**CTA button:** Sign Up

---

## S5 — Not A Sportsbook → `png/s5-not-a-sportsbook.png`

**Hook:** The compliance moat. Targets the non-bettor sports fan.

**Primary text:**
> Pick1 is an AI sports analysis tool — not a sportsbook. We publish predictions with confidence scores and a public accuracy ledger. We don't take, place, or facilitate any wagers. Think of it as research for the data-curious sports fan.

**Headline:** A forecast tool, not a sportsbook
**Description:** AI sports predictions · 1 week free
**CTA button:** Sign Up

---

## Destination URL (for all 5)

```
https://pick1.live/?utm_source=meta&utm_medium=paid&utm_campaign=LEAD-US-broad-20260511&utm_content={{ad.name}}
```

Use Meta's dynamic URL parameter macro `{{ad.name}}` so each ad's name auto-populates in `utm_content` — that way Brevo gets the exact ad name for every signup.

---

## What to do after Day 7

- Identify the top-performing ad by CPL (cost per lead) in the breakdown view
- Take that ad's concept, make 3 variations:
  - Different sport (Lakers vs Pick1 / Cowboys vs Pick1)
  - Different headline (test 2–3 hook angles)
  - Different color emphasis (lime vs green vs mixed)
- Add to the same ad set; Meta will A/B them against the original
- Pause anything with CPL >$15 after 3 days of data
