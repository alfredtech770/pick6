// Pick6Screens.swift
// Individual screen views for the Pick6 onboarding flow.

import SwiftUI

// MARK: - Welcome

struct WelcomeScreen: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("⚡")
                .font(.system(size: 72))
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: appeared)
                .padding(.bottom, 16)

            Text("FIND YOUR")
                .font(.custom("BarlowCondensed-Black", size: 52))
                .kerning(-2)
                .foregroundColor(.white)
                .textCase(.uppercase)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.easeOut(duration: 0.45).delay(0.1), value: appeared)

            Text("BETTING EDGE")
                .font(.custom("BarlowCondensed-Black", size: 52))
                .kerning(-2)
                .foregroundColor(Color.white.opacity(0.16))
                .textCase(.uppercase)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.easeOut(duration: 0.45).delay(0.18), value: appeared)

            Text("6 quick questions.\nA personalised AI profile.\nA hard truth about your betting.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.top, 18)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.easeOut(duration: 0.45).delay(0.26), value: appeared)

            HStack(spacing: 8) {
                Text("🔒")
                Text("Anonymous · 60 seconds")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.top, 20)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.45).delay(0.34), value: appeared)

            Spacer()

            P6Button("Let's Find Out →", action: onNext)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .animation(.easeOut(duration: 0.45).delay(0.42), value: appeared)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .onAppear { appeared = true }
    }
}

// MARK: - Quiz Question

struct QuestionScreen: View {
    let question: QuizQuestion
    let index: Int
    let total: Int
    let onAnswer: (String) -> Void

    @State private var chosen: String? = nil
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Counter
            Text("Question \(index + 1) of \(total)")
                .font(.custom("BarlowCondensed-Bold", size: 10))
                .kerning(2)
                .textCase(.uppercase)
                .foregroundColor(Color.white.opacity(0.35))
                .padding(.bottom, 18)

            // Question title
            Text(question.question)
                .font(.custom("BarlowCondensed-Black", size: 30))
                .kerning(-0.8)
                .textCase(.uppercase)
                .foregroundColor(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.3).delay(0.04), value: appeared)

            // Subtitle
            Text(question.subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55))
                .padding(.top, 6)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.1), value: appeared)

            // Options
            ForEach(Array(question.options.enumerated()), id: \.element.id) { i, opt in
                let isChosen = chosen == opt.id
                let isDimmed = chosen != nil && !isChosen

                Button {
                    if chosen == nil {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { chosen = opt.id }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { onAnswer(opt.id) }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opt.label)
                                .font(.custom("BarlowCondensed-Black", size: 18))
                                .textCase(.uppercase)
                                .foregroundColor(.white)
                            Text(opt.subtitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color.white.opacity(isChosen ? 0.6 : 0.55))
                        }
                        Spacer()
                        // Radio
                        ZStack {
                            Circle()
                                .stroke(isChosen ? question.accentColor : Color.white.opacity(0.22), lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if isChosen {
                                Circle().fill(question.accentColor).frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isChosen)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 15)
                    .background(isChosen ? question.accentColor.opacity(0.16) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isChosen ? question.accentColor : Color.white.opacity(0.1), lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .opacity(isDimmed ? 0.2 : 1.0)
                    .scaleEffect(isChosen ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.3).delay(0.1 + Double(i) * 0.06), value: appeared)
                .padding(.bottom, i < question.options.count - 1 ? 9 : 0)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .onAppear { appeared = true }
    }
}

// MARK: - Processing

struct ProcessingScreen: View {
    let profile: BettorProfile
    let onDone: () -> Void

