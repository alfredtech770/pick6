//
//  Pick6SplashLoader.swift
//  Betting app
//
//  Created by Ethan on 4/1/26.
//

import SwiftUI

struct Pick6SplashLoader: View {

    // ── Animation state ──
    @State private var ring1Scale: CGFloat = 0.3
    @State private var ring2Scale: CGFloat = 0.3
    @State private var ring3Scale: CGFloat = 0.3
    @State private var ring1Opacity: Double = 0
    @State private var ring2Opacity: Double = 0
    @State private var ring3Opacity: Double = 0
    @State private var orbitAngle: Double = 0
    @State private var logoScale: CGFloat = 0.4
    @State private var logoOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    private let green = Color(hex: "#22C55E")

    // Sport icons orbiting
    private let sportIcons: [(symbol: String, color: Color, offset: Double)] = [
        ("sportscourt.fill",      Color(hex: "#22C55E"), 0),         // tennis/general
        ("figure.basketball",     Color(hex: "#FF6B35"), 0.167),     // basketball
        ("soccerball",            Color(hex: "#4E9A41"), 0.333),     // soccer
        ("car.fill",              Color(hex: "#E8002D"), 0.5),       // F1
        ("football.fill",         Color(hex: "#8B4513"), 0.667),     // NFL
        ("tennisball.fill",       Color(hex: "#C5E84D"), 0.833),     // tennis
    ]

    var body: some View {
        ZStack {
            // Background
            Color(hex: "#0D0D0F").ignoresSafeArea()

            // Subtle radial glow behind everything
            RadialGradient(
                colors: [green.opacity(glowOpacity * 0.12), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 200
            )

            // ── Pulse rings ──
            ZStack {
                // Ring 3 (outermost)
                Circle()
                    .stroke(green.opacity(0.08), lineWidth: 1.5)
                    .frame(width: 260, height: 260)
                    .scaleEffect(ring3Scale)
                    .opacity(ring3Opacity)

                // Ring 2
                Circle()
                    .stroke(green.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 190, height: 190)
                    .scaleEffect(ring2Scale)
                    .opacity(ring2Opacity)

                // Ring 1 (innermost)
                Circle()
                    .stroke(green.opacity(0.25), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(ring1Scale)
                    .opacity(ring1Opacity)

                // ── Orbiting sport icons ──
                ForEach(0..<sportIcons.count, id: \.self) { i in
                    let icon = sportIcons[i]
                    let angle = Angle.degrees(orbitAngle + icon.offset * 360)
                    let radius: CGFloat = 115

                    Image(systemName: icon.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(icon.color.opacity(0.7))
                        .offset(
                            x: radius * CGFloat(cos(angle.radians)),
                            y: radius * CGFloat(sin(angle.radians))
                        )
                        .opacity(ring3Opacity)
                }

                // ── Center logo ──
                VStack(spacing: 4) {
                    // Glow circle behind logo
                    ZStack {
                        Circle()
                            .fill(green.opacity(glowOpacity * 0.08))
                            .frame(width: 90, height: 90)
                            .blur(radius: 20)

                        HStack(spacing: 0) {
                            Text("PICK")
                                .font(.custom("BarlowCondensed-Black", size: 42))
                                .foregroundColor(.white)
                            Text("6")
                                .font(.custom("BarlowCondensed-Black", size: 42))
                                .foregroundColor(green)
                        }
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // ── Subtitle ──
                VStack {
                    Spacer().frame(height: 70)
                    Text("SPORTS PREDICTIONS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundColor(.white.opacity(0.25))
                        .opacity(subtitleOpacity)
                }
            }

            // ── Bottom loading dots ──
            VStack {
                Spacer()
                LoadingDots(color: green)
                    .opacity(ring1Opacity)
                    .padding(.bottom, 80)
            }
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Ring 1 — expand and pulse
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
            ring1Scale = 1.0
            ring1Opacity = 1.0
        }

        // Ring 2 — expand with slight delay
        withAnimation(.spring(response: 0.7, dampingFraction: 0.60).delay(0.25)) {
            ring2Scale = 1.0
            ring2Opacity = 1.0
        }

        // Ring 3 — expand last
        withAnimation(.spring(response: 0.8, dampingFraction: 0.55).delay(0.4)) {
            ring3Scale = 1.0
            ring3Opacity = 1.0
        }

        // Logo — spring in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Glow pulse
        withAnimation(.easeInOut(duration: 1.2).delay(0.5)) {
            glowOpacity = 1.0
        }

        // Subtitle fade
        withAnimation(.easeIn(duration: 0.6).delay(0.7)) {
            subtitleOpacity = 1.0
        }

        // Orbiting icons — continuous rotation
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            orbitAngle = 360
        }

        // Pulsing rings — continuous
        pulseRings()
    }

    private func pulseRings() {
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(1.0)) {
            ring1Scale = 1.06
            ring2Scale = 1.04
            ring3Scale = 1.03
        }
    }
}

// ── Animated loading dots ──
private struct LoadingDots: View {
    let color: Color
    @State private var dot1: CGFloat = 0.3
    @State private var dot2: CGFloat = 0.3
    @State private var dot3: CGFloat = 0.3

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6).opacity(dot1)
            Circle().fill(color).frame(width: 6, height: 6).opacity(dot2)
            Circle().fill(color).frame(width: 6, height: 6).opacity(dot3)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                dot1 = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.15)) {
                dot2 = 1.0
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.3)) {
                dot3 = 1.0
            }
        }
    }
}

#Preview {
    Pick6SplashLoader()
}
