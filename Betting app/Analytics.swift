//
//  Analytics.swift
//  Betting app
//
//  Single funnel-event helper for Pick1. Today it fires to PostHog
//  (product analytics: onboarding → paywall → trial → subscribe + retention).
//
//  The Meta SDK standard events (CompleteRegistration / StartTrial / Purchase
//  with value) get layered into these same functions later — once the Meta app
//  + facebook-ios-sdk package exist. See launch/META_SDK_SETUP.md. Keeping one
//  helper means call sites never change when Meta is added.
//
//  Setup: Xcode → Add Package → https://github.com/PostHog/posthog-ios
//  (add `PostHog` to the "Betting app" target). The Project API Key below is
//  PostHog's PUBLIC client key — safe to ship in the binary (write-only
//  ingestion; it cannot read or delete data).
//

import Foundation
import PostHog

enum Analytics {
    private static let postHogKey  = "phc_yzgtib4eMMgg9dRGfujgECRiBrVhArkZMDAoLWMZk3Dv"
    private static let postHogHost = "https://us.i.posthog.com"   // US Cloud

    /// Call once at launch — from Betting_appApp.init().
    static func bootstrap() {
        let config = PostHogConfig(apiKey: postHogKey, host: postHogHost)
        config.captureScreenViews = true   // auto screen-view tracking
        PostHogSDK.shared.setup(config)
    }

    /// Generic event.
    static func track(_ event: String, _ props: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event, properties: props)
    }

    /// Tie subsequent events to the signed-in user (Supabase user id — no PII).
    static func identify(_ userId: String) { PostHogSDK.shared.identify(userId) }
    /// Call on sign-out.
    static func reset() { PostHogSDK.shared.reset() }

    // MARK: - Funnel events
    static func onboardingCompleted() { track("onboarding_completed") }
    static func paywallViewed()       { track("paywall_viewed") }
    static func pickViewed(league: String) { track("pick_viewed", ["league": league]) }
    static func trialStarted(productId: String) { track("trial_started", ["product": productId]) }
    static func subscribed(amount: Double, currency: String, productId: String) {
        track("subscribed", ["product": productId, "amount": amount, "currency": currency])
    }
}
