// Pick1ScoresWidget.swift
// Home-screen scoreboard: today's games, live first, read straight from
// ESPN's public scoreboards in the widget process (no App Group needed),
// with a PICK1 mark on the games PICK1 analysed. The call itself stays in
// the app, so the widget never gives away a Premium pick. Tapping a game
// opens its page through pick1://game?key=...

import WidgetKit
import SwiftUI

private let slime = Color(red: 0.776, green: 1.0, blue: 0.204)
private let scard = Color(red: 0.11, green: 0.11, blue: 0.118)
private let sgray = Color(red: 0.557, green: 0.557, blue: 0.576)

struct ScoreGame: Identifiable, Hashable {
    let id: String
    let key: String
    let league: String
    let state: String
    let detail: String
    let date: Date
    let homeCode: String
    let awayCode: String
    let homeScore: String
    let awayScore: String
    var homeLogo: Data?
    var awayLogo: Data?
    var homeLogoURL: String? = nil
    var awayLogoURL: String? = nil
    var pick1 = false
}

struct ScoresEntry: TimelineEntry {
    let date: Date
    let games: [ScoreGame]
}

private enum ScoresFetcher {
    static let leagues: [(path: String, label: String)] = [
        ("football/nfl", "NFL"), ("basketball/nba", "NBA"), ("hockey/nhl", "NHL"), ("baseball/mlb", "MLB"),
        ("soccer/eng.1", "Premier League"), ("soccer/uefa.champions", "Champions League"),
        ("football/college-football", "NCAAF"), ("basketball/wnba", "WNBA"),
    ]
    static let anon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxnbmphd25na2lhbWxuZ2NmZnJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczNzE5MTIsImV4cCI6MjA5Mjk0NzkxMn0.JgIspzgxL3YaMuq_I5gdvh67AJN09kimJSOnM_uJaD4"

    static var etDay: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: Date())
    }

    static func games(limit: Int) async -> [ScoreGame] {
        let day = etDay
        var all: [ScoreGame] = []
        await withTaskGroup(of: [ScoreGame].self) { group in
            for league in leagues { group.addTask { await fetch(league.path, label: league.label, day: day) } }
            for await rows in group { all += rows }
        }
        let called = await pickTeams(day: day)
        all = all.map { g in
            var g = g
            g.pick1 = called.contains { $0.contains(g.homeCode.lowercased()) || $0.contains(g.awayCode.lowercased()) }
            return g
        }
        // Live first, then what starts next, then finals; PICK1 games ahead within each.
        let rank: (ScoreGame) -> Int = { $0.state == "in" ? 0 : $0.state == "pre" ? 1 : 2 }
        let ordered = all.sorted {
            (rank($0), $0.pick1 ? 0 : 1, $0.date) < (rank($1), $1.pick1 ? 0 : 1, $1.date)
        }
        var picked = Array(ordered.prefix(limit))
        for i in picked.indices {
            picked[i].homeLogo = await logo(picked[i].homeLogoURL)
            picked[i].awayLogo = await logo(picked[i].awayLogoURL)
        }
        return picked
    }

    private static func fetch(_ path: String, label: String, day: String) async -> [ScoreGame] {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(path)/scoreboard?dates=\(day.replacingOccurrences(of: "-", with: ""))") else { return [] }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let iso = ISO8601DateFormatter()
        let minutes = DateFormatter(); minutes.locale = Locale(identifier: "en_US_POSIX"); minutes.dateFormat = "yyyy-MM-dd'T'HH:mmX"
        return (root["events"] as? [[String: Any]] ?? []).compactMap { e in
            guard let id = e["id"] as? String, let ds = e["date"] as? String,
                  let date = iso.date(from: ds) ?? minutes.date(from: ds),
                  let c = (e["competitions"] as? [[String: Any]])?.first,
                  let cs = c["competitors"] as? [[String: Any]],
                  let h = cs.first(where: { $0["homeAway"] as? String == "home" }),
                  let a = cs.first(where: { $0["homeAway"] as? String == "away" }) else { return nil }
            let type = (e["status"] as? [String: Any])?["type"] as? [String: Any]
            func team(_ x: [String: Any]) -> [String: Any] { x["team"] as? [String: Any] ?? [:] }
            return ScoreGame(id: id, key: "espn|\(path)|\(id)|\(day)", league: label,
                             state: type?["state"] as? String ?? "pre", detail: type?["shortDetail"] as? String ?? "",
                             date: date,
                             homeCode: team(h)["abbreviation"] as? String ?? "", awayCode: team(a)["abbreviation"] as? String ?? "",
                             homeScore: h["score"] as? String ?? "", awayScore: a["score"] as? String ?? "",
                             homeLogo: nil, awayLogo: nil,
                             homeLogoURL: team(h)["logo"] as? String, awayLogoURL: team(a)["logo"] as? String)
        }
    }

    /// Team names on today's published calls, lowercased, to mark PICK1 games.
    private static func pickTeams(day: String) async -> [String] {
        var comps = URLComponents(string: "https://lgnjawngkiamlngcffrk.supabase.co/rest/v1/picks")!
        comps.queryItems = [.init(name: "select", value: "home_team,away_team"), .init(name: "game_date", value: "eq.\(day)")]
        guard let url = comps.url else { return [] }
        var req = URLRequest(url: url)
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return rows.map { "\($0["home_team"] as? String ?? "") \($0["away_team"] as? String ?? "")".lowercased() }
    }

    /// Widgets cannot load remote images at render time: fetch and shrink now.
    private static func logo(_ s: String?) async -> Data? {
        guard let s, let url = URL(string: s), let (data, _) = try? await URLSession.shared.data(from: url),
              let img = UIImage(data: data) else { return nil }
        let side: CGFloat = 48
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2; fmt.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: fmt).image { _ in
            let r = min(side / max(img.size.width, 1), side / max(img.size.height, 1))
            let size = CGSize(width: img.size.width * r, height: img.size.height * r)
            img.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }.pngData()
    }
}

