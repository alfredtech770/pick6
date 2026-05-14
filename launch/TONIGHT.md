# Tonight — prioritized launch action list

The sweeps is live and the email surfaces are auto-running. The
remaining moves are account-gated, which means **you** post them. In
priority order by leverage:

---

## 🔥 Tier 1 — do tonight, ~45 min total

### 1. X / Twitter post (5 min)
- Paste copy from `launch/SWEEPSTAKES_LAUNCH_COPY.md` § 1
- Attach `assets/ad-creative/v2/gleam-hero.png`
- Pin to top of @PICK1sport profile
- Quote-tweet from @PICK1sport's normal pick tweets later in the week

### 2. Instagram feed post (5 min)
- Paste § 2 from same file
- Update IG bio link to the Gleam URL
- Story-share the post to amplify reach

### 3. Facebook Page post (3 min)
- Paste § 4
- Pin to top of FB Page
- Share to Noa's personal FB

### 4. Meta Campaign 1 launch (20 min)
- 3 ad creatives ready: `ad1-receipts.png`, `ad2-lock.png`, `ad3-9sports.png` (all in `assets/ad-creative/v2/`)
- Playbook: `launch/meta-ads-playbook.md`
- $50/day budget, start tonight
- Audience: lookalikes + interest stack (NBA + NFL + sports betting + 25-40 male US)
- All 3 creatives in one ad set, let Meta optimize

### 5. Email blast to existing waitlist (3 min)
- Paste § 5
- Send via Resend (audience id 1c839163-9225-4d38-84a3-a97351900b74)
- Schedule for 9am ET tomorrow if not sent tonight (better open rate)

### 6. LinkedIn founder post (Noa, 3 min)
- Paste from `launch/DISTRIBUTION_QUEUE.md` § "LinkedIn founder post"
- Link in first comment (LinkedIn algo down-ranks posts with external links in the body)

### 7. Reddit — r/SideProject (5 min)
- Paste from `launch/DISTRIBUTION_QUEUE.md` § "r/SideProject (400K)"
- This is the easiest Reddit sub (no karma threshold, builder-friendly)
- Reply to every comment in the first hour for algo boost

---

## 🌡️ Tier 2 — tomorrow morning, ~30 min

### 8. Reddit — r/giveaways (10 min)
- Paste from § "r/giveaways (1M members)"
- **Read sub rules first** — they're strict on format
- Post in `[USA] [Free] [Online]` title format

### 9. Reddit — r/contests (5 min)
- Paste from § "r/contests (100K)"
- Less strict than r/giveaways

### 10. Indie Hackers milestone (5 min)
- Paste from § "Indie Hackers milestone"
- If you don't have an account, takes 2 min to create

### 11. Outreach via DMs (10 min total)
- Send a quick DM to 5 friends/colleagues asking for an entry + share
- Personal asks convert at 30-50% vs. 1-3% on cold posts

---

## 📅 Tier 3 — this week (Day 7-10), planned

### 12. Day 7 (May 21) — Influencer outreach
- 20-creator list ready in `launch/INFLUENCER_OUTREACH.md`
- DM template + anti-spam rules in same file

### 13. Day 8 (May 22) — SparkLoop
- Submit to https://sparkloop.app/ ($200 budget cap)
- 24-72hr approval window
- Expected: 100-200 newsletter-sourced signups

### 14. Day 10 (May 24) — KingSumo viral giveaway
- Free tier supports 1,000 entries
- In-kind prize only (10× Lifetime Pro, $0 our cost)
- Setup at https://kingsumo.com

### 15. Day 18 (Tuesday morning) — Show HN
- Paste from `launch/DISTRIBUTION_QUEUE.md` § "Hacker News Show HN"
- Post at 8am ET on a Tuesday
- Don't post during launch week itself — gets buried by HN's launch fatigue

---

## What's auto-running right now (no action needed)

1. **pick1.live banner** — visible on every page, points to the Gleam sweeps URL
2. **Waitlist counter** — live social proof
3. **Welcome email** — every new signup sees the sweeps CTA
4. **Daily pick email** — every existing subscriber sees the sweeps CTA every morning until May 31
5. **Gleam page itself** — public at the live URL, optimized title + description
6. **Daily tweet cron** — pushes the daily pick to @PICK1sport (needs Twitter dev app creds from you to activate)

---

## Won't autonomously fire — needs your touchpoint

- **Twitter dev app credentials** (4 OAuth values) — paste into Vercel env vars to unlock the daily tweet cron
- **Existing tab logged-in accounts** — you're signed into Gleam, FB, IG, TAAFT, Resend, Vercel. If you sign into Reddit + LinkedIn + IndieHackers + Hacker News on this same Chrome profile, I can post for you autonomously.

---

## Daily check-in cadence

Every morning, check:
1. Waitlist signup delta from yesterday (via Supabase or `/api/waitlist-count`)
2. Gleam entries delta (Gleam dashboard)
3. Meta Ads CPL (kill if >$3)
4. Top organic post views (boost the one that's working)

I'll continue checking the tracker between drops and surface anomalies.
