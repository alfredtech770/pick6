// Pick1Motion.swift
//
// Centralized motion language for Pick1. Premium iOS apps rest on three
// pillars: consistent springs, press-state feedback on every tap, and
// haptics that confirm intent. This file defines those primitives so
// every screen draws from the same well.
//
// Three things to know:
//
//   1. `Pick1Springs` — three canonical springs (.snappy / .smooth /
//      .bouncy). Reach for these instead of inlining magic
//      response/dampingFraction pairs. Inconsistent values are what
//      makes an app "feel off".
//
//   2. `.pressableScale()` — a tap-feedback modifier that subtly
//      scales (0.97) and dims a button on press, springing back on
//      release. Apply to every Button label that doesn't already
//      have its own press treatment.
//
//   3. `Haptics.tap() / .selection() / .success() / .impact()` — thin
//      wrappers over UIImpactFeedbackGenerator + .sensoryFeedback so
//      we can fire haptics from imperative code AND declaratively bind
//      them to view state (`.sensoryFeedback(.selection, trigger: x)`).

import SwiftUI
import UIKit

// MARK: - Springs

/// Canonical spring values. Centralizing them is the single biggest win
/// for "feels consistent" across screens — when the paywall toggle, tab
/// switch, and sheet dismissal all use the same `response`/`damping`,
/// the eye perceives the app as one designed system rather than seven
/// stitched-together screens.
enum Pick1Springs {
    /// Tight, business-like — selection swaps, toggles, chip taps. The
    /// fastest "this responded" feel without being jittery.
    static let snappy: Animation = .spring(response: 0.25, dampingFraction: 0.82)

    /// All-purpose default for screen transitions and sheet dismissals.
    /// Calm, deliberate; the audio equivalent of a soft "click".
    static let smooth: Animation = .spring(response: 0.42, dampingFraction: 0.84)

    /// Celebratory — saves, success states, the post-pay confetti
    /// equivalents. Used sparingly; if everything bounces, nothing
    /// reads as special.
    static let bouncy: Animation = .spring(response: 0.55, dampingFraction: 0.60)
}

// MARK: - Press-state modifier

/// Apply to any Button label that needs press feedback. Uses a
/// DragGesture-driven `@GestureState` so the press feels instant
/// (no Button-style indirection) and springs back via Pick1Springs.snappy
/// when released — the same hand-feel as Apple's own primary CTAs.
///
/// Usage:
///   Button { … } label: {
///       MyLabel().pressableScale()
///   }
///   .buttonStyle(.plain)
struct PressableScale: ViewModifier {
    /// Scale at full press. 0.97 is the sweet spot — visible but not
    /// goofy. 0.95 is for tiles; 0.99 is for large hero cards where
    /// a smaller delta reads more "responsive" than "rubbery".
    var pressedScale: CGFloat = 0.97

    /// Opacity at full press. Subtle dim adds tactile feel; 0.92 is
    /// enough to register without breaking color identity.
    var pressedOpacity: Double = 0.92

    @GestureState private var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1)
            .opacity(isPressed ? pressedOpacity : 1)
            .animation(Pick1Springs.snappy, value: isPressed)
            // `minimumDistance: 0` makes the gesture fire instantly on
            // touch-down rather than waiting for a drag threshold —
            // critical for the "this responded" feel.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
            )
    }
}

extension View {
    /// Apply press-state feedback (subtle scale + dim, springs back on
    /// release). The default `pressedScale: 0.97` is right for buttons
    /// and small tiles; pass `0.99` for large cards (HeroCard, GameCard).
    func pressableScale(_ scale: CGFloat = 0.97, opacity: Double = 0.92) -> some View {
        modifier(PressableScale(pressedScale: scale, pressedOpacity: opacity))
    }
}

// MARK: - Haptics

/// Thin imperative wrapper around UIKit's feedback generators. Use these
/// when you need to fire a haptic at a moment that isn't expressible as
/// a state change (e.g. inside a `Task` after a network call completes).
/// For state-driven haptics, prefer SwiftUI's native
/// `.sensoryFeedback(_, trigger:)` — it handles the generator lifecycle
/// (prepare/release) automatically.
enum Haptics {

    /// Single light tap — buttons, toggle confirms.
    static func tap() {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
    }

    /// Medium impact — important taps (paywall CTA, save).
    static func medium() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
    }

    /// Heavy impact — destructive confirmations (delete account).
    static func heavy() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
    }

    /// Selection feedback — tab switches, segmented-control swaps.
    /// The subtlest of the haptics; doesn't read as "thump", reads as
    /// "tick".
    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
    }

    /// Notification.success — pick saved, purchase completed.
    static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    /// Notification.warning — non-fatal heads-up (network blip retried).
    static func warning() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
    }

    /// Notification.error — fatal user-visible failure.
    static func error() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.error)
    }
}