struct ScoresProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScoresEntry { ScoresEntry(date: Date(), games: []) }
    func getSnapshot(in context: Context, completion: @escaping (ScoresEntry) -> Void) {
        Task { completion(ScoresEntry(date: Date(), games: await ScoresFetcher.games(limit: limit(context)))) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoresEntry>) -> Void) {
        Task {
            let games = await ScoresFetcher.games(limit: limit(context))
            // Every 10 minutes while something is live, otherwise every 30.
            let live = games.contains { $0.state == "in" }
            let next = Date().addingTimeInterval(live ? 600 : 1800)
            completion(Timeline(entries: [ScoresEntry(date: Date(), games: games)], policy: .after(next)))
        }
    }
    private func limit(_ context: Context) -> Int {
        switch context.family { case .systemSmall: 1; case .systemLarge: 6; default: 3 }
    }
}

struct ScoresWidgetView: View {
    let entry: ScoresEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
            HStack {
                Text("PICK1").font(.system(size: 11, weight: .heavy)).foregroundStyle(slime)
                Text("Scores").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                if entry.games.contains(where: { $0.state == "in" }) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("LIVE").font(.system(size: 9, weight: .heavy)).foregroundStyle(.red)
                }
            }
            if entry.games.isEmpty {
                Spacer()
                Text("No games today").font(.system(size: 13, weight: .semibold)).foregroundStyle(sgray)
                Spacer()
            } else {
                ForEach(entry.games) { g in
                    Link(destination: URL(string: "pick1://game?key=\(g.key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")")!) {
                        row(g)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) { Color.black }
    }

    private func row(_ g: ScoreGame) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                team(g.awayCode, g.awayLogo, g.awayScore, g)
                team(g.homeCode, g.homeLogo, g.homeScore, g)
            }
            if family != .systemSmall {
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
                VStack(alignment: .leading, spacing: 2) {
                    if g.state == "in" {
                        Text("Live").font(.system(size: 11, weight: .bold)).foregroundStyle(.red)
                        Text(g.detail).font(.system(size: 10)).foregroundStyle(.white).lineLimit(1)
                    } else if g.state == "post" {
                        Text(g.detail.isEmpty ? "Final" : g.detail).font(.system(size: 11, weight: .semibold)).foregroundStyle(sgray)
                    } else {
                        Text(g.date, style: .time).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        Text(g.league).font(.system(size: 9)).foregroundStyle(sgray).lineLimit(1)
                    }
                    if g.pick1 {
                        Text("PICK1").font(.system(size: 8, weight: .heavy)).foregroundStyle(.black)
                            .padding(.horizontal, 4).padding(.vertical, 1).background(RoundedRectangle(cornerRadius: 3).fill(slime))
                    }
                }.frame(width: 74, alignment: .leading)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(scard))
    }

    private func team(_ code: String, _ logo: Data?, _ score: String, _ g: ScoreGame) -> some View {
        HStack(spacing: 6) {
            if let logo, let ui = UIImage(data: logo) {
                Image(uiImage: ui).resizable().scaledToFit().frame(width: 16, height: 16)
            } else {
                Circle().fill(Color.white.opacity(0.15)).frame(width: 16, height: 16)
            }
            Text(code).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Spacer(minLength: 2)
            if g.state != "pre" {
                Text(score).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).monospacedDigit()
            }
        }
    }
}

struct Pick1ScoresWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Pick1ScoresWidget", provider: ScoresProvider()) { entry in
            ScoresWidgetView(entry: entry)
        }
        .configurationDisplayName("PICK1 Scores")
        .description("Today's games with live scores. PICK1 marks the games it analysed.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
