//
//  HomeView.swift
//  Betting app
//
//  Premier League homepage with match cards and AI analysis.
//

import SwiftUI

// MARK: - Brand Constants
struct Brand {
    // Colors
    static let black         = Color(hex: "#0A0A0A")
    static let white         = Color(hex: "#FFFFFF")
    static let cardPink     = Color(hex: "#F4A7C0")
    static let cardBlue      = Color(hex: "#5BB5E8")
    static let cardMint      = Color(hex: "#7DDAB4")
    static let cardGold      = Color(hex: "#E8C84A")
    static let plPurple      = Color(hex: "#3D195B")
    static let textGray      = Color(hex: "#999999")
    static let lightGray     = Color(hex: "#C8C8C8")

    // Typography — Barlow Condensed throughout
    static func display(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .custom("BarlowCondensed-Black", size: size)
    }
    static func heading(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Bold", size: size)
    }
    static func label(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-SemiBold", size: size)
    }
    static func caption(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Medium", size: size)
    }
}

// MARK: - Models (PL prefix to avoid conflict with MatchStatus)
struct PLMatch: Identifiable {
    let id: Int
    let date: String
    let month: String
    let time: (String, String)
    let cardBg: Color
    let darkAccent: Color
    let home: PLTeam
    let away: PLTeam
    let homePct: Int
    let drawPct: Int
    let awayPct: Int
    let homeForm: [Bool]
    let awayForm: [Bool]
    let aiPick: String
    let aiConf: Int
    let aiReason: String
    let lineup: PLLineupData
    let h2h: [PLH2HResult]
}

struct PLTeam {
    let name: String
    let sub: String
    let abbr: String
    let color: Color
    let kitColor: Color
    let form: [String]
    let goalsPerGame: Double
}

struct PLPlayer {
    let name: String
    let number: Int
}

struct PLLineupData {
    let home: [PLPlayer]
    let away: [PLPlayer]
}

struct PLH2HResult {
    let date: String
    let score: String
    let winner: String // "home" | "away" | "draw"
}

