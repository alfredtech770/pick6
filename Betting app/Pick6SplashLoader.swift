// Pick6SplashLoader.swift
// Splash screen — implements the design from `Pick6 Onboarding.html` Splash:
//   • Black canvas with a slow-pulsing lime radial glow
//   • 1px horizontal scanline grain overlay
//   • Center stack:  EST · 2026  /  PICK6 wordmark (84pt, "6" inside a lime
//     star)  /  PICKS · STATS · GLORY
//   • Bottom: ticker scrolling infinitely + 2pt loader bar 0→100% with
//     "LOADING PICKS…" caption

import SwiftUI

struct Pick6SplashLoader: View {
    @State private var glowPulse: Bool = false
    @State private var loaderProgress: Double = 0
    @State private var tickerOffset: CGFloat = 0
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Pulsing lime radial glow (matches `.splash-glow` 500×500 pulse 3s)
            RadialGradient(
                colors: [Color(hex: "#D4FF3A").opacity(glowPulse ? 0.18 : 0.10), .clear],
                center: UnitPoint(x: 0.4, y: 0.5),
                startRadius: 0,
                endRadius: 280
            )
            .blur(radius: 30)
            .ignoresSafeArea()

            // Horizontal scanline grain overlay
            ScanlineOverlay()
                .opacity(0.04)
                .ignoresSafeArea()

            // Center stack
            VStack(spacing: 18) {
                Text("EST · 2026")
                    .font(.mono(11, weight: .medium))
                    .tracking(3.3)
                    .foregroundColor(Color(hex: "#6E6F75"))

                Pick6Wordmark(size: 84)

                Text("PICKS · STATS · GLORY")
                    .font(.archivoNarrow(12, weight: .semibold))
                    .tracking(4.2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }
            .opacity(contentOpacity)

            // Bottom: ticker + loader stack
            VStack(spacing: 50) {
                Spacer()
                tickerStrip
                    .opacity(contentOpacity)
                loaderBar
                    .opacity(contentOpacity)
                    .padding(.bottom, 30)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1
            }
            // Slow glow pulse, ease-in-out, repeat forever
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            // Loader bar 0 → 1 over 2s, looping
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                loaderProgress = 1.0
            }
            // Ticker slow scroll left, 28s linear infinite
            withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                tickerOffset = -1
            }
        }
    }

    // MARK: Ticker

    private let tickerItems: [String] = [
        "NBA · LAKERS −2.5", "EPL · ARSENAL TO WIN", "MLB · DODGERS ML",
        "NFL · CHIEFS −3", "NHL · LIGHTNING ML", "UFC · MAIN CARD LIVE",
        "ATP · SINNER WIN", "F1 · MONACO GP",
    ]

    private var tickerStrip: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color(hex: "#22252B")).frame(height: 1)
            GeometryReader { geo in
                let w = geo.size.width
                let totalWidth = w * 2  // two copies for seamless loop
                HStack(spacing: 24) {
                    ForEach(0..<2, id: \.self) { _ in
                        ForEach(tickerItems, id: \.self) { item in
                            HStack(spacing: 24) {
                                Text(item)
                                    .font(.mono(10, weight: .bold))
                                    .tracking(2.4)
                                    .foregroundColor(Color(hex: "#6E6F75"))
                                Circle()
                                    .fill(Color(hex: "#D4FF3A"))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
                .offset(x: tickerOffset * (totalWidth / 2))
                .frame(height: 36)
            }
            .frame(height: 36)
            Rectangle().fill(Color(hex: "#22252B")).frame(height: 1)
        }
    }

    // MARK: Loader

    private var loaderBar: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(hex: "#16181C"))
                    Rectangle()
                        .fill(Color(hex: "#D4FF3A"))
                        .frame(width: geo.size.width * loaderProgress)
                        .shadow(color: Color(hex: "#D4FF3A").opacity(0.4), radius: 4)
                }
                .clipShape(Capsule())
            }
            .frame(height: 2)
            .padding(.horizontal, 60)

            Text("LOADING PICKS…")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.6)
                .foregroundColor(Color(hex: "#6E6F75"))
        }
    }
}

// MARK: - Pick1 wordmark (PICK + lime star with "1" inside)

struct Pick6Wordmark: View {
    let size: CGFloat

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: size * 0.04) {
            Text("PICK")
                .font(.anton(size))
                .tracking(-size * 0.012)
                .foregroundColor(Color(hex: "#F5F3EE"))

            ZStack {
                StarShape()
                    .fill(Color(hex: "#D4FF3A"))
                    .frame(width: size * 0.95, height: size * 0.95)
                    .shadow(color: Color(hex: "#D4FF3A").opacity(0.35), radius: 14)
                Text("1")
                    .font(.anton(size * 0.5))
                    .foregroundColor(Color(hex: "#0A0B0D"))
            }
            .offset(y: -size * 0.05)
        }
    }
}

/// Five-pointed star used inside the Pick1 wordmark.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        var path = Path()
        for i in 0..<10 {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(i) * .pi / 5 - .pi / 2
            let pt = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Scanline overlay

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let pitch: CGFloat = 2
                for y in stride(from: 0, through: size.height, by: pitch) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 0.5)
                }
            }
        }
        .blendMode(.overlay)
    }
}

#Preview {
    Pick6SplashLoader()
}
