# Pick1 on Google Play, what is left to do

Rewritten 2026-09-15 (second session). The app is with Google.

## Status: SENT FOR REVIEW, 2026-09-15

**17 changes submitted to Google**, including the production release
**1.0.18, versionCode 3**, full rollout to 177 countries. Publishing overview
shows *Changes in review*. Google states reviews are typically completed
within 7 days. Managed publishing is **off**, so it publishes as soon as it
is approved.

### How the bundle finally got uploaded

The browser bridge caps `file_upload` at 10 MB and the un-minified bundle was
20.2 MB. Two workarounds failed (a local HTTP server the page could not
reach, and the Play Developer API, blocked behind a passkey re-auth on
console.cloud.google.com that only Ethan can clear). The fix was to make the
bundle smaller, properly:

- **R8 and resource shrinking are now ON** (`isMinifyEnabled = true`,
  `isShrinkResources = true`) with real keep rules in
  `app/proguard-rules.pro` for kotlinx.serialization, ktor, Supabase,
  Firebase, Billing and coroutines.
- **20.2 MB to 9.29 MB.** 11 407 unused `material.icons.extended` vectors
  were the bulk of it. Download size for a new install is **4.48 MB**.
- Verified on the emulator before upload, not assumed: signed in as
  review@pick1.live, the Supabase auth call returned, the board loaded the
  real pick of the day with its reasoning factors, the paywall rendered both
  plans. Zero SerializationException, zero crashes. That is exactly the path
  R8 threatened.

### Two Google requirements that blocked the first attempt

The first upload (versionCode 2) was rejected at the preview step:

1. **Play Billing 7.1.1 to 8.0.0.** Bumped; compiled with no source changes.
2. **targetSdk 35 to 36.** Bumped, with compileSdk 36. AGP 8.7.3 warns that
   it was only tested to 35; it builds and runs. Upgrading AGP is the clean
   follow-up.

Re-verified on device after both bumps: sign-in, board, paywall all fine.

**versionCode 2 is burned.** It was uploaded before those errors surfaced and
Play never releases a versionCode. The shipped build is **3**.

### Advertising ID declaration

Play's pre-submit check flagged it as missing. The merged manifest does carry
`com.google.android.gms.permission.AD_ID`, pulled in by the Meta SDK, so the
answer is **Yes**, purpose **Advertising or marketing** only. Not analytics:
PostHog uses its own anonymous id and the app ships firebase-messaging, not
firebase-analytics.

### Found while testing, not fixed, worth a pass

The in-app onboarding copy is as stale as the store listing was:

- "Every matchup across NBA, NFL, EPL, MLB, UFC, NHL, F1, tennis, cricket and
  golf" names **ten** sports and omits Australian football and rugby.
- "Calibrated confidence: when it says 73%, it hits ~73%" is a performance
  claim, the kind the store copy deliberately avoids.
- Em dashes throughout `strings.xml`, against the house style rule.
- `strings.xml` has four non-positional format strings that warn on every
  build (`funnel_feat2_body`, `funnel_green2_lead`, `funnel_social2_sub`,
  `referral_share_msg`).

## State of play, read from the console 2026-09-15

| | |
|---|---|
| Developer account | **PICK1**, **Organisation**, ID 7878940870871307495 |
| Owner | **admin@pick1.live** (Chrome profile index u/2) |
| App | `PICK1: AI Sports Picks`, `com.pick1.app`, created 4 Aug 2026 |
| App status | **Draft**, never reviewed |
| Internal testing | 1.0.14, versionCode 1, released 4 Aug, **Not reviewed** (internal releases are not) |
| Production | draft release **1.0.18** saved, notes in 7 languages, **177 countries** |
| Our bundle | `app/build/outputs/bundle/release/app-release.aab`, versionCode **2**, versionName 1.0.18 |
| Upload keystore | `android/pick1-upload.jks`, passwords in the gitignored `keystore.properties` |
| Firebase (push) | project `pick1-7684d`, `com.pick1.app` registered |
| Privacy policy | https://pick1.live/privacy, 200 |
| Account deletion page | https://pick1.live/delete-account, 200 (a Play requirement) |
| Android device tokens in Supabase | **0**, nobody has installed it yet |

**The organisation account is the important part.** Google's rule requiring
12 testers opted in continuously for 14 days applies only to *personal*
accounts created after 13 November 2023. This is an organisation account, so
there is no two week wait.

## Done in the console

### App setup, 11 of 11
Store listing, privacy policy, ads declaration, government / financial /
health declarations, app category **Sports**, contact details, content
rating (**All Other App Types**), sign in details, target audience (**18 and
over**), data safety, internal tester list.

### Store listing, rewritten in all 7 locales
en-US, fr-FR, es-ES, de-DE, it-IT, pt-PT, ar.

What was live until today was the **1.0.14 draft copy**, and it was going to
cause problems:

- **"AI picks across 9 leagues"**, naming NBA / NFL / EPL / MLB / NHL / UFC /
  F1 / tennis / IPL. No golf, no Australian football, no rugby, and the app
  does not work off a league shortlist at all.
- **"Free, one pick per sport, every day."** The free tier is one pick a day
  in total. A false store listing is a policy violation, not a typo.
- **"Weekly, Monthly or Annual Pro."** There is no annual product.
- **"Check our calibration: when we say 70%, we show you how often 70%
  actually hit."** A performance claim, exactly what the positioning avoids.
- Em dashes throughout, against the house style rule.

Replaced with the LISTING.md copy, corrected to **twelve sports** (LISTING.md
said ten while listing twelve; the file is fixed too), plus the Play-required
auto-renewal sentence and the `not a sportsbook` line.