// MARK: - Sample Data
let plSampleMatches: [PLMatch] = [
    PLMatch(
        id: 1, date: "08", month: "SEPTEMBER", time: ("09", "30"),
        cardBg: Color(hex: "#F4A7C0"), darkAccent: Color(hex: "#C9547A"),
        home: PLTeam(name: "MANCHESTER", sub: "UNITED", abbr: "MU",
                   color: Color(hex: "#DA291C"), kitColor: .white,
                   form: ["W","W","L","W","W"], goalsPerGame: 2.1),
        away: PLTeam(name: "F.C.", sub: "CHELSEA", abbr: "CH",
                   color: Color(hex: "#034694"), kitColor: .white,
                   form: ["W","D","W","L","W"], goalsPerGame: 1.8),
        homePct: 31, drawPct: 22, awayPct: 47,
        homeForm: [true,true,true,true], awayForm: [true,false,true,false],
        aiPick: "CHELSEA", aiConf: 74,
        aiReason: "Chelsea's recent xG superiority and Man Utd's defensive injuries give the away side a clear edge this matchday.",
        lineup: PLLineupData(
            home: [PLPlayer(name:"Onana",number:24),PLPlayer(name:"Dalot",number:20),PLPlayer(name:"Maguire",number:5),PLPlayer(name:"Varane",number:19),PLPlayer(name:"Shaw",number:23),PLPlayer(name:"Casemiro",number:18),PLPlayer(name:"Fernandes",number:8),PLPlayer(name:"Mount",number:7),PLPlayer(name:"Rashford",number:10),PLPlayer(name:"Martial",number:9),PLPlayer(name:"Højlund",number:11)],
            away: [PLPlayer(name:"Sánchez",number:1),PLPlayer(name:"James",number:24),PLPlayer(name:"Silva",number:6),PLPlayer(name:"Disasi",number:20),PLPlayer(name:"Chilwell",number:21),PLPlayer(name:"Caicedo",number:25),PLPlayer(name:"Gallagher",number:23),PLPlayer(name:"Palmer",number:20),PLPlayer(name:"Sterling",number:17),PLPlayer(name:"Mudryk",number:15),PLPlayer(name:"Jackson",number:14)]
        ),
        h2h: [PLH2HResult(date:"Mar 24",score:"1–2",winner:"away"),PLH2HResult(date:"Oct 23",score:"0–1",winner:"away"),PLH2HResult(date:"May 23",score:"2–1",winner:"home")]
    ),
    PLMatch(
        id: 2, date: "12", month: "SEPTEMBER", time: ("12", "00"),
        cardBg: Color(hex: "#5BB5E8"), darkAccent: Color(hex: "#1A7FC0"),
        home: PLTeam(name: "CRYSTAL", sub: "PALACE", abbr: "CP",
                   color: Color(hex: "#1B458F"), kitColor: .white,
                   form: ["W","L","W","W","D"], goalsPerGame: 1.4),
        away: PLTeam(name: "LEICESTER", sub: "CITY", abbr: "LC",
                   color: Color(hex: "#003090"), kitColor: .white,
                   form: ["L","D","L","W","L"], goalsPerGame: 0.9),
        homePct: 38, drawPct: 25, awayPct: 37,
        homeForm: [true,false,true,true], awayForm: [false,true,true,false],
        aiPick: "CRYSTAL PALACE", aiConf: 68,
        aiReason: "Palace's home record is strong and Leicester are struggling with key absences in midfield.",
        lineup: PLLineupData(
            home: [PLPlayer(name:"Henderson",number:1),PLPlayer(name:"Ward",number:2),PLPlayer(name:"Andersen",number:5),PLPlayer(name:"Guehi",number:6),PLPlayer(name:"Mitchell",number:3),PLPlayer(name:"Doucoure",number:8),PLPlayer(name:"Hughes",number:14),PLPlayer(name:"Eze",number:10),PLPlayer(name:"Olise",number:7),PLPlayer(name:"Ayew",number:11),PLPlayer(name:"Mateta",number:14)],
            away: [PLPlayer(name:"Ward",number:1),PLPlayer(name:"Castagne",number:27),PLPlayer(name:"Faes",number:5),PLPlayer(name:"Vestergaard",number:6),PLPlayer(name:"Justin",number:2),PLPlayer(name:"Soumare",number:42),PLPlayer(name:"Ndidi",number:25),PLPlayer(name:"Tete",number:7),PLPlayer(name:"Daka",number:20),PLPlayer(name:"Vardy",number:9),PLPlayer(name:"Iheanacho",number:14)]
        ),
        h2h: [PLH2HResult(date:"Feb 24",score:"2–0",winner:"home"),PLH2HResult(date:"Sep 23",score:"1–1",winner:"draw"),PLH2HResult(date:"Mar 23",score:"2–2",winner:"draw")]
    ),
    PLMatch(
        id: 3, date: "14", month: "SEPTEMBER", time: ("13", "00"),
        cardBg: Color(hex: "#7DDAB4"), darkAccent: Color(hex: "#2CAA78"),
        home: PLTeam(name: "AFC", sub: "BOURNEMOUTH", abbr: "AB",
                   color: Color(hex: "#DA291C"), kitColor: .white,
                   form: ["W","W","D","W","L"], goalsPerGame: 1.7),
        away: PLTeam(name: "VILLA SAN", sub: "CARLOS", abbr: "VS",
                   color: Color(hex: "#6B21A8"), kitColor: .white,
                   form: ["L","W","L","D","W"], goalsPerGame: 1.3),
        homePct: 42, drawPct: 30, awayPct: 28,
        homeForm: [true,true,false,true], awayForm: [false,true,false,false],
        aiPick: "BOURNEMOUTH", aiConf: 65,
        aiReason: "Bournemouth are in excellent home form with a high press that disrupts Villa San's build-up play.",
        lineup: PLLineupData(
            home: [PLPlayer(name:"Flekken",number:1),PLPlayer(name:"Smith",number:2),PLPlayer(name:"Mepham",number:5),PLPlayer(name:"Senesi",number:15),PLPlayer(name:"Zemura",number:33),PLPlayer(name:"Cook",number:4),PLPlayer(name:"Christie",number:11),PLPlayer(name:"Billing",number:29),PLPlayer(name:"Semenyo",number:22),PLPlayer(name:"Solanke",number:9),PLPlayer(name:"Kluivert",number:19)],
            away: [PLPlayer(name:"Martínez",number:1),PLPlayer(name:"Cash",number:2),PLPlayer(name:"Carlos",number:3),PLPlayer(name:"Torres",number:6),PLPlayer(name:"Digne",number:12),PLPlayer(name:"Luiz",number:6),PLPlayer(name:"Kamara",number:8),PLPlayer(name:"McGinn",number:7),PLPlayer(name:"Bailey",number:31),PLPlayer(name:"Watkins",number:11),PLPlayer(name:"Diaby",number:19)]
        ),
        h2h: [PLH2HResult(date:"Jan 24",score:"0–1",winner:"away"),PLH2HResult(date:"Aug 23",score:"3–2",winner:"home"),PLH2HResult(date:"Apr 23",score:"1–1",winner:"draw")]
    ),
    PLMatch(
        id: 4, date: "15", month: "SEPTEMBER", time: ("14", "00"),
        cardBg: Color(hex: "#E8C84A"), darkAccent: Color(hex: "#B89A10"),
        home: PLTeam(name: "JUVENTUS", sub: "F.C", abbr: "JV",
                   color: .black, kitColor: .white,
                   form: ["W","W","W","D","W"], goalsPerGame: 2.3),
        away: PLTeam(name: "STOKE", sub: "CITY", abbr: "SK",
                   color: Color(hex: "#E03A3E"), kitColor: .white,
                   form: ["L","L","D","L","W"], goalsPerGame: 0.8),
        homePct: 55, drawPct: 24, awayPct: 21,
        homeForm: [true,true,true,false], awayForm: [false,false,true,false],
        aiPick: "JUVENTUS", aiConf: 81,
        aiReason: "Juventus dominate at home and Stoke's away form this season has been dire — just 1 point from 5 road games.",
        lineup: PLLineupData(
            home: [PLPlayer(name:"Szczesny",number:1),PLPlayer(name:"Danilo",number:13),PLPlayer(name:"Bremer",number:3),PLPlayer(name:"Gatti",number:15),PLPlayer(name:"Cambiaso",number:27),PLPlayer(name:"Locatelli",number:5),PLPlayer(name:"Rabiot",number:25),PLPlayer(name:"Kostic",number:11),PLPlayer(name:"Vlahovic",number:9),PLPlayer(name:"Chiesa",number:7),PLPlayer(name:"Yildiz",number:10)],
            away: [PLPlayer(name:"Bonham",number:1),PLPlayer(name:"Wilmot",number:2),PLPlayer(name:"O'Brien",number:5),PLPlayer(name:"Vrančić",number:8),PLPlayer(name:"Tymon",number:3),PLPlayer(name:"Baker",number:14),PLPlayer(name:"Laurent",number:7),PLPlayer(name:"Thompson",number:18),PLPlayer(name:"Gayle",number:9),PLPlayer(name:"Maja",number:11),PLPlayer(name:"Sawyers",number:8)]
        ),
        h2h: [PLH2HResult(date:"Dec 23",score:"2–0",winner:"home"),PLH2HResult(date:"May 23",score:"3–1",winner:"home"),PLH2HResult(date:"Nov 22",score:"1–0",winner:"home")]
    )
]

