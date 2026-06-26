//
//  Betting_appApp.swift
//  Betting app
//
//  Created by Ethan on 3/9/26.
//

import SwiftUI
import CoreText

@main
struct Betting_appApp: App {
    // Meta SDK needs an app-launch hook (SwiftUI has none by default).
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Set once the user finishes the post-OTP onboarding flow
    // (PickSports → Notifications → Success). Until then, returning users
    // who close the app mid-flow resume from PickSports.
    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false
    @AppStorage("selectedSports") private var selectedSports = ""
    @State private var authManager = AuthManager()
    @StateObject private var subscriptions = SubscriptionManager()
    @StateObject private var favorites = FavoritesStore()

    /// SwiftUI scene lifecycle — drives the ATT permission request.
    /// applicationDidBecomeActive on the delegate adaptor never fires in
    /// scene-based apps, which is why build 7's prompt never appeared.
    @Environment(\.scenePhase) private var scenePhase

    /// Drives every t(...) lookup in the app. Picking a new language in
    /// Profile → Language mutates `languageCode` here, which propagates
    /// through @Environment(LocalizationManager.self) and triggers a
    /// view-tree re-render — no app restart needed.
    @State private var localization = LocalizationManager.shared

    init() {
        registerCustomFonts()
        // Enlarge the shared URL cache so team/athlete/league logos
        // persist and render instantly (no placeholder-badge flash).
        LogoPrefetch.bootCache()
        // Product analytics (PostHog) — funnel + retention.
        Analytics.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingSession {
                    Pick1SplashLoader()
                        .preferredColorScheme(.dark)
                } else if !authManager.isAuthenticated || !hasFinishedOnboarding {
                    // The single source of truth for everything pre-main:
                    // welcome → value carousel → auth/OTP → sports → notifications → success → paywall.
                    Pick1AuthFlow(authManager: authManager) { sports in
                        selectedSports = sports.sorted().joined(separator: ",")
                        hasFinishedOnboarding = true
                        Analytics.onboardingCompleted()
                    }
                } else {
                    Pick1HomeHiFi()
                        .preferredColorScheme(.dark)
                }
            }
            .environment(authManager)
            .environment(localization)
            .environmentObject(subscriptions)
            .environmentObject(favorites)
            // Flip the whole view tree to RTL when the user picks Arabic.
            // SwiftUI mirrors layout (HStack ordering, leading/trailing
            // edges, sheet animations) automatically once this is set.
            .environment(\.layoutDirection, localization.layoutDirection)
            .task {
                RatingsPrompt.incrementLaunch()
                await authManager.checkSession()
                await subscriptions.bootstrap()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Analytics.requestATTIfNeeded()
                    // Re-register for push on every activation (token can
                    // change) and re-upload if one was captured before the
                    // user signed in.
                    PushManager.shared.registerIfAuthorized()
                    PushManager.shared.uploadIfPending()
                    // Re-check comped Pro grants so a newly-granted (or
                    // just-signed-in) user unlocks without a full relaunch.
                    Task { await subscriptions.refreshCompAccess() }
                }
            }
        }
    }

    private func registerCustomFonts() {
        // The Anton / Archivo / ArchivoNarrow / JetBrainsMono families drive
        // the new Pick1 Home Hi-Fi design (Anton = display, Archivo = UI,
        // ArchivoNarrow = small-caps labels, JetBrainsMono = stats/numbers).
        // BarlowCondensed remains for legacy onboarding screens.
        let fontNames = [
            // Display
            "Anton-Regular",
            // UI sans
            "Archivo-Regular", "Archivo-Medium", "Archivo-SemiBold",
            "Archivo-Bold", "Archivo-ExtraBold", "Archivo-Black",
            // Narrow labels
            "ArchivoNarrow-Medium", "ArchivoNarrow-SemiBold", "ArchivoNarrow-Bold",
            // Stats / numbers
            "JetBrainsMono-Regular", "JetBrainsMono-Medium",
            "JetBrainsMono-Bold", "JetBrainsMono-ExtraBold",
            // Legacy onboarding
            "BarlowCondensed-Black", "BarlowCondensed-Bold", "BarlowCondensed-SemiBold",
        ]
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