    private let steps = [
        "Mapping your betting behaviour",
        "Calculating your loss patterns",
        "Building your risk profile",
        "Generating your personalised plan",
    ]

    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Radar rings
            ZStack {
                ForEach([196, 180, 148, 116], id: \.self) { size in
                    Circle()
                        .stroke(Color.p6Red.opacity(size == 180 ? 0.0 : 0.12), lineWidth: size == 180 ? 1.5 : 1)
                        .frame(width: CGFloat(size), height: CGFloat(size))
                }
                // Rotating ring
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(colors: [.p6Red.opacity(0.7), .p6Red.opacity(0.15), .clear],
                                        center: .center),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(rotation))
                // Counter-rotating
                Circle()
                    .trim(from: 0, to: 0.4)
                    .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1))
                    .frame(width: 148, height: 148)
                    .rotationEffect(.degrees(-rotation * 0.6))
                // Ping rings
                PingRing(color: .p6Red, delay: 0)
                PingRing(color: .p6Red, delay: 0.65)
                // Center dot
                Circle()
                    .fill(Color.p6Red)
                    .frame(width: 16, height: 16)
                    .shadow(color: .p6Red.opacity(0.8), radius: 10)
            }
            .frame(width: 200, height: 200)
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .padding(.bottom, 32)

            Text("Analysing\nYour Profile")
                .font(.custom("BarlowCondensed-Black", size: 36))
                .kerning(-1)
                .textCase(.uppercase)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .padding(.bottom, 8)

            if currentStep < steps.count {
                Text(steps[currentStep] + "...")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .id(currentStep)
            }

            Spacer()

            // Step list
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.08)).padding(.bottom, 18)

                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    let done = completedSteps.contains(i)
                    let active = i == currentStep

                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(done ? Color.p6Green : Color.white.opacity(0.15), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if done {
                                Circle().fill(Color.p6Green).frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: done)

                        Text(step)
                            .font(.system(size: 14, weight: done ? .medium : .regular))
                            .foregroundColor(done ? Color.white.opacity(0.85) : Color.white.opacity(0.45))
                            .animation(.easeOut(duration: 0.3), value: done)

                        Spacer()
                    }
                    .padding(.vertical, 11)
                    .opacity(done || active ? 1 : 0.28)
                    .animation(.easeOut(duration: 0.4), value: done || active)

                    if i < steps.count - 1 {
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .onAppear { startSequence() }
    }

    private func startSequence() {
        for i in 0..<steps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i + 1) * 0.7) {
                withAnimation { completedSteps.insert(i) }
                if i < steps.count - 1 {
                    withAnimation { currentStep = i + 1 }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) { onDone() }
    }
}

// Ping ring animation
private struct PingRing: View {
    let color: Color
    let delay: Double
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0.8

    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 1.5)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(delay)) {
                    scale = 2.5
                    opacity = 0
                }
            }
    }
}

// MARK: - Issue Screen 1: Profile Reveal

struct IssueRevealScreen: View {
    let profile: BettorProfile
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StepDots(current: 0, total: 3, color: .p6Red)
                Spacer()
                Text("1 of 3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.p6Red.opacity(0.65))
            }
            .padding(.bottom, 18)

            // Full-height profile card
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient.issueCard)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.p6Red.opacity(0.45), lineWidth: 1.5)
                // Radial glow
                RadialGradient(colors: [Color.p6Red.opacity(0.18), .clear], center: .init(x: 0.2, y: 0.2), startRadius: 0, endRadius: 200)

                VStack(alignment: .leading, spacing: 0) {
                    P6LiveBadge(label: "Profile identified", color: .p6Red)
                        .padding(.bottom, 16)

                    Text(profile.name)
                        .font(.custom("BarlowCondensed-Black", size: 40))
                        .kerning(-1)
                        .textCase(.uppercase)
                        .foregroundColor(.white)
                        .lineSpacing(-2)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
                        .padding(.bottom, 10)

                    Text(profile.tag)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#ff7878").opacity(0.9))
                        .padding(.bottom, 10)

                    Text(profile.summary)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#ffddd0").opacity(0.78))
                        .lineSpacing(4)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 240)

            // Stats
            HStack(spacing: 8) {
                ForEach(profile.stats, id: \.number) { stat in
                    StatChipRed(number: stat.number, label: stat.label)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
                }
            }
            .padding(.top, 12)

            Spacer()

            P6Button("The hard truth →", gradient: .redDeep, action: onNext)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .onAppear { appeared = true }
    }
}

// MARK: - Issue Screen 2: Pain Detail