// MARK: - Team Badge
struct PLTeamBadge: View {
    let team: PLTeam
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle()
                .fill(team.color)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.88), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
            Text(team.abbr)
                .font(.custom("BarlowCondensed-Black", size: size * 0.3))
                .foregroundColor(team.kitColor)
        }
    }
}

// MARK: - PL Logo
struct PLLogo: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            Circle().fill(Brand.plPurple).frame(width: size, height: size)
            Text("PL")
                .font(.custom("BarlowCondensed-Black", size: size * 0.36))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Stacked Match Card
struct PLStackedMatchCard: View {
    let match: PLMatch
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: matchup info
            VStack(alignment: .leading, spacing: 8) {
                // Date + time pill
                HStack(spacing: 6) {
                    Text("\(match.date) \(match.month.prefix(3))")
                        .font(.custom("BarlowCondensed-Bold", size: 11))
                        .foregroundColor(Brand.black.opacity(0.5))
                        .kerning(0.8)
                    Text("·")
                        .font(.custom("BarlowCondensed-Bold", size: 11))
                        .foregroundColor(Brand.black.opacity(0.3))
                    Text("\(match.time.0):\(match.time.1)")
                        .font(.custom("BarlowCondensed-Bold", size: 11))
                        .foregroundColor(Brand.black.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.08))
                .clipShape(Capsule())

                // Teams row
                HStack(spacing: 10) {
                    PLTeamBadge(team: match.home, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(match.home.name) \(match.home.sub)")
                            .font(.custom("BarlowCondensed-Black", size: 19))
                            .foregroundColor(Brand.black)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("vs")
                                .font(.custom("BarlowCondensed-Bold", size: 12))
                                .foregroundColor(Brand.black.opacity(0.4))
                            PLTeamBadge(team: match.away, size: 16)
                            Text("\(match.away.name) \(match.away.sub)")
                                .font(.custom("BarlowCondensed-SemiBold", size: 12))
                                .foregroundColor(Brand.black.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            // Right: AI confidence
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(match.aiConf)%")
                        .font(.custom("BarlowCondensed-Black", size: 34))
                        .foregroundColor(Brand.black)
                    Text("AI CONF")
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .foregroundColor(Brand.black.opacity(0.45))
                        .kerning(1.5)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Brand.black.opacity(0.35))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(match.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: pressed)
        .onTapGesture { onTap() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}


// MARK: - List View
struct PLMatchListView: View {
    let onSelect: (PLMatch) -> Void
    @State private var cardsVisible = false

    var body: some View {
        VStack(spacing: 0) {
            // Nav
            HStack {
                PLLogo(size: 30)
                Spacer()
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 4).fill(Brand.black).frame(width: 26, height: 7)
                    RoundedRectangle(cornerRadius: 4).fill(Brand.lightGray).frame(width: 7, height: 7)
                    RoundedRectangle(cornerRadius: 4).fill(Brand.lightGray).frame(width: 7, height: 7)
                }
                Spacer()
                Circle()
                    .stroke(Brand.lightGray, lineWidth: 1.5)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Brand.black.opacity(0.7))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Title
            VStack(alignment: .leading, spacing: 0) {
                Text("PREMIER")
                    .font(.custom("BarlowCondensed-Black", size: 82))
                    .foregroundColor(Brand.black)
                    .kerning(-2.5)
                    .lineSpacing(-10)
                Text("LEAGUE")
                    .font(.custom("BarlowCondensed-Black", size: 82))
                    .foregroundColor(Brand.lightGray)
                    .kerning(-2.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 22)

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(plSampleMatches.enumerated()), id: \.element.id) { idx, match in
                        PLStackedMatchCard(match: match) {
                            onSelect(match)
                        }
                        .offset(y: cardsVisible ? 0 : CGFloat(60 + idx * 20))
                        .opacity(cardsVisible ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(Double(idx) * 0.09 + 0.05), value: cardsVisible)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .background(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                cardsVisible = true
            }
        }
    }
}

// MARK: - AI Analysis + Probability Bar
struct PLAIAnalysisView: View {
    let match: PLMatch
    @Binding var barAnimated: Bool
    @State private var countedConf: Int = 0
    @State private var countedHome: Int = 0
    @State private var countedDraw: Int = 0
    @State private var countedAway: Int = 0

    var dark: Color { Color.black.opacity(0.82) }
    var faint: Color { Color.black.opacity(0.16) }
    var mid: Color { Color.black.opacity(0.5) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // AI Header row
            HStack(alignment: .center, spacing: 10) {
                // Spark icon pill
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(dark).frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(match.cardBg)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI ANALYSIS")
                        .font(.custom("BarlowCondensed-Bold", size: 8))
                        .foregroundColor(mid)
                        .kerning(2)
                    Text("PICK: \(match.aiPick)")
                        .font(.custom("BarlowCondensed-Black", size: 18))
                        .foregroundColor(dark)
                }
                Spacer()
                // Confidence pill
                VStack(spacing: 0) {
                    Text("\(countedConf)%")
                        .font(.custom("BarlowCondensed-Black", size: 20))
                        .foregroundColor(match.cardBg)
                    Text("CONFIDENCE")
                        .font(.custom("BarlowCondensed-Bold", size: 7))
                        .foregroundColor(match.cardBg.opacity(0.7))
                        .kerning(1.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(dark)
                .clipShape(Capsule())
            }
            .padding(.bottom, 12)

            // Reasoning
            Text(match.aiReason)
                .font(.custom("BarlowCondensed-SemiBold", size: 13))
                .foregroundColor(dark)
                .lineSpacing(4)
                .padding(10)
                .background(Color.black.opacity(0.07))
                .cornerRadius(10)
                .padding(.bottom, 14)

            // Form dots
            VStack(alignment: .leading, spacing: 5) {
                PLFormDotsRow(label: "▶ \(match.home.abbr)", form: match.homeForm, dark: dark, faint: faint, indent: 0)
                PLFormDotsRow(label: match.away.abbr, form: match.awayForm, dark: dark, faint: faint, indent: 18)
            }
            .padding(.bottom, 10)

            // Three-zone bar
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Zone 1 — solid black (home)
                    Rectangle()
                        .fill(dark)
                        .frame(width: barAnimated ? geo.size.width * CGFloat(match.homePct) / 100 : 0, height: 18)
                        .cornerRadius(4, corners: [.topLeft, .bottomLeft])
                        .animation(.spring(response: 0.95, dampingFraction: 0.8).delay(0.05), value: barAnimated)

                    // Zone 2 — gray (draw)
                    Rectangle()
                        .fill(Color.black.opacity(0.28))
                        .frame(width: barAnimated ? geo.size.width * CGFloat(match.drawPct) / 100 : 0, height: 18)
                        .animation(.spring(response: 0.95, dampingFraction: 0.8).delay(0.08), value: barAnimated)

                    // Zone 3 — tick marks (away)
                    ZStack {
                        Rectangle().fill(Color.clear)
                        HStack(spacing: 0) {
                            ForEach(0..<20) { i in
                                Rectangle()
                                    .fill(Color.black.opacity(0.22))
                                    .frame(width: 1.5)
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 18)
                    .opacity(barAnimated ? 1 : 0)
                    .animation(.easeIn(duration: 0.3).delay(0.5), value: barAnimated)
                }
            }
            .frame(height: 18)
            .padding(.bottom, 12)

            // Percentage labels
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(countedHome)%")
                        .font(.custom("BarlowCondensed-Black", size: 28))
                        .foregroundColor(dark)
                    Text(match.home.abbr)
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .foregroundColor(mid)
                        .kerning(1.2)
                }
                Spacer()
                VStack(alignment: .center, spacing: 1) {
                    Text("\(countedDraw)%")
                        .font(.custom("BarlowCondensed-Black", size: 28))
                        .foregroundColor(dark)
                    Text("DRAW")
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .foregroundColor(mid)
                        .kerning(1.2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(countedAway)%")
                        .font(.custom("BarlowCondensed-Black", size: 28))
                        .foregroundColor(dark)
                    Text(match.away.abbr)
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .foregroundColor(mid)
                        .kerning(1.2)
                }
            }
        }
        .onAppear {
            if barAnimated {
                animateCounts()
            }
        }
        .onChange(of: barAnimated) { _, animated in
            if animated { animateCounts() }
        }
    }

    func animateCounts() {
        animateCount(to: match.aiConf,   duration: 1.2) { countedConf = $0 }
        animateCount(to: match.homePct,  duration: 1.0) { countedHome = $0 }
        animateCount(to: match.drawPct,  duration: 1.0) { countedDraw = $0 }
        animateCount(to: match.awayPct,  duration: 1.0) { countedAway = $0 }
    }

    func animateCount(to target: Int, duration: Double, update: @escaping (Int) -> Void) {
        let steps = 60
        let interval = duration / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                let progress = Double(i) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)
                update(Int(eased * Double(target)))
            }
        }
    }
}

