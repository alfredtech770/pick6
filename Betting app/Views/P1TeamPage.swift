import SwiftUI
import Combine

// MARK: Team pages and search
// A page per team (record, standing, next game, schedule, results, and how
// PICK1 has called its games) and a search across teams and today's games.
// All read from ESPN's public team and schedule endpoints.

/// Everything a nested game page needs from the home screen.
/// The upgrade pitch, built from the real StoreKit offer for this user.
struct P1Offer {
    /// "Start for €0.99" or "Unlock for €9.99/week".
    var cta = "Unlock every call"
    /// "First week €0.99, then €9.99/week. Cancel anytime."
    var terms = ""
}

struct P1GameActions {
    var offer = P1Offer()
    /// PICK1's real 30-day record in a league, only when it is worth showing.
    var leagueRecord: (Pick) -> String? = { _ in nil }
    var picks: [Pick] = []
    var isLocked: (Pick) -> Bool = { _ in false }
    var isWatching: (Pick) -> Bool = { _ in false }
    var onAnalysis: (Pick) -> Void = { _ in }
    var onWatch: (Pick) -> Void = { _ in }
    var onUnlock: () -> Void = {}
}

struct P1TeamRef: Identifiable, Hashable {
    let path: String
    let teamID: String
    let sport: String
    let name: String
    let logo: String?
    /// Team colour, hex without #, for the crest tile in "Manage your teams".
    var color: String? = nil
    var id: String { path + "/" + teamID }
    var mineID: String { "mine-" + id }

    var league: P1BoardLeague {
        P1ScoreboardFeed.leagues.first { $0.path == path } ?? P1BoardLeague(sport: sport, label: "", path: path)
    }
}

extension P1Game {
    func teamRef(_ side: P1GameSide) -> P1TeamRef? {
        guard let path, let id = side.teamID, !isField, sport != "tennis" else { return nil }
        return P1TeamRef(path: path, teamID: id, sport: sport, name: side.name, logo: side.logo)
    }
}

