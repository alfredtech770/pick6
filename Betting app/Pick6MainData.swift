// Pick6MainData.swift
// Match data and models for the Pick6 main screen.

import SwiftUI

// MARK: - Models

struct Sport: Identifiable, Equatable {
    let id: String
    let label: String
    let icon: String
    let sfSymbol: String
    let color: Color
    let color2: Color      // secondary gradient color
    let logoURL: String    // official league/sport logo URL
}

struct Team {
    let name: String
    let sub: String
    let abbr: String
    let hex: Color
    let kitColor: Color
    let form: [FormResult]   // last 5
    let goalsPerGame: Double
    var logoURL: String = ""       // ESPN CDN or similar URL for team crest
}

// ESPN player headshot helper
func espnPlayerHeadshot(_ id: String) -> String {
    "https://a.espncdn.com/i/headshots/\(id)"
}

// Player info with optional headshot
struct PlayerInfo {
    let name: String
    let number: Int
    let headshotURL: String?

    init(_ name: String, _ number: Int, _ url: String? = nil) {
        self.name = name
        self.number = number
        self.headshotURL = url
    }
}

enum FormResult: String { case win = "W", draw = "D", loss = "L", podium = "P" }

struct H2HResult {
    let date: String
    let score: String
    let outcome: String  // "home" | "away" | "draw"
}

struct MatchData: Identifiable {
    let id: Int
    let date: String
    let month: String
    let kickoffHour: String
    let kickoffMin: String
    let home: Team
    let away: Team
    let homePct: Int
    let drawPct: Int
    let awayPct: Int
    let aiPick: String   // "home" | "away" | "draw"
    let aiConf: Int
    let aiReason: String
    let homeLineup: [String]
    let awayLineup: [String]
    let h2h: [H2HResult]
    let isLive: Bool
    let liveMinute: Int
    let liveHomeScore: Int
    let liveAwayScore: Int

    var winnerTeam: Team? {
        switch aiPick {
        case "home": return home
        case "away": return away
        default: return nil
        }
    }

    // Pastelise the predicted winner's color for card background
    var cardBackground: Color {
        guard let w = winnerTeam else { return Color(hex: "#E8E8E8") }
        return w.hex.pastelised(amount: 0.58)
    }
}

struct LeagueData {
    let name: String
    let sub: String
    let matches: [MatchData]
}

// MARK: - Color helpers

extension Color {
    func pastelised(amount: Double = 0.58) -> Color {
        let uic = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red:   r + (1 - r) * amount,
            green: g + (1 - g) * amount,
            blue:  b + (1 - b) * amount
        )
    }

    func darkened(by amount: Double = 0.25) -> Color {
        let uic = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red:   r * (1 - amount),
            green: g * (1 - amount),
            blue:  b * (1 - amount)
        )
    }
}

// MARK: - All sports

