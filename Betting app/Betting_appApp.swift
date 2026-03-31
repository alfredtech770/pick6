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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("hasEverLoggedIn") private var hasEverLoggedIn = false
    @AppStorage("hasSeenPaywall") private var hasSeenPaywall = false
    @State private var authManager = AuthManager()

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingSession {
                    // Hold on a dark splash while Keychain session is restored
                    ZStack {
                        Color(hex: "#151517").ignoresSafeArea()
                        HStack(spacing: 0) {
                            Text("PICK")
                                .font(.custom("BarlowCondensed-Black", size: 38))
                                .foregroundColor(.white)
                            Text("6")
                                .font(.custom("BarlowCondensed-Black", size: 38))
                                .foregroundColor(Color(hex: "#22C55E"))
                        }
                    }
                    .preferredColorScheme(.dark)
                } else if !hasCompletedOnboarding {
                    Pick6OnboardingView { _ in
                        hasCompletedOnboarding = true
                    }
                } else if !authManager.isAuthenticated && !hasEverLoggedIn {
                    // Only show auth if the user has NEVER logged in before
                    AuthView(authManager: authManager)
                } else if !authManager.isProfileComplete && !hasEverLoggedIn {
                    ProfileSetupView(authManager: authManager)
                } else if !hasSeenPaywall && !hasEverLoggedIn {
                    // Show paywall after account creation, before main app
                    P6PaywallScreen { plan in
                        UserDefaults.standard.set(plan, forKey: "selectedPlan")
                        hasSeenPaywall = true
                        hasEverLoggedIn = true
                    }
                } else {
                    // User has logged in before — go straight to main view
                    // Session refreshes in the background via auth listener
                    Pick6MainView()
                        .preferredColorScheme(.dark)
                }
            }
            .environment(authManager)
            .task {
                await authManager.checkSession()
                // Remember once the user is fully authenticated + profile done
                if authManager.isAuthenticated && authManager.isProfileComplete {
                    hasEverLoggedIn = true
                }
            }
        }
    }

    private func registerCustomFonts() {
        let fontNames = ["BarlowCondensed-Black", "BarlowCondensed-Bold", "BarlowCondensed-SemiBold"]
        for name in fontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
