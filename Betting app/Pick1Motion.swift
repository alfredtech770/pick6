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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Scale at full press. 0.97 is the sweet spot — visible but not
    /// goofy. 0.95 is for tiles; 0.99 is for large hero cards.
    var scale: CGFloat = 0.97

    /// Opacity at full press. Subtle dim adds tactile feel.
    var opacity: Double = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(reduceMotion ? nil : Pick1Springs.snappy, value: configuration.isPressed)
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


// Entrance motion runs once per mounted card; reduced motion presents it immediately.
private struct P1Entrance: ViewModifier {
    var delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .scaleEffect(shown || reduceMotion ? 1 : 0.985, anchor: .top)
            .onAppear {
                guard !shown else { return }
                withAnimation(reduceMotion ? nil : Pick1Springs.smooth.delay(delay)) { shown = true }
            }
    }
}
extension View {
    func p1Entrance(delay: Double = 0) -> some View { modifier(P1Entrance(delay: delay)) }
}

struct P1SpotlightSheen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swept = false
    var body: some View {
        if !reduceMotion {
            GeometryReader { geometry in
                LinearGradient(colors: [.clear, .white.opacity(0.10), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geometry.size.width * 0.45)
                    .rotationEffect(.degrees(18))
                    .offset(x: swept ? geometry.size.width * 1.5 : -geometry.size.width * 0.6)
                    .onAppear {
                        guard !swept else { return }
                        withAnimation(.easeInOut(duration: 1.15).delay(0.3)) { swept = true }
                    }
            }.allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

// Short score highlights reset on each new value and cancel when the view disappears.
private struct P1ScoreFlash: ViewModifier {
    let value: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var previous: String?
    @State private var glowing = false
    func body(content: Content) -> some View {
        content.contentTransition(.numericText())
            .padding(3)
            .background(Color.p1Lime.opacity(glowing ? 0.16 : 0), in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: Color.p1Lime.opacity(glowing ? 0.45 : 0), radius: 8)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: glowing)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: value)
            .task(id: value) {
                let changed = previous != nil && previous != value
                previous = value
                guard changed, !reduceMotion else { glowing = false; return }
                glowing = true
                do { try await Task.sleep(for: .milliseconds(650)) } catch { glowing = false; return }
                glowing = false
            }
    }
}
extension View {
    func p1ScoreFlash(_ value: String) -> some View { modifier(P1ScoreFlash(value: value)) }
}
struct P1LivePulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    var body: some View {
        Circle().fill(Color.p1Red).frame(width: 5, height: 5)
            .opacity(pulsing && !reduceMotion ? 0.45 : 1)
            .scaleEffect(pulsing && !reduceMotion ? 1.25 : 1)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }.accessibilityHidden(true)
    }
}
struct P1LoadingCards: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in P1SkeletonGameCard() }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading games and predictions")
    }
}
