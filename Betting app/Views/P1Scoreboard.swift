import SwiftUI
import Combine

// MARK: All games
// Every game of the day from ESPN's public scoreboards, with its live score,
// whether or not PICK1 published a prediction on it. The pipeline only writes
// the games it analysed, and its own live loop only reads yesterday through
// tomorrow, so a home page built on picks alone showed part of the slate and
// sometimes missed live games entirely. This is the whole board, read by the
// app itself, with the PICK1 call attached where one exists.

nonisolated struct P1GameSide: Hashable, Sendable {
    let name: String
    let short: String
    let code: String
    let logo: String?
    let record: String?
    let score: Int?
    let winner: Bool
    /// ESPN team id, for the team page. Nil for athletes and pick-only rows.
    var teamID: String? = nil
    /// Team colour, hex without #; the alternate when the primary is black or white.
    var color: String? = nil
}

nonisolated struct P1Game: Identifiable, Hashable, Sendable {
    enum Phase: Int, Sendable { case live = 0, pre = 1, final = 2, off = 3 }
    let id: String
    let sport: String
    let league: String
    let order: Int
    let date: Date
    let phase: Phase
    let detail: String
    let home: P1GameSide
    let away: P1GameSide
    let note: String
    /// Races and tournaments: one line, no opponent.
    let isField: Bool
    /// ESPN feed path ("football/nfl"), nil for rows built from a pick alone.
    var path: String? = nil
}

extension Notification.Name {
    static let pick1OpenGame = Notification.Name("pick1OpenGame")
}

/// A game a notification asked to open, held until the home screen can.
@MainActor enum P1DeepLink {
    static var pendingGameKey: String?
}

extension P1Game {
    /// "espn|football/nfl|401873011|2026-10-25": the id the team-alerts job,
    /// push deep links and Live Activities share.
    var alertKey: String? {
        guard let path, !id.hasPrefix("pick-") else { return nil }
        return "espn|\(path)|\(id)|\(P1BookDays.key(date))"
    }
}

nonisolated struct P1BoardLeague: Sendable {
    let sport: String
    let label: String
    let path: String
    var query = ""
}

