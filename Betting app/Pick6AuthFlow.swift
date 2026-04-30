// Pick6AuthFlow.swift
// Coordinator + screens for the Pick6 onboarding flow.
// Implements the design from `Pick6 Onboarding.html`:
//   Welcome → Value Carousel (4) → Auth → OTP → Pick Sports → Notifications → Success → Paywall
//
// The Paywall step matches `Pick6 Account Pages.html` (Pro · All-Access).

import SwiftUI
import UserNotifications

// MARK: - Step model

private enum AuthFlowStep: Equatable {
    case welcome
    case value(Int)        // 0...3
    case auth              // delegates to AuthView (signup/signin + OTP)
    case pickSports
    case notifications
    case success
    case paywall

    var hasBack: Bool {
        switch self {
        case .welcome, .auth, .success: return false
        case .value(let i): return i > 0
        case .pickSports, .notifications, .paywall: return true
        }
    }
}

// MARK: - Coordinator

struct Pick6AuthFlow: View {
    @Bindable var authManager: AuthManager
    let onComplete: (Set<String>) -> Void

    @State private var step: AuthFlowStep
    @State private var direction: Int = 1
    @State private var selectedSports: Set<String> = ["nba", "epl", "nfl"]

    init(authManager: AuthManager, onComplete: @escaping (Set<String>) -> Void) {
        self.authManager = authManager
        self.onComplete = onComplete

        // Debug-only: jump to a specific step by passing
        // `-PreviewStep <name>` as a launch argument. Names: welcome,
        // value-0…value-3, auth, sports, notif, success.
        let initial: AuthFlowStep
        if let preview = UserDefaults.standard.string(forKey: "PreviewStep"),
           let mapped = Self.step(forPreviewName: preview) {
            initial = mapped
        } else if authManager.isAuthenticated {
            // Returning mid-flow user resumes after auth.
            initial = .pickSports
        } else {
            initial = .welcome
        }
        _step = State(initialValue: initial)
    }

    private static func step(forPreviewName name: String) -> AuthFlowStep? {
        switch name {
        case "welcome": return .welcome
        case "value-0": return .value(0)
        case "value-1": return .value(1)
        case "value-2": return .value(2)
        case "value-3": return .value(3)
        case "auth", "signup", "otp": return .auth
        case "sports": return .pickSports
        case "notif", "notifications": return .notifications
        case "success": return .success
        case "paywall": return .paywall
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            Color.p6Ink.ignoresSafeArea()

            ZStack {
                screenView
                    .id(stepID)
                    .transition(transition)
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.84), value: stepID)
        }
        .preferredColorScheme(.dark)
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            // After successful OTP, advance the flow.
            if isAuth, case .auth = step {
                advance(to: .pickSports)
            }
        }
    }

    @ViewBuilder
    private var screenView: some View {
        switch step {
        case .welcome:
            OBWelcomeScreen(
                onPrimary: { advance(to: .value(0)) },
                onSignIn:  { advance(to: .auth) }
            )

        case .value(let i):
            OBValueCarouselScreen(
                index: i,
                onNext: {
                    if i < 3 { advance(to: .value(i + 1)) }
                    else     { advance(to: .auth) }
                },
                onBack: i > 0 ? { back(to: .value(i - 1)) } : nil,
                onSkip: { advance(to: .auth) }
            )

        case .auth:
            AuthView(authManager: authManager)

        case .pickSports:
            // No back from sports — user is already authenticated; going
            // back would mean signing them out, which the design doesn't
            // imply.
            OBPickSportsScreen(
                selected: $selectedSports,
                onContinue: { advance(to: .notifications) }
            )

        case .notifications:
            OBNotificationsScreen(
                onBack: { back(to: .pickSports) },
                onContinue: { advance(to: .success) }
            )

        case .success:
            OBSuccessScreen(
                sportsCount: selectedSports.count,
                onContinue: { advance(to: .paywall) }
            )

        case .paywall:
            // Back from the paywall enters the app without subscribing —
            // matches the soft-paywall pattern (the trial CTA is the
            // primary path; the back affordance is a graceful exit).
            OBPaywallScreen(
                onBack: { onComplete(selectedSports) },
                onSubscribe: { plan in
                    UserDefaults.standard.set(plan, forKey: "selectedPlan")
                    onComplete(selectedSports)
                },
                onSkip: { onComplete(selectedSports) }
            )
        }
    }

    // MARK: - Navigation

    private func advance(to next: AuthFlowStep) {
        direction = 1
        withAnimation { step = next }
    }

    private func back(to prev: AuthFlowStep) {
        direction = -1
        withAnimation { step = prev }
    }

    private var transition: AnyTransition {
        direction == 1
            ? .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                          removal:   .move(edge: .leading).combined(with: .opacity))
            : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                          removal:   .move(edge: .trailing).combined(with: .opacity))
    }

    private var stepID: String {
        switch step {
        case .welcome: return "welcome"
        case .value(let i): return "value-\(i)"
        case .auth: return "auth"
        case .pickSports: return "sports"
        case .notifications: return "notif"
        case .success: return "success"
        case .paywall: return "paywall"
        }
    }
}