struct IssuePainScreen: View {
    let profile: BettorProfile
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StepDots(current: 1, total: 3, color: .p6Red)
                Spacer()
                Text("2 of 3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.p6Red.opacity(0.65))
            }
            .padding(.bottom, 18)

            Text(profile.pain.uppercased())
                .font(.custom("BarlowCondensed-Black", size: 38))
                .kerning(-1)
                .foregroundColor(.white)
                .lineSpacing(-2)
                .padding(.bottom, 4)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: appeared)

            Text(profile.tag)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(hex: "#ff7878").opacity(0.6))
                .padding(.bottom, 18)

            // Main card
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient.issueCard)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.p6Red.opacity(0.4), lineWidth: 1.5)
                RadialGradient(colors: [Color.p6Red.opacity(0.1), .clear], center: .init(x: 0.8, y: 0.8), startRadius: 0, endRadius: 180)

                VStack(alignment: .leading, spacing: 14) {
                    Text("🚨")
                        .font(.system(size: 28))
                    Text(profile.painDetail)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "#ffdcdc").opacity(0.88))
                        .lineSpacing(5)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)

            // Quote strip
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.p6Red.opacity(0.55))
                    .frame(width: 3)
                Text("\u{201C}\(profile.painQuote)\u{201D}")
                    .font(.system(size: 13, weight: .medium))
                    .italic()
                    .foregroundColor(Color(hex: "#ffafaf").opacity(0.82))
                    .lineSpacing(3)
                    .padding(.leading, 14).padding(.vertical, 12)
                Spacer()
            }
            .background(Color.p6Red.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.top, 12)

            Spacer()

            P6Button("See how to fix this →", gradient: .redDeep, action: onNext)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .onAppear { appeared = true }
    }
}

// MARK: - Issue Screen 3: Annual Cost

struct IssueCostScreen: View {
    let profile: BettorProfile
    let onNext: () -> Void
    @State private var appeared = false

    var lossStat: ProfileStat { profile.stats.last! }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StepDots(current: 2, total: 3, color: .p6Red)
                Spacer()
                Text("3 of 3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.p6Red.opacity(0.65))
            }
            .padding(.bottom, 18)

            Text("WHAT THIS")
                .font(.custom("BarlowCondensed-Black", size: 38))
                .kerning(-1).foregroundColor(.white)
            Text("COSTS YOU")
                .font(.custom("BarlowCondensed-Black", size: 38))
                .kerning(-1).foregroundColor(Color.p6Red.opacity(0.45))
                .padding(.bottom, 20)

            // Hero stat
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient.issueCard)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.p6Red.opacity(0.5), lineWidth: 1.5)
                RadialGradient(colors: [Color.p6Red.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: 160)

                VStack(spacing: 6) {
                    Text("Average \(profile.short) loses")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "#ff9b9b").opacity(0.6))
                        .kerning(1)
                        .textCase(.uppercase)
                    Text(lossStat.number)
                        .font(.custom("BarlowCondensed-Black", size: 72))
                        .kerning(-3)
                        .foregroundColor(Color(hex: "#ff4d4d"))
                        .scaleEffect(appeared ? 1 : 0.7)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)
                    Text("every single year")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#ffb4b4").opacity(0.75))
                }
                .padding(.vertical, 28)
            }
            .frame(maxWidth: .infinity)

            // Two supporting stats
            HStack(spacing: 8) {
                ForEach(Array(profile.stats.prefix(2)), id: \.number) { stat in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(stat.number)
                            .font(.custom("BarlowCondensed-Black", size: 28))
                            .kerning(-0.5)
                            .foregroundColor(Color(hex: "#ff6b6b"))
                        Text(stat.label)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color(hex: "#ff9b9b").opacity(0.68))
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.p6Red.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.p6Red.opacity(0.22), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.top, 10)

            Spacer()

            P6Button("See how to fix this →", gradient: .redDeep, action: onNext)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .onAppear { appeared = true }
    }
}

// MARK: - Solve Screen 1: Intro

