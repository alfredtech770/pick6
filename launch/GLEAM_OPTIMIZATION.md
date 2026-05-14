# Gleam campaign — conversion optimization (✅ DONE May 14)

**Final live URL:** https://gleam.io/Ivb0j/win-2-fifa-world-cup-tickets-lifetime-pick1-pro
**Editor:** https://gleam.io/editor-next/competitions/Ivb0j-win-2-fifa-world-cup-tickets-lifetime-pick1-pro/edit

**What shipped (Free tier):**
- ✅ Title: prize-first ("Win 2 FIFA World Cup Tickets 🏆 + Lifetime Pick1 Pro") — URL slug auto-updated to match
- ✅ Description: 79-word prize-first pitch with $1,499 value cue, "Free to enter", "Drawn live May 31, 11:59 PM ET"
- ✅ Entry methods: 2 (waitlist + IG follow) — see paywall notes below

**Free-tier paywall blockers (documented for future, but worked around):**
- ❌ Feature Media (hero image upload) — Hobby+ only
- ❌ Inline images in description — Hobby+ only (server-side validator blocks the save)
- ❌ Custom CSS (brand colors) — Business+ only
- ❌ Viral Share entry method — Pro+ only. Replaced by our own position-jumping referral system on pick1.live (Activation 1).
- ❌ Visit-a-Page entries auto-inject "Repeat Action Limit" — Hobby+ only. Adding TikTok/X follow entries triggers this. Worked around by mentioning the socials in the description copy instead.

**Where the hero image lives instead:** `assets/ad-creative/v2/gleam-hero.png` is wired into the pick1.live banner (above the signup form) + FB page cover + social-share image + Meta ad creative. The Gleam page itself is text-only — but visitors arriving via pick1.live or social ads see the branded asset before they land there.

For paste-ready launch posts using the new URL, see `SWEEPSTAKES_LAUNCH_COPY.md`.

---

## Reference: the changes that were applied

The original plan below is preserved for context. Items marked
[Free-tier blocked] could not be applied without an upgrade.

---

## 1 · Setup tab → Competition Name

**Current (brand-first, buries prize):**
> PICK1 Launch Sweepstakes — Win 2026 FIFA World Cup Tickets

**Replace with (prize-first, emoji as visual anchor):**
> Win 2 FIFA World Cup Tickets 🏆 + Lifetime Pick1 Pro

Why: The name appears in social previews, share cards, and the
in-widget header. Leading with the verb "Win" + concrete prize lifts
click-through on shared links. Brand is secondary on a sweeps page —
people enter for the prize, not for us yet.

---

## 2 · Design tab → Hero image

**Upload:** `assets/ad-creative/v2/gleam-hero.png` (1200×600, 353 KB)

Designed prize-first: massive "WIN 2 / WORLD CUP / TICKETS" in Anton,
trophy emoji on the right with a $1,499 prize-value card, PICK1 logo
anchoring the bottom-left, deadline reminder in the bottom-right.
Brand-consistent with pick1.live (black bg, acid-green accent).

---

## 3 · Design tab → Brand colors

Gleam usually has fields for "Primary color" and "Background color".

- **Primary / Accent:** `#d4ff3a`  (acid green — matches site CTA)
- **Background / Dark:** `#0a0b0d`  (near-black — matches site bg)
- **Text on dark:** `#ffffff`
- **Muted text:** `#9095a0`

If Gleam offers a "Dark mode" toggle, enable it. The black-on-acid
palette is what users will see on pick1.live → continuity reduces
bounce.

---

## 4 · Setup tab → Description / Short Description

**Paste this short description (under 200 chars, optimized for share
cards):**

> Pick1 is launching: one AI sports pick per day across 9 sports, every call logged publicly. To celebrate, we're giving 1 winner 2 group-stage 2026 FIFA World Cup tickets + Lifetime Pro access. Free to enter.

**Long description (if there's a body / "About this competition" field):**

> ### What you can win
> - **2 tickets to a 2026 FIFA World Cup group-stage match** (US host city, winner's choice subject to availability)
> - **Lifetime Pick1 Pro** — AI sports predictions across 9 sports, daily, every call logged publicly. Lifetime access never goes on sale.
> - **Total prize value: $1,499**
>
> ### How it works
> 1. Enter via any of the actions below (Instagram follow, X follow, TikTok follow, waitlist signup, etc.)
> 2. Each completed action = additional entries
> 3. Share your unique referral link — every friend who joins gives you bonus entries
> 4. Winner drawn live on May 31, 11:59 PM ET
>
> ### About Pick1
> One game. One pick. Every day. AI-generated sports predictions across NBA, NFL, MLB, NHL, college football, college basketball, soccer, tennis, and golf. Every prediction logged publicly the night before tip-off — no edits, no excuses.

---

## 5 · How to Enter tab — remaining methods

Free Competitions tier paywalls some actions. Workarounds below:

| Entry | Status | Worth |
|------|--------|------|
| Join Pick1 Waitlist (required, custom URL) | ✅ Done | +10 |
| Follow @pick1.live on Instagram | ✅ Done | +3 |
| Follow @PICK1sport on X | ⚠️ Use "Visit a Page" → x.com/PICK1sport | +3 |
| Follow @pick1app on TikTok | ⚠️ Use "Visit a Page" → tiktok.com/@pick1app | +3 |
| Follow Pick1 on Facebook | ✅ Done | +2 |
| Refer friends (viral share) | ⚠️ Add "Viral Share" action — Gleam auto-generates referral URLs | +5 per friend |
| Answer a question | ⚠️ Add "Answer a Question" — "Who's your AI pick for the 2026 World Cup champion?" | +1 |

The Viral Share action is the most valuable — it turns every entrant
into a referrer. Without it, the campaign won't compound.

---

## 6 · Post-Entry tab — share copy

Gleam shows a thank-you screen after entry with auto-share buttons.
Set the social share text to:

> I just entered to win 2 @FIFAWorldCup tickets + lifetime access to @Pick1sport's AI sports predictions. Free to enter — drawn May 31. 🏆

And the post-entry thank-you message body:

> You're in 🎉 — your entries are locked. Share your unique link below for +5 entries per friend who joins. Drawing live on May 31, 11:59 PM ET.

---

## Quick QA checklist before re-publishing

- [ ] Hero image visible in widget preview (right rail of editor)
- [ ] Title reads "Win 2 FIFA World Cup Tickets…" not "PICK1 Launch…"
- [ ] Background is black, accents are acid-green
- [ ] Viral Share action is live
- [ ] Tested share link in incognito → flow ends on pick1.live
- [ ] Updated FB Page + IG bio with the live Gleam URL
