# Pick6 — App Store Submission Checklist

Work through this top-to-bottom. Each step has the exact field names and values to use.

---

## Phase 0 — One-time prerequisites

- [ ] **Apple Developer Program** membership is active (`developer.apple.com` → Account → Membership). $99/year. Without this you can't ship to the App Store.
- [ ] You're signed into Xcode with the same Apple ID that holds the developer membership: Xcode → Settings → Accounts → "+" → Apple ID.
- [ ] You have an LLC or sole-proprietor identity to publish under (Apple lets you use your personal name, but most teams register a business entity).

---

## Phase 1 — Xcode project (5 min)

The bundle identifier is now `com.pick6.app`.

- [ ] Open `Betting app.xcodeproj` in Xcode
- [ ] Select the **"Betting app"** target → **Signing & Capabilities** tab
- [ ] **Team**: pick your developer team from the dropdown
- [ ] **Bundle Identifier**: confirm it reads `com.pick6.app`
- [ ] Verify the **Sign in with Apple** capability is listed (already wired in `Betting app.entitlements`)
- [ ] Verify the **In-App Purchase** capability is listed — if not, click `+ Capability` → search "In-App Purchase" → add
- [ ] Build for **Any iOS Device (arm64)** — Product → Archive (⌥⌘B). Resolves any signing issues before you head to App Store Connect.

---

## Phase 2 — App Store Connect: app record (10 min)

URL: https://appstoreconnect.apple.com