nonisolated struct P1TeamInfo: Sendable {
    var name = ""
    var record: String?
    var standing: String?
    var color: String?
    var logo: String?
    var games: [P1Game] = []

    static func load(_ ref: P1TeamRef) async -> P1TeamInfo? {
        let base = "https://site.api.espn.com/apis/site/v2/sports/\(ref.path)/teams/\(ref.teamID)"
        async let teamData = get(base)
        async let scheduleData = get(base + "/schedule")
        guard let team = (await teamData)?["team"] as? [String: Any] else { return nil }
        var info = P1TeamInfo()
        info.name = team["displayName"] as? String ?? ref.name
        info.record = ((team["record"] as? [String: Any])?["items"] as? [[String: Any]])?.first?["summary"] as? String
        info.standing = team["standingSummary"] as? String
        let main = (team["color"] as? String)?.lowercased()
        info.color = (main == nil || main == "000000" || main == "ffffff") ? (team["alternateColor"] as? String) : main
        info.logo = (team["logos"] as? [[String: Any]])?.first?["href"] as? String ?? ref.logo
        let league = await MainActor.run { ref.league }
        let events = ((await scheduleData)?["events"] as? [[String: Any]]) ?? []
        info.games = events.compactMap { P1ScoreboardFeed.parseEvent($0, league: league) }.sorted { $0.date < $1.date }
        return info
    }

    private static func get(_ url: String) async -> [String: Any]? {
        guard let u = URL(string: url) else { return nil }
        var req = URLRequest(url: u); req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

struct P1TeamPage: View {
    let ref: P1TeamRef
    var actions = P1GameActions()
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var info: P1TeamInfo?
    @State private var loaded = false
    @State private var openRow: P1GameRow?

    private var rows: [P1GameRow] { P1GameMatch.attach(games: info?.games ?? [], picks: actions.picks) }
    private var upcoming: [P1GameRow] { rows.filter { $0.game.phase == .pre || $0.game.phase == .live } }
    private var results: [P1GameRow] { rows.filter { $0.game.phase == .final }.reversed() }
    private var following: Bool { favorites.followsTeam(ref.name) }

    /// PICK1's settled calls on this team's games, any side.
    private var calls: [Pick] {
        let side = P1GameSide(name: info?.name ?? ref.name, short: ref.name, code: "", logo: nil, record: nil, score: nil, winner: false)
        return actions.picks.filter { p in
            p.sport == ref.sport && (P1GameMatch.same(side, p.homeTeam, sport: p.sport) || P1GameMatch.same(side, p.awayTeam, sport: p.sport))
        }.sorted { $0.gameDate > $1.gameDate }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header
                if !loaded {
                    ProgressView().tint(.white).padding(40)
                } else if info == nil {
                    card { Text("This team could not load. Try again in a moment.").font(.system(size: 14)).foregroundStyle(P1Board.secondary) }
                        .padding(.horizontal, 16)
                } else {
                    if let next = upcoming.first {
                        section(next.game.phase == .live ? "Live now" : "Next game") { gameRow(next) }
                    }
                    pick1Card.padding(.horizontal, 16)
                    if upcoming.count > 1 {
                        section("Upcoming") { ForEach(upcoming.dropFirst().prefix(5)) { gameRow($0) } }
                    }
                    if !results.isEmpty {
                        section("Results") { ForEach(results.prefix(8)) { gameRow($0) } }
                    }
                }
            }.padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task(id: ref.id) {
            info = await P1TeamInfo.load(ref)
            loaded = true
        }
        .fullScreenCover(item: $openRow) { row in
            P1GameDetail(row: row, locked: row.pick.map(actions.isLocked) ?? false,
                         watching: row.pick.map(actions.isWatching) ?? false,
                         onAnalysis: actions.onAnalysis, onWatch: actions.onWatch, onUnlock: actions.onUnlock)
                .environmentObject(favorites)
        }
    }

    private var tint: Color {
        guard let c = info?.color, c.count == 6 else { return P1Board.pill }
        return Color(hex: "#" + c)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Group {
                if let logo = info?.logo ?? ref.logo, let url = URL(string: logo) {
                    CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
                } else {
                    TeamLogo(sport: ref.sport, team: ref.name, size: .big)
                }
            }.frame(width: 84, height: 84)
            Text(info?.name ?? ref.name).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                if let r = info?.record { Text(r).font(.system(size: 15, weight: .semibold)).monospacedDigit() }
                if let s = info?.standing { Text("· " + s).font(.system(size: 14)) }
            }.foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            Button {
                favorites.toggleTeam(ref.name, sport: ref.sport)
            } label: {
                Label(following ? "Following" : "Follow", systemImage: following ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(following ? Color.black : .black)
                    .padding(.horizontal, 22).frame(height: 40)
                    .background(Capsule().fill(following ? Color.p1Lime : Color.white))
            }
            .buttonStyle(PressableButtonStyle())
            .sensoryFeedback(.selection, trigger: following)
            Text(following ? "Kickoff, scores and finals are sent to you." : "Follow to get kickoff, scores and finals.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 110).padding(.bottom, 26).padding(.horizontal, 16)
        .background(LinearGradient(colors: [tint.opacity(0.85), .black], startPoint: .top, endPoint: .bottom))
    }

    private var pick1Card: some View {
        let settled = calls.filter { !$0.isPending }
        let wins = settled.filter(\.isWin).count
        return card {
            HStack {
                Text("PICK1 on this team").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Spacer()
                if !settled.isEmpty {
                    Text("\(wins)-\(settled.count - wins)").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.p1Lime).monospacedDigit()
                }
            }
            if calls.isEmpty {
                Text("PICK1 has not published a call on their games yet.").font(.system(size: 14)).foregroundStyle(P1Board.secondary)
            } else {
                Text("\(calls.count) published \(calls.count == 1 ? "call" : "calls") on their games. Every one stays in the public record.")
                    .font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                ForEach(calls.prefix(5)) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.awayTeam + " @ " + p.homeTeam).font(.system(size: 13)).foregroundStyle(P1Board.secondary).lineLimit(1)
                            if p.isPending && actions.isLocked(p) {
                                Label("Prediction ready", systemImage: "lock.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            } else {
                                Text(p.shortDisplayPick + " · \(Int(p.probability.rounded()))%").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            }
                        }
                        Spacer()
                        Text(p.isPending ? p.gameDate : p.isWin ? "Won" : "Lost")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(p.isPending ? P1Board.secondary : p.isWin ? Color.p1Lime : P1Board.secondary)
                    }
                    if p.id != calls.prefix(5).last?.id { P1DashedRule() }
                }
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            content()
        }.padding(.horizontal, 16)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }

    private func gameRow(_ row: P1GameRow) -> some View {
        P1GameListRow(row: row, locked: row.pick.map(actions.isLocked) ?? false,
                      watching: row.pick.map(actions.isWatching) ?? false,
                      onOpen: { openRow = row },
                      onWatch: { if let p = row.pick { actions.onWatch(p) } },
                      onUnlock: actions.onUnlock)
    }
}

// MARK: Search

/// Every team in the main leagues, fetched once per launch for search.
@MainActor final class P1TeamsIndex: ObservableObject {
    static let shared = P1TeamsIndex()
    @Published private(set) var teams: [P1TeamRef] = []
    @Published private(set) var loading = false
    private var leagueOf: [String: String] = [:]

