//
//  MatchStatus.swift
//  Betting app
//
//  Created by Ethan on 3/10/26.
//


import SwiftUI
import Combine

// MARK: - Oddlytics Design System Colors
extension Color {
    // Core palette — Pastel pink theme (reference: sports concept app)
    static let odPrimary     = Color(hex: "#1A1A1A")   // Black — primary text/CTA
    static let odSecondary   = Color(hex: "#C6FF4D")   // Lime green accent
    static let odBg          = Color(hex: "#F5D5DD")   // Pastel pink base
    static let odBgAlt       = Color(hex: "#EEC8D2")   // Slightly darker pink
    static let odSurface     = Color(hex: "#FFFFFF")   // Cards, sheets
    static let odSurface2    = Color(hex: "#F8F8FA")   // Secondary surface
    static let odTextPrimary = Color(hex: "#1A1A1A")   // Headings, bold labels
    static let odTextSecondary = Color(hex: "#4A4A4A") // Body text
    static let odTextMuted   = Color(hex: "#999999")   // Captions, meta
    static let odDivider     = Color(hex: "#E0C0C8")   // Borders, separators
    static let odBadgeDark   = Color(hex: "#1A1A1A")   // Badge bg — dark

    // Confidence colors
    static let odConfHigh    = Color(hex: "#1A1A1A")   // Black — high confidence
    static let odConfMed     = Color(hex: "#FFB347")   // Orange — medium
    static let odConfLow     = Color(hex: "#999999")   // Muted gray — low

    // Sport card pastel colors (from reference video)
    static let sportPink     = Color(hex: "#F5C6D0")   // Pink card
    static let sportBlue     = Color(hex: "#C6D8F5")   // Blue card
    static let sportGreen    = Color(hex: "#C6F5D0")   // Green card
    static let sportYellow   = Color(hex: "#F5ECC6")   // Yellow card
    static let sportPurple   = Color(hex: "#D8C6F5")   // Purple card
    static let sportOrange   = Color(hex: "#F5D8C6")   // Orange card

    // Legacy aliases
    static let appGreen  = Color(hex: "#34C759")
    static let appOrange = Color(hex: "#FFB347")
    static let appRed    = Color(hex: "#FF453A")
    static let appBlue   = Color(hex: "#0A84FF")
    static let appGray   = Color(hex: "#999999")
    static let appGray2  = Color(hex: "#CCCCCC")
    static let appGray3  = Color(hex: "#E5E5E5")
    static let cardBg    = Color(hex: "#FFFFFF")
    static let sheetBg   = Color(hex: "#F5D5DD")
    static let appGold   = Color(hex: "#FFE566")
    static let appAmber  = Color(hex: "#C6FF4D")
    static let surfaceOne = Color(hex: "#FFFFFF")
    static let surfaceTwo = Color(hex: "#F8F8FA")
    static let surfaceThree = Color(hex: "#F0F0F2")
    static let lightBg   = Color(hex: "#F5D5DD")
    static let darkText  = Color(hex: "#1A1A1A")
    static let secondaryText = Color(hex: "#999999")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Sport Gradients (Oddlytics)
struct SportGradient {
    /// Pastel card color for each sport
    static func cardColor(for sport: String) -> Color {
        switch sport.lowercased() {
        case "nba":    return .sportPink
        case "nhl":    return .sportBlue
        case "nfl":    return .sportGreen
        case "soccer": return .sportPink
        case "f1":     return .sportOrange
        default:       return .sportPink
        }
    }

    static func colors(for sport: String) -> [Color] {
        let base = cardColor(for: sport)
        return [base, base.opacity(0.7)]
    }

