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
    // Set once the user finishes the post-OTP onboarding flow
    // (PickSports → Notifications → Success). Until then, returning users
    // who close the app mid-flow resume from PickSports.
    @AppStorage("hasFinishedOnboarding") private var hasFinishedOnboarding = false
    @AppStorage("selectedSports") private var selectedSports = ""
    @State private var authManager = AuthManager()
    @StateObject private var subscriptions = SubscriptionManager()
    @StateObject private var favorites = FavoritesStore()

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingSession {
                    Pick1SplashLoader()
                        .preferredColorScheme(.dark)
                } else if !authManager.isAuthenticated || !hasFinishedOnboarding {
                    // The single source of truth for everything pre-main:
                    // welcome → value carousel → auth/OTP → sports → notifications → success.
                    Pick1AuthFlow(authManager: authManager) { sports in
                        selectedSports = sports.sorted().joined(separator: ",")
                        hasFinishedOnboarding = true
                    }
                } else {
                    Pick1HomeHiFi()
                        .preferredColorScheme(.dark)
                }
            }
            .environment(authManager)
            .environmentObject(subscriptions)
            .environmentObject(favorites)
            .task {
                await authManager.checkSession()
                await subscriptions.bootstrap()
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