// MARK: - Shared chrome

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
                        .foregroundColor(.p6Foreground)
                        .frame(width: 36, height: 36)
                        .background(Color.p6Panel.opacity(0.7))
                        .overlay(Circle().stroke(Color.p6Line, lineWidth: 1))
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
                            .fill(i == step ? Color.p6Lime
                                  : (i < step ? Color.p6Ink2 : Color.p6Line2))
                            .frame(width: i == step ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: step)
                    }
                }
            }

            Spacer()

            if canSkip, let onSkip {
                Button(action: onSkip) {
                    Text("SKIP")
                        .font(.custom("BarlowCondensed-Bold", size: 12))
                        .kerning(2.4)
                        .foregroundColor(.p6Mute)
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
                .foregroundColor(disabled ? .p6Mute : .p6LimeInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(disabled ? Color.p6Panel2 : Color.p6Lime)
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
                colors: [Color.p6Ink.opacity(0), Color.p6Ink.opacity(0.92), Color.p6Ink],
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
            .foregroundColor(.p6Lime)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.p6Lime.opacity(0.12))
            .overlay(
                Capsule().stroke(Color.p6Lime.opacity(0.3), lineWidth: 1)
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
                .foregroundColor(.p6Foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if !line2Lead.isEmpty {
                    Text(line2Lead)
                        .foregroundColor(.p6Foreground)
                }
                if !line2Emphasis.isEmpty {
                    Text(line2Emphasis)
                        .foregroundColor(.p6Lime)
                }
            }
            .font(.custom("BarlowCondensed-Black", size: size))
            .kerning(-0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - 02 · Welcome

struct OBWelcomeScreen: View {
    let onPrimary: () -> Void
    let onSignIn: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background orb — sized circle offset off-canvas to match
            // the design's `top: -80, right: -140; width/height: 400` blob.
            // Brightest point lives off-screen so only the soft falloff
            // bleeds in.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.p6Lime.opacity(0.34), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 140, y: -80)
                .blur(radius: 32)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 16)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Logo wordmark
                        HStack(spacing: 0) {
                            Text("PICK")
                                .font(.custom("BarlowCondensed-Black", size: 26))
                                .foregroundColor(.p6Foreground)
                            Text("6")
                                .font(.custom("BarlowCondensed-Black", size: 26))
                                .foregroundColor(.p6Lime)
                        }
                        .kerning(0.5)
                        .padding(.bottom, 22)

                        OBKicker(text: "WELCOME TO PICK6")
                            .padding(.bottom, 14)

                        OBTitle("PICK", "SHARPER", emphasis: "TODAY.", size: 78)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 14)
                            .animation(.easeOut(duration: 0.45).delay(0.05), value: appeared)

                        Text("AI sports analysis across 8 leagues.\nClear reasoning on every recommendation.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.p6Ink2)
                            .lineSpacing(4)
                            .padding(.top, 14)
                            .frame(maxWidth: 310, alignment: .leading)

                        // Stats row
                        HStack(spacing: 14) {
                            wstat(num: "68", suffix: "%", label: "PICK ACCURACY")
                            divider
                            wstat(num: "9",  suffix: "",  label: "SPORTS COVERED")
                            divider
                            wstat(num: "24", suffix: "/7", label: "LIVE TRACKING")
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 16)
                        .background(Color.p6Panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.p6Line, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.top, 36)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OBStickyBar {
                OBPrimaryButton(label: "Let's go", action: onPrimary)
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.system(size: 12))
                        .foregroundColor(.p6Mute)
                    Button(action: onSignIn) {
                        Text("Sign in")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.p6Lime)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
            }
        }
        .onAppear { appeared = true }
    }

    private var divider: some View {
        Rectangle().fill(Color.p6Line).frame(width: 1, height: 36)
    }

    private func wstat(num: String, suffix: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(num)
                    .font(.custom("BarlowCondensed-Black", size: 32))
                    .foregroundColor(.p6Foreground)
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.p6Ink2)
                }
            }
            Text(label)
                .font(.custom("BarlowCondensed-Bold", size: 9))
                .kerning(1.8)
                .foregroundColor(.p6Mute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 03 · Value Carousel

private struct ValueSlide {
    let kicker: String
    let line1: String
    let line2: String
    let body: String
    let visual: Visual

    enum Visual { case sports, live, confidence, teams }
}

private let valueSlides: [ValueSlide] = [
    .init(kicker: "01 · AI PICKS",
          line1: "NINE SPORTS,", line2: "ONE BRAIN.",
          body: "Every recommendation backed by 10,000+ data points across NBA, EPL, MLB, NFL, NHL, UFC, F1 & Cricket.",
          visual: .sports),
    .init(kicker: "02 · LIVE TRACKING",
          line1: "IN THE", line2: "MOMENT.",
          body: "Watch your picks play out live. Every bucket, goal, lap — tracked in real-time with win probability.",
          visual: .live),
    .init(kicker: "03 · CONFIDENCE",
          line1: "NO MORE", line2: "GUESSING.",
          body: "Every pick comes with a confidence score and plain-English reasoning. Know WHY behind every call.",
          visual: .confidence),
    .init(kicker: "04 · YOUR TEAMS",
          line1: "NEVER MISS", line2: "A GAME.",
          body: "Follow your teams. Get alerts 30 min before tip-off, live score updates, and AI insights for every match.",
          visual: .teams),
]

struct OBValueCarouselScreen: View {
    let index: Int
    let onNext: () -> Void
    let onBack: (() -> Void)?
    let onSkip: () -> Void

    var body: some View {
        let slide = valueSlides[index]

        VStack(spacing: 0) {
            Spacer().frame(height: 8)
            OBTopBar(canGoBack: onBack != nil,
                     step: index, total: valueSlides.count,
                     canSkip: true,
                     onBack: onBack, onSkip: onSkip)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    visualView(for: slide.visual)
                        .frame(maxWidth: .infinity, minHeight: 320)
                        .padding(.horizontal, 22)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(slide.kicker)
                            .font(.custom("BarlowCondensed-Bold", size: 11))
                            .kerning(2.5)
                            .foregroundColor(.p6Lime)
                            .padding(.bottom, 14)

                        OBTitle(slide.line1, slide.line2, size: 50)

                        Text(slide.body)
                            .font(.system(size: 14))
                            .foregroundColor(.p6Ink2)
                            .lineSpacing(4)
                            .padding(.top, 14)
                            .frame(maxWidth: 330, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OBStickyBar {
                OBPrimaryButton(
                    label: index == valueSlides.count - 1 ? "Create account" : "Next",
                    action: onNext
                )
            }
        }
    }

    @ViewBuilder
    private func visualView(for v: ValueSlide.Visual) -> some View {
        switch v {
        case .sports:     ValueSportsTile()
        case .live:       ValueLiveCard()
        case .confidence: ValueConfidenceCard()
        case .teams:      ValueTeamsList()
        }
    }
}

// Visuals
private struct ValueSportsTile: View {
    private let icons = ["⚽", "🏀", "⚾", "🏈", "🏒", "🥊", "🏎", "🎾", "🏏"]
    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(Array(icons.enumerated()), id: \.offset) { i, icon in
                let highlight = (i == 4)
                Text(icon)
                    .font(.system(size: 40))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(highlight ? Color.p6Lime.opacity(0.1) : Color.p6Panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(highlight ? Color.p6Lime : Color.p6Line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .scaleEffect(highlight ? 1.06 : 1)
                    .shadow(color: highlight ? Color.p6Lime.opacity(0.25) : .clear, radius: 18)
            }
        }
        .padding(.horizontal, 10)
    }
}

private struct ValueLiveCard: View {
    @State private var pulse = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(Color.p6Hot)
                    .frame(width: 7, height: 7)
                    .opacity(pulse ? 0.4 : 1)
                Text("LIVE · Q3 4:22")
                    .font(.custom("BarlowCondensed-Bold", size: 11))
                    .kerning(2.2)
                    .foregroundColor(.p6Hot)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HEAT").font(.custom("BarlowCondensed-Bold", size: 11)).kerning(1.6).foregroundColor(.p6Ink2)
                    Text("88").font(.custom("BarlowCondensed-Black", size: 50)).foregroundColor(.p6Ink2)
                }
                Spacer()
                Text("–").font(.custom("BarlowCondensed-Black", size: 32)).foregroundColor(.p6Mute)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("NUGGETS").font(.custom("BarlowCondensed-Bold", size: 11)).kerning(1.6).foregroundColor(.p6Ink2)
                    Text("91").font(.custom("BarlowCondensed-Black", size: 50)).foregroundColor(.p6Lime)
                }
            }

            HStack(spacing: 10) {
                Text("WIN PROB")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .kerning(1.8)
                    .foregroundColor(.p6Mute)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.p6Line).frame(height: 4)
                        Capsule().fill(Color.p6Lime).frame(width: geo.size.width * 0.68, height: 4)
                    }
                }
                .frame(height: 4)
                Text("68%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.p6Lime)
            }

            HStack {
                Text("YOUR PICK")
                    .font(.custom("BarlowCondensed-Bold", size: 10))
                    .kerning(2)
                    .foregroundColor(.p6Lime)
                Spacer()
                Text("NUGGETS +2.5 · HITTING")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.p6Foreground)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.p6Lime.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.p6Lime.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(18)
        .background(Color.p6Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.p6Line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct ValueConfidenceCard: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("YANKEES ML")
                    .font(.custom("BarlowCondensed-Black", size: 22))
                    .foregroundColor(.p6Foreground)
                Spacer()
                Text("+135")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.p6Lime)
            }

            // Ring
            ZStack {
                Circle().stroke(Color.p6Line, lineWidth: 6).frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: 0.76)
                    .stroke(Color.p6Lime, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("76").font(.custom("BarlowCondensed-Black", size: 44))
                        Text("%").font(.custom("BarlowCondensed-Black", size: 18))
                    }
                    .foregroundColor(.p6Lime)
                    Text("CONFIDENCE")
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .kerning(2)
                        .foregroundColor(.p6Mute)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("WHY")
                    .font(.custom("BarlowCondensed-Bold", size: 9))
                    .kerning(2)
                    .foregroundColor(.p6Mute)
                ForEach(["Cole 2.34 ERA vs LAD",
                         "Judge 4-for-10 vs Buehler",
                         "Home stand 8-2 last 10"], id: \.self) { line in
                    HStack(spacing: 8) {
                        Text("✓").font(.system(size: 11, weight: .heavy)).foregroundColor(.p6Lime)
                        Text(line).font(.system(size: 12)).foregroundColor(.p6Ink2)
                    }
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.p6Line).frame(height: 1)
            }
            .padding(.top, 6)
        }
        .padding(20)
        .background(Color.p6Panel)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.p6Line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ValueTeamsList: View {
    private struct T { let crest: String; let mark: String; let name: String; let color: Color }
    private let teams: [T] = [
        .init(crest: "MIA", mark: "MIA", name: "HEAT",      color: Color(hex: "#98002E")),
        .init(crest: "LIV", mark: "LIV", name: "LIVERPOOL", color: Color(hex: "#C8102E")),
        .init(crest: "NYY", mark: "NYY", name: "YANKEES",   color: Color(hex: "#132448")),
        .init(crest: "KC",  mark: "KC",  name: "CHIEFS",    color: Color(hex: "#E31837")),
    ]
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(teams.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 12) {
                    Text(t.mark)
                        .font(.custom("BarlowCondensed-Black", size: 11))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(t.color)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 2))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.name)
                            .font(.custom("BarlowCondensed-Black", size: 16))
                            .foregroundColor(.p6Foreground)
                        Text("NEXT · TONIGHT · 7:30P")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .kerning(1.4)
                            .foregroundColor(.p6Mute)
                    }
                    Spacer()
                    Text("★").font(.system(size: 18)).foregroundColor(.p6Lime)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color.p6Panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.p6Line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

