//
//  Pick1OnboardingFunnel.swift
//  Betting app
//
//  The 20-screen marketing onboarding funnel — a faithful SwiftUI rebuild of
//  the "Pick1 Onboarding Funnel" design. Replaces the legacy Pick1AuthFlow.
//
//  Flow: Welcome → Features → Sign up → 5-question quiz → Analysis ring →
//        4× hard-truth (red) → 3× the-fix (green) → Social proof → Comparison
//        → Goals → Referral → Rating → Time-to-win → Paywall → Success.
//
//  Pricing: Weekly / Monthly / Lifetime ($299). No free trial by default —
//  a referral code grants a free week, rating grants +3 days (both server-side
//  comp grants, not StoreKit intro offers).
//
//  Built in phases; integration hooks (auth / referral / paywall / rating)
//  land in Phase 3. Until wired in as the entry point (Phase 5) this is
//  reachable only via #Preview.
//

import SwiftUI
import AuthenticationServices
import StoreKit
import Supabase

// MARK: - Design tokens (from the funnel :root)

enum Fnl {
    static let ink    = Color(hex: "#0a0b0d")   // screen background
    static let lime   = Color(hex: "#cdfa3f")
    static let panel  = Color(hex: "#101114")
    static let panel2 = Color(hex: "#16181c")
    static let line   = Color(hex: "#22252b")
    static let white  = Color(hex: "#f5f3ee")
    static let ink2   = Color(hex: "#b9b7b0")
    static let mute   = Color(hex: "#6e6f75")
    static let hot    = Color(hex: "#ff5a36")   // "hard truth" red
    static let win    = Color(hex: "#4ade80")   // "the fix" green
}

// MARK: - Step model

/// One entry per swipe-able screen. The quiz is flattened to 5 steps so the
/// progress bar advances per question. `ordered` is the canonical sequence.
enum FunnelStep: Hashable {
    case welcome
    case features
    case signup
    case quiz(Int)      // 0...4
    case analysis
    case red(Int)       // 0...3  hard-truth screens
    case green(Int)     // 0...2  the-fix screens
    case social
    case compare
    case goals
    case referral
    case rating
    case timeToWin
    case paywall
    case success

    static let ordered: [FunnelStep] = {
        var s: [FunnelStep] = [.welcome, .features, .signup]
        s += (0..<5).map { .quiz($0) }
        s.append(.analysis)
        s += (0..<4).map { .red($0) }
        s += (0..<3).map { .green($0) }
        s += [.social, .compare, .goals, .referral, .rating, .timeToWin, .paywall, .success]
        return s
    }()

    /// Whether the top progress bar + back button show on this step.
    var showsChrome: Bool {
        switch self {
        case .welcome, .success: return false
        default: return true
        }
    }
}

// MARK: - Container

struct Pick1OnboardingFunnel: View {
    /// Called when the user reaches the end of the funnel. `sports` is the
    /// (optional) set of leagues collected — kept for parity with the legacy
    /// flow's completion signature.
    var onFinish: (_ sports: [String]) -> Void = { _ in }

    @Environment(AuthManager.self) private var authManager
    @EnvironmentObject private var subs: SubscriptionManager

    @State private var index: Int = 0
    @State private var quizAnswers: [Int: Int] = [:]   // question → option
    @State private var selectedGoal: Int? = nil

    private var steps: [FunnelStep] { FunnelStep.ordered }
    private var step: FunnelStep { steps[index] }
    private var progress: Double { Double(index) / Double(steps.count - 1) }

    var body: some View {
        ZStack(alignment: .top) {
            Fnl.ink.ignoresSafeArea()

            // Per-screen content, re-keyed on index so the slide transition
            // fires on every advance.
            screen(for: step)
                .id(index)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity))

            if step.showsChrome { chrome }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: index)
    }

    // MARK: Chrome (progress bar + back)

    private var chrome: some View {
        HStack(spacing: 14) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(Fnl.ink2)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Fnl.panel).overlay(Circle().stroke(Fnl.line, lineWidth: 1)))
            }
            .opacity(index > 0 ? 1 : 0)
            // Progress bar — same row as the back button.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(Fnl.lime)
                        .frame(width: max(4, geo.size.width * CGFloat(progress)))
                        .shadow(color: Fnl.lime.opacity(0.6), radius: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 40)
        }
        .padding(.horizontal, 30)
        .padding(.top, 8)
    }

    // MARK: Navigation

    private func next() {
        if index < steps.count - 1 { index += 1 }
        else { onFinish([]) }
    }
    private func back() { if index > 0 { index -= 1 } }
    /// Jump straight to the account step (Welcome's "Sign in" link).
    private func jumpToSignup() { if let i = steps.firstIndex(of: .signup) { index = i } }

    // MARK: Screen router

    @ViewBuilder
    private func screen(for step: FunnelStep) -> some View {
        switch step {
        case .welcome:   WelcomeScreen(onNext: next, onSignIn: jumpToSignup)
        case .features:  FeaturesScreen(onNext: next)
        case .signup:    SignupScreen(onNext: next)
        case .quiz(let i):
            QuizScreen(index: i, selected: quizAnswers[i]) { opt in
                quizAnswers[i] = opt; next()
            }
        case .analysis:  AnalysisScreen(onDone: next)
        case .red(let i):    RedScreen(index: i, onNext: next)
        case .green(let i):  GreenScreen(index: i, onNext: next)
        case .social:    SocialProofScreen(onNext: next)
        case .compare:   CompareScreen(onNext: next)
        case .goals:     GoalsScreen(selected: $selectedGoal, onNext: next)
        case .referral:  ReferralScreen(onNext: next)
        case .rating:    RatingScreen(onNext: next)
        case .timeToWin: TimeToWinScreen(onNext: next)
        case .paywall:   PaywallScreen(onDone: next)
        case .success:   SuccessScreen(onFinish: { onFinish([]) })
        }
    }
}