### Subscriptions, created and active
Both products existed only in the app's code before today. The Android
paywall would have rendered `PlaceholderCatalogue` and sold nothing.

| Product ID | Base plan | Price | Intro offer |
|---|---|---|---|
| `com.pick1.app.pro.weekly` | `weekly`, auto-renewing, 174 countries | $14.99 US, 15,99 € FR | `intro-first-week`: single payment, 1 week, $0.99 / 0,99 € |
| `com.pick1.app.pro.monthly` | `monthly`, auto-renewing, 174 countries | $39.99 US, 41,99 € FR | `intro-first-month`: single payment, 1 month, $0.99 / 0,99 € |

Both base plans and both offers are **Active**. Eligibility is *New customer
acquisition* with entitlement *Never had any subscription in this app*, which
reproduces Apple's one-intro-per-subscription-group rule.

Four benefits on each product, same wording, all inside Play's 40 characters:
`Every game on the board, 12 sports`, `AI call and win probability per game`,
`Full public record, wins and losses`, `Live scores beside every call`.

**Prices are not identical to the App Store.** Play converts from the US
price and folds local tax in, so France lands at 15,99 € weekly and 41,99 €
monthly against Apple's 17,99 € and 44,99 €. Android is therefore ~11%
cheaper in the eurozone. The intro price is 0,99 € on both stores, which is
the number the ads quote. Left as Play converted it; changing it means
hand-editing every euro country, and it is a pricing call, not a launch
blocker.

## Judgement calls worth knowing

- **Content rating category: All Other App Types, not Game.** Google's Game
  bucket explicitly covers "a game or betting app ... or daily fantasy
  sports". Pick1 takes no bets and runs no contests.
- **Age-restricted promotion or sale, including gambling: No.** Verified by
  reading every outbound link in the app: only pick1.live's own support,
  terms and privacy pages. No bookmaker, no affiliate.
- **Online content: Yes.** The picks are AI-generated and served, not
  bundled, which is Google's own example.
- **Minor-blocking: on.** Optional, one click to undo. The funnel already
  gates at 21+, so it costs no real reach.
- **Target age 18+**, which skipped the child-safety sub-sections entirely.
- **177 countries on production**, mirroring the 175 Apple territories. Three
  of them do not support subscriptions, hence 174 on the base plans.

## The reviewer account

`review@pick1.live` existed since 10 June with zero `pro_grants` rows and no
subscription, so it only ever saw the free tier. Google states on the Sign in
details page that reviewers cannot purchase and cannot use free trials, so
there was no path for them to see the paid product. Fixed with a non-expiring
comp grant, `granted_by` = `claude/play-launch-2026-09-15`. Delete that row
to revoke. Apple's reviewer needs the same thing, so leave it.

**The credential.** `AuthManager` holds two values and only one is ever typed
by a human: `REVIEWER_STATIC_CODE` **070770** goes in the six-digit OTP box,
and `REVIEWER_PASSWORD` is used internally by the app for a Supabase password
grant. The Play form's Password field takes **070770**.

## Still open after the bundle goes up

**1. Play Developer service account.** Setup, API access, link or create a
Google Cloud service account, grant it *Release manager*, download the JSON.
Hand me that file and every future release is mine: upload, tracks, staged
rollout, listing updates, subscription changes, no console visit. Same
arrangement as the App Store Connect `.p8` I already use.

**2. Play Billing has never run on a real device.** The emulator has no Play
services, so the paywall has only ever shown `PlaceholderCatalogue`. Now that
the products exist, the internal testing track is the first honest test. Do
it before the production rollout completes.

**3. Screenshots predate rugby and the sport tags.** Accurate about the
product, not current. Worth regenerating before production.

**4. No win-back, no trial-save sheet, no billing recovery banners.** Those
three retention surfaces are iOS only. They act on lapsing subscribers and
Android has none yet, so they are not launch blockers. They become real work
the moment there are paying Android users.

## Order of operations, if any of this is ever redone

1. Confirm the developer account exists. play.google.com/console.
2. Create the app. All apps, Create app. Free, App, en-US default.
3. Upload the bundle to internal testing, add yourself as a tester.
4. Create the two subscriptions. The IDs must match `Products.WEEKLY` and
   `Products.MONTHLY` in `billing/Billing.kt` exactly or the paywall renders
   nothing.
5. Content rating questionnaire.
6. Data safety, matching the four declared permissions (`INTERNET`,
   `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`, `BILLING`).
7. API access, service account, JSON.

## Ships in the NEXT build, versionCode 4 (do not touch the one in review)

Written 2026-09-17. All compiled; paywall and hero verified on the emulator.

- **Favourites sync to `user_favorites`** (`data/Favorites.kt`): upsert on `user_id,game_id`, delete on un-star, best-effort. Proven end-to-end from the emulator. Every favourite-driven push finally has an Android audience.
- **FOLLOW pill on the hero card** (`HomeV4.kt` + `HomeScreen.kt`): "☆ FOLLOW THIS GAME · GET ALERTS" → "★ FOLLOWING · ALERTS ON". One tap, no navigation.
- **Paywall: monthly first, explicit saving** (`Billing.kt`, `PaywallScreen.kt`, 7× `strings.xml`): "Save $24.25 a month" under monthly, "$64.24 / month" under weekly. Placeholder catalogue aligned.
- Already in versionCode 3 (in review): R8 on, Billing 8.0.0, targetSdk 36.

Server side still to deploy, blocked on a Supabase access token: `send-push` (personal +5/day budget, `fav_start` copy, broadcast cap kept at 3) and `pipeline/index.js` (`fav_start` trigger, baseball goals). Order is send-push FIRST: an unknown key sends its raw name as the title.
