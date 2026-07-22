package com.pick1.app.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Pick1 color tokens — a 1:1 port of the iOS palette.
 *
 * Source of truth on iOS:
 *   • `Pick1Theme.swift`            → the `p1*` colors
 *   • `Pick1OnboardingFunnel.swift` → the `Fnl` funnel tokens
 *
 * Keep these in step with the iOS files; the design is intentionally
 * identical across platforms.
 */
object P1 {
    // ── Core surfaces ────────────────────────────────────────────
    val Ink        = Color(0xFF0A0B0D)   // screen background
    val Panel      = Color(0xFF101114)   // card background
    val Panel2     = Color(0xFF16181C)   // inset / field background
    val Line       = Color(0xFF22252B)   // hairline border
    val Line2      = Color(0xFF2D3038)

    // ── Text ─────────────────────────────────────────────────────
    val Foreground = Color(0xFFF5F3EE)   // primary text ("white")
    val Ink2       = Color(0xFFB9B7B0)   // secondary text
    val Mute       = Color(0xFF6E6F75)   // tertiary / labels

    // ── Brand accent ─────────────────────────────────────────────
    val Lime       = Color(0xFFD4FF3A)   // primary accent (home/app)
    val LimeFunnel = Color(0xFFCDFA3F)   // the funnel uses a slightly warmer lime
    val LimeInk    = Color(0xFF0A0B0D)   // text on top of lime

    // ── Semantic ─────────────────────────────────────────────────
    val Hot        = Color(0xFFFF5A36)   // "hard truth" red (funnel)
    val Red        = Color(0xFFE8002D)
    val RedDeep    = Color(0xFFC9082A)
    val Loss       = Color(0xFFFF5A5A)   // losing pick / negative P&L
    val Orange     = Color(0xFFFF8000)
    val Green      = Color(0xFF22C55E)
    val GreenMid   = Color(0xFF15803D)
    val GreenDeep  = Color(0xFF14532D)
    val Win        = Color(0xFF4ADE80)   // "the fix" green (funnel)

    // Bet tracker / calibration use a brighter lime for wins.
    val WinLime    = Color(0xFFD4FF3A)

    // ── League / sport accents ───────────────────────────────────
    val Navy       = Color(0xFF0033A0)
    val Purple     = Color(0xFF552583)
    val SoccerGrn  = Color(0xFF1A6B3A)
    val Golf       = Color(0xFF3FA34D)
}

/**
 * Summer Football (World Cup hub) palette — ports the `WC` enum used by
 * `Pick1SummerFootball.swift`.
 */
object WC {
    val Bg     = P1.Ink
    val Panel  = P1.Panel
    val Line   = P1.Line
    val Ink    = P1.Foreground
    val Mute   = P1.Mute
    val Gold   = Color(0xFFD4AF37)
    val Navy   = Color(0xFF0A1F44)
    val Blue   = Color(0xFF0033A0)
    val Accent = P1.Lime
}
