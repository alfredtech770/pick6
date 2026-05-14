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

/// Press-state feedback applied as a custom `ButtonStyle`. This is the
/// ONLY pattern that doesn't steal taps from the enclosing Button —
/// because it IS the button's style, not a competing gesture overlay.
///
/// History (what NOT to do, with the symptoms they each produced):
///
///   v1 — `.gesture(DragGesture(minimumDistance: 0))` on the label.
///        ⛔ Broken. Drag-gesture wins over the Button's TapGesture; the
///        Button's action closure never fires. Floating bottom-nav was
///        completely unresponsive to taps.
///
///   v2 — `.onLongPressGesture(minimumDuration: 0, perform: {},
///        onPressingChanged: ...)` on the label.
///        ⛔ Also broken. Even with minimumDuration: 0 and an empty
///        perform closure, the long-press recognizer still consumes
///        touches on iOS 26. Taps don't reach the parent Button.
///
///   v3 (this one) — `ButtonStyle`. Apple's intended API for "react to
///        the button being pressed". `configuration.isPressed` comes
///        from the Button itself, no separate gesture, no conflict.
///        ✅ Works. Taps fire. Press feedback animates.
///
/// Apply on the Button (NOT inside its label):
///
///   Button { ... } label: { MyLabel() }
///       .buttonStyle(PressableButtonStyle())
struct PressableButtonStyle: ButtonStyle {
    /// Scale at full press. 0.97 is the sweet spot — visible but not
    /// goofy. 0.95 is for tiles; 0.99 is for large hero cards.
    var scale: CGFloat = 0.97

    /// Opacity at full press. Subtle dim adds tactile feel.
    var opacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(Pick1Springs.snappy, value: configuration.isPressed)
    }
}

extension View {
    /// Compatibility no-op. Existing call sites apply `.pressableScale()`
    /// to the *label* inside a Button — that placement cannot work
    /// without stealing the Button's tap (see header doc). Rather than
    /// touch every call site immediately, we keep this as a no-op so
    /// the app remains functional, and migrate sites one by one to
    /// `.buttonStyle(PressableButtonStyle(...))` on the Button itself.
    ///
    /// **DO NOT** use this on new code; reach for the ButtonStyle
    /// directly. Migration path:
    ///
    ///   // Old (broken — press feedback OR working tap, never both)
    ///   Button { … } label: {
    ///       MyLabel().pressableScale(0.95)
    ///   }
    ///   .buttonStyle(.plain)
    ///
    ///   // New
    ///   Button { … } label: { MyLabel() }
    ///       .buttonStyle(PressableButtonStyle(scale: 0.95))
    func pressableScale(_ scale: CGFloat = 0.97, opacity: Double = 0.92) -> some View {
        // No-op: returning self lets call sites compile while we
        // gradually migrate them. The arguments are accepted (and
        // currently ignored) so the migration is mechanical when we
        // pull each site over to the ButtonStyle form.
        self
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