    static func gradient(for sport: String) -> LinearGradient {
        LinearGradient(
            colors: colors(for: sport),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Models
enum MatchStatus { case live, final_, upcoming }
enum Confidence  { case high, med, low }

extension Confidence {
    var color: Color {
        switch self { case .high: return .odConfHigh; case .med: return .odConfMed; case .low: return .odConfLow }
    }
    var label: String {
        switch self { case .high: return "HIGH"; case .med: return "MED"; case .low: return "LOW" }
    }
}

struct TeamInfo {
    let name: String
    let abbr: String
    let score: Int?
    let record: String
    let color: Color
}

struct H2H {
    let awayWins: Int
    let homeWins: Int
    let note: String
}

struct LineMove {
    let from: String
    let to: String
    let label: String
}

struct StatBar {
    let label: String
    let awayVal: String
    let homeVal: String
    let awayNum: Double
    let homeNum: Double
}

struct Signal: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let favor: String // "away", "home", "neutral"
}

struct Match: Identifiable {
    let id: Int
    let sport: String
    let league: String
    let status: String
    let statusType: MatchStatus
    let away: TeamInfo
    let home: TeamInfo
    let aiPick: String
    let aiPickAbbr: String
    let confidence: Confidence
    let confPct: Int
    let awayPct: Int
    let homePct: Int
    let oddsAway: String
    let oddsHome: String
    let spreadAway: String
    let spreadHome: String
    let overUnder: String
    let aiAccuracy: Int
    let formAway: [String]
    let formHome: [String]
    let h2h: H2H
    let lineMove: LineMove

    var hasScore: Bool { away.score != nil }

    var sportIcon: String {
        switch sport {
        case "nba": return "basketball.fill"
        case "soccer": return "soccerball"
        case "nfl": return "football.fill"
        case "nhl": return "hockey.puck.fill"
        case "f1": return "flag.checkered"
        default: return "sportscourt.fill"
        }
    }

    /// Dynamic confidence color: >=75% pink, >=68% orange, <68% muted
    var confColor: Color {
        if confPct >= 75 { return .odConfHigh }
        else if confPct >= 68 { return .odConfMed }
        else { return .odConfLow }
    }

    func statBars() -> [StatBar] {
        switch sport {
        case "nba": return [
            StatBar(label: "Points/G",  awayVal: "118.4", homeVal: "112.7", awayNum: 118.4, homeNum: 112.7),
            StatBar(label: "Opp Pts/G", awayVal: "109.2", homeVal: "115.8", awayNum: 109.2, homeNum: 115.8),
            StatBar(label: "3PT %",     awayVal: "37.8%", homeVal: "34.2%", awayNum: 37.8,  homeNum: 34.2),
            StatBar(label: "Rebounds",  awayVal: "46.1",  homeVal: "43.8",  awayNum: 46.1,  homeNum: 43.8),
        ]
        case "soccer": return [
            StatBar(label: "Goals/G", awayVal: "2.1", homeVal: "1.8", awayNum: 2.1, homeNum: 1.8),
            StatBar(label: "xG",      awayVal: "1.9", homeVal: "1.5", awayNum: 1.9, homeNum: 1.5),
            StatBar(label: "Poss %",  awayVal: "58%", homeVal: "54%", awayNum: 58,  homeNum: 54),
        ]
        case "nfl": return [
            StatBar(label: "Pts/G",   awayVal: "27.4", homeVal: "21.8", awayNum: 27.4, homeNum: 21.8),
            StatBar(label: "Yds/G",   awayVal: "382",  homeVal: "341",  awayNum: 382,  homeNum: 341),
            StatBar(label: "3rd Dn%", awayVal: "48%",  homeVal: "34%",  awayNum: 48,   homeNum: 34),
        ]
        case "nhl": return [
            StatBar(label: "Goals/G", awayVal: "3.8",  homeVal: "2.4",  awayNum: 3.8,  homeNum: 2.4),
            StatBar(label: "Save %",  awayVal: ".924", homeVal: ".898", awayNum: 92.4, homeNum: 89.8),
            StatBar(label: "PP %",    awayVal: "24.1", homeVal: "17.8", awayNum: 24.1, homeNum: 17.8),
        ]
        case "f1": return [
            StatBar(label: "Wins",     awayVal: "7",    homeVal: "5",    awayNum: 7,    homeNum: 5),
            StatBar(label: "Podiums",  awayVal: "14",   homeVal: "11",   awayNum: 14,   homeNum: 11),
            StatBar(label: "Points",   awayVal: "389",  homeVal: "312",  awayNum: 389,  homeNum: 312),
        ]
        default: return [
            StatBar(label: "Form",   awayVal: "4-1", homeVal: "2-3", awayNum: 4, homeNum: 2),
            StatBar(label: "H2H",    awayVal: "6",   homeVal: "4",   awayNum: 6, homeNum: 4),
            StatBar(label: "Rating", awayVal: "8.2", homeVal: "7.1", awayNum: 82, homeNum: 71),
        ]
        }
    }

    func signals() -> [Signal] {
        let pa = aiPickAbbr == away.abbr
        switch sport {
        case "soccer": return [
            Signal(label: "Recent Form",  value: "\(away.abbr): \(formAway.joined()) · \(home.abbr): \(formHome.joined())", favor: pa ? "away" : "home"),
            Signal(label: "Head to Head", value: "\(pa ? away.abbr : home.abbr) \(pa ? h2h.awayWins : h2h.homeWins)-\(pa ? h2h.homeWins : h2h.awayWins) (L10)", favor: pa ? "away" : "home"),
            Signal(label: "xG",           value: "\(pa ? away.abbr : home.abbr) 1.8 vs 0.9", favor: pa ? "away" : "home"),
            Signal(label: "Injury",       value: "1 key player out", favor: "neutral"),
            Signal(label: "Line Move",    value: "\(lineMove.from) → \(lineMove.to)", favor: pa ? "away" : "home"),
        ]
        case "nfl": return [
            Signal(label: "Recent Form",   value: "\(away.abbr) 4-1, \(home.abbr) 2-3 (L5)", favor: "away"),
            Signal(label: "Head to Head",  value: "\(pa ? away.abbr : home.abbr) \(pa ? h2h.awayWins : h2h.homeWins)-\(pa ? h2h.homeWins : h2h.awayWins) (L10)", favor: pa ? "away" : "home"),
            Signal(label: "3rd Down %",    value: "48% vs 34%", favor: "away"),
            Signal(label: "Turnover Diff", value: "+6 on season", favor: pa ? "away" : "home"),
            Signal(label: "Weather",       value: "38°F, 12 mph wind", favor: "neutral"),
        ]
        case "nhl": return [
            Signal(label: "Recent Form",  value: "\(away.abbr) 4-1, \(home.abbr) 1-4 (L5)", favor: "away"),
            Signal(label: "Head to Head", value: "\(pa ? away.abbr : home.abbr) \(pa ? h2h.awayWins : h2h.homeWins)-\(pa ? h2h.homeWins : h2h.awayWins) (L10)", favor: pa ? "away" : "home"),
            Signal(label: "Save %",       value: "\(pa ? away.abbr : home.abbr) .924 vs .898", favor: pa ? "away" : "home"),
            Signal(label: "Power Play %", value: "24.1% vs 17.8%", favor: pa ? "away" : "home"),
            Signal(label: "Line Move",    value: "\(lineMove.from) → \(lineMove.to)", favor: pa ? "away" : "home"),
        ]
        default: return [
            Signal(label: "Recent Form",      value: "\(away.abbr) 4-1, \(home.abbr) 2-3 (L5)", favor: pa ? "away" : "home"),
            Signal(label: "Head to Head",     value: "\(pa ? away.abbr : home.abbr) \(pa ? h2h.awayWins : h2h.homeWins)-\(pa ? h2h.homeWins : h2h.awayWins) (L10)", favor: pa ? "away" : "home"),
            Signal(label: "PPG Edge",         value: "\(pa ? away.abbr : home.abbr) +5.8 avg", favor: pa ? "away" : "home"),
            Signal(label: "Defensive Rating", value: "#4 vs #18", favor: pa ? "away" : "home"),
            Signal(label: "Rest",             value: "\(pa ? away.abbr : home.abbr): 3 days", favor: pa ? "away" : "home"),
            Signal(label: "Line Move",        value: "\(lineMove.from) → \(lineMove.to)", favor: pa ? "away" : "home"),
        ]
        }
    }
}

// MARK: - Sample Data
let sampleMatches: [Match] = [
    Match(id: 1, sport: "nba", league: "NBA", status: "3rd 8:39", statusType: .live,
          away: TeamInfo(name: "Warriors", abbr: "GSW", score: 57, record: "32-18", color: Color(hex: "#1D428A")),
          home: TeamInfo(name: "Lakers",   abbr: "LAL", score: 62, record: "28-22", color: Color(hex: "#552583")),
          aiPick: "Lakers", aiPickAbbr: "LAL", confidence: .high, confPct: 71,
          awayPct: 29, homePct: 71, oddsAway: "+185", oddsHome: "-220",
          spreadAway: "+5.5", spreadHome: "-5.5", overUnder: "224.5", aiAccuracy: 74,
          formAway: ["W","L","W","W","L"], formHome: ["W","W","W","L","W"],
          h2h: H2H(awayWins: 3, homeWins: 7, note: "Lakers dominate series"),
          lineMove: LineMove(from: "-195", to: "-220", label: "Sharp money on Lakers")),

    Match(id: 2, sport: "soccer", league: "Premier League", status: "63'", statusType: .live,
          away: TeamInfo(name: "Arsenal",  abbr: "ARS", score: 1, record: "", color: Color(hex: "#EF0107")),
          home: TeamInfo(name: "Man City", abbr: "MCI", score: 1, record: "", color: Color(hex: "#6CABDD")),
          aiPick: "Arsenal", aiPickAbbr: "ARS", confidence: .med, confPct: 58,
          awayPct: 58, homePct: 42, oddsAway: "+110", oddsHome: "+240",
          spreadAway: "-0.5", spreadHome: "+0.5", overUnder: "2.5", aiAccuracy: 61,
          formAway: ["W","W","D","W","W"], formHome: ["W","L","W","D","L"],
          h2h: H2H(awayWins: 6, homeWins: 4, note: "Arsenal strong recently"),
          lineMove: LineMove(from: "+120", to: "+110", label: "Money moving to Arsenal")),

    Match(id: 3, sport: "f1", league: "Formula 1", status: "Sun 2:00 PM", statusType: .upcoming,
          away: TeamInfo(name: "Red Bull", abbr: "RBR", score: nil, record: "1st WCC", color: Color(hex: "#3671C6")),
          home: TeamInfo(name: "Ferrari",  abbr: "FER", score: nil, record: "2nd WCC", color: Color(hex: "#E80020")),
          aiPick: "Red Bull", aiPickAbbr: "RBR", confidence: .high, confPct: 74,
          awayPct: 74, homePct: 26, oddsAway: "-180", oddsHome: "+150",
          spreadAway: "N/A", spreadHome: "N/A", overUnder: "N/A", aiAccuracy: 68,
          formAway: ["W","W","W","L","W"], formHome: ["W","L","W","W","L"],
          h2h: H2H(awayWins: 7, homeWins: 3, note: "Red Bull leads season"),
          lineMove: LineMove(from: "-170", to: "-180", label: "Favoring Red Bull")),

    Match(id: 4, sport: "nhl", league: "NHL", status: "2nd 14:22", statusType: .live,
          away: TeamInfo(name: "Maple Leafs", abbr: "TOR", score: 3, record: "28-14-5", color: Color(hex: "#002654")),
          home: TeamInfo(name: "Canadiens",   abbr: "MTL", score: 2, record: "18-25-4", color: Color(hex: "#AF1E2D")),
          aiPick: "Maple Leafs", aiPickAbbr: "TOR", confidence: .high, confPct: 76,
          awayPct: 76, homePct: 24, oddsAway: "-185", oddsHome: "+155",
          spreadAway: "-1.5", spreadHome: "+1.5", overUnder: "5.5", aiAccuracy: 69,
          formAway: ["W","W","L","W","W"], formHome: ["L","L","W","L","L"],
          h2h: H2H(awayWins: 6, homeWins: 4, note: "Toronto leads series"),
          lineMove: LineMove(from: "-170", to: "-185", label: "Heavy action on Toronto")),

    Match(id: 5, sport: "soccer", league: "MLS", status: "6:30 PM", statusType: .upcoming,
          away: TeamInfo(name: "Orlando", abbr: "ORL", score: nil, record: "9-5-7", color: Color(hex: "#633492")),
          home: TeamInfo(name: "Toronto", abbr: "TFC", score: nil, record: "3-9-10", color: Color(hex: "#B81137")),
          aiPick: "Orlando", aiPickAbbr: "ORL", confidence: .med, confPct: 64,
          awayPct: 64, homePct: 36, oddsAway: "-110", oddsHome: "+155",
          spreadAway: "-0.5", spreadHome: "+0.5", overUnder: "2.5", aiAccuracy: 59,
          formAway: ["W","D","W","W","L"], formHome: ["L","L","D","L","W"],
          h2h: H2H(awayWins: 7, homeWins: 3, note: "Orlando leads H2H"),
          lineMove: LineMove(from: "-100", to: "-110", label: "Slight move to Orlando")),

    Match(id: 6, sport: "nfl", league: "NFL", status: "Sun 4:25 PM", statusType: .upcoming,
          away: TeamInfo(name: "Eagles",  abbr: "PHI", score: nil, record: "11-6", color: Color(hex: "#004C54")),
          home: TeamInfo(name: "Cowboys", abbr: "DAL", score: nil, record: "8-9",  color: Color(hex: "#003594")),
          aiPick: "Eagles", aiPickAbbr: "PHI", confidence: .high, confPct: 82,
          awayPct: 82, homePct: 18, oddsAway: "-175", oddsHome: "+148",
          spreadAway: "-4.5", spreadHome: "+4.5", overUnder: "47.5", aiAccuracy: 77,
          formAway: ["W","W","W","L","W"], formHome: ["L","W","L","L","W"],
          h2h: H2H(awayWins: 7, homeWins: 3, note: "Eagles 7-3 last 10 vs DAL"),
          lineMove: LineMove(from: "-165", to: "-175", label: "Heavy action on Eagles")),

    Match(id: 7, sport: "nba", league: "NBA", status: "9:30 PM", statusType: .upcoming,
          away: TeamInfo(name: "Celtics", abbr: "BOS", score: nil, record: "42-14", color: Color(hex: "#007A33")),
          home: TeamInfo(name: "Heat",    abbr: "MIA", score: nil, record: "27-29", color: Color(hex: "#98002E")),
          aiPick: "Celtics", aiPickAbbr: "BOS", confidence: .high, confPct: 88,
          awayPct: 88, homePct: 12, oddsAway: "-310", oddsHome: "+248",
          spreadAway: "-8.5", spreadHome: "+8.5", overUnder: "214.5", aiAccuracy: 81,
          formAway: ["W","W","W","W","L"], formHome: ["L","L","W","L","L"],
          h2h: H2H(awayWins: 8, homeWins: 2, note: "Celtics dominant H2H"),
          lineMove: LineMove(from: "-290", to: "-310", label: "Sharp money: Celtics")),
]

// MARK: - Shared Components

// MARK: - ESPN CDN Logo URL Helper
func teamLogoURL(sport: String, abbr: String) -> URL? {
    let a = abbr.lowercased()
    switch sport {
    case "nba":
        return URL(string: "https://a.espncdn.com/i/teamlogos/nba/500/\(a).png")
    case "nfl":
        return URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(a).png")
    case "nhl":
        return URL(string: "https://a.espncdn.com/i/teamlogos/nhl/500/\(a).png")
    case "soccer":
        let soccerIDs: [String: String] = [
            "ars": "359", "mci": "382", "liv": "364", "che": "363",
            "mun": "360", "tot": "367", "orl": "9598", "tfc": "7035",
        ]
        if let id = soccerIDs[a] {
            return URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/\(id).png")
        }
        return nil
    case "f1":
        let f1Map: [String: String] = [
            "rbr": "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/red-bull-racing-logo.png",
            "fer": "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/ferrari-logo.png",
            "mcl": "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/mclaren-logo.png",
            "mer": "https://media.formula1.com/d_team_car_fallback_image.png/content/dam/fom-website/teams/2024/mercedes-logo.png",
        ]
        if let u = f1Map[a] { return URL(string: u) }
        return nil
    default:
        return nil
    }
}

struct TeamLogo: View {
    let abbr: String
    let color: Color
    var size: CGFloat = 38
    var sport: String = ""

    private var logoURL: URL? {
        teamLogoURL(sport: sport, abbr: abbr)
    }

    var body: some View {
        if let url = logoURL {
            // Real team logo from ESPN CDN
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .shadow(color: color.opacity(0.4), radius: size * 0.12)
                case .failure:
                    fallbackLogo
                default:
                    fallbackLogo.opacity(0.5)
                }
            }
        } else {
            fallbackLogo
        }
    }

    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 1))
                .shadow(color: color.opacity(0.35), radius: size * 0.12)
            Text(String(abbr.prefix(3)))
                .font(.system(size: size * 0.3, weight: .black))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: size, height: size)
    }
}