extension Pick6Data {
    static let allSports: [Sport] = [
        Sport(id: "soccer",  label: "PREMIER LEAGUE", icon: "⚽", sfSymbol: "soccerball.fill",   color: Color(hex:"#3D195B"), color2: Color(hex:"#04F5EC"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/23.png&w=80&h=80"),
        Sport(id: "f1",      label: "F1",              icon: "🏎", sfSymbol: "car.fill",          color: Color(hex:"#E8002D"), color2: Color(hex:"#FF6B6B"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/f1.png&w=80&h=80"),
        Sport(id: "tennis",  label: "TENNIS",          icon: "🎾", sfSymbol: "tennisball.fill",   color: Color(hex:"#4E9A41"), color2: Color(hex:"#A3D977"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/wta.png&w=80&h=80"),
        Sport(id: "nba",     label: "NBA",             icon: "🏀", sfSymbol: "basketball.fill",   color: Color(hex:"#1D428A"), color2: Color(hex:"#C9082A"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nba.png&w=80&h=80"),
        Sport(id: "nfl",     label: "NFL",             icon: "🏈", sfSymbol: "football.fill",     color: Color(hex:"#013369"), color2: Color(hex:"#D50A0A"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nfl.png&w=80&h=80"),
        Sport(id: "nhl",     label: "NHL",             icon: "🏒", sfSymbol: "hockey.puck.fill",  color: Color(hex:"#000000"), color2: Color(hex:"#A2AAAD"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nhl.png&w=80&h=80"),
        Sport(id: "cricket", label: "IPL",             icon: "🏏", sfSymbol: "cricket.ball.fill", color: Color(hex:"#1C2C5B"), color2: Color(hex:"#D4A843"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/cricket/cricinfologo.png&w=80&h=80"),
    ]

    static let leagues: [String: LeagueData] = [
        "soccer": LeagueData(name: "PREMIER", sub: "LEAGUE", matches: [
            MatchData(id:101, date:"08", month:"SEPTEMBER", kickoffHour:"09", kickoffMin:"30",
                home: Team(name:"MANCHESTER", sub:"UNITED",    abbr:"MU",  hex:Color(hex:"#DA291C"), kitColor:.white, form:[.win,.win,.loss,.win,.win],    goalsPerGame:2.1, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/360.png"),
                away: Team(name:"F.C.",       sub:"CHELSEA",   abbr:"CH",  hex:Color(hex:"#034694"), kitColor:.white, form:[.win,.draw,.win,.loss,.win],   goalsPerGame:1.8, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/363.png"),
                homePct:31, drawPct:22, awayPct:47, aiPick:"away", aiConf:74,
                aiReason:"Chelsea's recent xG superiority and Man Utd's defensive injuries give the away side a clear edge.",
                homeLineup:["Onana","Dalot","Maguire","Varane","Shaw","Casemiro","Fernandes","Mount","Rashford","Martial","Højlund"],
                awayLineup:["Sánchez","James","Silva","Disasi","Chilwell","Caicedo","Gallagher","Palmer","Sterling","Mudryk","Jackson"],
                h2h:[H2HResult(date:"Mar 24",score:"1–2",outcome:"away"),H2HResult(date:"Oct 23",score:"0–1",outcome:"away"),H2HResult(date:"May 23",score:"2–1",outcome:"home")],
                isLive: true, liveMinute: 67, liveHomeScore: 1, liveAwayScore: 2),
            MatchData(id:102, date:"12", month:"SEPTEMBER", kickoffHour:"12", kickoffMin:"00",
                home: Team(name:"CRYSTAL",   sub:"PALACE",  abbr:"CP",  hex:Color(hex:"#C41E3A"), kitColor:.white, form:[.win,.loss,.win,.win,.draw],  goalsPerGame:1.4, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/384.png"),
                away: Team(name:"LEICESTER", sub:"CITY",    abbr:"LC",  hex:Color(hex:"#0053A0"), kitColor:.white, form:[.loss,.draw,.loss,.win,.loss], goalsPerGame:0.9, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/375.png"),
                homePct:38, drawPct:25, awayPct:37, aiPick:"home", aiConf:68,
                aiReason:"Palace's home record is strong. Leicester are struggling with key absences in midfield.",
                homeLineup:["Henderson","Ward","Andersen","Guehi","Mitchell","Doucoure","Hughes","Eze","Olise","Ayew","Mateta"],
                awayLineup:["Ward","Castagne","Faes","Vestergaard","Justin","Soumare","Ndidi","Tete","Daka","Vardy","Iheanacho"],
                h2h:[H2HResult(date:"Feb 24",score:"2–0",outcome:"home"),H2HResult(date:"Sep 23",score:"1–1",outcome:"draw"),H2HResult(date:"Mar 23",score:"2–2",outcome:"draw")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:103, date:"14", month:"SEPTEMBER", kickoffHour:"13", kickoffMin:"00",
                home: Team(name:"AFC",     sub:"BOURNEMOUTH", abbr:"AB",  hex:Color(hex:"#DA291C"), kitColor:.white, form:[.win,.win,.draw,.win,.loss],  goalsPerGame:1.7, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/349.png"),
                away: Team(name:"ASTON",   sub:"VILLA",       abbr:"AV",  hex:Color(hex:"#95BFE5"), kitColor:Color(hex:"#4b0082"), form:[.loss,.win,.loss,.draw,.win], goalsPerGame:1.3, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/362.png"),
                homePct:42, drawPct:30, awayPct:28, aiPick:"home", aiConf:65,
                aiReason:"Bournemouth are in excellent home form with a high press that disrupts Aston Villa's build-up play.",
                homeLineup:["Flekken","Smith","Mepham","Senesi","Zemura","Cook","Christie","Billing","Semenyo","Solanke","Kluivert"],
                awayLineup:["Martínez","Cash","Carlos","Torres","Digne","Luiz","Kamara","McGinn","Bailey","Watkins","Diaby"],
                h2h:[H2HResult(date:"Jan 24",score:"0–1",outcome:"away"),H2HResult(date:"Aug 23",score:"3–2",outcome:"home"),H2HResult(date:"Apr 23",score:"1–1",outcome:"draw")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:104, date:"15", month:"SEPTEMBER", kickoffHour:"14", kickoffMin:"00",
                home: Team(name:"MANCHESTER", sub:"CITY",    abbr:"MC",  hex:Color(hex:"#6CADDF"), kitColor:.white, form:[.win,.win,.win,.draw,.win],   goalsPerGame:2.8, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/382.png"),
                away: Team(name:"ARSENAL",    sub:"F.C.",    abbr:"ARS", hex:Color(hex:"#EF0107"), kitColor:.white, form:[.win,.win,.loss,.win,.win],   goalsPerGame:2.3, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/359.png"),
                homePct:45, drawPct:22, awayPct:33, aiPick:"home", aiConf:78,
                aiReason:"Man City's home dominance and Haaland's form make them strong favourites in this top-of-table clash.",
                homeLineup:["Ederson","Walker","Rúben","Akanji","Gvardiol","Rodri","Kovačić","De Bruyne","Bernardo","Doku","Haaland"],
                awayLineup:["Raya","White","Saliba","Gabriel","Zinchenko","Odegaard","Rice","Havertz","Saka","Martinelli","Jesus"],
                h2h:[H2HResult(date:"Apr 24",score:"0–0",outcome:"draw"),H2HResult(date:"Jan 24",score:"1–0",outcome:"home"),H2HResult(date:"Sep 23",score:"1–0",outcome:"away")],
                isLive: true, liveMinute: 34, liveHomeScore: 2, liveAwayScore: 0),
            MatchData(id:105, date:"16", month:"SEPTEMBER", kickoffHour:"16", kickoffMin:"30",
                home: Team(name:"TOTTENHAM",  sub:"HOTSPUR",  abbr:"TOT", hex:Color(hex:"#132257"), kitColor:.white, form:[.win,.loss,.win,.draw,.loss], goalsPerGame:1.6, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/367.png"),
                away: Team(name:"LIVERPOOL",  sub:"F.C.",     abbr:"LIV", hex:Color(hex:"#C8102E"), kitColor:.white, form:[.win,.win,.win,.win,.draw],   goalsPerGame:2.5, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/364.png"),
                homePct:24, drawPct:20, awayPct:56, aiPick:"away", aiConf:81,
                aiReason:"Liverpool's front three are in ruthless form — 18 goals in 6 games. Spurs' high line is vulnerable on the counter.",
                homeLineup:["Forster","Pedro Porro","Romero","Van de Ven","Destiny","Bentancur","Bissouma","Maddison","Johnson","Son","Richarlison"],
                awayLineup:["Alisson","Alexander-Arnold","Konaté","Van Dijk","Robertson","Szoboszlai","Mac Allister","Curtis","Salah","Diaz","Nunez"],
                h2h:[H2HResult(date:"Apr 24",score:"0–2",outcome:"away"),H2HResult(date:"Sep 23",score:"2–1",outcome:"home"),H2HResult(date:"Apr 23",score:"1–6",outcome:"away")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:106, date:"17", month:"SEPTEMBER", kickoffHour:"20", kickoffMin:"00",
                home: Team(name:"NEWCASTLE",  sub:"UNITED",   abbr:"NEW", hex:Color(hex:"#241F20"), kitColor:.white, form:[.win,.win,.draw,.win,.win],   goalsPerGame:2.0, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/361.png"),
                away: Team(name:"WEST HAM",   sub:"UNITED",   abbr:"WHU", hex:Color(hex:"#60223B"), kitColor:.white, form:[.loss,.draw,.loss,.win,.loss], goalsPerGame:1.1, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/371.png"),
                homePct:55, drawPct:22, awayPct:23, aiPick:"home", aiConf:69,
                aiReason:"Newcastle's St. James' Park fortress (W8 D1 L0) and Isak's blistering form make them strong favourites.",
                homeLineup:["Pope","Trippier","Schär","Burn","Hall","Tonali","Guimarães","Almiron","Murphy","Gordon","Isak"],
                awayLineup:["Fabianski","Coufal","Dawson","Ogbonna","Emerson","Soucek","Rice","Bowen","Fornals","Benrahma","Antonio"],
                h2h:[H2HResult(date:"Mar 24",score:"4–2",outcome:"home"),H2HResult(date:"Oct 23",score:"0–2",outcome:"away"),H2HResult(date:"Apr 23",score:"1–1",outcome:"draw")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:107, date:"21", month:"MARCH", kickoffHour:"20", kickoffMin:"30",
                home: Team(name:"MIAMI HEAT",   sub:"HEAT",    abbr:"MIA", hex:Color(hex:"#98002E"), kitColor:Color(hex:"#F9A01B"),form:[.win,.win,.loss,.win,.loss], goalsPerGame:109.8, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/mia.png"),
                away: Team(name:"NEW YORK",     sub:"KNICKS",  abbr:"NYK", hex:Color(hex:"#006BB6"), kitColor:Color(hex:"#F58426"),form:[.win,.loss,.win,.win,.win],  goalsPerGame:114.2, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/ny.png"),
                homePct:44, drawPct:0, awayPct:56, aiPick:"away", aiConf:67,
                aiReason:"Jalen Brunson's clutch scoring (34.2 ppg in last 10) and New York's improved paint defense make the Knicks the pick.",
                homeLineup:["Adebayo","Butler","Lowry","Strus","Vincent","Herro","Oladipo","Dedmon","Highsmith","Caleb","Dru"],
                awayLineup:["Brunson","Barrett","Randle","Hartenstein","OG","Donte","Quickley","Robinson","McBride","Bogdanovic","Hart"],
                h2h:[H2HResult(date:"Feb 24",score:"109–104",outcome:"away"),H2HResult(date:"Jan 24",score:"120–113",outcome:"home"),H2HResult(date:"Nov 23",score:"116–110",outcome:"away")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:108, date:"22", month:"MARCH", kickoffHour:"03", kickoffMin:"00",
                home: Team(name:"PHOENIX",      sub:"SUNS",    abbr:"PHX", hex:Color(hex:"#1D1160"), kitColor:Color(hex:"#E56020"),form:[.loss,.win,.loss,.loss,.win], goalsPerGame:110.5, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/phx.png"),
                away: Team(name:"OKLAHOMA CITY",sub:"THUNDER", abbr:"OKC", hex:Color(hex:"#007AC1"), kitColor:Color(hex:"#EF3B24"),form:[.win,.win,.win,.win,.win],   goalsPerGame:122.8, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/okc.png"),
                homePct:33, drawPct:0, awayPct:67, aiPick:"away", aiConf:84,
                aiReason:"OKC leads the West with a +11.2 net rating. Shai Gilgeous-Alexander's efficiency (32.4 ppg, 54% FG) is unstoppable.",
                homeLineup:["Durant","Booker","Beal","Nurkic","Bridges","Allen","Wiseman","Okoye","Craig","Mason","Eric"],
                awayLineup:["SGA","Holmgren","Williams","Wallace","Dort","Dieng","Giddey","Hartenstein","Pingris","Chet","Joe"],
                h2h:[H2HResult(date:"Mar 24",score:"120–107",outcome:"away"),H2HResult(date:"Nov 23",score:"118–109",outcome:"away"),H2HResult(date:"Feb 23",score:"124–115",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
        ]),

        "tennis": LeagueData(name: "MIAMI", sub: "OPEN", matches: [
            MatchData(id:201, date:"24", month:"MARCH", kickoffHour:"19", kickoffMin:"00",
                home: Team(name:"CARLOS",  sub:"ALCARAZ",   abbr:"ALC", hex:Color(hex:"#FFDA00"), kitColor:Color(hex:"#1D1D1D"), form:[.win,.win,.win,.loss,.win],   goalsPerGame:6.4, logoURL:"https://a.espncdn.com/combiner/i?img=/i/headshots/tennis/players/full/4686087.png&w=350&h=254"),
                away: Team(name:"JANNIK",  sub:"SINNER",    abbr:"SIN", hex:Color(hex:"#F04438"), kitColor:.white,               form:[.win,.win,.win,.win,.loss],  goalsPerGame:6.1, logoURL:"https://a.espncdn.com/combiner/i?img=/i/headshots/tennis/players/full/4685460.png&w=350&h=254"),
                homePct:48, drawPct:0, awayPct:52, aiPick:"away", aiConf:69,
                aiReason:"Sinner's hard-court win rate of 91% this season and his dominant serve (67% first-serve points won) give him the edge.",
                homeLineup:["Alcaraz","J.C. Ferrero","Samuel López","Juanjo Moreno","Alberto Lledó","Antonio Martínez","Daniel Urquijo","Pablo Carreño","Rafael Nadal","David Ferrer","Feliciano López"],
                awayLineup:["Sinner","Darren Cahill","Simone Vagnozzi","Umberto Ferrara","Giacomo Naldi","Federico Cinà","Matteo Arnaldi","Lorenzo Musetti","Fabio Fognini","Flavio Cobolli","Andrea Vavassori"],
                h2h:[H2HResult(date:"AO 24",score:"6-4 6-4",outcome:"away"),H2HResult(date:"USO 23",score:"6-3 7-5",outcome:"home"),H2HResult(date:"IW 23",score:"6-1 6-4",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:202, date:"25", month:"MARCH", kickoffHour:"21", kickoffMin:"00",
                home: Team(name:"NOVAK",   sub:"DJOKOVIC",  abbr:"DJO", hex:Color(hex:"#1D428A"), kitColor:.white,               form:[.win,.loss,.win,.win,.win],  goalsPerGame:5.8, logoURL:"https://a.espncdn.com/combiner/i?img=/i/headshots/tennis/players/full/598.png&w=350&h=254"),
                away: Team(name:"DANIIL",  sub:"MEDVEDEV",  abbr:"MED", hex:Color(hex:"#C41E3A"), kitColor:.white,               form:[.win,.win,.loss,.win,.loss], goalsPerGame:5.5, logoURL:"https://a.espncdn.com/combiner/i?img=/i/headshots/tennis/players/full/4251.png&w=350&h=254"),
                homePct:62, drawPct:0, awayPct:38, aiPick:"home", aiConf:76,
                aiReason:"Djokovic holds a 12-4 H2H record against Medvedev and his Miami hard-court record is impeccable.",
                homeLineup:["Djokovic","Goran Ivanisevic","Gebhard Gritsch","Marco Panichi","Miljan Amanovic","Carlos Gomez-Herrera","Dusan Lajovic","Filip Krajinovic","Laslo Djere","Miomir Kecmanovic","Hamad Medjedovic"],
                awayLineup:["Medvedev","Gilles Cervara","Gilles Simon","Cédric Pioline","Éric Babolat","Andrey Rublev","Karen Khachanov","Aslan Karatsev","Roman Safiullin","Pavel Kotov","Alexander Shevchenko"],
                h2h:[H2HResult(date:"AO 24",score:"6-3 6-4",outcome:"home"),H2HResult(date:"USO 23",score:"6-3 7-6",outcome:"home"),H2HResult(date:"MC 23",score:"5-7 7-6 6-3",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
        ]),

        "nba": LeagueData(name: "NBA", sub: "2024–25", matches: [
            MatchData(id:301, date:"19", month:"MARCH", kickoffHour:"07", kickoffMin:"30",
                home: Team(name:"LOS ANGELES", sub:"LAKERS",  abbr:"LAL", hex:Color(hex:"#552583"), kitColor:Color(hex:"#FDB927"), form:[.win,.loss,.win,.win,.loss], goalsPerGame:112.4, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/lal.png"),
                away: Team(name:"BOSTON",       sub:"CELTICS", abbr:"BOS", hex:Color(hex:"#007A33"), kitColor:.white,              form:[.win,.win,.win,.loss,.win],  goalsPerGame:119.1, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/bos.png"),
                homePct:38, drawPct:0, awayPct:62, aiPick:"away", aiConf:77,
                aiReason:"Boston's defense ranks #1 in the league and their 3-point shooting (42.1%) neutralises the Lakers' paint dominance.",
                homeLineup:["LeBron","Davis","Reaves","Hachimura","Knecht","Hayes","Redick","Christie","Kessler","Cam","Gabe"],
                awayLineup:["Brown","Tatum","White","Porzingis","Al H.","Hauser","Holiday","Kornet","Nesmith","Pritchard","Sam H."],
                h2h:[H2HResult(date:"Jan 24",score:"114–105",outcome:"away"),H2HResult(date:"Dec 23",score:"128–124",outcome:"home"),H2HResult(date:"Mar 23",score:"125–121",outcome:"away")],
                isLive: true, liveMinute: 0, liveHomeScore: 89, liveAwayScore: 95),
            MatchData(id:302, date:"20", month:"MARCH", kickoffHour:"00", kickoffMin:"00",
                home: Team(name:"GOLDEN ST.", sub:"WARRIORS", abbr:"GSW", hex:Color(hex:"#FFC72C"), kitColor:Color(hex:"#1D428A"), form:[.win,.win,.loss,.win,.win],  goalsPerGame:118.2, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/gs.png"),
                away: Team(name:"DENVER",     sub:"NUGGETS",  abbr:"DEN", hex:Color(hex:"#0E2240"), kitColor:Color(hex:"#FEC524"), form:[.win,.loss,.win,.win,.loss], goalsPerGame:115.9, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/den.png"),
                homePct:52, drawPct:0, awayPct:48, aiPick:"home", aiConf:64,
                aiReason:"Curry's home efficiency (53% FG at Chase Center) and Jokic missing practice create a narrow Warriors edge.",
                homeLineup:["Curry","Thompson","Green","Wiggins","Kuminga","Paul","Moody","Podziemski","Looney","Butler","CP3"],
                awayLineup:["Murray","Porter Jr.","Jokic","Gordon","KCP","Braun","Strawther","DeAndre","Vlatko","Bones","Zeke"],
                h2h:[H2HResult(date:"Feb 24",score:"120–118",outcome:"home"),H2HResult(date:"Nov 23",score:"112–108",outcome:"away"),H2HResult(date:"Apr 23",score:"130–127",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
        ]),

        "nfl": LeagueData(name: "NFL", sub: "PLAYOFFS", matches: [
            MatchData(id:401, date:"22", month:"JANUARY", kickoffHour:"21", kickoffMin:"00",
                home: Team(name:"KANSAS CITY",   sub:"CHIEFS", abbr:"KC", hex:Color(hex:"#E31837"), kitColor:.white,              form:[.win,.win,.win,.loss,.win], goalsPerGame:27.4, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/kc.png"),
                away: Team(name:"SAN FRANCISCO", sub:"49ERS",  abbr:"SF", hex:Color(hex:"#AA0000"), kitColor:Color(hex:"#B3995D"),form:[.win,.win,.loss,.win,.win], goalsPerGame:24.8, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/sf.png"),
                homePct:54, drawPct:0, awayPct:46, aiPick:"home", aiConf:71,
                aiReason:"Mahomes at home in January is historically unbeatable — 14-1 record, and the Chiefs D is elite in the cold.",
                homeLineup:["Mahomes","Hill","Kelce","Jones","Hardman","McKinnon","Moore","Toney","Wylie","Humphrey","Thuney"],
                awayLineup:["Purdy","Aiyuk","Kittle","Deebo","McCaffrey","Juszczyk","Jennings","Mason","Bosa","Warner","Ward"],
                h2h:[H2HResult(date:"Feb 24",score:"25–22",outcome:"home"),H2HResult(date:"Oct 23",score:"31–17",outcome:"home"),H2HResult(date:"Feb 23",score:"38–35",outcome:"home")],
                isLive: true, liveMinute: 0, liveHomeScore: 20, liveAwayScore: 17),
            MatchData(id:402, date:"22", month:"JANUARY", kickoffHour:"17", kickoffMin:"30",
                home: Team(name:"SAN FRANCISCO", sub:"49ERS",  abbr:"SF", hex:Color(hex:"#AA0000"), kitColor:Color(hex:"#B3995D"),form:[.win,.win,.loss,.win,.win], goalsPerGame:24.8, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/sf.png"),
                away: Team(name:"LOS ANGELES",   sub:"RAMS",   abbr:"LAR",hex:Color(hex:"#003594"), kitColor:Color(hex:"#FFA300"),form:[.win,.loss,.win,.loss,.win], goalsPerGame:22.1, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/la.png"),
                homePct:61, drawPct:0, awayPct:39, aiPick:"home", aiConf:68,
                aiReason:"The 49ers' home record at Levi's Stadium (9-1 this season) and McCaffrey's dominance on the ground give them a clear edge.",
                homeLineup:["Purdy","McCaffrey","Aiyuk","Kittle","Deebo","Bosa","Warner","Hufanga","Greenlaw","Moody","Mitchell"],
                awayLineup:["Stafford","Kupp","Nacua","Robinson","Kamara","Donald","Young","Rapp","Thomas","Williams","Burden"],
                h2h:[H2HResult(date:"Jan 24",score:"27–21",outcome:"home"),H2HResult(date:"Oct 23",score:"30–23",outcome:"home"),H2HResult(date:"Jan 22",score:"20–17",outcome:"away")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:403, date:"23", month:"JANUARY", kickoffHour:"21", kickoffMin:"00",
                home: Team(name:"PHILADELPHIA", sub:"EAGLES",  abbr:"PHI",hex:Color(hex:"#004C54"), kitColor:.white,              form:[.win,.win,.win,.win,.loss], goalsPerGame:29.1, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/phi.png"),
                away: Team(name:"DALLAS",       sub:"COWBOYS", abbr:"DAL",hex:Color(hex:"#003594"), kitColor:.white,              form:[.loss,.win,.win,.loss,.win], goalsPerGame:25.6, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/dal.png"),
                homePct:58, drawPct:0, awayPct:42, aiPick:"home", aiConf:73,
                aiReason:"Eagles' O-line ranks #1 in the league and Jalen Hurts' scrambling ability exploits Dallas's soft edge rushers.",
                homeLineup:["Hurts","A.J.Brown","Smith","Kelce","Goedert","Saquon","Mailata","Jordan","Johnson","Sweat","Graham"],
                awayLineup:["Prescott","CeeDee","Lamb","Elliott","Schultz","Martin","Smith","Lawrence","Parsons","Diggs","Neal"],
                h2h:[H2HResult(date:"Nov 23",score:"28–23",outcome:"home"),H2HResult(date:"Oct 23",score:"17–9",outcome:"home"),H2HResult(date:"Dec 22",score:"40–34",outcome:"away")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
            MatchData(id:404, date:"24", month:"JANUARY", kickoffHour:"19", kickoffMin:"00",
                home: Team(name:"BUFFALO",   sub:"BILLS",    abbr:"BUF",hex:Color(hex:"#00338D"), kitColor:.white,              form:[.win,.win,.win,.loss,.win], goalsPerGame:28.3, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/buf.png"),
                away: Team(name:"MIAMI",     sub:"DOLPHINS", abbr:"MIA",hex:Color(hex:"#008E97"), kitColor:Color(hex:"#FC4C02"),form:[.win,.loss,.win,.win,.loss], goalsPerGame:26.7, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/mia.png"),
                homePct:63, drawPct:0, awayPct:37, aiPick:"home", aiConf:79,
                aiReason:"Josh Allen's cold-weather performance (108.4 passer rating below 40°F) and Buffalo's 4th-quarter dominance seal this.",
                homeLineup:["Allen","Diggs","Shakir","Knox","Cook","Motor","Dawkins","Morse","Brown","Oliver","Milano"],
                awayLineup:["Tagovailoa","Hill","Waddle","Gesicki","Mostert","Ahmed","Terron","Hunt","Wilkins","Jones","Baker"],
                h2h:[H2HResult(date:"Jan 24",score:"34–31",outcome:"home"),H2HResult(date:"Sep 23",score:"48–20",outcome:"home"),H2HResult(date:"Jan 23",score:"34–31 OT",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
        ]),

        // ── FORMULA ONE — Australian GP — Full 2025 grid, one card per driver ──
        "f1": LeagueData(name: "FORMULA", sub: "ONE", matches: [

            // P1 — Max Verstappen (Red Bull)
            MatchData(id:501, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"MAX",      sub:"VERSTAPPEN", abbr:"VER", hex:Color(hex:"#3671C6"), kitColor:.white, form:[.win,.win,.podium,.win,.win],        goalsPerGame:25, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/redbullracing/maxver01/2026redbullracingmaxver01right.webp"),
                away: Team(name:"YUKI",     sub:"TSUNODA",    abbr:"TSU", hex:Color(hex:"#6692FF"), kitColor:.white, form:[.podium,.loss,.podium,.loss,.loss],  goalsPerGame:8,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/redbullracing/yuktsu01/2026redbullracingyuktsu01right.webp"),
                homePct:88, drawPct:0, awayPct:12, aiPick:"home", aiConf:88,
                aiReason:"Verstappen's race pace at Albert Park is historically dominant — won 3 of last 4. RB21 has a 0.3s sector advantage and his tyre management is unmatched.",
                homeLineup:["Verstappen","Tsunoda"], awayLineup:["Tsunoda","Verstappen"],
                h2h:[H2HResult(date:"Bah 25",score:"P1",outcome:"home"),H2HResult(date:"Jed 25",score:"P3",outcome:"home"),H2HResult(date:"Mel 24",score:"P1",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P2 — Lando Norris (McLaren)
            MatchData(id:502, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"LANDO",    sub:"NORRIS",     abbr:"NOR", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.podium,.win,.podium,.win,.podium],  goalsPerGame:20, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mclaren/lannor01/2026mclarenlannor01right.webp"),
                away: Team(name:"OSCAR",    sub:"PIASTRI",    abbr:"PIA", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.win,.podium,.podium,.loss,.podium], goalsPerGame:16, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mclaren/oscpia01/2026mclarenoscpia01right.webp"),
                homePct:79, drawPct:0, awayPct:21, aiPick:"home", aiConf:79,
                aiReason:"McLaren's MCL39 has the strongest long-run pace this season. Norris has podiumed in every race so far and his tyre deg is excellent.",
                homeLineup:["Norris","Piastri"], awayLineup:["Piastri","Norris"],
                h2h:[H2HResult(date:"Bah 25",score:"P2",outcome:"home"),H2HResult(date:"Jed 25",score:"P1",outcome:"home"),H2HResult(date:"Mel 24",score:"P5",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P3 — Charles Leclerc (Ferrari)
            MatchData(id:503, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"CHARLES",  sub:"LECLERC",    abbr:"LEC", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.win,.podium,.win,.win],      goalsPerGame:18, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/ferrari/chalec01/2026ferrarichalec01right.webp"),
                away: Team(name:"LEWIS",    sub:"HAMILTON",   abbr:"HAM", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.podium,.loss,.podium,.win],  goalsPerGame:14, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/ferrari/lewham01/2026ferrarilewham01right.webp"),
                homePct:74, drawPct:0, awayPct:26, aiPick:"home", aiConf:74,
                aiReason:"Leclerc's race craft has been flawless in 2025. Ferrari's SF-25 traction advantage out of slow corners at Albert Park suits his style perfectly.",
                homeLineup:["Leclerc","Hamilton"], awayLineup:["Hamilton","Leclerc"],
                h2h:[H2HResult(date:"Bah 25",score:"P3",outcome:"home"),H2HResult(date:"Jed 25",score:"P1",outcome:"home"),H2HResult(date:"Mel 24",score:"P2",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P4 — Lewis Hamilton (Ferrari)
            MatchData(id:504, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"LEWIS",    sub:"HAMILTON",   abbr:"HAM", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.podium,.loss,.podium,.win],  goalsPerGame:14, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/ferrari/lewham01/2026ferrarilewham01right.webp"),
                away: Team(name:"CHARLES",  sub:"LECLERC",    abbr:"LEC", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.win,.podium,.win,.win],      goalsPerGame:18, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/ferrari/chalec01/2026ferrarichalec01right.webp"),
                homePct:65, drawPct:0, awayPct:35, aiPick:"home", aiConf:65,
                aiReason:"Hamilton is finding his rhythm in the SF-25. His experience at Albert Park (6 wins) and wet-weather craft give him a strong P4 floor.",
                homeLineup:["Hamilton","Leclerc"], awayLineup:["Leclerc","Hamilton"],
                h2h:[H2HResult(date:"Bah 25",score:"P5",outcome:"home"),H2HResult(date:"Jed 25",score:"P4",outcome:"home"),H2HResult(date:"Mel 24",score:"P6",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P5 — Oscar Piastri (McLaren)
            MatchData(id:505, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"OSCAR",    sub:"PIASTRI",    abbr:"PIA", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.win,.podium,.podium,.loss,.podium],  goalsPerGame:16, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mclaren/oscpia01/2026mclarenoscpia01right.webp"),
                away: Team(name:"LANDO",    sub:"NORRIS",     abbr:"NOR", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.podium,.win,.podium,.win,.podium],  goalsPerGame:20, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mclaren/lannor01/2026mclarenlannor01right.webp"),
                homePct:61, drawPct:0, awayPct:39, aiPick:"home", aiConf:61,
                aiReason:"Piastri is the home hero at Albert Park. His race pace has improved dramatically and the MCL39 gives him a genuine shot at the podium.",
                homeLineup:["Piastri","Norris"], awayLineup:["Norris","Piastri"],
                h2h:[H2HResult(date:"Bah 25",score:"P4",outcome:"home"),H2HResult(date:"Jed 25",score:"P3",outcome:"home"),H2HResult(date:"Mel 24",score:"P5",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P6 — George Russell (Mercedes)
            MatchData(id:506, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"GEORGE",   sub:"RUSSELL",    abbr:"RUS", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.podium,.podium,.win,.loss,.podium],  goalsPerGame:16, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mercedes/georus01/2026mercedesgeorus01right.webp"),
                away: Team(name:"KIMI",     sub:"ANTONELLI",  abbr:"ANT", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.loss,.podium,.loss,.loss,.podium],   goalsPerGame:8,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mercedes/andant01/2026mercedesandant01right.webp"),
                homePct:58, drawPct:0, awayPct:42, aiPick:"home", aiConf:58,
                aiReason:"Russell's tyre management and strategic nous give him an edge but the W16 lacks raw pace. A top 6 is his realistic ceiling.",
                homeLineup:["Russell","Antonelli"], awayLineup:["Antonelli","Russell"],
                h2h:[H2HResult(date:"Bah 25",score:"P6",outcome:"home"),H2HResult(date:"Jed 25",score:"P5",outcome:"home"),H2HResult(date:"Mel 24",score:"P3",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P7 — Kimi Antonelli (Mercedes)
            MatchData(id:507, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"KIMI",     sub:"ANTONELLI",  abbr:"ANT", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.loss,.podium,.loss,.loss,.podium],   goalsPerGame:8,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mercedes/andant01/2026mercedesandant01right.webp"),
                away: Team(name:"GEORGE",   sub:"RUSSELL",    abbr:"RUS", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.podium,.podium,.win,.loss,.podium],  goalsPerGame:16, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mercedes/georus01/2026mercedesgeorus01right.webp"),
                homePct:48, drawPct:0, awayPct:52, aiPick:"home", aiConf:48,
                aiReason:"The rookie sensation is showing flashes of brilliance. Raw speed is there but consistency at Albert Park's tricky turn 11–12 complex is the question.",
                homeLineup:["Antonelli","Russell"], awayLineup:["Russell","Antonelli"],
                h2h:[H2HResult(date:"Bah 25",score:"P8",outcome:"home"),H2HResult(date:"Jed 25",score:"P7",outcome:"home"),H2HResult(date:"Mel 24",score:"—",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P8 — Carlos Sainz (Williams)
            MatchData(id:508, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"CARLOS",   sub:"SAINZ",      abbr:"SAI", hex:Color(hex:"#64C4FF"), kitColor:.white, form:[.podium,.loss,.podium,.podium,.win],  goalsPerGame:15, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/williams/carsai01/2026williamscarsai01right.webp"),
                away: Team(name:"ALEX",     sub:"ALBON",      abbr:"ALB", hex:Color(hex:"#64C4FF"), kitColor:.white, form:[.loss,.loss,.podium,.loss,.loss],     goalsPerGame:6,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/williams/alealb01/2026williamsalealb01right.webp"),
                homePct:44, drawPct:0, awayPct:56, aiPick:"home", aiConf:44,
                aiReason:"Sainz is extracting maximum performance from the FW47. His racecraft could steal points but the car lacks outright pace for a top 6.",
                homeLineup:["Sainz","Albon"], awayLineup:["Albon","Sainz"],
                h2h:[H2HResult(date:"Bah 25",score:"P7",outcome:"home"),H2HResult(date:"Jed 25",score:"P8",outcome:"home"),H2HResult(date:"Mel 24",score:"P4",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P9 — Yuki Tsunoda (Red Bull)
            MatchData(id:509, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"YUKI",     sub:"TSUNODA",    abbr:"TSU", hex:Color(hex:"#6692FF"), kitColor:.white, form:[.podium,.loss,.podium,.loss,.loss],   goalsPerGame:8,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/redbullracing/yuktsu01/2026redbullracingyuktsu01right.webp"),
                away: Team(name:"MAX",      sub:"VERSTAPPEN", abbr:"VER", hex:Color(hex:"#3671C6"), kitColor:.white, form:[.win,.win,.podium,.win,.win],         goalsPerGame:25, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/redbullracing/maxver01/2026redbullracingmaxver01right.webp"),
                homePct:38, drawPct:0, awayPct:62, aiPick:"home", aiConf:38,
                aiReason:"Tsunoda's aggressive style works well at Albert Park. His qualifying pace has been surprisingly strong this season but race consistency is the concern.",
                homeLineup:["Tsunoda","Verstappen"], awayLineup:["Verstappen","Tsunoda"],
                h2h:[H2HResult(date:"Bah 25",score:"P9",outcome:"home"),H2HResult(date:"Jed 25",score:"P10",outcome:"home"),H2HResult(date:"Mel 24",score:"P8",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),

            // P10 — Fernando Alonso (Aston Martin)
            MatchData(id:510, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"FERNANDO", sub:"ALONSO",     abbr:"ALO", hex:Color(hex:"#229971"), kitColor:.white, form:[.loss,.podium,.loss,.loss,.podium],   goalsPerGame:10, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/astonmartin/feralo01/2026astonmartinferalo01right.webp"),
                away: Team(name:"LANCE",    sub:"STROLL",     abbr:"STR", hex:Color(hex:"#229971"), kitColor:.white, form:[.loss,.loss,.loss,.loss,.loss],        goalsPerGame:4,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/astonmartin/lanstr01/2026astonmartinlanstr01right.webp"),
                homePct:35, drawPct:0, awayPct:65, aiPick:"home", aiConf:35,
                aiReason:"The veteran's experience and tyre management could be the difference in a chaotic race. AMR25 has improved but still lacks top-6 pace.",
                homeLineup:["Alonso","Stroll"], awayLineup:["Stroll","Alonso"],
                h2h:[H2HResult(date:"Bah 25",score:"P10",outcome:"home"),H2HResult(date:"Jed 25",score:"P9",outcome:"home"),H2HResult(date:"Mel 24",score:"P7",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
        ]),

        "nhl": LeagueData(name: "NHL", sub: "2024–25", matches: [
            MatchData(id:601, date:"21", month:"MARCH", kickoffHour:"19", kickoffMin:"00",
                home: Team(name:"COLORADO", sub:"AVALANCHE", abbr:"COL", hex:Color(hex:"#236192"), kitColor:.white,              form:[.win,.win,.loss,.win,.win],  goalsPerGame:3.8, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/col.png"),
                away: Team(name:"EDMONTON", sub:"OILERS",    abbr:"EDM", hex:Color(hex:"#FF4C00"), kitColor:Color(hex:"#041E42"),form:[.win,.loss,.win,.win,.loss], goalsPerGame:3.5, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/edm.png"),
                homePct:51, drawPct:0, awayPct:49, aiPick:"home", aiConf:63,
                aiReason:"MacKinnon's 1.4 pts/game at Ball Arena and Colorado's 5-on-5 xGF% of 54.2 give them a slight structural edge.",
                homeLineup:["Kuemper","MacKinnon","Rantanen","Landeskog","Makar","Girard","Lehkonen","O'Connor","Manson","Byram","Helm"],
                awayLineup:["Skinner","McDavid","Draisaitl","Hyman","Ekholm","Bouchard","Nugent-Hopkins","Yamamoto","Nurse","Ceci","Puljujarvi"],
                h2h:[H2HResult(date:"Feb 24",score:"4–3 OT",outcome:"away"),H2HResult(date:"Nov 23",score:"6–2",outcome:"home"),H2HResult(date:"Mar 23",score:"5–3",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
        ]),

        "cricket": LeagueData(name: "IPL", sub: "2025", matches: [
            MatchData(id:701, date:"22", month:"MARCH", kickoffHour:"14", kickoffMin:"00",
                home: Team(name:"MUMBAI",  sub:"INDIANS",    abbr:"MI",  hex:Color(hex:"#004BA0"), kitColor:.white,              form:[.win,.win,.loss,.win,.loss], goalsPerGame:178, logoURL:"https://a.espncdn.com/i/teamlogos/cricket/500/335974.png"),
                away: Team(name:"CHENNAI", sub:"SUPER KINGS", abbr:"CSK", hex:Color(hex:"#FDBE00"), kitColor:Color(hex:"#002147"),form:[.win,.win,.win,.loss,.win],  goalsPerGame:192, logoURL:"https://a.espncdn.com/i/teamlogos/cricket/500/335973.png"),
                homePct:42, drawPct:0, awayPct:58, aiPick:"away", aiConf:72,
                aiReason:"CSK's batting depth (avg 7th wicket at 28.4) and Dhoni's finishing rate in Mumbai make them favourites.",
                homeLineup:["Rohit","Ishan","Suryakumar","Hardik","Pollard","Krunal","Bumrah","Boult","Chahar","Saurabh","Tilak"],
                awayLineup:["Ruturaj","Devon","Shivam","Ambati","Jadeja","Dube","Dhoni","Asitha","Mustafizur","Simarjeet","Pathirana"],
                h2h:[H2HResult(date:"IPL 24",score:"206–190",outcome:"away"),H2HResult(date:"IPL 23",score:"157–177",outcome:"away"),H2HResult(date:"IPL 22",score:"195–186",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0),
        ]),
    ]
}

extension FormResult {
    var shortLabel: String {
        switch self { case .win: return "W"; case .draw: return "D"; case .loss: return "L"; case .podium: return "P" }
    }
    var isPositive: Bool { self == .win || self == .podium }
}