// MARK: - Shared building blocks

/// Lime pill CTA — the design's `.cta`.
struct FnlCTA: View {
    let title: String
    var style: Style = .lime
    let action: () -> Void
    enum Style { case lime, ghost, dark }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.anton(style == .ghost ? 16 : 20))
                .kerning(0.4)
                .foregroundColor(style == .lime ? Fnl.ink : (style == .dark ? Fnl.white : Fnl.ink2))
                .frame(maxWidth: .infinity)
                .padding(.vertical, style == .ghost ? 16 : 19)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: style == .lime ? Fnl.lime.opacity(0.35) : .clear, radius: 20, y: 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .lime:  Fnl.lime
        case .ghost: RoundedRectangle(cornerRadius: 16).fill(Color.clear).overlay(RoundedRectangle(cornerRadius: 16).stroke(Fnl.line, lineWidth: 1))
        case .dark:  RoundedRectangle(cornerRadius: 16).fill(Fnl.panel2).overlay(RoundedRectangle(cornerRadius: 16).stroke(Fnl.line, lineWidth: 1))
        }
    }
}

/// Uppercase tracked kicker — the design's `.kick`.
struct FnlKick: View {
    let text: String
    var tone: Tone = .lime
    enum Tone { case lime, red, win }
    var body: some View {
        Text(text.uppercased())
            .font(.archivoNarrow(12, weight: .bold))
            .kerning(2.9)
            .foregroundColor(tone == .red ? Fnl.hot : (tone == .win ? Fnl.win : Fnl.lime))
    }
}

/// Big Anton headline with a lime (or red/win) emphasized tail.
/// `parts` is (text, emphasized) segments; emphasized ones take the accent.
struct FnlHeadline: View {
    let parts: [(String, Bool)]
    var accent: Color = Fnl.lime
    var size: CGFloat = 56
    var center: Bool = false

    /// Split the (text, emphasized) segments into lines on "\n", preserving
    /// each segment's color so a lime tail can sit mid-line. Rendering each
    /// line as its own Text lets a negative VStack spacing pull the lines
    /// together — SwiftUI clamps `lineSpacing` at 0, so it can't tighten
    /// Anton's tall line-height on a single multi-line Text.
    private var lines: [[(String, Bool)]] {
        var out: [[(String, Bool)]] = [[]]
        for (text, emph) in parts {
            let pieces = text.components(separatedBy: "\n")
            for (i, piece) in pieces.enumerated() {
                if i > 0 { out.append([]) }
                if !piece.isEmpty { out[out.count - 1].append((piece, emph)) }
            }
        }
        return out
    }

    var body: some View {
        VStack(alignment: center ? .center : .leading, spacing: -size * 0.27) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                line.reduce(Text("")) { acc, seg in
                    acc + Text(seg.0).foregroundColor(seg.1 ? accent : Fnl.white)
                }
                .font(.anton(size))
                .kerning(0.2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: center ? .infinity : nil, alignment: center ? .center : .leading)
    }
}

/// Body paragraph — the design's `.lead`.
struct FnlLead: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.archivo(16))
            .foregroundColor(Fnl.ink2)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Top radial glow — lime / red / green variants.
struct FnlGlow: View {
    var tone: FnlKick.Tone = .lime
    var body: some View {
        let c: Color = tone == .red ? Fnl.hot : (tone == .win ? Fnl.win : Fnl.lime)
        return RadialGradient(colors: [c.opacity(tone == .lime ? 0.16 : 0.21), .clear],
                              center: .init(x: tone == .lime ? 0.8 : 0.5, y: 0.0),
                              startRadius: 0, endRadius: 340)
            .frame(height: 400)
            .frame(maxWidth: .infinity, alignment: .top)
            // Bleed under the Dynamic Island so the glow starts at the true top
            // of the screen — no seam/line at the safe-area edge.
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

/// Standard screen scaffold: optional glow, a non-scrolling body (everything
/// fits on one screen) with the design's top inset, and a pinned bottom CTA.
struct FnlScreen<C: View, B: View>: View {
    var glow: FnlKick.Tone? = .lime
    @ViewBuilder var content: () -> C
    @ViewBuilder var bottom: () -> B

    var body: some View {
        ZStack(alignment: .top) {
            if let glow { FnlGlow(tone: glow) }
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .padding(.horizontal, 30)
                    .padding(.top, 64)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                VStack(spacing: 0) { bottom() }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 12)
            }
        }
    }
}

