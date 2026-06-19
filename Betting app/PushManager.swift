//
//  PushManager.swift
//  Betting app
//
//  Captures the APNs device token and persists it (per signed-in user) into
//  the `device_tokens` table, so the `send-push` Edge Function can deliver
//  per-game notifications (new picks, score changes, results).
//
//  Flow:
//    • registerIfAuthorized() — call on launch / after the onboarding
//      permission prompt. If notifications are authorized it asks iOS for a
//      token via registerForRemoteNotifications().
//    • AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken → setDeviceToken
//    • upload() persists the token whenever we have BOTH a token and a session
//      (the token can arrive before sign-in, or the user can sign in later).
//
import UIKit
import Supabase

@MainActor
final class PushManager {
    static let shared = PushManager()
    private init() {}

    private var pendingToken: String?

    /// Ask iOS for an APNs token, but only if the user has granted permission.
    func registerIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            default:
                break
            }
        }
    }

    /// Called by AppDelegate when APNs returns the device token.
    func setDeviceToken(_ data: Data) {
        pendingToken = data.map { String(format: "%02x", $0) }.joined()
        Task { await upload() }
    }

    /// Best-effort: re-attempt the upload (e.g. after the user signs in, when
    /// a token was already captured during onboarding).
    func uploadIfPending() {
        guard pendingToken != nil else { return }
        Task { await upload() }
    }

    private struct TokenRow: Encodable {
        let token: String
        let user_id: String
        let environment: String
        let platform: String
        let app_version: String?
        /// The user's chosen app language ("en"/"fr"/"es"/…), so the
        /// send-push function can localize every notification server-side.
        let locale: String
    }

    private func upload() async {
        guard let token = pendingToken,
              let userId = SupabaseManager.client.auth.currentSession?.user.id
        else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        do {
            try await SupabaseManager.client
                .from("device_tokens")
                .upsert(
                    TokenRow(token: token,
                             user_id: userId.uuidString,
                             environment: environment,
                             platform: "ios",
                             app_version: version,
                             locale: LocalizationManager.shared.languageCode),
                    onConflict: "token"
                )
                .execute()
        } catch {
            // Best-effort — a failed token upload must never disrupt the app.
        }
    }
}
