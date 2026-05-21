# Pick1 — In-App Event: FIFA World Cup 2026

In-App Events (IAEs) appear on your product page, in **Search**, in personalized
recommendations, and can be featured in the **Today** tab — one of the best free
visibility levers Apple gives you. This event ties Pick1 to the single biggest
sports moment of 2026.

> Setup path: App Store Connect → your app → (left sidebar) **In-App Events** →
> **(+)**. The event must be submitted for review (~24–72h) and only goes live
> once both the app and the event are approved. Create it now in draft.

---

## Event timing

- **Real-world event:** FIFA World Cup 2026 — opening match **June 11, 2026**.
- **IAE start (publish/go-live):** **June 11, 2026** (kickoff day).
- **IAE end:** **July 9, 2026** — Apple caps event duration at **31 days**, and the
  full tournament (Jun 11–Jul 19) is longer, so run the event across the group
  stage + Round of 16 and refresh/relaunch a second event for the knockouts if
  you want continued coverage.
- **Deep link target:** the in-app **FIFA World Cup hub** (the `showWorldCup`
  fullScreenCover). Use a universal link like `https://pick1.live/worldcup`
  (set up the associated-domain redirect) or a custom URL the app handles.

## Event details (ASC fields)

| Field | Value |
|---|---|
| **Reference Name** (internal) | `World Cup 2026 — Group Stage` |
| **Badge / Event type** | **Special Event** |
| **Event name** (30 char) | `World Cup 2026 Picks` |
| **Short description** (50 char) | `AI picks for every World Cup match, daily.` |
| **Priority** | High (your tentpole event) |

### Long description (120–600 char)
```
The world's biggest tournament is here — and Pick1's AI is calling every match.
From the opening whistle on June 11, get a daily AI prediction for every World
Cup fixture, with the reasoning behind each call: form, head-to-head, squad
news, and confidence ratings. Group stage to the final — one tap, every game.
Open the World Cup hub to see today's slate.
```

### Event card / media
- **Event card image:** 1920 × 1080 (16:9), no text in the safe area Apple overlays.
  Use the World Cup hub's gold-bordered hero look: dark ink ground, the trophy +
  flags motif, lime "PICK1" mark. (You'll supply this asset.)
- **Optional video:** 1920×1080, 10–30s, screen-recording of the World Cup hub.

### Purchase / cost
- **No additional cost** to view the event. (Picks themselves are gated by the
  normal Free/Pro tiers inside the app — the event is free to engage with.)

### Localization
- Localize the event **name + short + long description** into the same 6 languages
  as the listing (see `app-store-localizations.md`). World Cup interest is global —
  this is where IAE localization pays off most.

---

## Why this matters for visibility
- IAEs are **indexed in Search** — "world cup" is one of the highest-volume sports
  queries on Earth during the tournament; this puts Pick1 in those results.
- Events are **eligible for editorial featuring** — Apple actively curates
  event-based collections around major tentpoles like the World Cup.
- A live event badge on your product page **lifts conversion** vs. a static listing.

## Caveats
- The app must be **live (approved)** before the event can display — so this can't
  show until v1.0 passes review. Build it in draft now; submit the event alongside
  or right after the app.
- Don't imply gambling in the event copy (Apple scrutinizes IAEs too) — the copy
  above stays in "AI predictions / analysis" framing, matching the app.
