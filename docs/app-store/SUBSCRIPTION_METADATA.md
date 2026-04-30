# Pick6 Subscriptions — App Store Connect Setup

Exact values to paste into App Store Connect → Monetization → Subscriptions.

---

## Subscription Group

| Field | Value |
|---|---|
| Reference Name | `pick6-pro` |
| Localized Display Name (English) | `Pick6 Pro` |

---

## Product 1 — Pick6 Pro Weekly

### Reference Information
| Field | Value |
|---|---|
| Reference Name | `Pick6 Pro Weekly` |
| Product ID | `com.pick6.app.pro.weekly` |

### Subscription Duration
| Field | Value |
|---|---|
| Subscription Duration | **1 Week** |

### Subscription Prices
| Field | Value |
|---|---|
| Base Country | United States |
| Price | **$14.99 USD** (Tier 15) |
| Family Sharing | **Off** |

### Introductory Offer (Weekly only)
| Field | Value |
|---|---|
| Type | **Free** |
| Duration | **7 Days** |
| Eligibility | **New Subscribers** |
| Countries | All territories |

### App Store Localization (English U.S.)
| Field | Value |
|---|---|
| Subscription Display Name | `Pick6 Pro · Weekly` |
| Description | `Every AI sports pick across 8 leagues, live tracking, and full reasoning. 7-day free trial for new subscribers, then $14.99/week. Cancel anytime.` |

### Review Information
| Field | Value |
|---|---|
| Screenshot | Upload a screenshot of the in-app paywall (the OBPaywallScreen view). 1024×1024 minimum. |
| Review Notes | `Auto-renewable weekly subscription unlocking the full picks feed. Trial fires on first purchase for new subscribers; resumes at $14.99/week thereafter. The app validates entitlement via StoreKit 2 Transaction.currentEntitlements; cross-device sync coming in v1.1.` |

---

## Product 2 — Pick6 Pro Monthly

### Reference Information
| Field | Value |
|---|---|
| Reference Name | `Pick6 Pro Monthly` |
| Product ID | `com.pick6.app.pro.monthly` |

### Subscription Duration
| Field | Value |
|---|---|
| Subscription Duration | **1 Month** |

### Subscription Prices
| Field | Value |
|---|---|
| Base Country | United States |
| Price | **$39.99 USD** (Tier 40) |
| Family Sharing | **Off** |

### Introductory Offer
None — the trial lives on the weekly product only.

### App Store Localization (English U.S.)
| Field | Value |
|---|---|
| Subscription Display Name | `Pick6 Pro · Monthly` |
| Description | `Every AI sports pick across 8 leagues, live tracking, and full reasoning. $39.99/month. Cancel anytime.` |

### Review Information
| Field | Value |
|---|---|
| Screenshot | Same paywall screenshot as the weekly product is fine |
| Review Notes | `Auto-renewable monthly subscription unlocking the full picks feed at a discounted rate vs weekly. No introductory offer.` |

---

## Order in the paywall UI

The iOS code reads `SubscriptionManager.productIds` in this order, and the paywall renders Weekly on the left, Monthly on the right with a "BEST VALUE" / "SAVE 33%" ribbon on Monthly:

```swift
static let productIds: [String] = [
    "com.pick6.app.pro.weekly",
    "com.pick6.app.pro.monthly",
]
```

If you ever want to add a Yearly tier or a Pro+ tier, append to that array and the paywall toggle code accommodates it (with minor styling tweaks).

---

## How users cancel

Apple handles all cancellations natively:

1. iOS Settings → Apple ID (top of Settings) → **Subscriptions**
2. Tap **Pick6 Pro** → **Cancel Subscription**
3. They keep access until the end of the current billing period

Pick6 does not need to render its own cancellation flow. Apple's guideline 3.1.2 *requires* you to disclose this and link to the system Subscription page if you build any in-app cancellation UI — easier to skip it entirely and let Apple handle it.

---

## Family Sharing — why "Off"

Apple lets you opt into Family Sharing per subscription. For Pick6 we recommend **Off** in v1.0:
- AI prediction services are typically priced per individual
- Family-sharing edge cases (different timezones, different sports prefs) complicate UX
- Easy to flip on later if user demand is there

---

## Refunds

Apple handles refund requests through reportaproblem.apple.com. Pick6 receives a refund notification via Apple Server-to-Server Notifications (which Path B v1.1 will wire to a Supabase Edge Function). For v1.0, the device simply observes `Transaction.updates` on next app launch and revokes Pro access.