/// The design's logo lockup (P1 tile + PICK1 wordmark).
struct FnlLockup: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("P1")
                .font(.anton(24)).foregroundColor(Fnl.ink)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 13).fill(Fnl.lime))
                .shadow(color: Fnl.lime.opacity(0.5), radius: 14)
            (Text("PICK").foregroundColor(Fnl.white) + Text("1").foregroundColor(Fnl.lime))
                .font(.anton(28))
        }
    }
}

// MARK: - Screen: Welcome

private struct WelcomeScreen: View {
    let onNext: () -> Void
    var onSignIn: () -> Void = {}
    var body: some View {
        ZStack(alignment: .top) {
            FnlGlow()
            VStack(spacing: 0) {
                FnlLockup().padding(.top, 24)
                Spacer()
                VStack(spacing: 18) {
                    FnlHeadline(parts: [("WIN\n", false), ("SMARTER.\n", false), ("NOT HARDER.", true)], size: 70, center: true)
                        .multilineTextAlignment(.center)
                    FnlLead(text: "The AI that calls one game a day across 9 sports — and logs every result in public.")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                Spacer()
                VStack(spacing: 0) {
                    FnlCTA(title: "GET STARTED →", action: onNext)
                    Button(action: onSignIn) {
                        (Text("Already a member? ").foregroundColor(Fnl.mute)
                         + Text("Sign in").foregroundColor(Fnl.lime))
                            .font(.mono(11, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30)
            .padding(.top, 60)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Screen: Features

private struct FeaturesScreen: View {
    let onNext: () -> Void
    private let feats: [(String, String, String)] = [
        ("🎯", "One daily AI pick", "The single highest-edge call across NBA, NFL, EPL, MLB, UFC, NHL, F1, Tennis & Cricket."),
        ("📊", "Calibrated confidence", "When it says 73%, it hits ≈73%. A measured forecast — never a \"guaranteed lock.\""),
        ("🧾", "Public results ledger", "Every call logged before kickoff. Wins AND losses, on the record forever."),
        ("💰", "Best line, 6 books", "Pick1 finds the best price across 6 sportsbooks — you decide where to play."),
    ]
    var body: some View {
        FnlScreen {
            FnlKick(text: "Meet Pick1").padding(.bottom, 14)
            FnlHeadline(parts: [("ONE APP.\n", false), ("EVERY ", false), ("EDGE.", true)])
            VStack(spacing: 0) {
                ForEach(Array(feats.enumerated()), id: \.offset) { i, f in
                    HStack(alignment: .top, spacing: 16) {
                        Text(f.0)
                            .font(.system(size: 24))
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 13).fill(Fnl.lime.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Fnl.lime.opacity(0.3), lineWidth: 1)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(f.1).font(.anton(19)).foregroundColor(Fnl.white)
                            Text(f.2).font(.archivo(13.5)).foregroundColor(Fnl.ink2).lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 16)
                    if i < feats.count - 1 { Rectangle().fill(Fnl.line).frame(height: 1) }
                }
            }
            .padding(.top, 26)
        } bottom: {
            FnlCTA(title: "CONTINUE →", action: onNext)
        }
    }
}

// MARK: - Screen: Sign up (placeholder auth — wired in Phase 3)

private struct SignupScreen: View {
    let onNext: () -> Void
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var code = ""
    @State private var otpSent = false
    @State private var busy = false
    @State private var appleNonce = ""

    var body: some View {
        FnlScreen {
            FnlKick(text: otpSent ? "Check your email" : "Create account").padding(.bottom, 14)
            FnlHeadline(parts: otpSent ? [("ENTER\n", false), ("YOUR CODE.", true)] : [("JOIN THE\n", false), ("1,000+.", true)])

            if !otpSent {
                SignInWithAppleButton(.signUp) { req in
                    let nonce = randomNonceString(); appleNonce = nonce
                    req.requestedScopes = [.fullName, .email]
                    req.nonce = sha256Hex(nonce)
                } onCompletion: { result in handleApple(result) }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 26)

                HStack(spacing: 12) {
                    Rectangle().fill(Fnl.line).frame(height: 1)
                    Text("OR").font(.archivoNarrow(10, weight: .bold)).kerning(2).foregroundColor(Fnl.mute)
                    Rectangle().fill(Fnl.line).frame(height: 1)
                }
                .padding(.vertical, 18)
                fnlField(label: "Email", text: $email, placeholder: "you@email.com")
                    .textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
            } else {
                FnlLead(text: "We sent a 6-digit code to \(email). Enter it to finish signing in.").padding(.top, 22)
                fnlField(label: "Verification code", text: $code, placeholder: "123456")
                    .keyboardType(.numberPad)
                Button("Use a different email") { otpSent = false; code = "" }
                    .font(.archivo(13, weight: .medium)).foregroundColor(Fnl.lime)
            }

            if let e = auth.error, !e.isEmpty {
                Text(e).font(.archivo(13)).foregroundColor(Fnl.hot).padding(.top, 10)
            }
        } bottom: {
            VStack(spacing: 0) {
                FnlCTA(title: busy ? "…" : (otpSent ? "VERIFY →" : "CONTINUE WITH EMAIL →")) {
                    Task { await primary() }
                }
                if !otpSent {
                    Text("BY JOINING YOU AGREE TO OUR TERMS · 21+")
                        .font(.mono(11, weight: .bold)).foregroundColor(Fnl.mute).padding(.top, 14)
                }
            }
        }
        .onChange(of: auth.isAuthenticated) { _, v in if v { onNext() } }
        // Returning user who's already signed in but hasn't finished the
        // funnel — skip the account step rather than trapping them on it
        // (isAuthenticated is already true, so onChange never fires).
        .onAppear { if auth.isAuthenticated { onNext() } }
    }

    private func primary() async {
        busy = true; defer { busy = false }
        if !otpSent {
            guard email.contains("@"), email.contains(".") else { return }
            await auth.sendOTP(email: email)
            if auth.error == nil { withAnimation { otpSent = true } }
        } else {
            await auth.verifyOTP(email: email, token: code.trimmingCharacters(in: .whitespaces))
            // Success flips auth.isAuthenticated → onChange advances.
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authz):
            guard let cred = authz.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else { return }
            Task {
                await auth.signInWithApple(idToken: idToken, nonce: appleNonce,
                                           firstName: cred.fullName?.givenName,
                                           lastName: cred.fullName?.familyName)
            }
        case .failure(let error):
            if let e = error as? ASAuthorizationError, e.code == .canceled { return }
        }
    }
}

/// The design's `.field` input.
private func fnlField(label: String, text: Binding<String>, placeholder: String, secure: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(label.uppercased()).font(.archivoNarrow(11, weight: .bold)).kerning(2.2).foregroundColor(Fnl.mute)
        Group {
            if secure { SecureField("", text: text, prompt: Text(placeholder).foregroundColor(Fnl.mute)) }
            else { TextField("", text: text, prompt: Text(placeholder).foregroundColor(Fnl.mute)) }
        }
        .font(.archivo(16)).foregroundColor(Fnl.white)
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Fnl.panel).overlay(RoundedRectangle(cornerRadius: 14).stroke(Fnl.line, lineWidth: 1)))
    }
    .padding(.bottom, 16)
}

// MARK: - Screen: Quiz

private struct QuizScreen: View {
    let index: Int
    let selected: Int?
    let onPick: (Int) -> Void

    static let questions: [(String, [(String, String)])] = [
        ("How often do you bet on sports?", [("📅","Every day"),("🗓️","A few times a week"),("🎲","Weekends only"),("🆕","Just getting started")]),
        ("How do you pick your bets today?", [("🧠","Gut feeling"),("📰","News & headlines"),("📊","Some stats"),("🤷","Honestly? Random")]),
        ("Are you up or down this year?", [("📉","Down money"),("➖","About even"),("📈","Slightly up"),("🤔","No idea — I don't track")]),
        ("What frustrates you most?", [("😤","Losing on 'sure things'"),("🎰","Chasing parlays"),("🕳️","No idea what works"),("⏱️","Too much time researching")]),
        ("How much do you bet per week?", [("💵","Under $50"),("💰","$50–$200"),("💸","$200–$500"),("🏦","$500+")]),
    ]

    var body: some View {
        let q = Self.questions[index]
        return VStack(alignment: .leading, spacing: 0) {
            Text("Question \(index + 1) of 5")
                .font(.mono(13, weight: .bold)).kerning(1.9).foregroundColor(Fnl.lime)
                .padding(.bottom, 10)
            Text(q.0.uppercased())
                .font(.anton(34)).foregroundColor(Fnl.white).lineSpacing(-6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 26)
            VStack(spacing: 12) {
                ForEach(Array(q.1.enumerated()), id: \.offset) { i, opt in
                    Button { onPick(i) } label: {
                        HStack(spacing: 14) {
                            Text(opt.0).font(.system(size: 26))
                            Text(opt.1).font(.archivo(16, weight: .bold)).foregroundColor(Fnl.white)
                            Spacer(minLength: 0)
                            ZStack {
                                Circle().stroke(selected == i ? Fnl.lime : Fnl.line, lineWidth: 2)
                                    .background(Circle().fill(selected == i ? Fnl.lime : .clear))
                                if selected == i {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundColor(Fnl.ink)
                                }
                            }
                            .frame(width: 26, height: 26)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 16).fill(selected == i ? Fnl.lime.opacity(0.08) : Fnl.panel)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected == i ? Fnl.lime : Fnl.line, lineWidth: 2)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Screen: Analysis (animated ring 0→100 + checklist)

private struct AnalysisScreen: View {
    let onDone: () -> Void
    @State private var pct: Int = 0
    @State private var litRows = 0
    private let rows = ["Scanning your betting habits…", "Measuring your edge vs the books…", "Finding where you lose money…", "Building your Pick1 plan…"]

    var body: some View {
        ZStack(alignment: .top) {
            FnlGlow()
            VStack(spacing: 0) {
                FnlKick(text: "Analyzing your answers").frame(maxWidth: .infinity)
                ZStack {
                    Circle().stroke(Color(hex: "#22252b"), lineWidth: 7)
                    Circle().trim(from: 0, to: CGFloat(pct) / 100)
                        .stroke(Fnl.lime, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(pct)%").font(.anton(56)).foregroundColor(Fnl.lime)
                }
                .frame(width: 180, height: 180)
                .padding(.top, 30)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(i < litRows ? Fnl.lime : Fnl.line)
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy))
                                    .foregroundColor(i < litRows ? Fnl.ink : Fnl.mute)
                            }.frame(width: 26, height: 26)
                            Text(r).font(.archivo(15)).foregroundColor(i < litRows ? Fnl.white : Fnl.ink2)
                        }
                        .opacity(i < litRows ? 1 : 0.3)
                    }
                }
                .padding(.top, 26)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 30)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 2.6)) { pct = 100 }
            // tick the counter + light rows
            for i in 1...100 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.6 * Double(i) / 100) { pct = i }
            }
            for i in 0..<rows.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.6) { litRows = i + 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { onDone() }
        }
    }
}