struct LiveBadge: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(Color.appRed.opacity(0.4))
                    .frame(width: pulsing ? 12 : 7, height: pulsing ? 12 : 7)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
                Circle()
                    .fill(Color.appRed)
                    .frame(width: 7, height: 7)
            }
            Text("LIVE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.appRed)
                .kerning(0.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.appRed.opacity(0.15))
        .overlay(RoundedRectangle(cornerRadius: 99).stroke(Color.appRed.opacity(0.4), lineWidth: 0.5))
        .clipShape(Capsule())
        .onAppear { pulsing = true }
    }
}

struct StatusPillView: View {
    let match: Match
    var body: some View {
        switch match.statusType {
        case .live:
            HStack(spacing: 4) {
                LiveBadge()
                Text(match.status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.darkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        case .final_:
            Text("Final")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Color.black.opacity(0.05))
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                .clipShape(Capsule())
        case .upcoming:
            Text(match.status)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.appBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Color.appBlue.opacity(0.12))
                .overlay(Capsule().stroke(Color.appBlue.opacity(0.25), lineWidth: 0.5))
                .clipShape(Capsule())
        }
    }
}

struct FormBubblesView: View {
    let results: [String]
    private var bubbleSize: CGFloat { isCompactPhone ? 24 : 28 }
    var body: some View {
        HStack(spacing: isCompactPhone ? 4 : 6) {
            ForEach(results, id: \.self) { r in
                let c: Color = r == "W" ? .appGreen : r == "L" ? .appRed : .appOrange
                ZStack {
                    Circle().fill(c.opacity(0.12))
                    Circle().stroke(c, lineWidth: 1.5)
                    Text(r).font(.system(size: bubbleSize * 0.36, weight: .black)).foregroundColor(c)
                }
                .frame(width: bubbleSize, height: bubbleSize)
            }
        }
    }
}

// MARK: - Glassmorphism Card
struct GlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .background(
                ZStack {
                    Color.black.opacity(0.04)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.3))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.black.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

// MARK: - Confidence Ring
struct ConfidenceRing: View {
    let percentage: Int
    let color: Color
    @State private var animatedPct: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: animatedPct)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.4), color, color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 4)
            VStack(spacing: 1) {
                Text("\(Int(animatedPct * 100))%")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text("conf")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.appGray)
                    .textCase(.uppercase)
                    .kerning(0.5)
            }
        }
        .frame(width: 64, height: 64)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2)) {
                animatedPct = CGFloat(percentage) / 100.0
            }
        }
    }
}

// MARK: - Sport Filter Chip (Oddlytics)
struct SportChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .black : .medium))
                .foregroundColor(isSelected ? .white : .odTextPrimary.opacity(0.5))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? Color.odTextPrimary : Color.odTextPrimary.opacity(0.06))
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Screen-adaptive helpers
private let isCompactPhone: Bool = false
private let featuredCardHeight: CGFloat = 240
private let heroImageHeight: CGFloat = 260
private let scoreFontSize: CGFloat = 38
private let detailScoreFontSize: CGFloat = 54

// MARK: - Featured Card
struct FeaturedCard: View {
    let sportImages: [(String, String, String)] = [
        ("https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800&q=80", "NBA", "basketball.fill"),
        ("https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=800&q=80", "Soccer", "soccerball"),
        ("https://images.unsplash.com/photo-1560272564-c83b66b1ad12?w=800&q=80", "NFL", "football.fill"),
        ("https://images.unsplash.com/photo-1515703407324-5f753afd8be8?w=800&q=80", "NHL", "hockey.puck.fill"),
        ("https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&q=80", "F1", "flag.checkered"),
    ]
    @State private var currentIndex = 0
    @State private var loadedImages: [Int: Bool] = [:]
    let timer = Timer.publish(every: 4.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Fixed-size container prevents layout shifts
            ZStack {
                ForEach(0..<sportImages.count, id: \.self) { idx in
                    AsyncImage(url: URL(string: sportImages[idx].0)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Rectangle().fill(Color.odBgAlt)
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width - 28, height: featuredCardHeight)
                    .clipped()
                    .opacity(idx == currentIndex ? 1 : 0)
                }
            }
            .frame(height: featuredCardHeight)

            // Bottom gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.45), .black.opacity(0.85)],
                startPoint: UnitPoint(x: 0.5, y: 0.3),
                endPoint: .bottom
            )

