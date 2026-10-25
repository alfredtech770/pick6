import SwiftUI

// Match board components. A quote is a captured market price shown for context, never model-implied odds.

/// Tennis rows carry the tour the pipeline scheduled them under, which is not always the player's
/// tour (WTA matches have come through as "ATP"). The sport is always right, so tennis reads "Tennis".
func p1LeagueLabel(_ pick: Pick) -> String {
    pick.sport == "tennis" ? "Tennis" : pick.league
}

func p1GamesCount(_ count: Int) -> String { count == 1 ? "1 game" : "\(count) games" }

// MARK: Scoreboard frame
// The look of a scores app: charcoal card on black, grey status line, dashed
// rules, one team per row with its code on the left and the score (or the
// PICK1 call) on the right. Shared by the featured rail and the game list.
enum P1Board {
    // Measured on X's own scores screens: black ground, #141414 cards with
    // a hairline #1C1C1C edge, #232323 price boxes and pills.
    static let card = Color(hex: "#141414")
    static let edge = Color(hex: "#222222")
    static let pill = Color(hex: "#232323")
    static let rule = Color(hex: "#2A2A2A")
    static let secondary = Color(hex: "#8B8B8B")
    static let radius: CGFloat = 16
}

struct P1DashedRule: View {
    var body: some View {
        DashedLine().stroke(P1Board.rule, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
    }
}

/// "NE", "CHI" for US leagues, the usual short name everywhere else.
func p1TeamCode(_ team: String, sport: String) -> String {
    TeamLogoLookup.code(sport: sport, team: team) ?? teamShortName(team, sport: sport)
}

struct P1ScoreLines: View {
    let pick: Pick
    var score: LiveScore?
    var locked = false
    var compact = false

    private var fresh: LiveScore? {
        guard let score else { return nil }
        if score.isLive, let updated = score.updatedAt, Date().timeIntervalSince(updated) > 7200 { return nil }
        return score
    }
    private var isLive: Bool { fresh?.isLive == true }
    private var isFinal: Bool { fresh?.isFinal == true || !pick.isPending }
    private var homeScore: Int? { fresh?.homeScore ?? pick.homeScore }
    private var awayScore: Int? { fresh?.awayScore ?? pick.awayScore }
    private var isField: Bool { pick.sport == "f1" || pick.sport == "golf" }

    private var statusLeft: String {
        if isLive { return "Live" }
        if isFinal { return "Final" }
        guard let date = pick.scheduledStartDate else { return pick.isToday ? "Today" : P1BookDays.label(pick.gameDate) }
        let cal = Calendar.autoupdatingCurrent
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }
    private var statusRight: String {
        if isLive { return fresh?.quarter ?? "" }
        if isFinal { return compact ? "" : p1LeagueLabel(pick) }
        if let time = pick.localizedStartTimeDisplay { return "at " + time }
        return compact ? "" : p1LeagueLabel(pick)
    }
    private func picked(_ team: String) -> Bool {
        !locked && pick.pick.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(team) == .orderedSame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 9 : 11) {
            HStack(spacing: 6) {
                if isLive { P1LivePulse() }
                Text(statusLeft).foregroundStyle(isLive ? Color.p1Red : P1Board.secondary)
                Spacer(minLength: 6)
                Text(statusRight).foregroundStyle(P1Board.secondary).lineLimit(1)
            }.font(.system(size: compact ? 13 : 14, weight: .medium))
            P1DashedRule()
            if isField {
                row(pick.homeTeam == "Field" ? pick.awayTeam : pick.homeTeam, value: nil, other: nil)
                Text("Tournament winner").font(.system(size: 12)).foregroundStyle(P1Board.secondary)
            } else {
                row(pick.awayTeam, value: awayScore, other: homeScore)
                row(pick.homeTeam, value: homeScore, other: awayScore)
            }
        }
    }

    private func row(_ team: String, value: Int?, other: Int?) -> some View {
        let showScore = (isLive || isFinal) && value != nil
        let leads = showScore && (value ?? 0) >= (other ?? 0) && value != other
        return HStack(spacing: 10) {
            TeamLogo(sport: pick.sport, team: team, size: .small)
                .scaleEffect(compact ? 0.6 : 0.7).frame(width: compact ? 26 : 30, height: compact ? 26 : 30)
            Text(p1TeamCode(team, sport: pick.sport))
                .font(.system(size: compact ? 18 : 20, weight: .semibold))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            if picked(team) {
                Text("PICK1").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color.p1Ink)
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.p1Lime))
                    .fixedSize()
            }
            Spacer(minLength: 4)
            if showScore, let value {
                Text("\(value)")
                    .font(.system(size: compact ? 18 : 20, weight: leads || !isFinal ? .bold : .regular))
                    .foregroundStyle(leads || !isFinal ? Color.white : P1Board.secondary)
                    .monospacedDigit().p1ScoreFlash(String(value))
            } else if picked(team) {
                Text("\(Int(pick.probability.rounded()))%")
                    .font(.system(size: compact ? 17 : 19, weight: .regular))
                    .foregroundStyle(Color.p1Lime).monospacedDigit().fixedSize()
            }
        }
    }
}

/// Bottom pill of a card, the slot a scores app uses for "Highlights".
struct P1BoardPill: View {
    let title: String
    let icon: String
    var tint: Color = .white
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(Capsule().fill(P1Board.pill))
    }
}