    func label(_ ref: P1TeamRef) -> String { leagueOf[ref.id] ?? "" }

    func loadIfNeeded() async {
        guard teams.isEmpty, !loading else { return }
        loading = true
        let leagues = P1ScoreboardFeed.leagues.filter { !["tennis", "f1"].contains($0.sport) && !$0.path.contains("college") }
        let results = await withTaskGroup(of: [(P1TeamRef, String)].self) { group in
            for l in leagues { group.addTask { await Self.fetch(l) } }
            var all: [(P1TeamRef, String)] = []
            for await r in group { all += r }
            return all
        }
        var seen = Set<String>()
        teams = results.filter { seen.insert($0.0.id).inserted }.map(\.0).sorted { $0.name < $1.name }
        for (ref, label) in results { leagueOf[ref.id] = label }
        loading = false
    }

    nonisolated private static func fetch(_ l: P1BoardLeague) async -> [(P1TeamRef, String)] {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(l.path)/teams?limit=200"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let list = (((root["sports"] as? [[String: Any]])?.first?["leagues"] as? [[String: Any]])?.first?["teams"] as? [[String: Any]]) ?? []
        return list.compactMap { item in
            guard let t = item["team"] as? [String: Any], let id = t["id"] as? String, let name = t["displayName"] as? String else { return nil }
            let logo = (t["logos"] as? [[String: Any]])?.first?["href"] as? String
            let main = (t["color"] as? String)?.lowercased()
            let color = (main == nil || main == "000000" || main == "ffffff") ? (t["alternateColor"] as? String) : main
            return (P1TeamRef(path: l.path, teamID: id, sport: l.sport, name: name, logo: logo, color: color), l.label)
        }
    }
}

struct P1SearchScreen: View {
    let games: [P1GameRow]
    var actions = P1GameActions()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var index = P1TeamsIndex.shared
    @State private var query = ""
    @State private var openRow: P1GameRow?
    @FocusState private var focused: Bool

    private var needle: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var teamHits: [P1TeamRef] {
        guard needle.count >= 2 else { return [] }
        return Array(index.teams.filter { $0.name.localizedCaseInsensitiveContains(needle) || index.label($0).localizedCaseInsensitiveContains(needle) }.prefix(20))
    }
    private var gameHits: [P1GameRow] {
        guard needle.count >= 2 else { return [] }
        return Array(games.filter { r in
            [r.game.home.name, r.game.away.name, r.game.home.code, r.game.away.code, r.game.league]
                .contains { $0.localizedCaseInsensitiveContains(needle) }
        }.prefix(15))
    }
    private var followed: [P1TeamRef] { index.teams.filter { favorites.followsTeam($0.name) } }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(P1Board.secondary)
                        TextField("Teams, leagues, games", text: $query)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .focused($focused).foregroundStyle(.white)
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(P1Board.secondary) }
                                .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 14).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 14).fill(P1Board.card))

                    if needle.count < 2 {
                        if !followed.isEmpty { teamSection("Your teams", followed) }
                        Text(index.loading ? "Loading teams…" : "Search any team in the NFL, NBA, NHL, MLB, WNBA, MLS and the top soccer leagues, or a game on today's board.")
                            .font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                    } else {
                        if !teamHits.isEmpty { teamSection("Teams", teamHits) }
                        if !gameHits.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Games").font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                                ForEach(gameHits) { row in
                                    P1GameListRow(row: row, locked: row.pick.map(actions.isLocked) ?? false,
                                                  watching: row.pick.map(actions.isWatching) ?? false,
                                                  onOpen: { openRow = row },
                                                  onWatch: { if let p = row.pick { actions.onWatch(p) } },
                                                  onUnlock: actions.onUnlock)
                                }
                            }
                        }
                        if teamHits.isEmpty && gameHits.isEmpty && !index.loading {
                            Text("Nothing matches \u{201C}\(needle)\u{201D}.").font(.system(size: 14)).foregroundStyle(P1Board.secondary)
                        }
                    }
                }.padding(16)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.tint(.white) }
            }
            .navigationDestination(for: P1TeamRef.self) { ref in P1TeamPage(ref: ref, actions: actions) }
            .fullScreenCover(item: $openRow) { row in
                P1GameDetail(row: row, locked: row.pick.map(actions.isLocked) ?? false,
                             watching: row.pick.map(actions.isWatching) ?? false,
                             onAnalysis: actions.onAnalysis, onWatch: actions.onWatch, onUnlock: actions.onUnlock)
                    .environmentObject(favorites)
            }
        }
        .preferredColorScheme(.dark)
        .task { await index.loadIfNeeded() }
        .onAppear { focused = true }
    }

    private func teamSection(_ title: String, _ teams: [P1TeamRef]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            VStack(spacing: 0) {
                ForEach(teams) { ref in
                    NavigationLink(value: ref) {
                        HStack(spacing: 12) {
                            Group {
                                if let l = ref.logo, let url = URL(string: l) {
                                    CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Circle().fill(P1Board.pill) }
                                } else { Circle().fill(P1Board.pill) }
                            }.frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(ref.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                                Text(index.label(ref)).font(.system(size: 12)).foregroundStyle(P1Board.secondary)
                            }
                            Spacer()
                            if favorites.followsTeam(ref.name) { Image(systemName: "star.fill").foregroundStyle(Color.p1Lime).font(.system(size: 12)) }
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(P1Board.secondary)
                        }.padding(.horizontal, 14).frame(height: 56)
                    }
                    if ref.id != teams.last?.id { Rectangle().fill(P1Board.pill).frame(height: 1).padding(.leading, 56) }
                }
            }
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
        }
    }
}