struct SolveIntroScreen: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StepDots(current: 0, total: 3, color: .p6Green)
                Spacer()
                Text("1 of 3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.p6Green.opacity(0.7))
            }
            .padding(.bottom, 18)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient.solveCard)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.p6Green.opacity(0.4), lineWidth: 1.5)
                RadialGradient(colors: [Color.p6Green.opacity(0.12), .clear], center: .init(x: 0.3, y: 0.2), startRadius: 0, endRadius: 200)

                VStack(alignment: .leading, spacing: 0) {
                    P6LiveBadge(label: "The solution", color: .p6Green).padding(.bottom, 18)

                    Text("🚀")
                        .font(.system(size: 52))
                        .scaleEffect(appeared ? 1 : 0.6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: appeared)
                        .padding(.bottom, 14)

                    Text("PICK6\nCHANGES\nEVERYTHING")
                        .font(.custom("BarlowCondensed-Black", size: 40))
                        .kerning(-1)
                        .textCase(.uppercase)
                        .foregroundColor(.white)
                        .lineSpacing(-2)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
                        .padding(.bottom, 14)

                    Text("AI-powered predictions that give you the systematic edge the bookies don't want you to have.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(hex: "#b4ffb4").opacity(0.8))
                        .lineSpacing(4)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, minHeight: 340)

            Spacer()

            P6Button("See how it works →", gradient: .greenDeep, action: onNext)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .onAppear { appeared = true }
    }
}

// MARK: - Solve Screen 2: AI + Probability

struct SolveAIScreen: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StepDots(current: 1, total: 3, color: .p6Green)
                Spacer()
                Text("2 of 3").font(.system(size: 12, weight: .medium)).foregroundColor(Color.p6Green.opacity(0.7))
            }.padding(.bottom, 18)

            Text("SMARTER")
                .font(.custom("BarlowCondensed-Black", size: 40)).kerning(-1.5).foregroundColor(.white)
            Text("EVERY MATCH")
                .font(.custom("BarlowCondensed-Black", size: 40)).kerning(-1.5)
                .foregroundColor(Color.p6Green.opacity(0.4)).padding(.bottom, 20)

            VStack(spacing: 12) {
                // AI card
                VStack(alignment: .leading, spacing: 8) {
                    Text("🤖").font(.system(size: 28)).padding(.bottom, 4)
                    Text("AI Picks Every Game")
                        .font(.custom("BarlowCondensed-Black", size: 20)).textCase(.uppercase).foregroundColor(.white)
                    Text("Our model processes **200+ data points** per match — team form, weather, injuries, xG, head-to-head, line movement. One confident prediction. No noise.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#b4ffb4").opacity(0.75))
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(LinearGradient(colors: [Color.p6Green.opacity(0.1), Color(hex: "#14532D").opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.p6Green.opacity(0.38), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 24)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                // Probability card
                VStack(alignment: .leading, spacing: 8) {
                    Text("📊").font(.system(size: 28)).padding(.bottom, 4)
                    Text("Win Probability Bar")
                        .font(.custom("BarlowCondensed-Black", size: 20)).textCase(.uppercase).foregroundColor(.white)
                    Text("Three-zone bar showing the **exact likelihood** of each outcome. Know the true odds — not the bookmaker's odds. Bet only when there's real value.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(hex: "#b4ffb4").opacity(0.75))
                        .lineSpacing(3)
                    // Demo bar
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.p6Green).frame(width: geo.size.width * 0.54)
                            Rectangle().fill(Color.white.opacity(0.3)).frame(width: geo.size.width * 0.18)
                            Rectangle().fill(Color.white.opacity(0.1))
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)
                    .padding(.top, 4)

                    HStack {
                        Text("54% Home").font(.custom("BarlowCondensed-Black", size: 12)).foregroundColor(.p6Green)
                        Spacer()
                        Text("18%").font(.custom("BarlowCondensed-Bold", size: 12)).foregroundColor(Color.white.opacity(0.4))
                        Spacer()
                        Text("28% Away").font(.custom("BarlowCondensed-Bold", size: 12)).foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(LinearGradient(colors: [Color.p6Green.opacity(0.08), Color(hex: "#14532D").opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.p6Green.opacity(0.28), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 24)
                .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)
            }

            Spacer()
            P6Button("And there's more →", gradient: .greenDeep, action: onNext)
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 18)
        .onAppear { appeared = true }
    }
}

// MARK: - Solve Screen 3: Live + Bankroll

struct SolveLiveScreen: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                StepDots(current: 2, total: 3, color: .p6Green)
                Spacer()
                Text("3 of 3").font(.system(size: 12, weight: .medium)).foregroundColor(Color.p6Green.opacity(0.7))
            }.padding(.bottom, 18)

            Text("IN-PLAY &")
                .font(.custom("BarlowCondensed-Black", size: 40)).kerning(-1.5).foregroundColor(.white)
            Text("IN CONTROL")
                .font(.custom("BarlowCondensed-Black", size: 40)).kerning(-1.5)
                .foregroundColor(Color.p6Green.opacity(0.4)).padding(.bottom, 20)

            VStack(spacing: 12) {
                GreenFeatureCard(icon: "🏟",
                                 title: "Live Field Intelligence",
                                 bodyText: "A real-time animated pitch showing player positions, momentum shifts and live AI pick updates. See what's happening — and what it means for your bet.")
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 24)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                GreenFeatureCard(icon: "💰",
                                 title: "Bankroll Protection",
                                 bodyText: "Built-in staking advice and real-time P&L tracking. Know exactly how much you should stake and where you stand — always.")
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 24)
                .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)
            }

            Spacer()
            P6Button("See real results →", gradient: .greenDeep, action: onNext)
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 18)
        .onAppear { appeared = true }
    }
}

