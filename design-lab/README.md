# Pick1 design lab

HTML replica of the live SwiftUI app, built for iterating on the design
before touching Swift.

## Run

```bash
python3 -m http.server 4321 --directory ~/betting-app/design-lab
```

Then open http://localhost:4321. (Opening `index.html` directly also
works in Safari, but a server is safer for the local font files.)

## Files

| File | What it is | Swift counterpart |
|---|---|---|
| `tokens.css` | colours, fonts, radii, shadows | `Pick1Theme.swift` |
| `app.css` | one block per component, each labelled with its struct | `Pick1HomeHiFi.swift`, `Pick1Screens.swift` |
| `app.js` | mock slate + the render functions | `PicksViewModel` + the view bodies |
| `redesign.css` / `redesign.js` | the card-art home (proposal, not shipped) | — |
| `stake.css` / `stake.js` | the whole app in Stake's design language | — |
| `mono.css` / `mono.js` | Betclic-style layout with no colour at all | — |
| `fonts/` | the exact TTFs from the app bundle | `Betting app/Fonts` |

## Generated matchup art

The card-art home draws every game's image from the two teams' colours —
no image assets. `TEAM_COLOR` in `redesign.js` maps a team to one hex;
`.art` in `redesign.css` blends the pair into opposing radial washes under
a halftone screen, a diagonal gloss and a vignette. An unmapped team falls
back to a hash of its name, so it still gets its own colour rather than a
grey blank. Adding a team is one line.

The picked side wears a lime ring, which is what makes the model's call
readable at a glance without reading any text.

## Stake skin

All four tabs, not just home: navy-on-navy surfaces (`#0F212E` / `#1A2C38`
/ `#213743`), one signal green (`#00E701`), 4–6px radii, no display type.
The substantive change is that the model's call is expressed as a **market**
— two priced outcomes with the recommended selection highlighted — rather
than as a headline. Free tier greys the prices out instead of hiding the
fixture.

Note: this reads as a sportsbook, which is the opposite of Pick1's
"not a sportsbook" positioning. See the caveat before shipping any of it.

## Mono skin

The European sportsbook layout Betclic uses (sport strip with an underlined
active tab, compact event rows, 1/N/2 markets, live timer) with zero colour.
Every piece of emphasis is carried by weight, size, surface or an inverted
fill instead of hue. The model's selection is the one white-filled button on
the screen, which makes it the most emphatic element in the app without a
single accent colour.

Crests are desaturated too, so the screen is genuinely monochrome. One rule
in `mono.css` (`.mono .crest img { filter: grayscale(1) … }`) reverses that
if team colours should come back.

Odds for the outcomes the model didn't take come from `counterPrices()` in
`app.js`, derived from the **market** price of the pick rather than the
model's probability. The model is deliberately more confident than the
market, so pricing off it produced absurd numbers (an 18.80 on a side a book
would hang at 5).

Fonts, spacing and colour values were lifted 1:1 from the source, so a
SwiftUI `.padding(14)` is `padding: 14px` here and `.tracking(1.6)` is
`letter-spacing: 1.6px`.

## Covered

Home (Free and Premium variants), Picks, Live, Profile, the floating nav,
the sport dropdown, and every card language: hero, win receipt, locked
slate row, pro slate row, premium upsell, won/lost/live/upcoming cards.

## Not covered yet

`MatchDetailView`, `PaywallScreen`, `SportHubView`, the onboarding funnel,
`PredictionHistoryView`. Tapping a card or an unlock opens a stub sheet
that says so.

## Porting changes back

Each `app.css` section names the struct it came from. Change the CSS,
agree on the look, then apply the same numbers to that struct.