nonisolated enum P1ScoreboardFeed {
    static let leagues: [P1BoardLeague] = [
        .init(sport: "football", label: "NFL", path: "football/nfl"),
        .init(sport: "football", label: "NCAAF", path: "football/college-football", query: "&groups=80"),
        .init(sport: "basketball", label: "NBA", path: "basketball/nba"),
        .init(sport: "basketball", label: "WNBA", path: "basketball/wnba"),
        .init(sport: "basketball", label: "NCAAB", path: "basketball/mens-college-basketball", query: "&groups=50"),
        .init(sport: "hockey", label: "NHL", path: "hockey/nhl"),
        .init(sport: "baseball", label: "MLB", path: "baseball/mlb"),
        .init(sport: "soccer", label: "Premier League", path: "soccer/eng.1"),
        .init(sport: "soccer", label: "Champions League", path: "soccer/uefa.champions"),
        .init(sport: "soccer", label: "Europa League", path: "soccer/uefa.europa"),
        .init(sport: "soccer", label: "Conference League", path: "soccer/uefa.europa.conf"),
        .init(sport: "soccer", label: "La Liga", path: "soccer/esp.1"),
        .init(sport: "soccer", label: "Serie A", path: "soccer/ita.1"),
        .init(sport: "soccer", label: "Bundesliga", path: "soccer/ger.1"),
        .init(sport: "soccer", label: "Ligue 1", path: "soccer/fra.1"),
        .init(sport: "soccer", label: "MLS", path: "soccer/usa.1"),
        .init(sport: "soccer", label: "Liga MX", path: "soccer/mex.1"),
        .init(sport: "soccer", label: "Eredivisie", path: "soccer/ned.1"),
        .init(sport: "soccer", label: "Primeira Liga", path: "soccer/por.1"),
        .init(sport: "tennis", label: "ATP", path: "tennis/atp"),
        .init(sport: "tennis", label: "WTA", path: "tennis/wta"),
        .init(sport: "f1", label: "F1", path: "racing/f1"),
    ]

    /// All leagues for one US Eastern day. Returns the games and how many feeds failed.
    static func fetchDay(_ day: String) async -> ([P1Game], Int) {
        await withTaskGroup(of: ([P1Game], Bool).self) { group in
            for (order, league) in leagues.enumerated() {
                group.addTask { await fetch(day: day, league: league, order: order) }
            }
            var games: [P1Game] = []; var failed = 0
            for await (rows, ok) in group { games += rows; if !ok { failed += 1 } }
            var seen = Set<String>()
            return (games.filter { seen.insert($0.id).inserted }, failed)
        }
    }

    private static func fetch(day: String, league: P1BoardLeague, order: Int) async -> ([P1Game], Bool) {
        let compact = day.replacingOccurrences(of: "-", with: "")
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.path)/scoreboard?dates=\(compact)&limit=1000\(league.query)") else { return ([], false) }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ([], false) }
            let events = root["events"] as? [[String: Any]] ?? []
            var games: [P1Game] = []
            for event in events {
                if league.sport == "tennis" {
                    let slug = league.label == "ATP" ? "mens-singles" : "womens-singles"
                    let comps = (event["groupings"] as? [[String: Any]] ?? [])
                        .filter { (($0["grouping"] as? [String: Any])?["slug"] as? String) == slug }
                        .flatMap { $0["competitions"] as? [[String: Any]] ?? [] }
                    for c in comps {
                        if let g = game(competition: c, event: event, league: league, order: order, day: day) { games.append(g) }
                    }
                } else if league.sport == "f1" {
                    let race = (event["competitions"] as? [[String: Any]] ?? [])
                        .first { (($0["type"] as? [String: Any])?["abbreviation"] as? String) == "Race" }
                    if let race, let g = fieldGame(race: race, event: event, league: league, order: order, day: day) { games.append(g) }
                } else if let c = (event["competitions"] as? [[String: Any]])?.first {
                    if let g = game(competition: c, event: event, league: league, order: order, day: day) { games.append(g) }
                }
            }
            return (games, true)
        } catch { return ([], false) }
    }

    private static func parseDate(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: s) { return d }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd'T'HH:mmX"
        return f.date(from: s)
    }

    static func easternDay(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/New_York"); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func phase(_ status: [String: Any]?) -> (P1Game.Phase, String) {
        let type = status?["type"] as? [String: Any]
        let state = type?["state"] as? String ?? "pre"
        let name = (type?["name"] as? String ?? "").uppercased()
        let detail = type?["shortDetail"] as? String ?? ""
        if name.contains("POSTPONED") || name.contains("CANCELED") || name.contains("SUSPENDED") || name.contains("DELAYED") {
            return (.off, type?["description"] as? String ?? "Postponed")
        }
        switch state {
        case "in": return (.live, detail)
        case "post": return (.final, detail.isEmpty ? "Final" : detail)
        default: return (.pre, detail)
        }
    }

    private static func intScore(_ value: Any?) -> Int? {
        if let s = value as? String { return Int(s) }
        if let n = value as? NSNumber { return n.intValue }
        if let d = value as? [String: Any] { return intScore(d["value"] ?? d["displayValue"]) }
        return nil
    }

    private static func side(_ c: [String: Any], sport: String, opponent: [String: Any]?) -> P1GameSide? {
        let team = c["team"] as? [String: Any]
        let athlete = c["athlete"] as? [String: Any]
        guard let name = (team?["displayName"] ?? athlete?["displayName"]) as? String else { return nil }
        let short: String
        let code: String
        var score = intScore(c["score"])
        if let athlete {
            short = athlete["shortName"] as? String ?? name
            code = String(name.split(separator: " ").last ?? Substring(name))
            // Tennis carries sets in linescores, not a single score: count sets won.
            let mine = (c["linescores"] as? [[String: Any]] ?? []).compactMap { intScore($0["value"]) }
            let theirs = (opponent?["linescores"] as? [[String: Any]] ?? []).compactMap { intScore($0["value"]) }
            if !mine.isEmpty { score = zip(mine, theirs).filter { $0 > $1 }.count }
        } else {
            short = (sport == "soccer" ? team?["shortDisplayName"] : (team?["name"] ?? team?["shortDisplayName"])) as? String ?? name
            code = team?["abbreviation"] as? String ?? short
        }
        let records = c["records"] as? [[String: Any]]
        let record = (records?.first { ($0["type"] as? String) == "total" } ?? records?.first)?["summary"] as? String
        return P1GameSide(name: name, short: short, code: code.uppercased(),
                          logo: (team?["logo"] as? String) ?? ((team?["logos"] as? [[String: Any]])?.first?["href"] as? String)
                            ?? ((athlete?["flag"] as? [String: Any])?["href"] as? String),
                          record: record, score: score, winner: c["winner"] as? Bool ?? false,
                          teamID: team?["id"] as? String,
                          color: {
                              let main = (team?["color"] as? String)?.lowercased()
                              if let main, main != "000000", main != "ffffff" { return main }
                              return (team?["alternateColor"] as? String) ?? main
                          }())
    }

    /// One event from any ESPN feed (a team schedule, a scoreboard), not tied to a day.
    static func parseEvent(_ event: [String: Any], league: P1BoardLeague) -> P1Game? {
        guard let c = (event["competitions"] as? [[String: Any]])?.first else { return nil }
        return game(competition: c, event: event, league: league, order: 0, day: nil)
    }

    private static func game(competition c: [String: Any], event: [String: Any], league: P1BoardLeague, order: Int, day: String?) -> P1Game? {
        guard let id = (c["id"] ?? event["id"]) as? String,
              let date = parseDate(c["date"] ?? c["startDate"] ?? event["date"]), day == nil || easternDay(date) == day else { return nil }
        let competitors = c["competitors"] as? [[String: Any]] ?? []
        guard competitors.count == 2 else { return nil }
        let h = competitors.first { $0["homeAway"] as? String == "home" } ?? competitors[0]
        let a = competitors.first { $0["homeAway"] as? String == "away" } ?? competitors[1]
        guard let home = side(h, sport: league.sport, opponent: a), let away = side(a, sport: league.sport, opponent: h),
              ![home.name, away.name].contains(where: { ["tbd", "tba", "unknown"].contains($0.lowercased()) }) else { return nil }
        let (ph, detail) = phase((c["status"] ?? event["status"]) as? [String: Any])
        let venue = (c["venue"] as? [String: Any])?["fullName"] as? String
        let tv = ((c["broadcasts"] as? [[String: Any]])?.first?["names"] as? [String])?.first
        return P1Game(id: id, sport: league.sport, league: league.label, order: order, date: date, phase: ph, detail: detail,
                      home: home, away: away, note: [venue, tv].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                      isField: false, path: league.path)
    }

    private static func fieldGame(race: [String: Any], event: [String: Any], league: P1BoardLeague, order: Int, day: String) -> P1Game? {
        guard let id = (race["id"] ?? event["id"]) as? String,
              let date = parseDate(race["date"] ?? race["startDate"]), easternDay(date) == day else { return nil }
        let name = event["name"] as? String ?? "Formula 1"
        let (ph, detail) = phase((race["status"] ?? event["status"]) as? [String: Any])
        let side = P1GameSide(name: name, short: event["shortName"] as? String ?? name, code: "F1", logo: nil, record: nil, score: nil, winner: false)
        let circuit = (race["venue"] as? [String: Any])?["fullName"] as? String ?? ((event["circuit"] as? [String: Any])?["fullName"] as? String) ?? ""
        return P1Game(id: id, sport: "f1", league: league.label, order: order, date: date, phase: ph, detail: detail,
                      home: side, away: side, note: circuit, isField: true, path: league.path)
    }
}