            // Sport badge + page dots (top)
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: sportImages[currentIndex].2)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                        Text(sportImages[currentIndex].1.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .kerning(1.5)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(0..<sportImages.count, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 99)
                                .fill(i == currentIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(width: i == currentIndex ? 18 : 6, height: 6)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentIndex)
                                .onTapGesture { currentIndex = i }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                Spacer()
            }

            // Bottom content overlay
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S TOP PICKS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.odPrimary)
                    .kerning(1.5)
                Text("AI-powered predictions\nacross all sports")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(-0.5)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10, weight: .bold))
                        Text("74% Accuracy")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.odPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.odPrimary.opacity(0.2))
                    .clipShape(Capsule())

                    HStack(spacing: 5) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .bold))
                        Text("7 picks")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: featuredCardHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 14)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentIndex = (currentIndex + 1) % sportImages.count
            }
        }
    }
}

// MARK: - Prediction Card (Oddlytics — White Floating Card)
// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.4), location: 0.45),
                            .init(color: .white.opacity(0.4), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

struct SkeletonPredCard: View {
    var body: some View {
        VStack(spacing: 0) {
            // Sport badge + status
            HStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.odBgAlt).frame(width: 50, height: 18)
                RoundedRectangle(cornerRadius: 4).fill(Color.odBgAlt).frame(width: 60, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: 8).fill(Color.odBgAlt).frame(width: 55, height: 20)
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 10)

            // Pick name
            RoundedRectangle(cornerRadius: 6).fill(Color.odBgAlt).frame(width: 180, height: 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22).padding(.bottom, 6)

            // Subtitle
            RoundedRectangle(cornerRadius: 4).fill(Color.odBgAlt).frame(width: 140, height: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22).padding(.bottom, 14)

            // Confidence bar
            RoundedRectangle(cornerRadius: 99).fill(Color.odBgAlt).frame(height: 5)
                .padding(.horizontal, 22).padding(.bottom, 16)

            // Teams
            HStack {
                Circle().fill(Color.odBgAlt).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.odBgAlt).frame(width: 70, height: 12)
                    RoundedRectangle(cornerRadius: 3).fill(Color.odBgAlt).frame(width: 40, height: 10)
                }
                Spacer()
                RoundedRectangle(cornerRadius: 4).fill(Color.odBgAlt).frame(width: 50, height: 20)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.odBgAlt).frame(width: 70, height: 12)
                    RoundedRectangle(cornerRadius: 3).fill(Color.odBgAlt).frame(width: 40, height: 10)
                }
                Circle().fill(Color.odBgAlt).frame(width: 40, height: 40)
            }
            .padding(.horizontal, 22).padding(.bottom, 18)
        }
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .modifier(ShimmerModifier())
    }
}

// MARK: - Flip Digit View

struct FlipDigitView: View {
    let value: Int
    @State private var displayedValue: Int
    @State private var animating = false

    init(value: Int) {
        self.value = value
        self._displayedValue = State(initialValue: value)
    }

    var body: some View {
        Text("\(displayedValue)")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(.odTextPrimary)
            .id("score-\(displayedValue)")
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .onChange(of: value) { _, newVal in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    displayedValue = newVal
                }
            }
    }
}

// MARK: - Confetti View

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var rotation: Double
    var rotSpeed: Double
    var color: Color
    var size: CGFloat
    var opacity: Double = 1.0
}

struct ConfettiView: View {
    @Binding var trigger: Bool
    @State private var pieces: [ConfettiPiece] = []
    @State private var startTime: Date?

    private let colors: [Color] = [.odPrimary, .odSecondary, Color(hex: "#34C759"), .white, Color(hex: "#FFB347")]

    var body: some View {
        TimelineView(.animation(paused: pieces.isEmpty)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date
                guard let start = startTime else { return }
                let elapsed = now.timeIntervalSince(start)

                for piece in pieces {
                    let t = CGFloat(elapsed)
                    let px = piece.x + piece.vx * t
                    let py = piece.y + piece.vy * t + 400 * t * t // gravity
                    let rot = piece.rotation + piece.rotSpeed * Double(t)
                    let alpha = max(0, 1.0 - Double(t) / 2.0)

                    guard alpha > 0, py < size.height + 50 else { continue }

                    ctx.opacity = alpha
                    ctx.translateBy(x: px, y: py)
                    ctx.rotate(by: .degrees(rot))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 2, width: piece.size, height: piece.size * 0.6)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
                    ctx.rotate(by: .degrees(-rot))
                    ctx.translateBy(x: -px, y: -py)
                    ctx.opacity = 1
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, fire in
            if fire {
                spawnConfetti()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    pieces = []
                    startTime = nil
                    trigger = false
                }
            }
        }
    }

    private func spawnConfetti() {
        startTime = Date()
        pieces = (0..<50).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 120...260),
                y: CGFloat.random(in: 0...30),
                vx: CGFloat.random(in: -180...180),
                vy: CGFloat.random(in: -500 ... -200),
                rotation: Double.random(in: 0...360),
                rotSpeed: Double.random(in: -400...400),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 5...10)
            )
        }
    }
}

// MARK: - Streak Badge

struct StreakBadge: View {
    let streak: Int
    @State private var showPopover = false
    @State private var flamePulse = false
    @State private var emberOffsets: [CGFloat] = [0, 0, 0, 0]

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPopover.toggle()
        } label: {
            ZStack {
                // Ember particles
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i % 2 == 0 ? Color.odPrimary : Color.odSecondary)
                        .frame(width: CGFloat.random(in: 3...5), height: CGFloat.random(in: 3...5))
                        .offset(
                            x: CGFloat([-6, 6, -3, 4][i]),
                            y: emberOffsets[i]
                        )
                        .opacity(0.6)
                }

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#FF6B3D"))
                        .scaleEffect(flamePulse ? 1.15 : 1.0)
                    Text("\(streak)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.odTextPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.odSurface)
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#FF6B3D").opacity(0.2), radius: 8, y: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
            // Ember float animation
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                emberOffsets = [-12, -16, -10, -14]
            }
        }
        .popover(isPresented: $showPopover) {
            streakPopover
        }
    }

    private var streakPopover: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FF6B3D"))
                Text("\(streak) game streak")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.odTextPrimary)
            }

            Divider()

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(streak)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.odTextPrimary)
                    Text("Current").font(.system(size: 10, weight: .medium)).foregroundColor(.odTextMuted)
                }
                VStack(spacing: 2) {
                    Text("12").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.odPrimary)
                    Text("Best").font(.system(size: 10, weight: .medium)).foregroundColor(.odTextMuted)
                }
                VStack(spacing: 2) {
                    Text("74%").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.odTextPrimary)
                    Text("Accuracy").font(.system(size: 10, weight: .medium)).foregroundColor(.odTextMuted)
                }
            }

            // Mini bar chart — last 7 days
            VStack(alignment: .leading, spacing: 6) {
                Text("Last 7 days")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.odTextMuted)
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<7, id: \.self) { i in
                        let heights: [CGFloat] = [28, 36, 22, 40, 32, 44, 38]
                        let won = [true, true, false, true, true, true, true]
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(won[i] ? Color.odPrimary : Color.odBgAlt)
                                .frame(width: 20, height: heights[i])
                            Text(["M","T","W","T","F","S","S"][i])
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.odTextMuted)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 260)
        .background(Color.odSurface)
    }
}

// MARK: - Quick Look Preview (Context Menu)

struct QuickLookPreview: View {
    let match: Match

    private var scoreText: String {
        if match.hasScore, let a = match.away.score, let h = match.home.score {
            return "\(a) – \(h)"
        }
        return ""
    }

    private func signalColor(for signal: Signal) -> Color {
        if signal.favor == "away" { return Color.odPrimary }
        if signal.favor == "home" { return Color.odConfMed }
        return Color.odTextMuted
    }