// MARK: - Screen: Red "hard truth"

private struct RedScreen: View {
    let index: Int
    let onNext: () -> Void
    static let data: [(head: [(String, Bool)], stat: String, statSmall: String, lead: String, ct: String, cb: String, cta: String)] = [
        ([("YOU BET ON\n", false), ("EMOTION.", true)], "55", "%", "Gut picks lose ~55% of the time long-term. Your favorite team isn't a strategy.", "No system = no edge", "Without a model, you're just guessing against people who aren't.", "NEXT →"),
        ([("PARLAYS ARE\n", false), ("KILLING YOU.", true)], "-32", "%", "The average multi-leg parlay returns -32% to the bettor. The house loves them for a reason.", "Chasing the big hit", "Every extra leg multiplies the house edge against you.", "NEXT →"),
        ([("YOU DON'T\n", false), ("TRACK IT.", true)], "0", "records", "You can't fix what you don't measure. Most bettors have no idea if they're actually up or down.", "Flying blind", "No log means no learning — you repeat the same losing bets.", "NEXT →"),
        ([("BAD LINES\n", false), ("DRAIN YOU.", true)], "-5", "%/bet", "Taking the first line you see leaves 3–5% on the table every single bet. It compounds fast.", "Overpaying the vig", "You never shop for the best price across books — so you always overpay.", "SHOW ME THE FIX →"),
    ]
    var body: some View {
        let d = Self.data[index]
        FnlScreen(glow: .red) {
            HStack(spacing: 6) {
                ForEach(0..<4) { i in Capsule().fill(i <= index ? Fnl.hot : Fnl.line).frame(width: 22, height: 4) }
            }.padding(.bottom, 14)
            FnlKick(text: "The hard truth · \(index + 1) of 4", tone: .red).padding(.bottom, 14)
            FnlHeadline(parts: d.head, accent: Fnl.hot)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(d.stat).font(.anton(72)).foregroundColor(Fnl.hot)
                Text(d.statSmall).font(.archivo(18, weight: .bold)).foregroundColor(Fnl.ink2)
            }.padding(.top, 24)
            FnlLead(text: d.lead).padding(.top, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(d.ct).font(.archivo(15, weight: .bold)).foregroundColor(Fnl.white)
                Text(d.cb).font(.archivo(12.5)).foregroundColor(Fnl.ink2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Fnl.hot.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Fnl.hot.opacity(0.28), lineWidth: 1)))
            .padding(.top, 20)
        } bottom: {
            FnlCTA(title: d.cta, action: onNext)
        }
    }
}

