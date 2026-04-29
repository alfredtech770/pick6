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

    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isCheckingSession {
                    Pick6SplashLoader()
                        .preferredColorScheme(.dark)
                } else if !authManager.isAuthenticated || !hasFinishedOnboarding {
                    // The single source of truth for everything pre-main:
                    // welcome → value carousel → auth/OTP → sports → notifications → success.
                    Pick6AuthFlow(authManager: authManager) { sports in
                        selectedSports = sports.sorted().joined(separator: ",")
                        hasFinishedOnboarding = true
                    }
                } else {
                    Pick6MainView()
                        .preferredColorScheme(.dark)
                }
            }
            .environment(authManager)
            .task {
                await authManager.checkSession()
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