/// "Favorite Teams" strip: stacked crests of the teams the reader follows.
struct P1FavoriteTeamsBanner: View {
    let teams: [(name: String, sport: String)]
    let active: Bool
    var onTap: () -> Void
    var onClose: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    HStack(spacing: -14) {
                        if teams.isEmpty {
                            Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.p1Lime)
                                .frame(width: 46, height: 46).background(Circle().fill(Color(hex: "#2C2C2E")))
                        }
                        ForEach(Array(teams.prefix(3).enumerated()), id: \.offset) { index, team in
                            TeamLogo(sport: team.sport, team: team.name, size: .small)
                                .frame(width: 32, height: 32)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Color(hex: "#2C2C2E")))
                                .overlay(Circle().strokeBorder(Color.black, lineWidth: 2))
                                .zIndex(Double(3 - index))
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Favorite Teams").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        Text(teams.isEmpty ? "Pick the teams you follow" : active ? "Showing only your teams" : "Show only their games")
                            .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.85)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }.buttonStyle(PressableButtonStyle())
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 32, height: 32)
            }.accessibilityLabel("Hide favorite teams")
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
        .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(active ? Color.p1Lime.opacity(0.5) : P1Board.edge))
    }
}

struct P1BookHeader: View {
    @AppStorage("pick1SoundsEnabled") private var soundsEnabled = false
    var onProfile: () -> Void
    var onTeams: (() -> Void)? = nil
    var onSearch: (() -> Void)? = nil
    var onPage: ((P1ExplorePage) -> Void)? = nil
    var body: some View {
        HStack(spacing: 14) {
            Pick1Wordmark(size: 24)
            Spacer()
            if let onTeams {
                Button(action: onTeams) {
                    Label("Teams", systemImage: "plus").font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 13).frame(height: 32)
                        .background(Capsule().fill(P1Board.pill))
                }.buttonStyle(PressableButtonStyle()).accessibilityLabel("Follow teams")
            }
            if let onPage {
                Menu {
                    if let onSearch {
                        Button(action: onSearch) { Label("Search teams and games", systemImage: "magnifyingglass") }
                    }
                    ForEach(P1ExplorePage.allCases) { page in
                        Button { onPage(page) } label: { Label(page.rawValue, systemImage: page.icon) }
                    }
                    Button {
                        soundsEnabled.toggle()
                        if soundsEnabled { P1ArenaAudio.play("pick1-click") }
                    } label: { Label(soundsEnabled ? "Mute sounds" : "Turn on sounds", systemImage: soundsEnabled ? "speaker.slash" : "speaker.wave.2") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold))
                        .frame(width: 32, height: 32).background(Circle().fill(P1Board.pill))
                }.accessibilityLabel("More")
            } else {
                Button {
                    soundsEnabled.toggle()
                    if soundsEnabled { P1ArenaAudio.play("pick1-click") }
                } label: {
                    Image(systemName: soundsEnabled ? "speaker.wave.2" : "speaker.slash").font(.system(size: 16)).foregroundStyle(Color.p1Ink2)
                }.buttonStyle(PressableButtonStyle()).accessibilityLabel(soundsEnabled ? "Mute app sounds" : "Enable app sounds")
            }
            Button(action: onProfile) { Image(systemName: "person.crop.circle").font(.system(size: 22)) }
                .buttonStyle(PressableButtonStyle()).accessibilityLabel("Profile")
        }.foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct P1BookSportRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ring
    let sports: [String]
    let active: String
    var onSelect: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(sports, id: \.self) { sport in
                    Button { withAnimation(reduceMotion ? nil : Pick1Springs.snappy) { onSelect(sport) } } label: {
                        VStack(spacing: 7) {
                            Group {
                                if sport == Pick1HomeV4.allSports { Image(systemName: "flame.fill").font(.system(size: 20)).foregroundStyle(Color.p1Primary) }
                                else { P1SportMark(sport: sport, size: 21, glowing: false) }
                            }.frame(width: 44, height: 44)
                                .background(Circle().fill(Color.p1Panel))
                                .overlay { if sport == active { Circle().strokeBorder(Color.p1Primary, lineWidth: 1.5).matchedGeometryEffect(id: "sportRing", in: ring) } }
                                .scaleEffect(!reduceMotion && sport == active ? 1.06 : 1)
                            Text(sport == Pick1HomeV4.allSports ? "For you" : v4Name(sport))
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(sport == active ? .white : V4.mute)
                        }.frame(width: 56)
                    }.buttonStyle(PressableButtonStyle())
                        .accessibilityAddTraits(sport == active ? [.isSelected, .isButton] : .isButton)
                }
            }.padding(.horizontal, 16)
        }.padding(.vertical, 12)
            .sensoryFeedback(.selection, trigger: active)
    }
}

struct P1BookFeatured: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pick: Pick
    var selected: Bool
    var onOpen: () -> Void
    var onAdd: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("HIGHEST MODEL CONFIDENCE").font(.system(size: 9, weight: .heavy)).tracking(1)
                Text(pick.shortDisplayPick).font(.system(size: 25, weight: .heavy)).lineLimit(2).minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    LeagueLogo(leagueId: pick.league, fallbackSymbol: "trophy.fill", swatch: Color.p1Panel2, size: 20)
                    Text(p1LeagueLabel(pick) + " · " + (pick.startTimeDisplay ?? "Upcoming")).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                }
                Text(pick.homeTeam + " vs " + pick.awayTeam).font(.system(size: 11)).lineLimit(2).foregroundStyle(.white.opacity(0.8))
                Text("Model estimate · not a guaranteed win").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.75))
                Button(action: onOpen) { Text("View PICK1 analysis").font(.system(size: 11, weight: .bold)).padding(.horizontal, 14).padding(.vertical, 9).background(Capsule().fill(Color.black.opacity(0.45))) }
                    .buttonStyle(PressableButtonStyle())
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Text("\(Int(pick.probability.rounded()))%")
                    .font(.system(size: 32, weight: .heavy)).foregroundStyle(Color.p1Lime)
                Text("MODEL CONFIDENCE").font(.system(size: 7, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                if let quote = P1BookQuote.forPick(pick) {
                    Text(String(format: "%.2f", quote.odds)).font(.system(size: 23, weight: .heavy, design: .monospaced))
                    Text("Market odds").font(.system(size: 8)).foregroundStyle(.white.opacity(0.7))
                }
                Button(action: onAdd) { Image(systemName: selected ? "checkmark" : "plus").contentTransition(.symbolEffect(.replace)).font(.system(size: 14, weight: .bold)).frame(width: 32, height: 32).background(Circle().fill(Color.white.opacity(0.12))) }
                    .buttonStyle(PressableButtonStyle()).symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : selected).accessibilityLabel(selected ? "In your watchlist" : "Add to watchlist")
            }
        }.foregroundStyle(.white).padding(18)
            .background {
                GeometryReader { geometry in
                    Image(pick.sport == "soccer" ? "ConfidenceStadium" : "Confidence_" + pick.sport).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .overlay(Color.black.opacity(0.48))
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .animation(reduceMotion ? nil : Pick1Springs.snappy, value: selected)
            .p1Entrance(delay: 0.06)
    }
}

