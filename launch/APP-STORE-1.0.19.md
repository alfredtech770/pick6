# App Store listing, 1.0.19 (2026-09-17)

Written and applied through the App Store Connect API (see the memory note
`pick1_asc_api`). Source of truth for the text is `app-store-copy-1.0.19.json`
in this folder: subtitle, promotional text, keywords, what's new and the full
description for en-US, fr-FR, es-ES (also used for es-MX), de-DE, it, pt-BR.

What changed and why:

- **No free tier anywhere in the copy.** The hard paywall (rule of
  2026-09-17) made "Free, one pick per sport" a false listing.
- **Reactivation first.** 507 people ran a trial and left. The promotional
  text (live already, on 1.0.18) and a "Coming back?" paragraph name the
  COMEBACK50 offer code (50% off the first month, expired subscribers), and
  the app now opens Apple's redemption sheet from the paywall ("Have a
  code?"). Apple win-back offers (50% for 3 months on monthly, 50% for 4
  weeks on weekly) are set to auto-merchandise on the store page for lapsed
  paid subscribers.
- **Plans paragraph** names weekly, monthly and every three months.
- Subtitle: "Every game called by AI" (and its translations).

Version 1.0.19 is in PREPARE_FOR_SUBMISSION with this text; attach the build
carrying the hard paywall, weekly-first and cohort products, and the four new
subscriptions (quarterly and the .b price test) ride along with it.
