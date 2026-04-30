# Pick6 — App Store Screenshots Guide

Apple requires screenshots in two iPhone display sizes minimum. This guide covers exactly which simulator to use, which 5 screens to capture, and how to take them.

---

## Required device sizes

| Device class | Simulator to use | Resolution | App Store slot |
|---|---|---|---|
| **6.7" / 6.9"** | iPhone 16 Pro Max | 1290 × 2796 | "iPhone 6.7 Display" |
| **6.5"** | iPhone 14 Plus *(or 11 Pro Max)* | 1242 × 2688 | "iPhone 6.5 Display" |

Apple auto-scales the 6.7" screenshots down for older sizes if you don't supply them, but providing both guarantees the cleanest look across the App Store iPhone gallery.

---

## The 5 screens to capture, in order

App Store guidelines: the **first** screenshot is what users see in search results, so make it the strongest visual.

1. **Home Hi-Fi** — the lime-hero "TOP PICK" screen with the confidence ring and crests. (This is your hero shot.)
2. **Match Detail** — tap any game card, capture the pick reasoning + 4-tab pill.
3. **Sport Hub** — long-press a sport chip (e.g. NBA) → capture the per-sport view with its glow tint.
4. **Profile · Stats tab** — show the avatar gradient + ROI/RECORD/STREAK strip + 4 stat tiles.
5. **Paywall** — the lime "Unlock Every Pick." hero with the weekly/monthly toggle.

---

## How to capture in the simulator

```bash
# Open the right simulator
xcrun simctl boot "iPhone 16 Pro Max"     # for 6.7"
# (or "iPhone 14 Plus" for 6.5")

# Build + run Pick6 to that simulator
# In Xcode: select the simulator from the run destinations, ⌘R

# When the screen you want is on display, save a screenshot:
xcrun simctl io "iPhone 16 Pro Max" screenshot ~/Desktop/pick6-01-home.png
xcrun simctl io "iPhone 16 Pro Max" screenshot ~/Desktop/pick6-02-detail.png
# etc.
```

Or simpler: with the simulator focused, press **⌘S**. Files land on your Desktop.

---

## Pre-capture checklist

Before each shot:

- [ ] Status bar shows **9:41** (this is App Store visual standard) — the simulator does this automatically when you set device locale
- [ ] At least 3 picks loaded in the database (run the pipeline once during a live slate so you have real data)
- [ ] Set `selectedSport` to "all" so the chip filter shows the cleanest state
- [ ] The Live indicator is green (means there are picks loaded)
- [ ] No keyboard or system overlays visible
- [ ] **Hero card data**: pick a moment with a confident pick (≥80%) so the lime ring fills nearly all the way

---

## Optional: text overlays for marketing

You can either submit raw screenshots OR overlay marketing copy on each. The dark Pick6 aesthetic looks great with:

- Anton 80pt headline at top in lime `#D4FF3A` ("AI THAT BEATS THE BOOK.")
- Original screenshot framed below

I recommend doing 5 raw screenshots first (faster to ship), then iterating on overlay versions in v1.1 once you have App Store conversion data.

For overlay generation: any Sketch / Figma file with a 1290×2796 frame works. I can generate a simple template if you want.

---

## App Preview video (optional, recommended for v1.1)

Apple lets you upload one 15–30 second video preview per device size. Record:

```bash
xcrun simctl io "iPhone 16 Pro Max" recordVideo ~/Desktop/pick6-preview.mov
# Tap through Home → Detail → Hub → Profile in 25 seconds
# Press ⌃C in Terminal to stop recording
```

Then trim in QuickTime to 15–30s. App Store requires `.mov` or `.mp4`, max 500 MB.

For v1.0 launch, **skip the video** — adding it later only requires re-uploading the asset, no full re-review.

---

## File naming convention

When you upload to App Store Connect, use clear filenames so you can sort fast:

```
pick6-67in-01-home.png
pick6-67in-02-detail.png
pick6-67in-03-hub.png
pick6-67in-04-profile.png
pick6-67in-05-paywall.png

pick6-65in-01-home.png
pick6-65in-02-detail.png
pick6-65in-03-hub.png
pick6-65in-04-profile.png
pick6-65in-05-paywall.png
```

Upload via App Store Connect → your version → Screenshots section → drag-and-drop.

---

## Common rejection reasons for screenshots

- **Showing iOS UI elements that aren't part of your app** (control center pulled down, notification banner) → recapture with those hidden
- **Showing competitor logos or copyrighted team logos prominently** → Pick6 uses generic team color crests with abbreviated mono initials, so this is naturally avoided. Just don't add team logos in marketing overlays.
- **Showing device frames in screenshots** → upload raw simulator captures, not photos of an iPhone with the screen visible
- **Pricing in screenshots that doesn't match what's in App Store Connect** → if you add a price overlay, keep it consistent with $14.99/wk · $39.99/mo

---

When the simulator is open with the screen ready, ⌘S 5 times in a row, repeat for the second device size. 10 minutes of work total.
