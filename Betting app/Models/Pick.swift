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
    /// Phase 2: real, web-search-backed supporting facts from the AI
    /// pipeline (recent form, head-to-head, key injury, decisive stat).
    /// Renders as the MATCHUP card on the detail page. Optional + decoded
    /// leniently so older picks (or any decode hiccup) just omit the card.
    let matchupFacts: [MatchupFact]?
    let result: String // "pending", "win", "loss"
    let homeScore: Int?
    let awayScore: Int?
    /// Real decimal odds for the picked outcome from an actual market
    /// (Polymarket or a major sportsbook), captured by the pipeline at
    /// generation time. Nil when no market quote was found — the
    /// detail page then falls back to confidence-implied odds.
    let marketOdds: Double?
    /// Where marketOdds came from ("Polymarket", "DraftKings", …).
    let oddsSource: String?

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
        case matchupFacts = "matchup_facts"
        case result
        case homeScore = "home_score"
        case awayScore = "away_score"
        case marketOdds = "market_odds"
        case oddsSource = "odds_source"
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

    /// Refund-guarantee eligibility: any pick the AI calls at 85%+
    /// carries the "we refund it if it loses" tag. Fulfillment is
    /// out-of-band (user submits a claim form; honored as a
    /// subscription refund/credit) — the app only displays the state.
    var isRefundEligible: Bool { probability >= 85 }

    /// User-facing pick line. Match-result leagues (Summer Football)
    /// can call a draw, so the outcome type is made explicit —
    /// "Mexico to win" / "Draw" — instead of a bare team name. Every
    /// other sport keeps the raw pick text. Call sites uppercase as
    /// needed for their typography.
    var displayPick: String {
        guard league == "WC" else { return pick }
        if pick.lowercased().contains("draw") { return "Draw" }
        return "\(pick) to win"
    }

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

        // Day boundary is computed in America/New_York (the pipeline's
        // timezone — game_date is an ET calendar date). Using
        // Calendar.current here meant a Pacific-time user near
        // midnight ET saw the awaiting/upcoming flip 3h off.
        let etCal = Self.easternCalendar
        let dayStart = etCal.startOfDay(for: now)
        if let gd = gameDateValue, gd < dayStart {
            return .awaitingResult
        }

        // Same-day staleness guard. A pick whose game is TODAY (ET),
        // still pending, with NO live_scores row at all (very common
        // while the score feed is degraded — see pipeline), would
        // otherwise fall through to `.upcoming` and render a bare
        // "VS" badge for a game that kicked off hours ago. There's no
        // start_time on the Pick itself, so we use a conservative
        // wall-clock heuristic: by ~11pm ET essentially every
        // same-day fixture across every league we cover has finished.
        // Past that hour, a still-ungraded today pick is "awaiting",
        // not "upcoming". This is deliberately late so a genuine
        // primetime game (8pm ET kickoff) still reads as upcoming
        // until it's realistically over.
        if liveScore == nil,
           let gd = gameDateValue,
           etCal.isDate(gd, inSameDayAs: dayStart) {
            let hourET = etCal.component(.hour, from: now)
            // 23:00–01:59 ET → the slate is done; ungraded == awaiting.
            if hourET >= 23 || hourET < 2 {
                return .awaitingResult
            }
        }

        // Pending + future kickoff (or kickoff unknown but date is
        // today/future) → genuinely upcoming.
        return .upcoming
    }

    /// Calendar pinned to America/New_York. The pipeline writes
    /// game_date as an ET calendar date, so every day-boundary
    /// comparison in renderState must use the same zone or a
    /// West-Coast user sees the wrong day's slate near midnight ET.
    private static let easternCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        return c
    }()
}

// MARK: - Matchup fact

/// One real, web-search-backed supporting fact for a pick — a labeled
/// value the AI pipeline generates (e.g. "Recent form" → "W-W-L-W-D").
/// Rendered in the detail page's MATCHUP card.
struct MatchupFact: Codable, Identifiable, Hashable {
    let label: String
    let value: String
    var id: String { label + value }
}

// MARK: - Lenient decoding

/// Custom decoder kept in an extension (not the struct body) so the
/// synthesized memberwise initializer is preserved — `sfPick()` and a
/// couple of fallback picks build `Pick` directly. The only behavioral
/// change vs. the synthesized decoder: `matchup_facts` decodes
/// leniently, so a malformed/absent value drops the MATCHUP card for
/// that pick instead of failing the whole decode.
extension Pick {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        sport = try c.decode(String.self, forKey: .sport)
        league = try c.decode(String.self, forKey: .league)
        gameDate = try c.decode(String.self, forKey: .gameDate)
        gameId = try c.decodeIfPresent(String.self, forKey: .gameId)
        homeTeam = try c.decode(String.self, forKey: .homeTeam)
        awayTeam = try c.decode(String.self, forKey: .awayTeam)
        pick = try c.decode(String.self, forKey: .pick)
        probability = try c.decode(Double.self, forKey: .probability)
        confidence = try c.decode(String.self, forKey: .confidence)
        reasoning = try c.decode(String.self, forKey: .reasoning)
        keyFactor = try c.decodeIfPresent(String.self, forKey: .keyFactor)
        matchupFacts = (try? c.decodeIfPresent([MatchupFact].self, forKey: .matchupFacts)) ?? nil
        result = try c.decode(String.self, forKey: .result)
        homeScore = try c.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try c.decodeIfPresent(Int.self, forKey: .awayScore)
        // Lenient like matchup_facts: rows predating the market-odds
        // migration (or junk values) just fall back to implied odds.
        marketOdds = (try? c.decodeIfPresent(Double.self, forKey: .marketOdds)) ?? nil
        oddsSource = (try? c.decodeIfPresent(String.self, forKey: .oddsSource)) ?? nil
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
