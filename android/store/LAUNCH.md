# Pick1 on Google Play, what is left to do

Written 2026-09-15. Everything that can be done without signing into Google
is done. What remains needs a Play Console session, because the Play
Developer API cannot create an app; it can only manage one that already
exists.

## State of play

Read directly from Play Console on 2026-09-15. Much of this was already
done; the earlier version of this file assumed none of it was.

| | |
|---|---|
| Developer account | **PICK1**, **Organisation** account, ID 7878940870871307495 |
| Owner | **admin@pick1.live** (Chrome profile index u/2) |
| App entry | **exists already**: `PICK1: AI Sports Picks`, `com.pick1.app`, created 4 Aug 2026 |
| App status | **Draft**, internal testing track, 0 installs |
| Existing release | 1.0.14, versionCode 1, uploaded 4 Aug, never reviewed |
| Public listing | 404, because a Draft app is not published |
| Our bundle | ready, `app/build/outputs/bundle/release/app-release.aab`, versionCode **2**, versionName 1.0.18 |
| Upload keystore | `android/pick1-upload.jks`, passwords in the gitignored `keystore.properties` |
| Firebase (push) | project `pick1-7684d`, `com.pick1.app` registered |
| Store listing copy | `LISTING.md`, 8 locales, updated for 12 sports |
| Privacy policy | https://pick1.live/privacy, returns 200, already set in the console |
| Android device tokens in Supabase | **0**, because nobody has ever installed it |

**The organisation account is the important part.** Google's rule requiring
12 testers opted in continuously for 14 days applies only to *personal*
accounts created after 13 November 2023. This account is an organisation, so
that rule does not apply and there is no two week wait.

## What is actually left

The console's own checklist says **3 of 11 complete**. Done: privacy policy,
ads declaration, store listing. Remaining, in the console's words:

1. Sign in details
2. Content rating
3. Target audience
4. Data safety
5. Government apps
6. Financial features
7. Health
8. Select an app category and provide contact details

Plus, on the internal testing track, *Select testers*, which is the only
step of that track still open (2 of 3 complete).

## Order of operations

**1. Confirm the developer account exists.** play.google.com/console. If
there is no account yet it is a one-off $25 and an identity verification
that can take a few days, so check this first, it is the only step with an
external delay.

**2. Create the app.** All apps, Create app.

- App name `Pick1: AI Sports Picks`
- Default language English (United States)
- App or game: **App**
- Free or paid: **Free** (the subscriptions are in-app)

**3. Upload the bundle.** Testing, Internal testing, Create new release,
drop `app-release.aab`. Do internal testing first, not production: it goes
live in minutes, it proves Play Billing actually works on a real device,
and Billing has never once run outside an emulator on this project. Add
yourself as a tester.

**4. Create the two subscriptions.** Monetise, Subscriptions. The IDs must
match exactly or the paywall renders nothing:

| Product ID | Billing period | Price (US / FR) | Intro offer |
|---|---|---|---|
| `com.pick1.app.pro.weekly` | 1 week | $14.99 / 17,99 € | $0.99 / 0,99 € for the first week |
| `com.pick1.app.pro.monthly` | 1 month | $39.99 / 44,99 € | $0.99 / 0,99 € for the first month |

These mirror App Store Connect exactly, read from it on 2026-09-15. Unlike
Apple, Play does let an intro offer be shorter than the billing period, so
the monthly could be given a one week intro here. Do not do it unilaterally:
the two stores would then sell different things under one brand.

**5. Content rating.** Start the questionnaire. Category: **Reference,
News, or Educational**. The answers that matter: no user-generated content,
no gambling, no real money wagering. Pick1 takes no bets and holds no money.

**6. Data safety.** What the app actually collects, and nothing else, based
on the four permissions it declares (`INTERNET`, `ACCESS_NETWORK_STATE`,
`POST_NOTIFICATIONS`, `BILLING`):

| Data type | Collected | Shared | Why |
|---|---|---|---|
| Email address | yes | no | account sign-in (Supabase) |
| User IDs | yes | no | account, push targeting |
| Purchase history | yes | no | entitlement |
| App interactions | yes | no | product analytics (PostHog) |
| Crash logs / diagnostics | yes | no | stability |
| Location, contacts, photos, files, health, financial info | **no** | | never requested |

All in transit over HTTPS. Account deletion is offered in the app, which is
a Play requirement, and it must also be reachable from a web URL.

**7. Give me the keys, once.** Setup, API access, then link or create a
Google Cloud service account, grant it *Release manager*, and download the
JSON. Hand me that file and every future release is mine: upload, tracks,
staged rollout, listing updates, subscription changes, no console visit.
Same arrangement as the App Store Connect `.p8` I already use.

## Things that are deliberately not identical to iOS

Called out so nobody discovers them later and assumes something broke:

- **No win-back, no trial-save sheet, no billing recovery banners.** Those
  three retention surfaces exist on iOS only. They act on lapsing
  subscribers, and Android has none yet, so they are not launch blockers.
  They become real work the moment there are paying Android users.
- **Play Billing has never run on a real device.** The emulator has no Play
  services, so the paywall has only ever shown `PlaceholderCatalogue`. The
  internal testing track in step 3 is the first honest test of it.
- **Screenshots predate rugby and the sport tags.** They are accurate about
  the product but not current. Worth regenerating before production, not
  before internal testing.