// MARK: - Proof

struct ProofScreen: View {
    let onNext: () -> Void

    private let stats = [("78%","AI pick accuracy"), ("$312","Avg monthly gain"), ("94%","Smarter in 2 wks")]
    private let reviews = [
        ("Jordan M.", "First week I made back 3 months of losses. The AI picks are genuinely different.", "⚽ Soccer", Color.p6RedDeep),
        ("Priya K.",  "I used to lose €200 every weekend. Now I know WHY I'm placing each bet.", "🏀 NBA", Color.p6Orange),
        ("Tom H.",    "Live field view alone is worth it. Tactical edge I couldn't find elsewhere.", "🏈 NFL", Color.p6Navy),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("REAL PEOPLE.")
                    .font(.custom("BarlowCondensed-Black", size: 38)).kerning(-1.5).foregroundColor(.white)
                Text("REAL GAINS.")
                    .font(.custom("BarlowCondensed-Black", size: 38)).kerning(-1.5)
                    .foregroundColor(Color.white.opacity(0.16)).padding(.bottom, 14)

                // Stat chips
                HStack(spacing: 8) {
                    ForEach(stats, id: \.0) { s in
                        VStack(spacing: 4) {
                            Text(s.0).font(.custom("BarlowCondensed-Black", size: 22)).foregroundColor(.white)
                            Text(s.1).font(.system(size: 11, weight: .regular))
                                .foregroundColor(Color(hex: "#b4ffb4").opacity(0.65)).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12).padding(.horizontal, 8)
                        .background(Color.p6Green.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.p6Green.opacity(0.35), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.bottom, 14)

                VStack(spacing: 8) {
                    ForEach(reviews, id: \.0) { r in
                        ReviewCard(name: r.0, text: r.1, sport: r.2, color: r.3)
                    }
                }
                .padding(.bottom, 20)

                P6Button("Choose Your Sports →", gradient: .greenDeep, action: onNext)
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)
        }
    }
}

// MARK: - Sport Selection

