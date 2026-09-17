package com.pick1.app.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.consumePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import com.pick1.app.BuildConfig
import com.pick1.app.data.Prefs
import com.pick1.app.data.Supabase
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

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
    /** Formatted price of the introductory first billing period, e.g. "$0.99",
     *  or null when this storefront/account gets no intro. It is a PAID intro,
     *  not a free trial: iOS sells $0.99 for the first period then $14.99, and
     *  Android has to say the same thing. */
    val introPrice: String? = null,
    val isBestValue: Boolean = false,
    /// What this plan costs per 30 days, in the storefront's currency, or
    /// null for a plan already billed monthly (nothing to convert).
    val perMonth: String? = null,
    /// What this plan saves per 30 days against the dearest plan on the
    /// paywall. Only ever set on the cheapest-per-month plan, so exactly one
    /// card carries it, and it is subtraction over the two figures above.
    val savingPerMonth: String? = null,
)

object Products {
    const val WEEKLY = "com.pick1.app.pro.weekly"
    const val MONTHLY = "com.pick1.app.pro.monthly"
    const val DAY_PASS = "com.pick1.app.daypass"

    /**
     * Subscription SKUs, in paywall display order.
     *
     * TWO products, matching iOS exactly: weekly and monthly, both $14.99
     * recurring after a $0.99 first period. The annual was removed on
     * 2026-09-10 because iOS no longer sells one; Android was still
     * advertising it at $249.99, a product that does not exist, and the
     * best-value preselect was pointing straight at it.
     */
    // MONTHLY FIRST, since 2026-09-16. It is the preselected plan and it
    // carries BEST VALUE, but it was rendering second, so the first price on
    // screen was the smallest sticker, "$14.99/wk", attached to the plan that
    // reaches a paid period 16.8% of the time against monthly's 33.8% and
    // whose median life is three days against thirty. This list IS the
    // paywall's display order (PaywallScreen renders Billing.offers in order).
    val SUBS = listOf(MONTHLY, WEEKLY)

    fun name(id: String) = when (id) {
        WEEKLY -> "Weekly"; MONTHLY -> "Monthly"; DAY_PASS -> "Day Pass"
        else -> id
    }
    fun subtitle(id: String) = when (id) {
        WEEKLY -> "Full access, billed weekly"
        // Was "Same price, four times the access", written while both plans
        // were $14.99. App Store Connect has the monthly at $39.99 against
        // $14.99 a week, so the prices are NOT the same and that sentence had
        // become a false pricing claim. It is still the cheaper month, which
        // is what `isBestValue` says, so the subtitle just states the terms.
        MONTHLY -> "Full access, billed monthly"
        DAY_PASS -> "24-hour full access"
        else -> ""
    }
    fun fallbackUnit(id: String) = when (id) {
        WEEKLY -> "/wk"; MONTHLY -> "/mo"; else -> ""
    }
}

/**
 * Placeholder catalogue — the paywall's fallback when real `ProductDetails`
 * aren't available (Play Store absent, e.g. an emulator without Play services,
 * or the reviewer path). Prices mirror the live App Store ones so the layout
 * is correct; [Billing.offers] replaces them with localized Play prices the
 * moment the catalogue loads.
 */
object PlaceholderCatalogue {
    fun plans(introEligible: Boolean): List<PlanOffer> = listOf(
        // Monthly FIRST, same order as the live catalogue. The placeholder is
        // what an emulator and any device without Play services renders, so
        // when it disagrees with the real paywall the disagreement is the bug.
        //
        // BEST VALUE is arithmetic, not a slogan: $39.99 a month against
        // $14.99 a week, which is $64.24 over the same 30 days.
        PlanOffer(
            Products.MONTHLY, "Monthly", "Full access, billed monthly",
            "$39.99", "/mo",
            introPrice = if (introEligible) "$0.99" else null,
            isBestValue = true,
            savingPerMonth = "$24.25",
        ),
        PlanOffer(
            Products.WEEKLY, "Weekly", "Full access, billed weekly",
            "$14.99", "/wk",
            introPrice = if (introEligible) "$0.99" else null,
            perMonth = "$64.24",
        ),
    )
}

