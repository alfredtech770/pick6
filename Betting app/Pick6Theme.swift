// Pick6Theme.swift
// Design tokens, shared types, and data models for the Pick6 onboarding flow.

import SwiftUI

// MARK: - Colors

extension Color {
    static let p6Ink        = Color(hex: "#151517")
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

// MARK: - Typography

extension Font {
    static func barlow(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .custom("BarlowCondensed-Black", size: size)
            .weight(weight)
    }
    static func barlowBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Bold", size: size)
    }
    static func barlowSemiBold(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-SemiBold", size: size)
    }
}

// MARK: - Gradients

extension LinearGradient {
    static let pick6Brand = LinearGradient(
        colors: [.p6RedDeep, .p6Red, .p6Orange],
        startPoint: .leading, endPoint: .trailing
    )
    static let redDeep = LinearGradient(
        colors: [Color(hex: "#7f0000"), .p6RedDeep, .p6Red],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let greenDeep = LinearGradient(
        colors: [.p6GreenDeep, .p6GreenMid, .p6Green],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let issueCard = LinearGradient(
        colors: [Color(hex: "#1e0505"), Color(hex: "#2d0808")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let solveCard = LinearGradient(
        colors: [Color(hex: "#041a06"), Color(hex: "#072610")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Shared view modifiers

struct P6PrimaryButton: ViewModifier {
    let isDisabled: Bool
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(isDisabled ? Color.white.opacity(0.1) : nil)
            .foregroundColor(isDisabled ? Color.white.opacity(0.3) : .white)
            .font(.barlow(15))
            .kerning(2.5)
            .textCase(.uppercase)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Data Models

struct QuizQuestion: Identifiable {
    let id: String
    let question: String
    let subtitle: String
    let accentColor: Color
    let options: [QuizOption]
}

struct QuizOption: Identifiable {
    let id: String
    let label: String
    let subtitle: String
}

struct BettorProfile {
    let name: String
    let short: String
    let emoji: String
    let accentColor: Color
    let tag: String
    let summary: String
    let stats: [ProfileStat]
    let pain: String
    let painDetail: String
    let painQuote: String
}

struct ProfileStat {
    let number: String
    let label: String
}

struct SportItem: Identifiable {
    let id: String
    let label: String
    let icon: String
    let color: Color
    let gradientColors: [Color]
}

// MARK: - Data

enum Pick6Data {

    static let questions: [QuizQuestion] = [
        .init(id: "freq", question: "How often do you bet?", subtitle: "Be honest — we won't judge",
              accentColor: .p6RedDeep, options: [
                .init(id: "never",  label: "Never yet",    subtitle: "Just exploring"),
                .init(id: "rarely", label: "Occasionally", subtitle: "A few times a year"),
                .init(id: "weekly", label: "Every week",   subtitle: "A regular habit"),
                .init(id: "daily",  label: "Almost daily", subtitle: "Part of my routine"),
              ]),
        .init(id: "spend", question: "How much per week?", subtitle: "Average across all bets",
              accentColor: .p6Orange, options: [
                .init(id: "zero", label: "Nothing yet",  subtitle: "Haven't started"),
                .init(id: "low",  label: "Under $20",    subtitle: "Just small stakes"),
                .init(id: "mid",  label: "$20 – $100",   subtitle: "Regular amounts"),
                .init(id: "high", label: "$100+",        subtitle: "Serious stakes"),
              ]),
        .init(id: "pain", question: "Biggest frustration?", subtitle: "The one that hurts most",
              accentColor: .p6Red, options: [
                .init(id: "picks",    label: "Can't pick winners",   subtitle: "Gut feeling keeps failing"),
                .init(id: "overload", label: "Too much information", subtitle: "Don't know what to trust"),
                .init(id: "bankroll", label: "Losing control",       subtitle: "Spend more than I should"),
                .init(id: "noedge",   label: "No real edge",         subtitle: "Bookies always win"),
              ]),
        .init(id: "method", question: "How do you pick bets?", subtitle: "Your honest method",
              accentColor: .p6Navy, options: [
                .init(id: "gut",   label: "Pure gut feeling", subtitle: "Instinct and vibes"),
                .init(id: "stats", label: "I research stats", subtitle: "Form, odds, numbers"),
                .init(id: "tips",  label: "Tips from others", subtitle: "Groups and tipsters"),
                .init(id: "nosys", label: "No real system",   subtitle: "Wing it every time"),
              ]),
        .init(id: "result", question: "How are your results?", subtitle: "Over the last 6 months",
              accentColor: .p6SoccerGn, options: [
                .init(id: "alwaysloss", label: "Always losing",     subtitle: "Nothing ever works"),
                .init(id: "mostlyloss", label: "Mostly losing",     subtitle: "Occasional wins, still down"),
                .init(id: "breakeven",  label: "About break-even",  subtitle: "Not up, not down"),
                .init(id: "winning",    label: "I'm actually up",   subtitle: "More wins than losses"),
              ]),
        .init(id: "goal", question: "What's your real goal?", subtitle: "What success looks like for you",
              accentColor: .p6Purple, options: [
                .init(id: "fun",     label: "Make it more fun",       subtitle: "Enjoy sports more"),
                .init(id: "profit",  label: "Generate real profit",   subtitle: "Make money consistently"),
                .init(id: "smarter", label: "Bet smarter",            subtitle: "Stop wasting money"),
                .init(id: "edge",    label: "Get an AI edge",         subtitle: "Data over guesses"),
              ]),
    ]

    static let profiles: [String: BettorProfile] = [
        "gutpunter": .init(
            name: "THE GUT\nPUNTER", short: "Gut Punter", emoji: "\u{1F3B2}",
            accentColor: .p6Red,
            tag: "You're betting on feel",
            summary: "You bet on instinct. Sometimes it works — but bookmakers have spent decades engineering their odds specifically to beat gut decisions.",
            stats: [.init(number: "97%",  label: "of gut bettors\nlose long-term"),
                    .init(number: "3.2\u{00D7}", label: "more likely to\nchase losses"),
                    .init(number: "$1,400", label: "average\nannual loss")],
            pain: "Your instincts are working against you",
            painDetail: "Every time you bet on instinct, you're playing a game that's been mathematically rigged against you. Bookmakers use vast pricing models to exploit exactly the kind of pattern-seeking, emotional decision-making that feels like intuition.",
            painQuote: "You can't out-feel a machine. But you can use one."
        ),
        "databoy": .init(
            name: "THE DATA\nSEEKER", short: "Data Seeker", emoji: "\u{1F4CA}",
            accentColor: .p6Navy,
            tag: "You're drowning in data",
            summary: "You try to research before betting — but it takes hours and you're still not confident. More data isn't solving the problem.",
            stats: [.init(number: "4.5h",  label: "wasted researching\nper week"),
                    .init(number: "71%",   label: "still lose despite\nresearch"),
                    .init(number: "$890",  label: "average\nannual loss")],
            pain: "The problem isn't the data",
            painDetail: "A single match has 200+ meaningful variables. Human working memory holds about 7 things at once. No matter how much you read, you're always operating with an incomplete picture — which creates false confidence, not real edge.",
            painQuote: "Research without a model is just noise with extra steps."
        ),
        "tipster": .init(
            name: "THE\nFOLLOWER", short: "The Follower", emoji: "\u{1F4F1}",
            accentColor: .p6SoccerGn,
            tag: "You're trusting the wrong people",
            summary: "You follow tipsters and groups — but most of them earn money from the bookmakers they're sending you to, not from your winnings.",
            stats: [.init(number: "89%",   label: "of tipsters don't\nbeat the market"),
                    .init(number: "62%",   label: "of tips are already\npriced in"),
                    .init(number: "$1,100", label: "average\nannual loss")],
            pain: "Free tips have a hidden cost",
            painDetail: "Most tipster groups run on bookmaker affiliate commissions. Their income comes from keeping you betting — not from keeping you winning. By the time a tip circulates in a group, the market has already adjusted for it.",
            painQuote: "If the tip were actually good, it wouldn't be free."
        ),
        "sharpwanna": .init(
            name: "ASPIRING\nSHARP", short: "Aspiring Sharp", emoji: "\u{26A1}",
            accentColor: .p6Red,
            tag: "You know the game — but not the edge",
            summary: "You understand sports better than most casual bettors. But consistently beating the market requires systematic analysis that's impossible to do by hand.",
            stats: [.init(number: "<1%",  label: "of bettors consistently\nbeat the market"),
                    .init(number: "3\u{2013}5%", label: "is the typical\nsharp's edge"),
                    .init(number: "$1,400", label: "average\nannual loss")],
            pain: "Knowledge alone isn't enough",
            painDetail: "The sharpest bettors operate on 3\u{2013}5% edges, found by processing thousands of variables per match, back-testing across years of data, and adjusting for real-time line movement. There is no human-speed way to do that.",
            painQuote: "Sharp bettors don't bet more — they bet smarter."
        ),
    ]

    static let sports: [SportItem] = [
        .init(id: "soccer",  label: "SOCCER",  icon: "\u{26BD}", color: .p6SoccerGn,  gradientColors: [Color(hex:"#0d3d22"), Color(hex:"#1a6b3a")]),
        .init(id: "nba",     label: "NBA",     icon: "\u{1F3C0}", color: .p6RedDeep,   gradientColors: [Color(hex:"#6b0415"), Color(hex:"#C9082A")]),
        .init(id: "nfl",     label: "NFL",     icon: "\u{1F3C8}", color: Color(hex:"#013369"), gradientColors: [Color(hex:"#011830"), Color(hex:"#013369")]),
        .init(id: "f1",      label: "F1",      icon: "\u{1F3CE}", color: .p6Red,       gradientColors: [Color(hex:"#6b0010"), Color(hex:"#E8002D")]),
        .init(id: "nhl",     label: "NHL",     icon: "\u{1F3D2}", color: .p6Navy,      gradientColors: [Color(hex:"#001550"), Color(hex:"#0033A0")]),
        .init(id: "cricket", label: "CRICKET", icon: "\u{1F3CF}", color: Color(hex:"#1C4F2A"), gradientColors: [Color(hex:"#0d2714"), Color(hex:"#1C4F2A")]),
    ]

    static func profile(for answers: [String: String]) -> BettorProfile {
        let method = answers["method"] ?? ""
        let key: String
        switch method {
        case "gut", "nosys": key = "gutpunter"
        case "stats":        key = "databoy"
        case "tips":         key = "tipster"
        default:             key = "sharpwanna"
        }
        return profiles[key]!
    }
}
