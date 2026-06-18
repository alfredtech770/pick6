//
//  GlassCompat.swift
//  Betting app
//
//  iOS 26 introduced Liquid Glass (`glassEffect`). To keep the minimum
//  deployment target low (iOS 18) so the app installs on the vast majority of
//  iPhones, this shim applies real Liquid Glass on iOS 26+ and falls back to an
//  `.ultraThinMaterial` (optionally tinted) in the same shape on iOS 18–25.
//
import SwiftUI

extension View {
    @ViewBuilder
    func glassCompat<S: Shape>(
        in shape: S,
        interactive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            // Build the Glass value in an inline closure so the ViewBuilder
            // branch stays a single expression.
            self.glassEffect(
                {
                    var glass: Glass = .regular
                    if let tint { glass = glass.tint(tint) }
                    if interactive { glass = glass.interactive() }
                    return glass
                }(),
                in: shape
            )
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(tint ?? .clear, in: shape)
        }
    }
}