// MARK: Manage your teams

/// X's "Manage your teams" sheet: pick a league, search, tick teams, Done.
/// Every tick follows the team, which feeds the Favorite Teams banner and
/// the kickoff, score and final alerts.
struct P1ManageTeamsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var index = P1TeamsIndex.shared
    @State private var query = ""
    @State private var league = "NFL"
    @State private var feedback = 0

    private var leagues: [String] {
        let present = Set(index.teams.map { index.label($0) })
        return P1ScoreboardFeed.leagues.map(\.label).filter { present.contains($0) }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    }
    private var needle: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var shown: [P1TeamRef] {
        let all = needle.isEmpty ? index.teams.filter { index.label($0) == league }
                                 : index.teams.filter { $0.name.localizedCaseInsensitiveContains(needle) }
        return all.sorted { $0.name < $1.name }
    }
    private var followed: [P1TeamRef] { index.teams.filter { favorites.followsTeam($0.name) } }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Manage your teams").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                    }.accessibilityLabel("Close")
                    Spacer()
                }
            }
            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 14)
            Rectangle().fill(P1Board.pill).frame(height: 1).padding(.horizontal, 16)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(P1Board.secondary)
                TextField("Search Teams", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().foregroundStyle(.white)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(P1Board.secondary) }
                }
            }
            .padding(.horizontal, 14).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 14).fill(P1Board.pill))
            .padding(.horizontal, 16).padding(.top, 16)

            if needle.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(leagues, id: \.self) { l in
                            Button { league = l } label: {
                                Text(l).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(l == league ? Color.black : .white)
                                    .padding(.horizontal, 14).frame(height: 34)
                                    .background(Capsule().fill(l == league ? Color.white : Color.black))
                                    .overlay(Capsule().strokeBorder(l == league ? .clear : Color(hex: "#363636")))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 16)
                }.padding(.top, 14)
            }

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if needle.isEmpty, !followed.isEmpty {
                        sectionTitle("Your teams")
                        ForEach(followed, id: \.mineID) { row($0) }
                    }
                    sectionTitle(needle.isEmpty ? "All teams" : "Results")
                    if index.loading && index.teams.isEmpty {
                        ProgressView().tint(.white).frame(maxWidth: .infinity).padding(30)
                    } else if shown.isEmpty {
                        Text("No team matches \u{201C}\(needle)\u{201D}.").font(.system(size: 14)).foregroundStyle(P1Board.secondary)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    ForEach(shown) { row($0) }
                    Color.clear.frame(height: 90)
                }
            }
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.9),
                                         .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
        }
        .overlay(alignment: .bottom) {
            Button { dismiss() } label: {
                Text("Done").font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .background(P1Board.card.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: feedback)
        .task { await index.loadIfNeeded() }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 14)).foregroundStyle(P1Board.secondary)
            .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 6)
    }

    private func row(_ ref: P1TeamRef) -> some View {
        let on = favorites.followsTeam(ref.name)
        return Button {
            favorites.toggleTeam(ref.name, sport: ref.sport)
            feedback += 1
        } label: {
            HStack(spacing: 14) {
                Group {
                    if let l = ref.logo, let url = URL(string: l) {
                        CachedImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.clear }
                            .padding(8)
                    } else { Color.clear }
                }
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ref.color.flatMap { $0.count == 6 ? Color(hex: "#" + $0) : nil } ?? P1Board.pill))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ref.name).font(.system(size: 17, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                    if !needle.isEmpty {
                        Text(index.label(ref)).font(.system(size: 12)).foregroundStyle(P1Board.secondary)
                    }
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 5).strokeBorder(on ? Color.p1Lime : Color(hex: "#5A5A5A"), lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(on ? Color.p1Lime : .clear))
                    if on { Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(.black) }
                }.frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16).frame(height: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ref.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
