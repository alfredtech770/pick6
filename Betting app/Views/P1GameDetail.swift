import SwiftUI

// MARK: Game page
// One page per game, PICK1 call or not: a header washed in the two teams'
// colours, text tabs, and charcoal cards underneath. Stats, leaders and plays
// come from ESPN's public game summary; the PICK1 tab carries the call.

nonisolated struct P1GameSummary: Sendable {
    struct Leader: Sendable {
        let value: String
        let detail: String?
        let name: String
        let headshot: String?
    }
    struct LeaderRow: Sendable, Identifiable {
        let id: String
        let label: String
        let away: Leader?
        let home: Leader?
    }
    struct StatRow: Sendable, Identifiable {
        let id: String
        let label: String
        let away: String
        let home: String
    }
    struct Play: Sendable, Identifiable {
        let id: String
        let text: String
        let when: String
        let logo: String?
        let awayScore: Int?
        let homeScore: Int?
    }
    var awayColor: String?
    var homeColor: String?
    var awayLines: [String] = []
    var homeLines: [String] = []
    var leaders: [LeaderRow] = []
    var stats: [StatRow] = []
    var scoring: [Play] = []
    var latest: [Play] = []
    var venue: String?
    var city: String?
    var tv: String?
    var extras = P1GameExtras()

    static func load(path: String, event: String) async -> P1GameSummary? {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(path)/summary?event=\(event)") else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return parse(root)
        } catch { return nil }
    }

    private static func parse(_ d: [String: Any]) -> P1GameSummary {
        var s = P1GameSummary()
        let comp = ((d["header"] as? [String: Any])?["competitions"] as? [[String: Any]])?.first
        let competitors = comp?["competitors"] as? [[String: Any]] ?? []
        let home = competitors.first { $0["homeAway"] as? String == "home" }
        let away = competitors.first { $0["homeAway"] as? String == "away" }
        func team(_ c: [String: Any]?) -> [String: Any] { c?["team"] as? [String: Any] ?? [:] }
        func abbr(_ c: [String: Any]?) -> String { team(c)["abbreviation"] as? String ?? "" }
        func lines(_ c: [String: Any]?) -> [String] {
            (c?["linescores"] as? [[String: Any]] ?? []).map { ($0["displayValue"] as? String) ?? "\($0["value"] ?? "")" }
        }
        // Black or white primaries (Steelers, Raiders) wash out; use the alternate.
        func color(_ c: [String: Any]?) -> String? {
            let main = (team(c)["color"] as? String)?.lowercased()
            if let main, main != "000000", main != "ffffff" { return main }
            return (team(c)["alternateColor"] as? String) ?? main
        }
        s.awayColor = color(away)
        s.homeColor = color(home)
        s.awayLines = lines(away)
        s.homeLines = lines(home)

        var logos: [String: String] = [:]
        for c in [home, away] {
            let t = team(c)
            if let id = t["id"] as? String,
               let logo = (t["logo"] as? String) ?? ((t["logos"] as? [[String: Any]])?.first?["href"] as? String) {
                logos[id] = logo
            }
        }

        if let info = d["gameInfo"] as? [String: Any], let venue = info["venue"] as? [String: Any] {
            s.venue = venue["fullName"] as? String
            let address = venue["address"] as? [String: Any]
            s.city = [address?["city"] as? String, (address?["state"] ?? address?["country"]) as? String]
                .compactMap { $0 }.joined(separator: ", ")
        }
        if let b = (d["broadcasts"] as? [[String: Any]])?.first {
            s.tv = ((b["media"] as? [String: Any])?["shortName"] as? String) ?? (b["names"] as? [String])?.first
        }

        // Leaders: one block per team, categories paired by key.
        let leaderTeams = d["leaders"] as? [[String: Any]] ?? []
        func block(_ code: String) -> [[String: Any]] {
            (leaderTeams.first { ((($0["team"] as? [String: Any])?["abbreviation"] as? String) ?? "") == code }?["leaders"] as? [[String: Any]]) ?? []
        }
        func leader(_ cat: [String: Any]?) -> Leader? {
            guard let top = (cat?["leaders"] as? [[String: Any]])?.first,
                  let athlete = top["athlete"] as? [String: Any] else { return nil }
            let display = top["displayValue"] as? String ?? ""
            let number = (top["value"] as? NSNumber).map { n -> String in
                let v = n.doubleValue
                return v.rounded() == v ? Int(v).formatted() : String(format: "%.1f", v)
            } ?? display
            return Leader(value: number, detail: display == number || display.isEmpty ? nil : display,
                          name: athlete["shortName"] as? String ?? athlete["displayName"] as? String ?? "",
                          headshot: (athlete["headshot"] as? [String: Any])?["href"] as? String)
        }
        let awayBlock = block(abbr(away)), homeBlock = block(abbr(home))
        let keys = (awayBlock + homeBlock).compactMap { $0["name"] as? String }
        var seen = Set<String>()
        for key in keys where seen.insert(key).inserted {
            let a = awayBlock.first { $0["name"] as? String == key }
            let h = homeBlock.first { $0["name"] as? String == key }
            let label = ((a ?? h)?["shortDisplayName"] as? String) ?? ((a ?? h)?["displayName"] as? String) ?? key
            let row = LeaderRow(id: key, label: label.replacingOccurrences(of: " Yards", with: ""), away: leader(a), home: leader(h))
            if row.away != nil || row.home != nil { s.leaders.append(row) }
        }

        // Team stats, side by side.
        let boxTeams = (d["boxscore"] as? [String: Any])?["teams"] as? [[String: Any]] ?? []
        func stats(_ code: String) -> [[String: Any]] {
            (boxTeams.first { ((($0["team"] as? [String: Any])?["abbreviation"] as? String) ?? "") == code }?["statistics"] as? [[String: Any]]) ?? []
        }
        let awayStats = stats(abbr(away)), homeStats = stats(abbr(home))
        for stat in awayStats {
            guard let name = stat["name"] as? String, let av = stat["displayValue"] as? String, !av.isEmpty,
                  let hv = homeStats.first(where: { $0["name"] as? String == name })?["displayValue"] as? String, !hv.isEmpty else { continue }
            let label = (stat["label"] as? String ?? name)
            s.stats.append(StatRow(id: name, label: label.count <= 6 ? label.capitalized : label, away: av, home: hv))
            if s.stats.count == 10 { break }
        }

        // Plays: scoring first, then the latest few while it is on.
        func play(_ p: [String: Any], index: Int) -> Play? {
            guard let text = p["text"] as? String, !text.isEmpty else { return nil }
            let period = (p["period"] as? [String: Any])
            let periodLabel = (period?["displayValue"] as? String) ?? (period?["number"] as? Int).map { "P\($0)" } ?? ""
            let clock = ((p["clock"] as? [String: Any])?["displayValue"] as? String) ?? ""
            let teamID = (p["team"] as? [String: Any])?["id"] as? String
            let logo = ((p["team"] as? [String: Any])?["logo"] as? String) ?? teamID.flatMap { logos[$0] }
            return Play(id: (p["id"] as? String) ?? "\(index)", text: text,
                        when: [periodLabel, clock].filter { !$0.isEmpty }.joined(separator: " · "),
                        logo: logo, awayScore: p["awayScore"] as? Int, homeScore: p["homeScore"] as? Int)
        }
        let scoringPlays = d["scoringPlays"] as? [[String: Any]]
        let plays = d["plays"] as? [[String: Any]] ?? []
        let keyEvents = d["keyEvents"] as? [[String: Any]] ?? []
        let scoringSource = scoringPlays
            ?? (plays.isEmpty ? keyEvents.filter { ($0["scoringPlay"] as? Bool) == true } : plays.filter { ($0["scoringPlay"] as? Bool) == true })
        // Basketball logs every basket as a scoring play; keep the latest 60.
        s.scoring = Array(scoringSource.enumerated().compactMap { play($1, index: $0) }.suffix(60))
        let recent = plays.isEmpty ? keyEvents : plays
        s.latest = Array(recent.suffix(12).reversed().enumerated().compactMap { play($1, index: $0) })
        s.extras = P1GameExtras.parse(d)
        return s
    }
}

