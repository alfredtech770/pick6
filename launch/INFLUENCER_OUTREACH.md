# Influencer outreach — micro-tier (5K-100K followers)

We're not chasing Pat McAfee. We're chasing the 20-50 micro-creators
who have a niche, engaged, betting-curious audience. The math:

> A 30K-follower IG account with 6% engagement = 1,800 people seeing
> a Pick1 post. Compare to a 1M-follower account at 0.4% = 4,000
> impressions for 30x the cost. Micro wins on both engagement AND
> trust (their followers don't see ads on their feed).

**Offer:** Free Lifetime Pro account ($999 perceived value, $0 our
cost) + a chance to do a paid post in week 3 if the audience responds.
No cash up front.

**Track in:** `launch/tracker/MASTER_TRACKER.xlsx` → "Influencer
Outreach" tab. Add a column per contact: contacted_date,
response_date, status (pending / declined / accepted / posted),
posted_url, signups_attributed (from UTM).

---

## Outreach playbook

### Channels
1. **Instagram DM** — primary. Almost all micros run their DM
   themselves.
2. **Twitter DM** — secondary. Often closed; if so, find a Linktree
   or website with a contact form.
3. **Email** — only if it's a verified business profile and they have
   it listed. Otherwise IG DM converts 5x better.

### The DM (use this template — personalized first line is non-
optional)

> Hey [first name] — saw your [SPECIFIC POST: e.g. "your write-up on
> the OKC/MIN second-half adjustments last night"]. The way you
> [SPECIFIC THING THEY DID] is exactly how we think about sports
> picks.
>
> I'm one of the founders of Pick1 — we launch end of May. The short
> version: an AI that calls one game a day across 9 sports, and every
> call (wins AND misses) gets logged publicly forever. No cherry-
> picking, no "guaranteed locks."
>
> I'd love to give you a free Lifetime Pro account ($999 perceived
> value) — no strings. If you like it after a week, maybe we do
> something together for launch.
>
> Take a look: pick1.live — full receipts are at pick1.live/tracker.
>
> — Noa

### Anti-spam rules
- **Never** send the same DM to >5 people in an hour (IG/TikTok will
  flag).
- Personalized first line is hard requirement — generic templates
  read as bot.
- If they don't respond in 7 days, **do not follow up**. One ask, one
  reply window.

---

## Target list (20 micro-creators)

Ranked by audience fit, descending. Engagement % is the metric to
prioritize, not raw follower count.

### Sports betting / NFL+NBA niche

| # | Handle | Platform | Followers | Niche | Why a fit |
|---|---|---|---|---|---|
| 1 | @oddsjam_official | Twitter | 45K | Sportsbook arbitrage / line shopping | Audience is calibration-aware (knows what +EV means); won't be confused by Pick1's methodology |
| 2 | @SharpestSports | Twitter | 30K | Public-vs-sharp money tracking | Their followers think about consensus vs contrarian — Pick1 fits |
| 3 | @theaction_park | IG | 22K | Daily picks across sports | Direct demographic overlap; they already preach "transparent records" |
| 4 | @TheLinesUSA | Twitter | 80K | Legal sports betting news US | Will signal-boost a transparency story |
| 5 | @gambIing.advice | IG | 18K | "Don't be stupid with your money" content | Anti-tout audience |

### NBA-specific

| # | Handle | Platform | Followers | Niche | Why a fit |
|---|---|---|---|---|---|
| 6 | @nbacollegepicks | IG | 35K | NBA + college hoops picks | Active 7 days/week; mid-tier influence |
| 7 | @TheNbaCentral_ | Twitter | 60K | NBA news + analytics | Calibration content does well there |
| 8 | @hoopstribe | TikTok | 75K | NBA short-form | TikTok-native; audience is younger, more open to AI |
| 9 | @nbadraftcentral | IG | 28K | Draft + young player analysis | Builds-relationship with mid-summer audience |
| 10 | @courtsidefilms | IG | 15K | Highlight cuts w/ analytics overlays | Their style aligns w/ Pick1 visual brand |

### NFL-specific

| # | Handle | Platform | Followers | Niche | Why a fit |
|---|---|---|---|---|---|
| 11 | @nflmemes | Twitter | 95K | NFL memes (low-effort but high reach) | Tier-bridging; could turn 1 quote-tweet into 50K impressions |
| 12 | @fantasyguru | IG | 55K | Fantasy football picks | Adjacent: their audience already thinks in expected-value terms |
| 13 | @NFL_lasvegas | Twitter | 40K | Lines & line movement | Lines audience overlaps perfectly w/ Pick1 |
| 14 | @gridironrumors | IG | 30K | NFL news + insider takes | Newsletter format; their audience trusts written analysis |
| 15 | @nflprops_ | TikTok | 22K | Player props content | Pro-prop audience = pro-data audience |

### Multi-sport / general

| # | Handle | Platform | Followers | Niche | Why a fit |
|---|---|---|---|---|---|
| 16 | @SportsBettingDime | Twitter | 50K | All-sport odds + picks | Publisher-adjacent; might do an official content swap |
| 17 | @parlayboys | TikTok | 65K | Parlay-culture meme content | Younger audience, AI-curious, viral potential |
| 18 | @VegasInsider | Twitter | 110K | Lines + Vegas-based analysis | Edge case: more publisher than micro, but DMs are open |
| 19 | @betstamp | IG | 14K | App reviews + tools | They review betting tools — natural fit for Pick1 mention |
| 20 | @PicksWithPrime | Twitter | 8K | Genuinely small acct posting daily picks | Lowest reach but probably highest conversion rate |

---

## Selection criteria recap

A creator is in-scope if **all 3** apply:
1. 5K-100K followers (micro range — bigger = too expensive to start)
2. Posts about sports / sports-betting / sports-analytics at least
   3x/week
3. Engagement rate >2% (likes ÷ followers on recent posts)

A creator is out-of-scope (do **not** contact) if **any** apply:
- Promotes specific sportsbooks for affiliate dollars (DraftKings,
  FanDuel paid posts) — they'll see Pick1 as competitive
- Sells their own "premium picks" — Pick1 directly undermines their
  product
- Crypto / NFT / day-trading adjacent — wrong audience
- Anonymous account with no track record — high spam risk

---

## Tier-2 list (backup if response rate <10%)

If after sending the 20 above we get fewer than 2 responses, the
problem is the message, not the list. Iterate the DM. If response
rate stays low, expand to Tier-2:

- College-specific (CFB / CBB) handles in the 5-20K range
- Soccer / EPL handles (international audience but they care about
  the World Cup)
- Golf and tennis handles (smaller niches but ultra-engaged)
- Reddit users with >5K karma in r/sportsbook (DM them directly)

---

## Tracking

Once outreach starts, log every contact in
`launch/tracker/MASTER_TRACKER.xlsx` → "Influencer Outreach" tab.
Columns:

| Column | Type | Notes |
|---|---|---|
| `handle` | str | Without @ |
| `platform` | enum | ig / tt / tw |
| `followers` | int | At outreach time |
| `niche` | str | Free-text |
| `contacted_date` | date | When we DM'd |
| `dm_url` | str | Link to the DM thread (IG/TT only) |
| `response_date` | date | When they replied (blank if no reply) |
| `status` | enum | pending / declined / accepted / posted |
| `posted_url` | str | URL of the post they made |
| `signups_attributed` | int | From `utm_content={handle}` |
| `notes` | str | Anything qualitative |

Compute the response rate weekly. Cut creators that say no (don't
re-contact). Promote creators who post to "warm" for week 3 paid
collab (~$50-100/post if their first post performed).