// MARK: - Screen: Green "the fix"

private struct GreenScreen: View {
    let index: Int
    let onNext: () -> Void
    static let data: [(kick: String, head: [(String, Bool)], lead: String, cta: String)] = [
        ("The Pick1 fix · 1 of 3", [("DATA, NOT\n", false), ("EMOTION.", true)], "One AI-calculated pick a day — the single highest-edge call across 9 sports.", "NEXT →"),
        ("The Pick1 fix · 2 of 3", [("SEE THE\n", false), ("REASONING.", true)], "Calibrated confidence + the \"why\" behind every pick. When it says 73%, it hits ≈73%.", "NEXT →"),
        ("The Pick1 fix · 3 of 3", [("TRACK\n", false), ("EVERYTHING.", true)], "Every call logged in public — wins and losses. Live tracking and a full ROI dashboard.", "CONTINUE →"),
    ]
    var body: some View {
        let d = Self.data[index]
        FnlScreen(glow: .win) {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in Capsule().fill(i <= index ? Fnl.win : Fnl.line).frame(width: 22, height: 4) }
            }.padding(.bottom, 14)
            FnlKick(text: d.kick, tone: .win).padding(.bottom, 14)
            FnlHeadline(parts: d.head, accent: Fnl.win)
            FnlLead(text: d.lead).padding(.top, 16)
            // Phone-in-phone app preview placeholder (fleshed out in Phase 2 polish)
            RoundedRectangle(cornerRadius: 24).fill(Fnl.panel)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Fnl.line, lineWidth: 1))
                .frame(height: 230)
                .overlay(Image(systemName: "iphone").font(.system(size: 44)).foregroundColor(Fnl.mute))
                .padding(.top, 24)
        } bottom: {
            FnlCTA(title: d.cta, action: onNext)
        }
    }
}