struct P1TextTabs: View {
    let items: [String]
    @Binding var active: String
    @Namespace private var bar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button { withAnimation(reduceMotion ? nil : Pick1Springs.snappy) { active = item } } label: {
                    VStack(spacing: 9) {
                        Text(item).font(.system(size: items.count > 4 ? 15 : 16, weight: item == active ? .bold : .semibold))
                            .foregroundStyle(item == active ? Color.white : P1Board.secondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        ZStack {
                            Capsule().fill(Color.clear).frame(height: 3)
                            if item == active {
                                Capsule().fill(Color.white).frame(width: 44, height: 3).matchedGeometryEffect(id: "bar", in: bar)
                            }
                        }
                    }.frame(maxWidth: .infinity).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(item == active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8).padding(.top, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(P1Board.pill).frame(height: 1) }
    }
}

struct P1GameDetail: View {
    let row: P1GameRow
    var locked = false
    var watching = false
    var onAnalysis: (Pick) -> Void = { _ in }
    var onWatch: (Pick) -> Void = { _ in }
    var onUnlock: () -> Void = {}
    /// What a team page opened from here needs (picks, locks, callbacks).
    var actions = P1GameActions()
    @State private var teamSheet: P1TeamRef?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var tracking = false
    @State private var followFeedback = 0
    private var following: Bool { favorites.followsTeam(game.home.name) || favorites.followsTeam(game.away.name) }
    @State private var summary: P1GameSummary?
    @State private var loaded = false
    @State private var tab = ""
    /// The colour header has scrolled away, so the bar needs its own ground.
    @State private var collapsed = false