// MARK: - 07 · Pick Sports

private struct OBSport: Identifiable {
    let id: String
    let name: String
    let sub: String
    let icon: String
}

// The 8 sports the AI pipeline produces predictions for. Each `id`
// is the Supabase `picks.league` value used to filter; the `sub`
// label maps to `picks.sport` (basketball, soccer, …).
private let obSports: [OBSport] = [
    .init(id: "nba", name: "NBA",    sub: "Basketball", icon: "🏀"),
    .init(id: "epl", name: "EPL",    sub: "Soccer",     icon: "⚽"),
    .init(id: "mlb", name: "MLB",    sub: "Baseball",   icon: "⚾"),
    .init(id: "nfl", name: "NFL",    sub: "Football",   icon: "🏈"),
    .init(id: "nhl", name: "NHL",    sub: "Hockey",     icon: "🏒"),
    .init(id: "ufc", name: "UFC",    sub: "Combat",     icon: "🥊"),
    .init(id: "f1",  name: "F1",     sub: "Motorsport", icon: "🏎"),
    .init(id: "atp", name: "Tennis", sub: "ATP / WTA",  icon: "🎾"),
]

struct OBPickSportsScreen: View {
    @Binding var selected: Set<String>
    let onContinue: () -> Void

    private var canContinue: Bool { selected.count >= 3 }

