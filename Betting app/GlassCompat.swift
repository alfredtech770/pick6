//
//  GlassCompat.swift
//  Betting app
//
//  iOS 26 introduced Liquid Glass (`glassEffect`). To keep the minimum
//  deployment target low (iOS 18) so the app installs on the vast majority of
//  iPhones, this shim applies real Liquid Glass on iOS 26+ and falls back to an
//  `.ultraThinMaterial` (optionally tinted) in the same shape on iOS 18–25.
//
//  NOTE: this build ships with SWIFT_OPTIMIZATION_LEVEL=-Onone as a workaround
//  for a Swift SIL-optimizer crash (Xcode 26.5) compiling the app module's
//  iOS-availability code at -O. Revisit with a newer toolchain.
//
import SwiftUI

@available(iOS 26.0, *)
private func pick1Glass(interactive: Bool, tint: Color?) -> Glass {
    var glass: Glass = .regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    @ViewBuilder
    func glassCompat<S: Shape>(
        in shape: S,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(pick1Glass(interactive: interactive, tint: tint), in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(tint ?? .clear, in: shape)
        }
    }
}