@MainActor
final class P1ScoreboardStore: ObservableObject {
    @Published private(set) var days: [String: [P1Game]] = [:]
    @Published private(set) var loading: Set<String> = []
    @Published private(set) var failures: [String: Int] = [:]
    private var fetchedAt: [String: Date] = [:]

    func games(_ day: String) -> [P1Game] { days[day] ?? [] }

    func load(_ day: String, force: Bool = false) async {
        if !force, let at = fetchedAt[day], Date().timeIntervalSince(at) < 25 { return }
        if days[day] == nil { loading.insert(day) }
        let (games, failed) = await P1ScoreboardFeed.fetchDay(day)
        loading.remove(day)
        // A refresh that failed outright keeps the last good board.
        if games.isEmpty, failed > 0, !(days[day] ?? []).isEmpty { failures[day] = failed; return }
        for g in games {
            for s in [g.home, g.away] where !g.isField { if let logo = s.logo { TeamLogoStore.register(team: s.name, url: logo) } }
        }
        days[day] = games.sorted { ($0.order, $0.date) < ($1.order, $1.date) }
        failures[day] = failed
        fetchedAt[day] = Date()
    }

    /// Loads the shown day and today, then keeps them fresh: every 30 seconds
    /// while a game is live or about to start, every 5 minutes otherwise.
    func follow(day: String) async {
        let today = P1BookDays.key()
        while !Task.isCancelled {
            await load(day)
            if day != today { await load(today) }
            let watched = games(day) + (day == today ? [] : games(today))
            let busy = watched.contains {
                $0.phase == .live || ($0.phase == .pre && $0.date.timeIntervalSinceNow < 900 && $0.date.timeIntervalSinceNow > -3 * 3600)
            }
            do { try await Task.sleep(for: .seconds(busy ? 30 : 300)) } catch { return }
            fetchedAt.removeAll()
        }
    }
}

// MARK: Matching PICK1 calls to games

struct P1GameRow: Identifiable {
    let game: P1Game
    let pick: Pick?
    var id: String { game.id }
}