- [ ] **My Apps** → "+" → **New App**
- [ ] Platform: **iOS**
- [ ] Name: `Pick6` *(if taken, try `Pick6 — AI Sports Picks`)*
- [ ] Primary Language: **English (U.S.)**
- [ ] Bundle ID: select `com.pick6.app` from the dropdown (Xcode populates this once you've signed/built once)
- [ ] SKU: `pick6-ios-001` (internal-only — pick anything unique)
- [ ] User Access: **Full Access**
- [ ] Click **Create**

---

## Phase 3 — Tax & Banking (REQUIRED to sell subscriptions)

Without these, paid subscriptions won't work. Allow 1–3 business days for IRS/tax-authority validation.

- [ ] **Agreements, Tax, and Banking** → click into the **Paid Apps** agreement
- [ ] Sign the agreement (electronic signature)
- [ ] Add **Bank Account** (US: routing + account number; international: SWIFT + IBAN)
- [ ] Fill **Tax Forms** (US: W-9 if domestic, W-8BEN if foreign)
- [ ] Status must show **Active** before submitting the app

---

## Phase 4 — Subscription products (15 min)

Use **`SUBSCRIPTION_METADATA.md`** in this directory for exact copy/values.

- [ ] App Store Connect → your app → **Monetization** → **Subscriptions**
- [ ] **+** → **Create Subscription Group** → name it `Pick6 Pro` → reference name `pick6-pro`
- [ ] Inside the group, click **+** twice to create both subscriptions:
  - **Weekly**: product ID `com.pick6.app.pro.weekly` → reference name `Pick6 Pro Weekly` → Subscription Duration **1 Week** → Price **$14.99 USD** (Tier 15)
  - **Monthly**: product ID `com.pick6.app.pro.monthly` → reference name `Pick6 Pro Monthly` → Subscription Duration **1 Month** → Price **$39.99 USD** (Tier 40)
- [ ] For **Weekly only**, add an **Introductory Offer**:
  - Type: **Free**
  - Duration: **7 days**
  - Eligibility: **New Subscribers**
- [ ] For each subscription, fill the **Localization** (English):
  - Display Name (weekly): `Pick6 Pro · Weekly`
  - Display Name (monthly): `Pick6 Pro · Monthly`
  - Description: see `SUBSCRIPTION_METADATA.md`
- [ ] Upload a **Review Screenshot** — a screenshot of the in-app paywall is fine (1024×1024 minimum)
- [ ] Click **Save**, then **Submit for Review** on each product (they'll be reviewed alongside the app binary)

---

## Phase 5 — App information (10 min)

App Store Connect → your app → **App Information**

- [ ] **Subtitle**: `AI sports analysis & advice` *(30 char max)*
- [ ] **Category** → Primary: **Sports** · Secondary: **News**
- [ ] **Content Rights**: tick the box only if you own the rights or have permission for everything you're publishing (you do — it's all your content)
- [ ] **Age Rating** → click Edit, answer the questionnaire (see `STORE_LISTING.md` for exact answers — should land you at **12+** or **4+**, NOT 17+, since Pick6 is sports analysis content not gambling)

---

## Phase 6 — Pricing & Availability

- [ ] **Pricing and Availability**
- [ ] **Price**: Free *(subscriptions handle all monetization)*
- [ ] **Availability**: All countries. Pick6 is a sports analysis / content app (like ESPN or The Athletic), not a gambling product, so it carries no jurisdiction restrictions. Standard safe-list applies: optionally deselect Iran, North Korea, Cuba, Syria (sanctions). Everything else stays selected.
- [ ] **Distribution**: Public on the App Store

---

## Phase 7 — Privacy (REQUIRED)

App Store Connect → your app → **App Privacy**

- [ ] **Data Collection**: click **Get Started** if not already filled, then walk through using the answers in **`APP_PRIVACY.md`** in this directory
- [ ] **Privacy Policy URL**: paste your hosted URL (see "Hosting legal docs" below)

Hosting legal docs (one-time):

- [ ] Create a public site or repo to host `docs/legal/PRIVACY_POLICY.md` and `TERMS_OF_SERVICE.md` as web pages
- [ ] Easiest: in your GitHub repo settings → Pages → enable from `main` branch → `/docs` folder → URL becomes something like `https://alfredtech770.github.io/pick6/legal/PRIVACY_POLICY.html`
- [ ] Or buy `pick6.app` and serve them at `/privacy` and `/terms`

---

## Phase 8 — App Store listing copy

Use **`STORE_LISTING.md`** in this directory — every field below has its exact text there.

- [ ] **Promotional Text** (170 char) — paste from `STORE_LISTING.md`
- [ ] **Description** (4000 char) — paste from `STORE_LISTING.md`
- [ ] **Keywords** (100 char) — paste from `STORE_LISTING.md`
- [ ] **Support URL**: `https://pick6.app/support` *(or wherever you set up support)*
- [ ] **Marketing URL**: `https://pick6.app` *(optional)*
- [ ] **Version**: `1.0`
- [ ] **What's New in This Version** (4000 char) — paste from `STORE_LISTING.md`

---

## Phase 9 — Screenshots (20 min)

Use **`SCREENSHOTS.md`** in this directory for the exact screens to capture and how.

You need at minimum:

- [ ] **6.7" iPhone** (iPhone 16 Pro Max simulator) — 5 screenshots, 1290×2796
- [ ] **6.5" iPhone** (iPhone 11 Pro Max / 14 Plus simulator) — 5 screenshots, 1242×2688

Recommended additional sets:

- [ ] **5.5" iPhone** (iPhone 8 Plus) — only required if you support iOS < 13; safe to skip for iOS 17+ projects

For each set, in order: **Home Hi-Fi → Match Detail → Sport Hub → Profile → Paywall**.

---

## Phase 10 — App Review information

App Store Connect → your app → **App Review Information**

- [ ] **Sign-in required**: **Yes**
- [ ] **Demo Account**: create one in advance via your normal email-OTP signup. Hand the credentials to Apple here so reviewers can log in. Use a `+test1@yourdomain.com` email and a real OTP path.
- [ ] **Notes**: paste the App Review Notes from `STORE_LISTING.md` (explains why this is a predictions app, not a real-money sportsbook)
- [ ] **Contact Information**: your name, your phone, your email. Apple may call to clarify edge-cases.

---

## Phase 11 — Build upload (10 min)

In Xcode:

- [ ] Select **Any iOS Device (arm64)** as the run destination
- [ ] **Product** → **Archive**
- [ ] When the Organizer window opens after the archive completes:
  - [ ] Click **Distribute App** → **App Store Connect** → **Upload** → defaults → **Upload**
- [ ] Wait ~5–15 min for Apple to process the build (you'll get an email)

In App Store Connect:

- [ ] Open your app → version 1.0 → **Build** section → click **+** → select your uploaded build
- [ ] If you see a yellow warning for **Encryption Compliance**, click and answer **No** unless you've added custom crypto (Apple's standard libs are exempt)

---

## Phase 12 — Submit for Review

- [ ] **Save** at the top right
- [ ] **Add for Review** → walk through any prompts → **Submit to App Review**
- [ ] Apple typically reviews iOS apps in **24–48 hours**

When the email arrives:

- **Approved** → click **Release this version** in App Store Connect to make it live
- **Rejected** → read the Resolution Center message. The most common Pick6-flavored rejection reasons:
  - "App appears to facilitate gambling" → reply that the app surfaces AI-generated predictions for entertainment only and does not facilitate placing real-money wagers (this is true)
  - "Subscription terms unclear" → ensure the paywall lists exact prices, billing period, and that the **Privacy Policy** + **Terms** URLs are linked
  - "Account deletion missing" → required since iOS 14.5: I'll add an "Delete Account" row in Profile → Settings if it's flagged

---

## Post-launch — Sandbox testing before submission

Before you submit, test the actual purchase flow against Apple's sandbox so you don't ship a broken paywall:

- [ ] App Store Connect → **Users and Access** → **Sandbox Testers** → create a test Apple ID (use a fresh email you control)
- [ ] On your test iPhone: Settings → App Store → Sandbox Account → sign in with the sandbox tester
- [ ] Run Pick6 on that device → tap any locked card → paywall → "Start 7-Day Free Trial"
- [ ] Apple's sandbox sheet appears → confirm purchase → verify the app flips to Pro (locked cards become real cards, Profile reads "Subscription · PRO")
- [ ] Test "Restore Purchases" by signing out + back in
- [ ] Test cancel flow: Settings → Apple ID → Subscriptions → cancel → verify app reverts to Free at the next refresh

---

## When you're ready

Hit me up once your tax/banking forms are active and the products are at "Ready to Submit". I'll walk through any rejection reasons that come back and ship fixes immediately.
