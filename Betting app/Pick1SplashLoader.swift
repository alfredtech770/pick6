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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var glow = false
    @State private var step = 0

    /// What the app is actually doing while this shows, in order.
    private let steps = ["Loading today's games", "Reading live scores", "Matching PICK1 calls"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.p1Lime.opacity(glow ? 0.16 : 0.08), .clear],
                           center: UnitPoint(x: 0.5, y: 0.36), startRadius: 0, endRadius: 300)
                .blur(radius: 24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                Pick1Wordmark(size: 64)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)
                Text("Every game. Every call. Graded in public.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(P1Board.secondary)
                    .padding(.top, 18)
                    .opacity(appeared ? 1 : 0)
                Spacer()
                // A preview of the board that is on its way.
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { i in
                        P1SkeletonGameCard().opacity(1 - Double(i) * 0.28)
                    }
                }
                .padding(.horizontal, 16)
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                .frame(height: 300, alignment: .top)
                .clipped()
                .padding(.bottom, 14)
                .opacity(appeared ? 1 : 0)
                HStack(spacing: 8) {
                    ProgressView().tint(Color.p1Lime).scaleEffect(0.8)
                    Text(steps[step])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .contentTransition(.opacity)
                        .id(step)
                }
                .padding(.bottom, 34)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PICK1 is loading today's games")
        .task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.8)) { appeared = true }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
            }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(1100)) } catch { return }
                withAnimation(.easeInOut(duration: 0.25)) { step = (step + 1) % steps.count }
            }
        }
    }
}

/// A game card in the shape of P1GameListRow, shimmering while data loads.
struct P1SkeletonGameCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false
    private let fill = Color.white.opacity(0.07)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 10) {
                            Circle().fill(fill).frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 5) {
                                Capsule().fill(fill).frame(width: 96, height: 11)
                                Capsule().fill(fill).frame(width: 34, height: 8)
                            }
                            Spacer()
                            Capsule().fill(fill).frame(width: 22, height: 16)
                        }
                    }
                }
                Rectangle().fill(P1Board.rule).frame(width: 1).padding(.horizontal, 14)
                VStack(alignment: .leading, spacing: 7) {
                    Capsule().fill(fill).frame(width: 62, height: 9)
                    Capsule().fill(fill).frame(width: 48, height: 12)
                }.frame(width: 82, alignment: .leading)
            }
            .padding(.horizontal, 16).padding(.top, 15).padding(.bottom, 13)
            P1DashedRule().padding(.horizontal, 16)
            HStack { Capsule().fill(fill).frame(width: 170, height: 9); Spacer() }
                .padding(.horizontal, 16).frame(height: 40)
        }
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
        .overlay {
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.06), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: sweep ? geo.size.width : -geo.size.width * 0.6)
            }
            .clipShape(RoundedRectangle(cornerRadius: P1Board.radius))
            .opacity(reduceMotion ? 0 : 1)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { sweep = true }
        }
        .accessibilityHidden(true)
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
    var tileColor: Color = Color(hex: "#C6FF34")
    /// Color of the "1" digit inside the tile.
    var digitColor: Color = Color(hex: "#171717")

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