struct P1BookEventRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pick: Pick
    var score: LiveScore?
    var locked = false
    var selected = false
    var onOpen: () -> Void
    var onAdd: () -> Void
    var onUnlock: () -> Void

    private var isField: Bool { pick.sport == "f1" || pick.sport == "golf" }
    private var quote: P1BookQuote? { locked ? nil : P1BookQuote.forPick(pick) }
    private var freshScore: LiveScore? {
        guard let score else { return nil }
        if score.isLive, let updated = score.updatedAt, Date().timeIntervalSince(updated) > 7200 { return nil }
        return score
    }
    private var pickedSide: String? {
        let name = pick.pick.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name == pick.homeTeam.lowercased() { return "1" }
        if name == pick.awayTeam.lowercased() { return "2" }
        if ["draw", "tie", "x"].contains(name) { return "X" }
        return nil
    }
    private var whenLabel: String {
        if let sc = freshScore, sc.isLive { return sc.quarter ?? "LIVE" }
        if freshScore?.isFinal == true || !pick.isPending { return "FINAL" }
        if let schedule = pick.localizedScheduleDisplay { return schedule }
        if pick.isToday { return "TODAY" }
        return pick.gameDateValue?.formatted(.dateTime.month(.abbreviated).day()) ?? pick.gameDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LeagueLogo(leagueId: pick.league, fallbackSymbol: "trophy.fill", swatch: P1Board.pill, size: 18)
                Text(p1LeagueLabel(pick)).font(.system(size: 13, weight: .semibold)).foregroundStyle(P1Board.secondary)
                Spacer()
                if !locked && pick.isPending {
                    Button(action: onAdd) {
                        Label(selected ? "Watching" : "Watch", systemImage: selected ? "checkmark" : "plus")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(selected ? Color.p1Lime : .white)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(P1Board.pill))
                    }.buttonStyle(PressableButtonStyle())
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : selected)
                }
            }
            Button(action: onOpen) {
                P1ScoreLines(pick: pick, score: freshScore, locked: locked)
            }.buttonStyle(PressableButtonStyle(scale: 0.98))
            P1DashedRule()
            HStack(spacing: 7) {
                if locked {
                    Button(action: onUnlock) { Label("Unlock PICK1 prediction", systemImage: "lock.fill") }
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.p1Lime)
                } else {
                    Text("PICK1").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color.p1Ink)
                        .padding(.horizontal, 5).padding(.vertical, 3).background(RoundedRectangle(cornerRadius: 4).fill(Color.p1Lime))
                    Text(pick.shortDisplayPick).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.p1Ink2).lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(Int(pick.probability.rounded()))% AI").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.p1Lime)
                }
            }
            if !locked {
                P1SpectrumProgress(value: pick.probability / 100)
                    .accessibilityLabel("AI probability")
                HStack(spacing: 10) {
                    if let forecast = pick.predictedScore, !forecast.isEmpty {
                        Label("Forecast \(forecast)", systemImage: "chart.bar.fill")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.p1Ink2)
                    }
                    Spacer(minLength: 0)
                    if selected {
                        Label("In your watchlist", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.p1Lime)
                    }
                }
                let insight = pick.keyFactor?.trimmingCharacters(in: .whitespacesAndNewlines)
                let preview = (insight?.isEmpty == false ? insight! : pick.reasoning.trimmingCharacters(in: .whitespacesAndNewlines))
                if !preview.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(Color.p1Primary)
                        Text(preview).font(.system(size: 11)).foregroundStyle(Color.p1Ink2)
                            .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                }
            } else {
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(Color.p1Primary)
                        Text("Premium analysis · AI probability · score forecast")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.p1Ink2)
                        Spacer(minLength: 0)
                        Image(systemName: "lock.fill").foregroundStyle(Color.p1Lime)
                    }.padding(11).background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(PressableButtonStyle())
            }
            if let quote {
                Text("Market odds \(String(format: "%.2f", quote.odds)) · \(quote.source)")
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(V4.mute).lineLimit(1)
            }

        }.padding(16)
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(selected ? Color.p1Lime.opacity(0.55) : .clear))
            .animation(reduceMotion ? nil : Pick1Springs.snappy, value: selected)
            .p1Entrance()
    }
}