    var body: some View {
        VStack(spacing: 0) {
            OBTopBar(step: 1, total: 3)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    OBKicker(text: "STEP 2 · YOUR SPORTS")
                        .padding(.bottom, 14)
                    OBTitle("WHAT DO", "YOU ", emphasis: "WATCH?", size: 56)
                    Text("Pick 3 or more. We'll send you picks & alerts for these.")
                        .font(.system(size: 14))
                        .foregroundColor(.p6Ink2)
                        .lineSpacing(4)
                        .padding(.top, 12)
                        .frame(maxWidth: 330, alignment: .leading)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                          spacing: 8) {
                    ForEach(obSports) { sport in
                        sportTile(sport)
                    }
                }
                .padding(.horizontal, 22)

                // Counter card
                HStack(spacing: 12) {
                    Text("\(selected.count)")
                        .font(.custom("BarlowCondensed-Black", size: 30))
                        .foregroundColor(.p6Lime)
                    Text(selected.count < 3
                         ? "SELECTED · PICK \(3 - selected.count) MORE"
                         : "SELECTED · LOOKS GOOD")
                        .font(.custom("BarlowCondensed-Bold", size: 11))
                        .kerning(2.2)
                        .foregroundColor(.p6Ink2)
                    Spacer()
                }
                .padding(14)
                .background(Color.p6Panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.p6Line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OBStickyBar {
                OBPrimaryButton(
                    label: canContinue ? "Continue" : "Pick \(3 - selected.count) more",
                    disabled: !canContinue,
                    action: onContinue
                )
            }
        }
    }

