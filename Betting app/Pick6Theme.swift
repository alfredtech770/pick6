// Pick6Theme.swift
// Design tokens, shared types, and data models for the Pick6 onboarding flow.

import SwiftUI

// MARK: - Hex initializer

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: s).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch s.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Colors

extension Color {
    static let p6Ink        = Color(hex: "#0A0B0D")
    static let p6Panel      = Color(hex: "#101114")
    static let p6Panel2     = Color(hex: "#16181C")
    static let p6Line       = Color(hex: "#22252B")
    static let p6Line2      = Color(hex: "#2D3038")
    static let p6Mute       = Color(hex: "#6E6F75")
    static let p6Ink2       = Color(hex: "#B9B7B0")
    static let p6Foreground = Color(hex: "#F5F3EE")
    static let p6Lime       = Color(hex: "#D4FF3A")
    static let p6LimeInk    = Color(hex: "#0A0B0D")
    static let p6Hot        = Color(hex: "#FF5A36")
    static let p6Red        = Color(hex: "#E8002D")
    static let p6RedDeep    = Color(hex: "#C9082A")
    static let p6Orange     = Color(hex: "#FF8000")
    static let p6Green      = Color(hex: "#22C55E")
    static let p6GreenMid   = Color(hex: "#15803D")
    static let p6GreenDeep  = Color(hex: "#14532D")
    static let p6Navy       = Color(hex: "#0033A0")
    static let p6Purple     = Color(hex: "#552583")
    static let p6SoccerGn   = Color(hex: "#1a6b3a")
}

// MARK: - Namespace

/// Static namespace extended elsewhere (e.g. `Pick6MainData.swift` adds
/// `allSports` and `leagues`). Kept as an empty enum here so other modules
/// can extend it without depending on legacy onboarding data.
enum Pick6Data {}
