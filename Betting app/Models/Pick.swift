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

    /// Parses `gameDate` (ISO yyyy-MM-dd) into a Date at midnight
    /// in the pipeline's timezone (America/New_York). Using
    /// TimeZone.current here was a subtle bug: a user in PT would
    /// see "yesterday's" pick as today's because midnight ET is
    /// 9 PM PT the previous day. The pipeline writes dates in ET
    /// so we parse them as ET.
    ///
    /// The formatter is hoisted to a static let (with en_US_POSIX
    /// locale) — the previous per-call allocation cost was visible
    /// in render-path profiling once realtime updates started
    /// triggering re-renders on every score tick.
    var gameDateValue: Date? {
        return Self.gameDateFormatter.date(from: gameDate)
    }

    private static let gameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return f
    }()

    /// Single source of truth for "what badge / chrome should this
    /// pick render with right now?". Considers (1) the graded
    /// result, (2) the live-score state of the game, (3) clock
    /// reality — game_date and start_time vs now. Without (3) a
    /// pick from yesterday with result=pending stays glued in the
    /// "UPCOMING" branch forever, which is the bug the user hit.
    func renderState(liveScore: LiveScore?, now: Date = Date()) -> PickRenderState {
        // Graded picks short-circuit — once result is win/loss the
        // game is done and the box-score sits in pick.home/awayScore.
        if isWin { return .won }
        if isLoss { return .lost }

        // Pending + the live-score row says "in progress" → LIVE.
        if liveScore?.isLive == true { return .live }

        // Pending + the live-score row says "final" → game's over
        // but we haven't graded yet (pipeline is between grade ticks).
        if liveScore?.isFinal == true { return .awaitingResult }

        // Pending + game time is in the past (either by start_time
        // or by gameDate) → not really "upcoming" anymore; the
        // pipeline hasn't caught up.
        if let kickoff = liveScore?.startTime, kickoff < now {
            return .awaitingResult
        }
        let dayStart = Calendar.current.startOfDay(for: now)
        if let gd = gameDateValue, gd < dayStart {
            return .awaitingResult
        }

        // Pending + future kickoff (or kickoff unknown but date is
        // today/future) → genuinely upcoming.
        return .upcoming
    }
}

// MARK: - Pick render state

/// Display-state for a single pick card. Every per-card view that
/// renders a badge / score / kickoff label should switch on this
/// instead of inferring the state inline from `result` + isLive,
/// so the rules stay consistent across the app.
enum PickRenderState {
    case live              // game in progress; show live score
    case won               // settled W
    case lost              // settled L
    case awaitingResult    // pending but game is in the past — needs grading
    case upcoming          // pending and game is in the future
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