    private var gradientHeader: some View {
        ZStack {
            LinearGradient(
                colors: SportGradient.colors(for: match.sport),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Text(match.league)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        TeamLogo(abbr: match.away.abbr, color: match.away.color, size: 36, sport: match.sport)
                        Text(match.away.abbr).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    }
                    if match.hasScore {
                        Text(scoreText).font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.white)
                    } else {
                        Text("vs").font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.7))
                    }
                    VStack(spacing: 4) {
                        TeamLogo(abbr: match.home.abbr, color: match.home.color, size: 36, sport: match.sport)
                        Text(match.home.abbr).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .frame(height: 120)
    }

    var body: some View {
        VStack(spacing: 0) {
            gradientHeader

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Pick").font(.system(size: 10, weight: .medium)).foregroundColor(.odTextMuted)
                        Text(match.aiPick).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(.odTextPrimary)
                    }
                    Spacer()
                    ConfidenceRing(percentage: match.confPct, color: match.confColor)
                        .frame(width: 44, height: 44)
                }

                ForEach(Array(match.signals().prefix(2))) { signal in
                    HStack(spacing: 8) {
                        Circle().fill(signalColor(for: signal)).frame(width: 6, height: 6)
                        Text(signal.label).font(.system(size: 12, weight: .medium)).foregroundColor(.odTextSecondary)
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(Color.odSurface)
        }
        .frame(width: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - PredCard

struct PredCard: View {
    let match: Match
    let onTap: () -> Void
    var onSave: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    @State private var appeared = false
    @State private var barActive = false
    @State private var isPressed = false
    @State private var pulsing = false
    @State private var dragOffset: CGFloat = 0
    @State private var showConfetti = false

    let index: Int

    var dynColor: Color { match.confColor }
    var pickAway: Bool { match.aiPickAbbr == match.away.abbr }

    private var edgePct: Int {
        let homeNum = Int(match.oddsHome.replacingOccurrences(of: "+", with: "")) ?? 0
        let implH = homeNum < 0 ? Int(Double(abs(homeNum)) / Double(abs(homeNum) + 100) * 100) : Int(100.0 / Double(homeNum + 100) * 100)
        let pickedImpl = pickAway ? (100 - implH) : implH
        return (pickAway ? match.awayPct : match.homePct) - pickedImpl
    }

    private var swipeReveal: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "star.fill").font(.system(size: 20, weight: .bold))
                Text("Save").font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 32)
            Spacer()
            HStack(spacing: 8) {
                Text("Hide").font(.system(size: 14, weight: .bold))
                Image(systemName: "eye.slash.fill").font(.system(size: 20, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            HStack(spacing: 0) {
                Color.odPrimary.opacity(dragOffset > 0 ? 1 : 0)
                Color.appRed.opacity(dragOffset < 0 ? 1 : 0)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .opacity(abs(dragOffset) > 10 ? 1 : 0)
    }

    /// Sport-based pastel card color
    private var cardColor: Color { SportGradient.cardColor(for: match.sport) }

    var body: some View {
        ZStack {
            swipeReveal

            // Main card — Reference style: colored bg, big time, team logos
            VStack(spacing: 0) {
                // Team logos + date row
                HStack(spacing: 0) {
                    // Away & home small logos
                    HStack(spacing: -6) {
                        TeamLogo(abbr: match.away.abbr, color: match.away.color, size: 28, sport: match.sport)
                        TeamLogo(abbr: match.home.abbr, color: match.home.color, size: 28, sport: match.sport)
                    }

                    Spacer()

                    // Date
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("08")
                            .font(.system(size: 11, weight: .bold))
                        Text("SEPTEMBER")
                            .font(.system(size: 7, weight: .bold))
                            .kerning(0.5)
                    }
                    .foregroundColor(.odTextPrimary.opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

                // Big time display
                Text(match.statusType == .upcoming ? "TBD" : match.status)
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(.odTextPrimary)
                    .tracking(-2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                // League label
                Text(match.league.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.odTextPrimary.opacity(0.35))
                    .kerning(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Teams row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(match.away.name.uppercased())
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.odTextPrimary)
                        Text(match.away.abbr.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.odTextPrimary.opacity(0.4))
                    }
                    Spacer()
                    if match.hasScore {
                        Text("\(match.away.score!) – \(match.home.score!)")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.odTextPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(match.home.name.uppercased())
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.odTextPrimary)
                        Text(match.home.abbr.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.odTextPrimary.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                // Confidence bar
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 99)
                                .fill(Color.odTextPrimary.opacity(0.1))
                            RoundedRectangle(cornerRadius: 99)
                                .fill(Color.odTextPrimary)
                                .frame(width: barActive ? geo.size.width * CGFloat(match.confPct) / 100 : 0)
                                .animation(.spring(response: 0.9, dampingFraction: 0.8), value: barActive)
                        }
                    }
                    .frame(height: 4)

                    Text("\(match.confPct)%")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.odTextPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .background(cardColor)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .offset(x: dragOffset)
            .rotationEffect(.degrees(Double(dragOffset) / 40), anchor: .bottom)

            ConfettiView(trigger: $showConfetti)
        }
        .scaleEffect(isPressed ? 0.975 : (appeared ? 1.0 : 0.97))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(.spring(response: 0.42, dampingFraction: 0.75).delay(Double(index) * 0.06), value: appeared)
        .contextMenu {
            Button { onSave?() } label: { Label("Save Pick", systemImage: "star") }
            Button { } label: { Label("Share", systemImage: "square.and.arrow.up") }
            Button(role: .destructive) { onDismiss?() } label: { Label("Hide", systemImage: "eye.slash") }
        } preview: {
            QuickLookPreview(match: match)
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onChanged { v in
                    dragOffset = v.translation.width
                }
                .onEnded { v in
                    if v.translation.width > 120 {
                        // Save
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                        onSave?()
                    } else if v.translation.width < -120 {
                        // Dismiss
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        withAnimation(.spring(response: 0.3)) { dragOffset = 0 }
                        onDismiss?()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = 0 }
                    }
                }
        )
        .onTapGesture {
            onTap()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .onAppear {
            appeared = true
            if match.statusType == .live { pulsing = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.06) {
                barActive = true
            }
        }
    }

    private func signalDotColor(_ signal: Signal) -> Color {
        if signal.favor == "away" { return Color.odPrimary }
        if signal.favor == "home" { return Color.odConfMed }
        return Color.odTextMuted
    }

    private var expandSpread: String { pickAway ? match.spreadAway : match.spreadHome }
    private var expandML: String { pickAway ? match.oddsAway : match.oddsHome }

    private var expandedContent: some View {
        VStack(spacing: 12) {
            Divider().padding(.horizontal, 22)

            HStack(spacing: 0) {
                expandOddsItem(label: "Spread", value: expandSpread)
                expandOddsItem(label: "Moneyline", value: expandML)
                expandOddsItem(label: "O/U", value: match.overUnder)
            }
            .padding(.horizontal, 22)

            expandedSignals

            expandedForm
        }
    }

    private var expandedSignals: some View {
        VStack(spacing: 6) {
            ForEach(Array(match.signals().prefix(3))) { signal in
                HStack(spacing: 8) {
                    Circle().fill(signalDotColor(signal)).frame(width: 6, height: 6)
                    Text(signal.label).font(.system(size: 12, weight: .medium)).foregroundColor(.odTextSecondary)
                    Spacer()
                    Text(signal.value).font(.system(size: 11)).foregroundColor(.odTextMuted)
                }
            }
        }
        .padding(.horizontal, 22)
    }

    private var expandedForm: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(match.away.abbr).font(.system(size: 10, weight: .bold)).foregroundColor(.odTextMuted)
                FormBubblesView(results: match.formAway)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(match.home.abbr).font(.system(size: 10, weight: .bold)).foregroundColor(.odTextMuted)
                FormBubblesView(results: match.formHome)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    private func expandOddsItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.odTextMuted)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.odTextPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Date Picker
struct DatePickerRow: View {
    @Binding var selectedDate: Date
    let days: [Date]

    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private let numFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
    private let monFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()

    let gameDayIndices: Set<Int> = [0, 2, 4]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    let isSel = calendar.isDate(day, inSameDayAs: selectedDate)
                    let hasGames = gameDayIndices.contains(i)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = day
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(i == 0 ? "Today" : dayFormatter.string(from: day).uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isSel ? .white.opacity(0.7) : .secondaryText)
                                .kerning(0.3)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(numFormatter.string(from: day))
                                .font(.system(size: isCompactPhone ? 18 : 20, weight: .heavy, design: .rounded))
                                .foregroundColor(isSel ? .white : .darkText)
                            Text(monFormatter.string(from: day).uppercased())
                                .font(.system(size: 10))
                                .foregroundColor(isSel ? .white.opacity(0.6) : .secondaryText)
                                .lineLimit(1)
                            Circle()
                                .fill(hasGames ? (isSel ? Color.white.opacity(0.6) : Color.appBlue) : Color.clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(minWidth: 44, idealWidth: 50)
                        .padding(.vertical, 10)
                        .background(isSel ? Color.darkText : Color.black.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(isSel ? 0 : 0.06), lineWidth: 0.5))
                        .shadow(color: isSel ? Color.darkText.opacity(0.15) : .clear, radius: 8, y: 2)
                        .scaleEffect(isSel ? 1.06 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Bookmaker Sheet
struct BookmakerSheet: View {
    let match: Match
    @Binding var isPresented: Bool
    @State private var appeared = false

    let bookmakers = [
        ("Winamax", "suit.spade.fill", Color(hex: "#E8000D"), ["home": "1.65", "away": "2.20", "draw": "3.40"]),
        ("Betclic",  "bolt.fill", Color(hex: "#FF6600"), ["home": "1.68", "away": "2.15", "draw": "3.35"]),
        ("PMU",      "hare.fill", Color(hex: "#006633"), ["home": "1.62", "away": "2.25", "draw": "3.50"]),
        ("Unibet",   "target", Color(hex: "#147B45"), ["home": "1.70", "away": "2.18", "draw": "3.30"]),
        ("BetFair",  "chart.bar.fill", Color(hex: "#C8A951"), ["home": "1.72", "away": "2.22", "draw": "3.45"]),
    ]

    var conf: Color { match.confidence.color }
    var pickAway: Bool { match.aiPickAbbr == match.away.abbr }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.odDivider).frame(width: 38, height: 5).padding(.top, 13).padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Place Your Bet")
                    .font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(.odTextPrimary)
                HStack(spacing: 8) {
                    TeamLogo(abbr: match.away.abbr, color: match.away.color, size: 22, sport: match.sport)
                    Text("\(match.away.abbr) vs \(match.home.abbr)")
                        .font(.system(size: 13)).foregroundColor(.appGray)
                    Spacer()
                    Text("AI: \(match.aiPick)")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(conf)
                        .padding(.horizontal, 11).padding(.vertical, 3)
                        .background(conf.opacity(0.15))
                        .overlay(Capsule().stroke(conf, lineWidth: 0.5))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.bottom, 16)

            Divider().background(Color.odDivider).padding(.horizontal, 20)

            HStack {
                Text("Bookmaker").frame(maxWidth: .infinity, alignment: .leading)
                Text(match.away.abbr).frame(maxWidth: .infinity, alignment: .center)
                Text("Draw").frame(maxWidth: .infinity, alignment: .center)
                Text(match.home.abbr).frame(maxWidth: .infinity, alignment: .center)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.odTextMuted)
            .textCase(.uppercase)
            .padding(.horizontal, 20).padding(.vertical, 8)

            ForEach(Array(bookmakers.enumerated()), id: \.offset) { i, b in
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(b.2).frame(width: 33, height: 33)
                                .shadow(color: b.2.opacity(0.5), radius: 4)
                            Image(systemName: b.1)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text(b.0).font(.system(size: 14, weight: .semibold)).foregroundColor(.odTextPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(["away", "draw", "home"], id: \.self) { side in
                        let isPick = (side == "away" && pickAway) || (side == "home" && !pickAway)
                        Text(b.3[side] ?? "N/A")
                            .font(.system(size: 15, weight: isPick ? .heavy : .medium, design: .rounded))
                            .foregroundColor(isPick ? conf : .white.opacity(0.6))
                            .padding(.horizontal, isPick ? 6 : 0).padding(.vertical, isPick ? 3 : 0)
                            .background(isPick ? conf.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 13)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.odDivider), alignment: .top)
                .offset(x: appeared ? 0 : CGFloat(40 + i * 12))
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.75).delay(Double(i) * 0.06), value: appeared)
            }

            Button { isPresented = false } label: {
                Text("Close")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.odTextPrimary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.odBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20).padding(.top, 18)
            Spacer(minLength: 44)
        }
        .background(Color.odSurface)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { appeared = true } }
    }
}