struct SportSelectScreen: View {
    @Binding var selectedSports: Set<String>
    let onNext: () -> Void

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var buttonGradient: LinearGradient {
        let colors = Pick6Data.sports.filter { selectedSports.contains($0.id) }.flatMap { $0.gradientColors }
        return colors.isEmpty ? LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PICK YOUR")
                .font(.custom("BarlowCondensed-Black", size: 38)).kerning(-1.5).foregroundColor(.white)
            Text("SPORTS")
                .font(.custom("BarlowCondensed-Black", size: 38)).kerning(-1.5)
                .foregroundColor(Color.white.opacity(0.16)).padding(.bottom, 8)

            Text("Select all you want AI predictions for")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55)).padding(.bottom, 14)

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(Pick6Data.sports) { sport in
                    let on = selectedSports.contains(sport.id)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                            if on { selectedSports.remove(sport.id) }
                            else  { selectedSports.insert(sport.id) }
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 6) {
                                Text(sport.icon).font(.system(size: 30))
                                Text(sport.label)
                                    .font(.custom("BarlowCondensed-Black", size: 10))
                                    .kerning(1.5).textCase(.uppercase)
                                    .foregroundColor(on ? .white : Color.white.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(
                                on ? AnyView(LinearGradient(colors: sport.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                   : AnyView(Color.white.opacity(0.06))
                            )
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(on ? sport.color : Color.white.opacity(0.1), lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .scaleEffect(on ? 1.04 : 1.0)

                            if on {
                                ZStack {
                                    Circle().fill(sport.color).frame(width: 16, height: 16)
                                    Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                                }
                                .padding(6)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            P6Button(
                selectedSports.isEmpty ? "Select at least one sport"
                    : "Continue with \(selectedSports.count) sport\(selectedSports.count > 1 ? "s" : "") →",
                gradient: selectedSports.isEmpty ? nil : buttonGradient,
                disabled: selectedSports.isEmpty,
                action: onNext
            )
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 18)
    }
}

// MARK: - Login

struct LoginScreen: View {
    let onApple: () -> Void
    let onPhone: (String) -> Void

    @State private var phone = ""
    var valid: Bool { phone.filter(\.isNumber).count >= 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CREATE YOUR")
                .font(.custom("BarlowCondensed-Black", size: 38)).kerning(-1).foregroundColor(.white)
            Text("ACCOUNT")
                .font(.custom("BarlowCondensed-Black", size: 38)).kerning(-1)
                .foregroundColor(Color.white.opacity(0.16)).padding(.bottom, 24)

            // Apple Sign In
            Button(action: onApple) {
                HStack(spacing: 12) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    Text("Continue with Apple")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)

            // Divider
            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
                Text("or").font(.system(size: 13, weight: .regular)).foregroundColor(Color.white.opacity(0.35))
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 0.5)
            }
            .padding(.bottom, 16)

            Text("Phone number")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.white.opacity(0.45))
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                // Country code
                HStack(spacing: 6) {
                    Text("🇺🇸")
                    Text("+1").font(.custom("BarlowCondensed-Black", size: 15)).foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .padding(.horizontal, 12).padding(.vertical, 14)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Phone input
                TextField("(555) 000-0000", text: $phone)
                    .keyboardType(.phonePad)
                    .font(.custom("BarlowCondensed-Black", size: 18))
                    .foregroundColor(.white)
                    .tint(.p6Red)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.bottom, 14)

            P6Button(
                valid ? "Send Verification Code →" : "Enter your phone number",
                gradient: valid ? .redDeep : nil,
                disabled: !valid
            ) { onPhone(phone) }

            Spacer()

            Text("By continuing you agree to our Terms of Service and Privacy Policy")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.white.opacity(0.22))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 18)
    }
}

// MARK: - OTP

struct OTPScreen: View {
    let phone: String
    let onVerified: () -> Void

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @State private var timer = 59
    @FocusState private var focusedIndex: Int?