struct P1BookNavigation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @Binding var tab: P1V4Tab
    var count: Int
    var onSlip: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            item("Sports", "house.fill", .tonight)
            item("Live", "dot.radiowaves.left.and.right", .live)
            Button(action: onSlip) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.p1Lime)
                        .frame(width: 52, height: 42)
                    if count > 0 {
                        Text("\(count)").font(.system(size: 8, weight: .bold))
                            .contentTransition(.numericText()).padding(4)
                            .background(Circle().fill(Color.p1Lime))
                            .foregroundStyle(Color.p1Ink).offset(x: -3, y: 0)
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Watchlist, \(count) picks")
            item("My picks", "bookmark.fill", .yours)
            item("Results", "chart.line.uptrend.xyaxis", .results)
        }
        .padding(.horizontal, 7).padding(.vertical, 5)
        .glassCompat(in: .capsule, tint: Color(hex: "#232323").opacity(0.55))
        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 20)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 4)
        .padding(.bottom, 8)
    }

    private func item(_ title: String, _ icon: String, _ value: P1V4Tab) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : Pick1Springs.snappy) { tab = value }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tab == value ? Color.white : V4.mute)
                .frame(width: 52, height: 42)
                .background {
                    if tab == value {
                        Capsule().fill(Color.white.opacity(0.10))
                            .matchedGeometryEffect(id: "bookTab", in: selection)
                    }
                }
                .contentShape(Rectangle())
        }.buttonStyle(PressableButtonStyle())
            .accessibilityLabel(title)
            .accessibilityAddTraits(tab == value ? [.isSelected, .isButton] : .isButton)
    }
}

struct P1BookSlip: View {
    let picks: [Pick]
    var onRemove: (Pick) -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if picks.isEmpty {
                        ContentUnavailableView("Your watchlist is empty", systemImage: "list.bullet.rectangle",
                                               description: Text("Tap Watch on any game to follow PICK1's prediction and its result here."))
                    } else {
                        Text("Games you're watching").font(.system(size: 20, weight: .bold))
                        Text("Each prediction stays here with its live score, then its graded result.")
                            .font(.system(size: 12)).foregroundStyle(V4.mute)
                        ForEach(picks) { pick in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(p1LeagueLabel(pick).uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(V4.mute)
                                    Spacer()
                                    Button { onRemove(pick) } label: { Image(systemName: "xmark") }
                                        .accessibilityLabel("Remove \(pick.shortDisplayPick)")
                                }
                                Text(pick.displayPick).font(.system(size: 17, weight: .bold))
                                Text("\(pick.homeTeam) · \(pick.awayTeam)").font(.system(size: 11)).foregroundStyle(Color.p1Ink2)
                                HStack {
                                    Text("\(Int(pick.probability.rounded()))% AI probability").foregroundStyle(Color.p1Lime)
                                    Spacer()
                                    if let quote = P1BookQuote.forPick(pick) {
                                        Text("Market odds " + String(format: "%.2f", quote.odds)).monospacedDigit().foregroundStyle(Color.p1Ink2)
                                    }
                                }.font(.system(size: 12, weight: .semibold))
                                Text(pick.isPending ? (pick.localizedScheduleDisplay ?? "Upcoming") : pick.isWin ? "Prediction won" : pick.isLoss ? "Prediction lost" : "Settled")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(!pick.isPending && pick.isWin ? Color.p1Lime : V4.mute)
                            }.padding(16).background(RoundedRectangle(cornerRadius: 12).fill(Color.p1Panel))
                        }
                    }
                }.padding(16)
            }.background(Color.p1Ink).foregroundStyle(.white)
                .navigationTitle("Watchlist · \(picks.count)").navigationBarTitleDisplayMode(.inline)
        }.preferredColorScheme(.dark)
    }
}

struct P1BookDayRail: View {
    let days: [String]
    let picks: [Pick]
    @Binding var selected: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("MATCH DATES · ET").font(.system(size: 8, weight: .semibold)).foregroundStyle(V4.mute).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        Button { withAnimation(reduceMotion ? nil : Pick1Springs.snappy) { selected = day } } label: {
                            VStack(spacing: 5) {
                                Text(P1BookDays.label(day)).font(.system(size: 12, weight: .semibold))
                                Text(p1GamesCount(picks.filter { $0.gameDate == day }.count)).font(.system(size: 9))
                            }.foregroundStyle(selected == day ? Color.p1Ink : Color.p1Ink2).frame(minWidth: 76).padding(.vertical, 10)
                                .background { if selected == day { RoundedRectangle(cornerRadius: 10).fill(Color.white).matchedGeometryEffect(id: "day", in: highlight) } else { RoundedRectangle(cornerRadius: 10).fill(Color.p1Panel) } }
                        }.buttonStyle(PressableButtonStyle()).accessibilityAddTraits(selected == day ? [.isSelected, .isButton] : .isButton)
                    }
                }.padding(.horizontal, 16)
            }
        }
    }
}

// Sportsbook discovery uses published games and captured prices only.
enum P1ExplorePage: String, CaseIterable, Identifiable {
    case markets = "Predictions", leagues = "Leagues", guide = "How it works"
    var id: String { rawValue }
    var icon: String { switch self { case .markets: "square.grid.2x2"; case .leagues: "trophy"; case .guide: "book" } }
    var accent: Color { self == .markets ? Color(hex: "#B596FF") : Color.p1Ink2 }
}

struct P1ExploreRail: View {
    let onSelect: (P1ExplorePage) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(P1ExplorePage.allCases) { page in
                    Button { onSelect(page) } label: {
                        Label(page.rawValue, systemImage: page.icon)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(page.accent)
                            .padding(.horizontal, 13).padding(.vertical, 10)
                            .background(Capsule().fill(page.accent.opacity(0.09)))
                            .overlay(Capsule().strokeBorder(page.accent.opacity(0.3)))
                    }.buttonStyle(PressableButtonStyle())
                }
            }.padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}