/**
 * Google Play Billing (Library 7) — the Android counterpart of the iOS
 * `SubscriptionManager`/StoreKit layer.
 *
 * Entitlement is the OR of two sources so it matches iOS exactly:
 *   • local Play purchases (`queryPurchasesAsync`) — fast, offline, the
 *     device's own subscription;
 *   • the backend `subscriptions` table — so a member who subscribed on iOS
 *     is Pro here too (one account, one entitlement across platforms).
 *
 * On every purchase we POST the purchase token to the `play-verify` Edge
 * Function, which validates it against the Google Play Developer API and
 * writes the server-authoritative row (the RTDN webhook keeps it fresh after).
 */
object Billing {

    private const val TAG = "Billing"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val json = Json { ignoreUnknownKeys = true }

    private val _isPro = MutableStateFlow(false)
    val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    private val _offers = MutableStateFlow<List<PlanOffer>>(emptyList())
    /** Real Play offers; empty until the catalogue loads (UI falls back). */
    val offers: StateFlow<List<PlanOffer>> = _offers.asStateFlow()

    private val _introEligible = MutableStateFlow(false)
    /** True when Play is offering the $0.99 first period on this account. */
    val introEligible: StateFlow<Boolean> = _introEligible.asStateFlow()

    private var appContext: Context? = null
    private var client: BillingClient? = null
    private val detailsById = mutableMapOf<String, ProductDetails>()