enum P1GameMatch {
    private static let aliases: [[String]] = [
        ["was", "wsh"], ["gs", "gsw"], ["ny", "nyk"], ["sa", "sas"], ["no", "nop"], ["pho", "phx"],
        ["uta", "utah", "uth"], ["nj", "njd"], ["tb", "tbl", "tam"], ["sj", "sjs"], ["la", "lak"], ["mon", "mtl"],
        ["chw", "cws"], ["kc", "kcr"], ["sd", "sdp"], ["sf", "sfg"], ["vgk", "veg", "lv"], ["cls", "cbj"], ["nas", "nsh"],
        ["lv", "lvr"], ["jax", "jac"], ["ari", "az"], ["oak", "ath"], ["wsh", "wsn"], ["cal", "cgy"],
    ]
    // Normalising a name folds diacritics and splits on punctuation, which is
    // slow enough that redoing it for every game x pick pair on every render
    // froze the home page. Each string is normalised once.
    private static var keys: [String: String] = [:]
    private static var codes: [String: String] = [:]
    private static func key(_ s: String) -> String {
        if let k = keys[s] { return k }
        let k = TeamLogoStore.normKey(s); keys[s] = k; return k
    }
    private static func codeKey(_ team: String, sport: String) -> String {
        let id = sport + "|" + team
        if let c = codes[id] { return c }
        let c = key(p1TeamCode(team, sport: sport)); codes[id] = c; return c
    }

    static func same(_ side: P1GameSide, _ team: String, sport: String) -> Bool {
        let t = key(team)
        guard !t.isEmpty else { return false }
        if t == key(side.name) || t == key(side.short) || t == key(side.code) { return true }
        let code = codeKey(team, sport: sport), theirs = key(side.code)
        if code == theirs { return true }
        if aliases.contains(where: { $0.contains(code) && $0.contains(theirs) }) { return true }
        if sport == "tennis" {
            return t.split(separator: " ").last == key(side.name).split(separator: " ").last
        }
        let full = key(side.name), short = key(side.short)
        // "Virginia" for "Virginia Cavaliers", "Patriots" for "New England Patriots".
        return (t.count >= 4 && (full.hasSuffix(" " + t) || full.hasPrefix(t + " "))) || (short.count >= 4 && t.hasSuffix(short))
    }

    private static func matches(_ game: P1Game, _ pick: Pick) -> Bool {
        guard pick.sport == game.sport else { return false }
        if let gid = pick.gameId, gid == game.id || gid.hasSuffix("-" + game.id) { return true }
        if game.isField {
            let a = key(pick.homeTeam), b = key(game.home.name)
            return !a.isEmpty && (a.contains(b) || b.contains(a) || a.split(separator: " ").contains { $0.count > 4 && b.contains($0) })
        }
        return (same(game.home, pick.homeTeam, sport: game.sport) && same(game.away, pick.awayTeam, sport: game.sport))
            || (same(game.home, pick.awayTeam, sport: game.sport) && same(game.away, pick.homeTeam, sport: game.sport))
    }

    /// ESPN's games for the day with PICK1's calls attached, plus a row for
    /// every published call ESPN does not list (KHL, a missing feed...).
    private static var cache: [String: (signature: Int, rows: [P1GameRow])] = [:]

    static func rows(games: [P1Game], picks: [Pick], scores: [LiveScore], day: String) -> [P1GameRow] {
        let dayPicks = picks.filter { $0.gameDate == day && P1_SPORTS.contains($0.sport) }
            .sorted { $0.probability > $1.probability }
        var hasher = Hasher()
        hasher.combine(games)
        for p in dayPicks { hasher.combine(p.id); hasher.combine(p.result); hasher.combine(p.gameId) }
        for s in scores where s.gameId.isEmpty == false { hasher.combine(s.gameId); hasher.combine(s.homeScore); hasher.combine(s.awayScore); hasher.combine(s.status) }
        let signature = hasher.finalize()
        if let hit = cache[day], hit.signature == signature { return hit.rows }
        let built = build(games: games, dayPicks: dayPicks, scores: scores)
        cache[day] = (signature, built)
        return built
    }

    /// Each pick as a row: on its ESPN game when the board for its day is
    /// loaded, on a game built from the pick otherwise.
    static func rowsFor(picks: [Pick], games: (String) -> [P1Game], scores: [LiveScore]) -> [P1GameRow] {
        var seen = Set<String>()
        return picks.compactMap { p in
            let row: P1GameRow
            if let g = games(p.gameDate).first(where: { matches($0, p) }) {
                row = P1GameRow(game: g, pick: p)
            } else {
                row = P1GameRow(game: synthesize(p, score: scores.first { $0.gameId == p.gameId }), pick: p)
            }
            return seen.insert(row.game.id).inserted ? row : nil
        }
    }

    /// PICK1's call on each game, if any, without adding pick-only rows.
    static func attach(games: [P1Game], picks: [Pick]) -> [P1GameRow] {
        let byDay = Dictionary(grouping: picks.filter { P1_SPORTS.contains($0.sport) }, by: \.gameDate)
        return games.map { g in
            let day = P1BookDays.key(g.date)
            let found = (byDay[day] ?? []).filter { matches(g, $0) }.max { $0.probability < $1.probability }
            return P1GameRow(game: g, pick: found)
        }
    }

