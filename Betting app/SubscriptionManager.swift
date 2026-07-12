// SubscriptionManager.swift
// StoreKit 2 wrapper for Pick1 Pro.
//
// Drives the gate between Free and Pro:
//   • Free  → sees one pick per sport (the highest-confidence pick of the day)
//   • Pro   → sees every pick across every sport
//
// You'll need to create these products in App Store Connect under a single
// subscription group (e.g. "Pick1 Pro"). The IDs MUST match `productIds`
// below EXACTLY or the paywall shows no products:
//
//   Product ID                  Type                   Price
//   com.pick1.app.pro.weekly    Auto-Renewable Weekly  $14.99
//   com.pick1.app.pro.monthly   Auto-Renewable Monthly $39.99
//
// A 3-day free trial is configured as an "Introductory Offer" on the
// MONTHLY product only (the weekly product has no introductory offer).
//
// The Xcode target's bundle identifier is com.pick1.app (matches the IDs).
//
// For TestFlight + App Store, this works against the live StoreKit
// servers automatically — no extra config beyond App Store Connect.
//
// For local Xcode testing, add a StoreKit Configuration File:
//   File > New > File > StoreKit Configuration File → "Pick1.storekit"
//   Then in your scheme: Edit Scheme > Run > Options > StoreKit Configuration
//   = Pick1.storekit. That lets you test purchases without TestFlight.

import Foundation
import Combine
import Supabase
import StoreKit
import SwiftUI

