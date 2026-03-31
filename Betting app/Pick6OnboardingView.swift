// Pick6OnboardingView.swift
// Root coordinator for the entire Pick6 onboarding flow.

import SwiftUI

// MARK: - Onboarding Result

struct OnboardingResult {
    let answers: [String: String]
    let sports: Set<String>
    let plan: String
}

// MARK: - Onboarding Steps

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case q1, q2, q3, q4, q5, q6
    case processing
    case issue1, issue2, issue3
    case solve1, solve2, solve3
    case proof
    case done

    var totalSteps: Int { OnboardingStep.done.rawValue }
    var progress: Double {
        self == .welcome ? 0 : Double(rawValue) / Double(totalSteps)
    }
    var canGoBack: Bool {
        let noBack: Set<OnboardingStep> = [.welcome, .processing, .done]
        return !noBack.contains(self)
    }
}

// MARK: - Main View

struct Pick6OnboardingView: View {
    let onComplete: (OnboardingResult) -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var direction: Int = 1   // 1 = forward, -1 = back
    @State private var answers: [String: String] = [:]

    private var profile: BettorProfile { Pick6Data.profile(for: answers) }

    init(onComplete: @escaping (OnboardingResult) -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.p6Ink.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation bar + progress
                Pick6NavBar(
                    canGoBack: step.canGoBack,
                    progress: step.progress
                ) { goBack() }
                .padding(.top, 44) // safe area top

                // Screen content
                ZStack {
                    screenView
                        .id(step.rawValue)
                        .transition(screenTransition)
                }
                .animation(
                    .spring(response: 0.38, dampingFraction: 0.82),
                    value: step.rawValue
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Screen routing

    @ViewBuilder
    private var screenView: some View {
        switch step {
        case .welcome:
            WelcomeScreen(onNext: advance)

        case .q1: questionScreen(index: 0)
        case .q2: questionScreen(index: 1)
        case .q3: questionScreen(index: 2)
        case .q4: questionScreen(index: 3)
        case .q5: questionScreen(index: 4)
        case .q6: questionScreen(index: 5)

        case .processing:
            ProcessingScreen(profile: profile, onDone: advance)

        case .issue1:
            IssueRevealScreen(profile: profile, onNext: advance)
        case .issue2:
            IssuePainScreen(profile: profile, onNext: advance)
        case .issue3:
            IssueCostScreen(profile: profile, onNext: advance)

        case .solve1:
            SolveIntroScreen(onNext: advance)
        case .solve2:
            SolveAIScreen(onNext: advance)
        case .solve3:
            SolveLiveScreen(onNext: advance)

        case .proof:
            ProofScreen {
                let result = OnboardingResult(answers: answers, sports: [], plan: "")
                onComplete(result)
                advance()
            }

        case .done:
            DoneScreen()
        }
    }

    @ViewBuilder
    private func questionScreen(index: Int) -> some View {
        let q = Pick6Data.questions[index]
        QuestionScreen(
            question: q,
            index: index,
            total: Pick6Data.questions.count
        ) { answer in
            answers[q.id] = answer
            advance()
        }
    }

    // MARK: - Navigation

    private func advance() {
        direction = 1
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        withAnimation { step = next }
    }

    private func goBack() {
        guard step.canGoBack, let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        direction = -1
        withAnimation { step = prev }
    }

    private var screenTransition: AnyTransition {
        direction == 1
            ? .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                          removal:   .move(edge: .leading).combined(with: .opacity))
            : .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                          removal:   .move(edge: .trailing).combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview {
    Pick6OnboardingView { result in
        print("Completed:", result.plan, result.sports)
    }
}
