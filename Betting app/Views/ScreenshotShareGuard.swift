// ScreenshotShareGuard.swift
// Anti-sharing + viral growth: when a user screenshots the app, the real
// picks are blanked out of the captured image (secure-entry trick) and a
// branded "go get your own Pick1" promo shows instead — so a screenshot
// sent to a friend markets the subscription rather than leaking the picks.
// Also pops a quick in-app reaction the moment a screenshot is detected.

import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// MARK: - The promo that ends up IN the screenshot
// ════════════════════════════════════════════════════════════════

struct ScreenshotPromoView: View {
    private let lime = Color(hex: "#D4FF3A")

    var body: some View {
        ZStack {
            Color(hex: "#07080A").ignoresSafeArea()
            RadialGradient(colors: [lime.opacity(0.16), .clear],
                           center: .center, startRadius: 0, endRadius: 320)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                Pick1Wordmark(size: 64)
                Image(systemName: "lock.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(lime)
                Text("NICE TRY 📸")
                    .font(.anton(34))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text("The picks are for members only.\nYour friend's gotta get their own.")
                    .font(.archivo(15, weight: .medium))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Text("GET PICK1 PRO")
                    .font(.archivoNarrow(14, weight: .heavy)).tracking(2)
                    .foregroundColor(Color(hex: "#0A0B0D"))
                    .padding(.horizontal, 26).padding(.vertical, 13)
                    .background(Capsule().fill(lime))
                Text("AI picks across every sport · 56% accuracy")
                    .font(.archivo(12, weight: .regular))
                    .foregroundColor(Color(hex: "#6E6F75"))
                Spacer()
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Guard modifier — promo behind, real content blanked in capture
// ════════════════════════════════════════════════════════════════

extension View {
    /// Wrap a screen so a screenshot of it captures the Pick1 promo
    /// instead of the real content. On-device the user sees the real
    /// content; in any screen capture the content blanks and the promo
    /// behind it shows through.
    func shareGuarded(_ enabled: Bool = true) -> some View {
        modifier(ShareGuardModifier(enabled: enabled))
    }
}

private struct ShareGuardModifier: ViewModifier {
    let enabled: Bool
    @State private var flash = false

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else {
            ZStack {
                // Seen ONLY in captures (the protected content blanks).
                ScreenshotPromoView()
                // Real content — omitted from screen captures.
                content.screenshotProtected(true)

                // Brief on-device reaction so the user knows it was caught.
                if flash {
                    Color.black.opacity(0.55).ignoresSafeArea()
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(Color(hex: "#D4FF3A"))
                        Text("Screenshot blocked 😏")
                            .font(.archivo(15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Share Pick1 with friends instead — they get their own.")
                            .font(.archivo(12))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .transition(.opacity)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                Haptics.tap()
                withAnimation(.easeOut(duration: 0.2)) { flash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeOut(duration: 0.3)) { flash = false }
                }
            }
        }
    }
}
