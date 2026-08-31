# Pick1 — Revenue Recovery Plan

**Written 2026-07-28.** All figures verified against App Store Connect and the
`subscriptions` table (Apple Server Notifications V2), not estimated.

---

## 1. Where the business actually is

| Metric | Value | Source |
|---|---|---|
| Lifetime proceeds | **$1,071** | ASC, all time |
| Last 7 days (Jul 20–26) | **$527** ($75/day) | ASC daily proceeds |
| Last 3 days (Jul 24–26) | $142 ($47/day) | ASC daily proceeds |
| Signups/day (steady state) | **~67** | `signups` |
| New subscriptions/day | **~18** | `subscriptions` |
| of which start as trial | ~12 | `subscriptions` |
| Active plans / paid plans | 91 / 64 | ASC |
| Will bill again (auto-renew ON) | **52** | `subscriptions` |

$1,043 of the $1,071 lifetime landed in 15 days (Jul 12–26). Revenue peaked
Jul 21 at $147 — **two days after the World Cup final** — because that was the
Jul 13–19 signup surge clearing the 3-day trial. It has fallen since as that
one cohort ages out.

### The problem in one line

Acquisition is not the bottleneck. **Retention is.** Without intervention the
existing base decays to ~$5/day by late August, because almost nobody survives
past their first payment.

---

## 2. The equation

```
revenue/day  =  signups/day × signup→sub × trial→paid × net ARPPU × renewal multiple
   ~$45-75   =      67      ×    ~27%    ×   12.8%    ×   $11.58   ×     1.37
```

Every lever below multiplies into the same line. Ranked by size of the gap:

| Lever | Now | Peer median | Gap |
|---|---|---|---|
| Trial → paid | **12.8%** | ~30–40% typical | 484 of 551 subs died at exactly 3.0 days |
| Renewal survival (weekly) | **27%** | 50–60% typical | 67 first payments → 18 second → 2 third |
| Involuntary churn | **17.6%** | 5–8% | 102 of 573 died on a failed charge |
| Download → paid conversion | **1.48%** | 2.68% (Apple peer set) | 1.8x revenue on identical traffic |
| Day 1 retention | **20.67%** | 26.04% (Apple peer set) | users never return to see a pick land |

### The one number that is already excellent

**Proceeds per paying user: $28.00 — above the 75th percentile ($19.05).**
Pricing is not the problem and must not be cut. The problem is that too few
people ever pay, and those who do leave after one cycle.

---

## 3. Phase 1 — Stop the leaks (Days 1–14)

Recovers money already won. Mostly shipped 2026-07-28.

| Item | Status | Expected effect |
|---|---|---|
| Billing Grace Period (16d, All Renewals, Production) | **DONE** | Recovers 40–60% of the 17.6% involuntary churn |
| `payment_failed` push — 50 users live | **DONE** | Tells the user the card failed; nothing did before |
| `renewal_off_save` push — cancellers, 16–48h pre-expiry | **DONE** | First contact ever with this segment |
| `day1_return` push (A/B) | **DONE** | Attacks D1 retention 20.67% |
| `trial_ending` / `trial_ending_cancelled` push | **DONE** | Attacks the 3-day wall |
| Set `RESEND_API_KEY` | **BLOCKED — needs Ethan** | Activates email fallback to 25 push-unreachable users, welcome emails, AND founder alerts (all three have never worked) |
| Win-back offer for 448 lapsed users | TODO | Largest single pool; zero ad spend |

**Target by Day 14:** involuntary churn 17.6% → under 10%. Revenue floor holds
at $45–60/day instead of decaying toward $5.

**Measure:** `DID_FAIL_TO_RENEW` → recovered ratio vs the 78/23 baseline;
`push_log` vs `notification_opened` for each segment.

---

## 4. Phase 2 — The trial wall (Days 15–45)

This is the single biggest conversion lever in the business.

### 4.1 Test 3-day → 7-day trial

