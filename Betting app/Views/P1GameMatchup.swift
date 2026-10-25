import SwiftUI
import Charts

// MARK: Game page depth
// The rest of ESPN's game summary: the live win-probability curve, the
// pre-game matchup (series, form, standings, injuries) and the player box
// score. Parsed alongside P1GameSummary, drawn as cards on the game page.

nonisolated struct P1GameExtras: Sendable {
    struct FormGame: Sendable, Identifiable {
        let id: String
        let result: String
        let opponent: String
        let opponentLogo: String?
        let score: String
        let atVs: String
    }
    struct Injury: Sendable, Identifiable {
        let id: String
        let name: String
        let position: String
        let status: String
        let detail: String
        let headshot: String?
    }
    struct Standing: Sendable, Identifiable {
        let id: String
        let teamID: String
        let name: String
        let record: String
    }
    struct StandingGroup: Sendable, Identifiable {
        let id: String
        let title: String
        let rows: [Standing]
    }
    struct BoxGroup: Sendable, Identifiable {
        let id: String
        let title: String
        let labels: [String]
        let rows: [BoxRow]
    }
    struct BoxRow: Sendable, Identifiable {
        let id: String
        let name: String
        let starter: Bool
        let stats: [String]
    }

    var homeID = ""
    var awayID = ""
    /// Home team's chance of winning after each play, 0 to 100.
    var homeWin: [Double] = []
    /// ESPN's own pre-game projection for each side, when it publishes one.
    var predictorHome: Double?
    var predictorAway: Double?
    var series: String?
    var awayForm: [FormGame] = []
    var homeForm: [FormGame] = []
    var awayInjuries: [Injury] = []
    var homeInjuries: [Injury] = []
    var standings: [StandingGroup] = []
    var awayBox: [BoxGroup] = []
    var homeBox: [BoxGroup] = []
    /// The market's spread, total and moneyline for the game.
    var lines: P1GameLines?

    var hasMatchup: Bool {
        series != nil || !awayForm.isEmpty || !homeForm.isEmpty || !standings.isEmpty
            || !awayInjuries.isEmpty || !homeInjuries.isEmpty || predictorHome != nil
    }

    static func parse(_ d: [String: Any]) -> P1GameExtras {
        var x = P1GameExtras()
        let comp = ((d["header"] as? [String: Any])?["competitions"] as? [[String: Any]])?.first
        for c in comp?["competitors"] as? [[String: Any]] ?? [] {
            let id = (c["team"] as? [String: Any])?["id"] as? String ?? ""
            if c["homeAway"] as? String == "home" { x.homeID = id } else { x.awayID = id }
        }

        // Win probability: one point per play. Thinned to about 160 points so
        // the chart stays light on a 500-play basketball game.
        let wp = (d["winprobability"] as? [[String: Any]] ?? []).compactMap { ($0["homeWinPercentage"] as? NSNumber)?.doubleValue }
        if wp.count > 1 {
            let step = max(1, wp.count / 160)
            var thinned = stride(from: 0, to: wp.count, by: step).map { wp[$0] * 100 }
            if let last = wp.last, (wp.count - 1) % step != 0 { thinned.append(last * 100) }
            x.homeWin = thinned
        }
        x.lines = P1GameLines.parse(d)
        if let p = d["predictor"] as? [String: Any] {
            x.predictorHome = ((p["homeTeam"] as? [String: Any])?["gameProjection"] as? String).flatMap(Double.init)
            x.predictorAway = ((p["awayTeam"] as? [String: Any])?["gameProjection"] as? String).flatMap(Double.init)
        }

        if let s = (d["seasonseries"] as? [[String: Any]])?.first, let summary = s["summary"] as? String, !summary.isEmpty {
            x.series = summary
        }

        for block in d["lastFiveGames"] as? [[String: Any]] ?? [] {
            let teamID = (block["team"] as? [String: Any])?["id"] as? String ?? ""
            let games = (block["events"] as? [[String: Any]] ?? []).prefix(5).compactMap { e -> FormGame? in
                guard let id = e["id"] as? String, let result = e["gameResult"] as? String else { return nil }
                let opp = e["opponent"] as? [String: Any]
                return FormGame(id: id, result: result, opponent: opp?["abbreviation"] as? String ?? "",
                                opponentLogo: e["opponentLogo"] as? String, score: e["score"] as? String ?? "",
                                atVs: e["atVs"] as? String ?? "")
            }
            if teamID == x.homeID { x.homeForm = Array(games) } else if teamID == x.awayID { x.awayForm = Array(games) }
        }

        for block in d["injuries"] as? [[String: Any]] ?? [] {
            let teamID = (block["team"] as? [String: Any])?["id"] as? String ?? ""
            let list = (block["injuries"] as? [[String: Any]] ?? []).prefix(8).compactMap { i -> Injury? in
                guard let a = i["athlete"] as? [String: Any], let name = a["shortName"] as? String ?? a["displayName"] as? String else { return nil }
                let details = i["details"] as? [String: Any]
                return Injury(id: (a["id"] as? String) ?? name, name: name,
                              position: ((a["position"] as? [String: Any])?["abbreviation"] as? String) ?? "",
                              status: i["status"] as? String ?? "",
                              detail: [details?["type"] as? String, details?["detail"] as? String].compactMap { $0 }.joined(separator: " · "),
                              headshot: (a["headshot"] as? [String: Any])?["href"] as? String)
            }
            if teamID == x.homeID { x.homeInjuries = Array(list) } else if teamID == x.awayID { x.awayInjuries = Array(list) }
        }

        let groups = ((d["standings"] as? [String: Any])?["groups"] as? [[String: Any]]) ?? []
        for (gi, g) in groups.enumerated() {
            let entries = ((g["standings"] as? [String: Any])?["entries"] as? [[String: Any]]) ?? []
            let rows = entries.enumerated().map { i, e -> Standing in
                let stats = e["stats"] as? [[String: Any]] ?? []
                func stat(_ n: String) -> String? { stats.first { $0["name"] as? String == n }?["displayValue"] as? String }
                let record = stat("overall") ?? [stat("wins"), stat("losses")].compactMap { $0 }.joined(separator: "-")
                return Standing(id: "\(gi)-\(i)", teamID: e["id"] as? String ?? "", name: e["team"] as? String ?? "", record: record)
            }
            if !rows.isEmpty {
                let title = (g["header"] as? String) ?? "Standings"
                x.standings.append(StandingGroup(id: "\(gi)", title: title, rows: rows))
            }
        }

        let players = ((d["boxscore"] as? [String: Any])?["players"] as? [[String: Any]]) ?? []
        for team in players {
            let teamID = (team["team"] as? [String: Any])?["id"] as? String ?? ""
            let tables = (team["statistics"] as? [[String: Any]] ?? []).enumerated().compactMap { ti, s -> BoxGroup? in
                let labels = (s["labels"] as? [String]) ?? (s["names"] as? [String]) ?? []
                let rows = (s["athletes"] as? [[String: Any]] ?? []).compactMap { a -> BoxRow? in
                    guard (a["didNotPlay"] as? Bool) != true, let stats = a["stats"] as? [String], !stats.isEmpty,
                          let athlete = a["athlete"] as? [String: Any] else { return nil }
                    let name = athlete["shortName"] as? String ?? athlete["displayName"] as? String ?? ""
                    return BoxRow(id: (athlete["id"] as? String) ?? name, name: name, starter: a["starter"] as? Bool ?? false, stats: stats)
                }
                guard !labels.isEmpty, !rows.isEmpty else { return nil }
                let title = (s["text"] as? String) ?? (s["name"] as? String)?.capitalized ?? "Players"
                return BoxGroup(id: "\(ti)", title: title, labels: labels, rows: Array(rows.prefix(15)))
            }
            if teamID == x.homeID { x.homeBox = tables } else if teamID == x.awayID { x.awayBox = tables }
        }
        return x
    }
}

