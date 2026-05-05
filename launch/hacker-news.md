# Hacker News — "Show HN" Submission

## Title (max 80 chars — keep close to 70 for mobile)

> Show HN: Pick1 – AI sports prediction engine, like Kalshi but for sports

Why this title works:
- "Show HN:" is the format HN expects — never skip it
- "Pick1" before the dash is the name (HN displays it bold-ish)
- "AI sports prediction engine" is the literal product description
- "like Kalshi but for sports" is the comparison hook — Kalshi is well-known on HN
- Under 70 chars, no emoji (HN strips them anyway)

## URL

> https://pick1.live

## Text (only fill this if you submit text-only; usually leave blank for URL submissions)

> [leave blank — submit as a URL post, not a text post]

## First Comment (post immediately after submitting)

The first comment is critical on HN. Post it within 60 seconds of submission, before anyone else can. Format below:

---

Maker here. Quick context on why we built this.

Sports is the largest category of probabilistic bets in the world but the actual prediction layer is hidden inside sportsbooks (their lines are predictions, but the probability isn't visible — only the price). Outside the books, the "prediction" market for sports is filled with Telegram tipsters who post wins and quietly archive losses.

Pick1 is the AI-native answer: a single model trained on 1.2M+ historical games, with three principles borrowed from prediction-market design (Kalshi/Polymarket):

1. Calibrated probabilities (a 75% pick wins 75% over a large sample, with reliability diagrams to prove it). The methodology page has the calibration tables: https://pick1.live/methodology

2. Public ledger — every pick gets timestamped and logged at publication time. No edit history, no selective sharing. Hot weeks are visible. Cold weeks are too.

3. Calibrated against closing-line value (CLV), the metric professional sports bettors and sportsbooks both use. Recalibrated nightly. Average target is +3% CLV which is in the range successful syndicate bettors aim for.

We're pre-launch, waitlist-only. Frontend is static (Vercel), the model is the interesting part. Happy to go deep on:

- Why CLV beats win-rate as the calibration metric
- The Kalshi/Polymarket comparison and why a peer prediction market doesn't make sense for sports (sportsbooks already are them)
- How the live in-game probability head differs from the pre-game model
- Why we publish losses (selection bias / survivorship bias / the structural problem with tipsters)

Long-form on the comparison: https://pick1.live/blog/kalshi-polymarket-sports

Ask me anything.

---

## Tips for HN traction

- **Submit during US morning** (8–10am ET). HN's first-page algorithm rewards velocity, not raw upvote count. Mornings are peak.
- **Submit Tue, Wed, or Thu**. Mondays are noisy from weekend backlog. Fri/weekend is dead.
- **Don't ask for upvotes anywhere**. HN explicitly bans this and your post will be flagged. Just submit, then post the first comment.
- **Reply to every comment within 30 minutes for the first 2 hours**. HN ranks based on comment activity, not just upvotes.
- **Don't be defensive**. HN will challenge the model, the framing, the analogies. Engage genuinely. Saying "good point, that's a real limitation, here's how we think about it" buys more credibility than defending.
- **Avoid marketing language in replies**. "Synergy", "leverage", "best-in-class" all get downvoted. Engineering language ("the model", "the calibration", "the loss function") gets respect.
- **Have a thick skin for the gambling angle**. Some HN regulars dislike sports betting on principle. The right reply is "fair, we don't take bets ourselves — we publish predictions; what you do with them is your choice."

## Anti-patterns to avoid

- Don't post the link to friends asking them to upvote (HN tracks this)
- Don't reply with copy-pasted blocks of text from the website
- Don't try to bury negative comments
- Don't say "we'll address that in v2" — say what you'd actually do
