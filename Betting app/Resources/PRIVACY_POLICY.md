# Pick6 — Privacy Policy

**Effective date: April 30, 2026**

This Privacy Policy describes how Pick6 ("we", "us", "our") collects, uses, and shares information when you use the Pick6 mobile application (the "Service").

By using Pick6, you agree to the collection and use of information in accordance with this policy.

---

## 1. Information we collect

### 1.1 Information you give us

When you create a Pick6 account we collect:

- **Email address** — used to log you in via a one-time passcode (OTP)
- **Sport preferences** — which of the 8 supported sports you want to follow (NBA, NHL, NFL, MLB, EPL, UFC, F1, IPL Cricket)
- **Notification preferences** — whether you want push alerts for daily picks, live game updates, etc.

We never ask you for, and we never store, your full name unless you choose to add it. We never ask for your home address, your date of birth, or your phone number.

### 1.2 Information collected automatically

When you use Pick6 we collect:

- **Account identifier** — a randomly generated UUID assigned by our authentication provider (Supabase) so we can associate your saved picks with your account
- **Pick history** — which AI predictions you've viewed, saved, or tapped through to detail
- **Subscription status** — whether you're on Free or Pro, your subscription tier, and expiration date (this comes from Apple, not from your card — we never see payment information)

### 1.3 Information we do *not* collect

We deliberately do not collect:

- Real name (unless you optionally add one)
- Phone number
- Physical address
- Date of birth (we age-gate via Apple's 17+ rating)
- Photos, videos, audio, or any device content
- Location data
- Health, fitness, biometric, or financial information beyond what Apple confirms about your subscription
- Browsing or search history outside of Pick6

We never sell your data and we do not share it for advertising purposes.

---

## 2. How we use your information

We use the information we collect to:

- **Run the service** — show you AI predictions for the sports you follow
- **Authenticate you** — send OTP codes to your email so only you can log in to your account
- **Personalize your feed** — filter the home feed by your selected sports
- **Track subscription state** — make sure you only get Pro features if you have an active subscription
- **Improve Pick6** — anonymized usage patterns help us decide which features to build next (we don't tie this to your identity in any analysis)

We never use your information to:

- Build advertising profiles
- Track you across other apps or websites
- Send marketing email outside of transactional service emails (e.g. an OTP code, a subscription receipt, a critical bug fix announcement)

---

## 3. How we store your information

- **Authentication and pick data**: stored in **Supabase** (https://supabase.com), a SOC 2 Type 2-compliant managed Postgres provider, encrypted at rest and in transit
- **Subscription verification**: handled directly by Apple via StoreKit 2; we never store payment cards or transaction details outside of the user-product-expiry tuple Apple gives us
- **Local device storage**: a small amount of preference data (your selected sports, whether you've finished onboarding) is kept in iOS UserDefaults on your phone

We retain your data for as long as your account is active. If you delete your account (see "Your rights" below), we delete all personally identifiable data within 30 days, except where retention is required by law.

---

## 4. How we share your information

We share information with **only** the third parties needed to deliver Pick6:

| Provider | Purpose | Data shared |
|---|---|---|
| **Supabase** | Account auth, pick database, realtime sync | Email, account ID, pick history |
| **Apple (App Store / StoreKit)** | Subscription processing | The transaction Apple itself initiated; we do not send Apple any of your personal data — they already have it |
| **Anthropic** | AI prediction generation | None — predictions are generated server-side using only public sports data, not user information |
| **Sportsdata.io** | Live sports schedules and scores | None — read-only public data |

We do **not** sell, rent, or share your information with advertisers, data brokers, or any third party not listed above.

We may share information if compelled by valid legal process (subpoena, court order). We will challenge overly broad requests and will notify you when legally permitted.

---

## 5. Your rights

You have the right to:

- **Access** the data we hold about you. Email `privacy@pick6.app` and we'll send you a JSON export within 30 days.
- **Correct** inaccurate data. You can update most fields directly in the app's Profile screen, or email us if a field isn't editable.
- **Delete** your account and associated data. In the app: Profile → Settings → Delete Account. Or email `privacy@pick6.app`. We complete deletion within 30 days.
- **Port** your data. Use the "Access" right above to receive a JSON export.
- **Opt out** of marketing communications (Pick6 sends none, so this right is moot — but here on principle).

If you're an EEA, UK, or California resident you also have the right to lodge a complaint with your data protection authority (ICO, CNIL, CPPA, etc.).

---

## 6. Children's privacy

Pick6 is not intended for users under **13 years of age** (or such higher age as required in your jurisdiction by COPPA, GDPR-K, or local law). We do not knowingly collect data from children. Pick6 is rated 12+ on the App Store as a sports analysis and content app — comparable to ESPN, The Athletic, or FiveThirtyEight.

If you believe a child has created a Pick6 account, contact `privacy@pick6.app` and we will delete the account within 7 days.

---

## 7. International data transfers

Pick6 data is hosted in EU (Supabase EU region) and US (Apple's payment processing). If you access Pick6 from outside these regions, your data may be transferred to and processed in regions other than your own. We rely on Standard Contractual Clauses to govern these transfers in compliance with GDPR.

---

## 8. Security

We implement reasonable security practices to protect your information:

- All network traffic uses TLS 1.2 or higher
- Supabase enforces row-level security so you can only access your own picks history
- Apple handles all payment data — we never see, store, or transmit credit card numbers
- We rotate authentication secrets regularly and limit administrative access to a small set of authorized engineers

No system is perfectly secure. If a data breach occurs and your information is affected we will notify you within 72 hours of becoming aware of the breach in accordance with applicable law.

---

## 9. Changes to this policy

We may update this policy periodically. When we do we'll bump the "Effective date" at the top and, for material changes, send you a notice via email or an in-app banner before the change takes effect. Continued use of Pick6 after a policy update constitutes acceptance of the revised policy.

---

## 10. Contact

Questions, requests, complaints:

```
Pick6 Privacy
support@pick6.app
```

For GDPR / California requests specifically, prefix the subject with `[Privacy Request]`.

---

This policy is intentionally short and human-readable. We reviewed every word — there's no boilerplate buried in here that contradicts the plain English above. If anything seems off, email us.
