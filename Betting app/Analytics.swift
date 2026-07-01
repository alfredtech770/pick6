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
        // Auto-log the install/activation event + collect IDFA/IDFV so Meta can
        // attribute installs and optimize on value. ATT (requestATTIfNeeded)
        // gates whether the advertiser ID is actually usable for tracking.
        Settings.shared.isAutoLogAppEventsEnabled      = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        return true
    }

    // APNs token callbacks → PushManager persists the token per-user so the
    // send-push Edge Function can deliver per-game notifications.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.setDeviceToken(deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Best-effort — registration can fail (no network / simulator); the
        // app stays fully usable, we simply won't have a token this session.
    }

    // NOTE: applicationDidBecomeActive is NEVER called in SwiftUI
    // scene-based apps — UIKit routes lifecycle events to the scene, so
    // an ATT request placed here silently never fires (App Review
    // flagged exactly this on build 7: "unable to locate the App
    // Tracking Transparency permission request"). The request now lives
    // in Analytics.requestATTIfNeeded(), driven by scenePhase == .active
    // in Betting_appApp.
}

enum Analytics {
    // PostHog — public client key, US Cloud.
    private static let postHogKey  = "phc_yzgtib4eMMgg9dRGfujgECRiBrVhArkZMDAoLWMZk3Dv"
    private static let postHogHost = "https://us.i.posthog.com"
    // Meta — public App ID + Client Token (safe to ship).
    static let metaAppID       = "1750424039461325"
    static let metaClientToken = "e89e5a741c0d9b92f24a536d3632d33e"

    /// App Tracking Transparency — prompt once, then tell the Meta SDK
    /// whether advertiser tracking is allowed (sharpens ad attribution
    /// when granted; SKAdNetwork covers attribution when denied).
    /// Driven by scenePhase == .active (the SwiftUI-correct lifecycle
    /// hook); safe to call repeatedly.
    static func requestATTIfNeeded() {
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else {
            Settings.shared.isAdvertiserTrackingEnabled = (status == .authorized)
            return
        }
        // Small delay so the prompt lands after the first frame — an
        // immediate request during scene activation can be dropped.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ATTrackingManager.requestTrackingAuthorization { status in
                Settings.shared.isAdvertiserTrackingEnabled = (status == .authorized)
            }
        }
    }

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

    /// Fires the moment auth succeeds inside onboarding. Meta's
    /// CompleteRegistration belongs HERE (account creation) — not at the end
    /// of the funnel, which now sits past the paywall and would skew the ad
    /// funnel toward payers only.
    static func signupCompleted() {
        track("signup_completed")
        AppEvents.shared.logEvent(.completedRegistration)
    }

    /// End of the whole onboarding funnel (post-paywall). PostHog only —
    /// the Meta registration event already fired at signup.
    static func onboardingCompleted() {
        track("onboarding_completed")
    }
    static func paywallViewed() {
        track("paywall_viewed")
        // Meta: purchase-intent signal — a step above install, below trial.
        // Gives AEM another event to prioritize between registration and trial.
        AppEvents.shared.logEvent(.initiatedCheckout)
    }
    static func pickViewed(league: String) {
        track("pick_viewed", ["league": league])
        // Meta: engagement / content-view signal, tagged with the league so
        // Meta can see which sports drive the most activation.
        AppEvents.shared.logEvent(.viewedContent, parameters: [.contentType: league])
    }
    static func trialStarted(productId: String) {
        track("trial_started", ["product": productId])
        AppEvents.shared.logEvent(.startTrial)
    }
    static func subscribed(amount: Double, currency: String, productId: String) {
        track("subscribed", ["product": productId, "amount": amount, "currency": currency])
        AppEvents.shared.logPurchase(amount: amount, currency: currency)
    }
}
