// Pick1GameAttributes.swift
// Shared between the main app and the Live Activity widget extension.
// Defines the static (per-game) + dynamic (live-updating) data for a
// Pick1 live-game Activity — the Apple Sports–style lock screen / Dynamic
// Island card that tracks a game the user has a pick on.

import Foundation
import ActivityKit

struct Pick1GameAttributes: ActivityAttributes {
    /// The live-updating part — pushed/refreshed as the game progresses.
    public struct ContentState: Codable, Hashable {
        var homeScore: Int
        var awayScore: Int
        /// Short status line, e.g. "LIVE · Q3", "HALFTIME", "FINAL".
        var statusLine: String
        /// True while the user's pick is currently the winning side.
        var pickHitting: Bool
        /// True once the game is over (drives the FINAL treatment).
        var isFinal: Bool
    }

    // Static for the life of the Activity.
    var homeTeam: String
    var awayTeam: String
    var homeAbbr: String
    var awayAbbr: String
    var league: String
    /// The user's pick text (e.g. "Morocco to win").
    var pickText: String
    var gameId: String
}