    private static func build(games: [P1Game], dayPicks: [Pick], scores: [LiveScore]) -> [P1GameRow] {
        let bySport = Dictionary(grouping: dayPicks, by: \.sport)
        var used = Set<UUID>()
        var rows: [P1GameRow] = games.map { game in
            let found = (bySport[game.sport] ?? []).filter { !used.contains($0.id) && matches(game, $0) }
            found.forEach { used.insert($0.id) }
            return P1GameRow(game: game, pick: found.first)
        }
        for pick in dayPicks where !used.contains(pick.id) {
            used.insert(pick.id)
            rows.append(P1GameRow(game: synthesize(pick, score: scores.first { $0.gameId == pick.gameId }), pick: pick))
        }
        return rows
    }

    private static func synthesize(_ pick: Pick, score: LiveScore?) -> P1Game {
        var fresh = score
        if let s = score, s.isLive, let u = s.updatedAt, Date().timeIntervalSince(u) > 7200 { fresh = nil }
        let phase: P1Game.Phase = !pick.isPending || fresh?.isFinal == true ? .final : fresh?.isLive == true ? .live : .pre
        let hs = fresh?.homeScore ?? pick.homeScore, aws = fresh?.awayScore ?? pick.awayScore
        func side(_ name: String, logo: String?, score: Int?, other: Int?) -> P1GameSide {
            P1GameSide(name: name, short: teamShortName(name, sport: pick.sport), code: p1TeamCode(name, sport: pick.sport),
                       logo: logo, record: nil, score: score, winner: phase == .final && (score ?? 0) > (other ?? 0))
        }
        let isField = pick.sport == "f1" || pick.sport == "golf"
        let date = pick.scheduledStartDate ?? P1BookDays.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: pick.gameDateValue ?? Date()) ?? Date()
        return P1Game(id: "pick-" + pick.id.uuidString, sport: pick.sport, league: p1LeagueLabel(pick), order: 999, date: date,
                      phase: phase, detail: phase == .live ? (fresh?.quarter ?? "") : phase == .final ? "Final" : "",
                      home: side(isField ? pick.homeTeam : pick.homeTeam, logo: pick.homeLogo, score: hs, other: aws),
                      away: side(pick.awayTeam, logo: pick.awayLogo, score: aws, other: hs),
                      note: "", isField: isField)
    }
}

// MARK: Views

/// Text tabs with an underline under the active one.
struct P1SportTabs: View {
    let sports: [String]
    let active: String
    var onSelect: (String) -> Void
    @Namespace private var bar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(sports, id: \.self) { sport in
                    Button { withAnimation(reduceMotion ? nil : Pick1Springs.snappy) { onSelect(sport) } } label: {
                        VStack(spacing: 9) {
                            Text(v4Name(sport))
                                .font(.system(size: 16, weight: sport == active ? .bold : .semibold))
                                .foregroundStyle(sport == active ? Color.white : P1Board.secondary)
                            ZStack {
                                Capsule().fill(Color.clear).frame(height: 3)
                                if sport == active {
                                    Capsule().fill(Color.white).frame(height: 3).matchedGeometryEffect(id: "bar", in: bar)
                                }
                            }
                        }.fixedSize(horizontal: true, vertical: false)
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(sport == active ? .isSelected : [])
                }
            }.padding(.horizontal, 16)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(P1Board.pill).frame(height: 1) }
    }
}

/// Boxed day chips: weekday over the date number.
struct P1DayChips: View {
    let days: [String]
    @Binding var selected: String
    var liveDays: Set<String> = []
    private static let parser: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "America/New_York"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private func parts(_ day: String) -> (String, String) {
        guard let d = Self.parser.date(from: day) else { return ("", day) }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = Self.parser.timeZone
        f.dateFormat = "EEE"; let w = f.string(from: d)
        f.dateFormat = "d"; return (w, f.string(from: d))
    }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let (weekday, number) = parts(day)
                        let on = day == selected
                        Button { selected = day } label: {
                            VStack(spacing: 3) {
                                Text(day == P1BookDays.key() ? "Today" : weekday).font(.system(size: 12, weight: .medium))
                                Text(number).font(.system(size: 19, weight: .bold)).monospacedDigit()
                            }
                            .foregroundStyle(on ? Color.white : Color.white.opacity(0.85))
                            .frame(width: 56, height: 58)
                            .background(RoundedRectangle(cornerRadius: 12).fill(on ? P1Board.pill : Color.black))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? Color(hex: "#5A5A5A") : Color(hex: "#363636"), lineWidth: 1))
                            .overlay(alignment: .topTrailing) {
                                if liveDays.contains(day) { Circle().fill(Color.p1Red).frame(width: 6, height: 6).padding(7) }
                            }
                        }.buttonStyle(PressableButtonStyle()).id(day)
                            .accessibilityLabel(P1BookDays.label(day))
                    }
                }.padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
    }
}