    var filled: Int { digits.filter { !$0.isEmpty }.count }
    var isComplete: Bool { filled == 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Lock icon
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.p6Red.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.p6Red.opacity(0.3), lineWidth: 1.5))
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.p6Red)
            }
            .frame(width: 54, height: 54)
            .padding(.bottom, 22)

            Text("Verify your\nnumber")
                .font(.custom("BarlowCondensed-Black", size: 38))
                .kerning(-1).textCase(.uppercase).foregroundColor(.white)
                .padding(.bottom, 10)

            Text("We sent a 6-digit code to\n**\(phone)**")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.5))
                .lineSpacing(3).padding(.bottom, 28)

            // OTP boxes
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    OTPBox(
                        digit: $digits[i],
                        isFocused: focusedIndex == i,
                        onFilled: { if i < 5 { focusedIndex = i + 1 } else { verify() } },
                        onBackspace: { if i > 0 { digits[i-1] = ""; focusedIndex = i - 1 } }
                    )
                    .focused($focusedIndex, equals: i)
                }
            }
            .padding(.bottom, 24)

            P6Button(
                isComplete ? "Verify & Continue →" : "Enter verification code",
                gradient: isComplete ? .redDeep : nil,
                disabled: !isComplete,
                action: verify
            )

            // Resend
            VStack(spacing: 4) {
                Text("Didn't receive it?")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.4))
                if timer > 0 {
                    Text("Resend code in \(String(format: "0:%02d", timer))")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.35))
                        .tint(.p6Red)
                } else {
                    Button("Resend code") {
                        digits = Array(repeating: "", count: 6)
                        timer = 59
                        focusedIndex = 0
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.p6Red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)

            Spacer()

            Text("By verifying you agree to our Terms of Service and Privacy Policy")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.white.opacity(0.22))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
        .onAppear {
            focusedIndex = 0
            startTimer()
        }
    }

    private func verify() {
        guard isComplete else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { onVerified() }
    }

    private func startTimer() {
        guard timer > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if timer > 0 { timer -= 1; startTimer() }
        }
    }
}

// Single OTP input box
struct OTPBox: View {
    @Binding var digit: String
    let isFocused: Bool
    let onFilled: () -> Void
    let onBackspace: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(digit.isEmpty ? Color.white.opacity(0.05) : Color.p6Red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(digit.isEmpty ? (isFocused ? Color.white.opacity(0.45) : Color.white.opacity(0.1))
                                              : Color.p6Red, lineWidth: 2)
                )

            if digit.isEmpty && isFocused {
                // Cursor
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 28)
                    .cornerRadius(1)
                    .opacity(isFocused ? 1 : 0)
                    .animation(.easeInOut(duration: 0.9).repeatForever(), value: isFocused)
            } else {
                Text(digit)
                    .font(.custom("BarlowCondensed-Black", size: 28))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }

            // Hidden TextField for input
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
        .frame(height: 60)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: digit)
    }
}

// MARK: - Paywall

struct P6PaywallScreen: View {
    let onComplete: (String) -> Void

    @State private var plan: String? = "monthly"   // pre-select best value
    @State private var appeared = false

    private let features = [
        ("brain.head.profile", "AI Picks Every Match"),
        ("sportscourt", "Live Field Intelligence"),
        ("chart.bar.fill", "Win Probability Engine"),
        ("bell.badge.fill", "Real-Time Smart Alerts"),
        ("banknote", "Bankroll Protection"),
        ("arrow.up.forward", "All Future Sports Free"),
    ]