struct PLFormDotsRow: View {
    let label: String
    let form: [Bool]
    let dark: Color
    let faint: Color
    var indent: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.custom("BarlowCondensed-ExtraBold", size: 9))
                .foregroundColor(dark)
                .frame(minWidth: 38, alignment: .leading)
                .kerning(0.6)
            HStack(spacing: 4) {
                ForEach(0..<form.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(form[i] ? dark : faint)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .padding(.leading, indent)
    }
}

// MARK: - Player Card
struct PLPlayerCardView: View {
    let player: PLPlayer
    let cardBg: Color
    let dark: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Big faded jersey number
            Text("\(player.number)")
                .font(.custom("BarlowCondensed-Black", size: 38))
                .foregroundColor(Color.black.opacity(0.18))
                .padding(.leading, 8)
                .padding(.bottom, 4)

            // Player silhouette
            PLPlayerSilhouette()
                .frame(width: 62, height: 80)
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(y: 0)

            // Name top left
            VStack(alignment: .leading, spacing: 1) {
                let parts = player.name.split(separator: " ")
                if parts.count > 1 {
                    Text(parts.first?.uppercased() ?? "")
                        .font(.custom("BarlowCondensed-Bold", size: 9))
                        .foregroundColor(Color.black.opacity(0.5))
                }
                Text((parts.last ?? Substring(player.name)).uppercased())
                    .font(.custom("BarlowCondensed-Black", size: 16))
                    .foregroundColor(Color.black.opacity(0.82))
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 90, height: 128)
        .background(Color.black.opacity(0.12))
        .cornerRadius(14)
    }
}

