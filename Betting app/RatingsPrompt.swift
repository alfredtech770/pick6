// RatingsPrompt.swift
// Asks for an App Store rating at a *positive* moment — after the user has
// shown engagement and has a win to feel good about. Ratings drive store
// ranking and downloads, and there was no prompt at all before.
//
// Triple-gated so it can never nag:
//   • only when there's a positive signal (the user has winning picks)
//   • only after ≥3 app launches (engaged, not a first-run visitor)
//   • at most once per app version (we remember the version we asked on)
// Apple additionally caps system review prompts to ~3 per year.

import StoreKit
import UIKit

enum RatingsPrompt {
    private static let lastVersionKey = "pick1.lastRatedVersion"
    private static let launchCountKey = "pick1.launchCount"

    /// Bump on each cold launch (called from the app's launch task).
    static func incrementLaunch() {
        let n = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(n, forKey: launchCountKey)
    }

    @MainActor
    static func maybeRequest(hasPositiveSignal: Bool) {
        guard hasPositiveSignal else { return }
        guard UserDefaults.standard.integer(forKey: launchCountKey) >= 3 else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard UserDefaults.standard.string(forKey: lastVersionKey) != version else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        AppStore.requestReview(in: scene)
        UserDefaults.standard.set(version, forKey: lastVersionKey)
    }
}