// MARK: - Detail Pager (Apple Sports Style)
struct GameDetailPager: View {
    let matches: [Match]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            Color.odBg.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(matches.enumerated()), id: \.element.id) { i, match in
                    DetailPage(match: match, isPresented: $isPresented)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            currentIndex = initialIndex
        }
        .onChange(of: currentIndex) { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Detail Page (Single Game — Apple Sports Style)
struct DetailPage: View {
    let match: Match
    @Binding var isPresented: Bool
    @State private var saved = false
    @State private var showBookmakers = false
    @State private var confCount = 0
    @State private var statsActive = false
    @State private var ctaPressed = false
    @State private var headerAppeared = false
    @State private var detailTab = "Stats"

    var conf: Color { match.confidence.color }
    var pickAway: Bool { match.aiPickAbbr == match.away.abbr }
    var pickedTeam: String { pickAway ? match.away.abbr : match.home.abbr }

    // MARK: Scoreboard Card (Oddlytics — gradient header + white card)
    private var scoreboardCard: some View {
        VStack(spacing: 0) {
            // Sport-specific gradient header
            ZStack {
                SportGradient.gradient(for: match.sport)

                VStack(spacing: 4) {
                    Text(match.league.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .kerning(0.5)

                    // Big scores row
                    HStack(alignment: .center, spacing: 0) {
                        Text(match.hasScore ? "\(match.away.score!)" : "–")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundColor(.odTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .scaleEffect(headerAppeared ? 1.0 : 0.85)
                            .opacity(headerAppeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: headerAppeared)

                        VStack(spacing: 2) {
                            if match.statusType == .live {
                                Image(systemName: match.sportIcon)
                                    .font(.system(size: 10))
                                    .foregroundColor(.odTextPrimary.opacity(0.5))
                                Text(match.status)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.odTextPrimary.opacity(0.8))
                            } else if match.statusType == .final_ {
                                Text("Final")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.odTextPrimary.opacity(0.5))
                            } else {
                                Text(match.status)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.odTextPrimary.opacity(0.5))
                            }
                        }
                        .frame(width: 80)

                        Text(match.hasScore ? "\(match.home.score!)" : "–")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .foregroundColor(.odTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(headerAppeared ? 1.0 : 0.85)
                            .opacity(headerAppeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: headerAppeared)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }

            // White card for team info (overlaps gradient)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 6) {
                        TeamLogo(abbr: match.away.abbr, color: match.away.color, size: 48, sport: match.sport)
                            .scaleEffect(headerAppeared ? 1.0 : 0.7)
                            .opacity(headerAppeared ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.12), value: headerAppeared)
                        Text(match.away.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.odTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if !match.away.record.isEmpty {
                            Text(match.away.record)
                                .font(.system(size: 12))
                                .foregroundColor(.odTextMuted)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Spacer().frame(width: 80)

                    VStack(spacing: 6) {
                        TeamLogo(abbr: match.home.abbr, color: match.home.color, size: 48, sport: match.sport)
                            .scaleEffect(headerAppeared ? 1.0 : 0.7)
                            .opacity(headerAppeared ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.18), value: headerAppeared)
                        Text(match.home.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.odTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if !match.home.record.isEmpty {
                            Text(match.home.record)
                                .font(.system(size: 12))
                                .foregroundColor(.odTextMuted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 18)
            }
            .background(Color.odSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: Section tab bar (Oddlytics)
    private var sectionTabBar: some View {
        HStack(spacing: 0) {
            ForEach(["Stats", "AI Signals", "Form"], id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { detailTab = tab }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.system(size: 15, weight: detailTab == tab ? .bold : .regular))
                            .foregroundColor(detailTab == tab ? .odTextPrimary : .odTextMuted)
                        Rectangle()
                            .fill(detailTab == tab ? Color.odPrimary : Color.clear)
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.2), value: detailTab)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundColor(Color.odDivider),
            alignment: .bottom
        )
    }

    // MARK: Apple-style Betting Odds table
    private var appleOddsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Betting Odds")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.odTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Header row
            HStack(spacing: 0) {
                Text("Team")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Moneyline")
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Total")
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("Spread")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.odTextMuted)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().background(Color.odDivider).padding(.horizontal, 16)

            // Away row
            appleOddsRow(
                abbr: match.away.abbr,
                color: match.away.color,
                ml: match.oddsAway,
                total: "O\(match.overUnder)",
                spread: match.spreadAway,
                isPick: pickAway
            )

            Divider().background(Color.odDivider).padding(.horizontal, 16)

            // Home row
            appleOddsRow(
                abbr: match.home.abbr,
                color: match.home.color,
                ml: match.oddsHome,
                total: "U\(match.overUnder)",
                spread: match.spreadHome,
                isPick: !pickAway
            )

            // Line move info
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12))
                    .foregroundColor(.odTextMuted)
                Text(match.lineMove.label)
                    .font(.system(size: 12))
                    .foregroundColor(.odTextMuted)
                Spacer()
                Text("\(match.lineMove.from) → \(match.lineMove.to)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.odTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func appleOddsRow(abbr: String, color: Color, ml: String, total: String, spread: String, isPick: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 4, height: 20)
                Text(abbr)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.odTextPrimary)
                if isPick {
                    Text("AI")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(conf)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(conf.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(ml)
                .font(.system(size: 15, weight: isPick ? .bold : .regular, design: .rounded))
                .foregroundColor(isPick ? conf : .white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(total)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.odTextMuted)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(spread)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.odTextMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Apple-style Team Stats
    private var appleStatsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Team Stats")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.odTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Column headers
            HStack {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(match.away.color).frame(width: 4, height: 14)
                    Text(match.away.abbr)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.odTextMuted)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(match.home.abbr)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.odTextMuted)
                    RoundedRectangle(cornerRadius: 4).fill(match.home.color).frame(width: 4, height: 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ForEach(match.statBars(), id: \.label) { s in
                appleStatRow(s)
            }

            Spacer().frame(height: 12)
        }
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func appleStatRow(_ s: StatBar) -> some View {
        let total = s.awayNum + s.homeNum
        let awayPct = total > 0 ? s.awayNum / total : 0.5
        let awayLeads = s.awayNum >= s.homeNum

        return VStack(spacing: 6) {
            HStack {
                Text(s.awayVal)
                    .font(.system(size: 17, weight: awayLeads ? .bold : .regular, design: .rounded))
                    .foregroundColor(awayLeads ? .odTextPrimary : .odTextMuted)
                Spacer()
                Text(s.label)
                    .font(.system(size: 13))
                    .foregroundColor(.odTextMuted)
                Spacer()
                Text(s.homeVal)
                    .font(.system(size: 17, weight: !awayLeads ? .bold : .regular, design: .rounded))
                    .foregroundColor(!awayLeads ? .odTextPrimary : .odTextMuted)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 99)
                        .fill(match.away.color)
                        .frame(width: statsActive ? geo.size.width * awayPct : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: statsActive)
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 99)
                        .fill(match.home.color)
                        .frame(width: statsActive ? geo.size.width * (1 - awayPct) : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: statsActive)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var aiSignalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("AI Signals")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.odTextPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ForEach(Array(match.signals().enumerated()), id: \.offset) { i, sig in
                HStack(spacing: 10) {
                    let dot: Color = sig.favor == "away" ? match.away.color : sig.favor == "home" ? match.home.color : .white.opacity(0.3)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(dot)
                        .frame(width: 4, height: 20)
                    Text(sig.label)
                        .font(.system(size: 14))
                        .foregroundColor(.odTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(sig.value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(sig.favor == "neutral" ? .odTextMuted : .odTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                if i < match.signals().count - 1 {
                    Divider().background(Color.odDivider).padding(.horizontal, 16)
                }
            }

            Spacer().frame(height: 10)
        }
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Scoreboard card
                    scoreboardCard

                    // AI Prediction strip
                    aiPredictionCard

                    // Section tab bar
                    sectionTabBar

                    // Tab content
                    switch detailTab {
                    case "Stats":
                        VStack(spacing: 12) {
                            appleOddsSection
                            appleStatsSection
                        }
                    case "AI Signals":
                        aiSignalsSection
                            .padding(.horizontal, 2)
                    case "Form":
                        VStack(spacing: 12) {
                            recentFormCard
                            h2hCard
                        }
                    default:
                        EmptyView()
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            .background(Color.odBg)

            // STICKY CTA (Oddlytics pink)
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.odBg.opacity(0), Color.odBg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 28)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showBookmakers = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Lock \(match.aiPick)")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.odTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.odPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.odPrimary.opacity(0.4), radius: 12, y: 4)
                    .scaleEffect(ctaPressed ? 0.97 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16).padding(.bottom, 20)
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { ctaPressed = true } }
                    .onEnded { _ in withAnimation(.easeInOut(duration: 0.15)) { ctaPressed = false } }
                )
            }
            .background(Color.odBg)
        }
        .sheet(isPresented: $showBookmakers) {
            BookmakerSheet(match: match, isPresented: $showBookmakers)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation { headerAppeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                statsActive = true
                withAnimation(.easeOut(duration: 0.8)) {
                    confCount = match.confPct
                }
            }
        }
    }

    // MARK: AI Prediction compact card
    private var aiPredictionCard: some View {
        let homeNum = Int(match.oddsHome.replacingOccurrences(of: "+", with: "")) ?? 0
        let implH = homeNum < 0 ? Int(Double(abs(homeNum)) / Double(abs(homeNum) + 100) * 100) : Int(100.0 / Double(homeNum + 100) * 100)
        let pickedImpl = pickAway ? (100 - implH) : implH
        let edge = (pickAway ? match.awayPct : match.homePct) - pickedImpl

        return HStack(spacing: 12) {
            // Brain icon ring
            ZStack {
                Circle()
                    .stroke(conf.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(confCount) / 100.0)
                    .stroke(conf, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(conf)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text("AI Pick: \(match.aiPick)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.odTextPrimary)
                Text("\(match.confPct)% confidence · \(match.aiAccuracy)% accuracy")
                    .font(.system(size: 12))
                    .foregroundColor(.odTextMuted)
            }

            Spacer()

            if edge > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                    Text("+\(edge)%")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.appGreen)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.appGreen.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: Recent Form card
    private var recentFormCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recent Form")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.odTextPrimary)
                Spacer()
                Text("LAST 5")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            ForEach([(match.away, match.formAway), (match.home, match.formHome)], id: \.0.abbr) { team, form in
                HStack {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(team.color)
                            .frame(width: 4, height: 20)
                        Text(team.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.odTextSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    FormBubblesView(results: form)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Spacer().frame(height: 8)
        }
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: H2H card
    private var h2hCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Head to Head")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.odTextPrimary)
                Spacer()
                Text("LAST 10")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(match.h2h.awayWins)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.odTextMuted)
                    Text(match.away.abbr).font(.system(size: 12, weight: .medium)).foregroundColor(.odTextMuted)
                }
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 99).fill(match.away.color)
                                .frame(width: geo.size.width * CGFloat(match.h2h.awayWins) / 10)
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 99).fill(match.home.color)
                                .frame(width: geo.size.width * CGFloat(match.h2h.homeWins) / 10)
                        }
                    }
                    .frame(height: 6)
                    Text(match.h2h.note)
                        .font(.system(size: 12))
                        .foregroundColor(.odTextMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text("\(match.h2h.homeWins)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.odTextPrimary)
                    Text(match.home.abbr).font(.system(size: 12, weight: .medium)).foregroundColor(.odTextMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}

// MARK: - Profile Menu (Oddlytics Light)
struct ProfileMenuView: View {
    @Binding var isPresented: Bool
    @Binding var selectedSport: String
    @Environment(AuthManager.self) private var authManager
    @State private var showLogoutConfirm = false

    var body: some View {
        ZStack {
            Color.odBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // DRAG INDICATOR
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.odTextMuted.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 20)

                    // PROFILE HEADER CARD
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#C6FF4D"), Color(hex: "#A8E63E")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Text("E")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#0A0A0F"))
                        }

                        VStack(spacing: 4) {
                            Text("Ethan")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.odTextPrimary)
                            Text("Member since Mar 2026")
                                .font(.system(size: 13))
                                .foregroundColor(.odTextMuted)
                        }

                        // Stats row
                        HStack(spacing: 0) {
                            profileStat(value: "47", label: "Picks")
                            profileStatDivider()
                            profileStat(value: "74%", label: "Accuracy")
                            profileStatDivider()
                            profileStat(value: "12", label: "Win Streak")
                        }
                        .padding(.vertical, 16)
                        .background(Color.odBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.odSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.black.opacity(0.06), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // SETTINGS SECTIONS
                    VStack(spacing: 12) {
                        // Account section
                        profileSection(title: "Account") {
                            profileRow(icon: "person.fill", label: "Edit Profile")
                            profileDivider()
                            profileRow(icon: "bell.fill", label: "Notifications")
                            profileDivider()
                            profileRow(icon: "star.fill", label: "My Teams")
                        }

                        // Preferences section
                        profileSection(title: "Preferences") {
                            profileRow(icon: "sportscourt.fill", label: "Default Sport", trailing: "All")
                            profileDivider()
                            profileRow(icon: "chart.bar.fill", label: "Odds Format", trailing: "American")
                            profileDivider()
                            profileRow(icon: "clock.fill", label: "Timezone", trailing: "Auto")
                        }

                        // Support section
                        profileSection(title: "Support") {
                            profileRow(icon: "questionmark.circle.fill", label: "Help Center")
                            profileDivider()
                            profileRow(icon: "envelope.fill", label: "Contact Us")
                            profileDivider()
                            profileRow(icon: "doc.text.fill", label: "Terms & Privacy")
                        }

                        // Logout button
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showLogoutConfirm = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Log Out")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.appRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.odSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.04), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)

                        // App version
                        Text("Oddlytics v1.0.0")
                            .font(.system(size: 12))
                            .foregroundColor(.odTextMuted)
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                    }
                    .padding(.top, 24)
                }
            }
        }
        .alert("Log Out", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                Task { await authManager.signOut() }
            }
        } message: {
            Text("Are you sure you want to log out? You'll see the onboarding screen again.")
        }
    }

    // MARK: - Profile Components

    private func profileStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.odTextPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.odTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func profileStatDivider() -> some View {
        Rectangle()
            .fill(Color.odDivider)
            .frame(width: 0.5, height: 32)
    }

    @ViewBuilder
    private func profileSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.odTextMuted)
                .kerning(0.8)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.odSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.04), lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    private func profileRow(icon: String, label: String, trailing: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.odPrimary)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.odTextPrimary)
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 14))
                    .foregroundColor(.odTextMuted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.odTextMuted.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func profileDivider() -> some View {
        Rectangle()
            .fill(Color.odDivider)
            .frame(height: 0.5)
            .padding(.leading, 58)
    }
}