/// Centered date chip between hairlines: "Today", "Sun, Oct 25".
struct P1DateDivider: View {
    let day: String
    private var label: String {
        let cal = P1BookDays.calendar
        let now = Date()
        if day == P1BookDays.key(now) { return "Today" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), day == P1BookDays.key(y) { return "Yesterday" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), day == P1BookDays.key(t) { return "Tomorrow" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = cal.timeZone; f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: day) else { return day }
        f.dateFormat = "EEE, MMM d"; return f.string(from: d)
    }
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(P1Board.pill).frame(height: 1)
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color.black))
                .overlay(Capsule().strokeBorder(Color(hex: "#363636"), lineWidth: 1))
                .fixedSize()
            Rectangle().fill(P1Board.pill).frame(height: 1)
        }.padding(.horizontal, 16)
    }
}

struct P1GameListRow: View {
    let row: P1GameRow
    var locked = false
    var watching = false
    var onOpen: () -> Void = {}
    var onWatch: () -> Void = {}
    var onUnlock: () -> Void = {}

    private var game: P1Game { row.game }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        if game.isField {
                            teamLine(game.home, other: nil, single: true)
                        } else {
                            teamLine(game.away, other: game.home)
                            teamLine(game.home, other: game.away)
                        }
                    }
                    Rectangle().fill(P1Board.rule).frame(width: 1).padding(.horizontal, 14)
                    status.frame(width: 82, alignment: .leading)
                }
                .padding(.horizontal, 16).padding(.top, 15).padding(.bottom, 13)
                .contentShape(Rectangle())
            }.buttonStyle(PressableButtonStyle())
            P1DashedRule().padding(.horizontal, 16)
            footer.padding(.horizontal, 16).frame(minHeight: 42)
        }
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
        .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(watching ? Color.p1Lime.opacity(0.45) : P1Board.edge))
    }

    private var showsScore: Bool { game.phase == .live || game.phase == .final }

    private func picked(_ side: P1GameSide) -> Bool {
        guard let pick = row.pick, !locked, !game.isField else { return false }
        return P1GameMatch.same(side, pick.pick, sport: game.sport)
    }

    private func teamLine(_ side: P1GameSide, other: P1GameSide?, single: Bool = false) -> some View {
        let lost = game.phase == .final && other != nil && !side.winner && (other?.winner == true || (side.score ?? 0) < (other?.score ?? 0))
        return HStack(spacing: 10) {
            crest(side)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(single ? side.name : side.short)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(lost ? P1Board.secondary : Color.white)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    if picked(side) {
                        Text("PICK1").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color.p1Ink)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.p1Lime))
                    }
                }
                if let record = side.record, !record.isEmpty {
                    Text(record).font(.system(size: 12)).foregroundStyle(P1Board.secondary).monospacedDigit()
                } else if single, !game.note.isEmpty {
                    Text(game.note).font(.system(size: 12)).foregroundStyle(P1Board.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if showsScore, let score = side.score, !single {
                Text("\(score)")
                    .font(.system(size: 22, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(lost ? P1Board.secondary : Color.white)
                    .p1ScoreFlash(String(score))
            }
        }
    }

    @ViewBuilder private func crest(_ side: P1GameSide) -> some View {
        Group {
            if game.isField {
                Image(systemName: game.sport == "f1" ? "flag.checkered" : "trophy.fill")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30).background(Circle().fill(P1Board.pill))
            } else if game.sport != "tennis", let logo = side.logo, let url = URL(string: logo) {
                CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
                    .frame(width: 30, height: 30)
            } else {
                TeamLogo(sport: game.sport, team: side.name, size: .small)
                    .scaleEffect(0.7).frame(width: 30, height: 30)
            }
        }.accessibilityHidden(true)
    }

    @ViewBuilder private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch game.phase {
            case .live:
                HStack(spacing: 5) { P1LivePulse(); Text("Live").foregroundStyle(Color.p1Red) }
                    .font(.system(size: 14, weight: .semibold))
                Text(game.detail).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.8)
            case .final:
                Text(game.detail.isEmpty ? "Final" : game.detail).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(P1Board.secondary).lineLimit(2).minimumScaleFactor(0.8)
            case .off:
                Text(game.detail).font(.system(size: 13, weight: .medium)).foregroundStyle(P1Board.secondary).lineLimit(2)
            case .pre:
                Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 13)).foregroundStyle(P1Board.secondary).lineLimit(1).minimumScaleFactor(0.8)
                Text(game.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).monospacedDigit()
            }
        }
    }

    /// Where the call stands while the game is on: leading, level or behind.
    private var liveState: (String, Color)? {
        guard game.phase == .live, let pick = row.pick, !game.isField,
              let hs = game.home.score, let aws = game.away.score else { return nil }
        let onHome = P1GameMatch.same(game.home, pick.pick, sport: game.sport)
        let onAway = P1GameMatch.same(game.away, pick.pick, sport: game.sport)
        guard onHome != onAway else { return nil }
        let diff = onHome ? hs - aws : aws - hs
        return diff > 0 ? ("leading", Color.p1Lime) : diff == 0 ? ("level", P1Board.secondary) : ("behind", Color.p1Red)
    }

    @ViewBuilder private var footer: some View {
        if let pick = row.pick, locked, pick.isPending {
            // Sells the call without giving it away: never the side, only
            // what is already true about it (live lead, confidence, payout).
            Button(action: onUnlock) {
                HStack(spacing: 7) {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Color.p1Lime)
                    if let state = liveState, state.0 == "leading" {
                        Text("PICK1's call is leading").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.p1Lime)
                    } else if game.phase == .live {
                        Text("PICK1 called this game").font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    } else {
                        Text("PICK1").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.p1Lime)
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.22)).frame(width: 58, height: 11)
                        Text("· \(Int(pick.probability.rounded()))%").font(.system(size: 13)).foregroundStyle(P1Board.secondary).monospacedDigit()
                        Text("· pays \(P1Odds.money(100 * (pick.decimalOdds - 1)))").font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 4)
                    Text("Unlock").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 12).frame(height: 28).background(Capsule().fill(Color.p1Lime))
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("PICK1 prediction locked. Unlock with Premium")
        } else if let pick = row.pick {
            HStack(spacing: 6) {
                Text("PICK1").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.p1Lime)
                Text(pick.shortDisplayPick).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Group {
                    Text("· \(Int(pick.probability.rounded()))%")
                    if let odds = pick.marketOdds, odds > 1 { Text(String(format: "· %.2f", odds)) }
                }.font(.system(size: 13)).foregroundStyle(P1Board.secondary).monospacedDigit().lineLimit(1)
                if let state = liveState {
                    Text("· " + state.0).font(.system(size: 13, weight: .semibold)).foregroundStyle(state.1)
                } else if !pick.isPending {
                    Text(pick.isWin ? "· Won" : pick.isLoss ? "· Lost" : "· Void")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(pick.isWin ? Color.p1Lime : P1Board.secondary)
                }
                Spacer(minLength: 4)
                Button(action: onWatch) {
                    Image(systemName: watching ? "eye.fill" : "eye")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(watching ? Color.p1Lime : P1Board.secondary)
                        .frame(width: 34, height: 34).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(watching ? "Remove from watchlist" : "Add to watchlist")
            }
        } else {
            HStack {
                Text(game.isField ? game.league : (game.note.isEmpty ? game.league : game.note))
                    .font(.system(size: 13)).foregroundStyle(P1Board.secondary).lineLimit(1)
                Spacer()
            }
        }
    }
}