struct P1ExploreScreen: View {
    let page: P1ExplorePage
    let games: [Pick]
    let picks: [Pick]
    let onOpen: (Pick) -> Void
    let onAdd: (Pick) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var day = P1BookDays.key()
    @State private var search = ""
    @State private var category = "All"
    @State private var pricedOnly = false
    private var active: [Pick] { picks.filter { $0.isPending && $0.gameDate == day && (search.isEmpty || ($0.homeTeam + $0.awayTeam + $0.league).localizedCaseInsensitiveContains(search)) } }
    private var leagues: [String] { Array(Set(games.map(\.league))).sorted() }
    private func group(_ label: String) -> String {
        let text = label.lowercased()
        if text.contains("total") || text.contains("over") || text.contains("under") { return "Totals" }
        if text.contains("spread") || text.contains("handicap") || text.contains("margin") { return "Handicaps" }
        if text.contains("player") || text.contains("scorer") || text.contains("points") || text.contains("rebounds") { return "Players" }
        return "Other"
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introduction
                    if page == .markets {
                        P1BookDayRail(days: P1BookDays.dates(picks: games), picks: games, selected: $day)
                        TextField("Search teams or leagues", text: $search).font(.system(size: 14))
                            .padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.p1Panel2))
                    }
                    switch page {
                    case .markets: markets
                    case .leagues: leagueList
                    case .guide: guide
                    }
                }.padding(16)
            }.background(Color.p1Ink).foregroundStyle(.white)
                .navigationTitle(page.rawValue).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.tint(Color.p1Lime) } }
        }.preferredColorScheme(.dark)
    }
    private var introduction: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PICK1").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Color.p1Lime)
            Text(page == .markets ? "Every prediction for the day" : page == .leagues ? "Explore every competition" : "How PICK1 reads a game")
                .font(.system(size: 28, weight: .bold))
            Text(page == .markets ? "Match winners, totals and player projections, each with PICK1's model probability." : page == .leagues ? "Confirmed fixtures and PICK1 analysis, organised by league." : "What each number means, and how every prediction is graded in public.")
                .font(.system(size: 13)).foregroundStyle(Color.p1Ink2)
        }
    }
    @ViewBuilder private var markets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(["All", "Winners", "Totals", "Handicaps", "Players", "Other"], id: \.self) { value in
                    Button { category = value } label: {
                        Text(value).font(.system(size: 12, weight: .semibold)).padding(10)
                            .background(Capsule().fill(category == value ? Color.p1Lime : Color.p1Panel2))
                            .foregroundStyle(category == value ? Color.p1Ink : Color.white)
                    }.buttonStyle(PressableButtonStyle())
                }
            }
        }
        Toggle("Only with market odds", isOn: $pricedOnly).font(.system(size: 12)).tint(Color.p1Lime)
        let rows = active.filter { p in
            let winner = (category == "All" || category == "Winners") && (!pricedOnly || P1BookQuote.forPick(p) != nil)
            let props = (p.bettingProps ?? []).contains { (category == "All" || group($0.label) == category) && (!pricedOnly || !$0.validBooks.isEmpty || ($0.odds ?? 0) > 1) }
            return winner || props
        }
        if rows.isEmpty { empty("No published predictions match these filters.") }
        ForEach(rows) { pick in
            VStack(alignment: .leading, spacing: 14) {
                matchHeader(pick)
                if (category == "All" || category == "Winners") && (!pricedOnly || P1BookQuote.forPick(pick) != nil) {
                    Text("MATCH WINNER").font(.system(size: 10, weight: .bold)).foregroundStyle(V4.mute)
                    Text(pick.displayPick).font(.system(size: 18, weight: .bold))
                    Text("\(Int(pick.probability.rounded()))% model probability").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.p1Lime)
                    Button { onAdd(pick) } label: { Label("Watch this game", systemImage: "plus.circle").font(.system(size: 12, weight: .semibold)) }.tint(Color.p1Lime)
                }
                ForEach((pick.bettingProps ?? []).filter { (category == "All" || group($0.label) == category) && (!pricedOnly || !$0.validBooks.isEmpty || ($0.odds ?? 0) > 1) }) { prop in
                    Divider().overlay(V4.line)
                    HStack { Text(prop.label).font(.system(size: 12, weight: .semibold)); Spacer(); if let odds = prop.validBooks.first?.odds ?? prop.odds, odds > 1 { Text(String(format: "%.2f", odds)).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.p1Lime) } }
                    Text(prop.value).font(.system(size: 16, weight: .bold))
                    if let probability = prop.probability { Text("\(probability)% model probability").font(.system(size: 12)).foregroundStyle(Color.p1Lime) }
                    if let hint = prop.hint, !hint.isEmpty { Text(hint).font(.system(size: 12)).foregroundStyle(Color.p1Ink2) }
                }
            }.padding(16).background(RoundedRectangle(cornerRadius: 16).fill(Color.p1Panel))
        }
    }
    @ViewBuilder private var leagueList: some View {
        ForEach(leagues, id: \.self) { league in
            let fixtures = games.filter { $0.league == league }.sorted { ($0.gameDate, $0.startTime ?? "") < ($1.gameDate, $1.startTime ?? "") }
            NavigationLink {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(fixtures.count == 1 ? "1 published fixture" : "\(fixtures.count) published fixtures").font(.system(size: 13)).foregroundStyle(V4.mute)
                        ForEach(fixtures) { p in
                            VStack(alignment: .leading, spacing: 10) {
                                matchHeader(p)
                                Text("\(p.bettingProps?.count ?? 0) more projections · \(p.isPending ? "Upcoming" : "Final")").font(.system(size: 12)).foregroundStyle(V4.mute)
                                if picks.contains(where: { $0.id == p.id }) { Button("View match & analysis") { onOpen(p) }.tint(Color.p1Lime) }
                                else { Text("Prediction available with PICK1 Pro").font(.system(size: 12)).foregroundStyle(Color.p1Lime) }
                            }.padding(16).background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
                        }
                    }.padding(16)
                }.background(Color.p1Ink).foregroundStyle(.white).navigationTitle(league)
            } label: {
                HStack {
                    LeagueLogo(leagueId: league, fallbackSymbol: "trophy.fill", swatch: Color.p1Panel2, size: 32)
                    VStack(alignment: .leading, spacing: 4) { Text(league).font(.system(size: 16, weight: .bold)); Text("\(fixtures.filter { $0.isPending }.count) upcoming · \(Set(fixtures.map(\.gameDate)).count) match days").font(.system(size: 12)).foregroundStyle(V4.mute) }
                    Spacer(); Image(systemName: "chevron.right").font(.system(size: 12))
                }.foregroundStyle(.white).padding(18).background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
            }.buttonStyle(PressableButtonStyle())
        }
        if leagues.isEmpty { empty("Competitions appear when fixtures are published.") }
    }
    @ViewBuilder private var guide: some View {
        ForEach([
            ["AI probability", "PICK1's model estimate that the selection happens. 70% means the model expects it about 7 times out of 10, so 3 times out of 10 it does not. It is never a guarantee."],
            ["Market odds", "The price the market showed for the same selection when PICK1 captured it, shown for context only. PICK1 does not take bets and does not link to bookmakers."],
            ["Match winner", "The team or player PICK1 expects to win. In football a draw can also be the call."],
            ["Totals and handicaps", "Over or under a stated line, or a result adjusted by a margin. The exact line is part of the prediction."],
            ["Player projections", "A specific player's statistic or scoring outcome, graded on the official box score."],
            ["Your watchlist", "Tap Watch on a game to follow it: live score while it plays, graded result once it ends."],
            ["Public record", "Every prediction is published before kickoff and graded afterwards, wins and losses alike, in Results. Money figures in the record use a flat base of $100 a pick."]
        ], id: \.first) { article in
            DisclosureGroup {
                Text(article[1]).font(.system(size: 14)).foregroundStyle(Color.p1Ink2).padding(.top, 8)
            } label: { Text(article[0]).font(.system(size: 16, weight: .semibold)) }
                .tint(Color.p1Lime).padding(18).background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
        }
    }
    private func matchHeader(_ pick: Pick) -> some View {
        Button { if picks.contains(where: { $0.id == pick.id }) { onOpen(pick) } } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(p1LeagueLabel(pick).uppercased()) · \(P1BookDays.label(pick.gameDate))\(pick.startTimeDisplay.map { " · " + $0 } ?? "")").font(.system(size: 10, weight: .semibold)).foregroundStyle(V4.mute)
                HStack { HStack(spacing: 10) { Text(pick.homeTeam).frame(maxWidth: .infinity); Text("VS").font(.system(size: 9)).foregroundStyle(V4.mute); Text(pick.awayTeam).frame(maxWidth: .infinity) }.font(.system(size: 14, weight: .bold)).lineLimit(2).multilineTextAlignment(.center); Spacer(); Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Color.p1Lime) }
            }.foregroundStyle(.white)
        }.buttonStyle(PressableButtonStyle())
    }
    private func empty(_ text: String) -> some View {
        Label(text, systemImage: "calendar").font(.system(size: 14)).foregroundStyle(Color.p1Ink2).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 16).fill(Color.p1Panel))
    }
}