// MARK: Win probability

struct P1WinProbabilityCard: View {
    let game: P1Game
    let extras: P1GameExtras
    let pick: Pick?
    let locked: Bool
    var homeColor: Color
    var awayColor: Color

    private struct Point: Identifiable { let id: Int; let value: Double }

    /// The side the curve is drawn for: PICK1's side when there is an unlocked
    /// call, the home team otherwise.
    private var followsHome: Bool {
        guard let pick, !locked else { return true }
        return !P1GameMatch.same(game.away, pick.pick, sport: game.sport)
    }
    private var side: P1GameSide { followsHome ? game.home : game.away }
    private var points: [Point] {
        extras.homeWin.enumerated().map { Point(id: $0.offset, value: followsHome ? $0.element : 100 - $0.element) }
    }
    private var pickLine: Double? {
        guard let pick, !locked, !game.isField else { return nil }
        return pick.probability
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Win probability").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Spacer()
                if let last = points.last {
                    Text("\(side.code) \(Int(last.value.rounded()))%")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).monospacedDigit()
                }
            }
            Chart {
                RuleMark(y: .value("Even", 50))
                    .foregroundStyle(P1Board.rule)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if let pickLine {
                    RuleMark(y: .value("PICK1", pickLine))
                        .foregroundStyle(Color.p1Lime.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("PICK1 \(Int(pickLine.rounded()))%").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.p1Lime)
                        }
                }
                ForEach(points) { p in
                    AreaMark(x: .value("Play", p.id), yStart: .value("Base", 0), yEnd: .value("Win", p.value))
                        .foregroundStyle(LinearGradient(colors: [(followsHome ? homeColor : awayColor).opacity(0.35), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Play", p.id), y: .value("Win", p.value))
                        .foregroundStyle(followsHome ? homeColor : awayColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.2))
                        .interpolationMethod(.monotone)
                }
                if let last = points.last {
                    PointMark(x: .value("Play", last.id), y: .value("Win", last.value))
                        .foregroundStyle(.white).symbolSize(36)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { v in
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%").font(.system(size: 10)).foregroundStyle(P1Board.secondary) }
                }
            }
            .frame(height: 150)
            .accessibilityLabel("\(side.code) win probability chart, now \(Int((points.last?.value ?? 50).rounded())) percent")
            HStack {
                Text("Start").font(.system(size: 11)).foregroundStyle(P1Board.secondary)
                Spacer()
                Text(game.phase == .final ? "Final" : "Now").font(.system(size: 11)).foregroundStyle(P1Board.secondary)
            }
            Text("Live win probability from ESPN. The dashed lime line is PICK1's pre-game call.")
                .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }
}