    private func sportTile(_ s: OBSport) -> some View {
        let on = selected.contains(s.id)
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                if on { selected.remove(s.id) } else { selected.insert(s.id) }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Text(s.icon).font(.system(size: 30)).padding(.bottom, 2)
                    Text(s.name)
                        .font(.custom("BarlowCondensed-Black", size: 16))
                        .foregroundColor(.p6Foreground)
                    Text(s.sub.uppercased())
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .kerning(1.4)
                        .foregroundColor(.p6Mute)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(0.82, contentMode: .fit)
                .padding(8)
                .background(on ? Color.p6Lime.opacity(0.08) : Color.p6Panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(on ? Color.p6Lime : Color.p6Line, lineWidth: on ? 1.5 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: on ? Color.p6Lime.opacity(0.18) : .clear, radius: 14, y: 4)

                ZStack {
                    Circle()
                        .fill(on ? Color.p6Lime : Color.p6Line2)
                        .frame(width: 22, height: 22)
                    if on {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.p6LimeInk)
                    }
                }
                .padding(7)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 08 · Notifications

struct OBNotificationsScreen: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var prefs: [String: Bool] = [
        "picks": true, "live": true, "results": true, "teams": true
    ]
    @State private var showSystem = false
    @State private var systemAlertChoice: Bool? = nil

    private struct Pref { let key: String; let label: String; let sub: String }
    private let prefRows: [Pref] = [
        .init(key: "picks",   label: "Daily AI picks",     sub: "Your morning pick list, 8am"),
        .init(key: "live",    label: "Live game alerts",   sub: "Score changes on your picks"),
        .init(key: "results", label: "Pick results",       sub: "Final outcomes + ROI updates"),
        .init(key: "teams",   label: "Your teams",         sub: "30 min before tip-off"),
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                OBTopBar(canGoBack: true, step: 2, total: 3, onBack: onBack)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        OBKicker(text: "STEP 3 · ALERTS")
                            .padding(.bottom, 14)
                        OBTitle("STAY", "IN THE ", emphasis: "GAME.", size: 56)
                        Text("We'll only ping you for stuff that matters.")
                            .font(.system(size: 14))
                            .foregroundColor(.p6Ink2)
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)

                    // Notification preview
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(Color.p6Lime)
                                        .frame(width: 18, height: 18)
                                    Text("★").font(.system(size: 11, weight: .heavy)).foregroundColor(.p6LimeInk)
                                }
                                Text("PICK6")
                                    .font(.custom("BarlowCondensed-Bold", size: 10))
                                    .kerning(2)
                                    .foregroundColor(.p6Ink2)
                            }
                            Spacer()
                            Text("now")
                                .font(.system(size: 11))
                                .foregroundColor(.p6Mute)
                        }
                        Text("🔥 Your pick is hitting")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.p6Foreground)
                        Text("NUGGETS +2.5 · Q3 4:22 · up 91–88. Win prob 68%.")
                            .font(.system(size: 12.5))
                            .foregroundColor(.p6Ink2)
                            .lineSpacing(2)
                    }
                    .padding(14)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.p6Line, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)

                    // Pref toggles
                    VStack(spacing: 4) {
                        ForEach(prefRows, id: \.key) { p in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.label)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundColor(.p6Foreground)
                                    Text(p.sub)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.p6Mute)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { prefs[p.key] ?? false },
                                    set: { prefs[p.key] = $0 }
                                ))
                                .labelsHidden()
                                .tint(.p6Lime)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(Color.p6Panel)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.p6Line, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                OBStickyBar {
                    OBPrimaryButton(label: "Enable notifications", action: requestNotifications)
                    Button(action: onContinue) {
                        Text("Maybe later")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.p6Mute)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }

            // System dialog overlay
            if showSystem {
                Color.black.opacity(0.5).ignoresSafeArea()
                    .background(.ultraThinMaterial)
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.p6Lime)
                            .padding(.top, 18)
                        Text("\u{201C}Pick6\u{201D} Would Like to Send You Notifications")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        Text("Notifications may include alerts, sounds and icon badges. These can be configured in Settings.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.66))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 14)
                    }

                    Divider().background(Color.white.opacity(0.15))
                    HStack(spacing: 0) {
                        Button("Don't Allow") { dismissSystem(allowed: false) }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                        Divider().frame(width: 0.5).background(Color.white.opacity(0.15))
                        Button("Allow") { dismissSystem(allowed: true) }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                            .fontWeight(.semibold)
                    }
                }
                .background(Color(red: 0.16, green: 0.16, blue: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: 280)
                .shadow(color: .black.opacity(0.5), radius: 20)
                .padding(.horizontal, 30)
            }
        }
    }

    private func requestNotifications() {
        // Show our preview dialog, then request real iOS permission.
        withAnimation(.easeOut(duration: 0.18)) { showSystem = true }
    }

    private func dismissSystem(allowed: Bool) {
        withAnimation(.easeOut(duration: 0.18)) { showSystem = false }
        if allowed {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
        // Either way, advance the flow.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onContinue()
        }
    }
}

