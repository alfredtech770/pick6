package com.pick1.app.billing

/**
 * A purchasable plan, normalised so the paywall UI doesn't care whether it
 * came from Google Play Billing or a placeholder.
 *
 * Mirrors what `SubscriptionManager`/StoreKit vends on iOS. Product IDs are
 * kept IDENTICAL to the App Store ones so the backend, the `subscriptions`
 * table and analytics stay platform-agnostic.
 */
data class PlanOffer(
    val productId: String,
    val name: String,
    val subtitle: String,
    val displayPrice: String,
    val unit: String,
    val hasTrial: Boolean = false,
    val isBestValue: Boolean = false,
)

object Products {
    const val WEEKLY = "com.pick1.app.pro.weekly"
    const val MONTHLY = "com.pick1.app.pro.monthly"
    const val ANNUAL = "com.pick1.app.pro.annual"
    const val DAY_PASS = "com.pick1.app.daypass"
}

/**
 * Placeholder catalogue used until the Play Console products exist.
 *
 * Google Play only vends real SKUs to an app uploaded to a testing track
 * under a registered developer account — neither of which exists yet. Prices
 * here mirror the live App Store ones so the paywall can be laid out and
 * reviewed now; `BillingRepository` replaces them with real
 * `ProductDetails` (localised prices) the moment the Play catalogue is live.
 */
object PlaceholderCatalogue {
    fun plans(trialEligible: Boolean): List<PlanOffer> = listOf(
        PlanOffer(
            productId = Products.WEEKLY,
            name = "Weekly",
            subtitle = "Full access, billed weekly",
            displayPrice = "$14.99",
            unit = "/wk",
            hasTrial = trialEligible,
        ),
        PlanOffer(
            productId = Products.MONTHLY,
            name = "Monthly",
            subtitle = "Best per-week rate",
            displayPrice = "$39.99",
            unit = "/mo",
            isBestValue = true,
        ),
    )
}