// MARK: Matchup

struct P1MatchupCards: View {
    let game: P1Game
    let extras: P1GameExtras
    let pick: Pick?
    let locked: Bool

    var body: some View {
        VStack(spacing: 14) {
            if let home = extras.predictorHome, let away = extras.predictorAway { predictor(home: home, away: away) }
            if let series = extras.series { card { titled("Season series") { Text(series).font(.system(size: 15)).foregroundStyle(.white) } } }
            if !extras.awayForm.isEmpty || !extras.homeForm.isEmpty { formCard }
            ForEach(relevantStandings) { group in standingsCard(group) }
            if !extras.awayInjuries.isEmpty || !extras.homeInjuries.isEmpty { injuriesCard }
            if !extras.hasMatchup {
                card { titled("Matchup") {
                    Text("ESPN has not published matchup data for this game yet.").font(.system(size: 14)).foregroundStyle(P1Board.secondary)
                } }
            }
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }
    private func titled<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            content()
        }
    }
    private func crest(_ side: P1GameSide, size: CGFloat = 22) -> some View {
        Group {
            if let logo = side.logo, let url = URL(string: logo), game.sport != "tennis" {
                CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
            } else {
                TeamLogo(sport: game.sport, team: side.name, size: .small).scaleEffect(size / 44)
            }
        }.frame(width: size, height: size)
    }

    /// ESPN's projection next to PICK1's call: two independent models, side by side.
    private func predictor(home: Double, away: Double) -> some View {
        card {
            titled("Model check") {
                VStack(spacing: 10) {
                    bar(label: "ESPN projection", away: away, home: home)
                    if let pick, !locked, !game.isField {
                        let onHome = P1GameMatch.same(game.home, pick.pick, sport: game.sport)
                        let p = pick.probability
                        bar(label: "PICK1", away: onHome ? 100 - p : p, home: onHome ? p : 100 - p, lime: true)
                    }
                }
                Text("Two independent models. When they agree, the call is stronger; when they split, PICK1 explains why in the analysis.")
                    .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
            }
        }
    }

    private func bar(label: String, away: Double, home: Double, lime: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(game.away.code) \(Int(away.rounded()))%").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Spacer()
                Text(label).font(.system(size: 12)).foregroundStyle(lime ? Color.p1Lime : P1Board.secondary)
                Spacer()
                Text("\(Int(home.rounded()))% \(game.home.code)").font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }.foregroundStyle(.white)
            GeometryReader { geo in
                HStack(spacing: 3) {
                    Capsule().fill(away >= home ? (lime ? Color.p1Lime : Color.white) : P1Board.rule)
                        .frame(width: max(6, (geo.size.width - 3) * away / max(1, away + home)))
                    Capsule().fill(home > away ? (lime ? Color.p1Lime : Color.white) : P1Board.rule)
                }
            }.frame(height: 6)
        }
    }

    private var formCard: some View {
        card {
            titled("Last 5 games") {
                VStack(spacing: 14) {
                    formRow(game.away, extras.awayForm)
                    Rectangle().fill(P1Board.pill).frame(height: 1)
                    formRow(game.home, extras.homeForm)
                }
            }
        }
    }

    private func formRow(_ side: P1GameSide, _ games: [P1GameExtras.FormGame]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) { crest(side, size: 26); Text(side.code).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white) }
                .frame(width: 44)
            if games.isEmpty {
                Text("No recent games").font(.system(size: 13)).foregroundStyle(P1Board.secondary).padding(.top, 6)
            }
            ForEach(games) { g in
                VStack(spacing: 4) {
                    Text(g.result).font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(g.result == "W" ? Color.black : .white)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 8).fill(g.result == "W" ? Color.p1Lime : g.result == "L" ? P1Board.pill : P1Board.rule))
                    Text((g.atVs == "@" ? "@" : "") + g.opponent).font(.system(size: 10, weight: .medium)).foregroundStyle(P1Board.secondary).lineLimit(1)
                    Text(g.score).font(.system(size: 10)).foregroundStyle(P1Board.secondary).lineLimit(1).minimumScaleFactor(0.7)
                }.frame(maxWidth: .infinity)
            }
        }
    }

    /// Only the groups that hold one of the two teams.
    private var relevantStandings: [P1GameExtras.StandingGroup] {
        extras.standings.filter { g in g.rows.contains { $0.teamID == extras.homeID || $0.teamID == extras.awayID } }
    }

    private func standingsCard(_ group: P1GameExtras.StandingGroup) -> some View {
        card {
            titled(group.title) {
                VStack(spacing: 0) {
                    ForEach(Array(group.rows.enumerated()), id: \.element.id) { i, row in
                        let mine = row.teamID == extras.homeID || row.teamID == extras.awayID
                        HStack {
                            Text("\(i + 1)").font(.system(size: 13)).foregroundStyle(P1Board.secondary).frame(width: 22, alignment: .leading)
                            Text(row.name).font(.system(size: 15, weight: mine ? .bold : .regular))
                                .foregroundStyle(mine ? Color.white : Color.white.opacity(0.75))
                            Spacer()
                            Text(row.record).font(.system(size: 15, weight: mine ? .bold : .regular)).monospacedDigit()
                                .foregroundStyle(mine ? Color.white : P1Board.secondary)
                        }
                        .padding(.vertical, 9).padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(mine ? P1Board.pill : .clear))
                    }
                }
            }
        }
    }

    private var injuriesCard: some View {
        card {
            titled("Injuries") {
                VStack(alignment: .leading, spacing: 14) {
                    injuryList(game.away, extras.awayInjuries)
                    Rectangle().fill(P1Board.pill).frame(height: 1)
                    injuryList(game.home, extras.homeInjuries)
                }
            }
        }
    }

    private func injuryList(_ side: P1GameSide, _ list: [P1GameExtras.Injury]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { crest(side); Text(side.code).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white) }
            if list.isEmpty {
                Text("No reported injuries").font(.system(size: 13)).foregroundStyle(P1Board.secondary)
            }
            ForEach(list) { injury in
                HStack(spacing: 10) {
                    Group {
                        if let h = injury.headshot, let url = URL(string: h) {
                            CachedImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
                        } else { Image(systemName: "person.fill").font(.system(size: 12)).foregroundStyle(P1Board.secondary) }
                    }.frame(width: 30, height: 30).background(Circle().fill(P1Board.pill)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(injury.name + (injury.position.isEmpty ? "" : " · " + injury.position))
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        if !injury.detail.isEmpty { Text(injury.detail).font(.system(size: 12)).foregroundStyle(P1Board.secondary) }
                    }
                    Spacer()
                    Text(injury.status).font(.system(size: 12, weight: .bold))
                        .foregroundStyle(injury.status.lowercased().contains("out") ? Color.p1Red : Color(hex: "#FFB020"))
                }
            }
        }
    }
}