    private var game: P1Game { row.game }
    private var pick: Pick? { row.pick }

    private var tabs: [String] {
        var t = ["PICK1"]
        // ESPN publishes no game summary for tennis or races.
        let summaries = game.path != nil && !game.isField && game.sport != "tennis"
        if summaries { t += ["Matchup", "Stats", "Plays"] }
        if summaries || pick != nil { t.append("Odds") }
        return t
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                VStack(spacing: 0) {
                    P1TextTabs(items: tabs, active: $tab)
                    VStack(spacing: 14) {
                        switch tab {
                        case "Matchup": matchupTab
                        case "Stats": stats
                        case "Plays": playsTab
                        case "Odds": P1OddsTab(game: game, pick: pick, locked: locked, extras: summary?.extras, offer: actions.offer, onUnlock: onUnlock)
                        default: pickTab
                        }
                    }.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
                }
                .background(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26).fill(Color.black))
                .offset(y: -22).padding(.bottom, -22)
            }
        }
        .onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 190 } action: { _, now in
            withAnimation(.easeOut(duration: 0.18)) { collapsed = now }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .top) { topBar }
        .preferredColorScheme(.dark)
        .onAppear { if tab.isEmpty { tab = pick == nil && tabs.contains("Stats") ? "Stats" : "PICK1" } }
        .task(id: game.id) { await follow() }
        .onAppear { tracking = LiveActivityManager.shared.isTracking(game) }
        .sheet(item: $teamSheet) { ref in
            NavigationStack { P1TeamPage(ref: ref, actions: actions) }
                .environmentObject(favorites)
        }
    }

    private func follow() async {
        guard let path = game.path, !game.isField, game.sport != "tennis", !game.id.hasPrefix("pick-") else { loaded = true; return }
        while !Task.isCancelled {
            if let s = await P1GameSummary.load(path: path, event: game.id) { summary = s }
            loaded = true
            guard game.phase == .live else { return }
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
        }
    }

    // MARK: Header

    private func tint(_ hex: String?, fallback: Color) -> Color {
        guard let hex, hex.count == 6, hex.lowercased() != "000000", hex.lowercased() != "ffffff" else { return fallback }
        return Color(hex: "#" + hex)
    }

    private var header: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [tint(summary?.awayColor, fallback: P1Board.pill), tint(summary?.homeColor, fallback: Color(hex: "#1C1C1E"))],
                           startPoint: .leading, endPoint: .trailing)
                .opacity(0.9)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                .animation(.easeOut(duration: 0.4), value: summary?.homeColor)
            HStack(alignment: .center, spacing: 8) {
                teamBlock(game.away, alignment: .leading)
                Spacer(minLength: 4)
                centerBlock
                Spacer(minLength: 4)
                teamBlock(game.home, alignment: .trailing)
            }
            .padding(.horizontal, 22).padding(.bottom, 46).padding(.top, 128)
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.35)))
            }.accessibilityLabel("Back")
            Spacer()
            HStack(spacing: 6) {
                if game.phase == .live { P1LivePulse() }
                Text(game.isField ? game.home.short : "\(game.away.code) \(game.sport == "tennis" || game.sport == "soccer" ? "vs" : "@") \(game.home.code)")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            .padding(.horizontal, 14).frame(height: 36)
            .background(Capsule().fill(.black.opacity(0.3)))
            Spacer()
            Menu {
                if !game.isField && game.sport != "tennis" {
                    ForEach([game.away, game.home], id: \.name) { side in
                        let on = favorites.followsTeam(side.name)
                        Button {
                            favorites.toggleTeam(side.name, sport: game.sport)
                            followFeedback += 1
                        } label: {
                            Label(on ? "Unfollow \(side.short)" : "Follow \(side.short)", systemImage: on ? "star.slash" : "star")
                        }
                    }
                }
                if game.phase == .live || game.phase == .pre, game.alertKey != nil, LiveActivityManager.shared.enabled {
                    Button {
                        if tracking { LiveActivityManager.shared.stopTracking(game) } else { LiveActivityManager.shared.track(game: game, pick: pick, locked: locked) }
                        tracking.toggle()
                    } label: {
                        Label(tracking ? "Stop Lock Screen tracking" : "Track on Lock Screen", systemImage: tracking ? "lock.slash" : "lock.iphone")
                    }
                }
                if let pick, !locked {
                    Button { onWatch(pick) } label: {
                        Label(watching ? "Remove from Watchlist" : "Add to Watchlist", systemImage: watching ? "eye.slash" : "eye")
                    }
                }
            } label: {
                Image(systemName: following ? "star.fill" : "ellipsis").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(following ? Color.p1Lime : .white)
                    .frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.35)))
            }
            .accessibilityLabel("Game options")
            .sensoryFeedback(.selection, trigger: followFeedback)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
        .background {
            if collapsed {
                Rectangle().fill(Color.black.opacity(0.92)).background(.ultraThinMaterial)
                    .overlay(alignment: .bottom) { Rectangle().fill(P1Board.pill).frame(height: 1) }
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity)
            }
        }
    }

    private var showsScore: Bool { game.phase == .live || game.phase == .final }

    private func teamBlock(_ side: P1GameSide, alignment: HorizontalAlignment) -> some View {
        let crest = VStack(spacing: 6) {
            Group {
                if game.isField {
                    Image(systemName: "flag.checkered").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                } else if game.sport != "tennis", let logo = side.logo, let url = URL(string: logo) {
                    CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(.black.opacity(0.2)) }
                } else {
                    TeamLogo(sport: game.sport, team: side.name, size: .small)
                }
            }.frame(width: 46, height: 46)
            Text(game.isField ? "" : side.code).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        let number = Text(showsScore ? (side.score.map(String.init) ?? "") : (side.record ?? ""))
            .font(.system(size: showsScore ? 34 : 22, weight: showsScore ? .bold : .semibold))
            .foregroundStyle(.white).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        let ref = game.teamRef(side)
        let tappable = Button { teamSheet = ref } label: { crest }
            .buttonStyle(PressableButtonStyle()).disabled(ref == nil)
            .accessibilityLabel(ref == nil ? side.name : "Open \(side.name)")
        return HStack(spacing: 12) {
            if alignment == .leading { tappable; number } else { number; tappable }
        }
        .opacity(game.isField && alignment == .trailing ? 0 : 1)
    }

    private var centerBlock: some View {
        VStack(spacing: 4) {
            switch game.phase {
            case .live:
                HStack(spacing: 5) { P1LivePulse(); Text("Live").foregroundStyle(Color.p1Red) }
                    .font(.system(size: 15, weight: .bold))
                Text(game.detail).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85))
            case .final:
                Text(game.detail.isEmpty ? "Final" : game.detail).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            case .off:
                Text(game.detail).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            case .pre:
                Text(game.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(game.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
            }
        }
        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
        .frame(maxWidth: 120)
    }

    // MARK: Cards

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }

    private func lockedStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(Color.p1Lime).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundStyle(P1Board.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(P1Board.pill))
    }

    private func whiteButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(Capsule().fill(Color.white))
        }.buttonStyle(PressableButtonStyle())
    }

    private var infoCard: some View {
        card {
            Text(game.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) + " · " + game.date.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 8) {
                infoLine("League", game.league)
                if let venue = summary?.venue ?? (game.note.isEmpty ? nil : game.note) { infoLine("Venue", venue) }
                if let city = summary?.city, !city.isEmpty { infoLine("City", city) }
                if let tv = summary?.tv { infoLine("TV", tv) }
            }
        }
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label).font(.system(size: 14)).foregroundStyle(P1Board.secondary).frame(width: 52, alignment: .leading)
            Text(value).font(.system(size: 15)).foregroundStyle(.white)
        }
    }

    // MARK: PICK1 tab

    @ViewBuilder private var pickTab: some View {
        if let pick, locked {
            card {
                Label("PICK1 prediction", systemImage: "lock.fill").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color.p1Lime)
                Text("PICK1 has a call on this game.")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                if game.phase == .live, let hs = game.home.score, let aws = game.away.score {
                    let onHome = P1GameMatch.same(game.home, pick.pick, sport: game.sport)
                    let onAway = P1GameMatch.same(game.away, pick.pick, sport: game.sport)
                    if onHome != onAway, onHome ? hs > aws : aws > hs {
                        HStack(spacing: 6) {
                            P1LivePulse()
                            Text("It's leading right now.").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.p1Lime)
                        }
                    }
                }
                // What is true without giving the side away.
                HStack(spacing: 10) {
                    lockedStat("\(Int(pick.probability.rounded()))%", "Confidence")
                    lockedStat(P1Odds.money(100 * (pick.decimalOdds - 1)), "Pays on $100")
                    lockedStat("\((pick.bettingProps?.count ?? 0) + 1)", "Markets called")
                }
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.14)).frame(width: 44, height: 44)
                        .overlay(Image(systemName: "lock.fill").foregroundStyle(Color.p1Lime))
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.18)).frame(width: 150, height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.10)).frame(width: 210, height: 10)
                    }
                }.accessibilityHidden(true)
                if let record = actions.leagueRecord(pick) {
                    Label(record, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                Button(action: onUnlock) {
                    Text(actions.offer.cta).font(.system(size: 17, weight: .bold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 50).background(Capsule().fill(Color.p1Lime))
                }.buttonStyle(PressableButtonStyle())
                if !actions.offer.terms.isEmpty {
                    Text(actions.offer.terms).font(.system(size: 12)).foregroundStyle(P1Board.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        } else if let pick {
            card {
                HStack {
                    Text("PICK1 prediction").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color.p1Lime)
                    Spacer()
                    if !pick.isPending {
                        Text(pick.isWin ? "Won" : pick.isLoss ? "Lost" : "Void")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(pick.isWin ? Color.black : .white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(pick.isWin ? Color.p1Lime : P1Board.pill))
                    }
                }
                HStack(spacing: 12) {
                    if !game.isField {
                        let side = P1GameMatch.same(game.home, pick.pick, sport: game.sport) ? game.home : game.away
                        Group {
                            if game.sport != "tennis", let logo = side.logo, let url = URL(string: logo) {
                                CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
                            } else {
                                TeamLogo(sport: game.sport, team: side.name, size: .small)
                            }
                        }.frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pick.displayPick).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.7)
                        Text(p1LeagueLabel(pick) + " · model probability").font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                    }
                    Spacer()
                    Text("\(Int(pick.probability.rounded()))%").font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.p1Lime).monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(P1Board.pill)
                        Capsule().fill(Color.p1Lime).frame(width: geo.size.width * min(1, max(0, pick.probability / 100)))
                    }
                }.frame(height: 6)
                if let odds = pick.marketOdds, odds > 1 {
                    HStack {
                        Text("Market price").font(.system(size: 14)).foregroundStyle(P1Board.secondary)
                        Spacer()
                        Text(String(format: "%.2f", odds)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).monospacedDigit()
                        Text("· +" + (100 * (odds - 1)).formatted(.currency(code: "USD").precision(.fractionLength(0))) + " on $100")
                            .font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                    }
                }
                if let key = pick.keyFactor, !key.isEmpty {
                    P1DashedRule()
                    Text(key).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }
                if !pick.reasoning.isEmpty {
                    Text(pick.reasoning).font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.8)).lineLimit(5)
                }
                whiteButton("Full analysis", icon: "chart.bar.doc.horizontal") { onAnalysis(pick) }
                if pick.isPending && game.phase != .final {
                    P1PlaceButton("Place this pick", selections: [pick.handoffSelection], source: "game_pick1")
                }
            }
            if let s = summary, s.extras.homeWin.count > 1 { winChart(s) }
            if let facts = pick.matchupFacts, !facts.isEmpty {
                card {
                    Text("Matchup").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    ForEach(facts) { fact in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fact.label).font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                            Text(fact.value).font(.system(size: 15)).foregroundStyle(.white)
                        }
                        if fact.id != facts.last?.id { P1DashedRule() }
                    }
                }
            }
            Text("Probabilities are model estimates. Market prices are shown for context, on a $100-a-pick basis.")
                .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
        } else {
            card {
                Text("No PICK1 call on this game").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text("PICK1 publishes a prediction on the games its model rates. The live score, stats and plays stay here for every game.")
                    .font(.system(size: 14)).foregroundStyle(P1Board.secondary)
            }
        }
        infoCard
    }

    private func winChart(_ s: P1GameSummary) -> some View {
        P1WinProbabilityCard(game: game, extras: s.extras, pick: pick, locked: locked,
                             homeColor: tint(s.homeColor, fallback: .white), awayColor: tint(s.awayColor, fallback: .white))
    }

    // MARK: Matchup tab

    @ViewBuilder private var matchupTab: some View {
        if !loaded {
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(30)
        } else if let s = summary {
            P1MatchupCards(game: game, extras: s.extras, pick: pick, locked: locked)
        } else {
            card { Text("Matchup data could not load. Pull down on the home page and try again.").font(.system(size: 14)).foregroundStyle(P1Board.secondary) }
        }
    }

    /// A full-game winner projection on PICK1's side quotes the pick's own
    /// probability, so the page never shows two numbers for one call.
    private func projectionPercent(_ prop: BettingProp, pick: Pick) -> Int? {
        guard let p = prop.probability else { return nil }
        let winnerLabels: Set<String> = ["Moneyline winner", "Winner", "Match winner", "Match result"]
        guard winnerLabels.contains(prop.label), prop.value.rangeOfCharacter(from: .decimalDigits) == nil else { return p }
        let value = prop.value.replacingOccurrences(of: " win", with: "", options: [.caseInsensitive, .anchored, .backwards]).lowercased()
        let call = pick.pick.lowercased()
        let last = value.split(separator: " ").last.map(String.init) ?? value
        let sameSide = value == call || (last.count > 2 && call.hasSuffix(last)) || call.hasPrefix(value)
        return sameSide ? Int(pick.probability.rounded()) : p
    }

    // MARK: Stats tab

    @ViewBuilder private var stats: some View {
        infoCard
        if !loaded {
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(30)
        } else if let s = summary {
            if pick == nil || locked, s.extras.homeWin.count > 1 { winChart(s) }
            if showsScore, !s.awayLines.isEmpty, s.awayLines.count == s.homeLines.count { lineScore(s) }
            if !s.leaders.isEmpty { leadersCard(s) }
            if !s.stats.isEmpty { teamStats(s) }
            if showsScore, !s.extras.awayBox.isEmpty || !s.extras.homeBox.isEmpty { P1BoxScoreCard(game: game, extras: s.extras) }
            if s.leaders.isEmpty && s.stats.isEmpty && !showsScore {
                card { Text("Stats appear here once ESPN publishes them for this game.").font(.system(size: 14)).foregroundStyle(P1Board.secondary) }
            }
        } else {
            card { Text("Stats could not load. Pull down on the home page and try again.").font(.system(size: 14)).foregroundStyle(P1Board.secondary) }
        }
    }

    private func smallCrest(_ side: P1GameSide) -> some View {
        Group {
            if let logo = side.logo, let url = URL(string: logo), game.sport != "tennis" {
                CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
            } else {
                TeamLogo(sport: game.sport, team: side.name, size: .small).scaleEffect(0.5)
            }
        }.frame(width: 22, height: 22)
    }

    private func lineScore(_ s: P1GameSummary) -> some View {
        card {
            Grid(horizontalSpacing: 10, verticalSpacing: 12) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    ForEach(Array(s.awayLines.indices), id: \.self) { i in
                        Text("\(i + 1)").font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                    }
                    Text("T").font(.system(size: 13, weight: .bold)).foregroundStyle(P1Board.secondary)
                }
                ForEach([game.away, game.home], id: \.name) { side in
                    let values = side.name == game.away.name ? s.awayLines : s.homeLines
                    GridRow {
                        HStack(spacing: 8) { smallCrest(side); Text(side.code).font(.system(size: 15, weight: .semibold)) }
                        ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                            Text(v).font(.system(size: 15)).monospacedDigit()
                        }
                        Text(side.score.map(String.init) ?? "").font(.system(size: 15, weight: .bold)).monospacedDigit()
                    }.foregroundStyle(.white)
                }
            }
        }
    }

    private func leadersCard(_ s: P1GameSummary) -> some View {
        card {
            HStack {
                smallCrest(game.away); Text(game.away.code).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(showsScore ? "Game leaders" : "Team leaders").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(game.home.code).font(.system(size: 14, weight: .semibold)); smallCrest(game.home)
            }.foregroundStyle(.white)
            ForEach(s.leaders) { row in
                Rectangle().fill(P1Board.pill).frame(height: 1)
                HStack(alignment: .top, spacing: 8) {
                    leaderSide(row.away, trailing: false)
                    Text(row.label).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                        .multilineTextAlignment(.center).frame(width: 76).padding(.top, 10)
                    leaderSide(row.home, trailing: true)
                }
            }
        }
    }

    @ViewBuilder private func leaderSide(_ leader: P1GameSummary.Leader?, trailing: Bool) -> some View {
        if let leader {
            VStack(alignment: trailing ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 10) {
                    if trailing { Spacer(minLength: 0) }
                    if !trailing { headshot(leader) }
                    Text(leader.value).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    if trailing { headshot(leader) }
                    if !trailing { Spacer(minLength: 0) }
                }
                Text(leader.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                if let detail = leader.detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(P1Board.secondary)
                        .multilineTextAlignment(trailing ? .trailing : .leading).lineLimit(2)
                }
            }.frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        } else {
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    private func headshot(_ leader: P1GameSummary.Leader) -> some View {
        Group {
            if let h = leader.headshot, let url = URL(string: h) {
                CachedImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.clear }
            } else {
                Image(systemName: "person.fill").font(.system(size: 14)).foregroundStyle(P1Board.secondary)
            }
        }
        .frame(width: 34, height: 34).background(Circle().fill(P1Board.pill)).clipShape(Circle())
    }

    private func teamStats(_ s: P1GameSummary) -> some View {
        card {
            HStack {
                smallCrest(game.away); Spacer()
                Text(showsScore ? "Team stats" : "Season stats").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Spacer(); smallCrest(game.home)
            }
            ForEach(s.stats) { stat in
                Rectangle().fill(P1Board.pill).frame(height: 1)
                HStack {
                    Text(stat.away).font(.system(size: 16, weight: .semibold)).monospacedDigit().frame(width: 70, alignment: .leading)
                    Spacer()
                    Text(stat.label).font(.system(size: 13)).foregroundStyle(P1Board.secondary).multilineTextAlignment(.center)
                    Spacer()
                    Text(stat.home).font(.system(size: 16, weight: .semibold)).monospacedDigit().frame(width: 70, alignment: .trailing)
                }.foregroundStyle(.white)
            }
        }
    }

    // MARK: Plays tab

    @ViewBuilder private var playsTab: some View {
        if !loaded {
            ProgressView().tint(.white).frame(maxWidth: .infinity).padding(30)
        } else if let s = summary, !s.scoring.isEmpty || (game.phase == .live && !s.latest.isEmpty) {
            if game.phase == .live && !s.latest.isEmpty { playsCard("Latest", s.latest) }
            if !s.scoring.isEmpty { playsCard("Scoring", s.scoring.reversed()) }
        } else {
            card {
                Text(game.phase == .pre ? "Plays start at kickoff" : "No plays published").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Text(game.phase == .pre ? "Every scoring play shows here as it happens, with the running score." : "ESPN has not published a play log for this game.")
                    .font(.system(size: 14)).foregroundStyle(P1Board.secondary)
            }
        }
    }

    private func playsCard(_ title: String, _ plays: [P1GameSummary.Play]) -> some View {
        card {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            ForEach(plays) { play in
                HStack(alignment: .top, spacing: 12) {
                    Group {
                        if let logo = play.logo, let url = URL(string: logo) {
                            CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
                        } else {
                            Circle().fill(P1Board.pill)
                        }
                    }.frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(play.text).font(.system(size: 14)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                        if !play.when.isEmpty { Text(play.when).font(.system(size: 12)).foregroundStyle(P1Board.secondary) }
                    }
                    Spacer(minLength: 6)
                    if let a = play.awayScore, let h = play.homeScore {
                        Text("\(a)-\(h)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).monospacedDigit()
                    }
                }
                if play.id != plays.last?.id { P1DashedRule() }
            }
        }
    }

    // MARK: Projections tab

    @ViewBuilder private var projections: some View {
        if let pick, let props = pick.bettingProps, !props.isEmpty {
            card {
                Text("PICK1 projections").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                ForEach(props) { prop in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prop.label).font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                            Text(prop.value).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            if let hint = prop.hint, !hint.isEmpty {
                                Text(hint).font(.system(size: 11)).foregroundStyle(P1Board.secondary)
                            }
                        }
                        Spacer()
                        if let p = projectionPercent(prop, pick: pick) {
                            VStack(spacing: 2) {
                                Text("\(p)%").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.p1Lime).monospacedDigit()
                                Text("model").font(.system(size: 10)).foregroundStyle(P1Board.secondary)
                            }
                            .frame(width: 64, height: 46)
                            .background(RoundedRectangle(cornerRadius: 10).fill(P1Board.pill))
                        }
                    }
                    if prop.id != props.last?.id { Rectangle().fill(P1Board.pill).frame(height: 1) }
                }
            }
            Text("Model projections, not offers. PICK1 is a prediction tracker.")
                .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
        }
    }
}