/// The day's games grouped by league, live leagues and PICK1 leagues first.
struct P1AllGamesList: View {
    let rows: [P1GameRow]
    let isLocked: (Pick) -> Bool
    let isWatching: (Pick) -> Bool
    var onOpen: (P1GameRow) -> Void
    var onWatch: (Pick) -> Void
    var onUnlock: () -> Void
    /// Games a league shows before "Show all"; calls are always shown.
    var preview = 6
    @State private var expanded = Set<String>()

    private struct Group: Identifiable {
        let id: String
        let sport: String
        let rows: [P1GameRow]
    }
    private var groups: [Group] {
        Dictionary(grouping: rows, by: { $0.game.league }).map { league, rows in
            Group(id: league, sport: rows[0].game.sport, rows: rows.sorted {
                ($0.game.phase == .live ? 0 : 1, $0.game.date, $0.game.id) < ($1.game.phase == .live ? 0 : 1, $1.game.date, $1.game.id)
            })
        }.sorted {
            let a = ($0.rows.contains { $0.game.phase == .live } ? 0 : 1, $0.rows.contains { $0.pick != nil } ? 0 : 1, $0.rows[0].game.order, $0.id)
            let b = ($1.rows.contains { $0.game.phase == .live } ? 0 : 1, $1.rows.contains { $0.pick != nil } ? 0 : 1, $1.rows[0].game.order, $1.id)
            return a < b
        }
    }

