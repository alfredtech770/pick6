// Pick6Components.swift
// Reusable UI components shared across onboarding screens.

import SwiftUI

// MARK: - Top Nav Bar

struct Pick6NavBar: View {
    let canGoBack: Bool
    let progress: Double // 0–1
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                // Back button
                if canGoBack {
                    Button(action: onBack) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                                .frame(width: 34, height: 34)
                            Image(systemName: "arrow.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }
                } else {
                    Spacer().frame(width: 34)
                }

                Spacer()

                // Logo
                VStack(spacing: 2) {
                    HStack(spacing: 0) {
                        Text("PICK")
                            .font(.custom("BarlowCondensed-Black", size: 32))
                            .foregroundColor(.white)
                            .kerning(5)
                        Text("6")
                            .font(.custom("BarlowCondensed-Black", size: 32))
                            .foregroundColor(.p6Green)
                            .kerning(5)
                    }
                    Text("AI Sports Predictions")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.28))
                        .kerning(0.5)
                }

                Spacer()
                Spacer().frame(width: 34)
            }
            .padding(.horizontal, 20)

            // Progress bar
            if progress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient.pick6Brand)
                            .frame(width: geo.size.width * progress)
                            .animation(.spring(response: 0.55, dampingFraction: 0.82), value: progress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Primary Gradient Button

struct P6Button: View {
    let label: String
    let gradient: LinearGradient?
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    init(_ label: String, gradient: LinearGradient? = nil, disabled: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.gradient = gradient
        self.isDisabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: { if !isDisabled { action() } }) {
            Text(label)
                .font(.custom("BarlowCondensed-Black", size: 15))
                .kerning(2.5)
                .textCase(.uppercase)
                .foregroundColor(isDisabled ? Color.white.opacity(0.3) : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background {
                    if isDisabled {
                        Color.white.opacity(0.1)
                    } else if let g = gradient {
                        g
                    } else {
                        LinearGradient.pick6Brand
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .scaleEffect(isPressed && !isDisabled ? 0.97 : 1.0)
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
        ._onButtonGesture { pressing in
            withAnimation(.easeInOut(duration: 0.12)) { isPressed = pressing }
        } perform: {}
    }
}

// MARK: - Step Dots Indicator

struct StepDots: View {
    let current: Int  // 0-indexed
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? color : Color.white.opacity(0.15))
                    .frame(width: i == current ? 20 : 8, height: 3)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
            }
        }
    }
}

// MARK: - Screen Section Title

struct SectionHeading: View {
    let line1: String
    let line2: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(line1)
                .font(.custom("BarlowCondensed-Black", size: 42))
                .kerning(-1.5)
                .foregroundColor(.white)
                .textCase(.uppercase)
                .lineLimit(1)
            Text(line2)
                .font(.custom("BarlowCondensed-Black", size: 42))
                .kerning(-1.5)
                .foregroundColor(Color.white.opacity(0.18))
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Live Badge (renamed to avoid conflict with MatchStatus.swift)

struct P6LiveBadge: View {
    let label: String
    let color: Color

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .opacity(pulse ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(), value: pulse)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .kerning(0.3)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(color.opacity(0.14))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.4), lineWidth: 1))
        .clipShape(Capsule())
        .onAppear { pulse = true }
    }
}

// MARK: - Stat Chip (red variant)

struct StatChipRed: View {
    let number: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Text(number)
                .font(.custom("BarlowCondensed-Black", size: 26))
                .kerning(-0.5)
                .foregroundColor(Color(hex: "#ff5252"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(hex: "#ff9999").opacity(0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 8)
        .background(Color.p6Red.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.p6Red.opacity(0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Green Feature Row

struct GreenFeatureCard: View {
    let icon: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(icon)
                .font(.system(size: 26))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("BarlowCondensed-Black", size: 18))
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                Text(bodyText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color(hex: "#b4ffb4").opacity(0.75))
                    .lineSpacing(3)
            }

            Spacer()

            Rectangle()
                .fill(Color.p6Green)
                .frame(width: 4)
                .cornerRadius(2)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color.p6Green.opacity(0.09), Color(hex: "#14532D").opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.p6Green.opacity(0.32), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let name: String
    let text: String
    let sport: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(color.opacity(0.25))
                        .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 1.5))
                    Text(String(name.prefix(1)))
                        .font(.custom("BarlowCondensed-Black", size: 14))
                        .foregroundColor(.white)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.custom("BarlowCondensed-Black", size: 13))
                        .foregroundColor(.white)
                    Text(sport)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.38))
                }
                Spacer()
                Text("\u{2605}\u{2605}\u{2605}\u{2605}\u{2605}")
                    .font(.system(size: 12))
                    .foregroundColor(.p6Green)
            }
            Text("\"\(text)\"")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(hex: "#c8ffc8").opacity(0.72))
                .lineSpacing(3)
        }
        .padding(13)
        .background(Color.p6Green.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.p6Green.opacity(0.28), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
