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
    var leaguePos: Int = 0         // league table position
    var played: Int = 0
    var points: Int = 0
    var goalDiff: String = "+0"
    var cleanSheets: Int = 0
    var injuries: [String] = []    // injured/suspended players
    var topScorer: String = ""     // top scorer name
    var topScorerGoals: Int = 0
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
    var venue: String = ""
    var referee: String = ""
    var broadcast: String = ""
    var timeline: String = "today"
    // F1 driver-specific stats
    var f1Position: Int = 0
    var f1Points: Int = 0
    var f1Wins: Int = 0
    var f1Podiums: Int = 0
    var f1Poles: Int = 0
    var f1TeamName: String = ""
    var f1RaceName: String = ""
    var f1RaceRound: Int = 0
    var f1RaceFlag: String = ""
    // F1 detail card data
    var f1DriverNumber: Int = 0
    var f1Nationality: String = ""
    var f1FastestLaps: Int = 0
    var f1DNFs: Int = 0
    var f1AvgQualifying: Double = 0.0
    var f1AvgFinish: Double = 0.0
    var f1RecentRaces: [(race: String, flag: String, position: Int, points: Int)] = []
    var f1TeammateAbbr: String = ""
    var f1TeammateName: String = ""
    var f1TeammateQualH2H: String = ""
    var f1TeammateRaceH2H: String = ""
    var f1CircuitHistory: [(year: String, position: Int)] = []
    var f1CircuitName: String = ""
    var f1CircuitLaps: Int = 0
    var f1CircuitLength: String = ""
    var f1RaceTime: String = ""
    // Live match stats
    var livePossHome: Int = 50
    var livePossAway: Int = 50
    var liveShotsHome: Int = 0
    var liveShotsAway: Int = 0
    var liveShotsOnHome: Int = 0
    var liveShotsOnAway: Int = 0
    var liveFoulsHome: Int = 0
    var liveFoulsAway: Int = 0
    var liveCornersHome: Int = 0
    var liveCornersAway: Int = 0
    var liveYellowHome: Int = 0
    var liveYellowAway: Int = 0
    var liveRedHome: Int = 0
    var liveRedAway: Int = 0
    var goalScorers: [(player: String, minute: Int, isHome: Bool)] = []

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
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/leaguelogos/soccer/500/23.png&w=200&h=200"),
        Sport(id: "f1",      label: "F1",              icon: "🏎", sfSymbol: "car.fill",          color: Color(hex:"#E8002D"), color2: Color(hex:"#FF6B6B"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/f1.png&w=200&h=200"),
        Sport(id: "tennis",  label: "TENNIS",          icon: "🎾", sfSymbol: "tennisball.fill",   color: Color(hex:"#4E9A41"), color2: Color(hex:"#A3D977"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/atp.png&w=200&h=200"),
        Sport(id: "nba",     label: "NBA",             icon: "🏀", sfSymbol: "basketball.fill",   color: Color(hex:"#1D428A"), color2: Color(hex:"#C9082A"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nba.png&w=200&h=200"),
        Sport(id: "nfl",     label: "NFL",             icon: "🏈", sfSymbol: "football.fill",     color: Color(hex:"#013369"), color2: Color(hex:"#D50A0A"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nfl.png&w=200&h=200"),
        Sport(id: "nhl",     label: "NHL",             icon: "🏒", sfSymbol: "hockey.puck.fill",  color: Color(hex:"#000000"), color2: Color(hex:"#A2AAAD"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/teamlogos/leagues/500/nhl.png&w=200&h=200"),
        Sport(id: "cricket", label: "IPL",             icon: "🏏", sfSymbol: "cricket.ball.fill", color: Color(hex:"#1C2C5B"), color2: Color(hex:"#D4A843"),
              logoURL: "https://a.espncdn.com/combiner/i?img=/i/cricket/cricinfologo.png&w=200&h=200"),
    ]

    static let leagues: [String: LeagueData] = [
        "soccer": LeagueData(name: "PREMIER", sub: "LEAGUE", matches: [
            // Yesterday - March 31, 2026 - Final Score Games
            MatchData(id:101, date:"31", month:"MARCH", kickoffHour:"15", kickoffMin:"00",
                home: Team(name:"MANCHESTER", sub:"CITY",    abbr:"MC",  hex:Color(hex:"#6CADDF"), kitColor:.white, form:[.win,.win,.win,.draw,.win],   goalsPerGame:2.8, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/382.png",
                    leaguePos:1, played:29, points:69, goalDiff:"+45", cleanSheets:14, injuries:[], topScorer:"Haaland", topScorerGoals:23),
                away: Team(name:"ARSENAL",    sub:"F.C.",    abbr:"ARS", hex:Color(hex:"#EF0107"), kitColor:.white, form:[.win,.loss,.win,.win,.win],   goalsPerGame:2.2, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/359.png",
                    leaguePos:2, played:29, points:66, goalDiff:"+40", cleanSheets:13, injuries:[], topScorer:"Saka", topScorerGoals:15),
                homePct:48, drawPct:22, awayPct:30, aiPick:"home", aiConf:76,
                aiReason:"Man City's home form is relentless. This was a classic battle between the top two sides of the league.",
                homeLineup:["Ederson","Walker","Rúben","Akanji","Gvardiol","Rodri","Kovačić","De Bruyne","Bernardo","Doku","Haaland"],
                awayLineup:["Raya","White","Saliba","Gabriel","Tomiyasu","Odegaard","Rice","Havertz","Saka","Martinelli","Jesus"],
                h2h:[H2HResult(date:"Jan 26",score:"2–0",outcome:"home"),H2HResult(date:"Oct 25",score:"0–0",outcome:"draw"),H2HResult(date:"Sep 24",score:"1–0",outcome:"away")],
                isLive: true, liveMinute: 90, liveHomeScore: 2, liveAwayScore: 1,
                venue: "Etihad Stadium, Manchester", referee: "Michael Oliver", broadcast: "Sky Sports", timeline: "yesterday",
                livePossHome: 64, livePossAway: 36, liveShotsHome: 18, liveShotsAway: 6,
                liveShotsOnHome: 6, liveShotsOnAway: 2, liveFoulsHome: 8, liveFoulsAway: 12,
                liveCornersHome: 7, liveCornersAway: 3, liveYellowHome: 1, liveYellowAway: 3,
                liveRedHome: 0, liveRedAway: 0,
                goalScorers: [(player:"Haaland", minute:28, isHome:true), (player:"De Bruyne", minute:67, isHome:true), (player:"Martinelli", minute:82, isHome:false)]),
            MatchData(id:102, date:"31", month:"MARCH", kickoffHour:"17", kickoffMin:"30",
                home: Team(name:"LIVERPOOL",  sub:"F.C.",     abbr:"LIV", hex:Color(hex:"#C8102E"), kitColor:.white, form:[.win,.win,.win,.win,.draw],   goalsPerGame:2.5, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/364.png",
                    leaguePos:3, played:29, points:63, goalDiff:"+38", cleanSheets:12, injuries:[], topScorer:"Salah", topScorerGoals:19),
                away: Team(name:"F.C.",       sub:"CHELSEA",   abbr:"CH",  hex:Color(hex:"#034694"), kitColor:.white, form:[.win,.loss,.win,.win,.win],   goalsPerGame:1.9, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/363.png",
                    leaguePos:4, played:29, points:56, goalDiff:"+21", cleanSheets:11, injuries:[], topScorer:"Palmer", topScorerGoals:16),
                homePct:55, drawPct:20, awayPct:25, aiPick:"home", aiConf:79,
                aiReason:"Liverpool's Anfield record is exceptional this season with Salah in prime form. Chelsea's away form remains inconsistent.",
                homeLineup:["Alisson","Alexander-Arnold","Konaté","Van Dijk","Robertson","Szoboszlai","Mac Allister","Curtis","Salah","Diaz","Jota"],
                awayLineup:["Sánchez","Reece","Silva","Adarabioyo","Chilwell","Caicedo","Gallagher","Palmer","Sterling","Mudryk","Jackson"],
                h2h:[H2HResult(date:"Jan 26",score:"3–2",outcome:"away"),H2HResult(date:"Oct 25",score:"1–2",outcome:"away"),H2HResult(date:"May 24",score:"4–1",outcome:"home")],
                isLive: true, liveMinute: 90, liveHomeScore: 3, liveAwayScore: 2,
                venue: "Anfield, Liverpool", referee: "Craig Pawson", broadcast: "Sky Sports", timeline: "yesterday",
                livePossHome: 61, livePossAway: 39, liveShotsHome: 16, liveShotsAway: 10,
                liveShotsOnHome: 7, liveShotsOnAway: 5, liveFoulsHome: 9, liveFoulsAway: 11,
                liveCornersHome: 8, liveCornersAway: 4, liveYellowHome: 2, liveYellowAway: 2,
                liveRedHome: 0, liveRedAway: 0,
                goalScorers: [(player:"Salah", minute:14, isHome:true), (player:"Diaz", minute:41, isHome:true), (player:"Palmer", minute:56, isHome:false), (player:"Jackson", minute:73, isHome:false), (player:"Curtis", minute:87, isHome:true)]),
            // Today - April 1, 2026 - Live and Upcoming
            MatchData(id:103, date:"01", month:"APRIL", kickoffHour:"15", kickoffMin:"00",
                home: Team(name:"TOTTENHAM",  sub:"HOTSPUR",  abbr:"TOT", hex:Color(hex:"#132257"), kitColor:.white, form:[.win,.win,.win,.draw,.loss], goalsPerGame:1.8, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/367.png",
                    leaguePos:5, played:29, points:50, goalDiff:"+10", cleanSheets:8, injuries:[], topScorer:"Son", topScorerGoals:14),
                away: Team(name:"MANCHESTER", sub:"UNITED",    abbr:"MU",  hex:Color(hex:"#DA291C"), kitColor:.white, form:[.win,.win,.loss,.win,.win],    goalsPerGame:2.2, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/360.png",
                    leaguePos:6, played:29, points:47, goalDiff:"+7", cleanSheets:8, injuries:["Shaw (Calf)"], topScorer:"Hojlund", topScorerGoals:11),
                homePct:42, drawPct:26, awayPct:32, aiPick:"home", aiConf:68,
                aiReason:"Spurs' home form has been excellent recently with Son in peak form. United's away record is vulnerable.",
                homeLineup:["Forster","Porro","Romero","Van de Ven","Udogie","Bentancur","Bissouma","Maddison","Johnson","Son","Richarlison"],
                awayLineup:["Onana","Dalot","Maguire","Lisandro","Amass","Casemiro","Fernandes","Garnacho","Rashford","Martial","Hojlund"],
                h2h:[H2HResult(date:"Feb 26",score:"2–2",outcome:"draw"),H2HResult(date:"Oct 25",score:"3–0",outcome:"home"),H2HResult(date:"Apr 24",score:"0–1",outcome:"away")],
                isLive: true, liveMinute: 67, liveHomeScore: 1, liveAwayScore: 1,
                venue: "Tottenham Hotspur Stadium, London", referee: "Simon Hooper", broadcast: "TNT Sports",
                livePossHome: 52, livePossAway: 48, liveShotsHome: 11, liveShotsAway: 9,
                liveShotsOnHome: 4, liveShotsOnAway: 3, liveFoulsHome: 10, liveFoulsAway: 9,
                liveCornersHome: 5, liveCornersAway: 4, liveYellowHome: 1, liveYellowAway: 2,
                liveRedHome: 0, liveRedAway: 0,
                goalScorers: [(player:"Son", minute:23, isHome:true), (player:"Hojlund", minute:52, isHome:false)]
                ),
            MatchData(id:104, date:"01", month:"APRIL", kickoffHour:"20", kickoffMin:"00",
                home: Team(name:"NEWCASTLE",  sub:"UNITED",   abbr:"NEW", hex:Color(hex:"#241F20"), kitColor:.white, form:[.win,.win,.draw,.win,.win],   goalsPerGame:2.1, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/361.png",
                    leaguePos:7, played:29, points:44, goalDiff:"+12", cleanSheets:9, injuries:[], topScorer:"Isak", topScorerGoals:16),
                away: Team(name:"ASTON",   sub:"VILLA",       abbr:"AV",  hex:Color(hex:"#95BFE5"), kitColor:Color(hex:"#4b0082"), form:[.loss,.win,.loss,.draw,.win], goalsPerGame:1.5, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/362.png",
                    leaguePos:8, played:29, points:43, goalDiff:"+11", cleanSheets:9, injuries:["Kamara (Knee)"], topScorer:"Watkins", topScorerGoals:14),
                homePct:48, drawPct:24, awayPct:28, aiPick:"home", aiConf:70,
                aiReason:"Newcastle's St. James' Park fortress with Isak firing is formidable. Aston Villa's midfield injury concern impacts their pressing.",
                homeLineup:["Pope","Trippier","Schär","Burn","Hall","Joelinton","Guimarães","Almiron","Gordon","Longstaff","Isak"],
                awayLineup:["Martínez","Cash","Carlos","Torres","Digne","Onana","McGinn","Luiz","Bailey","Watkins","Diaby"],
                h2h:[H2HResult(date:"Feb 26",score:"1–0",outcome:"home"),H2HResult(date:"Nov 25",score:"0–2",outcome:"away"),H2HResult(date:"May 24",score:"2–2",outcome:"draw")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "St. James' Park, Newcastle", referee: "David Coote", broadcast: "Sky Sports"
                ),
            // Upcoming - Future Matches
            MatchData(id:105, date:"04", month:"APRIL", kickoffHour:"15", kickoffMin:"00",
                home: Team(name:"BRIGHTON",  sub:"& HOVE", abbr:"BHA", hex:Color(hex:"#0087DC"), kitColor:.white, form:[.draw,.win,.loss,.win,.win],   goalsPerGame:1.6, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/331.png",
                    leaguePos:9, played:29, points:42, goalDiff:"+8", cleanSheets:8, injuries:["Enciso (Ankle)"], topScorer:"Ferguson", topScorerGoals:10),
                away: Team(name:"WOLVERHAMPTON", sub:"WANDERERS", abbr:"WOL", hex:Color(hex:"#FDB913"), kitColor:Color(hex:"#231F20"), form:[.loss,.loss,.win,.loss,.win], goalsPerGame:1.2, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/3891.png",
                    leaguePos:13, played:29, points:34, goalDiff:"-6", cleanSheets:6, injuries:["Neves (Hamstring)"], topScorer:"Cunha", topScorerGoals:11),
                homePct:54, drawPct:22, awayPct:24, aiPick:"home", aiConf:72,
                aiReason:"Brighton's solid home record and higher league position give them the edge. Wolves' away form is inconsistent.",
                homeLineup:["Steele","Veltman","Dunk","van Hecke","Estupiñán","Bissouma","O'Riley","Mitoma","Trossard","March","Ferguson"],
                awayLineup:["Sá","Aït-Nouri","Kilman","Bueno","Semedo","Neves","Gomes","Moutinho","Cunha","Lemina","Hojbjerg"],
                h2h:[H2HResult(date:"Feb 26",score:"2–2",outcome:"draw"),H2HResult(date:"Oct 25",score:"1–3",outcome:"away"),H2HResult(date:"Apr 24",score:"2–0",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "Amex Stadium, Brighton", referee: "Anthony Taylor", broadcast: "Sky Sports", timeline: "upcoming"),
            MatchData(id:106, date:"05", month:"APRIL", kickoffHour:"14", kickoffMin:"00",
                home: Team(name:"WEST HAM",   sub:"UNITED",   abbr:"WHU", hex:Color(hex:"#60223B"), kitColor:.white, form:[.loss,.draw,.loss,.win,.loss], goalsPerGame:1.3, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/371.png",
                    leaguePos:14, played:29, points:34, goalDiff:"-7", cleanSheets:5, injuries:["Scamacca (Knee)"], topScorer:"Bowen", topScorerGoals:9),
                away: Team(name:"EVERTON",   sub:"F.C.",    abbr:"EVE", hex:Color(hex:"#003DA5"), kitColor:.white, form:[.win,.draw,.draw,.loss,.win],   goalsPerGame:1.4, logoURL:"https://a.espncdn.com/i/teamlogos/soccer/500/368.png",
                    leaguePos:15, played:29, points:33, goalDiff:"-8", cleanSheets:6, injuries:["Yarmolenko (Back)"], topScorer:"Calvert-Lewin", topScorerGoals:8),
                homePct:42, drawPct:28, awayPct:30, aiPick:"home", aiConf:61,
                aiReason:"Both teams are in mid-table purgatory. West Ham's home record is slightly better, but this is a tight contest.",
                homeLineup:["Fabianski","Coufal","Aguerd","Gollini","Emerson","Álvarez","Soucek","Bowen","Fornals","Benrahma","Antonio"],
                awayLineup:["Pickford","Mykolenko","Tarkowski","Keane","Patterson","Gueye","Armstrong","Onana","Gray","Gordon","Calvert-Lewin"],
                h2h:[H2HResult(date:"Feb 26",score:"1–1",outcome:"draw"),H2HResult(date:"Nov 25",score:"2–0",outcome:"home"),H2HResult(date:"May 24",score:"1–1",outcome:"draw")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "London Stadium", referee: "Robert Jones", broadcast: "Sky Sports", timeline: "upcoming"),
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
        "tennis": LeagueData(name: "ATP", sub: "MIAMI OPEN", matches: [
            MatchData(id:201, date:"01", month:"APRIL", kickoffHour:"18", kickoffMin:"00",
                home: Team(name:"CARLOS",  sub:"ALCARAZ",   abbr:"ALC", hex:Color(hex:"#FFDA00"), kitColor:Color(hex:"#1D1D1D"), form:[.win,.win,.win,.loss,.win],   goalsPerGame:6.5, logoURL:"https://www.atptour.com/-/media/alias/player-gladiator/A0E2"),
                away: Team(name:"JANNIK",  sub:"SINNER",    abbr:"SIN", hex:Color(hex:"#F04438"), kitColor:.white,               form:[.win,.win,.win,.win,.loss],  goalsPerGame:6.2, logoURL:"https://www.atptour.com/-/media/alias/player-gladiator/S0AG"),
                homePct:45, drawPct:0, awayPct:55, aiPick:"away", aiConf:72,
                aiReason:"Sinner's hard-court mastery and first-serve dominance (68% this season) give him the edge over Alcaraz in this semifinal.",
                homeLineup:["Alcaraz","Ferrero","López","Moreno","Lledó","Martínez","Urquijo","Carreño","Nadal","Ferrer","López"],
                awayLineup:["Sinner","Cahill","Vagnozzi","Ferrara","Naldi","Cinà","Arnaldi","Musetti","Fognini","Cobolli","Vavassori"],
                h2h:[H2HResult(date:"IW 26",score:"6-2 6-4",outcome:"away"),H2HResult(date:"AO 26",score:"6-4 6-4",outcome:"away"),H2HResult(date:"USO 25",score:"6-3 7-5",outcome:"home")],
                isLive: true, liveMinute: 68, liveHomeScore: 1, liveAwayScore: 2,
                venue: "Hard Rock Stadium, Miami", referee: "James Keothavong", broadcast: "ESPN"
                ),
            MatchData(id:202, date:"01", month:"APRIL", kickoffHour:"20", kickoffMin:"30",
                home: Team(name:"GAEL",    sub:"MONFILS",   abbr:"MON", hex:Color(hex:"#1D428A"), kitColor:.white,               form:[.win,.loss,.win,.win,.loss],  goalsPerGame:5.2, logoURL:"https://www.atptour.com/-/media/alias/player-gladiator/MC65"),
                away: Team(name:"TOMMY",  sub:"PAUL",      abbr:"PAU", hex:Color(hex:"#C41E3A"), kitColor:.white,               form:[.draw,.win,.loss,.win,.win], goalsPerGame:5.6, logoURL:"https://www.atptour.com/-/media/alias/player-gladiator/PE44"),
                homePct:38, drawPct:0, awayPct:62, aiPick:"away", aiConf:68,
                aiReason:"Paul's powerful serving and baseline game are well-suited to Miami hardcourts. Monfils' age is beginning to show.",
                homeLineup:["Monfils","Amélie Tarot","Laurent Lokoli","Christophe Lambert","Yannick Etrych","Nicolas Escudé","Michaël Llodra","Fabrice Santoro","Arnaud Clément","Paul-Henri Mathieu","Sébastien de Chaunac"],
                awayLineup:["Paul","Michael Russell","Brett Breeden","Jason Chmielewski","Marko Milic","Patrick Mouratoglou","Mark Philippoussis","Tommy Ho","Tim Henman","Bjorn Phau","Nicolas Kiefer"],
                h2h:[H2HResult(date:"IW 26",score:"6-1 6-3",outcome:"away"),H2HResult(date:"ADO 25",score:"6-4 6-2",outcome:"away"),H2HResult(date:"USO 24",score:"5-7 7-6 6-3",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "Hard Rock Stadium, Miami", referee: "Ibe Bloemert", broadcast: "ESPN"
                ),
        ]),
        "nba": LeagueData(name: "NBA", sub: "2025–26", matches: [
            // Yesterday - March 31, 2026 - Final Score
            MatchData(id:301, date:"31", month:"MARCH", kickoffHour:"22", kickoffMin:"00",
                home: Team(name:"DENVER",       sub:"NUGGETS",  abbr:"DEN", hex:Color(hex:"#0E2240"), kitColor:Color(hex:"#FEC524"), form:[.win,.loss,.win,.win,.loss], goalsPerGame:115.4, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/den.png"),
                away: Team(name:"LOS ANGELES",  sub:"LAKERS",   abbr:"LAL", hex:Color(hex:"#552583"), kitColor:Color(hex:"#FDB927"), form:[.win,.loss,.win,.win,.loss], goalsPerGame:113.2, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/lal.png"),
                homePct:56, drawPct:0, awayPct:44, aiPick:"home", aiConf:74,
                aiReason:"Jokic's home MVP-caliber performance and Denver's ball movement overcame the Lakers' third-quarter push.",
                homeLineup:["Murray","Porter Jr.","Jokic","Gordon","KCP","Braun","Strawther","DeAndre","Vlatko","Bones","Zeke"],
                awayLineup:["LeBron","Davis","Reaves","Hachimura","Vincent","Hayes","Christie","Reddish","Kessler","Walker","Anunobya"],
                h2h:[H2HResult(date:"Feb 26",score:"124–119",outcome:"home"),H2HResult(date:"Dec 25",score:"120–108",outcome:"away"),H2HResult(date:"Apr 25",score:"118–115",outcome:"home")],
                isLive: true, liveMinute: 90, liveHomeScore: 118, liveAwayScore: 108,
                venue: "Ball Arena, Denver", referee: "John Goble", broadcast: "ESPN", timeline: "yesterday"),
            // Today - April 1, 2026 - Live Game
            MatchData(id:302, date:"01", month:"APRIL", kickoffHour:"19", kickoffMin:"30",
                home: Team(name:"BOSTON",       sub:"CELTICS",  abbr:"BOS", hex:Color(hex:"#007A33"), kitColor:.white,              form:[.win,.win,.win,.loss,.win],  goalsPerGame:119.8, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/bos.png"),
                away: Team(name:"NEW YORK",     sub:"KNICKS",   abbr:"NYK", hex:Color(hex:"#006BB6"), kitColor:Color(hex:"#F58426"), form:[.win,.loss,.win,.win,.win],  goalsPerGame:116.4, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/ny.png"),
                homePct:62, drawPct:0, awayPct:38, aiPick:"home", aiConf:76,
                aiReason:"Boston's elite defense holds the Knicks to sub-45% shooting. Tatum's mid-range dominance and bench depth prevail.",
                homeLineup:["Brown","Tatum","White","Porzingis","Al H.","Hauser","Holiday","Kornet","Nesmith","Pritchard","Sam H."],
                awayLineup:["Brunson","Barrett","Randle","Hartenstein","OG","Donte","Quickley","Robinson","McBride","Bogdanovic","Hart"],
                h2h:[H2HResult(date:"Mar 26",score:"120–112",outcome:"home"),H2HResult(date:"Jan 26",score:"114–105",outcome:"away"),H2HResult(date:"Nov 25",score:"128–120",outcome:"home")],
                isLive: true, liveMinute: 48, liveHomeScore: 62, liveAwayScore: 55,
                venue: "TD Garden, Boston", referee: "Tony Brown", broadcast: "TNT"
                ),
            // Upcoming - April 1, 2026 Evening
            MatchData(id:303, date:"01", month:"APRIL", kickoffHour:"21", kickoffMin:"30",
                home: Team(name:"PHOENIX",      sub:"SUNS",     abbr:"PHX", hex:Color(hex:"#1D1160"), kitColor:Color(hex:"#E56020"), form:[.loss,.win,.loss,.loss,.win], goalsPerGame:112.8, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/phx.png"),
                away: Team(name:"GOLDEN STATE", sub:"WARRIORS", abbr:"GSW", hex:Color(hex:"#FFC72C"), kitColor:Color(hex:"#1D428A"), form:[.win,.win,.loss,.win,.win],  goalsPerGame:117.3, logoURL:"https://a.espncdn.com/i/teamlogos/nba/500/gs.png"),
                homePct:42, drawPct:0, awayPct:58, aiPick:"away", aiConf:71,
                aiReason:"Warriors' 3-point prowess (44.2% this month) exploits Phoenix's perimeter defense. Curry's shooting is elite.",
                homeLineup:["Durant","Booker","Beal","Nurkic","Bridges","Allen","Wiseman","Craig","Mason","Bradley","Gordon"],
                awayLineup:["Curry","Thompson","Green","Wiggins","Kuminga","Paul","Moody","Podziemski","Looney","Butler","Peyton"],
                h2h:[H2HResult(date:"Mar 26",score:"130–127",outcome:"away"),H2HResult(date:"Dec 25",score:"122–118",outcome:"away"),H2HResult(date:"Feb 25",score:"124–115",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "Footprint Center, Phoenix", referee: "David Crawford", broadcast: "ESPN"
                ),
        ]),
        "nfl": LeagueData(name: "NFL", sub: "PRESEASON", matches: [
            MatchData(id:401, date:"15", month:"AUGUST", kickoffHour:"19", kickoffMin:"30",
                home: Team(name:"NEW ENGLAND", sub:"PATRIOTS",  abbr:"NE",  hex:Color(hex:"#002244"), kitColor:.white,              form:[.win,.win,.win,.loss,.win], goalsPerGame:24.1, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/ne.png"),
                away: Team(name:"NEW YORK",    sub:"JETS",      abbr:"NYJ", hex:Color(hex:"#125740"), kitColor:.white,              form:[.win,.loss,.win,.win,.loss], goalsPerGame:22.4, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/nyj.png"),
                homePct:52, drawPct:0, awayPct:48, aiPick:"home", aiConf:63,
                aiReason:"AFC East rivalry heats up in preseason. Patriots' veteran QB experience edges out the young Jets offense.",
                homeLineup:["Zappe","Montgomery","Godchaux","Juwonu","Shurmur","Harris","Brown","Kraft","Otton","Callaway","Tyler"],
                awayLineup:["Rodgers","Hall","Carter","Becton","Quinnen","Williams","Sauce","Saleh","Breece","Moore","Stinnett"],
                h2h:[H2HResult(date:"Aug 25",score:"14–10",outcome:"home"),H2HResult(date:"Aug 24",score:"24–17",outcome:"away"),H2HResult(date:"Aug 23",score:"20–10",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "Gillette Stadium, Foxborough", referee: "Shawn Hochuli", broadcast: "NBC", timeline: "upcoming"),
            MatchData(id:402, date:"17", month:"AUGUST", kickoffHour:"20", kickoffMin:"00",
                home: Team(name:"KANSAS CITY", sub:"CHIEFS",  abbr:"KC",  hex:Color(hex:"#E31837"), kitColor:.white,              form:[.win,.win,.win,.loss,.win], goalsPerGame:27.8, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/kc.png"),
                away: Team(name:"DENVER",      sub:"BRONCOS", abbr:"DEN", hex:Color(hex:"#FB4F14"), kitColor:Color(hex:"#002B5C"), form:[.win,.loss,.win,.win,.loss], goalsPerGame:25.3, logoURL:"https://a.espncdn.com/i/teamlogos/nfl/500/den.png"),
                homePct:58, drawPct:0, awayPct:42, aiPick:"home", aiConf:71,
                aiReason:"AFC West dominance. Mahomes and the Chiefs' preseason execution typically surpass Denver's rebuild efforts.",
                homeLineup:["Mahomes","Hill","Kelce","Jones","McKinnon","Nelson","Thuney","Creed","Brown","Wylie","Orlando"],
                awayLineup:["Jarrett","Williams","Bolles","Meinerz","Fleming","Shurmur","Sutton","Jeudy","Sharpe","Pickens","Brown"],
                h2h:[H2HResult(date:"Aug 26",score:"31–13",outcome:"home"),H2HResult(date:"Aug 25",score:"22–19",outcome:"away"),H2HResult(date:"Aug 24",score:"27–20",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "Arrowhead Stadium, Kansas City", referee: "Bill Vinovich", broadcast: "CBS", timeline: "upcoming"),
        ]),
        // ── FORMULA ONE — Australian GP — Full 2025 grid, one card per driver ──
        "f1": LeagueData(name: "FORMULA", sub: "ONE", matches: [

            // P1 — Max Verstappen (Red Bull)
            MatchData(id:501, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"MAX",      sub:"VERSTAPPEN", abbr:"VER", hex:Color(hex:"#3671C6"), kitColor:.white, form:[.win,.win,.podium,.win,.win],        goalsPerGame:25, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/M/MAXVER01_Max_Verstappen/maxver01.png.transform/2col/image.png"),
                away: Team(name:"YUKI",     sub:"TSUNODA",    abbr:"TSU", hex:Color(hex:"#6692FF"), kitColor:.white, form:[.podium,.loss,.podium,.loss,.loss],  goalsPerGame:8,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/redbullracing/yuktsu01/2026redbullracingyuktsu01right.webp"),
                homePct:88, drawPct:0, awayPct:12, aiPick:"home", aiConf:88,
                aiReason:"Verstappen's race pace at Albert Park is historically dominant — won 3 of last 4. RB21 has a 0.3s sector advantage and his tyre management is unmatched.",
                homeLineup:["Verstappen","Tsunoda"], awayLineup:["Tsunoda","Verstappen"],
                h2h:[H2HResult(date:"Bah 25",score:"P1",outcome:"home"),H2HResult(date:"Jed 25",score:"P3",outcome:"home"),H2HResult(date:"Mel 24",score:"P1",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 1, f1Points: 256, f1Wins: 6, f1Podiums: 8, f1Poles: 5, f1TeamName: "Red Bull Racing",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 1, f1Nationality: "🇳🇱", f1FastestLaps: 2, f1DNFs: 0, f1AvgQualifying: 1.5, f1AvgFinish: 1.3,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 1, points: 25), (race: "Saudi Arabia", flag: "🇸🇦", position: 1, points: 25), (race: "Melbourne", flag: "🇦🇺", position: 2, points: 18), (race: "Japan", flag: "🇯🇵", position: 1, points: 25), (race: "China", flag: "🇨🇳", position: 1, points: 25)],
                f1TeammateAbbr: "TSU", f1TeammateName: "Yuki Tsunoda", f1TeammateQualH2H: "8-2", f1TeammateRaceH2H: "8-1",
                f1CircuitHistory: [(year: "2024", position: 2), (year: "2023", position: 1), (year: "2022", position: 1)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P2 — Lando Norris (McLaren)
            MatchData(id:502, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"LANDO",    sub:"NORRIS",     abbr:"NOR", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.podium,.win,.podium,.win,.podium],  goalsPerGame:20, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/L/LANNOR01_Lando_Norris/lannor01.png.transform/2col/image.png"),
                away: Team(name:"OSCAR",    sub:"PIASTRI",    abbr:"PIA", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.win,.podium,.podium,.loss,.podium], goalsPerGame:16, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mclaren/oscpia01/2026mclarenoscpia01right.webp"),
                homePct:79, drawPct:0, awayPct:21, aiPick:"home", aiConf:79,
                aiReason:"McLaren's MCL39 has the strongest long-run pace this season. Norris has podiumed in every race so far and his tyre deg is excellent.",
                homeLineup:["Norris","Piastri"], awayLineup:["Piastri","Norris"],
                h2h:[H2HResult(date:"Bah 25",score:"P2",outcome:"home"),H2HResult(date:"Jed 25",score:"P1",outcome:"home"),H2HResult(date:"Mel 24",score:"P5",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 2, f1Points: 221, f1Wins: 3, f1Podiums: 9, f1Poles: 3, f1TeamName: "McLaren",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 4, f1Nationality: "🇬🇧", f1FastestLaps: 1, f1DNFs: 0, f1AvgQualifying: 2.1, f1AvgFinish: 1.8,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 2, points: 18), (race: "Saudi Arabia", flag: "🇸🇦", position: 1, points: 25), (race: "Melbourne", flag: "🇦🇺", position: 1, points: 25), (race: "Japan", flag: "🇯🇵", position: 2, points: 18), (race: "China", flag: "🇨🇳", position: 2, points: 18)],
                f1TeammateAbbr: "PIA", f1TeammateName: "Oscar Piastri", f1TeammateQualH2H: "5-5", f1TeammateRaceH2H: "6-3",
                f1CircuitHistory: [(year: "2024", position: 4), (year: "2023", position: 3)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P3 — Charles Leclerc (Ferrari)
            MatchData(id:503, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"CHARLES",  sub:"LECLERC",    abbr:"LEC", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.win,.podium,.win,.win],      goalsPerGame:18, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/C/CHALEC01_Charles_Leclerc/chalec01.png.transform/2col/image.png"),
                away: Team(name:"LEWIS",    sub:"HAMILTON",   abbr:"HAM", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.podium,.loss,.podium,.win],  goalsPerGame:14, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/ferrari/lewham01/2026ferrarilewham01right.webp"),
                homePct:74, drawPct:0, awayPct:26, aiPick:"home", aiConf:74,
                aiReason:"Leclerc's race craft has been flawless in 2025. Ferrari's SF-25 traction advantage out of slow corners at Albert Park suits his style perfectly.",
                homeLineup:["Leclerc","Hamilton"], awayLineup:["Hamilton","Leclerc"],
                h2h:[H2HResult(date:"Bah 25",score:"P3",outcome:"home"),H2HResult(date:"Jed 25",score:"P1",outcome:"home"),H2HResult(date:"Mel 24",score:"P2",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 3, f1Points: 177, f1Wins: 1, f1Podiums: 6, f1Poles: 2, f1TeamName: "Ferrari",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 16, f1Nationality: "🇲🇨", f1FastestLaps: 1, f1DNFs: 1, f1AvgQualifying: 2.8, f1AvgFinish: 2.2,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 3, points: 15), (race: "Saudi Arabia", flag: "🇸🇦", position: 1, points: 25), (race: "Melbourne", flag: "🇦🇺", position: 3, points: 15), (race: "Japan", flag: "🇯🇵", position: 2, points: 18), (race: "China", flag: "🇨🇳", position: 3, points: 15)],
                f1TeammateAbbr: "HAM", f1TeammateName: "Lewis Hamilton", f1TeammateQualH2H: "6-4", f1TeammateRaceH2H: "5-2",
                f1CircuitHistory: [(year: "2024", position: 5), (year: "2023", position: 2), (year: "2022", position: 4)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P4 — Lewis Hamilton (Ferrari)
            MatchData(id:504, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"LEWIS",    sub:"HAMILTON",   abbr:"HAM", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.podium,.loss,.podium,.win],  goalsPerGame:14, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/L/LEWHAM01_Lewis_Hamilton/lewham01.png.transform/2col/image.png"),
                away: Team(name:"CHARLES",  sub:"LECLERC",    abbr:"LEC", hex:Color(hex:"#E8002D"), kitColor:.white, form:[.podium,.win,.podium,.win,.win],      goalsPerGame:18, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/ferrari/chalec01/2026ferrarichalec01right.webp"),
                homePct:65, drawPct:0, awayPct:35, aiPick:"home", aiConf:65,
                aiReason:"Hamilton is finding his rhythm in the SF-25. His experience at Albert Park (6 wins) and wet-weather craft give him a strong P4 floor.",
                homeLineup:["Hamilton","Leclerc"], awayLineup:["Leclerc","Hamilton"],
                h2h:[H2HResult(date:"Bah 25",score:"P5",outcome:"home"),H2HResult(date:"Jed 25",score:"P4",outcome:"home"),H2HResult(date:"Mel 24",score:"P6",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 4, f1Points: 141, f1Wins: 0, f1Podiums: 4, f1Poles: 1, f1TeamName: "Ferrari",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 44, f1Nationality: "🇬🇧", f1FastestLaps: 2, f1DNFs: 1, f1AvgQualifying: 3.2, f1AvgFinish: 3.1,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 5, points: 10), (race: "Saudi Arabia", flag: "🇸🇦", position: 4, points: 12), (race: "Melbourne", flag: "🇦🇺", position: 6, points: 8), (race: "Japan", flag: "🇯🇵", position: 3, points: 15), (race: "China", flag: "🇨🇳", position: 4, points: 12)],
                f1TeammateAbbr: "LEC", f1TeammateName: "Charles Leclerc", f1TeammateQualH2H: "4-6", f1TeammateRaceH2H: "2-5",
                f1CircuitHistory: [(year: "2024", position: 3), (year: "2023", position: 2), (year: "2022", position: 1)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P5 — Oscar Piastri (McLaren)
            MatchData(id:505, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"OSCAR",    sub:"PIASTRI",    abbr:"PIA", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.win,.podium,.podium,.loss,.podium],  goalsPerGame:16, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/O/OSCPIA01_Oscar_Piastri/oscpia01.png.transform/2col/image.png"),
                away: Team(name:"LANDO",    sub:"NORRIS",     abbr:"NOR", hex:Color(hex:"#FF8000"), kitColor:.white, form:[.podium,.win,.podium,.win,.podium],  goalsPerGame:20, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mclaren/lannor01/2026mclarenlannor01right.webp"),
                homePct:61, drawPct:0, awayPct:39, aiPick:"home", aiConf:61,
                aiReason:"Piastri is the home hero at Albert Park. His race pace has improved dramatically and the MCL39 gives him a genuine shot at the podium.",
                homeLineup:["Piastri","Norris"], awayLineup:["Norris","Piastri"],
                h2h:[H2HResult(date:"Bah 25",score:"P4",outcome:"home"),H2HResult(date:"Jed 25",score:"P3",outcome:"home"),H2HResult(date:"Mel 24",score:"P5",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 5, f1Points: 134, f1Wins: 2, f1Podiums: 5, f1Poles: 1, f1TeamName: "McLaren",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 81, f1Nationality: "🇦🇺", f1FastestLaps: 1, f1DNFs: 0, f1AvgQualifying: 2.6, f1AvgFinish: 2.8,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 4, points: 12), (race: "Saudi Arabia", flag: "🇸🇦", position: 3, points: 15), (race: "Melbourne", flag: "🇦🇺", position: 5, points: 10), (race: "Japan", flag: "🇯🇵", position: 3, points: 15), (race: "China", flag: "🇨🇳", position: 2, points: 18)],
                f1TeammateAbbr: "NOR", f1TeammateName: "Lando Norris", f1TeammateQualH2H: "5-5", f1TeammateRaceH2H: "3-6",
                f1CircuitHistory: [(year: "2024", position: 8), (year: "2023", position: 6)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P6 — George Russell (Mercedes)
            MatchData(id:506, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"GEORGE",   sub:"RUSSELL",    abbr:"RUS", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.podium,.podium,.win,.loss,.podium],  goalsPerGame:16, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/G/GEORUS01_George_Russell/georus01.png.transform/2col/image.png"),
                away: Team(name:"KIMI",     sub:"ANTONELLI",  abbr:"ANT", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.loss,.podium,.loss,.loss,.podium],   goalsPerGame:8,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mercedes/andant01/2026mercedesandant01right.webp"),
                homePct:58, drawPct:0, awayPct:42, aiPick:"home", aiConf:58,
                aiReason:"Russell's tyre management and strategic nous give him an edge but the W16 lacks raw pace. A top 6 is his realistic ceiling.",
                homeLineup:["Russell","Antonelli"], awayLineup:["Antonelli","Russell"],
                h2h:[H2HResult(date:"Bah 25",score:"P6",outcome:"home"),H2HResult(date:"Jed 25",score:"P5",outcome:"home"),H2HResult(date:"Mel 24",score:"P3",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 6, f1Points: 108, f1Wins: 1, f1Podiums: 4, f1Poles: 2, f1TeamName: "Mercedes",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 63, f1Nationality: "🇬🇧", f1FastestLaps: 1, f1DNFs: 0, f1AvgQualifying: 2.3, f1AvgFinish: 2.9,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 6, points: 8), (race: "Saudi Arabia", flag: "🇸🇦", position: 5, points: 10), (race: "Melbourne", flag: "🇦🇺", position: 3, points: 15), (race: "Japan", flag: "🇯🇵", position: 4, points: 12), (race: "China", flag: "🇨🇳", position: 5, points: 10)],
                f1TeammateAbbr: "ANT", f1TeammateName: "Kimi Antonelli", f1TeammateQualH2H: "7-3", f1TeammateRaceH2H: "6-2",
                f1CircuitHistory: [(year: "2024", position: 6), (year: "2023", position: 7), (year: "2022", position: 6)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P7 — Kimi Antonelli (Mercedes)
            MatchData(id:507, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"KIMI",     sub:"ANTONELLI",  abbr:"ANT", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.loss,.podium,.loss,.loss,.podium],   goalsPerGame:8,  logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/A/ANDANT01_Andrea_Kimi_Antonelli/andant01.png.transform/2col/image.png"),
                away: Team(name:"GEORGE",   sub:"RUSSELL",    abbr:"RUS", hex:Color(hex:"#27F4D2"), kitColor:.black, form:[.podium,.podium,.win,.loss,.podium],  goalsPerGame:16, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/mercedes/georus01/2026mercedesgeorus01right.webp"),
                homePct:48, drawPct:0, awayPct:52, aiPick:"home", aiConf:48,
                aiReason:"The rookie sensation is showing flashes of brilliance. Raw speed is there but consistency at Albert Park's tricky turn 11–12 complex is the question.",
                homeLineup:["Antonelli","Russell"], awayLineup:["Russell","Antonelli"],
                h2h:[H2HResult(date:"Bah 25",score:"P8",outcome:"home"),H2HResult(date:"Jed 25",score:"P7",outcome:"home"),H2HResult(date:"Mel 24",score:"—",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 7, f1Points: 72, f1Wins: 0, f1Podiums: 2, f1Poles: 0, f1TeamName: "Mercedes",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 12, f1Nationality: "🇮🇹", f1FastestLaps: 0, f1DNFs: 1, f1AvgQualifying: 3.4, f1AvgFinish: 4.1,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 8, points: 0), (race: "Saudi Arabia", flag: "🇸🇦", position: 7, points: 4), (race: "Melbourne", flag: "🇦🇺", position: 10, points: 0), (race: "Japan", flag: "🇯🇵", position: 7, points: 4), (race: "China", flag: "🇨🇳", position: 8, points: 0)],
                f1TeammateAbbr: "RUS", f1TeammateName: "George Russell", f1TeammateQualH2H: "3-7", f1TeammateRaceH2H: "2-6",
                f1CircuitHistory: [(year: "2024", position: 12)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P8 — Carlos Sainz (Williams)
            MatchData(id:508, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"CARLOS",   sub:"SAINZ",      abbr:"SAI", hex:Color(hex:"#64C4FF"), kitColor:.white, form:[.podium,.loss,.podium,.podium,.win],  goalsPerGame:15, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/C/CARSAI01_Carlos_Sainz/carsai01.png.transform/2col/image.png"),
                away: Team(name:"ALEX",     sub:"ALBON",      abbr:"ALB", hex:Color(hex:"#64C4FF"), kitColor:.white, form:[.loss,.loss,.podium,.loss,.loss],     goalsPerGame:6,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/williams/alealb01/2026williamsalealb01right.webp"),
                homePct:44, drawPct:0, awayPct:56, aiPick:"home", aiConf:44,
                aiReason:"Sainz is extracting maximum performance from the FW47. His racecraft could steal points but the car lacks outright pace for a top 6.",
                homeLineup:["Sainz","Albon"], awayLineup:["Albon","Sainz"],
                h2h:[H2HResult(date:"Bah 25",score:"P7",outcome:"home"),H2HResult(date:"Jed 25",score:"P8",outcome:"home"),H2HResult(date:"Mel 24",score:"P4",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 8, f1Points: 58, f1Wins: 0, f1Podiums: 3, f1Poles: 0, f1TeamName: "Williams",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 55, f1Nationality: "🇪🇸", f1FastestLaps: 1, f1DNFs: 0, f1AvgQualifying: 3.1, f1AvgFinish: 3.6,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 7, points: 4), (race: "Saudi Arabia", flag: "🇸🇦", position: 8, points: 0), (race: "Melbourne", flag: "🇦🇺", position: 4, points: 12), (race: "Japan", flag: "🇯🇵", position: 6, points: 8), (race: "China", flag: "🇨🇳", position: 7, points: 4)],
                f1TeammateAbbr: "ALB", f1TeammateName: "Alex Albon", f1TeammateQualH2H: "6-4", f1TeammateRaceH2H: "7-2",
                f1CircuitHistory: [(year: "2024", position: 11), (year: "2023", position: 9)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P9 — Yuki Tsunoda (Red Bull)
            MatchData(id:509, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"YUKI",     sub:"TSUNODA",    abbr:"TSU", hex:Color(hex:"#6692FF"), kitColor:.white, form:[.podium,.loss,.podium,.loss,.loss],   goalsPerGame:8,  logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/Y/YUKTSU01_Yuki_Tsunoda/yuktsu01.png.transform/2col/image.png"),
                away: Team(name:"MAX",      sub:"VERSTAPPEN", abbr:"VER", hex:Color(hex:"#3671C6"), kitColor:.white, form:[.win,.win,.podium,.win,.win],         goalsPerGame:25, logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/redbullracing/maxver01/2026redbullracingmaxver01right.webp"),
                homePct:38, drawPct:0, awayPct:62, aiPick:"home", aiConf:38,
                aiReason:"Tsunoda's aggressive style works well at Albert Park. His qualifying pace has been surprisingly strong this season but race consistency is the concern.",
                homeLineup:["Tsunoda","Verstappen"], awayLineup:["Verstappen","Tsunoda"],
                h2h:[H2HResult(date:"Bah 25",score:"P9",outcome:"home"),H2HResult(date:"Jed 25",score:"P10",outcome:"home"),H2HResult(date:"Mel 24",score:"P8",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 9, f1Points: 42, f1Wins: 0, f1Podiums: 2, f1Poles: 0, f1TeamName: "Red Bull Racing",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 22, f1Nationality: "🇯🇵", f1FastestLaps: 0, f1DNFs: 0, f1AvgQualifying: 2.2, f1AvgFinish: 4.6,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 9, points: 0), (race: "Saudi Arabia", flag: "🇸🇦", position: 10, points: 0), (race: "Melbourne", flag: "🇦🇺", position: 8, points: 0), (race: "Japan", flag: "🇯🇵", position: 5, points: 10), (race: "China", flag: "🇨🇳", position: 6, points: 8)],
                f1TeammateAbbr: "VER", f1TeammateName: "Max Verstappen", f1TeammateQualH2H: "2-8", f1TeammateRaceH2H: "1-8",
                f1CircuitHistory: [(year: "2024", position: 9), (year: "2023", position: 11)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
            // P10 — Fernando Alonso (Aston Martin)
            MatchData(id:510, date:"30", month:"MAR · RACE", kickoffHour:"06", kickoffMin:"00",
                home: Team(name:"FERNANDO", sub:"ALONSO",     abbr:"ALO", hex:Color(hex:"#229971"), kitColor:.white, form:[.loss,.podium,.loss,.loss,.podium],   goalsPerGame:10, logoURL:"https://media.formula1.com/d_driver_fallback_image.png/content/dam/fom-website/drivers/F/FERALO01_Fernando_Alonso/feralo01.png.transform/2col/image.png"),
                away: Team(name:"LANCE",    sub:"STROLL",     abbr:"STR", hex:Color(hex:"#229971"), kitColor:.white, form:[.loss,.loss,.loss,.loss,.loss],        goalsPerGame:4,  logoURL:"https://media.formula1.com/image/upload/c_lfill,w_440/q_auto/v1740000001/common/f1/2026/astonmartin/lanstr01/2026astonmartinlanstr01right.webp"),
                homePct:35, drawPct:0, awayPct:65, aiPick:"home", aiConf:35,
                aiReason:"The veteran's experience and tyre management could be the difference in a chaotic race. AMR25 has improved but still lacks top-6 pace.",
                homeLineup:["Alonso","Stroll"], awayLineup:["Stroll","Alonso"],
                h2h:[H2HResult(date:"Bah 25",score:"P10",outcome:"home"),H2HResult(date:"Jed 25",score:"P9",outcome:"home"),H2HResult(date:"Mel 24",score:"P7",outcome:"home")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                f1Position: 10, f1Points: 28, f1Wins: 0, f1Podiums: 1, f1Poles: 0, f1TeamName: "Aston Martin",
                f1RaceName: "Australian Grand Prix", f1RaceRound: 3, f1RaceFlag: "🇦🇺",
                f1DriverNumber: 14, f1Nationality: "🇪🇸", f1FastestLaps: 1, f1DNFs: 1, f1AvgQualifying: 4.2, f1AvgFinish: 4.8,
                f1RecentRaces: [(race: "Bahrain", flag: "🇸🇦", position: 10, points: 0), (race: "Saudi Arabia", flag: "🇸🇦", position: 9, points: 0), (race: "Melbourne", flag: "🇦🇺", position: 7, points: 4), (race: "Japan", flag: "🇯🇵", position: 8, points: 0), (race: "China", flag: "🇨🇳", position: 9, points: 0)],
                f1TeammateAbbr: "STR", f1TeammateName: "Lance Stroll", f1TeammateQualH2H: "8-2", f1TeammateRaceH2H: "8-1",
                f1CircuitHistory: [(year: "2024", position: 13), (year: "2023", position: 12), (year: "2022", position: 10)],
                f1CircuitName: "Albert Park Circuit", f1CircuitLaps: 58, f1CircuitLength: "5.278 km", f1RaceTime: "SUN 15:00 AEST"
                ),
        ]),
        "nhl": LeagueData(name: "NHL", sub: "PLAYOFFS", matches: [
            // Yesterday - March 31, 2026 - Final Score
            MatchData(id:601, date:"31", month:"MARCH", kickoffHour:"20", kickoffMin:"00",
                home: Team(name:"FLORIDA",  sub:"PANTHERS", abbr:"FLA", hex:Color(hex:"#041E42"), kitColor:Color(hex:"#C8102E"), form:[.win,.win,.loss,.win,.win],  goalsPerGame:3.4, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/fla.png"),
                away: Team(name:"TORONTO",  sub:"MAPLE LEAFS", abbr:"TOR", hex:Color(hex:"#00205B"), kitColor:.white,              form:[.win,.loss,.win,.win,.loss], goalsPerGame:3.2, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/tor.png"),
                homePct:54, drawPct:0, awayPct:46, aiPick:"home", aiConf:71,
                aiReason:"Florida's playoff experience (defending Cup champs) and home-ice advantage proved decisive in a tight Game 3.",
                homeLineup:["Bobrovsky","Ekblad","Montour","Forsling","Nutivaara","Huberdeau","Reinhart","Verhaeghe","Tkachuk","Lomberg","Barkov"],
                awayLineup:["Samsonov","Brodie","Holl","Lilypad","Rielly","Matthews","Marner","Knies","Nylander","Robertson","Kampf"],
                h2h:[H2HResult(date:"Mar 31",score:"3–2",outcome:"home"),H2HResult(date:"Mar 28",score:"1–2",outcome:"away"),H2HResult(date:"Mar 25",score:"4–1",outcome:"home")],
                isLive: true, liveMinute: 60, liveHomeScore: 3, liveAwayScore: 2,
                venue: "FTX Arena, Miami", referee: "Tim Peel", broadcast: "ESPN", timeline: "yesterday"),
            // Today - April 1, 2026 - Live Game
            MatchData(id:602, date:"01", month:"APRIL", kickoffHour:"19", kickoffMin:"00",
                home: Team(name:"NEW YORK",   sub:"RANGERS",  abbr:"NYR", hex:Color(hex:"#00205B"), kitColor:.white,              form:[.win,.win,.loss,.win,.win],  goalsPerGame:3.3, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/nyr.png"),
                away: Team(name:"COLORADO",   sub:"AVALANCHE", abbr:"COL", hex:Color(hex:"#236192"), kitColor:.white,              form:[.win,.loss,.win,.win,.loss], goalsPerGame:3.6, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/col.png"),
                homePct:48, drawPct:0, awayPct:52, aiPick:"away", aiConf:68,
                aiReason:"Avalanche's speed and MacKinnon's offensive prowess trouble the Rangers' back line. Colorado's depth is superior.",
                homeLineup:["Shesterkin","Fox","Lindgren","Rooney","Trocheck","Zibanejad","Panarin","Drury","Kakko","Kreider","Lafrenière"],
                awayLineup:["Kuemper","MacKinnon","Rantanen","Landeskog","Makar","Girard","Lehkonen","O'Connor","Manson","Byram","Topol"],
                h2h:[H2HResult(date:"Mar 26",score:"2–4",outcome:"away"),H2HResult(date:"Feb 14",score:"3–1",outcome:"home"),H2HResult(date:"Jan 16",score:"2–1",outcome:"away")],
                isLive: true, liveMinute: 52, liveHomeScore: 1, liveAwayScore: 2,
                venue: "Madison Square Garden, New York", referee: "Dan O'Halloran", broadcast: "TNT"
                ),
            // Upcoming - April 2, 2026
            MatchData(id:603, date:"02", month:"APRIL", kickoffHour:"19", kickoffMin:"30",
                home: Team(name:"BOSTON",     sub:"BRUINS",    abbr:"BOS", hex:Color(hex:"#FCB514"), kitColor:Color(hex:"#000000"), form:[.win,.win,.loss,.win,.win],  goalsPerGame:3.7, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/bos.png"),
                away: Team(name:"EDMONTON",   sub:"OILERS",    abbr:"EDM", hex:Color(hex:"#FF4C00"), kitColor:Color(hex:"#041E42"), form:[.win,.loss,.win,.win,.loss], goalsPerGame:3.5, logoURL:"https://a.espncdn.com/i/teamlogos/nhl/500/edm.png"),
                homePct:55, drawPct:0, awayPct:45, aiPick:"home", aiConf:69,
                aiReason:"Bruins' playoff intensity at home and Bergeron's leadership neutralize McDavid's brilliance.",
                homeLineup:["Ullmark","McAvoy","Hampus","Grzelcyk","Carlo","Forbort","Bergeron","Marchand","Pastrnak","DeBrusk","Krejci"],
                awayLineup:["Skinner","Ekholm","Bouchard","Nurse","Ceci","Draisaitl","RNH","Nugent-Hopkins","McDavid","Hyman","Leon"],
                h2h:[H2HResult(date:"Mar 15",score:"5–2",outcome:"home"),H2HResult(date:"Feb 22",score:"3–3",outcome:"draw"),H2HResult(date:"Jan 8",score:"4–3",outcome:"away")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "TD Garden, Boston", referee: "Wes McCauley", broadcast: "ESPN", timeline: "upcoming"),
        ]),
        "cricket": LeagueData(name: "IPL", sub: "2026", matches: [
            MatchData(id:701, date:"01", month:"APRIL", kickoffHour:"15", kickoffMin:"30",
                home: Team(name:"MUMBAI",  sub:"INDIANS",    abbr:"MI",  hex:Color(hex:"#004BA0"), kitColor:.white,              form:[.win,.win,.loss,.win,.loss], goalsPerGame:184, logoURL:"https://a.espncdn.com/i/teamlogos/cricket/500/335974.png"),
                away: Team(name:"DELHI",   sub:"CAPITALS",   abbr:"DC",  hex:Color(hex:"#00205B"), kitColor:.white,               form:[.win,.loss,.win,.win,.win],  goalsPerGame:176, logoURL:"https://a.espncdn.com/i/teamlogos/cricket/500/335975.png"),
                homePct:48, drawPct:0, awayPct:52, aiPick:"away", aiConf:67,
                aiReason:"Delhi's middle-order depth and Pant's counter-attacking brilliance trouble Mumbai despite home advantage.",
                homeLineup:["Rohit","Ishan","Suryakumar","Hardik","Pollard","Krunal","Bumrah","Boult","Chahar","Varma","Tilak"],
                awayLineup:["Marsh","Pant","Kunal","Kaul","Axar","Lalit","Nortje","Khaleel","Kumar","Rabada","Sarfaraz"],
                h2h:[H2HResult(date:"IPL 25",score:"198–176",outcome:"away"),H2HResult(date:"IPL 24",score:"206–190",outcome:"home"),H2HResult(date:"IPL 23",score:"157–177",outcome:"away")],
                isLive: true, liveMinute: 13, liveHomeScore: 42, liveAwayScore: 38,
                venue: "Wankhede Stadium, Mumbai", referee: "Nitin Menon", broadcast: "Star Sports"
                ),
            MatchData(id:702, date:"03", month:"APRIL", kickoffHour:"19", kickoffMin:"00",
                home: Team(name:"RAJASTHAN", sub:"ROYALS",    abbr:"RR",  hex:Color(hex:"#E74C3C"), kitColor:.white,              form:[.draw,.win,.loss,.win,.win],   goalsPerGame:182, logoURL:"https://a.espncdn.com/i/teamlogos/cricket/500/335976.png"),
                away: Team(name:"KOLKATA",  sub:"KNIGHT RIDERS", abbr:"KKR", hex:Color(hex:"#9B59B6"), kitColor:.white,           form:[.loss,.win,.loss,.win,.win],  goalsPerGame:188, logoURL:"https://a.espncdn.com/i/teamlogos/cricket/500/335977.png"),
                homePct:45, drawPct:0, awayPct:55, aiPick:"away", aiConf:70,
                aiReason:"Kolkata's hard-hitting batting lineup and Starc's death bowling prowess edge the Royals in this inter-state battle.",
                homeLineup:["Samson","Jaiswal","Hetmyer","Padikkal","Ashwin","Pahal","Boult","Jofra","Kulkarni","Stokes","Avesh"],
                awayLineup:["Gill","Narine","Rana","Iyer","Rinku","Sadakant","Varun","Starc","Harshit","Cummins","Russell"],
                h2h:[H2HResult(date:"IPL 25",score:"156–188",outcome:"away"),H2HResult(date:"IPL 24",score:"182–165",outcome:"home"),H2HResult(date:"IPL 23",score:"164–172",outcome:"away")],
                isLive: false, liveMinute: 0, liveHomeScore: 0, liveAwayScore: 0,
                venue: "Sawai Mansingh Stadium, Jaipur", referee: "Sharfudin Khan", broadcast: "Star Sports", timeline: "upcoming"),
        ]),
    ]
}

extension FormResult {
    var shortLabel: String {
        switch self { case .win: return "W"; case .draw: return "D"; case .loss: return "L"; case .podium: return "P" }
    }
    var isPositive: Bool { self == .win || self == .podium }
}