    var body: some View {
        ZStack {
            Color.p6Ink.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ──
                    VStack(spacing: 6) {
                        // Crown icon
                        ZStack {
                            Circle()
                                .fill(Color.p6Green.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                        }
                        .padding(.bottom, 8)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)

                        Text("UNLOCK YOUR")
                            .font(.custom("BarlowCondensed-Black", size: 40))
                            .kerning(-1.5)
                            .foregroundColor(.white)
                        Text("AI EDGE")
                            .font(.custom("BarlowCondensed-Black", size: 40))
                            .kerning(-1.5)
                            .foregroundColor(Color.p6Green)

                        Text("7-day free trial · Cancel anytime")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.45))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // ── Plan cards ──
                    VStack(spacing: 10) {
                        // Monthly — best value
                        paywallPlanCard(
                            id: "monthly",
                            badge: "BEST VALUE — SAVE 28%",
                            title: "Monthly",
                            priceMain: "$19",
                            priceCents: ".99",
                            period: "/month",
                            perDay: "~$0.66/day"
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                        // Weekly
                        paywallPlanCard(
                            id: "weekly",
                            badge: nil,
                            title: "Weekly",
                            priceMain: "$6",
                            priceCents: ".99",
                            period: "/week",
                            perDay: "~$1.00/day"
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.4).delay(0.22), value: appeared)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // ── Features ──
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.element.1) { i, feat in
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.p6Green.opacity(0.10))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: feat.0)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.p6Green)
                                }
                                Text(feat.1)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.p6Green)
                            }
                            .padding(.vertical, 10)
                            if i < features.count - 1 {
                                Divider().background(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // ── Social proof ──
                    HStack(spacing: 10) {
                        Circle().fill(Color.p6Green).frame(width: 7, height: 7)
                            .overlay(Circle().fill(Color.p6Green.opacity(0.3)).scaleEffect(1.8))
                        Text("2,847 members joined this week")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.48))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.bottom, 20)

                    // ── CTA ──
                    P6Button(
                        plan != nil ? "Start Free Trial →" : "Select a plan",
                        gradient: plan != nil ? .greenDeep : nil,
                        disabled: plan == nil
                    ) { if let p = plan { onComplete(p) } }
                    .padding(.horizontal, 20)

                    // Fine print
                    VStack(spacing: 6) {
                        Text("Free for 7 days, then billed \(plan == "weekly" ? "weekly" : "monthly")")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.30))

                        Text("Cancel anytime · 🔒 Secure payment")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.22))

                        Button("Restore purchases") {}
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.35))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { appeared = true }
    }

    // ── Plan Card ──
    @ViewBuilder
    private func paywallPlanCard(id: String, badge: String?, title: String, priceMain: String, priceCents: String, period: String, perDay: String) -> some View {
        let isSelected = plan == id
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { plan = id }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Badge
                if let badge {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(Color(hex: "#FFD700"))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(hex: "#FFD700").opacity(0.12))
                    .overlay(Capsule().stroke(Color(hex: "#FFD700").opacity(0.35), lineWidth: 1))
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.custom("BarlowCondensed-Black", size: 22))
                            .foregroundColor(.white)
                        Text(perDay)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.40))
                    }
                    Spacer()
                    HStack(alignment: .top, spacing: 0) {
                        (Text(priceMain).font(.custom("BarlowCondensed-Black", size: 36))
                         + Text(priceCents).font(.custom("BarlowCondensed-Black", size: 20)))
                            .foregroundColor(.white)
                        Text(period)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.38))
                            .padding(.top, 14)
                            .padding(.leading, 2)
                    }
                }
            }
            .padding(18)
            .background(isSelected ? Color.p6Green.opacity(0.08) : Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.p6Green : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    ZStack {
                        Circle().fill(Color.p6Green).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isSelected ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Done

struct DoneScreen: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("🚀")
                .font(.system(size: 72))
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: appeared)
                .padding(.bottom, 16)

            Text("YOU'RE IN.")
                .font(.custom("BarlowCondensed-Black", size: 52))
                .kerning(-2).textCase(.uppercase).foregroundColor(.white)
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            // Gradient text "LET'S WIN."
            Text("LET'S WIN.")
                .font(.custom("BarlowCondensed-Black", size: 52))
                .kerning(-2).textCase(.uppercase)
                .foregroundStyle(LinearGradient(colors: [.p6Green, Color(hex:"#FFB400"), .p6Red],
                                                startPoint: .leading, endPoint: .trailing))
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.4).delay(0.18), value: appeared)
                .padding(.bottom, 16)

            Text("Your AI picks are ready.\nFirst predictions loading now.")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55))
                .multilineTextAlignment(.center).lineSpacing(4)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.26), value: appeared)

            Spacer()

            P6Button("Go to My Picks →",
                     gradient: LinearGradient(colors: [.p6GreenDeep, .p6Green, Color(hex:"#FFB400")],
                                              startPoint: .leading, endPoint: .trailing)) {}
            .opacity(appeared ? 1 : 0).animation(.easeOut(duration: 0.4).delay(0.34), value: appeared)
        }
        .padding(.horizontal, 24).padding(.bottom, 28)
        .onAppear { appeared = true }
    }
}
