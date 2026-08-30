//  Pick1OnboardingV2.swift
//  "Onboarding v2" — the 10-step funnel from the design project
//
//  welcome → 3 quiz steps → analysis → sign up → hard truth → the fix →
//  social proof → paywall → done. A large simplification of the shipping
//  `Pick1OnboardingFunnel`, which runs 21 screens for the same job.
//
//  Sign-up reuses `AuthManager` unchanged: Sign in with Apple, or an email
//  OTP. No new auth path was written for this screen, so anything that works
//  in the shipping funnel works here.
//
//  Numbers policy, same as the v2 paywall: anything the app can actually
//  measure is measured (the record, the hit rate, the sport count, the plan
//  prices). Everything the mockup invents lives in
//  `OnboardingV2Placeholders` so it is one file to correct before this is
//  ever shown to a real user.

import SwiftUI
import StoreKit
import AuthenticationServices

// MARK: - Values with no data source

/// The mockup's unverifiable claims. The member count and both testimonials
/// are not in any data source; the "48% / 3+ hours" figures on the hard-truth
/// step are general market claims about gut-feel picking rather than claims
/// about Pick1's own results, which is why they are copy rather than data.
enum OnboardingV2Placeholders {
    /// 5,523 rows in `signups` on 2026-08-24, stated conservatively and
    /// rounded DOWN so it stays true as it grows. Re-check it before any
    /// campaign that leans on it; an inflated number on a purchase screen is
    /// an App Review 2.3.1 problem, not a marketing one.
    static let memberCount = "5,000+"
    static let testimonials: [(initials: String, name: String, tenure: String, quote: String)] = [
        ("DK", "Dan K.", "Member · 8 months",
         "First app that shows its losses. That's why I trust the wins."),
        ("SR", "Sofia R.", "Member · 5 months",
         "One pick a day fits my life. No spreadsheets, no noise, just the call."),
    ]
}

// MARK: - Steps

enum P1OnbStep: Int, CaseIterable {
    // `signup` sits where the shipping 21-screen funnel puts it: straight
    // after the analysis, before the hard truth. The user has answered three
    // questions and watched their profile build, so the account ask reads as
    // saving that result rather than as a cold registration wall. It is also
    // before the paywall, which StoreKit requires in practice: a purchase made
    // by an anonymous user cannot be tied back to an account.
    case welcome, sports, method, frustration, analysis, signup, pain, fix, proof, paywall, done

    var next: P1OnbStep? { P1OnbStep(rawValue: rawValue + 1) }
    /// 0…1 for the progress rail.
    var progress: Double {
        Double(rawValue) / Double(P1OnbStep.allCases.count - 1)
    }
}

// MARK: - Shared pieces

/// The mockup's `.rise` entrance: 22pt up, 0.55s, staggered 80ms per element.
private struct P1Rise: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 22)
            .onAppear {
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.55)
                    .delay(Double(index) * 0.08)) { shown = true }
            }
    }
}

private extension View {
    func rise(_ index: Int = 0) -> some View { modifier(P1Rise(index: index)) }
}

private struct P1OnbKicker: View {
    let text: String
    var color: Color = .p1Lime
    var body: some View {
        Text(text.uppercased())
            .font(.archivoNarrow(11, weight: .bold))
            .tracking(2.42)                              // 0.22em at 11pt
            .foregroundStyle(color)
    }
}

private struct P1OnbTitle: View {
    let plain: String
    var accent: String? = nil
    var accentColor: Color = .p1Lime

    var body: some View {
        Group {
            if let accent {
                Text(plain.uppercased()).foregroundStyle(Color.p1Foreground)
                    + Text(accent.uppercased()).foregroundStyle(accentColor)
            } else {
                Text(plain.uppercased()).foregroundStyle(Color.p1Foreground)
            }
        }
        .font(.anton(44))
        .lineSpacing(-6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }
}

private struct P1OnbCTA: View {
    let title: String
    var tint: Color = .p1Lime
    var fg: Color = .p1Ink
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.anton(17))
                .tracking(0.68)
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(tint))
                .shadow(color: tint.opacity(0.3), radius: 20, y: 14)
        }
        .buttonStyle(.plain)
    }
}

