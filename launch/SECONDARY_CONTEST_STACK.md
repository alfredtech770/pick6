# Secondary contest stack — week 2 + week 3

Gleam is the primary sweepstakes engine. To compound, we layer 3 more
contest mechanics on top, each running on a different platform with a
different value proposition. The goal is **not** more total prize
budget — the prize budget stays capped. The goal is **distribution
surface area**: every platform we light up is another set of audiences
who don't know each other, all funneling into the same waitlist.

**Hard rule:** every secondary contest must end on pick1.live with a
waitlist signup. The contest platform is the hook; the waitlist is
the conversion.

---

## Stack overview

| Week | Platform | Mechanic | Audience | Prize | $ |
|---|---|---|---|---|---|
| 1 | Gleam | Sweepstakes (FIFA WC tickets + Lifetime Pro) | Cold + warm, mixed | $500 tickets + $999 Pro | $500 |
| 2 | SparkLoop | Newsletter cross-promo | Warm (newsletter readers) | $1-2 CPL bounty to publishers | $200 |
| 2 | KingSumo | Viral giveaway with built-in referral multiplier | Cold (broad consumer) | 6-month Pro × 10 winners (in-kind) | $0 |
| 3 | Daily Drop | One-tweet-a-day micro-prize | Twitter community | $25 gift card × 7 days | $175 |
| 3 | Reddit | One-time r/sportsbook sweepstakes | Sportsbook community | 1× lifetime Pro + 1× $50 DK gift | $50 |
| **Total budget across all 4 secondary contests** | | | | | **$425** |

That keeps us at $500 (Gleam) + $425 (secondary) = **$925** for all
contest activity, leaving $75 contingency. Note: Meta and influencer
spend live in a separate bucket — see MASTER_STRATEGY §10.

---

## 1 · SparkLoop newsletter cross-promo (Day 8 launch)

### Why it works
SparkLoop is the standard tool that newsletter publishers (Morning
Brew, The Hustle, Milk Road, sports-finance ones) use to recommend
each other in welcome emails. We pay $1-2 per signup that converts.
A reader of "The Daily Upside" who just signed up to a finance
newsletter is **5-10x more likely** to engage with Pick1 than a cold
Meta click — same demographic profile (25-40, male-skewing, numerate)
and they've already proven they read email.

### Setup
- Submit Pick1 to SparkLoop at https://sparkloop.app/ (Upscribe tier)
- Target newsletter list (request placement):
  - Morning Brew Sports
  - The Daily Upside
  - Sports-finance: Joe Pomp Letter, Huddle Up
  - General: 1440, The Hustle
- Welcome-email recommendation copy: see Appendix A below
- Cap at $200 = 100-200 signups @ $1-2 each
- Approval timeline: 24-72hrs after submission

### Tracking
- UTM: `utm_source=sparkloop&utm_medium=newsletter&utm_campaign=launch&utm_content={publisher}`
- Goal: <$2 CPL; if a publisher consistently delivers >$3 CPL, pause
  that placement

---

## 2 · KingSumo viral giveaway (Day 10 launch)

### Why it works
KingSumo's built-in referral multiplier is its killer feature — each
entrant gets a unique URL, and the more friends they refer, the more
their odds increase **exponentially** (not linearly like most
sweepstakes). It's run on AppSumo's old launch every time and turns
1,000 entries into 10,000 in 7 days. Free tier supports up to 1,000
entries; we'll cap there and run a second instance in week 3 if it
performs.

### Mechanic
- **Title:** "Win 6 months of Pick1 Pro + a $50 DraftKings credit"
- **Prize:** 10 winners × 6-month Pro account (in-kind, $0 cost) +
  10 × $50 DK gift cards ($500 total — but we're NOT using DraftKings
  cards. Substitute with **Lifetime Pro × 10** (still in-kind, $0))
- **Final prize:** **10 winners × Lifetime Pick1 Pro** ($0 cost to us,
  $999/winner perceived value)
- Entry: email + waitlist signup (gateway, same as Gleam)
- Referral: each entrant's odds scale with each friend they refer (up
  to 10 referrals = 10x odds)
- Auto-pick winners on Day 25 (May 31) at midnight

### Setup
- Create at https://kingsumo.com (free tier)
- 200×200 logo + 1200×600 banner (reuse the Gleam hero image)
- Copy: "Be one of the first 10 people to lock in Lifetime Pro for
  free. We're giving away 10 lifetime accounts to celebrate launch
  week."
- Embed via shortcode on pick1.live (a second sweeps-banner block
  below the Gleam one — yes, two contests running in parallel)

### Risk
- If we run two contests at the same time, some users will be
  confused. Mitigation: the Gleam banner says "Win 2 World Cup
  tickets"; the KingSumo banner says "Win Lifetime Pro × 10". Two
  distinct value props, no overlap.

---

## 3 · Daily Drop on Twitter (Days 18-24, week 3)

### Why it works
A single $25 gift card given away every day for 7 days creates 7
separate Twitter events. Each one is shareable. Each one drives a
fresh wave of follows + retweets + replies. Total spend = $175 for 7
days of unbroken Twitter momentum into launch day. Cheap insurance
against the "Twitter goes dark in week 3" problem.

### Mechanic
- **Every day at 3pm ET**, post: "Daily Drop #X 🎯 Reply with your
  pick for tonight's [GAME]. We'll pick a winner at 11pm ET. Prize:
  $25 DK gift card. RT for double odds."
- Prize is announced and paid via DM (we use Resend to email the gift
  card code or just send a Visa via Tremendous.com)
