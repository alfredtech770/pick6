// ScreenshotProtection.swift
// Wrap any SwiftUI view in this and the system will blank it out
// during screen captures (screenshots, screen recordings, AirPlay
// mirroring, control-center capture, etc.).
//
// Used to protect Pro-tier pick content from being shared off-app —
// premium subscribers should not be able to screenshot the AI's picks
// and forward them to non-subscribers.
//
// Mechanism: iOS' UITextField in `isSecureTextEntry` mode hosts an
// internal canvas view that the OS deliberately omits from any
// system capture. We host SwiftUI content inside that canvas, so the
// content is visible on-device but blank in the captured image. This
// is the same trick the major banking and health apps use — Apple has
// not deprecated it through several iOS releases (still works on 26).
//
// On older iOS or if Apple ever removes the private subview, this
// wrapper degrades gracefully: the content renders normally without
// protection (i.e. screenshots succeed). Never silently fails to render.

import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════
// MARK: - ScreenshotProtected — UIViewRepresentable
// ════════════════════════════════════════════════════════════════

struct ScreenshotProtected<Content: View>: UIViewRepresentable {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: AnyView(content()))
    }

    func makeUIView(context: Context) -> UIView {
        // Hidden secure text field — its private canvas is the
        // capture-blanked view we host into.
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false

        // Find the canvas (private subview, name varies by iOS version
        // but always contains "CanvasView"). If it's gone in some
        // future iOS release, we fall back to a plain container so
        // content still renders.
        let canvas = field.subviews.first { sv in
            String(describing: type(of: sv)).contains("CanvasView")
        } ?? UIView()

        // Re-parent — pull canvas out of UITextField and use it as
        // our backing view. The textField itself is retained by the
        // coordinator so its secure-entry state stays alive.
        canvas.subviews.forEach { $0.removeFromSuperview() }
        canvas.translatesAutoresizingMaskIntoConstraints = false

        // Host the SwiftUI content.
        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false

        canvas.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: canvas.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: canvas.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: canvas.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: canvas.trailingAnchor),
        ])

        // Keep the parent textField alive (canvas weakly references it).
        context.coordinator.field = field
        return canvas
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Push fresh content into the hosted controller on every
        // SwiftUI update tick. AnyView avoids the generic-rebind
        // dance — we never tear down the host (which would lose state).
        context.coordinator.host.rootView = AnyView(content())
    }

    final class Coordinator {
        var field: UITextField?
        let host: UIHostingController<AnyView>

        init(rootView: AnyView) {
            self.host = UIHostingController(rootView: rootView)
            // Let the SwiftUI content size itself — autolayout drives
            // the surrounding canvas, so we want the host to be
            // intrinsically sized.
            self.host.view.backgroundColor = .clear
            self.host.sizingOptions = .intrinsicContentSize
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - View modifier
// ════════════════════════════════════════════════════════════════

extension View {
    /// Wraps the view in iOS' secure-text-entry container so screen
    /// captures (screenshots, recordings, mirroring) render this view
    /// as blank. Pass `enabled: false` to opt out per-view (e.g. for
    /// Free-tier locked previews that should be screenshot-able).
    @ViewBuilder
    func screenshotProtected(_ enabled: Bool = true) -> some View {
        if enabled {
            ScreenshotProtected { self }
        } else {
            self
        }
    }

    /// Like `screenshotProtected()` but only blocks captures for Pro
    /// subscribers. Free users (or Pro users viewing free preview
    /// content) can still capture screenshots normally — protection
    /// applies to actual paid content. Pulls `isPro` from the
    /// `SubscriptionManager` in the SwiftUI environment.
    @ViewBuilder
    func screenshotProtectedForPro() -> some View {
        modifier(ProScreenshotModifier())
    }
}

private struct ProScreenshotModifier: ViewModifier {
    @EnvironmentObject var subs: SubscriptionManager
    func body(content: Content) -> some View {
        content.screenshotProtected(subs.isPro)
    }
}
