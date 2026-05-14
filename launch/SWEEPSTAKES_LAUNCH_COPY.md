# Sweepstakes launch announcement — paste-ready copy

The Gleam sweeps is now live with conversion-optimized title +
description. Time to drive traffic. Below are the assets to ship.

**Live URL (use everywhere):**
https://gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro

**Hero asset:** `assets/ad-creative/v2/gleam-hero.png` (1200×600)

---

## 1 · X / Twitter (tonight)

> 🏆 We're launching end of May and giving away the best prize we
> could think of:
>
> 2 tickets to a 2026 FIFA World Cup group-stage match
> + Lifetime Pick1 Pro (AI sports picks, daily, every call logged
> publicly)
>
> $1,499 value. Free to enter. Drawn live May 31.
>
> pick1.live

(Attach: `assets/ad-creative/v2/gleam-hero.png`)

### Follow-up reply for the thread

> How Pick1 works: one game a day across 9 sports. Calibrated AI
> confidence score on every pick. Wins AND misses logged publicly
> forever — no cherry-picking, no "guaranteed locks."
>
> The kind of sports picks tool we wish existed.

---

## 2 · Instagram feed post (tonight)

**Image:** `assets/ad-creative/v2/gleam-hero.png` (1200×600 → IG will
center-crop on a 1080×1080 feed slot; the trophy + headline survive
the crop fine)

**Caption:**

> Pick1 launches end of May 🏆
>
> To celebrate we're giving away 2 World Cup tickets + Lifetime Pro
> ($1,499 value).
>
> Free to enter. Drawn live May 31, 11:59 PM ET.
>
> Tap the link in our bio to lock your entry.
>
> ──
>
> What's Pick1? One AI sports pick per day across 9 sports. Every
> call logged publicly forever. No tout BS.
>
> .
> .
> .
> #fifaworldcup #worldcup2026 #sportsbetting #nba #nfl #freegiveaway
> #sweepstakes #pickemchallenge #aiprediction #sportspicks

**Bio link (update now):** point Linktree / IG bio link to the Gleam
URL directly (or to pick1.live which has the banner above the
signup form).

---

## 3 · TikTok video idea (record this week)

A 15-second native-feel video, not over-produced. Founder Noa to
record.

**Beats:**
1. (0:00) Noa to camera, holding phone showing Pick1.live: "I built
   an AI that calls one game a day. Every pick logged publicly — even
   the losses."
2. (0:03) Cut to screen recording of pick1.live, scrolling the
   tracker page.
3. (0:06) Cut back to Noa: "To celebrate launching end of May we're
   giving away 2 World Cup tickets + lifetime access. Free to enter."
4. (0:10) Show the Gleam page on screen briefly.
5. (0:12) Noa: "Link in bio. Drawn live May 31."
6. (0:14) End-card: "PICK1 · pick1.live"

**Caption:**

> Built an AI to call sports games. Giving away 2 World Cup tickets to celebrate the launch. Link in bio.
> #fifaworldcup #aibetting #sportspicks

---

## 4 · Facebook page post (Noa to post tonight)

> 🏆 Sweepstakes is live.
>
> Win 2 group-stage tickets to the 2026 FIFA World Cup + lifetime
> access to Pick1 Pro — our AI sports prediction tool that calls one
> game per day across 9 sports with every prediction logged publicly.
>
> $1,499 prize value. Free to enter. Winner drawn May 31, 11:59 PM ET.
>
> Enter here → https://gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro

(Attach: `assets/ad-creative/v2/gleam-hero.png`)

---

## 5 · Email blast to existing waitlist (tomorrow morning)

Subject: **🏆 Win 2 World Cup tickets — sweeps just opened**

Body:

> Hi {first_name},
>
> Quick one — we just opened the launch sweepstakes:
>
> **Prize:** 2 tickets to a 2026 FIFA World Cup group-stage match
> + Lifetime Pick1 Pro ($1,499 total value)
> **Cost to enter:** $0
> **Drawn:** May 31, 11:59 PM ET — live on stream
>
> You're already on the waitlist so you're eligible. To boost your
> odds, do any of the entry actions on the sweeps page (follow IG, share
> with a friend who'd like an extra entry).
>
> [Enter the sweepstakes →](https://gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro)
>
> — Noa
> Founder, Pick1

---

## 6 · Reddit r/sportsbook (Day 20, May 26)

See `launch/SECONDARY_CONTEST_STACK.md` § Appendix C — the post
outline already covers the angle, but update the giveaway hook to
match the live sweeps:

> ...I'm also running a launch sweepstakes — winner gets 2 World Cup
> tickets + lifetime access. Free to enter, link's in my profile if
> you want in.

Critical: the Reddit post leads with VALUE (long-form analysis of
the last week of Pick1 picks), the sweeps is a footer. Reddit
downvote-bombs anything that smells like a giveaway shill.

---

## Tracking

For everything above, append these UTM params to the Gleam URL:

```
?utm_source={source}&utm_medium={medium}&utm_campaign=sweeps_launch
```

| Channel | utm_source | utm_medium |
|---|---|---|
| Twitter post | twitter | social |
| IG feed post | instagram | social |
| IG bio | instagram | bio |
| TikTok video | tiktok | social |
| FB page post | facebook | social |
| Email blast | resend | email |
| Reddit | reddit | community |
| Pick1.live banner | site | hero_banner |

Already-instrumented in `index.html` — pick1.live banner already
uses `utm_source=site&utm_medium=hero_banner` style attribution.
