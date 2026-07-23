package com.pick1.app.ui

import androidx.compose.ui.graphics.Color

/**
 * Per-sport emoji + card tint — ports the `sportEmoji` and `tint` computed
 * properties on ProSlateCard (`Pick1HomeHiFi.swift`). The tint drives the
 * colored wash on the left edge of each pick card.
 */
object Sport {

    fun emoji(sport: String): String = when (sport) {
        "basketball" -> "🏀"
        "baseball"   -> "⚾️"
        "hockey"     -> "🏒"
        "football"   -> "🏈"
        "soccer"     -> "⚽️"
        "combat"     -> "🥊"
        "f1"         -> "🏎️"
        "golf"       -> "⛳️"
        "cricket"    -> "🏏"
        "tennis"     -> "🎾"
        else         -> "🎯"
    }

    fun tint(sport: String): Color = when (sport) {
        "basketball" -> Color(0xFF2FA85B)
        "soccer"     -> Color(0xFF3563C7)
        "football"   -> Color(0xFFC73535)
        "baseball"   -> Color(0xFFC7852F)
        "hockey"     -> Color(0xFF35AEC7)
        "combat"     -> Color(0xFFC74A2F)
        "f1"         -> Color(0xFFC72F49)
        "golf"       -> Color(0xFF3E9E4E)
        "cricket"    -> Color(0xFF2FA89B)
        else         -> Color(0xFF6E6F75)
    }

    /**
     * Shortens a team name for the "AWAY VS HOME" headline, mirroring the
     * iOS `short(_:)` helper: drop a leading city when the name has one.
     */
    fun short(team: String): String {
        val t = team.trim()
        if (t.length <= 14) return t
        val parts = t.split(" ")
        return if (parts.size > 1) parts.last() else t
    }
}