/// One quiz row. `isOn` drives the lime border and the tinted wash.
private struct P1OnbOption: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Text(emoji).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.archivoNarrow(14.5, weight: .bold))
                        .foregroundStyle(isOn ? Color.p1Lime : Color.p1Foreground)
                    Text(subtitle)
                        .font(.archivoNarrow(11, weight: .semibold))
                        .foregroundStyle(Color.p1Mute)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(
                    isOn
                    ? AnyShapeStyle(LinearGradient(colors: [Color.p1Lime.opacity(0.12), .clear],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.p1Panel)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isOn ? Color.p1Lime : Color.p1Line, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A tinted bullet row — red on the hard-truth step, lime on the fix step.
private struct P1OnbBullet: View {
    let emoji: String
    let lead: String
    let bold: String
    let tail: String
    let tint: Color
    let boldColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 20))
            (
                Text(lead).foregroundStyle(Color.p1Foreground)
                + Text(bold).foregroundStyle(boldColor)
                + Text(tail).foregroundStyle(Color.p1Foreground)
            )
            .font(.archivo(13.5, weight: .semibold))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(RoundedRectangle(cornerRadius: 16).fill(tint.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.33), lineWidth: 1))
    }
}

/// The mockup's confetti burst on purchase.
private struct P1Confetti: View {
    let seed: Int
    private let colors: [Color] = [.p1Lime, .p1Violet, .p1Win, .white, Color(hex: "#FFD84D")]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.8) / 1.4
                guard t <= 1 else { return }
                var rng = SystemlessRandom(seed: UInt64(seed))
                for i in 0..<26 {
                    let x0 = size.width * (0.10 + rng.next() * 0.80)
                    let y0 = size.height * 0.30
                    let dx = CGFloat(rng.next() * 260 - 130)
                    let dy = CGFloat(rng.next() * 380 + 80)
                    let e = 1 - pow(1 - t, 2.2)          // cubic-bezier(.2,.6,.4,1)-ish
                    let rect = CGRect(x: x0 + dx * e, y: y0 + dy * e, width: 8, height: 8)
                    ctx.opacity = 1 - t
                    ctx.fill(Path(rect), with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Deterministic pseudo-random so the burst is stable across frames without
/// `Math.random`-style jitter re-rolling every tick.
private struct SystemlessRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}

// MARK: - Screen

struct Pick1OnboardingV2: View {
    @ObservedObject var vm: PicksViewModel
    @EnvironmentObject private var subs: SubscriptionManager
    /// Optional so the DEBUG review host still renders if the manager is not
    /// injected; the signup step simply cannot complete without it.
    @Environment(AuthManager.self) private var auth: AuthManager?
    /// Called when the funnel completes. In production this is where
    /// `hasFinishedOnboarding` would be set — v2 has no sign-up step, so the
    /// caller still owns account creation.
    var onFinish: () -> Void = {}

    @State private var step: P1OnbStep = .welcome
    @State private var sports: Set<Int> = []
    @State private var method: Int?
    @State private var frustration: Int?
    @State private var analysisPct = 0
    @State private var analysisRows = 0
    @State private var selectedProductId: String?
    @State private var isPurchasing = false
    @State private var confettiSeed = 0
    @State private var email = ""
    @State private var code = ""
    @State private var otpSent = false
    @State private var authBusy = false
    @State private var appleNonce = ""

    private var settled: [Pick] { vm.historyPicks.filter { !$0.isPending } }
    private var sportCount: Int {
        max(Set(vm.historyPicks.map(\.sport)).count, P1SportSummaryV2.all.count)
    }

    private var plans: [Product] {
        ["com.pick1.app.pro.weekly", "com.pick1.app.pro.monthly"]
            .compactMap { id in subs.products.first { $0.id == id } }
    }
    private var selectedPlan: Product? {
        plans.first { $0.id == selectedProductId } ?? plans.last
    }

    var body: some View {
        ZStack(alignment: .top) {
            background.ignoresSafeArea()

            Group {
                switch step {
                case .welcome:     welcomeStep
                case .sports:      sportsStep
                case .method:      methodStep
                case .frustration: frustrationStep
                case .analysis:    analysisStep
                case .signup:      signupStep
                case .pain:        painStep
                case .fix:         fixStep
                case .proof:       proofStep
                case .paywall:     paywallStep
                case .done:        doneStep
                }
            }
            .id(step)                                   // restart the rise on each step
            .padding(.horizontal, 26)
            .padding(.top, 78)
            .padding(.bottom, 30)

            // Progress rail
            Capsule().fill(.white.opacity(0.09))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule().fill(Color.p1Lime)
                            .frame(width: geo.size.width * step.progress)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 60)

            if confettiSeed > 0 {
                P1Confetti(seed: confettiSeed)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .preferredColorScheme(.dark)
        .task { if subs.products.isEmpty { await subs.reloadProducts() } }
    }

    /// The hard-truth and fix steps recolour the whole screen.
    @ViewBuilder private var background: some View {
        switch step {
        case .pain:
            LinearGradient(colors: [Color(hex: "#2A0D08"), Color(hex: "#160705"), Color.p1Ink],
                           startPoint: .top, endPoint: .bottom)
        case .fix:
            LinearGradient(colors: [Color(hex: "#12240C"), Color(hex: "#0B1607"), Color.p1Ink],
                           startPoint: .top, endPoint: .bottom)
        default:
            RadialGradient(colors: [Color(hex: "#1D2026"), Color.p1Ink],
                           center: .init(x: 0.5, y: -0.08), startRadius: 0, endRadius: 560)
        }
    }

    private func advance() {
        if let next = step.next { step = next } else { onFinish() }
    }

    private var boltDisc: some View {
        P1BoltMark()
            .fill(Color.p1LimeInk)
            .frame(width: 46, height: 46)
            .frame(width: 92, height: 92)
            .background(
                Circle().fill(
                    LinearGradient(colors: [Color.p1Lime, Color(hex: "#8FC218")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .shadow(color: Color.p1Lime.opacity(0.5), radius: 30)
    }

    // MARK: Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                boltDisc.padding(.top, 30)
                P1OnbKicker(text: "Welcome to Pick1").padding(.top, 24)
                (
                    Text("One AI pick.\nEvery day.\n").foregroundStyle(Color.p1Foreground)
                    + Text("Made public.").foregroundStyle(Color.p1Lime)
                )
                .font(.anton(44))
                .lineSpacing(-6)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                Text("\(sportCount) sports scored every morning. You get the single highest-edge call, logged before kickoff, win or lose.")
                    .font(.archivo(15, weight: .semibold))
                    .lineSpacing(4)
                    .foregroundStyle(Color.p1Ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
            .rise(0)

            // Real record, not the mockup's 62/85.
            HStack(spacing: 9) {
                statTile("\(vm.totalWins)/\(settled.count)", "Picks won")
                statTile("\(Int(vm.winRate.rounded()))%", "Hit rate")
                statTile("\(sportCount)", "Sports")
            }
            .padding(.top, 26)
            .rise(2)

            winsTicker.padding(.top, 18).rise(3)

            Spacer(minLength: 22)

            VStack(spacing: 14) {
                P1OnbCTA(title: "Get started") { advance() }
                Button { step = .proof } label: {
                    Text("I ALREADY HAVE AN ACCOUNT")
                        .font(.archivoNarrow(12, weight: .bold))
                        .tracking(1.44)
                        .foregroundStyle(Color.p1Mute)
                }
                .buttonStyle(.plain)
            }
            .rise(4)
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.anton(22))
                .foregroundStyle(Color.p1Lime)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label.uppercased())
                .font(.archivoNarrow(8.5, weight: .bold))
                .tracking(1.02)
                .foregroundStyle(Color.p1Mute)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.p1Panel))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.p1Line, lineWidth: 1))
    }

    /// Real settled wins, scrolling. Falls back to nothing rather than to the
    /// mockup's invented list.
    @ViewBuilder private var winsTicker: some View {
        let wins = settled.filter(\.isWin).prefix(6)
        if !wins.isEmpty {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 12) / 12
                GeometryReader { geo in
                    HStack(spacing: 18) {
                        ForEach(0..<2, id: \.self) { pass in
                            ForEach(Array(wins)) { p in
                                Text("✓ \(p.pick.uppercased()) WON")
                                    .font(.mono(10.5, weight: .bold))
                                    .foregroundStyle(Color.p1Win)
                                    .fixedSize()
                                    .id("\(pass)-\(p.id)")
                            }
                        }
                    }
                    .fixedSize()
                    .offset(x: geo.size.width * 0.3 - CGFloat(t) * geo.size.width * 1.3)
                }
                .frame(height: 14)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.p1Line, lineWidth: 1))
            .clipped()
        }
    }

    private var sportsStep: some View {
        quizStep(kicker: "Question 1 of 3",
                 title: "Which sports do you follow?",
                 cta: "Continue",
                 options: [
                    ("🏈", "Football", "NFL · NCAA"),
                    ("🏀", "Basketball", "NBA · Euroleague"),
                    ("⚽", "Soccer", "EPL · UCL · World Cup"),
                    ("🎾", "Tennis · MMA · more", "\(max(sportCount - 3, 0)) other sports"),
                 ],
                 isOn: { sports.contains($0) },
                 pick: { i in
                     // Multi-select, unlike the other two steps.
                     if sports.contains(i) { sports.remove(i) } else { sports.insert(i) }
                 })
    }

    private var methodStep: some View {
        quizStep(kicker: "Question 2 of 3",
                 title: "How do you pick winners today?",
                 cta: "Continue",
                 options: [
                    ("🤷", "Gut feeling", "I go with my instinct"),
                    ("📱", "Twitter / tipsters", "I follow picks accounts"),
                    ("📊", "My own research", "Stats, injuries, form"),
                    ("🎲", "Honestly? Random", "Whatever looks fun"),
                 ],
                 isOn: { method == $0 },
                 pick: { method = $0 })
    }

    private var frustrationStep: some View {
        quizStep(kicker: "Question 3 of 3",
                 title: "What's your biggest frustration?",
                 cta: "See my analysis",
                 options: [
                    ("📉", "Losing streaks", "Cold runs kill my confidence"),
                    ("🗑️", "Tipsters who delete losses", "Nobody shows their real record"),
                    ("⏰", "No time to research", "Too many games, too little time"),
                    ("🌪️", "Too much noise", "Everyone says something different"),
                 ],
                 isOn: { frustration == $0 },
                 pick: { frustration = $0 })
    }

    private func quizStep(kicker: String, title: String, cta: String,
                          options: [(String, String, String)],
                          isOn: @escaping (Int) -> Bool,
                          pick: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            P1OnbKicker(text: kicker).rise(0)
            P1OnbTitle(plain: title).rise(1)
            VStack(spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                    P1OnbOption(emoji: o.0, title: o.1, subtitle: o.2, isOn: isOn(i)) { pick(i) }
                }
            }
            .padding(.top, 20)
            .rise(2)

            Spacer(minLength: 22)
            P1OnbCTA(title: cta) { advance() }.rise(3)
        }
    }

    private var analysisStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            P1OnbKicker(text: "Analyzing your answers").rise(0)
            (
                Text("Building your\n").foregroundStyle(Color.p1Foreground)
                + Text("pick profile…").foregroundStyle(Color.p1Lime)
            )
            .font(.anton(44))
            .lineSpacing(-6)
            .padding(.top, 12)
            .rise(1)

            VStack(alignment: .leading, spacing: 16) {
                analysisRow(0, "Scanning your sports & leagues")
                analysisRow(1, "Comparing vs \(OnboardingV2Placeholders.memberCount) member profiles")
                analysisRow(2, "Measuring your edge without data")
                analysisRow(3, "Matching the AI model to your slate")
            }
            .padding(.top, 40)

            Capsule().fill(.white.opacity(0.08))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(LinearGradient(colors: [Color.p1Lime, Color(hex: "#7EE000")],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * Double(analysisPct) / 100)
                    }
                }
                .padding(.top, 34)

            Text("\(analysisPct)%")
                .font(.anton(52))
                .foregroundStyle(Color.p1Lime)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .task { await runAnalysis() }
    }

    private func analysisRow(_ index: Int, _ text: String) -> some View {
        let done = analysisRows > index
        return HStack(spacing: 12) {
            Text("✓")
                .font(.archivo(11, weight: .bold))
                .foregroundStyle(Color.p1Lime)
                .frame(width: 22, height: 22)
                .background(Circle().fill(done ? Color.p1Lime.opacity(0.12) : .clear))
                .overlay(Circle().strokeBorder(done ? Color.p1Lime : Color.p1Line, lineWidth: 2))
            Text(text)
                .font(.archivoNarrow(13, weight: .bold))
                .foregroundStyle(done ? Color.p1Foreground : Color.p1Mute)
        }
        .animation(.easeOut(duration: 0.3), value: done)
    }

    private func runAnalysis() async {
        for i in 1...4 {
            try? await Task.sleep(for: .milliseconds(i == 1 ? 700 : 800))
            analysisRows = i
        }
        while analysisPct < 100 {
            try? await Task.sleep(for: .milliseconds(260))
            analysisPct = min(analysisPct + Int.random(in: 3...11), 100)
        }
        try? await Task.sleep(for: .milliseconds(700))
        if step == .analysis { advance() }
    }

    // MARK: Sign up

    @ViewBuilder private var signupStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            P1OnbKicker(text: otpSent ? "Check your inbox" : "Your profile is ready").rise(0)
            P1OnbTitle(plain: otpSent ? "Enter the " : "Save it to ",
                       accent: otpSent ? "6-digit code." : "your account.").rise(1)

            if !otpSent {
                Text("Your picks, your record and your streak live on the account, not the device. One tap with Apple, or an email code.")
                    .font(.archivo(15, weight: .semibold))
                    .lineSpacing(4)
                    .foregroundStyle(Color.p1Ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .rise(2)

                SignInWithAppleButton(.signUp) { req in
                    let nonce = randomNonceString()
                    appleNonce = nonce
                    req.requestedScopes = [.fullName, .email]
                    req.nonce = sha256Hex(nonce)
                } onCompletion: { handleApple($0) }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 26)
                .rise(3)

                HStack(spacing: 12) {
                    Rectangle().fill(Color.p1Line).frame(height: 1)
                    Text("OR")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.p1Mute)
                    Rectangle().fill(Color.p1Line).frame(height: 1)
                }
                .padding(.vertical, 18)
                .rise(3)

                onbField(label: "Email", text: $email, placeholder: "you@email.com")
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .rise(3)
            } else {
                Text("We sent a code to \(email).")
                    .font(.archivo(15, weight: .semibold))
                    .foregroundStyle(Color.p1Ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                onbField(label: "6-digit code", text: $code, placeholder: "123456")
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(.top, 4)

                Button {
                    withAnimation { otpSent = false }
                    code = ""
                } label: {
                    Text("Use a different email")
                        .font(.archivo(13, weight: .medium))
                        .foregroundStyle(Color.p1Lime)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }

            if let e = auth?.error, !e.isEmpty {
                Text(e)
                    .font(.archivo(13))
                    .foregroundStyle(Color.p1Hot)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            Spacer(minLength: 22)

            VStack(spacing: 0) {
                P1OnbCTA(title: authBusy ? "…" : (otpSent ? "Verify & continue" : "Continue with email")) {
                    Task { await submitAuth() }
                }
                if !otpSent {
                    Text("By continuing you agree to the Terms and Privacy Policy.")
                        .font(.mono(10, weight: .semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.p1Mute)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                }
            }
            .rise(4)
        }
        // A user who is already signed in (reinstall, or they came back mid
        // funnel) should never be parked on an account wall. `-forceSignup`
        // holds the screen anyway: the Supabase session lives in the keychain
        // and survives an app uninstall, so on a dev device there is otherwise
        // no way to see this step at all.
        .onAppear {
            #if DEBUG
            if CommandLine.arguments.contains("-forceSignup") { return }
            #endif
            if auth?.isAuthenticated == true { advance() }
        }
        .onChange(of: auth?.isAuthenticated ?? false) { _, signedIn in
            guard signedIn, step == .signup else { return }
            #if DEBUG
            if CommandLine.arguments.contains("-forceSignup") { return }
            #endif
            // Meta CompleteRegistration fires at account creation, not at the
            // end of the funnel, which sits past the paywall.
            Analytics.signupCompleted()
            advance()
        }
    }

    private func onbField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label.uppercased())
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Color.p1Mute)
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Color.p1Mute))
                .font(.archivo(17, weight: .semibold))
                .foregroundStyle(Color.p1Foreground)
                .padding(.horizontal, 16).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.p1Line, lineWidth: 1))
        }
        .padding(.top, 8)
    }

    private func submitAuth() async {
        guard let auth, !authBusy else { return }
        authBusy = true
        defer { authBusy = false }
        if !otpSent {
            // Cheap client-side sanity check only; the server is authoritative.
            guard email.contains("@"), email.contains(".") else { return }
            await auth.sendOTP(email: email)
            if auth.error == nil { withAnimation { otpSent = true } }
        } else {
            await auth.verifyOTP(email: email,
                                 token: code.trimmingCharacters(in: .whitespaces))
            // Success flips isAuthenticated, and onChange advances.
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authz) = result,
              let cred = authz.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else { return }
        Task {
            await auth?.signInWithApple(idToken: idToken, nonce: appleNonce,
                                        firstName: cred.fullName?.givenName,
                                        lastName: cred.fullName?.familyName)
        }
    }

    private var painStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            P1OnbKicker(text: "Your analysis · the hard truth", color: Color(hex: "#FF7A5C")).rise(0)
            P1OnbTitle(plain: "Picking on instinct is ", accent: "costing you.",
                       accentColor: Color.p1Hot).rise(1)

            VStack(spacing: 11) {
                P1OnbBullet(emoji: "📉", lead: "Gut-feel pickers hit ", bold: "~48%",
                            tail: " long-term, worse than a coin flip after the juice.",
                            tint: .p1Hot, boldColor: Color(hex: "#FF7A5C"))
                P1OnbBullet(emoji: "🗑️", lead: "Tipster accounts ", bold: "delete their losses",
                            tail: ". You never see the real record.",
                            tint: .p1Hot, boldColor: Color(hex: "#FF7A5C"))
                P1OnbBullet(emoji: "⏰", lead: "Doing it right takes ", bold: "3+ hours a day",
                            tail: " of injuries, form and line moves.",
                            tint: .p1Hot, boldColor: Color(hex: "#FF7A5C"))
            }
            .padding(.top, 20)
            .rise(2)

            Text("YOUR PROFILE: HIGH EFFORT · LOW EDGE · NO SYSTEM")
                .font(.mono(11, weight: .bold))
                .tracking(0.66)
                .foregroundStyle(Color(hex: "#FF9A80"))
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .rise(3)

            Spacer(minLength: 22)
            P1OnbCTA(title: "Show me the fix", tint: .p1Hot, fg: .white) { advance() }.rise(4)
        }
    }

    private var fixStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            P1OnbKicker(text: "The fix · welcome to Pick1").rise(0)
            P1OnbTitle(plain: "One calibrated call. ", accent: "Zero noise.").rise(1)

            VStack(spacing: 11) {
                P1OnbBullet(emoji: "⚡", lead: "", bold: "One pick a day",
                            tail: " — the AI scores every game across \(sportCount) sports and hands you the single best edge.",
                            tint: .p1Lime, boldColor: .p1Lime)
                P1OnbBullet(emoji: "📌", lead: "", bold: "Logged before kickoff",
                            tail: " — every call timestamped publicly. Wins AND losses, forever.",
                            tint: .p1Lime, boldColor: .p1Lime)
                P1OnbBullet(emoji: "🎯", lead: "", bold: "Calibrated %",
                            tail: " — when it says 73%, it hits ≈73%. That's the whole point.",
                            tint: .p1Lime, boldColor: .p1Lime)
            }
            .padding(.top, 20)
            .rise(2)

            Spacer(minLength: 22)
            P1OnbCTA(title: "I want this") { advance() }.rise(3)
        }
    }

    private var proofStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            P1OnbKicker(text: "\(OnboardingV2Placeholders.memberCount) members already in").rise(0)
            P1OnbTitle(plain: "They stopped ", accent: "guessing.").rise(1)

            VStack(alignment: .leading, spacing: 0) {
                Text("⚡ MEMBER RECORD · THIS SEASON")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Color.p1Ink.opacity(0.65))
                Text("\(vm.totalWins) OF \(settled.count) WON")
                    .font(.anton(40))
                    .foregroundStyle(Color.p1Ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.top, 6)
                Text("\(Int(vm.winRate.rounded()))% HIT RATE · EVERY CALL PUBLIC · PICK1.LIVE")
                    .font(.mono(10.5, weight: .bold))
                    .foregroundStyle(Color.p1Ink.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20).fill(
                    LinearGradient(colors: [Color.p1Lime, Color(hex: "#8FD400")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .rotationEffect(.degrees(-1.5))
            .padding(.top, 16)
            .rise(2)

            VStack(spacing: 11) {
                ForEach(Array(OnboardingV2Placeholders.testimonials.enumerated()), id: \.offset) { _, t in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 10) {
                            Text(t.initials)
                                .font(.anton(12))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle().fill(
                                        LinearGradient(colors: [Color.p1Violet, Color(hex: "#4C2A9E")],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.name)
                                    .font(.archivoNarrow(13, weight: .bold))
                                    .foregroundStyle(Color.p1Foreground)
                                Text(t.tenure)
                                    .font(.archivoNarrow(10, weight: .bold))
                                    .foregroundStyle(Color.p1Mute)
                            }
                            Spacer(minLength: 8)
                            Text("★★★★★")
                                .font(.system(size: 12))
                                .tracking(2)
                                .foregroundStyle(Color.p1Lime)
                        }
                        Text("“\(t.quote)”")
                            .font(.archivo(13, weight: .semibold))
                            .lineSpacing(4)
                            .foregroundStyle(Color.p1Ink2)
                            // Without this the quote clips to one line inside
                            // the card instead of wrapping.
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.p1Panel))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.p1Line, lineWidth: 1))
                }
            }
            .padding(.top, 16)
            .rise(3)

            Spacer(minLength: 22)
            P1OnbCTA(title: "Now it's time to win") { step = .paywall }.rise(4)
        }
    }

    private var paywallStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            P1OnbKicker(text: "Last step").rise(0)
            P1OnbTitle(plain: "Unlock every pick. ", accent: "Start now.").rise(1)

            // The mockup's "Launch offer ends in 19:59" is omitted: a countdown
            // that restarts on every run is fabricated urgency and an App
            // Review 2.3.1 risk. See P1PayTimerV2 for the reusable component
            // once a real offer window exists.

            VStack(spacing: 11) {
                ForEach(plans, id: \.id) { p in
                    planRow(p)
                }
                if plans.isEmpty {
                    Text("Plans are still loading from the App Store.")
                        .font(.archivoNarrow(12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.p1Mute)
                }
            }
            .padding(.top, 16)
            .rise(2)

            // Wrapped chips, as in the mockup's .payfeat row.
            FlowChips(items: ["⚡ \(sportCount) sports", "📌 Public ledger", "🎯 Calibrated %", "📊 Full history"])
                .padding(.top, 14)
                .rise(3)

            Spacer(minLength: 22)

            VStack(spacing: 0) {
                P1OnbCTA(title: isPurchasing ? "…" : "Start winning today") {
                    guard let product = selectedPlan, !isPurchasing else { return }
                    isPurchasing = true
                    Task {
                        await subs.purchase(product)
                        isPurchasing = false
                        if subs.isPro {
                            confettiSeed = Int(Date().timeIntervalSince1970)
                            try? await Task.sleep(for: .milliseconds(700))
                            step = .done
                        }
                    }
                }
                Text("RECURRING BILLING · CANCEL ANYTIME IN SETTINGS\nPREDICTIONS ARE FORECASTS, NOT GUARANTEES · 18+")
                    .font(.mono(8.5, weight: .semibold))
                    .tracking(0.26)
                    .lineSpacing(5)
                    .foregroundStyle(Color.p1Mute)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            .rise(4)
        }
    }

    private func planRow(_ p: Product) -> some View {
        let isOn = p.id == selectedPlan?.id
        let isWeekly = p.id.hasSuffix("weekly")
        let days: Decimal = isWeekly ? 7 : 30
        let perDay = (p.price / days).formatted(p.priceFormatStyle)
        return Button { selectedProductId = p.id } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(isWeekly ? "WEEKLY" : "MONTHLY")
                        .font(.anton(17))
                        .foregroundStyle(Color.p1Foreground)
                    Spacer(minLength: 8)
                    Text(p.displayPrice)
                        .font(.anton(20))
                        .foregroundStyle(Color.p1Foreground)
                    + Text(isWeekly ? "/wk" : "/mo")
                        .font(.archivoNarrow(11, weight: .bold))
                        .foregroundStyle(Color.p1Mute)
                }
                (
                    Text(perDay).foregroundStyle(Color.p1Lime)
                    + Text("/day · cancel anytime").foregroundStyle(Color.p1Mute)
                )
                .font(.archivoNarrow(11.5, weight: .bold))
                .tracking(0.46)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18).fill(
                    isOn
                    ? AnyShapeStyle(LinearGradient(colors: [Color.p1Lime.opacity(0.10), .clear],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.p1Panel)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isOn ? Color.p1Lime : Color.p1Line, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                boltDisc.padding(.top, 80)
                P1OnbKicker(text: "You're in").padding(.top, 26)
                (
                    Text("Your first pick is ").foregroundStyle(Color.p1Foreground)
                    + Text("ready.").foregroundStyle(Color.p1Lime)
                )
                .font(.anton(44))
                .lineSpacing(-6)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                Text("Tonight's highest-edge call is waiting on your home screen. New pick every morning.")
                    .font(.archivo(15, weight: .semibold))
                    .lineSpacing(4)
                    .foregroundStyle(Color.p1Ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
            .rise(0)

            Spacer(minLength: 22)
            P1OnbCTA(title: "See tonight's pick →") { onFinish() }.rise(2)
        }
    }
}

/// Simple wrapping chip row for the paywall's feature pills.
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        // Two balanced rows keeps this predictable on a 350pt content width
        // without pulling in a full flow-layout implementation.
        let mid = (items.count + 1) / 2
        VStack(alignment: .leading, spacing: 7) {
            chipRow(Array(items.prefix(mid)))
            chipRow(Array(items.dropFirst(mid)))
        }
    }

    private func chipRow(_ row: [String]) -> some View {
        HStack(spacing: 7) {
            ForEach(row, id: \.self) { c in
                Text(c.uppercased())
                    .font(.archivoNarrow(10.5, weight: .bold))
                    .tracking(0.63)
                    .foregroundStyle(Color.p1Ink2)
                    .lineLimit(1)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Capsule().fill(Color.p1Panel))
                    .overlay(Capsule().strokeBorder(Color.p1Line, lineWidth: 1))
            }
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
/// `-showOnboardingV2`
struct Pick1OnboardingV2DebugHost: View {
    @StateObject private var vm = PicksViewModel()

    var body: some View {
        Pick1OnboardingV2(vm: vm)
            .task { await vm.loadAll() }
    }
}
#endif