// MARK: - Screen: Success

private struct SuccessScreen: View {
    let onFinish: () -> Void
    var body: some View {
        ZStack(alignment: .top) {
            FnlGlow(tone: .win)
            VStack(spacing: 0) {
                FnlLockup().padding(.top, 24)
                Spacer()
                VStack(spacing: 18) {
                    Text("🎉").font(.system(size: 70))
                    FnlHeadline(parts: [("YOU'RE IN.\n", false), ("LET'S ", false), ("WIN.", true)], accent: Fnl.win, size: 60, center: true)
                        .multilineTextAlignment(.center)
                    FnlLead(text: "Welcome to Pick1 Pro. Your first daily pick drops tomorrow at 6:30 AM.")
                        .multilineTextAlignment(.center).frame(maxWidth: 290)
                }
                Spacer()
                FnlCTA(title: "START YOUR JOURNEY →", action: onFinish)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30).padding(.top, 60).padding(.bottom, 20)
        }
    }
}

// MARK: - Screen: Social proof

private struct SocialProofScreen: View {
    let onNext: () -> Void
    private let tsts: [(av: String, name: String, sub: String, won: String, quote: String)] = [
        ("M", "Marcus B.", "@marcus_b · Chicago", "+$10.4K", "Followed Pick1 blind for 3 weeks. Up almost eleven grand. The calibration is unreal."),
        ("S", "Sara L.", "@sara_l · 11–2 ATS", "+$4.2K", "I stopped betting parlays and just take the daily pick. Best decision I made."),
        ("A", "Alex K.", "@alexk · $50→$2.4K", "+$2.4K", "Turned $50 into $2,400 in a month. The public ledger sold me — no hiding losses."),
    ]
    var body: some View {
        FnlScreen {
            FnlKick(text: "Real members · real wins").padding(.bottom, 14)
            FnlHeadline(parts: [("$289K WON\n", false), ("THIS ", false), ("SEASON.", true)])
            VStack(spacing: 12) {
                ForEach(Array(tsts.enumerated()), id: \.offset) { _, t in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Text(t.av).font(.anton(18)).foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(LinearGradient(colors: [Color(hex: "#6b46c1"), Color(hex: "#ec4899")], startPoint: .topLeading, endPoint: .bottomTrailing)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name).font(.archivo(14, weight: .bold)).foregroundColor(Fnl.white)
                                Text(t.sub).font(.mono(11)).foregroundColor(Fnl.mute)
                            }
                            Spacer(minLength: 0)
                            Text(t.won).font(.anton(24)).foregroundColor(Fnl.win)
                        }
                        Text("\"\(t.quote)\"").font(.archivo(14)).italic().foregroundColor(Fnl.ink2).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("★★★★★").font(.system(size: 15)).foregroundColor(Color(hex: "#ffd84d"))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Fnl.panel).overlay(RoundedRectangle(cornerRadius: 18).stroke(Fnl.line, lineWidth: 1)))
                }
            }
            .padding(.top, 24)
        } bottom: {
            FnlCTA(title: "I WANT IN →", action: onNext)
        }
    }
}

// MARK: - Screen: Comparison chart

private struct CompareScreen: View {
    let onNext: () -> Void
    private let rows = ["Calibrated %", "Public win/loss log", "Logged before kickoff", "Best-line finder", "No \"guaranteed locks\"", "9 sports, one call"]
    var body: some View {
        FnlScreen {
            FnlKick(text: "Why Pick1 wins").padding(.bottom, 14)
            FnlHeadline(parts: [("THE ", false), ("DIFFERENCE.", true)])
            VStack(spacing: 0) {
                HStack {
                    Text("FEATURE").font(.archivoNarrow(11, weight: .bold)).kerning(1.9).foregroundColor(Fnl.mute)
                    Spacer()
                    Text("OTHERS").font(.archivoNarrow(11, weight: .bold)).kerning(1.9).foregroundColor(Fnl.mute).frame(width: 70)
                    Text("PICK1").font(.archivoNarrow(11, weight: .bold)).kerning(1.9).foregroundColor(Fnl.lime).frame(width: 70)
                }
                .padding(.horizontal, 18).padding(.vertical, 16)
                .background(Fnl.panel2)
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    HStack {
                        Text(r).font(.archivo(13.5, weight: .medium)).foregroundColor(Fnl.white)
                        Spacer()
                        Text("✕").font(.system(size: 18)).foregroundColor(Fnl.hot).frame(width: 70)
                        Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundColor(Fnl.win).frame(width: 70)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 16)
                    if i < rows.count - 1 { Rectangle().fill(Fnl.line).frame(height: 1) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(Fnl.panel))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Fnl.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.top, 24)
        } bottom: {
            FnlCTA(title: "CONTINUE →", action: onNext)
        }
    }
}