struct PLPlayerSilhouette: View {
    var body: some View {
        Canvas { context, size in
            let dark = Color.black.opacity(0.35)
            let cx = size.width / 2
            // Head
            context.fill(Path(ellipseIn: CGRect(x: cx - 7, y: 1, width: 14, height: 16)), with: .color(dark))
            // Body
            var body = Path()
            body.move(to: CGPoint(x: cx - 13, y: 28))
            body.addCurve(to: CGPoint(x: cx + 13, y: 28),
                          control1: CGPoint(x: cx - 13, y: 20),
                          control2: CGPoint(x: cx + 13, y: 20))
            body.addLine(to: CGPoint(x: cx + 15, y: 50))
            body.addLine(to: CGPoint(x: cx - 15, y: 50))
            body.closeSubpath()
            context.fill(body, with: .color(dark))
            // Left arm
            var la = Path()
            la.move(to: CGPoint(x: cx - 13, y: 30)); la.addLine(to: CGPoint(x: cx - 21, y: 44)); la.addLine(to: CGPoint(x: cx - 17, y: 46)); la.addLine(to: CGPoint(x: cx - 9, y: 33))
            la.closeSubpath(); context.fill(la, with: .color(Color.black.opacity(0.28)))
            // Right arm
            var ra = Path()
            ra.move(to: CGPoint(x: cx + 13, y: 30)); ra.addLine(to: CGPoint(x: cx + 22, y: 42)); ra.addLine(to: CGPoint(x: cx + 18, y: 45)); ra.addLine(to: CGPoint(x: cx + 9, y: 33))
            ra.closeSubpath(); context.fill(ra, with: .color(Color.black.opacity(0.28)))
            // Left leg
            var ll = Path()
            ll.move(to: CGPoint(x: cx - 12, y: 50)); ll.addLine(to: CGPoint(x: cx - 14, y: 66)); ll.addLine(to: CGPoint(x: cx - 17, y: 79)); ll.addLine(to: CGPoint(x: cx - 10, y: 79)); ll.addLine(to: CGPoint(x: cx - 8, y: 66)); ll.addLine(to: CGPoint(x: cx - 6, y: 50))
            ll.closeSubpath(); context.fill(ll, with: .color(Color.black.opacity(0.3)))
            // Right leg
            var rl = Path()
            rl.move(to: CGPoint(x: cx + 4, y: 50)); rl.addLine(to: CGPoint(x: cx + 8, y: 65)); rl.addLine(to: CGPoint(x: cx + 12, y: 79)); rl.addLine(to: CGPoint(x: cx + 5, y: 79)); rl.addLine(to: CGPoint(x: cx + 2, y: 65)); rl.addLine(to: CGPoint(x: cx, y: 50))
            rl.closeSubpath(); context.fill(rl, with: .color(Color.black.opacity(0.3)))
        }
    }
}

