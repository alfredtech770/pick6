# Pick1 — Google Play graphic assets

All files live in `android/store/`. Dimensions verified with `sips`.

| Asset | File | Size | Play requirement | Status |
|---|---|---|---|---|
| App icon | `icon-512.png` | 512×512 | 512×512 PNG, required | ✅ ready (from the live App Store artwork — identical mark) |
| Feature graphic | `feature-graphic-1024x500.png` | 1024×500 | 1024×500, **required** | ✅ generated (Apple has no equivalent, so this is new — built with the app's real Anton/Archivo fonts and P1 lime) |
| Phone screenshots | `screenshots/0*.jpg` | 1242×2208 | 2–8 shots, 16:9/9:16, 320–3840px | ✅ **rebuilt for Android — ready to upload** |

### The upload set (`screenshots/`) — the Apple design, badge fixed

We kept the original App Store artwork: it is the stronger design (gradient
backgrounds, glowing floating annotation cards, better typographic hierarchy).

| # | File | Headline | Source |
|---|---|---|---|
| 1 | `01_best_picks.jpg` | The best picks every day. | Apple Shot1 — **badge replaced** |
| 2 | `02_locked_in.jpg` | Locked in before kickoff. | Apple Shot2, unchanged |
| 3 | `03_every_pick_tracked.jpg` | Every pick. Tracked. | Apple Shot3, unchanged |
| 4 | `04_track_your_picks.jpg` | Track your picks. | Apple Shot4, unchanged |
| 5 | `05_live_now.jpg` | Live now. | Apple Shot5, unchanged |

**Fixed — the false-claim badge.** Shot1 carried a chip reading
*"#1 in Sports Predictions / EDITOR'S CHOICE"*. Editors' Choice is a Google
Play editorial award; claiming it unearned breaches the Play *Misleading
Claims* policy and is exactly the kind of thing that gets a brand-new
developer account flagged rather than just an asset rejected. It was replaced
in place — same lime chip, same position, same tilt — with a claim that is
simply true: **"9 leagues. ONE AI — EVERY SINGLE DAY."**

Rebuild command lives in this repo's history; the untouched original is kept
at `screenshots-apple-original/` (**never upload that Shot1**).

### ⚠️ Accepted risk: iPhone device frames
All five shots frame the app in an **iPhone** (Dynamic Island, iOS status bar).
On a Play listing that misrepresents the platform, and Google's screenshot
guidance expects assets reflecting the real Android experience. This is a
**moderate** risk — far below the badge — and it was accepted deliberately to
keep the stronger artwork.

If Play flags it, a fully Android-framed alternative set is already built and
sitting in `screenshots-android-generated/` (real emulator captures, live
Supabase data, Android punch-hole frame) and can be swapped in immediately.

---

## Still to produce (optional but recommended)

- **Tablet screenshots** — only needed if we declare tablet support.
- **Localized screenshots** — Play lets each locale carry its own set. The
  current set is English-only. The app itself is fully localized in 7
  languages, so localized shots are a conversion win, not a requirement.
