// Pick1Theme.swift
// Design tokens, shared types, and data models for the Pick1 onboarding flow.

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

// Home v2 ("Switch Style") palette. The neutrals moved from warm-grey to a
// cool, slightly blue-shifted ramp — that shift is what makes the lime read
// as electric rather than olive, so the darks and the accent have to move
// together. Ink2 / Foreground / Mute / Hot were already identical in the
// design and are unchanged.
extension Color {
    static let p1Ink        = Color(hex: "#0A0B0D")   // v2: deeper, cooler
    static let p1Panel      = Color(hex: "#15171B")   // v2: blue-shifted
    static let p1Panel2     = Color(hex: "#1C1F24")   // v2: blue-shifted
    static let p1Line       = Color(hex: "#26292F")   // v2: blue-shifted
    static let p1Line2      = Color(hex: "#333740")
    static let p1Mute       = Color(hex: "#6E6F75")
    static let p1Ink2       = Color(hex: "#B9B7B0")
    static let p1Foreground = Color(hex: "#F5F3EE")
    static let p1Lime       = Color(hex: "#CDFA3F")   // v2: brighter, greener
    static let p1LimeInk    = Color(hex: "#0A0B0D")   // tracks p1Ink
    static let p1Hot        = Color(hex: "#FF5A36")

    /// Semantic result colors introduced by v2. `p1Win` is the settled-win
    /// green — deliberately distinct from `p1Green`, which is still used for
    /// generic positive UI (and for sport branding) elsewhere in the app.
    static let p1Win        = Color(hex: "#4ADE80")
    static let p1Violet     = Color(hex: "#8B5CF6")
    static let p1Red        = Color(hex: "#E8002D")
    static let p1RedDeep    = Color(hex: "#C9082A")
    static let p1Orange     = Color(hex: "#FF8000")
    static let p1Green      = Color(hex: "#22C55E")
    static let p1GreenMid   = Color(hex: "#15803D")
    static let p1GreenDeep  = Color(hex: "#14532D")
    static let p1Navy       = Color(hex: "#0033A0")
    static let p1Purple     = Color(hex: "#552583")
    static let p1SoccerGn   = Color(hex: "#1a6b3a")
}

// MARK: - Namespace

/// Static namespace extended elsewhere (e.g. `Pick6MainData.swift` adds
/// `allSports` and `leagues`). Kept as an empty enum here so other modules
/// can extend it without depending on legacy onboarding data.
enum Pick1Data {}