**Why.** 484 of 551 weekly subscriptions died at exactly 3.0 days. Three days
is ~3 picks. At a ~50% hit rate (34W–33L over the last 7 days) three picks is
statistical noise — the user cannot tell signal from luck, so they cancel.
Seven days is a full sports week and lets the *actual* product promise land:
**every pick publicly logged, wins and losses.** That promise needs a sample
size to mean anything.

**Cost.** 4 extra free days per trial start (~12/day). Marginal cost is near
zero — the picks are already generated.

**Success criterion.** Trial→paid above 20%. Below 16%, revert.

### 4.2 Day-1 and day-2 engagement

D1 retention 20.67% vs 26.04% median. The `day1_return` push is live; the
deeper fix is giving free users a reason to come back:

- Notify free users when *their* viewed pick settles (win or loss — honesty is
  the brand). Result notifications already exist for Pro (`result_win`,
  `result_loss`); extend to the free tier's one pick per sport.
- Surface the running public ledger on first open, not buried. The differentiator
  is transparency, not accuracy — lead with it.

**Target by Day 45:** trial→paid 12.8% → 20%+. D1 retention → 25%.

---

## 5. Phase 3 — Conversion and mix (Days 46–90)

### 5.1 Paywall: 1.48% → 2.68%

Closing to the peer median is a **1.8x revenue multiple on identical traffic**.
Store funnel is already healthy (64.1K impressions → 15.8K page views → 6.58K
downloads), so every fix belongs after install:

- Lead the paywall with the public ledger / "every pick logged" proof, which no
  competitor can copy and which is already true.
- Test hard vs soft paywall placement in `Pick1OnboardingFunnel`.
- Keep price. $28 proceeds per payer is top-quartile — do not discount.

### 5.2 Shift mix toward monthly

Weekly is 48 of 61 paid plans. Monthly holds 4x the cash per purchase decision
and removes 3 renewal decisions per month — each of which currently loses 73%
of subscribers. Consider a season pass for the NFL/NBA season start (Sept/Oct),
which aligns the billing period with the reason people subscribe.

**Target by Day 90:** download→paid 1.48% → 2.2%+; monthly share of new paid
plans above 30%.

---

## 6. Targets

| | Revenue/day | Trial→paid | Weekly survival | Involuntary churn |
|---|---|---|---|---|
| Today | $45–75 (falling) | 12.8% | 27% | 17.6% |
| Day 30 | **$70** (stable) | 16% | 35% | <10% |
| Day 60 | **$95** | 20% | 40% | <8% |
| Day 90 | **$120–140** | 22%+ | 45% | <8% |

These are product-only targets. No ad spend assumed.

---

## 7. The honest ceiling

Everything above raises **revenue per visitor**. It does not raise visitors.

At ~67 signups/day, even hitting every Day-90 target lands the business around
$120–140/day — roughly $45K/year. That is a real recovery from a decaying $5/day,
and it is worth doing first because it fixes the leaks *before* you pour traffic
into them. But it is a ceiling, not a growth curve.

The growth curve needs acquisition restarted — and the case for it gets stronger
after this work, not weaker: organic signup→sub is now ~27% against 9.9% during
the World Cup flood, so every future ad dollar buys ~3x what it did in July.
Fix the funnel, then fill it.

---

## 8. Weekly review checklist

1. ASC → Analytics → Monetization → Sales: daily proceeds trend
2. `subscriptions`: trial→paid by cohort week; survival to 2nd/3rd charge
3. `push_log` vs `notification_opened`: per-segment open rate, day1 A/B arm
4. `email_log`: `failed` rows (Resend domain verification for pick1.live)
5. ASC → Benchmarks: conversion and D1 retention vs the Sports peer set

## 9. Open items not in this plan

- `public.picks_archive_ufc` has **RLS disabled** — anyone with the anon key can
  read or write it. Needs a policy decision before enabling.
- Apple's MRR tile reads $11 against 64 paid plans — an ASC reporting artifact,
  not used in any figure here.
