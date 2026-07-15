// OBComponents.swift
// Shared onboarding-style UI primitives (top bar, CTA button, sticky bar,
// kicker pill, editorial title, OTP box). These outlived the legacy
// Pick1AuthFlow that first defined them — AuthView and Pick1Paywall still
// use them — so they were extracted here when the dead flow was removed.

import SwiftUI

/// Top bar with optional back button, step dots, and skip — matches the design's `.ob-top`.
struct OBTopBar: View {
    var canGoBack: Bool = false
    var step: Int = 0
    var total: Int = 0
    var canSkip: Bool = false
    var onBack: (() -> Void)? = nil
    var onSkip: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center) {
            if canGoBack, let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.p1Foreground)
                        .frame(width: 36, height: 36)
                        .background(Color.p1Panel.opacity(0.7))
                        .overlay(Circle().stroke(Color.p1Line, lineWidth: 1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            Spacer()

            if total > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<total, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.p1Lime
                                  : (i < step ? Color.p1Ink2 : Color.p1Line2))
                            .frame(width: i == step ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: step)
                    }
                }
            }

            Spacer()

            if canSkip, let onSkip {
                Button(action: onSkip) {
                    Text(t(.action_skip))
                        .font(.custom("BarlowCondensed-Bold", size: 12))
                        .kerning(2.4)
                        .foregroundColor(.p1Mute)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 18)
    }
}

/// Lime CTA button — matches the design's `.ob-cta`.
struct OBPrimaryButton: View {
    let label: String
    var disabled: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            Text(label)
                .font(.custom("BarlowCondensed-Black", size: 15))
                .kerning(2.8)
                .textCase(.uppercase)
                .foregroundColor(disabled ? .p1Mute : .p1LimeInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(disabled ? Color.p1Panel2 : Color.p1Lime)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .scaleEffect(pressed && !disabled ? 0.98 : 1.0)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
        ._onButtonGesture { pressing in
            withAnimation(.easeInOut(duration: 0.12)) { pressed = pressing }
        } perform: {}
    }
}

/// Sticky bottom bar with gradient fade — matches `.ob-stickybar`.
struct OBStickyBar<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [Color.p1Ink.opacity(0), Color.p1Ink.opacity(0.92), Color.p1Ink],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }
}

/// "ACCOUNT · STEP 1 OF 3" pill — matches `.ob-kicker`.
struct OBKicker: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.custom("BarlowCondensed-Bold", size: 11))
            .kerning(2.4)
            .foregroundColor(.p1Lime)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.p1Lime.opacity(0.12))
            .overlay(
                Capsule().stroke(Color.p1Lime.opacity(0.3), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

/// Big editorial heading — line1 always white. Line 2 is `line2Lead`
/// (white) + optional `line2Emphasis` (lime). Pass emphasis = "" for an
/// all-white headline. Mirrors the design's `<em>` accent on `.ob-title`.
struct OBTitle: View {
    let line1: String
    let line2Lead: String
    var line2Emphasis: String = ""
    var size: CGFloat = 56

    init(_ line1: String, _ line2Lead: String, emphasis: String = "", size: CGFloat = 56) {
        self.line1 = line1
        self.line2Lead = line2Lead
        self.line2Emphasis = emphasis
        self.size = size
    }

    var body: some View {
        // Negative VStack spacing tightens the gap between the two stacked
        // Text views so the result reads like the design's `line-height: 0.88`.
        VStack(alignment: .leading, spacing: -(size * 0.20)) {
            Text(line1)
                .font(.custom("BarlowCondensed-Black", size: size))
                .kerning(-0.5)
                .foregroundColor(.p1Foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if !line2Lead.isEmpty {
                    Text(line2Lead)
                        .foregroundColor(.p1Foreground)
                }
                if !line2Emphasis.isEmpty {
                    Text(line2Emphasis)
                        .foregroundColor(.p1Lime)
                }
            }
            .font(.custom("BarlowCondensed-Black", size: size))
            .kerning(-0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }
}

/// Single-digit input box used by `AuthView`'s OTP screen.
/// Hidden TextField captures the keystroke; visible `Text` renders it.
struct OTPBox: View {
    @Binding var digit: String
    let isFocused: Bool
    let onFilled: () -> Void
    let onBackspace: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.p1Panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused ? Color.p1Lime
                                      : (digit.isEmpty ? Color.p1Line : Color.p1Ink2),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .shadow(color: isFocused ? Color.p1Lime.opacity(0.18) : .clear, radius: 8)

            if digit.isEmpty && isFocused {
                Rectangle()
                    .fill(Color.p1Lime)
                    .frame(width: 2, height: 28)
                    .cornerRadius(1)
                    .opacity(isFocused ? 1 : 0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(), value: isFocused)
            } else {
                Text(digit)
                    .font(.custom("BarlowCondensed-Black", size: 28))
                    .foregroundColor(.p1Foreground)
                    .transition(.scale.combined(with: .opacity))
            }

            TextField("", text: Binding(
                get: { digit },
                set: { val in
                    let filtered = val.filter(\.isNumber).prefix(1)
                    if filtered.isEmpty && val.isEmpty && !digit.isEmpty {
                        digit = ""; onBackspace()
                    } else if let c = filtered.last {
                        digit = String(c); onFilled()
                    }
                }
            ))
            .keyboardType(.numberPad)
            .opacity(0.001)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 48, height: 58)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: digit)
    }
}