struct P1FanaticsEvents: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let picks: [Pick]
    var scores: [LiveScore] = []
    let onOpen: (Pick) -> Void
    var body: some View {
        let games = picks.filter { $0.sport != "f1" && $0.sport != "golf" }
        if !games.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Featured events").font(.system(size: 20, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(games) { pick in
                            Button { onOpen(pick) } label: { card(pick) }
                                .buttonStyle(PressableButtonStyle(scale: 0.97))
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content.opacity(reduceMotion || phase.isIdentity ? 1 : 0.85)
                                }
                                .p1Entrance(delay: min(Double(games.firstIndex(where: { $0.id == pick.id }) ?? 0) * 0.04, 0.2))
                        }
                    }.scrollTargetLayout().padding(.horizontal, 16)
                }.scrollTargetBehavior(.viewAligned)
            }
        }
    }
    private func card(_ pick: Pick) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            P1ScoreLines(pick: pick, score: scores.first(where: { $0.gameId == pick.gameId }), compact: true)
            if !pick.isPending {
                P1DashedRule()
                P1BoardPill(title: pick.isWin ? "PICK1 won" : pick.isLoss ? "PICK1 lost" : "Settled",
                            icon: pick.isWin ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis",
                            tint: pick.isWin ? Color.p1Lime : .white)
            }
        }
        .padding(15).frame(width: 214, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
    }
}

// Schedules are independent of predictions: an unanalysed fixture never gets a synthetic pick or price.
private struct P1ScheduledEvent: Identifiable, Sendable {
    let id: String
    let sport: String
    let league: String
    let home: String
    let away: String
    let date: Date
    let status: String
    let venue: String
}