// MARK: - Sportsbook Sheet
struct PLSportsbookSheet: View {
    let cardBg: Color
    let dark: Color
    let onClose: () -> Void

    let books = [
        ("Betclic",  "https://www.betclic.fr"),
        ("Winamax",  "https://www.winamax.fr"),
        ("Unibet",   "https://www.unibet.fr"),
        ("PMU",      "https://www.pmu.fr/paris-sportifs"),
        ("Bwin",     "https://sports.bwin.fr"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(books.enumerated()), id: \.offset) { idx, book in
                Link(destination: URL(string: book.1)!) {
                    HStack {
                        Text(book.0)
                            .font(.custom("BarlowCondensed-Black", size: 15))
                            .foregroundColor(.white)
                            .kerning(1.5)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .overlay(
                        idx < books.count - 1
                            ? Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5).frame(maxHeight: .infinity, alignment: .bottom)
                            : nil
                    )
                }
            }
        }
        .background(Color.black.opacity(0.92))
        .cornerRadius(16)
    }
}

// MARK: - Detail View
struct PLMatchDetailView: View {
    let match: PLMatch
    let onBack: () -> Void
    @State private var barAnimated = false
    @State private var showBooks = false
    @State private var isVisible = false

    var dark: Color { Color.black.opacity(0.82) }
    var faint: Color { Color.black.opacity(0.16) }
    var faint2: Color { Color.black.opacity(0.09) }
    var mid: Color { Color.black.opacity(0.5) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Match meta
                    HStack(spacing: 8) {
                        PLLogo(size: 20)
                        Text("\(match.date) \(match.month.prefix(3)) · PREMIER LEAGUE")
                            .font(.custom("BarlowCondensed-Bold", size: 10))
                            .foregroundColor(mid)
                            .kerning(1.5)
                    }
                    .padding(.bottom, 6)

                    // Teams + time
                    HStack {
                        PLTeamBadge(team: match.home, size: 48)
                        Spacer()
                        HStack(spacing: 0) {
                            Text(match.time.0)
                                .font(.custom("BarlowCondensed-Black", size: 60))
                                .foregroundColor(dark)
                            Text(":\(match.time.1)")
                                .font(.custom("BarlowCondensed-Black", size: 60))
                                .foregroundColor(faint)
                        }
                        Spacer()
                        PLTeamBadge(team: match.away, size: 48)
                    }
                    .padding(.bottom, 4)

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.home.name).font(.custom("BarlowCondensed-Black", size: 15)).foregroundColor(dark)
                            Text(match.home.sub).font(.custom("BarlowCondensed-SemiBold", size: 11)).foregroundColor(mid)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(match.away.name).font(.custom("BarlowCondensed-SemiBold", size: 11)).foregroundColor(mid)
                            Text(match.away.sub).font(.custom("BarlowCondensed-Black", size: 15)).foregroundColor(dark)
                        }
                    }
                    .padding(.bottom, 20)

                    Divider().overlay(Color.black.opacity(0.09)).padding(.bottom, 18)

                    // AI Analysis + bar
                    PLAIAnalysisView(match: match, barAnimated: $barAnimated)
                        .padding(.bottom, 20)

                    Divider().overlay(Color.black.opacity(0.09)).padding(.bottom, 18)

                    // Recent Form
                    PLSectionLabel(text: "RECENT FORM (LAST 5)", dark: dark)
                    ForEach([match.home, match.away], id: \.abbr) { team in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                PLTeamBadge(team: team, size: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(team.name) \(team.sub)").font(.custom("BarlowCondensed-Black", size: 13)).foregroundColor(dark)
                                    Text("Avg \(String(format: "%.1f", team.goalsPerGame)) goals / game").font(.custom("BarlowCondensed-SemiBold", size: 10)).foregroundColor(mid)
                                }
                            }
                            HStack(spacing: 5) {
                                ForEach(team.form, id: \.self) { r in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(faint)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(r == "W" ? dark : faint, lineWidth: 1.5))
                                        Text(r).font(.custom("BarlowCondensed-Black", size: 13)).foregroundColor(dark)
                                    }
                                    .frame(width: 32, height: 32)
                                    .opacity(r == "L" ? 0.45 : 1)
                                }
                            }
                        }
                        .padding(.bottom, 14)
                    }

                    // Goals per game bars
                    ForEach(Array([match.home, match.away].enumerated()), id: \.offset) { idx, team in
                        VStack(spacing: 3) {
                            HStack {
                                Text(team.abbr).font(.custom("BarlowCondensed-ExtraBold", size: 11)).foregroundColor(dark)
                                Spacer()
                                Text(String(format: "%.1f", team.goalsPerGame)).font(.custom("BarlowCondensed-Black", size: 13)).foregroundColor(dark)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3).fill(faint).frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(idx == 0 ? dark : mid)
                                        .frame(width: barAnimated ? geo.size.width * CGFloat(team.goalsPerGame / 3) : 0, height: 6)
                                        .animation(.spring(response: 0.8).delay(0.2), value: barAnimated)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.bottom, 9)
                    }

                    Divider().overlay(Color.black.opacity(0.09)).padding(.vertical, 18)

                    // Lineups
                    PLSectionLabel(text: "LINEUPS", dark: dark)
                    ForEach([("home", match.lineup.home, match.home), ("away", match.lineup.away, match.away)], id: \.0) { _, players, team in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                PLTeamBadge(team: team, size: 22)
                                Text("\(team.name) \(team.sub)")
                                    .font(.custom("BarlowCondensed-Black", size: 12))
                                    .foregroundColor(dark)
                                    .kerning(1)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(players, id: \.number) { player in
                                        PLPlayerCardView(player: player, cardBg: match.cardBg, dark: dark)
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }
                        .padding(.bottom, 20)
                    }

                    Divider().overlay(Color.black.opacity(0.09)).padding(.bottom, 18)

                    // H2H
                    PLSectionLabel(text: "HEAD TO HEAD", dark: dark)
                    ForEach(match.h2h, id: \.date) { g in
                        HStack {
                            Text(g.date).font(.custom("BarlowCondensed-Bold", size: 11)).foregroundColor(mid).frame(width: 52, alignment: .leading)
                            Spacer()
                            HStack(spacing: 10) {
                                PLTeamBadge(team: match.home, size: 24)
                                Text(g.score).font(.custom("BarlowCondensed-Black", size: 24)).foregroundColor(dark).kerning(-0.5)
                                PLTeamBadge(team: match.away, size: 24)
                            }
                            Spacer()
                            Text(g.winner == "home" ? match.home.abbr : g.winner == "away" ? match.away.abbr : "DRAW")
                                .font(.custom("BarlowCondensed-Black", size: 10))
                                .foregroundColor(dark)
                                .kerning(1)
                                .opacity(g.winner == "draw" ? 0.4 : 1)
                                .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        .overlay(Rectangle().fill(Color.black.opacity(0.07)).frame(height: 0.5).frame(maxHeight: .infinity, alignment: .bottom))
                    }

                    // Overall record
                    HStack {
                        ForEach([
                            (match.home.abbr, match.h2h.filter { $0.winner == "home" }.count),
                            ("DRAW", match.h2h.filter { $0.winner == "draw" }.count),
                            (match.away.abbr, match.h2h.filter { $0.winner == "away" }.count),
                        ], id: \.0) { lbl, val in
                            Spacer()
                            VStack(spacing: 1) {
                                Text("\(val)").font(.custom("BarlowCondensed-Black", size: 32)).foregroundColor(dark)
                                Text(lbl).font(.custom("BarlowCondensed-Bold", size: 9)).foregroundColor(mid).kerning(1)
                            }
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(faint2)
                    .cornerRadius(12)
                    .padding(.top, 14)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            // BET button overlay
            VStack(spacing: 0) {
                if showBooks {
                    PLSportsbookSheet(cardBg: match.cardBg, dark: dark, onClose: { showBooks = false })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button(action: { withAnimation(.spring(response: 0.4)) { showBooks.toggle() } }) {
                    HStack(spacing: 10) {
                        Text(showBooks ? "CLOSE" : "BET NOW")
                            .font(.custom("BarlowCondensed-Black", size: 16))
                            .foregroundColor(match.cardBg)
                            .kerning(4)
                        Image(systemName: showBooks ? "xmark" : "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(match.cardBg)
                            .rotationEffect(.degrees(showBooks ? 0 : 0))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(dark)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(
                LinearGradient(colors: [match.cardBg.opacity(0), match.cardBg], startPoint: .top, endPoint: .bottom)
                    .frame(height: showBooks ? 420 : 120)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
            )
        }
        .background(match.cardBg)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                barAnimated = true
            }
        }
    }
}

// MARK: - Section Label
struct PLSectionLabel: View {
    let text: String
    let dark: Color
    var body: some View {
        Text(text)
            .font(.custom("BarlowCondensed-Bold", size: 9))
            .foregroundColor(dark.opacity(0.48))
            .kerning(2.2)
            .padding(.bottom, 10)
    }
}

// MARK: - RoundedCorner helper (PL prefix to avoid conflict)
private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(PLRoundedCorner(radius: radius, corners: corners))
    }
}
struct PLRoundedCorner: Shape {
    var radius: CGFloat; var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

// MARK: - Root Home View
struct HomeView: View {
    @State private var selectedMatch: PLMatch? = nil
    @State private var showDetail = false

    var body: some View {
        ZStack {
            PLMatchListView { match in
                selectedMatch = match
                withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                    showDetail = true
                }
            }

            if let match = selectedMatch {
                VStack(spacing: 0) {
                    // Nav bar over detail
                    HStack {
                        PLLogo(size: 30)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                                showDetail = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                selectedMatch = nil
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.black.opacity(0.22), lineWidth: 1.5)
                                    .frame(width: 34, height: 34)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.7))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 0)
                    .background(match.cardBg)

                    // Hero title
                    VStack(alignment: .leading, spacing: 0) {
                        Group {
                            Text("THE BEST")
                                .font(.custom("BarlowCondensed-Black", size: 68))
                                .foregroundColor(Color.black.opacity(0.82))
                                .kerning(-2.5)
                            Text("FOOTBALL")
                                .font(.custom("BarlowCondensed-Black", size: 68))
                                .foregroundColor(Color.black.opacity(0.82))
                                .kerning(-2.5)
                        }
                        .offset(x: showDetail ? 0 : -50)
                        .opacity(showDetail ? 1 : 0)
                        .animation(.spring(response: 0.65, dampingFraction: 0.82), value: showDetail)

                        Text("MATCH")
                            .font(.custom("BarlowCondensed-Black", size: 68))
                            .foregroundColor(match.cardBg)
                            .kerning(-2.5)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 6)
                            .background(Color.black.opacity(0.82))
                            .offset(x: showDetail ? 0 : -50)
                            .opacity(showDetail ? 1 : 0)
                            .animation(.spring(response: 0.65, dampingFraction: 0.82).delay(0.07), value: showDetail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .background(match.cardBg)

                    PLMatchDetailView(match: match, onBack: {
                        withAnimation(.spring(response: 0.65, dampingFraction: 0.82)) {
                            showDetail = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            selectedMatch = nil
                        }
                    })
                }
                .offset(y: showDetail ? 0 : UIScreen.main.bounds.height)
                .animation(.spring(response: 0.65, dampingFraction: 0.82), value: showDetail)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    HomeView()
}