// MARK: - Screen: Goals

private struct GoalsScreen: View {
    @Binding var selected: Int?
    let onNext: () -> Void
    private let goals: [(String, String)] = [
        ("💸", "Grow my bankroll steadily"), ("🎯", "Beat the sportsbooks"),
        ("📈", "Bet smarter, lose less"), ("🏆", "Go pro / full-time"),
    ]
    var body: some View {
        FnlScreen {
            FnlKick(text: "Set your target").padding(.bottom, 14)
            FnlHeadline(parts: [("WHAT'S YOUR\n", false), ("GOAL?", true)])
            FnlLead(text: "We'll tailor your daily picks around it.").padding(.top, 16)
            VStack(spacing: 12) {
                ForEach(Array(goals.enumerated()), id: \.offset) { i, g in
                    Button { selected = i } label: {
                        HStack(spacing: 14) {
                            Text(g.0).font(.system(size: 24))
                            Text(g.1).font(.archivo(16, weight: .semibold)).foregroundColor(Fnl.white)
                            Spacer(minLength: 0)
                            ZStack {
                                Circle().stroke(selected == i ? Fnl.lime : Fnl.line, lineWidth: 2)
                                    .background(Circle().fill(selected == i ? Fnl.lime : .clear))
                                if selected == i { Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundColor(Fnl.ink) }
                            }.frame(width: 26, height: 26)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 16).fill(selected == i ? Fnl.lime.opacity(0.08) : Fnl.panel)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected == i ? Fnl.lime : Fnl.line, lineWidth: 2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 22)
        } bottom: {
            FnlCTA(title: "CONTINUE →", action: onNext)
        }
    }
}

// MARK: - Screen: Referral (code = free week of Pro)

private struct ReferralScreen: View {
    let onNext: () -> Void
    @EnvironmentObject private var subs: SubscriptionManager
    @State private var code = ""
    @State private var busy = false
    @State private var banner: (text: String, ok: Bool)?

    var body: some View {
        FnlScreen {
            FnlKick(text: "Got a code?").padding(.bottom, 14)
            FnlHeadline(parts: [("UNLOCK\n", false), ("YOUR ", false), ("BONUS.", true)])
            FnlLead(text: "Enter a friend's or creator's code — unlock a free week of Pro.").padding(.top, 16)
            fnlField(label: "Referral code (optional)", text: $code, placeholder: "PICK1-XXXX")
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(.top, 22)
            if let b = banner {
                Text(b.text).font(.archivo(13, weight: .medium)).foregroundColor(b.ok ? Fnl.lime : Fnl.hot)
            }
        } bottom: {
            VStack(spacing: 10) {
                FnlCTA(title: busy ? "…" : "CONTINUE →") { Task { await apply() } }
                FnlCTA(title: "Skip for now", style: .ghost, action: onNext)
            }
        }
    }

    private func apply() async {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { onNext(); return }
        busy = true; defer { busy = false }
        let outcome = await ReferralManager.shared.redeem(trimmed)
        switch outcome {
        case .success(let grantedPro):
            await subs.refreshCompAccess()
            banner = (grantedPro ? "🎉 Code applied — a free week of Pro is on us!" : "✓ Code applied!", true)
            try? await Task.sleep(nanoseconds: 700_000_000)
            onNext()
        case .invalid, .ownCode: banner = ("That code isn't valid.", false)
        case .alreadyUsed: banner = ("You've already used a code.", false)
        case .error: banner = ("Something went wrong — try again.", false)
        }
    }
}

// MARK: - Screen: Rating (+3 days reward)

private struct RatingScreen: View {
    let onNext: () -> Void
    @EnvironmentObject private var subs: SubscriptionManager
    var body: some View {
        ZStack(alignment: .top) {
            FnlGlow()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 16) {
                    FnlKick(text: "Help us grow").frame(maxWidth: .infinity)
                    FnlHeadline(parts: [("LOVE ", false), ("PICK1?", true)], center: true)
                    FnlLead(text: "Rate us on the App Store — it takes 5 seconds and unlocks a reward.")
                        .multilineTextAlignment(.center).frame(maxWidth: 300)
                    Text("★★★★★").font(.system(size: 40)).foregroundColor(Color(hex: "#ffd84d")).padding(.top, 14)
                    VStack(spacing: 4) {
                        Text("+3 DAYS").font(.anton(28)).foregroundColor(Fnl.lime)
                        Text("Bonus Pro access, on us — just for rating.").font(.archivo(13)).foregroundColor(Fnl.ink2)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Fnl.lime.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Fnl.lime.opacity(0.3), lineWidth: 1)))
                }
                Spacer()
                VStack(spacing: 10) {
                    FnlCTA(title: "RATE & CLAIM →") {
                        RatingsPrompt.maybeRequest(hasPositiveSignal: true)
                        Task {
                            // +3 days comp grant (idempotent, server-side).
                            try? await SupabaseManager.client.rpc("claim_rating_reward").execute()
                            await subs.refreshCompAccess()
                        }
                        onNext()
                    }
                    FnlCTA(title: "Maybe later", style: .ghost, action: onNext)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30).padding(.top, 64).padding(.bottom, 20)
        }
    }
}