struct P1DailySchedule: View {
    let published: [Pick]
    let day: String
    let sport: String
    let search: String
    @State private var events: [P1ScheduledEvent] = []
    @State private var loading = false
    @State private var failed = 0
    @State private var expanded = false
    private static let leagues: [(String, String, String)] = [
        ("football", "NFL", "football/nfl"), ("football", "College Football", "football/college-football"),
        ("basketball", "NBA", "basketball/nba"), ("basketball", "WNBA", "basketball/wnba"),
        ("basketball", "College Basketball", "basketball/mens-college-basketball"),
        ("baseball", "MLB", "baseball/mlb"), ("hockey", "NHL", "hockey/nhl"),
        ("soccer", "Premier League", "soccer/eng.1"), ("soccer", "Ligue 1", "soccer/fra.1"),
        ("soccer", "La Liga", "soccer/esp.1"), ("soccer", "Bundesliga", "soccer/ger.1"),
        ("soccer", "Serie A", "soccer/ita.1"), ("soccer", "MLS", "soccer/usa.1"),
        ("soccer", "Champions League", "soccer/uefa.champions"), ("soccer", "Europa League", "soccer/uefa.europa"),
        ("tennis", "ATP", "tennis/atp"), ("tennis", "WTA", "tennis/wta"),
        ("f1", "F1", "racing/f1")
    ]
    private var filtered: [P1ScheduledEvent] {
        events.filter { event in
            guard ![event.home, event.away].contains(where: { ["tbd", "unknown", "tba"].contains($0.lowercased()) }), !event.status.lowercased().contains("cancel") else { return false }
            let matchesSearch = search.isEmpty || "\(event.home) \(event.away) \(event.league)".localizedCaseInsensitiveContains(search)
            let alreadyPublished = published.contains { pick in
                pick.gameDate == day && pick.sport == event.sport && (pick.gameId?.hasSuffix("-" + event.id) == true ||
                    (pick.homeTeam.caseInsensitiveCompare(event.home) == .orderedSame && pick.awayTeam.caseInsensitiveCompare(event.away) == .orderedSame) ||
                    (pick.sport == "f1" && pick.awayTeam.caseInsensitiveCompare(event.home) == .orderedSame))
            }
            return matchesSearch && !alreadyPublished
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(Pick1Springs.smooth) { expanded.toggle() } } label: {
                HStack {
                    Image(systemName: "calendar").foregroundStyle(Color.p1Primary)
                    Text("More scheduled games").font(.system(size: 16, weight: .bold))
                    Spacer()
                    if loading { ProgressView().tint(.white) }
                    else { Text(p1GamesCount(filtered.count)).font(.system(size: 12)) }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.system(size: 11))
                }.foregroundStyle(.white)
            }.buttonStyle(PressableButtonStyle())
            Text("Fixtures awaiting PICK1 analysis · published picks below").font(.system(size: 11)).foregroundStyle(Color.p1Ink2)
            if expanded || !search.isEmpty {
                ForEach(filtered) { event in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(event.league.uppercased()).foregroundStyle(Color.p1Lime)
                            Spacer()
                            Text(event.date.formatted(date: .omitted, time: .shortened))
                        }.font(.system(size: 10, weight: .semibold))
                        HStack(spacing: 10) { Text(event.home).frame(maxWidth: .infinity); Text("VS").font(.system(size: 9, weight: .bold)).foregroundStyle(V4.mute); Text(event.away).frame(maxWidth: .infinity) }.font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
                        Text(event.status + (event.venue.isEmpty ? "" : " · " + event.venue)).font(.system(size: 11)).foregroundStyle(Color.p1Ink2)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.p1Panel2))
                }
                if !loading && filtered.isEmpty {
                    Text(failed > 0 ? "Some schedules could not load. Tap Retry." : (Self.leagues.contains(where: { sport == "all" || $0.0 == sport }) ? "No fixtures returned for this date and sport." : "Full schedules for this sport are not connected yet. Published PICK1 events appear below."))
                        .font(.system(size: 12)).foregroundStyle(Color.p1Ink2)
                }
                if failed > 0 { Button("Retry schedule") { Task { await load() } }.tint(Color.p1Primary) }
                Text("Schedule source: ESPN. Times shown in your local timezone. Predictions appear once PICK1 publishes them.")
                    .font(.system(size: 10)).foregroundStyle(Color.p1Ink2)
            }
        }.padding(14).background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#202022")))
        .task(id: day + sport) { await load() }
    }
    @MainActor private func load() async {
        loading = true; events = []; failed = 0
        let paths = Self.leagues.filter { sport == "all" || $0.0 == sport }
        let results = await withTaskGroup(of: ([P1ScheduledEvent], Bool).self) { group in
            for (_, league, path) in paths {
                group.addTask { await Self.fetch(day: day, league: league, path: path) }
            }
            var rows: [P1ScheduledEvent] = []; var errors = 0
            for await (items, success) in group { rows += items; if !success { errors += 1 } }
            return (rows, errors)
        }
        guard !Task.isCancelled else { return }
        var seen = Set<String>()
        events = results.0.filter { seen.insert($0.id).inserted }.sorted { $0.date < $1.date }
        failed = results.1; loading = false
    }
    private static func fetch(day: String, league: String, path: String) async -> ([P1ScheduledEvent], Bool) {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(path)/scoreboard?dates=\(day.replacingOccurrences(of: "-", with: ""))&limit=1000") else { return ([], false) }
        do {
            var request = URLRequest(url: url); request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let raw = root["events"] as? [[String: Any]] else { return ([], false) }
            let formatter = ISO8601DateFormatter()
            let minutes = DateFormatter(); minutes.locale = Locale(identifier: "en_US_POSIX"); minutes.dateFormat = "yyyy-MM-dd'T'HH:mmX"
            let dayFormatter = DateFormatter(); dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.timeZone = TimeZone(identifier: "America/New_York"); dayFormatter.dateFormat = "yyyy-MM-dd"
            if path.hasPrefix("tennis/") || path == "racing/f1" {
                var rows: [P1ScheduledEvent] = []
                for event in raw {
                    let competitions: [[String: Any]]
                    if path.hasPrefix("tennis/") {
                        competitions = (event["groupings"] as? [[String: Any]] ?? []).filter {
                            (($0["grouping"] as? [String: Any])?["slug"] as? String ?? "") == (path == "tennis/atp" ? "mens-singles" : "womens-singles")
                        }.flatMap { $0["competitions"] as? [[String: Any]] ?? [] }
                    } else {
                        competitions = (event["competitions"] as? [[String: Any]] ?? []).filter {
                            (($0["type"] as? [String: Any])?["abbreviation"] as? String) == "Race"
                        }
                    }
                    for c in competitions {
                        guard let id = c["id"] as? String, let ds = (c["date"] ?? c["startDate"]) as? String,
                              let date = formatter.date(from: ds) ?? minutes.date(from: ds), dayFormatter.string(from: date) == day else { continue }
                        let competitors = c["competitors"] as? [[String: Any]] ?? []
                        let type = (c["status"] as? [String: Any])?["type"] as? [String: Any]
                        let home: String; let away: String
                        if path == "racing/f1" {
                            home = event["name"] as? String ?? "Formula 1"; away = "Race"
                        } else {
                            guard competitors.count == 2 else { continue }
                            let h = competitors.first { $0["homeAway"] as? String == "home" } ?? competitors[0]
                            let a = competitors.first { $0["homeAway"] as? String == "away" } ?? competitors[1]
                            guard let hn = (h["athlete"] as? [String: Any])?["displayName"] as? String,
                                  let an = (a["athlete"] as? [String: Any])?["displayName"] as? String else { continue }
                            home = hn; away = an
                        }
                        rows.append(P1ScheduledEvent(id: id, sport: path == "racing/f1" ? "f1" : String(path.split(separator: "/").first ?? ""), league: league, home: home, away: away, date: date,
                            status: type?["shortDetail"] as? String ?? "Scheduled", venue: event["name"] as? String ?? ""))
                    }
                }
                return (rows, true)
            }
            let rows = raw.compactMap { e -> P1ScheduledEvent? in
                guard let id = e["id"] as? String, let ds = e["date"] as? String, let date = formatter.date(from: ds) ?? minutes.date(from: ds),
                      let c = (e["competitions"] as? [[String: Any]])?.first,
                      let competitors = c["competitors"] as? [[String: Any]],
                      let h = competitors.first(where: { $0["homeAway"] as? String == "home" }),
                      let a = competitors.first(where: { $0["homeAway"] as? String == "away" }),
                      let home = (h["team"] as? [String: Any])?["displayName"] as? String,
                      let away = (a["team"] as? [String: Any])?["displayName"] as? String else { return nil }
                // ESPN scoreboard dates are US Eastern. Verify the actual event date too.
                let df = DateFormatter(); df.timeZone = TimeZone(identifier: "America/New_York"); df.dateFormat = "yyyy-MM-dd"
                guard df.string(from: date) == day else { return nil }
                let type = (e["status"] as? [String: Any])?["type"] as? [String: Any]
                return P1ScheduledEvent(id: id, sport: path == "racing/f1" ? "f1" : String(path.split(separator: "/").first ?? ""), league: league, home: home, away: away, date: date,
                    status: type?["shortDetail"] as? String ?? "Scheduled", venue: (c["venue"] as? [String: Any])?["fullName"] as? String ?? "")
            }
            return (rows, true)
        } catch { return ([], false) }
    }
}