// MARK: - Favorites View

struct FavoritesView: View {
    @Binding var isPresented: Bool
    @State private var selectedDate = "Today"

    private let dateTabs = ["Today", "Yesterday", "Mar 11", "Mar 10", "Mar 9"]

    // Sample saved bets by date
    private let betsByDate: [String: [(match: Match, savedTime: String)]] = {
        var dict: [String: [(match: Match, savedTime: String)]] = [:]
        dict["Today"] = sampleMatches.prefix(3).map { (match: $0, savedTime: "\(Int.random(in: 1...8))h ago") }
        dict["Yesterday"] = Array(sampleMatches.dropFirst(3).prefix(2)).map { (match: $0, savedTime: "Yesterday") }
        dict["Mar 11"] = Array(sampleMatches.dropFirst(5).prefix(1)).map { (match: $0, savedTime: "2 days ago") }
        dict["Mar 10"] = Array(sampleMatches.dropFirst(1).prefix(2)).map { (match: $0, savedTime: "3 days ago") }
        dict["Mar 9"] = []
        return dict
    }()

    private var currentBets: [(match: Match, savedTime: String)] {
        betsByDate[selectedDate] ?? []
    }

    var body: some View {
        ZStack {
            Color.odBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Bets")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.odTextPrimary)
                            .tracking(-1)
                        Text("\(currentBets.count) saved pick\(currentBets.count != 1 ? "s" : "")")
                            .font(.system(size: 13))
                            .foregroundColor(.odTextMuted)
                    }
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.odTextMuted)
                            .frame(width: 30, height: 30)
                            .background(Color.odBgAlt)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // Date tabs
                HStack(spacing: 0) {
                    ForEach(dateTabs, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedDate = tab }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 8) {
                                Text(tab)
                                    .font(.system(size: 13, weight: selectedDate == tab ? .bold : .regular))
                                    .foregroundColor(selectedDate == tab ? .odTextPrimary : .odTextMuted)
                                Rectangle()
                                    .fill(selectedDate == tab ? Color.odPrimary : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.odDivider), alignment: .bottom)

