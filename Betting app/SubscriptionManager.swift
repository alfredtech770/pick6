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
// A 7-day free trial is configured as an "Introductory Offer" on the
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

    /// All Pick1 Pro product identifiers, in display order.
    /// These match the bundle identifier `com.pick1.app`. Configure both
    /// in App Store Connect → My App → Subscriptions → "Pick1 Pro" group.
    static let productIds: [String] = [
        "com.pick1.app.pro.weekly",
        "com.pick1.app.pro.monthly",
    ]

    // MARK: - Lifecycle

    private var transactionListenerTask: Task<Void, Never>?

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

    /// True only when both:
    ///   • The build is DEBUG (Xcode's automatic Debug configuration)
    ///   • The dedicated `PICK1_DEV_OVERRIDE` compilation flag is set
    ///     via xcconfig / OTHER_SWIFT_FLAGS for the developer's local
    ///     scheme. Neither alone is enough — this stops a stray DEBUG
    ///     leak in a Release build from granting free Pro.
    /// To enable for local dev, add to your scheme's "Run" settings:
    ///   OTHER_SWIFT_FLAGS = -D PICK1_DEV_OVERRIDE
    static var devOverrideActive: Bool {
        #if DEBUG && PICK1_DEV_OVERRIDE
        return true
        #else
        return false
        #endif
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    /// Call once on app launch (e.g. from `.task` on the root view).
    func bootstrap() async {
        await loadProducts()
        await refreshEntitlements()
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
                await transaction.finish()
                await refreshEntitlements()
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
        } catch {
            lastError = error.localizedDescription
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
                guard Self.productIds.contains(transaction.productID) else { continue }
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
        } else {
            self.isPro = false
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
