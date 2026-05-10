//
//  Pick.swift
//  Betting app
//
//  Created by Ethan on 3/30/26.
//

import Foundation

// MARK: - Pick Model
struct Pick: Identifiable, Codable {
    let id: UUID
    let createdAt: Date?
    let sport: String
    let league: String
    let gameDate: String
    let gameId: String?           // links pick → live_scores; populated by the AI pipeline
    let homeTeam: String
    let awayTeam: String
    let pick: String
    let probability: Double
    let confidence: String
    let reasoning: String
    let keyFactor: String?        // short tagline ("Cole 2.34 ERA vs LAD")
    let result: String // "pending", "win", "loss"
    let homeScore: Int?
    let awayScore: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case sport, league
        case gameDate = "game_date"
        case gameId = "game_id"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case pick, probability, confidence, reasoning
        case keyFactor = "key_factor"
        case result
        case homeScore = "home_score"
        case awayScore = "away_score"
    }

    // Confidence tier helper
    var confidenceTier: ConfidenceTier {
        if probability >= 80 { return .high }
        if probability >= 65 { return .medium }
        return .low
    }

    var isWin: Bool { result == "win" }
    var isLoss: Bool { result == "loss" }
    var isPending: Bool { result == "pending" }
}

enum ConfidenceTier {
    case high   // 80%+
    case medium // 65-79%
    case low    // below 65%

    var stars: String {
        switch self {
        case .high: return "***"
        case .medium: return "**"
        case .low: return "*"
        }
    }

    var color: String {
        switch self {
        case .high: return "#22C55E"
        case .medium: return "#F59E0B"
        case .low: return "#6B7280"
        }
    }
}

// MARK: - Live Score Model
struct LiveScore: Identifiable, Codable {
    let id: UUID
    let gameId: String
    let sport: String
    let homeTeam: String
    let awayTeam: String
    let homeScore: Int?
    let awayScore: Int?
    let status: String?
    let quarter: String?
    let startTime: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case gameId = "game_id"
        case sport
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case homeScore = "home_score"
        case awayScore = "away_score"
        case status, quarter
        case startTime = "start_time"
        case updatedAt = "updated_at"
    }

    /// True iff the game is currently in progress. Defensive against
    /// the wide variety of status strings sportsdata.io / Ergast return
    /// ("InProgress", "In Progress", "Halftime", "Q3", "1st", "Bot 7",
    /// "1H", "2H", "HT", "OT", etc.). Anything that's NOT clearly
    /// final/scheduled and has scores or a live-shaped status counts
    /// as live.
    var isLive: Bool {
        let s = (status ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return false }
        if isFinal { return false }
        if s.contains("schedul") || s == "ns" || s == "tbd"
            || s == "pre" || s == "preview" || s == "postponed"
            || s == "canceled" || s == "cancelled" || s == "delayed" {
            return false
        }
        return true
    }

    /// True iff the game has finished. Same defensive parsing.
    var isFinal: Bool {
        let s = (status ?? "")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return false }
        return s.contains("final")
            || s == "f" || s == "ft" || s == "aet" || s == "closed"
            || s == "f/ot" || s == "f/so" || s == "ended"
    }
}
