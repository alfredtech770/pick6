# Pick6 — App Store Submission Package

Everything you need to ship Pick6 to the App Store, ready to copy-paste.

## Files in this directory

| File | Purpose |
|---|---|
| `CHECKLIST.md` | Step-by-step from "open Xcode" to "Submit for Review". Follow this in order. |
| `STORE_LISTING.md` | All marketing copy — paste each section into the matching App Store Connect field. |
| `SUBSCRIPTION_METADATA.md` | Setup for the two in-app subscription products (weekly + monthly with 7-day trial). |
| `APP_PRIVACY.md` | Answers for every question in the App Privacy questionnaire. |
| `SCREENSHOTS.md` | Which simulator screens to capture for each required device size. |

Legal docs (host these on a public URL — Apple requires links):

| File | Where to host |
|---|---|
| `../legal/PRIVACY_POLICY.md` | e.g. `https://pick6.app/privacy` (or GitHub Pages). |
| `../legal/TERMS_OF_SERVICE.md` | e.g. `https://pick6.app/terms`. |

## Quick reference — bundle + product IDs

These are now hardcoded in the project. Keep them aligned in App Store Connect.

```
Bundle Identifier:    com.pick6.app
Subscription Group:   "Pick6 Pro"
Weekly product ID:    com.pick6.app.pro.weekly      $14.99/wk · 7-day free trial
Monthly product ID:   com.pick6.app.pro.monthly     $39.99/mo
```

If you ever need to change the bundle ID, update:
1. Xcode → Target → General → Bundle Identifier
2. `Betting app/SubscriptionManager.swift` → `productIds` array
3. Re-run pipeline + iOS to confirm purchase IDs still match

## Critical timeline notes

- **Apple Developer Program enrollment**: 24–48 hours (one-time, $99/year)
- **App Review for first submission**: typically 24–48 hours
- **In-App Subscription Approval**: reviewed alongside the binary; products must be in "Ready to Submit" state when you submit the build
- **Tax & Banking forms**: required *before* you can sell paid subscriptions. Fill out under Agreements, Tax, and Banking in App Store Connect. Allow 1–3 business days for IRS / tax-authority validation.

## What I cannot do for you

I can't:
- Log into your Apple Developer account or App Store Connect
- Sign legal agreements (Paid Apps Agreement, etc.)
- Enter banking / tax info
- Click "Submit for Review"

Everything else — copy, legal, code, screenshots — is in this directory ready to use.
