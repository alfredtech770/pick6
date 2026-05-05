// Pick1SplashLoader.swift
// Splash screen — implements the design from `Pick6 Onboarding.html` Splash:
//   • Black canvas with a slow-pulsing lime radial glow
//   • 1px horizontal scanline grain overlay
//   • Center stack:  EST · 2026  /  PICK6 wordmark (84pt, "6" inside a lime
//     star)  /  PICKS · STATS · GLORY
//   • Bottom: ticker scrolling infinitely + 2pt loader bar 0→100% with
//     "LOADING PICKS…" caption

import SwiftUI

struct Pick1SplashLoader: View {
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

                Pick1Wordmark(size: 84)

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

// MARK: - Pick1 wordmark (PICK + rounded lime tile with "1" inside)
//
// Matches the canonical Pick1 Logo Kit (Pick1 Logo.html). The tile
// is a rounded square — NOT a star — sized ~1.05× the cap-height of
// "PICK" with a 0.235em corner radius and the digit weighted heavier
// (Anton Bold/700) so the "1" reads as a typographic monogram inside
// its own surface.
//
// Color variants in the spec (currently we render the canonical
// lime-on-dark variant). To support light/lime backdrops later, expose
// the three colors as parameters.

struct Pick1Wordmark: View {
    let size: CGFloat

    /// Color of the "PICK" wordmark.
    var textColor: Color = Color(hex: "#F4F4F5")
    /// Color of the rounded tile that holds "1".
    var tileColor: Color = Color(hex: "#D4FF3A")
    /// Color of the "1" digit inside the tile.
    var digitColor: Color = Color(hex: "#0A0B0D")

    /// Tile geometry per the spec:
    ///   width / height = 1.05em (slightly larger than cap height)
    ///   corner-radius  = 0.235em
    ///   "1" font-size  = 0.62em, padding-bottom 0.04em
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.05) {
            Text("PICK")
                .font(.anton(size))
                .tracking(-size * 0.01)
                .foregroundColor(textColor)

            // Rounded tile + digit — anchored to the cap-line so it
            // visually sits with the rest of the wordmark.
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.235,
                                 style: .continuous)
                    .fill(tileColor)
                    .shadow(color: tileColor.opacity(0.35), radius: size * 0.18)
                Text("1")
                    .font(.anton(size * 0.62))
                    .foregroundColor(digitColor)
                    .padding(.bottom, size * 0.04)
            }
            .frame(width: size * 1.05, height: size * 1.05)
            // Drop the tile slightly so its baseline aligns with PICK.
            .alignmentGuide(.firstTextBaseline) { d in
                d[VerticalAlignment.bottom] - size * 0.10
            }
        }
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
    Pick1SplashLoader()
}