    private val purchasesListener = PurchasesUpdatedListener { result, purchases ->
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            for (p in purchases) handlePurchase(p)
        }
    }

    /** Call once from Application.onCreate. */
    fun init(context: Context) {
        if (client != null) return
        appContext = context.applicationContext
        val c = BillingClient.newBuilder(context.applicationContext)
            .setListener(purchasesListener)
            .enablePendingPurchases(
                PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
            )
            .build()
        client = c
        connect()
    }

    private fun connect(onReady: (() -> Unit)? = null) {
        val c = client ?: return
        if (c.isReady) { onReady?.invoke(); return }
        c.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    scope.launch { queryProducts(); refreshEntitlement() }
                    onReady?.invoke()
                } else {
                    Log.w(TAG, "billing setup failed: ${result.responseCode} ${result.debugMessage}")
                }
            }
            override fun onBillingServiceDisconnected() { /* reconnect lazily on next use */ }
        })
    }

    /** Re-check entitlement (e.g. app resume, or after a cross-platform sub). */
    fun refresh() = scope.launch { connect { scope.launch { refreshEntitlement() } } }

    // ── Catalogue ────────────────────────────────────────────────────────
    private suspend fun queryProducts() {
        val c = client ?: return
        val subProducts = Products.SUBS.map { id ->
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(id).setProductType(BillingClient.ProductType.SUBS).build()
        }
        val inappProducts = listOf(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(Products.DAY_PASS).setProductType(BillingClient.ProductType.INAPP).build()
        )
        runCatching {
            val subs = c.queryProductDetails(
                QueryProductDetailsParams.newBuilder().setProductList(subProducts).build()
            )
            val inapp = c.queryProductDetails(
                QueryProductDetailsParams.newBuilder().setProductList(inappProducts).build()
            )
            val all = (subs.productDetailsList.orEmpty() + inapp.productDetailsList.orEmpty())
            detailsById.clear()
            all.forEach { detailsById[it.productId] = it }
            rebuildOffers()
        }.onFailure { Log.w(TAG, "queryProducts failed: ${it.message}") }
    }

    /// Cost per 30 days in micros, from the recurring phase's own period.
    ///
    /// 30 days rather than 4 weeks on purpose: a 4-week month understates a
    /// weekly plan by about 8%, which is exactly the error this exists to
    /// correct. Mirrors `Product.monthlyEquivalent` on iOS.
    private fun perMonthMicros(periodIso: String?, micros: Long): Long? {
        val m = Regex("^P(?:(\\d+)Y)?(?:(\\d+)M)?(?:(\\d+)W)?(?:(\\d+)D)?$")
            .find(periodIso ?: return null) ?: return null
        val (y, mo, w, d) = (1..4).map { m.groupValues[it].toLongOrNull() ?: 0L }
        val days = y * 365 + mo * 30 + w * 7 + d
        if (days <= 0L) return null
        return micros * 30 / days
    }

    /// A plan plus the raw numbers needed to compare it with the others.
    /// Kept out of PlanOffer because the UI has no use for micros.
    private data class Priced(
        val plan: PlanOffer,
        val perMonthMicros: Long?,
        val currency: String?,
    )

    /// Micros to a localized money string, in the storefront's own currency
    /// and the device's own formatting, so "$24.97" and "24,97 €" both come
    /// out right without a hardcoded symbol table.
    private fun money(micros: Long, currency: String?): String? {
        val code = currency ?: return null
        return runCatching {
            val f = java.text.NumberFormat.getCurrencyInstance()
            f.currency = java.util.Currency.getInstance(code)
            f.format(micros / 1_000_000.0)
        }.getOrNull()
    }

    private fun rebuildOffers() {
        var anyIntro = false
        val list = Products.SUBS.mapNotNull { id ->
            val d = detailsById[id] ?: return@mapNotNull null
            val offer = bestOffer(d) ?: return@mapNotNull null
            val phases = offer.pricingPhases.pricingPhaseList
            val paidPhase = phases.lastOrNull()
            // The recurring price is the LAST phase; anything before it is the
            // introductory period. Detecting it by "price is zero" only ever
            // found a FREE trial, and this offer is a paid $0.99 intro, so the
            // old check reported no offer at all.
            val introPhase = phases.dropLast(1).firstOrNull()
            if (introPhase != null) anyIntro = true
            val plan = PlanOffer(
                productId = id,
                name = Products.name(id),
                subtitle = Products.subtitle(id),
                displayPrice = paidPhase?.formattedPrice ?: "",
                unit = unitFor(paidPhase?.billingPeriod) ?: Products.fallbackUnit(id),
                introPrice = introPhase?.formattedPrice,
                isBestValue = id == Products.MONTHLY,
            )
            Priced(
                plan = plan,
                perMonthMicros = perMonthMicros(paidPhase?.billingPeriod,
                                                paidPhase?.priceAmountMicros ?: 0L),
                currency = paidPhase?.priceCurrencyCode,
            )
        }
        // Second pass: a saving cannot be known until every plan's per-month
        // figure exists, so it is filled in here rather than in the map above.
        val dearest = list.mapNotNull { it.perMonthMicros }.maxOrNull()
        _offers.value = list.map { p ->
            val mine = p.perMonthMicros
            // Nothing to convert on a plan already billed monthly.
            val perMonth = if (p.plan.unit == "/mo" || mine == null) null
                           else money(mine, p.currency)
            // At least a currency unit of difference, so the line never reads
            // "Save $0.00" on two plans that happen to price out the same.
            val saving = if (mine != null && dearest != null && dearest - mine >= 1_000_000L)
                             money(dearest - mine, p.currency) else null
            p.plan.copy(perMonth = perMonth, savingPerMonth = saving)
        }
        _introEligible.value = anyIntro
    }

    /** The base subscription offer, preferring one that carries an intro phase. */
    private fun bestOffer(d: ProductDetails): ProductDetails.SubscriptionOfferDetails? {
        val offers = d.subscriptionOfferDetails ?: return null
        return offers.firstOrNull { it.pricingPhases.pricingPhaseList.size > 1 }
            ?: offers.lastOrNull()
    }

    private fun unitFor(period: String?): String? = when (period) {
        "P1W" -> "/wk"; "P1M" -> "/mo"; "P3M" -> "/qtr"; "P6M" -> "/6mo"; "P1Y" -> "/yr"; else -> null
    }

    // ── Purchase ─────────────────────────────────────────────────────────
    /** Launch the Play purchase sheet for [productId]. No-ops without Play. */
    fun purchase(activity: Activity, productId: String) {
        val c = client ?: return
        val details = detailsById[productId] ?: run {
            // Catalogue not ready — connect, load, and bail; user can retap.
            connect { scope.launch { queryProducts() } }
            return
        }
        val userId = Supabase.client.auth.currentUserOrNull()?.id
        val paramsBuilder = BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(details)
        if (productId in Products.SUBS) {
            val token = bestOffer(details)?.offerToken ?: return
            paramsBuilder.setOfferToken(token)
        }
        val flow = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(paramsBuilder.build()))
            .apply { userId?.let { setObfuscatedAccountId(it) } }
            .build()
        c.launchBillingFlow(activity, flow)
    }

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return
        scope.launch {
            val c = client ?: return@launch
            val productId = purchase.products.firstOrNull()
            // Report to the backend for server-side validation + record.
            reportToServer(purchase, isSub = productId in Products.SUBS)

            if (productId == Products.DAY_PASS) {
                // 24h consumable: consume so it can be re-bought, and grant a
                // local 24h window (server also records it).
                runCatching {
                    c.consumePurchase(ConsumeParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build())
                }
                appContext?.let { Prefs.setDayPassPurchased(it, purchase.purchaseTime) }
            } else if (!purchase.isAcknowledged) {
                runCatching {
                    c.acknowledgePurchase(
                        AcknowledgePurchaseParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
                    )
                }
            }
            refreshEntitlement()
        }
    }

    // ── Entitlement ──────────────────────────────────────────────────────
    private suspend fun refreshEntitlement() {
        val local = hasActiveLocalPurchase()
        val remote = backendEntitled()
        _isPro.value = local || remote
    }

    private suspend fun hasActiveLocalPurchase(): Boolean {
        val c = client ?: return false
        val subs = runCatching {
            c.queryPurchasesAsync(
                QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
            ).purchasesList
        }.getOrDefault(emptyList())
        val activeSub = subs.any { it.purchaseState == Purchase.PurchaseState.PURCHASED }
        if (activeSub) {
            // Acknowledge any sub that slipped through unacknowledged.
            subs.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED && !it.isAcknowledged }
                .forEach { p ->
                    runCatching {
                        c.acknowledgePurchase(
                            AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()
                        )
                    }
                }
            return true
        }
        // Day pass: local 24h window.
        val until = appContext?.let { Prefs.dayPassUntil(it) } ?: 0L
        return System.currentTimeMillis() < until
    }

    @Serializable
    private data class SubRow(val expires_date: String? = null, val revocation_date: String? = null)

    /** Cross-platform check: is there a live row in `subscriptions` for me? */
    private suspend fun backendEntitled(): Boolean {
        val userId = Supabase.client.auth.currentUserOrNull()?.id ?: return false
        return runCatching {
            val nowIso = com.pick1.app.data.nowIso()
            Supabase.client.from("subscriptions").select(
                io.github.jan.supabase.postgrest.query.Columns.raw("expires_date,revocation_date")
            ) {
                filter {
                    eq("user_id", userId)
                    gt("expires_date", nowIso)
                }
                limit(5)
            }.decodeList<SubRow>().any { it.revocation_date == null }
        }.getOrDefault(false)
    }

    @Serializable
    private data class VerifyBody(
        val userId: String?,
        val productId: String?,
        val purchaseToken: String,
        val isSub: Boolean,
    )

    private fun reportToServer(purchase: Purchase, isSub: Boolean) {
        val body = VerifyBody(
            userId = Supabase.client.auth.currentUserOrNull()?.id,
            productId = purchase.products.firstOrNull(),
            purchaseToken = purchase.purchaseToken,
            isSub = isSub,
        )
        runCatching {
            val url = URL("${BuildConfig.SUPABASE_URL}/functions/v1/play-verify")
            (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                doOutput = true
                connectTimeout = 15000
                readTimeout = 15000
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("apikey", BuildConfig.SUPABASE_ANON_KEY)
                val bearer = Supabase.client.auth.currentSessionOrNull()?.accessToken
                    ?: BuildConfig.SUPABASE_ANON_KEY
                setRequestProperty("Authorization", "Bearer $bearer")
                outputStream.use { it.write(json.encodeToString(VerifyBody.serializer(), body).toByteArray()) }
                val code = responseCode
                if (code !in 200..299) Log.w(TAG, "play-verify $code")
                disconnect()
            }
        }.onFailure { Log.w(TAG, "reportToServer failed: ${it.message}") }
    }

    /** Paywall "Restore purchases" — re-sync from Play + backend. */
    fun restore() = scope.launch {
        connect {
            scope.launch {
                val c = client ?: return@launch
                runCatching {
                    c.queryPurchasesAsync(
                        QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
                    ).purchasesList
                }.getOrDefault(emptyList())
                    .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }
                    .forEach { reportToServer(it, isSub = true) }
                refreshEntitlement()
            }
        }
    }
}