    var body: some View {
        // One container, so the caller's .id(day) really replaces the list.
        VStack(alignment: .leading, spacing: 0) {
        ForEach(groups) { group in
            let open = expanded.contains(group.id)
            let shown = open ? group.rows : Array(group.rows.enumerated().filter { $0.offset < preview || $0.element.pick != nil }.map(\.element))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    LeagueLogo(leagueId: group.id, fallbackSymbol: "trophy.fill", swatch: V4.glow(group.sport), size: 22)
                    Text(group.id).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                    let calls = group.rows.filter { $0.pick != nil }.count
                    Text(calls > 0 ? "\(p1GamesCount(group.rows.count)) · \(calls) PICK1" : p1GamesCount(group.rows.count))
                        .font(.system(size: 12)).foregroundStyle(P1Board.secondary)
                }
                ForEach(shown) { row in
                    P1GameListRow(row: row,
                                  locked: row.pick.map(isLocked) ?? false,
                                  watching: row.pick.map(isWatching) ?? false,
                                  onOpen: { onOpen(row) },
                                  onWatch: { if let p = row.pick { onWatch(p) } },
                                  onUnlock: onUnlock)
                }
                if shown.count < group.rows.count {
                    Button { withAnimation(Pick1Springs.smooth) { _ = expanded.insert(group.id) } } label: {
                        P1BoardPill(title: "Show all \(group.rows.count) games", icon: "chevron.down", tint: .white)
                    }.buttonStyle(PressableButtonStyle())
                }
            }.padding(.horizontal, 16).padding(.bottom, 20)
        }
        }
    }
}

/// Horizontal rail of the day's unlocked PICK1 games, drawn from the ESPN
/// rows so crests and scores come from the same feed as the list below.
struct P1FeaturedGames: View {
    let rows: [P1GameRow]
    var onOpen: (P1GameRow) -> Void

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Featured events").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(rows) { row in
                            Button { onOpen(row) } label: { card(row) }
                                .buttonStyle(PressableButtonStyle())
                        }
                    }.padding(.horizontal, 16)
                }
            }
        }
    }

    private func card(_ row: P1GameRow) -> some View {
        let g = row.game
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if g.phase == .live { P1LivePulse() }
                Text(g.phase == .live ? "Live" : g.phase == .final ? "Final" : dayLabel(g.date))
                    .foregroundStyle(g.phase == .live ? Color.p1Red : P1Board.secondary)
                Spacer(minLength: 6)
                Text(g.phase == .live ? g.detail : g.phase == .pre ? g.date.formatted(date: .omitted, time: .shortened) : g.league)
                    .foregroundStyle(P1Board.secondary).lineLimit(1)
            }.font(.system(size: 13, weight: .medium))
            P1DashedRule()
            if g.isField {
                line(g.home, row: row, other: nil)
            } else {
                line(g.away, row: row, other: g.home)
                line(g.home, row: row, other: g.away)
            }
            if !(row.pick?.isPending ?? true), let p = row.pick {
                P1BoardPill(title: p.isWin ? "PICK1 won" : p.isLoss ? "PICK1 lost" : "Void",
                            icon: p.isWin ? "checkmark.seal.fill" : "xmark.circle",
                            tint: p.isWin ? Color.p1Lime : P1Board.secondary)
            }
        }
        .padding(15).frame(width: 214, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
        .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.autoupdatingCurrent
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func line(_ side: P1GameSide, row: P1GameRow, other: P1GameSide?) -> some View {
        let g = row.game
        let picked = row.pick.map { P1GameMatch.same(side, $0.pick, sport: g.sport) } ?? false
        let scored = (g.phase == .live || g.phase == .final) && side.score != nil && other != nil
        let lost = g.phase == .final && other != nil && !side.winner && (other?.winner == true || (side.score ?? 0) < (other?.score ?? 0))
        return HStack(spacing: 9) {
            Group {
                if g.isField {
                    Image(systemName: "flag.checkered").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 26, height: 26).background(Circle().fill(P1Board.pill))
                } else if g.sport != "tennis", let logo = side.logo, let url = URL(string: logo) {
                    CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
                        .frame(width: 26, height: 26)
                } else {
                    TeamLogo(sport: g.sport, team: side.name, size: .small).scaleEffect(0.6).frame(width: 26, height: 26)
                }
            }
            Text(g.isField ? side.short : (g.sport == "tennis" ? side.code : side.code))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(lost ? P1Board.secondary : Color.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            if picked {
                Text("PICK1").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color.p1Ink)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.p1Lime)).fixedSize()
            }
            Spacer(minLength: 4)
            if scored, let s = side.score {
                Text("\(s)").font(.system(size: 18, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(lost ? P1Board.secondary : Color.white).fixedSize()
            } else if picked, let p = row.pick {
                Text("\(Int(p.probability.rounded()))%").font(.system(size: 17)).foregroundStyle(Color.p1Lime)
                    .monospacedDigit().fixedSize()
            }
        }
    }
}
