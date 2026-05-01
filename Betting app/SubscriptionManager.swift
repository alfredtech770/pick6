// SubscriptionManager.swift
// StoreKit 2 wrapper for Pick6 Pro.
//
// Drives the gate between Free and Pro:
//   • Free  → sees one pick per sport (the highest-confidence pick of the day)
//   • Pro   → sees every pick across every sport
//
// You'll need to create these products in App Store Connect under a single
// subscription group (e.g. "Pick6 Pro"):
//
//   Product ID                          Type                   Price
//   com.alfredtech770.pick6.pro.weekly  Auto-Renewable Weekly  $14.99
//   com.alfredtech770.pick6.pro.monthly Auto-Renewable Monthly $39.99
//
// Add a 7-day free trial as an "Introductory Offer" on the weekly product.
//
// Set the bundle identifier on the Xcode target to match
// (com.alfredtech770.pick6 or whatever you registered).
//
// For TestFlight + App Store, this works against the live StoreKit
// servers automatically — no extra config beyond App Store Connect.
//
// For local Xcode testing, add a StoreKit Configuration File:
//   File > New > File > StoreKit Configuration File → "Pick6.storekit"
//   Then in your scheme: Edit Scheme > Run > Options > StoreKit Configuration
//   = Pick6.storekit. That lets you test purchases without TestFlight.

import Foundation
import Combine
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

    // MARK: - Product IDs

    /// All Pick6 Pro product identifiers, in display order.
    /// These match the bundle identifier `com.pick6.app`. Configure both
    /// in App Store Connect → My App → Subscriptions → "Pick6 Pro" group.
    static let productIds: [String] = [
        "com.pick6.app.pro.weekly",
        "com.pick6.app.pro.monthly",
    ]

    // MARK: - Lifecycle

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        // Always start listening before checking entitlements so we don't
        // miss a purchase that completes mid-app-launch.
        transactionListenerTask = listenForTransactions()

        // In DEBUG, prime isPro=true on the very first paint so the
        // splash → home transition doesn't briefly flash the Free UI
        // before refreshEntitlements() reasserts the override. See
        // refreshEntitlements() for the canonical override.
        #if DEBUG
        self.isPro = true
        self.activeProductId = "com.pick6.app.pro.monthly"
        self.activeExpiration = Calendar.current.date(
            byAdding: .year, value: 10, to: Date()
        )
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
    /// Safe to call multiple times — silently no-ops on transient errors.
    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.productIds)
            // Sort weekly → monthly for stable display.
            self.products = fetched.sorted { lhs, rhs in
                Self.productIds.firstIndex(of: lhs.id) ?? 0 <
                Self.productIds.firstIndex(of: rhs.id) ?? 0
            }
        } catch {
            // No products is the same as no entitlement — Free tier is fine.
            print("Pick6 SubscriptionManager: loadProducts failed: \(error)")
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product. The native Apple sheet
    /// is presented automatically.
    func purchase(_ product: Product) async {
        purchasing = true
        defer { purchasing = false }
        lastError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()

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

        // ── DEBUG / SIMULATOR OVERRIDE ─────────────────────────────
        // Always grant Pro in debug builds so devs see the full app
        // without configuring a StoreKit configuration file or buying
        // a real subscription. Re-asserted on every refresh so the
        // listener can't silently downgrade us back to Free.
        // Compiled out of Release/TestFlight/App Store builds.
        #if DEBUG
        self.isPro = true
        if self.activeProductId == nil {
            self.activeProductId = "com.pick6.app.pro.monthly"
        }
        if self.activeExpiration == nil {
            // Far-future expiration so any "expires in N days" copy
            // doesn't render as "expired".
            self.activeExpiration = Calendar.current.date(
                byAdding: .year, value: 10, to: Date()
            )
        }
        #endif
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