// MARK: - OTP Box

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
                .fill(Color.p6Panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused ? Color.p6Lime
                                      : (digit.isEmpty ? Color.p6Line : Color.p6Ink2),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .shadow(color: isFocused ? Color.p6Lime.opacity(0.18) : .clear, radius: 8)

            if digit.isEmpty && isFocused {
                Rectangle()
                    .fill(Color.p6Lime)
                    .frame(width: 2, height: 28)
                    .cornerRadius(1)
                    .opacity(isFocused ? 1 : 0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(), value: isFocused)
            } else {
                Text(digit)
                    .font(.custom("BarlowCondensed-Black", size: 28))
                    .foregroundColor(.p6Foreground)
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

// MARK: - 09 · Success

struct OBSuccessScreen: View {
    let sportsCount: Int
    let onContinue: () -> Void

    @SwiftUI.State private var checkScale: CGFloat = 0
    @SwiftUI.State private var pulse = false
    @SwiftUI.State private var loadDot = 0
    @SwiftUI.State private var dotTimer: Timer?

    var body: some View {
        ZStack(alignment: .top) {
            // Glow — sized circle behind the check icon, blurred so the
            // edge falloff is soft. Pulses with the page's heartbeat.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.p6Lime.opacity(0.30), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 420, height: 420)
                .offset(y: 40)
                .blur(radius: 40)
                .allowsHitTesting(false)
                .opacity(pulse ? 1 : 0.6)

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Animated check
                ZStack {
                    Circle().stroke(Color.p6Lime, lineWidth: 3).frame(width: 80, height: 80)
                    Image(systemName: "checkmark")
                        .font(.system(size: 36, weight: .heavy))
                        .foregroundColor(.p6Lime)
                }
                .scaleEffect(checkScale)
                .padding(.bottom, 18)

                Text("YOU'RE IN")
                    .font(.custom("BarlowCondensed-Bold", size: 12))
                    .kerning(3.6)
                    .foregroundColor(.p6Lime)
                    .padding(.bottom, 10)

                OBTitle("LET'S", "GO.", size: 80)
                    .frame(maxWidth: .infinity)

                Text("We're warming up your picks for tonight's games.")
                    .font(.system(size: 13))
                    .foregroundColor(.p6Ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, 12)

                // Status list
                VStack(spacing: 4) {
                    statusRow(text: "Account created", state: .done)
                    statusRow(text: "Following \(sportsCount) sport\(sportsCount == 1 ? "" : "s")", state: .done)
                    statusRow(text: "Notifications enabled", state: .done)
                    statusRow(text: "Loading tonight's picks", state: .loading)
                }
                .padding(14)
                .background(Color.p6Panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.p6Line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 22)
                .padding(.top, 28)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OBStickyBar {
                OBPrimaryButton(label: "Show me my picks", action: onContinue)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                checkScale = 1
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            dotTimer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: true) { _ in
                loadDot = (loadDot + 1) % 3
            }
        }
        .onDisappear { dotTimer?.invalidate(); dotTimer = nil }
    }

    private enum RowState { case done, loading }

    @ViewBuilder
    private func statusRow(text: String, state: RowState) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color.p6Lime).frame(width: 8, height: 8)
                .opacity(state == .loading ? (pulse ? 0.4 : 1) : 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.p6Ink2)
            Spacer()
            switch state {
            case .done:
                Text("✓").font(.system(size: 14, weight: .heavy)).foregroundColor(.p6Lime)
            case .loading:
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(Color.p6Lime)
                            .frame(width: 4, height: 4)
                            .opacity(loadDot == i ? 1 : 0.3)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