- Picked winner gets tagged the next morning — bonus social proof.

### Setup
- 7 prizes × $25 = $175
- Source: Tremendous.com (one-off Visa cards, no annual fee) or
  Amazon gift codes
- Daily tweet cron already lives in `api/cron/daily-tweet.js` — add a
  conditional in week 3 to inject the Daily Drop variant.

### Tracking
- Each tweet drives traffic to pick1.live (CTA: "join the waitlist to
  qualify"). UTM: `utm_source=twitter&utm_medium=daily_drop&utm_campaign=launch`
- Goal: 50 new waitlist signups per Daily Drop = 350 total over the
  week.

---

## 4 · Reddit r/sportsbook one-shot (Day 20)

### Why it works
r/sportsbook is the **single highest-quality sports-bettor community
on the internet** — 800K members, low-tolerance for spam (great
filter), but very rewarding for content that earns it. A single
giveaway post (done right) can hit the front page and drive 500+
signups in 24 hours.

### Mechanic
- **Title:** "Giveaway: Lifetime Pro + $50 DK credit for the best
  pick analysis posted in this thread"
- **Format:** People post their best pick (any sport, any night) with
  reasoning. Best reasoning wins (judged by community upvotes +
  founder pick). Pro account + gift card.
- **Critical:** Don't just shill — provide a value-add first. Post a
  long-form analysis of Pick1's last 7 days of picks vs the consensus
  spread first. The giveaway is the "and also we're doing this"
  callout at the bottom.

### Setup
- Post must be approved by mods first (Reddit DM)
- Long-form analysis: 800-1200 words, includes Pick1's hit rate
  receipts table (already in tracker)
- Prize: 1 × Lifetime Pro ($0 cost) + 1 × $50 DK gift ($50)
- Total cost: $50

### Risk
- Reddit can downvote-bomb anything that smells like marketing.
  Mitigation: founder posts under their own account, not a brand
  account. References Pick1 once. Reads like a fan post.

---

## Stack execution timeline

```
Day 1 (May 14) — Gleam live ✅
Day 5 (May 18) — Gleam optimization complete (title + hero + viral share)
Day 8 (May 21) — SparkLoop submitted, awaiting approval
Day 10 (May 23) — KingSumo live (parallel to Gleam)
Day 11 (May 24) — SparkLoop placements going live (24-72hr post-submit)
Day 18 (May 31 -7) — Daily Drop #1 on Twitter
...
Day 24 (May 30) — Daily Drop #7 (last one)
Day 20 (May 26) — Reddit post goes live
Day 25 (May 31) — All contests close (winners drawn midnight)
Day 26 (June 1) — All winners announced (FB + IG + TT + X + email)
```

---

## Expected combined lift

| Source | Signups (target) | $ cost | Cost per signup |
|---|---|---|---|
| Gleam | 500-1,500 | $500 | $0.33-$1.00 |
| SparkLoop | 100-200 | $200 | $1.00-$2.00 |
| KingSumo | 300-600 | $0 | $0 (in-kind only) |
| Daily Drop (Twitter) | 200-350 | $175 | $0.50-$0.88 |
| Reddit | 200-500 | $50 | $0.10-$0.25 |
| **Total** | **1,300-3,150** | **$925** | **$0.29-$0.71 blended** |

If we hit the midpoint (~2,200 signups from contests alone) plus the
organic + Meta funnel, the 1,500 baseline is easily clearable — and
the 2,500 stretch is on the table.

---

## Appendix A — SparkLoop welcome-email recommendation copy

> **Pick1 — One AI sports pick per day, every call logged publicly.**
>
> If you read [The Daily Upside / Morning Brew Sports / wherever this
> is being placed], you already think about probabilities for a
> living. Pick1 is an AI that calls one game per day across 9 sports.
> Every pick — wins AND misses — is logged on the public site forever.
> No cherry-picking, no "guaranteed locks."
>
> [Join the waitlist →](https://pick1.live?utm_source=sparkloop)
>
> Free. Launching end of May. Cold-take: most touts hide their losses.
> We can't.

---

## Appendix B — KingSumo entry-page copy

> ### Win Lifetime Pick1 Pro (we're giving away 10)
>
> We're launching end of May and giving away 10 lifetime accounts to
> celebrate. Lifetime Pro never goes on sale after launch.
>
> **The prize:** Lifetime access to Pick1 Pro — one AI sports pick
> per day across 9 sports. Every call logged publicly.
>
> **How to enter:** Join the waitlist below. Refer friends with your
> unique link — each referral multiplies your odds.
>
> **Drawn:** May 31, 11:59 PM ET. Winners notified by email.

---

## Appendix C — Reddit r/sportsbook post outline

```
TITLE: I built an AI that calls one game a day for 9 sports — here's
the public log of every call it made last week (with receipts)

BODY (800-1200 words):
1. Hook: "Like most of you, I'm sick of touts who hide their losses."
2. The methodology — what calibration means and why most "AI picks"
   from public touts are actually just rerolled gambler's-fallacy
   nonsense.
3. The actual receipts — last 7 days of Pick1 picks vs Vegas
   consensus. Embedded screenshot from /tracker page.
4. What I got wrong — be specific. Owning the misses earns more
   trust than crowing about the wins.
5. Giveaway hook: "I'm giving away 1 lifetime account + $50 DK
   credit to whoever posts the best pick analysis in this thread
   (any sport, any night this week). Picking the winner Sunday
   night."
6. Sign-off: link to pick1.live. Disclose I built it. Don't apologize.
```