// MARK: - Screen: Time to win

private struct TimeToWinScreen: View {
    let onNext: () -> Void
    var body: some View {
        ZStack(alignment: .top) {
            FnlGlow(tone: .win)
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 20) {
                    FnlKick(text: "You're all set", tone: .win).frame(maxWidth: .infinity)
                    FnlHeadline(parts: [("NOW IT'S\n", false), ("TIME TO\n", false), ("WIN.", true)], accent: Fnl.win, size: 76, center: true)
                        .multilineTextAlignment(.center)
                    FnlLead(text: "Your personalized daily pick is ready. One tap away.")
                        .multilineTextAlignment(.center).frame(maxWidth: 290)
                }
                Spacer()
                FnlCTA(title: "SEE MY PLAN →", action: onNext)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30).padding(.top, 64).padding(.bottom, 20)
        }
    }
}

// MARK: - Screen: Paywall (Weekly / Monthly / Lifetime · no trial)

private struct PaywallScreen: View {
    let onDone: () -> Void
    @EnvironmentObject private var subs: SubscriptionManager
    @State private var selected: String = SubscriptionManager.lifetimeProductId
    @State private var busy = false

    private let feats = [
        "Daily AI pick across 9 sports", "Calibrated confidence + reasoning",
        "Public ledger, live tracking & ROI", "Best line across 6 sportsbooks",
    ]

    var body: some View {
        FnlScreen {
            FnlKick(text: "Go Pro").padding(.bottom, 14)
            FnlHeadline(parts: [("UNLOCK\n", false), ("EVERY ", false), ("PICK.", true)])
            VStack(alignment: .leading, spacing: 10) {
                ForEach(feats, id: \.self) { f in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundColor(Fnl.ink)
                            .frame(width: 20, height: 20).background(Circle().fill(Fnl.lime))
                        Text(f).font(.archivo(14, weight: .medium)).foregroundColor(Fnl.white)
                    }
                }
            }
            .padding(.top, 18)
            VStack(spacing: 10) {
                ForEach(subs.products, id: \.id) { p in
                    planCard(p)
                }
                if subs.products.isEmpty {
                    Text("Loading plans…").font(.archivo(13)).foregroundColor(Fnl.mute).padding(.vertical, 20)
                }
            }
            .padding(.top, 18)
        } bottom: {
            VStack(spacing: 0) {
                FnlCTA(title: busy ? "…" : (subs.isPro ? "CONTINUE →" : "UNLOCK PICK1 PRO →")) {
                    Task { await act() }
                }
                Text("NO FREE TRIAL · CANCEL ANYTIME · SECURE CHECKOUT")
                    .font(.mono(11, weight: .bold)).foregroundColor(Fnl.mute).padding(.top, 14)
                    .multilineTextAlignment(.center)
            }
        }
        .onChange(of: subs.isPro) { _, v in if v { onDone() } }
    }

    @ViewBuilder private func planCard(_ p: Product) -> some View {
        let isSel = selected == p.id
        let isLife = p.id == SubscriptionManager.lifetimeProductId
        Button { selected = p.id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(planName(p)).font(.anton(20)).foregroundColor(Fnl.white)
                    Text(planSub(p)).font(.archivo(12)).foregroundColor(Fnl.ink2)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(p.displayPrice).font(.anton(22)).foregroundColor(isSel ? Fnl.lime : Fnl.white)
                    Text(planUnit(p)).font(.archivo(12)).foregroundColor(Fnl.ink2)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(isSel ? Fnl.lime.opacity(0.08) : Fnl.panel)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSel ? Fnl.lime : Fnl.line, lineWidth: isSel ? 2 : 1)))
            .overlay(alignment: .topTrailing) {
                if isLife {
                    Text("BEST VALUE").font(.archivoNarrow(9, weight: .bold)).kerning(1.4).foregroundColor(Fnl.ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Fnl.lime)).offset(x: -12, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func planName(_ p: Product) -> String {
        if p.id.hasSuffix("weekly") { return "WEEKLY" }
        if p.id.hasSuffix("monthly") { return "MONTHLY" }
        if p.id == SubscriptionManager.lifetimeProductId { return "LIFETIME" }
        return p.displayName.uppercased()
    }
    private func planUnit(_ p: Product) -> String {
        if p.id.hasSuffix("weekly") { return "/wk" }
        if p.id.hasSuffix("monthly") { return "/mo" }
        return ""
    }
    private func planSub(_ p: Product) -> String {
        if p.id == SubscriptionManager.lifetimeProductId { return "One-time · yours forever" }
        return "Billed \(p.id.hasSuffix("weekly") ? "weekly" : "monthly") · cancel anytime"
    }

    private func act() async {
        if subs.isPro { onDone(); return }
        guard let p = subs.products.first(where: { $0.id == selected }) ?? subs.products.first else { return }
        busy = true; defer { busy = false }
        await subs.purchase(p)   // onChange(isPro) advances on success
    }
}

#if DEBUG
#Preview("Funnel") {
    Pick1OnboardingFunnel()
}
#endif
