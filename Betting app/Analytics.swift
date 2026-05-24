//
//  Analytics.swift
//  Betting app
//
//  Unified funnel-event helper for Pick1 — fires to BOTH:
//    • PostHog   — product analytics (funnel + retention)
//    • Meta SDK  — the standard events Meta optimizes ads on
//                  (CompleteRegistration / StartTrial / Purchase-with-value)
//  One helper means call sites never change.
//
//  Packages (Xcode → Add Package): PostHog (posthog-ios) + Facebook (facebook-ios-sdk).
//  Both keys/tokens below are PUBLIC client credentials — designed to ship in
//  the binary (write-only ingestion; they cannot read or delete data).
//

import Foundation
import UIKit
import PostHog
import FBSDKCoreKit
import AppTrackingTransparency

// MARK: - App-launch hook for the Meta SDK
// SwiftUI has no AppDelegate by default; this adaptor gives the Meta SDK the
// didFinishLaunching call it needs. PostHog is set up in Betting_appApp.init().
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Settings.shared.appID       = Analytics.metaAppID
        Settings.shared.clientToken = Analytics.metaClientToken
        Settings.shared.displayName = "Pick1"
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        return true
    }

    // App Tracking Transparency — prompt once, then tell the Meta SDK whether
    // advertiser tracking is allowed (sharpens iOS ad attribution when granted).
    func applicationDidBecomeActive(_ application: UIApplication) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            Settings.shared.isAdvertiserTrackingEnabled =
                (ATTrackingManager.trackingAuthorizationStatus == .authorized)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ATTrackingManager.requestTrackingAuthorization { status in
                Settings.shared.isAdvertiserTrackingEnabled = (status == .authorized)
            }
        }
    }
}

enum Analytics {
    // PostHog — public client key, US Cloud.
    private static let postHogKey  = "phc_yzgtib4eMMgg9dRGfujgECRiBrVhArkZMDAoLWMZk3Dv"
    private static let postHogHost = "https://us.i.posthog.com"
    // Meta — public App ID + Client Token (safe to ship).
    static let metaAppID       = "1750424039461325"
    static let metaClientToken = "e89e5a741c0d9b92f24a536d3632d33e"

    /// Call once at launch — from Betting_appApp.init(). (Meta init runs in AppDelegate.)
    static func bootstrap() {
        let config = PostHogConfig(apiKey: postHogKey, host: postHogHost)
        config.captureScreenViews = true   // auto screen-view tracking
        PostHogSDK.shared.setup(config)
    }

    /// Generic event → PostHog.
    static func track(_ event: String, _ props: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event, properties: props)
    }

    /// Tie subsequent events to the signed-in user (Supabase user id — no PII).
    static func identify(_ userId: String) { PostHogSDK.shared.identify(userId) }
    /// Call on sign-out.
    static func reset() { PostHogSDK.shared.reset() }

    // MARK: - Funnel events (PostHog + Meta standard event)
    static func onboardingCompleted() {
        track("onboarding_completed")
        AppEvents.shared.logEvent(.completedRegistration)
    }
    static func paywallViewed() { track("paywall_viewed") }
    static func pickViewed(league: String) { track("pick_viewed", ["league": league]) }
    static func trialStarted(productId: String) {
        track("trial_started", ["product": productId])
        AppEvents.shared.logEvent(.startTrial)
    }
    static func subscribed(amount: Double, currency: String, productId: String) {
        track("subscribed", ["product": productId, "amount": amount, "currency": currency])
        AppEvents.shared.logPurchase(amount: amount, currency: currency)
    }
}