/// Single source of truth for the user's subscription state.
@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Published state

    /// Becomes true once the user has an active entitlement to either tier.
    @Published private(set) var isPro: Bool = false

    /// True when this user has a comped Pro grant (a row in
    /// `public.pro_grants` with no expiry or a future one). Grants Pro
    /// WITHOUT an Apple purchase — used to hand out free access to
    /// specific users (press, influencers, team, friends). OR-ed into
    /// `isPro` so it stacks with any real subscription.
    @Published private(set) var compPro: Bool = false

    /// Active subscription's product ID (or nil if free).
    @Published private(set) var activeProductId: String?

    /// Active subscription expiration (or nil if free).
    @Published private(set) var activeExpiration: Date?

    /// All loaded products from the App Store (after `loadProducts()`).
    @Published private(set) var products: [Product] = []

    /// True while a purchase is in flight (drives CTA spinner / disable).
    @Published private(set) var purchasing: Bool = false

    /// Last error from a purchase attempt, surfaced to the UI.
    @Published var lastError: String?

    /// Whether this Apple ID can still receive the introductory free
    /// trial. Apple grants exactly ONE introductory offer per
    /// subscription group per Apple ID (and its Family Sharing group) —
    /// once it's been used, cancelling and re-subscribing does NOT make
    /// the user eligible again; they pay full price from the next
    /// purchase on. We mirror Apple's server-side rule here so the
    /// paywall stops advertising a "3-day free trial" to a returning
    /// user who's already burned theirs, and shows straight subscribe
    /// copy + pricing instead. Defaults to `true` (a brand-new Apple ID
    /// is eligible) until StoreKit tells us otherwise.
    @Published private(set) var introOfferEligible: Bool = true

    // MARK: - Product load state
    //
    // Background: App Review rejected build 6 with "the SUBSCRIBE NOW button
    // was unresponsive." Root cause was that `loadProducts()` failed
    // silently — products stayed empty, the user tapped Subscribe, and
    // `triggerPurchase` early-returned with only a tiny error label below
    // the button. To a reviewer that reads as a dead button.
    //
    // The paywall now drives its CTA off `productsLoadState`:
    //   .idle       → never attempted (shouldn't happen post-bootstrap)
    //   .loading    → request in flight, CTA shows a spinner + "LOADING…"
    //   .loaded     → ready, CTA shows normal Subscribe/Trial copy
    //   .failed     → CTA flips to "TAP TO RETRY" and re-runs loadProducts
    //
    // The state is published, so SwiftUI re-renders the CTA the instant
    // a load completes or fails. Combined with `lastLoadError` (a
    // human-readable string for the UI), this means the user always
    // sees motion when they tap — no more "looks unresponsive."

    enum ProductsLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    @Published private(set) var productsLoadState: ProductsLoadState = .idle

    /// Human-readable description of the most recent load failure, if any.
    /// Drives the small caption under the CTA so users see *why* a retry
    /// is being offered, not just an unexplained "RETRY" button.
    @Published private(set) var lastLoadError: String?

    // MARK: - Product IDs

    /// Lifetime = a one-time Non-Consumable IAP (not part of the auto-renewing
    /// "Pick1 Pro" subscription group). The entitlement check already treats a
    /// transaction with no expirationDate as active Pro, so no other changes are
    /// needed once this product exists in App Store Connect.
    static let lifetimeProductId = "com.pick1.app.pro.lifetime"

    /// Non-Renewing Subscription: 24 hours of Pro for one game day. StoreKit
    /// does NOT track expiry for this type (it never appears in
    /// currentEntitlements) — on purchase we call the `claim_day_pass` RPC,
    /// which writes a 24h `pro_grants` row; Pro then flows through the same
    /// comp-grant rail as referral weeks (`refreshCompAccess`).
    static let dayPassProductId = "com.pick1.app.pro.daypass"

    /// All Pick1 Pro product identifiers, in display order (weekly →
    /// monthly → day pass; the pass anchors the bottom as the
    /// no-commitment option). Configure the two auto-renewables in App
    /// Store Connect → Subscriptions → "Pick1 Pro" group; the Day Pass
    /// (Non-Renewing Subscription) lives under In-App Purchases.
    ///
    /// Lifetime was REMOVED from the lineup 2026-07 (also pulled from sale
    /// in ASC). `lifetimeProductId` stays defined and the entitlement path
    /// still honors it so any past purchaser keeps Pro forever.
    static let productIds: [String] = [
        "com.pick1.app.pro.weekly",
        "com.pick1.app.pro.monthly",
        dayPassProductId,
    ]

    /// Product ids the ENTITLEMENT check accepts — includes retired
    /// products (Lifetime) that existing owners must keep.
    static let entitledProductIds: [String] = productIds + [lifetimeProductId]

    // MARK: - Lifecycle

    private var transactionListenerTask: Task<Void, Never>?

    /// Grace window after a successful purchase during which
    /// `refreshEntitlements()` must NOT downgrade us back to Free.
    /// StoreKit's `Transaction.currentEntitlements` settles
    /// asynchronously, so a re-query fired immediately after a buy can
    /// momentarily return empty — which is exactly the "paid but the app
    /// didn't unlock" bug. We grant optimistically from the verified
    /// transaction and hold it until currentEntitlements catches up.
    private var optimisticEntitlementUntil: Date = .distantPast

    init() {
        // Always start listening before checking entitlements so we don't
        // miss a purchase that completes mid-app-launch.
        transactionListenerTask = listenForTransactions()

        // Dev-only override. Was previously gated by `#if DEBUG`, but
        // that flag bleeds into TestFlight builds if a scheme inherits
        // it — which would silently grant every user free Pro. Now
        // gated by a dedicated `PICK1_DEV_OVERRIDE` compilation flag
        // that MUST be opt-in via xcconfig for local dev only, never
        // set on the Release scheme.
        if Self.devOverrideActive {
            self.isPro = true
            self.activeProductId = "com.pick1.app.pro.monthly"
            self.activeExpiration = Calendar.current.date(
                byAdding: .year, value: 10, to: Date()
            )
        }
    }

    /// Dev Pro-override is fully disabled — the paywall and real StoreKit
    /// entitlements are authoritative in every build. (Previously gated on
    /// DEBUG + PICK1_DEV_OVERRIDE; removed so nothing can ever grant free
    /// Pro or skip the paywall.)
    static var devOverrideActive: Bool { false }

    deinit {
        transactionListenerTask?.cancel()
    }

    /// Call once on app launch (e.g. from `.task` on the root view).
    func bootstrap() async {
        await loadProducts()
        await refreshEntitlements()
        await refreshCompAccess()
        await retryPendingDayPassClaim()
    }

    // MARK: - Loading products

    /// Fetches the configured products from the App Store.
    /// Safe to call multiple times — drives the published `productsLoadState`
    /// so the paywall can render a spinner / retry button based on the
    /// real status of the request (instead of silently appearing dead).
    func loadProducts() async {
        // Only flip to .loading if we're not already mid-flight, so a
        // concurrent caller doesn't bounce the UI between states.
        if productsLoadState != .loading {
            productsLoadState = .loading
        }
        lastLoadError = nil

        do {
            let fetched = try await Product.products(for: Self.productIds)
            // Sort weekly → monthly for stable display.
            self.products = fetched.sorted { lhs, rhs in
                Self.productIds.firstIndex(of: lhs.id) ?? 0 <
                Self.productIds.firstIndex(of: rhs.id) ?? 0
            }

            // Apple returns an empty array (not an error) when the IDs
            // exist locally but aren't approved/available on the App
            // Store yet — e.g. "Developer Action Needed" or "Waiting
            // for Review" subscriptions. Treat that as a failure so the
            // paywall offers a retry instead of a dead CTA.
            if fetched.isEmpty {
                self.productsLoadState = .failed
                self.lastLoadError = "Subscriptions aren't available right now. Tap retry, or check your connection."
            } else {
                self.productsLoadState = .loaded
                await refreshIntroEligibility()
            }
        } catch {
            self.productsLoadState = .failed
            self.lastLoadError = "Couldn't reach the App Store. Tap retry, or check your connection."
            #if DEBUG
            print("Pick1 SubscriptionManager: loadProducts failed: \(error)")
            #endif
        }
    }

    /// Convenience for the paywall retry button — same as `loadProducts()`,
    /// but named for intent at the call site.
    func reloadProducts() async {
        await loadProducts()
    }

    /// Recomputes `introOfferEligible` from StoreKit. Eligibility is a
    /// property of the whole subscription group, so any product in the
    /// group answers for all of them. StoreKit derives the answer from
    /// the Apple ID's transaction history (including past trials on this
    /// device / Family Sharing group), so a user who cancels after their
    /// trial correctly comes back ineligible.
    func refreshIntroEligibility() async {
        guard let sub = products.compactMap({ $0.subscription }).first else { return }
        // No intro offer configured at all → nothing to be eligible for.
        guard sub.introductoryOffer != nil else {
            self.introOfferEligible = false
            return
        }
        self.introOfferEligible = await sub.isEligibleForIntroOffer
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product. The native Apple sheet
    /// is presented automatically.
    func purchase(_ product: Product) async {
        purchasing = true
        defer { purchasing = false }
        lastError = nil

        do {
            // Tag the purchase with the signed-in user's UUID. Apple echoes
            // this back as `appAccountToken` in every App Store Server
            // Notification, which is how the `apple-notifications` webhook maps
            // a subscription to a row in `public.subscriptions`.
            var options: Set<Product.PurchaseOption> = []
            if let uid = SupabaseManager.client.auth.currentSession?.user.id {
                options.insert(.appAccountToken(uid))
            }
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                // Grant Pro IMMEDIATELY from the transaction we just
                // verified — do NOT wait on a currentEntitlements re-query,
                // which can lag and leave the buyer locked. This is the
                // unlock the user sees the instant the purchase clears.
                self.isPro = true
                self.activeProductId = transaction.productID
                self.activeExpiration = transaction.expirationDate
                self.optimisticEntitlementUntil = Date().addingTimeInterval(60)
                await transaction.finish()
                // Day Pass (non-renewing): StoreKit won't track its expiry,
                // so convert the verified transaction into a 24h server
                // grant. Idempotent per transaction id; Pro then persists
                // through the comp-grant rail until the pass lapses.
                if transaction.productID == Self.dayPassProductId {
                    await claimDayPass(transactionId: String(transaction.id))
                }
                // Reconcile against StoreKit's source of truth. Guarded by
                // the grace window above so it can't bounce us back to Free
                // while currentEntitlements is still settling.
                await refreshEntitlements()
                // The trial is now consumed — reflect ineligibility so a
                // later visit to the paywall shows full-price copy.
                await refreshIntroEligibility()
                // NOTE (Meta value optimization — pickup when we move from
                // install-optimized to ROAS/value-optimized campaigns):
                // This logs the FULL product.price as the Meta Purchase value
                // even at a free-trial START (monthly has a 3-day trial), i.e.
                // before any money is collected. That's fine for install
                // optimization, but for VALUE/ROAS it over-credits trial-starts.
                // To fix: detect the trial via `transaction.offer?.type ==
                // .introductory` and log amount 0 (or the intro price) at trial
                // start, then log the real Purchase value on the first PAID
                // renewal (via Transaction.updates / refreshEntitlements). Until
                // then we optimize on StartTrial, not Purchase value.
                Analytics.subscribed(
                    amount: NSDecimalNumber(decimal: product.price).doubleValue,
                    currency: product.priceFormatStyle.currencyCode,
                    productId: product.id
                )
                if product.subscription?.introductoryOffer != nil {
                    Analytics.trialStarted(productId: product.id)
                }

            case .userCancelled:
                // User dismissed the sheet — not an error to surface.
                break

            case .pending:
                // Awaiting parental approval / SCA — UI should reflect this.
                lastError = "Your purchase is pending approval. We'll unlock Pro as soon as it clears."

            @unknown default:
                lastError = "Unexpected response from the App Store."
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Restores prior purchases from the user's Apple ID. Mirrors the
    /// "Restore Purchases" link in the paywall.
    func restorePurchases() async {
        purchasing = true
        defer { purchasing = false }
        lastError = nil

        do {
            // Triggers a sync with the App Store — entitlements update
            // through `StoreKit.Transaction.currentEntitlements`.
            try await AppStore.sync()
            await refreshEntitlements()
            await refreshIntroEligibility()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Converts a verified Day Pass purchase into a 24h `pro_grants` row via
    /// the `claim_day_pass` RPC (idempotent on the App Store transaction id,
    /// rate-limited server-side). Refreshes comp access so `isPro` holds
    /// after the optimistic window closes.
    private func claimDayPass(transactionId: String) async {
        do {
            _ = try await SupabaseManager.client
                .rpc("claim_day_pass", params: ["tx_id": transactionId])
                .execute()
            UserDefaults.standard.removeObject(forKey: Self.pendingDayPassKey)
        } catch {
            // Grant failed (offline / transient). The optimistic unlock covers
            // the session; persist the tx id so the next launch retries the
            // claim — a paid pass must never be lost to a network blip.
            UserDefaults.standard.set(transactionId, forKey: Self.pendingDayPassKey)
        }
        await refreshCompAccess()
    }

    private static let pendingDayPassKey = "pendingDayPassClaim"

    /// Retry a Day Pass claim that failed at purchase time (idempotent
    /// server-side, so double-claims are harmless). Called from bootstrap.
    func retryPendingDayPassClaim() async {
        guard let tx = UserDefaults.standard.string(forKey: Self.pendingDayPassKey) else { return }
        await claimDayPass(transactionId: tx)
    }

    // MARK: - Comp access (free Pro grants)

    /// Checks `public.pro_grants` for the signed-in user and reflects it
    /// in `compPro` / `isPro`. A row with a null expiry is permanent; a
    /// future `expires_at` is time-limited. Filtered server-side so we
    /// only need to know whether a matching row exists. Best-effort — a
    /// network failure just leaves Pro driven by Apple's receipt.
    func refreshCompAccess() async {
        guard let userId = SupabaseManager.client.auth.currentSession?.user.id else {
            compPro = false
            return
        }
        struct GrantRow: Decodable { let user_id: String }
        let nowISO = ISO8601DateFormatter().string(from: Date())
        do {
            let rows: [GrantRow] = try await SupabaseManager.client
                .from("pro_grants")
                .select("user_id")
                .eq("user_id", value: userId.uuidString)
                .or("expires_at.is.null,expires_at.gt.\(nowISO)")
                .execute()
                .value
            compPro = !rows.isEmpty
            if compPro { isPro = true }   // grant immediately; never downgrade a comp
        } catch {
            // Leave compPro untouched on failure.
        }
    }

    // MARK: - Entitlement check

    /// Walks `StoreKit.Transaction.currentEntitlements` and updates `isPro`.
    func refreshEntitlements() async {
        var foundActive: StoreKit.Transaction?
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                // We only care about subscriptions in our product set,
                // and only ones that are still inside their expiration.
                guard Self.entitledProductIds.contains(transaction.productID) else { continue }
                if let exp = transaction.expirationDate, exp > Date() {
                    foundActive = transaction
                    break
                }
                // Lifetime / non-renewing: take it as active too.
                if transaction.expirationDate == nil {
                    foundActive = transaction
                    break
                }
            } catch {
                continue
            }
        }
        if let tx = foundActive {
            self.isPro = true
            self.activeProductId = tx.productID
            self.activeExpiration = tx.expirationDate
        } else if Date() < optimisticEntitlementUntil {
            // A purchase just completed but currentEntitlements hasn't
            // settled yet. Hold the optimistic grant rather than flipping
            // the freshly-paid user back to Free for a few seconds.
        } else {
            // No active Apple subscription — but a comp grant still
            // counts as Pro. Only drop to Free when neither is present.
            self.isPro = compPro
            self.activeProductId = nil
            self.activeExpiration = nil
        }

        // ── DEV OVERRIDE ───────────────────────────────────────────
        // Always grant Pro when the PICK1_DEV_OVERRIDE flag is set on
        // a DEBUG build, so devs see the full app without StoreKit
        // config. Re-asserted on every refresh so the listener can't
        // silently downgrade us back to Free. NEVER active in
        // TestFlight/Release builds (see Self.devOverrideActive).
        if Self.devOverrideActive {
            self.isPro = true
            if self.activeProductId == nil {
                self.activeProductId = "com.pick1.app.pro.monthly"
            }
            if self.activeExpiration == nil {
                self.activeExpiration = Calendar.current.date(
                    byAdding: .year, value: 10, to: Date()
                )
            }
        }
    }

    // MARK: - Listener

    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self = self else { return }
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    // Drop bad signatures silently — Apple has retried.
                }
            }
        }
    }

    // MARK: - Helpers

    /// Throws if Apple's signature on the transaction is invalid.
    /// Marked `nonisolated` so the background listener task can call it.
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }

    // MARK: - Share-your-win reward

    /// The Day Pass product when loaded (nil until StoreKit returns it).
    var dayPassProduct: Product? {
        products.first { $0.id == Self.dayPassProductId }
    }

    /// Grants 24h of Pro after the user shares a win card (server-side
    /// rail: claim_share_reward RPC → pro_grants; capped to one claim
    /// per 7 days there). Returns true when the grant landed.
    func claimShareReward() async -> Bool {
        struct Claim: Decodable { let ok: Bool }
        do {
            let res: Claim = try await SupabaseManager.client
                .rpc("claim_share_reward")
                .execute().value
            if res.ok { await refreshCompAccess() }
            return res.ok
        } catch {
            return false
        }
    }

    // MARK: - Display helpers

    /// "$14.99/wk" — formatted for the paywall toggle.
    static func displayPrice(_ product: Product) -> String {
        let unit: String
        switch product.subscription?.subscriptionPeriod.unit {
        case .day:   unit = "/day"
        case .week:  unit = "/wk"
        case .month: unit = "/mo"
        case .year:  unit = "/yr"
        default:     unit = ""
        }
        return "\(product.displayPrice)\(unit)"
    }
}