                // Bets for selected date
                if currentBets.isEmpty {
                    VStack(spacing: 14) {
                        Spacer()
                        Text("⭐")
                            .font(.system(size: 44))
                        Text("No saved picks")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.odTextPrimary)
                        Text("Tap the star on any prediction to save it here")
                            .font(.system(size: 14))
                            .foregroundColor(.odTextMuted)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(currentBets, id: \.match.id) { bet in
                                favoriteBetCard(bet: bet)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    private func favoriteBetCard(bet: (match: Match, savedTime: String)) -> some View {
        let m = bet.match
        let dynColor = m.confColor

        return VStack(spacing: 0) {
            // Top: sport badge + time saved
            HStack {
                Text(m.sport.uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(hex: "#0A0A0F"))
                    .kerning(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.odBadgeDark)
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(bet.savedTime)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.odTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Teams row
            HStack(spacing: 0) {
                // Away
                HStack(spacing: 8) {
                    TeamLogo(abbr: m.away.abbr, color: m.away.color, size: 30, sport: m.sport)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.away.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.odTextPrimary)
                        Text(m.away.record)
                            .font(.system(size: 10))
                            .foregroundColor(.odTextMuted)
                    }
                }

                Spacer()

                // Status
                VStack(spacing: 2) {
                    Text(m.status)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(m.statusType == .live ? .odPrimary : .odTextMuted)
                    if let as_ = m.away.score, let hs = m.home.score {
                        Text("\(as_) - \(hs)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.odTextPrimary)
                    }
                }

                Spacer()

                // Home
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(m.home.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.odTextPrimary)
                        Text(m.home.record)
                            .font(.system(size: 10))
                            .foregroundColor(.odTextMuted)
                    }

                    TeamLogo(abbr: m.home.abbr, color: m.home.color, size: 30, sport: m.sport)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Divider
            Rectangle().fill(Color.odDivider).frame(height: 0.5)
                .padding(.horizontal, 16)

            // Pick + confidence
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Pick")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.odTextMuted)
                    Text(m.aiPick)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.odTextPrimary)
                }

                Spacer()

                // Confidence pill
                HStack(spacing: 4) {
                    Circle().fill(dynColor).frame(width: 6, height: 6)
                    Text("\(m.confPct)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(dynColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(dynColor.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Odds row
            HStack(spacing: 16) {
                oddsChip(label: "Spread", value: m.spreadAway)
                oddsChip(label: "ML", value: m.oddsAway)
                oddsChip(label: "O/U", value: m.overUnder)
                Spacer()
                // Remove button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.odPrimary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Color.odSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private func oddsChip(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.odTextMuted)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.odTextPrimary)
        }
    }
}

// MARK: - Scroll Offset PreferenceKey

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Previews

#Preview("MatchStatus - Status Pills") {
    VStack(spacing: 20) {
        StatusPillView(match: sampleMatches[0])
        StatusPillView(match: sampleMatches[2])
        StatusPillView(match: sampleMatches[4])
    }
    .padding()
    .background(Color.odBg)
    .preferredColorScheme(.dark)
}

#Preview("MatchStatus - Detail Pager") {
    GameDetailPager(matches: sampleMatches, initialIndex: 0, isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