// MARK: Box score

struct P1BoxScoreCard: View {
    let game: P1Game
    let extras: P1GameExtras
    @State private var showHome = false

    private var groups: [P1GameExtras.BoxGroup] { showHome ? extras.homeBox : extras.awayBox }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Box score").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    ForEach([false, true], id: \.self) { home in
                        let side = home ? game.home : game.away
                        Button { withAnimation(Pick1Springs.snappy) { showHome = home } } label: {
                            Text(side.code).font(.system(size: 13, weight: .bold))
                                .foregroundStyle(showHome == home ? Color.black : .white)
                                .padding(.horizontal, 14).frame(height: 30)
                                .background(Capsule().fill(showHome == home ? Color.white : P1Board.pill))
                        }.buttonStyle(.plain)
                    }
                }
            }
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 8) {
                    if groups.count > 1 { Text(group.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(P1Board.secondary) }
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Player").font(.system(size: 11, weight: .semibold)).foregroundStyle(P1Board.secondary).frame(height: 26)
                            ForEach(group.rows) { row in
                                Text(row.name).font(.system(size: 13, weight: row.starter ? .semibold : .regular))
                                    .foregroundStyle(.white).lineLimit(1).frame(height: 30)
                            }
                        }.frame(width: 112, alignment: .leading)
                        ScrollView(.horizontal, showsIndicators: false) {
                            Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 0) {
                                GridRow {
                                    ForEach(Array(group.labels.enumerated()), id: \.offset) { _, l in
                                        Text(l).font(.system(size: 11, weight: .semibold)).foregroundStyle(P1Board.secondary).frame(height: 26)
                                    }
                                }
                                ForEach(group.rows) { row in
                                    GridRow {
                                        ForEach(Array(row.stats.enumerated()), id: \.offset) { _, v in
                                            Text(v).font(.system(size: 13)).foregroundStyle(.white).monospacedDigit().frame(height: 30)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }
}
