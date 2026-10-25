import SwiftUI
import UserNotifications

struct P1SportsbookDetail: View {
    let pick: Pick
    var liveScore: LiveScore?
    var onClose: () -> Void
    var openTrackSheet = false
    @EnvironmentObject private var favorites: FavoritesStore
    @StateObject private var tracker = BetTracker.shared
    @State private var tab = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabHighlight
    @State private var tracking = false
    @State private var sharing = false
    @State private var marketSearch = ""
    @State private var pricedOnly = false
    @State private var marketCategory = "All"
    @State private var reminderMessage: String?
    @State private var reminderOn = false
    @AppStorage("sportsbookSlipIDs") private var slipIDs = ""
    private var inSlip: Bool { slipIDs.split(separator: ",").contains(Substring(pick.id.uuidString)) }
    private var quote: P1BookQuote? { P1BookQuote.forPick(pick) }
    private var score: LiveScore? {
        guard let liveScore else { return nil }
        if liveScore.isLive, let updated = liveScore.updatedAt, Date().timeIntervalSince(updated) > 7200 { return nil }
        return liveScore
    }
    private var field: Bool { pick.sport == "f1" || pick.sport == "golf" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 32, height: 36) }.accessibilityLabel("Back")
                VStack(alignment: .leading, spacing: 3) {
                    Text(p1LeagueLabel(pick)).font(.system(size: 13, weight: .bold))
                    Text(v4Name(pick.sport)).font(.system(size: 10)).foregroundStyle(V4.mute)
                }
                Spacer()
                Button { favorites.set(pick, on: !favorites.contains(pick.id)) } label: {
                    Image(systemName: favorites.contains(pick.id) ? "star.fill" : "star").foregroundStyle(Color.p1Lime).frame(width: 36, height: 36)
                }.accessibilityLabel("Follow match")
            }.foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 8)
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if pick.isWin && !pick.isPending { P1SettledWinReveal(pick: pick) }
                    scoreboard.p1Entrance()
                    prediction.p1Entrance(delay: 0.08)
                    followControls
                    HStack(spacing: 0) {
                        ForEach(Array(["Predictions", "PICK1 analysis", "Stats"].enumerated()), id: \.offset) { index, title in
                            Button { withAnimation(reduceMotion ? nil : Pick1Springs.snappy) { tab = index } } label: {
                                VStack(spacing: 10) {
                                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(tab == index ? Color.white : V4.mute)
                                    ZStack { Rectangle().fill(V4.line).frame(height: 2); if tab == index { Rectangle().fill(Color.p1Primary).frame(height: 2).matchedGeometryEffect(id: "detailTab", in: tabHighlight) } }
                                }.frame(maxWidth: .infinity)
                            }.buttonStyle(PressableButtonStyle()).accessibilityAddTraits(tab == index ? [.isSelected, .isButton] : .isButton)
                        }
                    }
                    Group {
                        if tab == 0 { markets }
                        else if tab == 1 { analysis }
                        else { stats }
                    }.id(tab)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
                        .animation(reduceMotion ? nil : Pick1Springs.smooth, value: tab)
                    if pick.isWin {
                        Button { sharing = true } label: { Label("Share result", systemImage: "square.and.arrow.up").font(.system(size: 13, weight: .semibold)) }.foregroundStyle(Color.p1Lime)
                    }
                }.padding(16)
            }
            .onAppear {
                #if DEBUG
                if CommandLine.arguments.contains("-showMarketPicks") {
                    DispatchQueue.main.async { proxy.scrollTo("marketPicks", anchor: .top) }
                }
                #endif
            }
            }
            if pick.isPending {
                VStack(spacing: 6) {
                    HStack {
                        Button { toggleSlip() } label: { Label(inSlip ? "Remove from watchlist" : "Add to watchlist", systemImage: inSlip ? "checkmark" : "plus") }
                        Spacer()
                        Button { tracking = true } label: { Label(tracker.isTracked(pick.id) ? "Edit tracked pick" : "Track this pick", systemImage: "square.and.pencil") }
                    }.font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.p1Ink2).padding(.vertical, 9)
                }.padding(.horizontal, 16).padding(.top, 10).background(Color.p1Ink)
            }
        }.background(P1ArenaBackdrop()).foregroundStyle(.white).preferredColorScheme(.dark)
            .sheet(isPresented: $sharing) { ShareWinSheet(pick: pick) }
            .sheet(isPresented: $tracking) {
                TrackBetSheet(pick: pick, accent: .p1Lime,
                              onTrack: { stake in Task { await tracker.track(pick: pick, stake: stake) } },
                              isTracked: tracker.isTracked(pick.id),
                              onUntrack: { Task { await tracker.untrack(pickId: pick.id) } })
                    .presentationDetents([.height(tracker.isTracked(pick.id) ? 480 : 420)])
            }
            .sensoryFeedback(.selection, trigger: tab)
            .sensoryFeedback(.selection, trigger: inSlip)
            .animation(reduceMotion ? nil : Pick1Springs.snappy, value: inSlip)
            .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
            .onAppear { tracking = openTrackSheet; Analytics.pickViewed(league: pick.league) }
            .task { if !tracker.loaded { await tracker.load() } }
    }

    private var scoreboard: some View {
        VStack(spacing: 18) {
            HStack {
                Text(score?.isLive == true ? "● LIVE · \(score?.quarter ?? "")" : score?.isFinal == true || !pick.isPending ? "FINAL" : pick.localizedScheduleDisplay ?? pick.gameDate)
                    .foregroundStyle(score?.isLive == true ? Color.p1Red : V4.mute)
                Spacer(); Text(p1LeagueLabel(pick).uppercased()).foregroundStyle(V4.mute)
            }.font(.system(size: 10, weight: .semibold))
            if field {
                Text(pick.homeTeam == "Field" ? pick.awayTeam : pick.homeTeam).font(.system(size: 21, weight: .bold))
                Text("Tournament winner").font(.system(size: 12)).foregroundStyle(V4.mute)
            } else {
                HStack(spacing: 8) {
                    competitor(pick.homeTeam)
                    VStack(spacing: 5) {
                        Text(scoreText).font(.system(size: 27, weight: .heavy, design: .monospaced))
                        Text(score?.isLive == true ? "IN PLAY" : !pick.isPending ? "RESULT" : "MATCH").font(.system(size: 8, weight: .bold)).foregroundStyle(V4.mute)
                    }.frame(width: 100)
                    competitor(pick.awayTeam)
                }
            }
        }.padding(16).background(RoundedRectangle(cornerRadius: 10).fill(Color.p1Panel))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(V4.line))
    }
    private var scoreText: String {
        if let h = score?.homeScore ?? pick.homeScore, let a = score?.awayScore ?? pick.awayScore { return "\(h) : \(a)" }
        return "VS"
    }
    private func competitor(_ name: String) -> some View {
        VStack(spacing: 8) {
            TeamLogo(sport: pick.sport, team: name, size: .small).scaleEffect(1.2).frame(width: 58, height: 58)
            Text(teamShortName(name, sport: pick.sport)).font(.system(size: 15, weight: .bold)).multilineTextAlignment(.center).lineLimit(2)
        }.frame(maxWidth: .infinity)
    }
    private var prediction: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text("PICK1 PREDICTION").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(Color.p1Lime)
                Text(pick.displayPick).font(.system(size: 18, weight: .bold))
                if let projected = pick.predictedScore { Text("Model score forecast: \(projected)").font(.system(size: 10)).foregroundStyle(V4.mute) }
            }
            Spacer(minLength: 8)
            VStack(spacing: 4) {
                Text("\(Int(pick.probability.rounded()))%").font(.system(size: 28, weight: .heavy)).foregroundStyle(Color.p1Lime)
                Text("AI PROBABILITY").font(.system(size: 7, weight: .semibold)).foregroundStyle(V4.mute)
            }
        }.padding(14).background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: "#7955D8").opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color(hex: "#7955D8").opacity(0.35)))
    }
    private var markets: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(field ? "Tournament winner" : "Match winner")
            HStack {
                Text(pick.displayPick).font(.system(size: 16, weight: .bold))
                Spacer()
                Text("\(Int(pick.probability.rounded()))% AI").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.p1Lime)
            }.padding(14).background(RoundedRectangle(cornerRadius: 9).fill(Color.p1Panel2))
            if let quote {
                Text("Market odds \(String(format: "%.2f", quote.odds)) · \(quote.source), shown for context")
                    .font(.system(size: 10)).foregroundStyle(V4.mute)
            }
            if let props = pick.bettingProps, !props.isEmpty {
                HStack { title("More PICK1 projections"); Spacer(); Text(props.count == 1 ? "1 projection" : "\(props.count) projections").font(.system(size: 10)).foregroundStyle(V4.mute) }.id("marketPicks")
                TextField("Search totals, handicaps, players…", text: $marketSearch)
                    .font(.system(size: 12)).padding(12).background(RoundedRectangle(cornerRadius: 9).fill(Color.p1Panel2))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["All", "Totals", "Handicaps", "Players", "Other"], id: \.self) { category in
                            Button { marketCategory = category } label: {
                                Text(category).font(.system(size: 12, weight: .semibold)).padding(9)
                                    .background(Capsule().fill(marketCategory == category ? Color.p1Lime : Color.p1Panel2))
                                    .foregroundStyle(marketCategory == category ? Color.p1Ink : .white)
                            }.buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                Toggle("Only with market odds", isOn: $pricedOnly).font(.system(size: 12)).tint(Color.p1Lime)
                let filtered = props.filter { prop in
                    (marketCategory == "All" || category(for: prop) == marketCategory) && (marketSearch.isEmpty || "\(prop.label) \(prop.value) \(prop.participant ?? "")".localizedCaseInsensitiveContains(marketSearch)) && (!pricedOnly || !prop.validBooks.isEmpty || (prop.odds ?? 0) > 1)
                }
                if filtered.isEmpty { Text("No matching projections.").font(.system(size: 12)).foregroundStyle(V4.mute) }
                ForEach(filtered) { prop in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(prop.label).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Spacer()
                            Text("PICK1").font(.system(size: 8, weight: .heavy)).foregroundStyle(Color(hex: "#C3ACFF"))
                                .padding(5).background(RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#7955D8").opacity(0.2)))
                        }
                        Divider().overlay(V4.line)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("PICK1 PICK").font(.system(size: 8, weight: .heavy)).tracking(1).foregroundStyle(Color.p1Lime)
                                Text(prop.value).font(.system(size: 16, weight: .bold))
                            }
                            Spacer()
                            if let probability = prop.probability, (1...99).contains(probability) {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(probability)%").font(.system(size: 21, weight: .heavy)).foregroundStyle(Color.p1Lime)
                                    Text("AI PROBABILITY").font(.system(size: 7)).foregroundStyle(V4.mute)
                                }
                            } else { Text("MODEL PROJECTION").font(.system(size: 8)).foregroundStyle(V4.mute) }
                        }
                        if let hint = prop.hint { Text(hint).font(.system(size: 11)).foregroundStyle(V4.mute) }
                        if let odds = prop.validBooks.first?.odds ?? prop.odds, odds.isFinite, odds > 1 {
                            Text("Market odds \(String(format: "%.2f", odds))").font(.system(size: 10)).foregroundStyle(V4.mute)
                        }
                    }.padding(14).background(RoundedRectangle(cornerRadius: 11).fill(Color.p1Panel))
                        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(V4.line))
                        .p1Entrance(delay: 0.03)
                }
            }

        }
    }
    private var analysis: some View {
        VStack(alignment: .leading, spacing: 15) {
            title("Why PICK1 backs this selection")
            if let factor = pick.keyFactor, !factor.isEmpty {
                Label(factor, systemImage: "sparkles").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.p1Lime).padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 10).fill(Color.p1Panel))
            }
            if let date = pick.createdAt {
                Text("Analysis published " + date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10)).foregroundStyle(V4.mute)
            }
            Text(pick.reasoning).font(.system(size: 13)).lineSpacing(5).foregroundStyle(Color.p1Ink2)
            if let factors = pick.factors {
                ForEach(factors) { factor in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(factor.label).font(.system(size: 12, weight: .bold))
                        Text(factor.value).font(.system(size: 11)).foregroundStyle(V4.mute)
                        ProgressView(value: Double(min(100, max(0, factor.strength))), total: 100).tint(.p1Lime)
                    }.padding(13).background(RoundedRectangle(cornerRadius: 9).fill(Color.p1Panel))
                }
            }
            Text("Model predictions are estimates, not guaranteed results.").font(.system(size: 10)).foregroundStyle(V4.mute)
        }
    }
    private var stats: some View {
        VStack(alignment: .leading, spacing: 13) {
            title("Match information")
            if let facts = pick.matchupFacts, !facts.isEmpty {
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: 6) { Text(fact.label).font(.system(size: 11, weight: .bold)); Text(fact.value).font(.system(size: 12)).foregroundStyle(Color.p1Ink2) }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(13).background(RoundedRectangle(cornerRadius: 9).fill(Color.p1Panel))
                }
            } else { Text("Detailed match statistics are not available for this event.").font(.system(size: 12)).foregroundStyle(V4.mute) }
            if let drivers = pick.fieldOdds {
                ForEach(drivers) { driver in HStack { Text(driver.name); Spacer(); Text("\(Int(driver.win.rounded()))% AI win").foregroundStyle(Color.p1Lime) }.font(.system(size: 12)).padding(12).background(Color.p1Panel) }
            }
        }
    }
    private func category(for prop: BettingProp) -> String {
        let key = (prop.marketKey ?? prop.label).lowercased()
        if key.contains("player") || prop.participant != nil { return "Players" }
        if key.contains("total") || key.contains("over") || key.contains("under") { return "Totals" }
        if key.contains("spread") || key.contains("handicap") { return "Handicaps" }
        return "Other"
    }
    private var followControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Follow your teams & leagues").font(.system(size: 13, weight: .bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(Set([pick.homeTeam, pick.awayTeam])).sorted(), id: \.self) { name in
                        Button { favorites.toggleTeam(name) } label: {
                            Label(teamShortName(name, sport: pick.sport), systemImage: favorites.teams.contains(name) ? "heart.fill" : "heart")
                                .font(.system(size: 11, weight: .semibold)).padding(9).background(Capsule().fill(Color.p1Panel2))
                        }.tint(Color.p1Lime)
                            .accessibilityLabel((favorites.teams.contains(name) ? "Unfollow " : "Follow ") + name)
                            .accessibilityAddTraits(favorites.teams.contains(name) ? [.isSelected, .isButton] : .isButton)
                    }
                    Button { favorites.toggleLeague(pick.league) } label: {
                        Label(p1LeagueLabel(pick), systemImage: favorites.leagues.contains(pick.league) ? "star.fill" : "star")
                            .font(.system(size: 11, weight: .semibold)).padding(9).background(Capsule().fill(Color.p1Panel2))
                    }.tint(Color.p1Lime)
                        .accessibilityLabel((favorites.leagues.contains(pick.league) ? "Unfollow " : "Follow ") + pick.league)
                        .accessibilityAddTraits(favorites.leagues.contains(pick.league) ? [.isSelected, .isButton] : .isButton)
                }
            }
            if pick.isPending {
                Button { Task { await toggleReminder() } } label: {
                    Label(reminderOn ? "Remove kickoff reminder" : "Remind me before kickoff", systemImage: reminderOn ? "bell.fill" : "bell")
                        .font(.system(size: 12, weight: .semibold))
                }.tint(Color.p1Ink2)
            }
            if let reminderMessage { Text(reminderMessage).font(.system(size: 10)).foregroundStyle(V4.mute) }
        }.padding(14).background(RoundedRectangle(cornerRadius: 12).fill(Color.p1Panel))
            .task {
                let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
                reminderOn = pending.contains { $0.identifier == "kickoff-" + pick.id.uuidString }
            }
    }
    @MainActor private func toggleReminder() async {
        let center = UNUserNotificationCenter.current()
        let id = "kickoff-" + pick.id.uuidString
        if reminderOn {
            center.removePendingNotificationRequests(withIdentifiers: [id]); reminderOn = false; reminderMessage = "Kickoff reminder removed."; return
        }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York"); formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let time = pick.startTime, let start = formatter.date(from: pick.gameDate + " " + time), start > Date() else {
            reminderMessage = "A confirmed future kickoff time is needed for a reminder."; return
        }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                reminderMessage = "Allow notifications in Settings to receive reminders."; return
            }
            let content = UNMutableNotificationContent(); content.title = "Game starting soon"
            content.body = pick.homeTeam + " vs " + pick.awayTeam + " · " + pick.league
            content.sound = .default
            let interval = max(1, start.timeIntervalSinceNow - 600)
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
            reminderOn = true; reminderMessage = "Reminder set for 10 minutes before kickoff, or shortly if kickoff is closer."
        } catch { reminderMessage = "Could not set the reminder. Please try again." }
    }
    private func title(_ text: String) -> some View { Text(text).font(.system(size: 15, weight: .bold)) }
    private func toggleSlip() {
        var ids = Set(slipIDs.split(separator: ",").map(String.init))
        let adding = !ids.contains(pick.id.uuidString)
        if adding { ids.insert(pick.id.uuidString) } else { ids.remove(pick.id.uuidString) }
        withAnimation(reduceMotion ? nil : Pick1Springs.snappy) { slipIDs = ids.sorted().joined(separator: ",") }
        Analytics.track(adding ? "pick_slip_added" : "pick_slip_removed", ["pick_id": pick.id.uuidString, "source": "detail"])
    }
}
