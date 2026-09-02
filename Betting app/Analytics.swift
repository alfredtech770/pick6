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
import UserNotifications
import PostHog
import Supabase
import FBSDKCoreKit
import AppTrackingTransparency

// MARK: - App-launch hook for the Meta SDK
// SwiftUI has no AppDelegate by default; this adaptor gives the Meta SDK the
// didFinishLaunching call it needs. PostHog is set up in Betting_appApp.init().
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
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
        // Own the notification center so we can (1) show pushes while the
        // app is foregrounded and (2) log the open + its A/B variant.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Notification tapped → log the open with its campaign + A/B variant
    /// (send-push stamps these into the payload's `data`).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        Analytics.notificationOpened(campaign: info["campaign"] as? String,
                                     variant: info["variant"] as? String)
        completionHandler()
    }

    /// Show banner + sound even when the app is in the foreground (so a
    /// win alert lands visibly while the user is in-app).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
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
    static func paywallViewed(source: String = "unknown") {
        track("paywall_viewed", ["source": source])
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
    static func trackSheetViewed(league: String, alreadyTracked: Bool) {
        track("track_sheet_viewed", ["league": league, "already_tracked": alreadyTracked])
    }
    static func pickTracked(league: String, sport: String, hasStake: Bool) {
        track("pick_tracked", ["league": league, "sport": sport, "has_stake": hasStake])
    }
    static func pickUntracked(league: String, sport: String) {
        track("pick_untracked", ["league": league, "sport": sport])
    }
    static func emptyStateAction(screen: String) {
        track("empty_state_action", ["screen": screen])
    }
    static func tabSelected(_ tab: String) {
        track("tab_selected", ["tab": tab])
    }
    static func notificationPermissionResult(granted: Bool, source: String) {
        track("notification_permission_result", ["granted": granted, "source": source])
    }
    // ── Share-your-win viral loop ─────────────────────────────────
    static func shareWinOpened(league: String) {
        track("share_win_opened", ["league": league])
    }
    static func shareWinCompleted(granted: Bool) {
        track("share_win_completed", ["reward_granted": granted])
    }
    // ── Share-your-streak viral loop ──────────────────────────────
    static func streakCardOpened(streak: Int) {
        track("streak_card_opened", ["streak": streak])
    }
    static func streakCardShared(streak: Int, granted: Bool) {
        track("streak_card_shared", ["streak": streak, "reward_granted": granted])
    }
    /// The gold MEMBERS WON MORE card on the free Latest Wins rail.
    static func memberCardTapped() {
        track("member_card_tapped")
    }

    static func trialStarted(productId: String) {
        track("trial_started", ["product": productId])
        AppEvents.shared.logEvent(.startTrial)
    }
    static func subscribed(amount: Double, currency: String, productId: String) {
        track("subscribed", ["product": productId, "amount": amount, "currency": currency])
        AppEvents.shared.logPurchase(amount: amount, currency: currency)
    }

    // ── Behavior (what drives engagement) ─────────────────────────
    /// A user filtered the board to a sport (or "all"). Shows which
    /// sports pull attention → what to invest model effort in.
    static func sportSelected(_ sport: String) {
        track("sport_selected", ["sport": sport])
    }
    static func favoriteToggled(_ on: Bool, league: String) {
        track("favorite_toggled", ["on": on, "league": league])
    }
    static func detailTabViewed(_ tab: String) {
        track("detail_tab_viewed", ["tab": tab])
    }
    static func dayPassPurchased() {
        track("day_pass_purchased")
    }
    static func languageChanged(_ code: String) {
        track("language_changed", ["language": code])
    }

    /// A notification was tapped open. `campaign` is the push key
    /// (pick_drop / free_recap / result_win …) and `variant` is the A/B
    /// arm (A/B) when the push was part of an experiment — this closes the
    /// loop on push OPEN rate + attributes the winning copy.
    static func notificationOpened(campaign: String?, variant: String?) {
        var props: [String: Any] = [:]
        if let campaign { props["campaign"] = campaign }
        if let variant { props["variant"] = variant }
        track("notification_opened", props)

        // Also record it in Postgres, next to the send.
        //
        // PostHog knows this already, but the SENDER cannot read PostHog, so
        // for a year push_log recorded that a notification left and nothing
        // about whether it landed. Measured on 2026-09-02, Pick1 was sending
        // 93,099 pushes a month with no way to say which key was worth
        // sending. `mark_push_opened` closes that: it matches the most recent
        // unopened send of this campaign to this user within a day, runs as
        // the caller's own session so nobody can mark someone else's, and is
        // the only thing that will ever fill push_log.opened_at.
        //
        // Fire and forget. A failed analytics write must never surface to
        // someone who just tapped a notification.
        guard let campaign, !campaign.isEmpty else { return }
        Task.detached(priority: .utility) {
            _ = try? await SupabaseManager.client
                .rpc("mark_push_opened", params: ["p_key": campaign])
                .execute()
        }
    }
}