struct P1LivePickStatus: View {
    let home: String
    let away: String
    let selection: String
    let homeScore: Int
    let awayScore: Int
    let yours: Bool
    var demo = false
    private var difference: Int? {
        let name = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.caseInsensitiveCompare(home) == .orderedSame { return homeScore - awayScore }
        if name.caseInsensitiveCompare(away) == .orderedSame { return awayScore - homeScore }
        return nil
    }
    var body: some View {
        if let difference {
            let leading = difference > 0
            VStack(alignment: .leading, spacing: 5) {
                if yours {
                    Label(difference == 0 ? "Your pick is tied" : leading ? "Your pick is leading" : "Your pick is trailing",
                          systemImage: leading ? "checkmark.circle.fill" : difference == 0 ? "equal.circle" : "clock")
                }
                Label(difference == 0 ? "PICK1’s pick is tied" : leading ? "PICK1’s pick is leading" : "PICK1’s pick is trailing",
                      systemImage: leading ? "sparkles" : "chart.line.uptrend.xyaxis")
                Text(demo ? "Simulated score · not a settled win" : "Current score · result not yet settled")
                    .font(.system(size: 9, weight: .regular)).foregroundStyle(Color.p1Mute)
            }.font(.system(size: 12, weight: .bold))
                .foregroundStyle(leading ? Color.p1Lime : Color.p1Ink2)
                .frame(maxWidth: .infinity, alignment: .leading).padding(11)
                .background(RoundedRectangle(cornerRadius: 9).fill(leading ? Color.p1Lime.opacity(0.09) : Color.p1Panel))
        }
    }
}

struct P1SpectrumProgress: View {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var fraction: CGFloat { value.isFinite ? CGFloat(min(max(value, 0), 1)) : 0 }
    private let colors = [Color(hex: "#F04452"), Color(hex: "#FF8A3D"), Color(hex: "#F6D64A"), Color.p1Lime, Color(hex: "#35D9BE"), Color(hex: "#49C8F5")]
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                spectrum.opacity(0.18)
                spectrum.mask(alignment: .leading) {
                    Rectangle().frame(width: width * fraction)
                }
                Capsule().fill(.white).frame(width: 3, height: 12)
                    .offset(x: min(max(width * fraction - 1.5, 0), max(width - 3, 0)))
            }.frame(height: 12)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: fraction)
        }.frame(height: 12)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int((Double(fraction) * 100).rounded())) percent")
    }
    private var spectrum: some View {
        Capsule()
            .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .frame(height: 6)
    }
}
