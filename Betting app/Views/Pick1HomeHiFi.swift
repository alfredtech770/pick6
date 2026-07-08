// Pick1HomeHiFi.swift
// "Home Hi-Fi" main screen — implements the design from
// `pick6/project/Pick6 Home HiFi.html` (Anton-driven, lime accent,
// scoreboard-bold). Replaces the old Pick6MainView as the post-onboarding
// landing screen.
//
// Wires to PicksViewModel:
//   - top pick           = highest-probability pick in todayPicks
//   - streak             = vm.currentStreak (consecutive wins from latest settled)
//   - accuracy           = vm.winRate (% over rolling 30-day history)
//   - game cards         = vm.todayPicks (filtered by selectedSport)
//   - LIVE / SCHEDULED   = lookup pick.gameId in vm.liveScores

import SwiftUI

// MARK: - Type stack

extension Font {
    static func anton(_ size: CGFloat) -> Font {
        .custom("Anton-Regular", size: size, relativeTo: .body)
    }
    static func archivo(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .black:       name = "Archivo-Black"
        case .heavy:       name = "Archivo-ExtraBold"
        case .bold:        name = "Archivo-Bold"
        case .semibold:    name = "Archivo-SemiBold"
        case .medium:      name = "Archivo-Medium"
        default:           name = "Archivo-Regular"
        }
        return .custom(name, size: size).weight(weight)
    }
    static func archivoNarrow(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .bold:     name = "ArchivoNarrow-Bold"
        case .medium:   name = "ArchivoNarrow-Medium"
        default:        name = "ArchivoNarrow-SemiBold"
        }
        return .custom(name, size: size).weight(weight)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .heavy:    name = "JetBrainsMono-ExtraBold"
        case .bold:     name = "JetBrainsMono-Bold"
        case .medium:   name = "JetBrainsMono-Medium"
        default:        name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: size).weight(weight)
    }
}

// MARK: - Root

struct Pick1HomeHiFi: View {
    enum Tab: Hashable { case home, picks, live, profile }
    @State private var tab: Tab = .home
    @State private var detailPick: Pick?           // game-card tap → detail sheet
    @State private var sportHub: String?           // sport-chip tap → hub sheet
    @State private var showPaywall: Bool = false
    @State private var showWins: Bool = false
    @StateObject private var vm = PicksViewModel()
    @StateObject private var updateChecker = UpdateChecker()
    /// Dismissed for this session only — the banner returns next launch
    /// while a newer App Store version is still out there.
    @State private var updateDismissed = false
    @EnvironmentObject private var subs: SubscriptionManager
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(AuthManager.self) private var auth
    // Drives the foreground-refresh: when the user returns to the app
    // we re-pull the slate and rebind realtime if the ET day rolled
    // over. Without this, an app left open overnight shows a frozen
    // yesterday feed and never advances to the new day's games.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark canvas with subtle radial bloom
            Color(hex: "#07080a").ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#1a1c21").opacity(0.9), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 800
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "#151821").opacity(0.7), .clear],
                center: UnitPoint(x: 1.05, y: 0.3),
                startRadius: 0,
                endRadius: 700
            )
            .ignoresSafeArea()

            // Content per tab.
            // Home extends through the top safe area so the lime hero
            // reaches all the way to the top edge of the device (the
            // status bar `9:41 + signal/wifi/battery` overlays the lime
            // card directly). Other tabs keep their TopNavBar inside
            // the safe area.
            Group {
                switch tab {
                case .home:
                    // SportHub is a full-page push within the Home tab —
                    // not a sheet. When `sportHub` is set, it replaces
                    // HomeHiFiContent entirely (FloatingNav stays at the
                    // bottom). Tapping the back chevron in SportHubView's
                    // TopNavBar clears `sportHub` and returns to Home.
                    if let id = sportHub {
                        // Every sport (including F1 + UFC) uses the
                        // generic SportHubView for v1. Dedicated F1 /
                        // UFC event-layout hubs are a v1.1 follow-up.
                        SportHubView(
                            sport: id,
                            vm: vm,
                            isPro: subs.isPro,
                            onClose: { sportHub = nil },
                            onTapPick: { detailPick = $0 },
                            onUnlock: { showPaywall = true }
                        )
                    } else {
                        HomeHiFiContent(vm: vm,
                                        isPro: subs.isPro,
                                        onTapPick: { detailPick = $0 },
                                        onTapSport: { sportHub = $0 },
                                        onUnlock: { showPaywall = true })
                            .ignoresSafeArea(edges: .top)
                    }
                case .picks:
                    // Picks tab renders the Wins design exactly — the
                    // user's saved/favorited match results. Tab-mode, so
                    // the back chevron is a no-op (it's a primary tab,
                    // not a pushed sheet).
                    WinsView(vm: vm,
                             onClose: {},
                             onTapPick: { detailPick = $0 })
                case .live:
                    LiveView(vm: vm,
                             isPro: subs.isPro,
                             onTapPick: { detailPick = $0 },
                             onUnlock: { showPaywall = true })
                case .profile:
                    ProfileView(vm: vm,
                                isPro: subs.isPro,
                                onShowPaywall: { showPaywall = true },
                                onSignOut: {
                                    // Sign out FIRST — it clears local
                                    // state synchronously so the UI
                                    // flips immediately. The realtime
                                    // teardown runs after; awaiting an
                                    // unsubscribe on a flaky socket
                                    // BEFORE signOut could hang forever
                                    // and made the button appear dead
                                    // (App Review 2.1(a) on iPad).
                                    Task {
                                        await auth.signOut()
                                        await vm.stopLiveSession()
                                    }
                                })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Tab content crossfades on switch instead of snapping. The
            // `.id(tab)` forces SwiftUI to treat each tab as a discrete
            // view tree so .transition fires cleanly on swap.
            .id(tab)
            .transition(.opacity)
            .animation(Pick1Springs.smooth, value: tab)
            // Subtle "tick" haptic on every tab change — the standard
            // iOS selection feedback. Cheap signal that the tap landed.
            .sensoryFeedback(.selection, trigger: tab)
            // Inside-Home back/forward (sport hub push/pop) also gets
            // a soft crossfade so the page swap doesn't snap.
            .animation(Pick1Springs.smooth, value: sportHub)

            FloatingNav(tab: $tab, liveCount: liveCount)
                // Pushed below the safe-area bottom so the nav sits
                // alongside the home-indicator gesture bar instead of
                // floating above it. -12pt on .padding(.bottom) lets
                // the pill bleed into the indicator zone — still well
                // above the actual screen edge, but visually anchored
                // to the bottom rather than hovering.
                .padding(.bottom, -12)
        }
        .preferredColorScheme(.dark)
        // Slim "Update available" banner pinned to the top — shows
        // whenever the App Store has a newer version than this build.
        .overlay(alignment: .top) {
            if updateChecker.updateAvailable && !updateDismissed {
                UpdateBanner(
                    onUpdate: { updateChecker.openAppStore() },
                    onDismiss: { withAnimation(Pick1Springs.smooth) { updateDismissed = true } }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Pick1Springs.smooth, value: updateChecker.updateAvailable)
        .task { await vm.startLiveSession() }
        .task { await updateChecker.check() }
        // Drive Live Activities off the live-score feed: start/update/end
        // a Lock-Screen + Dynamic Island card for each favorited game that's
        // in play (Apple Sports style).
        .onChange(of: vm.liveScores) { _, scores in
            let all = vm.todayPicks + vm.historyPicks
            let favGameIds = Set(all.filter { favorites.contains($0.id) }.compactMap(\.gameId))
            LiveActivityManager.shared.sync(favoritePickGameIds: favGameIds, picks: all, scores: scores)
        }
        // Re-pull the slate + rebind realtime whenever the app comes
        // back to the foreground. Catches: scores that ticked while
        // backgrounded, games that finished, and (critically) the ET
        // midnight rollover that would otherwise leave the realtime
        // filter bound to yesterday's date forever.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await vm.refreshForForeground() }
                Task { await updateChecker.check() }
            }
        }
        .sheet(item: $detailPick) { pick in
            MatchDetailView(pick: pick,
                            liveScore: liveScore(for: pick),
                            onClose: { detailPick = nil })
                // Constrain the sheet to vertical-only interaction.
                // Without these, iOS' interactive-dismiss gesture can pick
                // up small horizontal motion in the rubber-band and the
                // whole sheet appears to drift left/right while held.
                // .scrolls makes drag-to-dismiss fire only when the inner
                // scroll is pinned at the top, and .visible draws the
                // standard pull handle so vertical intent stays obvious.
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        // (SportHub is now a full-page push inside the Home tab — see the
        // `.home` branch of the tab switch above. No sheet needed.)
        .sheet(isPresented: $showPaywall) {
            OBPaywallScreen(
                onBack: { showPaywall = false },
                onSubscribe: { _ in showPaywall = false },
                onSkip: { showPaywall = false }
            )
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showWins) {
            WinsView(vm: vm,
                     onClose: { showWins = false },
                     onTapPick: { p in
                        showWins = false
                        detailPick = p
                     })
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
    }

    private var liveCount: Int {
        vm.todayPicks.filter { p in
            guard let gid = p.gameId,
                  let s = vm.liveScores.first(where: { $0.gameId == gid })
            else { return false }
            return s.isLive
        }.count
    }

    private func liveScore(for pick: Pick) -> LiveScore? {
        guard let gid = pick.gameId else { return nil }
        return vm.liveScores.first { $0.gameId == gid }
    }
}

// MARK: - Home content

struct HomeHiFiContent: View {
    @ObservedObject var vm: PicksViewModel
    let isPro: Bool
    let onTapPick: (Pick) -> Void
    let onTapSport: (String) -> Void
    let onUnlock: () -> Void

    /// Drives the Summer Football hub presentation (full-screen cover).
    @State private var showSummerFootball = false
    /// Won/lost prediction history sheet (opened from the stats tiles).
    @State private var showHistory = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button(action: {
                    if let t = topPick {
                        Haptics.tap()
                        onTapPick(t)
                    }
                }) {
                    if let top = topPick {
                        HeroCard(pick: top, isLive: isLive(top))
                    } else {
                        HeroCard.empty
                    }
                }
                .buttonStyle(.plain)
                // Hero card press feels great with a tiny 0.99 dip —
                // bigger surfaces want subtler scale.
                .pressableScale(0.99)

                StatsRow(winsThisWeek: vm.winsThisWeek,
                         gamesThisWeek: vm.gamesThisWeek,
                         lossesThisWeek: vm.lossesThisWeek,
                         accuracy: vm.accuracyAll,
                         delta: vm.accuracyDelta(),
                         record: vm.recentRecord(),
                         mood: vm.accuracyMood,
                         last10: vm.last10Results,
                         onTap: { showHistory = true })
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // Summer Football banner — sits between the stats row
                // and the sport filter, exactly per the design
                // (`Pick6 Home HiFi.html` → .wc-banner). Tapping opens
                // the full Summer Football hub.
                SummerFootballBanner(onTap: { showSummerFootball = true })
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                SportFilter(vm: vm, onLongPress: { onTapSport($0) })
                    // Breathing room between the WINS / ACCURACY tile
                    // pair and the sport carousel — was 4pt which made
                    // the chips feel glued to the tiles' bottom shadow.
                    .padding(.top, 22)

                // VALUE BOARD — today's biggest model-vs-market edges, sits
                // directly under the category chips. Hidden when no real
                // market edges exist.
                if !vm.valuePlays.isEmpty {
                    // Edges visible to all (the hook); free users hit the
                    // paywall on tap, Pro users open the detail.
                    ValueBoard(picks: vm.valuePlays, isPro: isPro,
                               onTap: { isPro ? onTapPick($0) : onUnlock() })
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                }

                // Section header — title matches the design
                // ("TODAY'S GAMES") with a SEE ALL → CTA. The CTA is
                // only enabled when a specific sport is selected, since
                // the SportHub is per-sport. When ALL is selected, the
                // CTA renders as a passive caption nudging the user to
                // pick a sport first.
                // SEE ALL CTA — Pro-only. The destination (SportHubView)
                // contains the full per-sport feed including locked picks
                // beneath a paywall card for Free tier; but the discovery
                // affordance itself is a Pro perk. Free users still
                // reach SportHub via long-press on a sport chip, where
                // they'll see the lock state.
                //
                // Three preconditions before the CTA renders:
                //   1. User is Pro.
                //   2. A specific sport chip is active (ALL has no
                //      single destination — eight hubs, not one).
                //   3. There's at least one Pro chip selected (the chip
                //      isn't the ALL chip, which is just the default).
                let activeSport: String? =
                    (isPro && vm.selectedSport != "all") ? vm.selectedSport : nil
                SectionHeader(
                    title: isPro ? "TODAY'S GAMES" : "FREE PICKS · TOP PER SPORT",
                    cta: activeSport.map { "SEE ALL \(sportLabelFull($0)) →" },
                    onTapCTA: activeSport.map { sport in
                        {
                            Haptics.tap()
                            onTapSport(sport)
                        }
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .animation(Pick1Springs.snappy, value: vm.selectedSport)
                .animation(Pick1Springs.snappy, value: isPro)

                LazyVStack(spacing: 10) {
                    let visible = vm.visiblePicks(isPro: isPro)
                    if vm.isLoading && visible.isEmpty {
                        ProgressView().tint(Color(hex: "#D4FF3A"))
                            .padding(.top, 40)
                    } else if visible.isEmpty {
                        EmptyTodayState()
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { idx, pick in
                            Button {
                                Haptics.tap()
                                onTapPick(pick)
                            } label: {
                                GameCard(pick: pick,
                                         isLive: isLive(pick),
                                         score: liveScore(for: pick),
                                         isRefundGuarantee: pick.isRefundEligible)
                                    .pressableScale(0.985)
                            }
                            .buttonStyle(.plain)
                            // Stagger each card's appearance so the list
                            // cascades in over ~250ms instead of popping.
                            // Reads as "curated" rather than "dumped".
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(
                                Pick1Springs.smooth.delay(Double(idx) * 0.05),
                                value: visible.count
                            )
                        }
                        // Free tier: show locked picks beneath as Pro upsell
                        if !isPro && !vm.lockedTodayPicks.isEmpty {
                            ProUnlockCard(lockedCount: vm.lockedTodayPicks.count,
                                          onUnlock: onUnlock)
                            ForEach(vm.lockedTodayPicks.prefix(3), id: \.id) { pick in
                                LockedPickCard(pick: pick, onUnlock: onUnlock)
                            }
                            if vm.lockedTodayPicks.count > 3 {
                                Text("+ \(vm.lockedTodayPicks.count - 3) more locked")
                                    .font(.archivoNarrow(10, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(Color(hex: "#6E6F75"))
                                    .padding(.top, 4)
                            }
                        }
                    }

                    // Upcoming events — future-dated picks (next F1 Grand
                    // Prix, next UFC card, tournament fixtures), each card
                    // carrying its real event date. Daily picks above stay
                    // the headline; this section previews what's next.
                    let upcoming = vm.filteredUpcomingEventPicks
                    if !upcoming.isEmpty {
                        SectionHeader(title: "UPCOMING EVENTS", cta: nil, onTapCTA: nil)
                            .padding(.top, 18)
                            .padding(.bottom, 2)
                        ForEach(upcoming.prefix(6), id: \.id) { pick in
                            Button {
                                Haptics.tap()
                                // Free users can't open a future prediction —
                                // the card is locked and tapping prompts Pro.
                                if isPro { onTapPick(pick) } else { onUnlock() }
                            } label: {
                                GameCard(pick: pick,
                                         isLive: false,
                                         score: liveScore(for: pick),
                                         isRefundGuarantee: isPro && pick.isRefundEligible,
                                         concealPick: !isPro)
                                    .pressableScale(0.985)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
        }
        // Pull-to-refresh — for a sports app the user opens at game
        // time, "tug down to fetch new scores" is muscle memory. Reuses
        // the same loadAll() path that runs on `.task`.
        // Pull-to-refresh removed — a manual refresh re-ran loadAll and briefly
        // emptied the slate. Realtime + the .task load keep picks fresh.
        .fullScreenCover(isPresented: $showSummerFootball) {
            SummerFootballHubView(vm: vm, onClose: { showSummerFootball = false },
                                  isPro: isPro,
                                  onUnlock: { showSummerFootball = false; onUnlock() })
        }
        .sheet(isPresented: $showHistory) {
            PredictionHistoryView(vm: vm)
        }
        .task {
            // Ask for an App Store rating only at a genuine high point —
            // an engaged user who has winning picks to feel good about.
            // RatingsPrompt itself enforces the launch-count / once-per-
            // version gating; the delay lets stats load first.
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            RatingsPrompt.maybeRequest(hasPositiveSignal: vm.winsThisWeek > 0)
        }
    }

    private var topPick: Pick? {
        // Highest-probability pick from today (already returned ordered desc by API)
        vm.filteredTodayPicks.max(by: { $0.probability < $1.probability })
    }

    private func isLive(_ pick: Pick) -> Bool {
        guard let gid = pick.gameId,
              let score = vm.liveScores.first(where: { $0.gameId == gid })
        else { return false }
        return score.isLive
    }

    private func liveScore(for pick: Pick) -> LiveScore? {
        guard let gid = pick.gameId else { return nil }
        return vm.liveScores.first { $0.gameId == gid }
    }

    /// Caps-cased league display name for the "SEE ALL <SPORT> →" CTA.
    /// The chip filter uses generic sport categories ("basketball",
    /// "football") which read awkwardly in caps; here we map to the
    /// league acronym (NBA, NFL) the user is most likely to recognize.
    private func sportLabelFull(_ sport: String) -> String {
        switch sport {
        case "basketball": return "NBA"
        case "football":   return "NFL"
        case "soccer":     return "SOCCER"
        case "baseball":   return "MLB"
        case "hockey":     return "NHL"
        case "combat":     return "UFC"
        case "f1":         return "F1"
        case "tennis":     return "TENNIS"
        case "cricket":    return "CRICKET"
        default:           return sport.uppercased()
        }
    }
}

// MARK: - Hero card

struct HeroCard: View {
    let pick: Pick?
    let isLive: Bool
    /// `false` (home screen): renders the Pick1 logo + HeroPill top bar
    /// and a 56pt status-bar inset (the card bleeds under the status bar
    /// on Home). `true` (sport-hub / embedded): no top bar, normal top
    /// padding — the host screen already has its own TopNavBar. Same
    /// surface, same AcidBorder, same lime confidence ring either way,
    /// so the featured frame is visually identical everywhere.
    var embedded: Bool = false

    static var empty: HeroCard { HeroCard(pick: nil, isLive: false) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Deep premium gradient base — replaces the flat lime
            // wash. Dark ink at the top fading into rich lime at the
            // bottom right, anchored by a soft pulsing lime glow.
            // Reads as a sports-broadcast scoreboard rather than a
            // candy-bright tile.
            heroSurface
                .clipShape(BottomRoundedShape(radius: 32))

            // Single bright top sheen — keeps the glassy specular
            // edge without piling on shimmer/stripes.
            LinearGradient(
                colors: [Color.white.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.12)
            )
            .clipShape(BottomRoundedShape(radius: 32))
            .allowsHitTesting(false)

            // Subtle inset bottom shadow — gives the card a slight
            // inner depth so it feels like a physical surface rather
            // than a flat fill.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.22)],
                startPoint: UnitPoint(x: 0.5, y: 0.6),
                endPoint: .bottom
            )
            .clipShape(BottomRoundedShape(radius: 32))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 22) {
                if !embedded { heroTopBar }
                heroBody
            }
            .padding(.horizontal, 22)
            // Home bleeds under the status bar (56pt inset); embedded
            // sits below a TopNavBar so it just needs normal padding.
            .padding(.top, embedded ? 22 : 56)
            .padding(.bottom, embedded ? 22 : 32)

            // Animated acid-green border — a conic gradient stroked
            // around the card's perimeter, rotating slowly. The
            // brightest lime "spotlight" drifts around the edge
            // like an ambient stadium-LED accent (14s per loop —
            // slow enough to feel atmospheric).
            AcidBorder(shape: BottomRoundedShape(radius: 32),
                       period: 14)
                .allowsHitTesting(false)
        }
        // Plain charcoal drop shadow — same as the other panel
        // cards. No lime tint; the only green element is the
        // animated AcidBorder traced on the perimeter.
        .shadow(color: Color.black.opacity(0.55),
                radius: 18, x: 0, y: 14)
        .shadow(color: Color.black.opacity(0.30),
                radius: 6, x: 0, y: 4)
    }

    /// Plain gray hero surface — same gradient as the WINS /
    /// ACCURACY tiles. No lime fade, no green tint; the animated
    /// AcidBorder is the only lime element on the card.
    private var heroSurface: some View {
        ZStack {
            // Identical gradient to `cardBackground` used throughout
            // the app — the hero is just another panel card.
            LinearGradient(
                colors: [
                    Color(hex: "#14161A"),
                    Color(hex: "#0E0F12")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Liquid Glass veil — refractive depth, low opacity so
            // it adds material feel without lightening the gray.
            Color.clear
                .glassCompat(in: BottomRoundedShape(radius: 32), interactive: true)
                .opacity(0.08)
                .allowsHitTesting(false)
        }
    }

    /// (Old `heroGradient` kept as a no-op to avoid breaking other
    /// references; superseded by `heroSurface`.)
    private var heroGradient: some View {
        // Replaced — see heroSurface. Returning the same surface for
        // any caller that still references this name.
        ZStack {
            Color(hex: "#D4FF3A")
            RadialGradient(
                colors: [
                    Color(hex: "#eaff7a"),
                    Color(hex: "#D4FF3A").opacity(0.0)
                ],
                center: UnitPoint(x: 1.1, y: -0.2),
                startRadius: 30,
                endRadius: 500
            )
            RadialGradient(
                colors: [.clear, Color(hex: "#a8e000").opacity(0.4)],
                center: UnitPoint(x: 0.5, y: 1.0),
                startRadius: 100,
                endRadius: 500
            )
        }
    }

    private var heroTopBar: some View {
        HStack(alignment: .center) {
            Pick1Logo()
            Spacer()
            HeroPill(isLive: isLive)
        }
    }

    private var heroBody: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                // Lime kicker — pops against the dark surface much
                // harder than the previous black-on-lime treatment.
                Text("★ TOP PICK · TONIGHT")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Color(hex: "#D4FF3A"))
                    .padding(.bottom, -8)

                // Two-line headline — predicted team in lime, "OVER
                // OTHER" in white. Reads "ADESANYA / over VOLKANOVSKI"
                // at a glance: the lime line is the call, the white
                // line is the opponent.
                // Consistent line spacing whether or not there's a pick.
                // Previously the empty "NO PICKS / YET" state used -28
                // (cramped) vs -7 for a real pick, so the featured frame
                // jumped between layouts. One value everywhere.
                VStack(alignment: .leading, spacing: -7) {
                    ForEach(Array(headlineLines.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.anton(50))
                            .tracking(-0.7)
                            .foregroundColor(idx == 0
                                             ? Color(hex: "#D4FF3A")
                                             : Color.white)
                            .lineLimit(1)
                            // 0.45 floor: long national-team names
                            // ("OVER HERZEGOVINA") shrink to fit
                            // instead of ellipsizing — same rule as
                            // the detail-page title.
                            .minimumScaleFactor(0.45)
                            .allowsTightening(true)
                    }
                }

                HeroMetaPill(time: timeText, channel: channelText)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                // Lime ring on dark — much higher contrast than the
                // dark-on-lime version.
                HiFiConfidenceRing(percent: pick?.probability ?? 0,
                                   color: Color(hex: "#D4FF3A"),
                                   trackColor: Color.white.opacity(0.12),
                                   size: 110,
                                   stroke: 6,
                                   numberColor: Color.white)
                CrestPair(home: pick?.homeTeam, away: pick?.awayTeam,
                          sport: pick?.sport ?? "",
                          soloName: (pick?.sport == "f1" || pick?.sport == "golf") ? pick?.pick : nil)
            }
            .frame(width: 130)
        }
    }

    private var headlineText: String {
        guard let pick = pick else { return "NO PICKS\nYET" }
        // Race events (F1/NASCAR) aren't head-to-head — the pick is the
        // driver, the "other" side is the whole field. "ANTONELLI OVER
        // FIELD" read as nonsense, so races get "<DRIVER> / TO WIN".
        if pick.sport == "f1" || pick.sport == "golf" {
            let winner = teamShortName(pick.pick, sport: pick.sport).uppercased()
            return "\(winner)\nTO WIN"
        }
        // "AWAY OVER HOME" if pick is away; "HOME OVER AWAY" if pick is home.
        // Use teamShortName so "BOSTON CELTICS" / "PHILADELPHIA 76ERS" don't
        // overflow the 50pt Anton at our hero width — we just want
        // "CELTICS / OVER 76ERS".
        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
            || pick.homeTeam.lowercased().contains(pick.pick.lowercased())
        let other = pickedHome ? pick.awayTeam : pick.homeTeam
        let pickShort = teamShortName(pick.pick, sport: pick.sport).uppercased()
        let otherShort = teamShortName(other, sport: pick.sport).uppercased()
        return "\(pickShort)\nOVER \(otherShort)"
    }

    /// Split the headline into individual lines so we can render them in
    /// a VStack with negative spacing (SwiftUI clamps lineSpacing to ≥0).
    private var headlineLines: [String] {
        headlineText.split(separator: "\n").map(String.init)
    }

    private var timeText: String {
        guard let date = pick?.createdAt else { return "TONIGHT" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private var channelText: String {
        guard let pick = pick else { return "" }
        switch pick.league.uppercased() {
        case "NBA":  return "TNT"
        case "NFL":  return "ESPN"
        case "NHL":  return "ESPN"
        case "MLB":  return "MLB.TV"
        case "EPL":  return "PEACOCK"
        case "UFC":  return "ESPN+"
        case "IPL":  return "STAR SPORTS"
        case "F1":   return "F1TV"
        default:     return ""
        }
    }
}

// MARK: - Animated acid border

/// Conic-gradient stroke that rotates continuously around any Shape's
/// perimeter. Used on the HeroCard for an animated "acid green" edge
/// — most of the perimeter sits at low-alpha lime, with a bright lime
/// "spotlight" that sweeps clockwise like a stadium-LED accent.
///
/// Rotation duration ≈ 6 s for one full loop; slow enough to read as
/// a deliberate animation rather than nervous flicker, fast enough to
/// register as motion within a few seconds of glancing at the card.
struct AcidBorder<S: Shape>: View {
    let shape: S
    var lineWidth: CGFloat = 2
    var period: Double = 6.0   // seconds per full revolution

    @State private var angle: Double = 0

    var body: some View {
        shape
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: "#D4FF3A").opacity(0.18), location: 0.00),
                        .init(color: Color(hex: "#D4FF3A").opacity(0.18), location: 0.40),
                        .init(color: Color(hex: "#D4FF3A").opacity(1.00), location: 0.50),
                        .init(color: Color(hex: "#D4FF3A").opacity(0.18), location: 0.60),
                        .init(color: Color(hex: "#D4FF3A").opacity(0.18), location: 1.00),
                    ]),
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: lineWidth
            )
            // Outer halo — the bright spotlight bleeds slightly past
            // the border itself, picking up the LED-trace feel.
            .shadow(color: Color(hex: "#D4FF3A").opacity(0.35),
                    radius: 4, x: 0, y: 0)
            .onAppear {
                withAnimation(.linear(duration: period)
                                .repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// Bottom-rounded shape for hero
struct BottomRoundedShape: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: 0))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                           control: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: radius, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - radius),
                           control: CGPoint(x: 0, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

/// Diagonal stripe overlay — matches the CSS `repeating-linear-gradient`
/// at 100° (near-vertical, 10° lean to the right) with a 41pt pitch and
/// a very faint dark stroke (rgba(0,0,0,0.03)).
struct DiagonalStripe: View {
    var body: some View {
        Canvas { ctx, size in
            let pitch: CGFloat = 41
            // 100° from horizontal → ~10° past vertical, slight rightward lean.
            let dx = tan(10 * .pi / 180) * size.height
            for x in stride(from: -dx, through: size.width + size.height, by: pitch) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + dx, y: size.height))
                ctx.stroke(path, with: .color(.black.opacity(0.03)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Hero subviews

struct Pick1Logo: View {
    var body: some View {
        // White "PICK" + lime "1" tile on the dark hero surface.
        // Mirrors the canonical Pick1 wordmark.
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("PICK")
                .font(.anton(34))
                .tracking(-0.34)
                .foregroundColor(.white)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "#D4FF3A"))
                    .frame(width: 30, height: 30)
                Text("1")
                    .font(.anton(22))
                    .foregroundColor(Color(hex: "#0A0B0D"))
                    .padding(.bottom, 2)
            }
            .padding(.leading, 4)
        }
    }
}

struct HeroPill: View {
    /// Only show the red "LIVE" treatment when the featured game is
    /// actually in progress. Otherwise this is just the AI badge — we
    /// never claim "LIVE" for an upcoming or finished game.
    var isLive: Bool = false

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isLive ? Color(hex: "#FF3B30") : Color(hex: "#D4FF3A"))
                .frame(width: 6, height: 6)
                .shadow(color: (isLive ? Color(hex: "#FF3B30") : Color(hex: "#D4FF3A")).opacity(0.6), radius: 3)
                .opacity(isLive ? (pulse ? 0.35 : 1.0) : 1.0)
            Text(isLive ? "LIVE" : "AI POWERED")
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .overlay(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .clipShape(Capsule())
        .onAppear {
            guard isLive else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct HeroMetaPill: View {
    let time: String
    let channel: String

    var body: some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.mono(12, weight: .bold))
                .foregroundColor(Color(hex: "#D4FF3A"))
            if !channel.isEmpty {
                Circle().fill(Color(hex: "#555555")).frame(width: 3, height: 3)
                Text(channel)
                    .font(.archivoNarrow(11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Color(hex: "#BBBBBB"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#0A0B0D"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Confidence ring

struct HiFiConfidenceRing: View {
    let percent: Double
    let color: Color
    let trackColor: Color
    let size: CGFloat
    let stroke: CGFloat
    let numberColor: Color
    let label: String

    /// Drives both the trim and the number text — animates from 0 →
    /// `percent` once on appear, and re-animates whenever `percent`
    /// changes (e.g. switching cards).
    @State private var displayed: Double = 0

    init(percent: Double,
         color: Color,
         trackColor: Color = Color.white.opacity(0.1),
         size: CGFloat = 110,
         stroke: CGFloat = 6,
         numberColor: Color = .white,
         label: String = "AI CONF") {
        self.percent = percent
        self.color = color
        self.trackColor = trackColor
        self.size = size
        self.stroke = stroke
        self.numberColor = numberColor
        self.label = label
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: stroke)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: max(0.02, min(1, displayed / 100)))
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(displayed.rounded()))")
                        .font(.anton(36))
                        .foregroundColor(numberColor)
                        // Mono digit width so the number doesn't jitter
                        // horizontally as it climbs (1 → 12 → 123).
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.archivo(18, weight: .regular))
                        .foregroundColor(numberColor)
                }
                Text(label)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(numberColor.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .onAppear { animateTo(percent) }
        .onChange(of: percent) { _, new in
            // Reset to 0 then climb so the count-up replays whenever
            // the displayed pick changes.
            displayed = 0
            animateTo(new)
        }
    }

    /// 1.4 s easeOut climb — fast enough to feel snappy, slow enough
    /// for the count-up to register visually.
    private func animateTo(_ target: Double) {
        withAnimation(.easeOut(duration: 1.4)) {
            displayed = target
        }
    }
}

// MARK: - Crests

struct CrestPair: View {
    let home: String?
    let away: String?
    var sport: String = ""
    /// Race events pass the picked driver here — shown alone instead of
    /// the meaningless "Field vs Grand Prix" pair.
    var soloName: String? = nil

    var body: some View {
        if let solo = soloName {
            TeamLogo(sport: sport, team: solo, size: .small)
        } else {
            HStack(spacing: 4) {
                TeamLogo(sport: sport, team: away ?? "—", size: .small)
                Text("VS")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color.black.opacity(0.55))
                TeamLogo(sport: sport, team: home ?? "—", size: .small)
            }
        }
    }
}

struct Crest: View {
    enum Size { case small, big
        var w: CGFloat { self == .small ? 40 : 68 }
        var h: CGFloat { self == .small ? 44 : 76 }
        var fontSize: CGFloat { self == .small ? 13 : 22 }
    }
    let team: String
    let size: Size

    var body: some View {
        ZStack {
            CrestShape()
                .fill(crestColor(for: team))
                .overlay(
                    CrestShape()
                        .fill(LinearGradient(colors: [
                            Color.white.opacity(0.18),
                            Color.clear,
                            Color.black.opacity(0.18)
                        ], startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    CrestShape()
                        .stroke(Color.black.opacity(0.25), lineWidth: 0.8)
                )
            Text(crestAbbrev(team))
                .font(.anton(size.fontSize))
                .tracking(0.24)
                .foregroundColor(.white)
                .padding(.bottom, size == .small ? 4 : 6)
        }
        .frame(width: size.w, height: size.h)
    }
}

struct CrestShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        return Path { p in
            // Mirror of CSS clipPath: M 16 1 L 30 5 L 30 20 Q 30 30 16 35 Q 2 30 2 20 L 2 5 Z
            p.move(to: CGPoint(x: 0.5*w, y: 0.02*h))
            p.addLine(to: CGPoint(x: 0.96*w, y: 0.14*h))
            p.addLine(to: CGPoint(x: 0.96*w, y: 0.56*h))
            p.addQuadCurve(to: CGPoint(x: 0.5*w, y: 0.98*h),
                           control: CGPoint(x: 0.96*w, y: 0.82*h))
            p.addQuadCurve(to: CGPoint(x: 0.04*w, y: 0.56*h),
                           control: CGPoint(x: 0.04*w, y: 0.82*h))
            p.addLine(to: CGPoint(x: 0.04*w, y: 0.14*h))
            p.closeSubpath()
        }
    }
}

private func crestAbbrev(_ team: String) -> String {
    let upper = team.uppercased()
    // Already an abbreviation? (3 caps or fewer)
    let alpha = upper.filter { $0.isLetter }
    if alpha.count <= 4 { return alpha }
    // Otherwise pull initials of words (NBA "Brooklyn Nets" → "BN" — fall back to first 3)
    let parts = team.split(separator: " ")
    let initials = parts.compactMap { $0.first }.prefix(3).map(String.init).joined()
    return initials.isEmpty ? String(upper.prefix(3)) : initials.uppercased()
}

/// Short uppercase label for a team — uses the nickname (last token)
/// when available so all card labels render at the same font size with
/// no auto-shrink. Falls back to the 3-letter abbreviation for very
/// long names.
///   "Brooklyn Nets"        → "NETS"
///   "Cleveland Cavaliers"  → "CAVALIERS"
///   "Tampa Bay Lightning"  → "LIGHTNING"
///   "Jannik Sinner"        → "SINNER"
///   "CLE" (already short)  → "CLE"
func teamShortName(_ team: String, sport: String? = nil) -> String {
    let trimmed = team.trimmingCharacters(in: .whitespacesAndNewlines)
    // Individual-athlete sports always render the surname, regardless
    // of total length — "Jon Jones" → "JONES", "Jannik Sinner" →
    // "SINNER", "Lando Norris" → "NORRIS". Keeps cards tight and
    // matches how UFC / F1 / tennis broadcasts label competitors.
    if let sport, sport == "combat" || sport == "f1" || sport == "tennis" || sport == "golf" {
        if let last = trimmed.split(separator: " ").last {
            return String(last).uppercased()
        }
        return trimmed.uppercased()
    }
    // National sides with a gender/format suffix — "England Women",
    // "Australia Men", "India XI" — must keep the COUNTRY, not the
    // suffix: dropping to the last word rendered "WOMEN vs WOMEN".
    let words = trimmed.split(separator: " ").map(String.init)
    let suffixes: Set<String> = ["WOMEN", "MEN", "XI", "U21", "U23"]
    if words.count >= 2, suffixes.contains(words.last!.uppercased()) {
        let country = words.dropLast().joined(separator: " ")
        let marker = words.last!.uppercased() == "WOMEN" ? " W" : ""
        let base = country.count <= 10 ? country : (words.first ?? country)
        return (base + marker).uppercased()
    }
    // Team sports — short names render as-is, long ones drop to the
    // nickname token ("Boston Celtics" → "CELTICS").
    if trimmed.count <= 12 { return trimmed.uppercased() }
    if let last = trimmed.split(separator: " ").last, last.count <= 12 {
        return String(last).uppercased()
    }
    return crestAbbrev(trimmed)
}

/// User-facing league label. The pipeline's league KEY is a stable join
/// id, not always the right display: cricket research covers more than
/// the IPL (a T20 World Cup match labeled "IPL" was wrong), and "WC"
/// must surface under our own brand.
func displayLeague(_ league: String, sport: String? = nil) -> String {
    switch league.uppercased() {
    case "WC":         return "SUMMER CUP"
    case "IPL":        return "CRICKET"
    case "LALIGA":     return "LA LIGA"
    case "SERIEA":     return "SERIE A"
    case "BUNDESLIGA": return "BUNDESLIGA"
    case "LIGUE1":     return "LIGUE 1"
    case "UCL":        return "CHAMPIONS LEAGUE"
    case "MLS":        return "MLS"
    case "LIGAMX":     return "LIGA MX"
    case "WNBA":       return "WNBA"
    case "EUROLEAGUE": return "EUROLEAGUE"
    case "NCAAB":      return "NCAAB"
    case "KBO":        return "KBO"
    case "NPB":        return "NPB"
    case "NASCAR":     return "NASCAR"
    default:           return league.uppercased()
    }
}

/// One-line "what is this league" descriptor — full name + country/region
/// flag — for leagues whose code isn't self-explanatory. Flag instead of a
/// country word keeps it language-neutral. Returns nil for universally-known
/// leagues (NBA/NFL/MLB/NHL/EPL/UFC/F1) so the detail page stays clean.
func leagueBlurb(_ league: String) -> String? {
    switch league.uppercased() {
    case "KBO":        return "Korea Baseball Organization · 🇰🇷"
    case "NPB":        return "Nippon Professional Baseball · 🇯🇵"
    case "EUROLEAGUE": return "EuroLeague Basketball · 🇪🇺"
    case "IPL":        return "Indian Premier League · 🇮🇳"
    case "MLS":        return "Major League Soccer · 🇺🇸"
    case "LIGAMX":     return "Liga MX · 🇲🇽"
    case "KHL":        return "Kontinental Hockey League · 🇷🇺"
    case "AHL":        return "American Hockey League · 🇺🇸"
    case "WNBA":       return "Women's National Basketball · 🇺🇸"
    case "NCAAB":      return "NCAA College Basketball · 🇺🇸"
    case "LALIGA":     return "La Liga · 🇪🇸"
    case "SERIEA":     return "Serie A · 🇮🇹"
    case "BUNDESLIGA": return "Bundesliga · 🇩🇪"
    case "LIGUE1":     return "Ligue 1 · 🇫🇷"
    case "UCL":        return "UEFA Champions League · 🇪🇺"
    default:           return nil
    }
}

/// Just the country/region flag for a cryptic league — appended to the
/// league code on game cards (e.g. "KBO 🇰🇷") so the card itself tells you
/// the country without needing to open the detail. Nil for well-known
/// leagues (no flag clutter).
func leagueFlag(_ league: String) -> String? {
    switch league.uppercased() {
    case "KBO":        return "🇰🇷"
    case "NPB":        return "🇯🇵"
    case "EUROLEAGUE": return "🇪🇺"
    case "IPL":        return "🇮🇳"
    case "MLS":        return "🇺🇸"
    case "LIGAMX":     return "🇲🇽"
    case "KHL":        return "🇷🇺"
    case "AHL":        return "🇺🇸"
    case "WNBA":       return "🇺🇸"
    case "NCAAB":      return "🇺🇸"
    case "LALIGA":     return "🇪🇸"
    case "SERIEA":     return "🇮🇹"
    case "BUNDESLIGA": return "🇩🇪"
    case "LIGUE1":     return "🇫🇷"
    case "UCL":        return "🇪🇺"
    default:           return nil
    }
}

private func crestColor(for team: String) -> Color {
    // Stable palette per team: use simple hash → curated palette of bold sports hues
    let palette: [Color] = [
        Color(hex: "#552583"), Color(hex: "#007a33"), Color(hex: "#98002e"),
        Color(hex: "#0e2240"), Color(hex: "#ef0107"), Color(hex: "#034694"),
        Color(hex: "#e31837"), Color(hex: "#00338d"), Color(hex: "#f9a01b"),
        Color(hex: "#ce1141"), Color(hex: "#1d428a"), Color(hex: "#006bb6"),
        Color(hex: "#23375b"), Color(hex: "#860038"), Color(hex: "#fdb927"),
    ]
    var hash = 0
    for c in team.unicodeScalars { hash = (hash &* 31) &+ Int(c.value) }
    return palette[abs(hash) % palette.count]
}

// MARK: - Stats row

struct StatsRow: View {
    let winsThisWeek: Int
    let gamesThisWeek: Int
    let lossesThisWeek: Int
    let accuracy: Double
    let delta: Double?
    let record: (wins: Int, losses: Int)
    let mood: PicksViewModel.AccuracyMood
    let last10: [Bool]
    /// Tapping either tile opens the won/lost prediction history.
    var onTap: () -> Void = {}

    /// Measured half-width so both tiles are EXACTLY equal regardless of
    /// content ("44 wins" is intrinsically wider than "60 %", which
    /// otherwise let the WINS tile claim more than half).
    @State private var tileWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 10) {
            WinsThisWeekTile(wins: winsThisWeek,
                             games: gamesThisWeek,
                             losses: lossesThisWeek)
                .frame(width: tileWidth > 0 ? tileWidth : nil)
            AccuracyTile(accuracy: accuracy,
                         delta: delta,
                         record: record,
                         mood: mood,
                         last10: last10)
                .frame(width: tileWidth > 0 ? tileWidth : nil)
        }
        .contentShape(Rectangle())
        .onTapGesture { Haptics.tap(); onTap() }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { tileWidth = (geo.size.width - 10) / 2 }
                    .onChange(of: geo.size.width) { _, w in
                        tileWidth = (w - 10) / 2
                    }
            }
        )
    }
}

/// "Wins this week" — replaces the prior STREAK tile. Shows wins
/// out of total settled games since Monday, with a segmented bar
/// where each played game is a slot (filled = won, unfilled = lost
/// or not played yet). Same visual rhythm as AccuracyTile so the
/// pair reads as one unit.
struct WinsThisWeekTile: View {
    let wins: Int
    let games: Int   // total settled this week (W + L)
    let losses: Int

    /// Total slots in the weekly bar — design's "10 of N" feel.
    /// Cap at the larger of (games, 7) so the bar always feels like
    /// "the week" (~7 days) without truncating a busy week.
    private var slots: Int { max(games, 7) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                Text("WINS")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(wins)")
                    .font(.anton(72))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                    .tracking(-1.4)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text(wins == 1 ? "win" : "wins")
                    .font(.archivo(18, weight: .bold))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .animation(Pick1Springs.smooth, value: wins)
            Spacer(minLength: 0)
            HStack {
                Text("OF \(games) THIS WEEK")
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if losses > 0 {
                    Text("\(wins)-\(losses)")
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBackground)
    }
}

/// AccuracyTile — visually mirrors WinsThisWeekTile so the home stats
/// row reads as a coherent pair. Same header / big-number / 10-segment
/// bar / sub-line rhythm; the bar's segments are the last 10 settled
/// picks (filled lime = win, mute = loss) instead of a sparkline.
struct AccuracyTile: View {
    let accuracy: Double
    let delta: Double?
    let record: (wins: Int, losses: Int)
    let mood: PicksViewModel.AccuracyMood
    let last10: [Bool]   // newest first; true = win

    /// 10 slots; if there are fewer than 10 settled picks, the unused
    /// slots render as mute.
    private let slots = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: moodIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(numberColor)
                Text("ACCURACY")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(mood == .empty ? "—" : "\(Int(accuracy.rounded()))")
                    .font(.anton(72))
                    .foregroundColor(numberColor)
                    .tracking(-1.4)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                if mood != .empty {
                    Text("%")
                        .font(.archivo(18, weight: .bold))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .animation(Pick1Springs.smooth, value: accuracy)
            Spacer(minLength: 0)
            HStack {
                if mood == .empty || (record.wins + record.losses) == 0 {
                    // Shown for sports with no settled picks yet AND those
                    // below the meaningful-sample floor (PicksViewModel
                    // .minSampleForAccuracy) — reads as a positive "give it
                    // time" rather than implying a bad/zero record.
                    Text("BUILDING TRACK RECORD")
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6F75"))
                } else {
                    // Scoped to high-confidence picks (PicksViewModel
                    // .accuracyConfidenceFloor) — labeled so the headline % is
                    // honest about what it measures. Lower-confidence cards
                    // still show throughout the app, just not in this record.
                    Text("\(record.wins)-\(record.losses) · 60%+ CALLS")
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                trailingBadge
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBackground)
    }

    /// Segment color: lime when that slot was a win, mute otherwise.
    /// Reverse the index so the bar reads left = oldest, right = newest.
    private func segmentColor(at i: Int) -> Color {
        let revIndex = slots - 1 - i        // newest is rightmost
        guard revIndex < last10.count else {
            return Color(hex: "#2D3038")    // unused slot
        }
        return last10[revIndex]
            ? Color(hex: "#D4FF3A")
            : Color(hex: "#2D3038")
    }

    /// Big-number color shifts with mood.
    private var numberColor: Color {
        switch mood {
        case .bullish, .strong: return Color(hex: "#D4FF3A")
        case .neutral:          return Color(hex: "#F5F3EE")
        case .cold:             return Color(hex: "#FF5A36")
        case .empty:            return Color(hex: "#6E6F75")
        }
    }

    /// Header icon — flame when bullish, trend-up otherwise.
    private var moodIcon: String {
        mood == .bullish ? "flame.fill" : "chart.line.uptrend.xyaxis"
    }

    /// Trailing badge in the footer row: ON FIRE when bullish, ↑/↓
    /// delta otherwise. Mirrors the "↑ N TO RECORD" trailing slot on
    /// the prior STREAK tile so the visual rhythm is preserved.
    @ViewBuilder
    private var trailingBadge: some View {
        if mood == .bullish {
            Text("ON FIRE")
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "#0A0B0D"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(hex: "#D4FF3A")))
        } else if let d = delta, abs(d) >= 1, mood != .empty {
            let up = d >= 0
            let color = up ? Color(hex: "#D4FF3A") : Color(hex: "#FF5A36")
            Text(up ? "↑ \(Int(d.rounded()))%"
                   : "↓ \(Int((-d).rounded()))%")
                .font(.mono(10, weight: .bold))
                .foregroundColor(color)
        }
    }
}

/// Stats-tile background. Spec calls for `.tile` with flat --panel fill
/// + 4-shadow stack (inset top white + inset bottom black + drop 10/24 + drop 2/6).
private var tileBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color(hex: "#101114"))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "#22252B"), lineWidth: 1)
        )
        // Inset top highlight — bright stroke faded to clear in the top half
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear],
                                     startPoint: .top, endPoint: .center))
        )
        // Inset bottom shadow — dark stroke faded to clear in the bottom half
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
                .mask(LinearGradient(colors: [.clear, .black],
                                     startPoint: .center, endPoint: .bottom))
        )
        .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 10)
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
}

struct SparklineView: View {
    var points: [CGFloat] = [50, 50, 50, 50, 50]
    var color: Color = Color(hex: "#D4FF3A")

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let safe = points.isEmpty ? [0] : points
            let maxY = safe.max() ?? 1
            let minY = safe.min() ?? 0
            let span = max(maxY - minY, 1)
            let step = safe.count > 1 ? w / CGFloat(safe.count - 1) : w
            let coords: [CGPoint] = safe.enumerated().map { i, p in
                CGPoint(x: CGFloat(i) * step,
                        y: h - ((p - minY) / span) * h)
            }
            if let first = coords.first {
                // Fill
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: first)
                    for c in coords.dropFirst() { p.addLine(to: c) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(color.opacity(0.1))
                // Line
                Path { p in
                    p.move(to: first)
                    for c in coords.dropFirst() { p.addLine(to: c) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5,
                                                   lineCap: .round,
                                                   lineJoin: .round))
            }
        }
    }
}

// MARK: - Sport filter

struct SportFilter: View {
    @ObservedObject var vm: PicksViewModel
    /// Optional long-press handler — used by Home to push a sport hub.
    var onLongPress: ((String) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                HiFiSportChip(label: "ALL · \(vm.effectiveTodayPicks.count)",
                          icon: "circle.grid.cross",
                          isActive: vm.selectedSport == "all") {
                    vm.selectedSport = "all"
                }
                ForEach(visibleSports, id: \.self) { sport in
                    HiFiSportChip(label: sportLabel(sport),
                              icon: sportIcon(sport),
                              isActive: vm.selectedSport == sport) {
                        vm.selectedSport = sport
                    }
                    .onLongPressGesture(minimumDuration: 0.4) {
                        onLongPress?(sport)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    /// The sport chips, always visible, in the requested order:
    /// Soccer · MLB · Golf · F1 · MMA · Cricket · Basketball · Hockey.
    /// Tapping a sport with no picks today shows the empty state — better
    /// discovery than hiding the chip.
    private var visibleSports: [String] {
        ["soccer", "baseball", "golf", "f1", "combat", "cricket", "football", "basketball", "hockey"]
    }

    /// Carousel label — uses the SPORT category name (Basketball, Soccer)
    /// rather than the league abbreviation (NBA, EPL). Sport-first labels
    /// match the design's mental model: a chip filters by sport, and each
    /// sport's hub then exposes its specific leagues (NBA, G-League, etc.)
    /// inside the league rail.
    private func sportLabel(_ sport: String) -> String {
        switch sport {
        case "basketball": return "Basketball"
        case "football":   return "NFL"
        case "soccer":     return "Soccer"
        case "baseball":   return "MLB"
        case "golf":       return "Golf"
        case "hockey":     return "Hockey"
        case "combat":     return "MMA"
        case "f1":         return "F1"
        case "cricket":    return "Cricket"
        default:           return sport.capitalized
        }
    }

    private func sportIcon(_ sport: String) -> String {
        switch sport {
        case "basketball": return "basketball.fill"
        case "football":   return "football.fill"
        case "soccer":     return "soccerball"
        case "baseball":   return "baseball.fill"
        case "hockey":     return "hockey.puck.fill"
        case "combat":     return "figure.boxing"
        case "f1":         return "car.fill"
        case "golf":       return "figure.golf"
        case "cricket":    return "figure.cricket"
        default:           return "circle"
        }
    }
}

struct HiFiSportChip: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(1.5)
            }
            .padding(.leading, 10)
            .padding(.trailing, 13)
            .padding(.vertical, 7)
            .foregroundColor(isActive ? Color(hex: "#0A0B0D") : Color(hex: "#B9B7B0"))
            .background(
                Capsule()
                    .fill(isActive ? Color(hex: "#F5F3EE") : Color(hex: "#101114"))
            )
            .overlay(
                Capsule().stroke(isActive ? Color(hex: "#F5F3EE") : Color(hex: "#22252B"), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Value Board

/// Today's biggest model-vs-market edges, across every sport. Each row is
/// a pick where our probability beats the market's implied probability;
/// ranked by edge. Tapping opens the pick's detail. Framed as a
/// prediction — never "bet to win money".
struct ValueBoard: View {
    let picks: [Pick]
    let isPro: Bool
    let onTap: (Pick) -> Void

    private var top: [Pick] { Array(picks.prefix(4)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                Text("BEST VALUE TODAY")
                    .font(.archivoNarrow(11, weight: .bold)).tracking(2.0)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                Text("WE BEAT THE MARKET")
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
            .padding(.bottom, 12)

            ForEach(Array(top.enumerated()), id: \.element.id) { idx, pick in
                Button { Haptics.tap(); onTap(pick) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: sportIcon(pick.sport))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#8A8D94"))
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(teamShortName(pick.pick, sport: pick.sport).uppercased())
                                .font(.archivo(13, weight: .bold))
                                .foregroundColor(Color(hex: "#F5F3EE"))
                                .lineLimit(1)
                            Text(matchupLabel(pick))
                                .font(.archivoNarrow(9, weight: .bold)).tracking(0.6)
                                .foregroundColor(Color(hex: "#6E6F75"))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        if !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#6E6F75"))
                        }
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("+\(edgePts(pick))%")
                                .font(.anton(16))
                                .foregroundColor(Color(hex: "#D4FF3A"))
                            Text("us \(Int(pick.probability))% · mkt \(impliedPct(pick))%")
                                .font(.archivoNarrow(8, weight: .bold)).tracking(0.4)
                                .foregroundColor(Color(hex: "#6E6F75"))
                        }
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .top) {
                        if idx > 0 { Rectangle().fill(Color(hex: "#1F2126")).frame(height: 1) }
                    }
                }
                .buttonStyle(.plain)
            }

            Text("AI PROJECTION · NOT A GUARANTEE")
                .font(.archivoNarrow(8, weight: .bold)).tracking(1.4)
                .foregroundColor(Color(hex: "#4A4B50"))
                .padding(.top, 10)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "#101114"))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "#D4FF3A").opacity(0.18), lineWidth: 1))
        )
    }

    private func edgePts(_ p: Pick) -> Int { Int((p.valueEdge ?? 0).rounded()) }
    private func impliedPct(_ p: Pick) -> Int { Int((p.impliedProbability ?? 0).rounded()) }
    private func matchupLabel(_ p: Pick) -> String {
        if p.sport == "f1" || p.sport == "golf" { return p.homeTeam.uppercased() }
        return "\(teamShortName(p.homeTeam, sport: p.sport)) vs \(teamShortName(p.awayTeam, sport: p.sport))".uppercased()
    }
    private func sportIcon(_ sport: String) -> String {
        switch sport {
        case "basketball": return "basketball.fill"
        case "football":   return "football.fill"
        case "soccer":     return "soccerball"
        case "baseball":   return "baseball.fill"
        case "hockey":     return "hockey.puck.fill"
        case "combat":     return "figure.boxing"
        case "f1":         return "car.fill"
        case "golf":       return "figure.golf"
        case "cricket":    return "figure.cricket"
        default:           return "circle"
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    let cta: String?
    let onTapCTA: (() -> Void)?

    init(title: String, cta: String? = nil, onTapCTA: (() -> Void)? = nil) {
        self.title = title
        self.cta = cta
        self.onTapCTA = onTapCTA
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.anton(30))
                .tracking(-0.15)
                .foregroundColor(Color(hex: "#F5F3EE"))
            Spacer()
            if let cta = cta {
                if let onTapCTA = onTapCTA {
                    // Tappable See-All affordance — opens the SportHub
                    // for the currently active sport.
                    Button(action: onTapCTA) {
                        Text(cta)
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "#D4FF3A"))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Non-interactive caption — kept for layout parity
                    // when no destination is available.
                    Text(cta)
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
            }
        }
    }
}

// MARK: - Game card

struct GameCard: View {
    let pick: Pick
    let isLive: Bool
    let score: LiveScore?

    /// True for 85%+ picks, which carry the refund guarantee. Drives
    /// the top ribbon: REFUND GUARANTEE while open, REFUNDED on a
    /// graded loss, GUARANTEED PICK · HIT on a win. Defaults to false
    /// so other call sites / previews render unchanged.
    var isRefundGuarantee: Bool = false

    /// When true, the AI pick + confidence are concealed behind a Pro
    /// lock (matchup + date still show). Used for Free users in the
    /// Upcoming Events section so future predictions stay gated.
    var concealPick: Bool = false

    @Environment(LocalizationManager.self) private var loc

    /// Authoritative card state — same helper every other surface uses.
    /// Replaces the old `isLive` Bool for badge / topline decisions so
    /// past-pending picks render with an "AWAITING" treatment instead
    /// of a "kickoff in the past" upcoming label.
    private var state: PickRenderState {
        pick.renderState(liveScore: score)
    }

    var body: some View {
        // F1 / MMA picks aren't two-team matchups — they're standalone
        // events (a race, a fight, a prop). Render those as event cards
        // matching the design's `.ev-card` (same component used inside
        // F1HubView and UFCHubView). Everything else keeps the original
        // home/away/score-grid layout.
        if isEventLayout {
            eventCardBody
        } else {
            teamCardBody
        }
    }

    /// True for sports whose picks are single-event outcomes (an F1
    /// race winner) rather than two-competitor matchups. Combat used
    /// to be in here too, but UFC fights ARE two-competitor matchups
    /// — same shape as tennis — so they now render through the team-
    /// card layout (which already wires AthleteHeadshot for the two
    /// fighters via TeamColumn → TeamLogo).
    private var isEventLayout: Bool {
        pick.sport == "f1" || pick.sport == "golf"
    }

    // ─── TEAM LAYOUT (NBA, NFL, EPL, MLB, NHL, NCAA, Cricket, Tennis) ──
    private var teamCardBody: some View {
        VStack(spacing: 0) {
            // Lock-of-the-Day ribbon — only on the day's single ≥85%
            // top pick. Reads HIT / MISSED once graded.
            if isRefundGuarantee {
                RefundGuaranteeBadge(won: pick.isWin, lost: pick.isLoss)
            }

            // Top row — switches on the authoritative renderState so
            // past-pending picks no longer say "TONIGHT" with a stale
            // kickoff. Four buckets:
            //   .live          → LIVE pulse + league mute
            //   .awaitingResult → amber AWAITING badge
            //   .won/.lost     → FINAL chip
            //   .upcoming      → original scheduledTopLine (e.g. "NBA · TONIGHT")
            HStack {
                topRowBadge
                Spacer()
                if concealPick {
                    lockChip
                } else {
                    ConfChip(percent: pick.probability, hot: pick.probability >= 80)
                }
            }
            .padding(.bottom, 14)

            // Teams + score — ScoreView now also reads state so a
            // past-pending pick shows AWAITING / hourglass instead of
            // "VS · 7:30 PM" in the past.
            HStack(alignment: .center, spacing: 14) {
                TeamColumn(team: pick.awayTeam, isAway: true, sport: pick.sport)
                ScoreView(pick: pick, state: state, score: score)
                    .frame(maxWidth: .infinity)
                TeamColumn(team: pick.homeTeam, isAway: false, sport: pick.sport)
            }

            // AI pick + mini ring
            Divider()
                .background(Color(hex: "#22252B"))
                .padding(.top, 14)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI PICKS")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                    Text(concealPick ? loc.t(.card_unlock_pro) : pick.shortDisplayPick.uppercased())
                        .font(.anton(17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .tracking(0.17)
                        .foregroundColor(concealPick ? Color(hex: "#6E6F75") : Color(hex: "#D4FF3A"))
                }
                Spacer()
                if concealPick {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                } else {
                    MiniRing(percent: pick.probability)
                }
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(homeCardBackground)
    }

    // ─── EVENT LAYOUT (F1, MMA) ─────────────────────────────────
    private var eventCardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Result / guarantee ribbon — see teamCardBody.
            if isRefundGuarantee {
                RefundGuaranteeBadge(won: pick.isWin, lost: pick.isLoss)
            } else if pick.isWin || pick.isLoss {
                PredictionResultBadge(won: pick.isWin)
            }

            // Tag + AI pill — for live/awaiting/final states swap the
            // race-day tag for the same shared badge the team card uses,
            // so an F1 weekend that's already underway reads "LIVE · L42"
            // and a past-but-not-yet-graded race reads AWAITING. Upcoming
            // keeps the sport-specific tag ("RACE · SUN 15:00").
            HStack {
                if state == .upcoming {
                    Text(eventTag)
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.0)
                        .foregroundColor(Color(hex: "#6E6F75"))
                } else {
                    topRowBadge
                }
                Spacer()
                if concealPick {
                    lockChip
                } else {
                    ConfChip(percent: pick.probability,
                             hot: pick.probability >= 70)
                }
            }
            .padding(.bottom, 10)

            // Title (e.g. "MONACO GP", "O'MALLEY vs VERA 2")
            Text(eventTitle)
                .font(.anton(22))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Sub (key factor / context) — hidden when concealed, since
            // the key factor often hints at the pick.
            if !eventSub.isEmpty && !concealPick {
                Text(eventSub)
                    .font(.mono(10))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // (Combat used to render its faceoff here; combat now uses
            //  the team-card layout instead, alongside tennis.)

            // Dashed divider
            Rectangle()
                .fill(Color.clear)
                .frame(height: 1)
                .overlay(
                    GeometryReader { proxy in
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: 0.5))
                            p.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
                        }
                        .stroke(Color(hex: "#22252B"),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                )
                .padding(.top, 10)

            // Pick row
            HStack {
                Text(concealPick ? loc.t(.card_unlock_pro) : pick.displayPick.uppercased())
                    .font(.archivo(12, weight: .bold))
                    .foregroundColor(concealPick ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                Spacer()
                if concealPick {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .frame(width: 36, height: 36)
                } else {
                    MiniRing(percent: pick.probability)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(homeCardBackground)
    }

    /// Small acid-green lock chip shown where the confidence % would be
    /// when a Free user views a concealed Upcoming Event.
    private var lockChip: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(Color(hex: "#D4FF3A"))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Capsule().fill(Color(hex: "#D4FF3A").opacity(0.12)))
            .overlay(Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.35), lineWidth: 1))
    }

    // ─── Shared card background (matches design's `.gcard`) ─────
    private var homeCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(hex: "#14161a"), Color(hex: "#0e0f12")],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(hex: "#22252B"), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    .mask(LinearGradient(colors: [.white, .clear],
                                         startPoint: .top, endPoint: .center))
            )
            .shadow(color: .black.opacity(0.7), radius: 10, x: 0, y: 10)
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
    }

    // ─── Event-card helpers ─────────────────────────────────────

    /// Tag line above the event title — sport-specific copy.
    private var eventTag: String {
        switch pick.sport {
        case "f1":     return "RACE · \(formattedDate)"
        case "combat": return "MAIN CARD · \(displayLeague(pick.league))"
        default:       return displayLeague(pick.league)
        }
    }

    /// Event title — for UFC two-fighter matchup, for F1 the GP name
    /// (which lives in homeTeam after the F1 pipeline). Falls back to
    /// the pick text if the upstream data is sparse.
    private var eventTitle: String {
        if pick.sport == "combat",
           !pick.homeTeam.isEmpty, !pick.awayTeam.isEmpty {
            // Last names only for fighters — "ADESANYA VS VOLKANOVSKI"
            // beats "ISRAEL ADESANYA VS ALEXANDER VOLKANOVSKI" for the
            // card headline (fits the 16pt frame, reads broadcast-style).
            let h = teamShortName(pick.homeTeam, sport: pick.sport)
            let a = teamShortName(pick.awayTeam, sport: pick.sport)
            return "\(h) VS \(a)"
        }
        if !pick.homeTeam.isEmpty {
            return pick.homeTeam.uppercased()
        }
        return pick.displayPick.uppercased()
    }

    private var eventSub: String {
        pick.keyFactor ?? ""
    }

    private var formattedDate: String {
        // gameDate ships as "yyyy-MM-dd" with no kickoff time — show
        // the event DAY ("SUN JUN 14"), not a fabricated 00:00 clock.
        if let d = pick.gameDateValue {
            let out = DateFormatter()
            out.dateFormat = "EEE MMM d"
            out.timeZone = TimeZone(identifier: "America/New_York") ?? .current
            return out.string(from: d).uppercased()
        }
        return "TODAY"
    }

    private var scheduledTopLine: String {
        let league = displayLeague(pick.league)
        switch league {
        case "EPL": return "EPL · MATCHDAY"
        case "NFL": return "NFL · PRIMETIME"
        case "MLB": return "MLB · TODAY"
        case "NBA": return "NBA · TONIGHT"
        case "NHL": return "NHL · TONIGHT"
        case "UFC": return "UFC · MAIN CARD"
        case "F1":  return "F1 · RACE WEEKEND"
        case "IPL": return "IPL · MATCH DAY"
        default:
            // Cryptic leagues get a country flag so the card is self-explanatory.
            if let flag = leagueFlag(pick.league) { return "\(league) \(flag)" }
            return league
        }
    }

    private func livePulseText(_ s: LiveScore) -> String {
        let q = s.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? (s.status ?? "LIVE").uppercased()
        return "LIVE · \(q)"
    }

    /// Per-state top-row badge for both team and event card layouts.
    /// Centralizes the four-way switch (live/awaiting/won-lost/upcoming)
    /// so every team-card surface in the app reads identically.
    @ViewBuilder
    private var topRowBadge: some View {
        switch state {
        case .live:
            if let s = score {
                HStack(spacing: 6) {
                    LivePulseBadge(label: livePulseText(s))
                    Text(displayLeague(pick.league))
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            } else {
                LivePulseBadge(label: "LIVE")
            }
        case .awaitingResult:
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text("AWAITING")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#F59E0B"))
            }
        case .won, .lost:
            HStack(spacing: 6) {
                Text("FINAL")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Text(displayLeague(pick.league))
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
        case .upcoming:
            Text(scheduledTopLine)
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#B9B7B0"))
        }
    }
}

/// Graded-result ribbon for ordinary picks (the 85%+ refund picks use
/// RefundGuaranteeBadge instead). A WIN gets the loudest treatment on
/// the card — solid lime, ink text — because "we called it" is the
/// product's whole pitch; a miss stays honest but quiet.
struct PredictionResultBadge: View {
    let won: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: won ? "trophy.fill" : "xmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(won ? Color(hex: "#0A0B0D") : Color(hex: "#6E6F75"))
            Text(won ? "PREDICTION HIT" : "PREDICTION MISSED")
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2.2)
                .foregroundColor(won ? Color(hex: "#0A0B0D") : Color(hex: "#6E6F75"))
            if won {
                Text("· AI CALLED IT")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(Color(hex: "#0A0B0D").opacity(0.65))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, won ? 7 : 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(won ? Color(hex: "#D4FF3A") : Color(hex: "#16181C"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(won ? Color(hex: "#D4FF3A") : Color(hex: "#2D3038"),
                        lineWidth: 1)
        )
        .shadow(color: won ? Color(hex: "#D4FF3A").opacity(0.35) : .clear,
                radius: 10, x: 0, y: 4)
        .padding(.bottom, 12)
    }
}

/// Refund-guarantee ribbon shown on every 85%+ pick. While the game is
/// open it reads "REFUND GUARANTEE · WE REFUND IF IT LOSES"; a graded
/// loss flips to "REFUNDED · CLAIM FORM COMING" (fulfilled out-of-band
/// via a claim form); a graded win reads "GUARANTEED PICK · HIT".
/// Product accepted the App Review wording risk knowingly (2026-06-10).
struct RefundGuaranteeBadge: View {
    let won: Bool
    let lost: Bool

    private enum Phase { case pending, hit, refunded }
    private var phase: Phase { won ? .hit : (lost ? .refunded : .pending) }

    private var accent: Color {
        switch phase {
        case .pending:  return Color(hex: "#D4FF3A")   // lime
        case .hit:      return Color(hex: "#22C55E")   // green
        case .refunded: return Color(hex: "#22C55E")   // green = money back
        }
    }
    private var icon: String {
        switch phase {
        case .pending:  return "shield.lefthalf.filled"
        case .hit:      return "checkmark.seal.fill"
        case .refunded: return "arrow.uturn.left.circle.fill"
        }
    }
    private var label: String {
        switch phase {
        case .pending:  return "REFUND GUARANTEE"
        case .hit:      return "GUARANTEED PICK · HIT"
        case .refunded: return "REFUNDED"
        }
    }
    private var sub: String? {
        switch phase {
        case .pending:  return "· WE REFUND IF IT LOSES"
        case .refunded: return "· WE'VE GOT YOU COVERED"
        case .hit:      return nil
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(accent)
            Text(label)
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2)
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let sub {
                Text(sub)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(accent.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(accent.opacity(0.35), lineWidth: 1)
        )
        .padding(.bottom, 12)
    }
}

struct LivePulseBadge: View {
    let label: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: "#FF5A36"))
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#FF5A36").opacity(0.5), lineWidth: 4)
                        .scaleEffect(pulse ? 2 : 1)
                        .opacity(pulse ? 0 : 1)
                )
                .onAppear {
                    withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                }
            Text(label)
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#FF5A36"))
        }
    }
}

struct ConfChip: View {
    let percent: Double
    let hot: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text("AI")
                .font(.mono(11, weight: .medium))
                .foregroundColor(hot ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
            Text("\(Int(percent.rounded()))%")
                .font(.mono(11, weight: .bold))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .monospacedDigit()
                // Digit-roll animation when the confidence value
                // updates (rare but happens when a pick re-grades).
                .contentTransition(.numericText())
                .animation(Pick1Springs.snappy, value: percent)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(hot ? Color(hex: "#D4FF3A").opacity(0.08) : Color(hex: "#16181C"))
        )
        .overlay(
            Capsule()
                .stroke(hot ? Color(hex: "#D4FF3A").opacity(0.4) : Color(hex: "#2D3038"), lineWidth: 1)
        )
    }
}

struct TeamColumn: View {
    let team: String
    let isAway: Bool
    var sport: String = ""

    var body: some View {
        VStack(spacing: 10) {
            TeamLogo(sport: sport, team: team, size: .big)
            // teamShortName keeps every card's name slot at the same
            // 16pt font height — no auto-shrink, so HEAT, CAVALIERS,
            // LIGHTNING, ARSENAL all render uniformly.
            Text(teamShortName(team, sport: sport))
                .font(.anton(16))
                .tracking(0.16)
                .foregroundColor(Color(hex: "#F5F3EE"))
                .lineLimit(1)
            Text(isAway ? "AWAY" : "HOME")
                .font(.mono(9, weight: .medium))
                .tracking(0.4)
                .foregroundColor(Color(hex: "#6E6F75"))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ScoreView: View {
    let pick: Pick
    let state: PickRenderState
    let score: LiveScore?

    var body: some View {
        // Per-state center column. The previous Bool-driven branch had
        // no way to express "game ended but isn't graded yet" — so a
        // past-pending pick rendered "VS · 7:30 PM" hours after kickoff.
        switch state {
        case .live, .won, .lost:
            // Game is in progress or settled — render the numeric score
            // if we have it. Fall back to a generic indicator otherwise
            // so a stale live_scores row doesn't blank the column.
            if let s = score,
               let h = s.homeScore, let a = s.awayScore {
                // Score digits animate when the live_scores stream
                // ticks — the most-watched numbers in the app.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(a)").font(.anton(28)).tracking(-0.28)
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("–").font(.anton(20))
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text("\(h)").font(.anton(28)).tracking(-0.28)
                        .foregroundColor(pickWon(home: h, away: a, pick: pick)
                                         ? Color(hex: "#D4FF3A")
                                         : Color(hex: "#F5F3EE"))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .animation(Pick1Springs.smooth, value: s.homeScore)
                .animation(Pick1Springs.smooth, value: s.awayScore)
            } else if let h = pick.homeScore, let a = pick.awayScore {
                // Graded picks carry their box score on the row itself
                // (live_scores may have rolled over) — use that.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(a)").font(.anton(28)).tracking(-0.28)
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .monospacedDigit()
                    Text("–").font(.anton(20))
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text("\(h)").font(.anton(28)).tracking(-0.28)
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .monospacedDigit()
                }
            } else {
                Text(state == .live ? "LIVE" : "FINAL")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }

        case .awaitingResult:
            // Game's over but pipeline hasn't graded it yet — be honest
            // about the state instead of showing a kickoff time in the
            // past.
            VStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text("AWAITING")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(Color(hex: "#F59E0B"))
            }

        case .upcoming:
            VStack(spacing: 2) {
                Text("VS")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                if let kickoffText = kickoffText {
                    Text(kickoffText)
                        .font(.mono(11, weight: .bold))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                } else if let dateText = futureDateText {
                    // No kickoff time in the feed (future-dated event
                    // picks: next UFC card, tournament fixtures) — show
                    // the event date instead of a bare "VS".
                    Text(dateText)
                        .font(.mono(11, weight: .bold))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
            }
        }
    }

    /// Event date ("SAT JUN 13") for picks whose game day is after
    /// today (ET). Nil for same-day games — those either have a real
    /// kickoff time from live_scores or just show "VS".
    private var futureDateText: String? {
        guard let d = pick.gameDateValue else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        guard d > Date() && !cal.isDateInToday(d) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        f.timeZone = cal.timeZone
        return f.string(from: d).uppercased()
    }

    /// Real kickoff time from the live_scores feed (sportsdata.io's
    /// `start_time`). Falls back to nil when we don't have one — we
    /// show "VS" alone rather than misleading garbage. Pick.createdAt
    /// is the AI-generation timestamp, NOT the game start; using it
    /// for a kickoff label was a long-standing bug.
    private var kickoffText: String? {
        guard let kickoff = score?.startTime else { return nil }
        return kickoffTimeText(kickoff)
    }

    private func pickWon(home: Int, away: Int, pick: Pick) -> Bool {
        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
            || pick.homeTeam.lowercased().contains(pick.pick.lowercased())
        return pickedHome ? home > away : away > home
    }
}

struct MiniRing: View {
    let percent: Double

    /// Same count-up driver as HiFiConfidenceRing — animates 0 → percent
    /// on appear, replays on change.
    @State private var displayed: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#2D3038"), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, displayed / 100)))
                .stroke(Color(hex: "#D4FF3A"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(displayed.rounded()))")
                .font(.mono(11, weight: .heavy))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(width: 38, height: 38)
        .onAppear { animateTo(percent) }
        .onChange(of: percent) { _, new in
            displayed = 0
            animateTo(new)
        }
    }

    private func animateTo(_ target: Double) {
        withAnimation(.easeOut(duration: 1.2)) { displayed = target }
    }
}

// MARK: - Floating glass nav

/// Floating bottom-nav pill — matches `Pick6 Account Pages.html` spec
/// exactly: 4 fixed items (Home / Picks / Live / Profile) on a glass
/// capsule. Live is a permanent red `live-btn` (always visible, always
/// pulsing) — not a conditional badge on a normal tab.
///
/// Spec values (account-pages.jsx + accompanying CSS):
///   • Container: bottom: 20px, blur(22) saturate(160), bg
///     rgba(22,24,28,0.82), border rgba(255,255,255,0.06), padding 8px
///   • Inactive item: padding 10×14, mute color, icon-only (no label)
///   • Active item:   padding 10×18, lime-tint bg (.14 alpha), inset
///                    lime stroke (.25 alpha), label visible, ink text,
///                    lime icon
///   • Live button:   padding 10×14, always red `#ff3b3b` text on
///                    .10-alpha red bg with .28-alpha red inset stroke,
///                    pulsing red dot, "LIVE" label always visible
///   • Live active:   solid red bg, white text, white dot
struct FloatingNav: View {
    @Binding var tab: Pick1HomeHiFi.Tab
    let liveCount: Int

    /// Observed so the active-tab label re-renders in the new language
    /// the instant the user picks one in Profile → Language.
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        HStack(spacing: 2) {
            NavItem(icon: "house",
                    label: loc.t(.nav_home),
                    isActive: tab == .home) { tab = .home }
            NavItem(icon: "star",
                    label: loc.t(.nav_picks),
                    isActive: tab == .picks) { tab = .picks }
            LiveNavItem(isActive: tab == .live,
                        liveCount: liveCount) { tab = .live }
            NavItem(icon: "person",
                    label: loc.t(.nav_profile),
                    isActive: tab == .profile) { tab = .profile }
        }
        .padding(8)   // spec: padding 8px around the row
        // iOS 26 Liquid Glass — true refractive material rather than
        // the older blur-and-tint trick. `.regular` glass with a dark
        // panel tint preserves the design's #16181C feel while letting
        // content underneath bend through the capsule edges.
        // NOTE: `.interactive()` was previously applied here but it
        // adds a press response on the *whole glass*, which can race
        // with the inner Buttons' tap recognition (specifically the
        // Profile tab on the trailing edge). Plain glass below; the
        // individual NavItem buttons handle press feedback via their
        // own .buttonStyle(.plain).
        .glassCompat(in: .capsule, tint: Color(hex: "#16181C").opacity(0.55))
        // Subtle 1pt rim — Liquid Glass already draws an edge, but a
        // very faint white-on-white stroke keeps the pill legible
        // against bright lime hero backdrops.
        .overlay(
            Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        // Spec drop shadows kept — they sit under the glass, not on top.
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 20)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 4)
    }
}

/// Standard nav item (Home / Picks / Profile). Icon-only when inactive,
/// icon + label when active. Active state uses a lime *tint* (not solid
/// lime) with an inset lime stroke — matches `.nav-item.active` in the
/// design CSS.
struct NavItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    // Active icon turns lime; inactive stays mute.
                    .foregroundColor(isActive ? Color(hex: "#D4FF3A")
                                              : Color(hex: "#6E6F75"))
                if isActive {
                    Text(label)
                        .font(.archivo(13, weight: .bold))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        // Label fades in when the tab becomes active so
                        // the pill grows smoothly rather than popping.
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, isActive ? 18 : 14)
            .background(
                Capsule()
                    .fill(isActive ? Color(hex: "#D4FF3A").opacity(0.14)
                                   : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? Color(hex: "#D4FF3A").opacity(0.25)
                                     : Color.clear,
                            lineWidth: 1)
            )
            // CRITICAL: with a clear inactive background, SwiftUI by
            // default only counts the visible icon's bounding box as
            // tappable. Without an explicit .contentShape, taps that
            // land in the padded ring around the icon (most of the
            // pill area) miss the Button entirely. The Profile tab
            // was unreachable because the user's thumb was hitting
            // padding rather than the 17pt person glyph.
            .contentShape(Capsule())
        }
        // Press-state feedback applied as a ButtonStyle (the canonical
        // SwiftUI pattern). Earlier the press feedback was a separate
        // gesture inside the label, which competed with the Button's
        // tap recognizer and broke navigation — this is the fix.
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        // Animate the pill width / label appearance when the active
        // tab swaps — keeps the floating nav from snapping mid-press.
        .animation(Pick1Springs.snappy, value: isActive)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Live nav item — always red, always shows the "LIVE" label and a
/// pulsing dot. Active state flips to a solid red bg with white text.
/// Mirrors `.nav-item.live-btn` in the design CSS.
struct LiveNavItem: View {
    let isActive: Bool
    let liveCount: Int
    let action: () -> Void

    /// Drives the dot's pulse halo (spec uses a CSS keyframe).
    @State private var pulse: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ZStack {
                    // Outer halo — pulses out from the dot.
                    Circle()
                        .fill(haloColor.opacity(0.55))
                        .frame(width: pulse ? 22 : 8, height: pulse ? 22 : 8)
                        .opacity(pulse ? 0 : 1)
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 14, height: 14)
                if isActive {
                    Text(labelText)
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.8)
                        .foregroundColor(textColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, isActive ? 16 : 12)
            .background(Capsule().fill(bgColor))
            .overlay(Capsule().stroke(strokeColor, lineWidth: 1))
            .shadow(color: isActive
                        ? Color(hex: "#FF3B3B").opacity(0.45)
                        : .clear,
                    radius: isActive ? 10 : 0, x: 0, y: 4)
            .contentShape(Capsule())
        }
        // ButtonStyle-based press feedback (no gesture conflict).
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .animation(Pick1Springs.snappy, value: isActive)
        .animation(Pick1Springs.smooth, value: liveCount)
        .accessibilityLabel(liveCount > 0
                            ? "Live games, \(liveCount) playing now"
                            : "Live games")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)
                .repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    private var labelText: String {
        liveCount > 0 ? "LIVE \(liveCount)" : "LIVE"
    }

    private var bgColor: Color {
        isActive ? Color(hex: "#FF3B3B")
                 : Color(hex: "#FF3B3B").opacity(0.10)
    }

    private var strokeColor: Color {
        isActive ? Color(hex: "#FF5A5A").opacity(0.6)
                 : Color(hex: "#FF3B3B").opacity(0.28)
    }

    private var textColor: Color {
        isActive ? .white : Color(hex: "#FF5A5A")
    }

    private var dotColor: Color {
        isActive ? .white : Color(hex: "#FF3B3B")
    }

    private var haloColor: Color {
        isActive ? .white : Color(hex: "#FF3B3B")
    }
}

// MARK: - Locked Pro picks (Free tier)

/// Lime banner card shown above the locked picks list. Tapping it
/// presents the paywall.
struct ProUnlockCard: View {
    let lockedCount: Int
    let onUnlock: () -> Void
    /// Trial copy is eligibility-gated: Apple grants one intro offer per
    /// Apple ID per group, so a returning subscriber must see straight
    /// upgrade copy — never a "free trial" Apple won't honor at checkout.
    @EnvironmentObject private var subs: SubscriptionManager

    var body: some View {
        Button(action: onUnlock) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("PICK1 PRO")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                }
                .foregroundColor(Color(hex: "#0A0B0D").opacity(0.7))

                Text("Unlock \(lockedCount) more pick\(lockedCount == 1 ? "" : "s")")
                    .font(.anton(28))
                    .foregroundColor(Color(hex: "#0A0B0D"))

                HStack(spacing: 6) {
                    Text(subs.introOfferEligible ? "3-day free trial" : "Go Pro from $14.99/wk")
                        .font(.archivo(12, weight: .bold))
                        .foregroundColor(Color(hex: "#0A0B0D").opacity(0.85))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                LimeGlassSurface(cornerRadius: 22)
            )
            .shadow(color: Color(hex: "#a8e000").opacity(0.35), radius: 14, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - LimeGlassSurface
// ════════════════════════════════════════════════════════════════

/// Shared lime "Liquid Glass" background used by every green featured
/// card in the app — hero, ProUnlockCard, SmallPickHero, Profile's
/// upgrade card. Composes the iOS 26 .glassEffect material on top of
/// the original radial-lime gradient + adds an iridescent chromatic
/// sheen so the surface feels like glass rather than flat paint.
struct LimeGlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // Lime gradient base.
            Color(hex: "#D4FF3A")
            RadialGradient(
                colors: [Color(hex: "#eaff7a"), Color(hex: "#D4FF3A").opacity(0)],
                center: UnitPoint(x: 1.1, y: -0.2),
                startRadius: 30,
                endRadius: 350
            )

            // iOS 26 Liquid Glass texture overlay. Sits on top of the
            // lime so the surface gets the refractive depth +
            // specular highlights of Apple's glass material while the
            // lime color still drives the chroma. Kept LOW — at higher
            // opacity the glass composites the dark backdrop through and
            // muddies the lime toward olive (visibly darker than the
            // brand #D4FF3A on buttons).
            Color.clear
                .glassCompat(in: shape, interactive: true)
                .opacity(0.18)
                .allowsHitTesting(false)

            // Iridescent shimmer — violet-to-cyan ramp at low alpha so
            // the card catches light differently as it tilts.
            LinearGradient(
                colors: [
                    Color(hex: "#B9A6FF").opacity(0.06),
                    Color.clear,
                    Color(hex: "#7AE2FF").opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .allowsHitTesting(false)

            // Top sheen — bright inset highlight on the top edge.
            LinearGradient(
                colors: [Color.white.opacity(0.32), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.18)
            )
            .allowsHitTesting(false)
        }
        .clipShape(shape)
    }
}

/// A blurred, locked version of a real pick card. Same dimensions as
/// `GameCard` so the list rhythm is preserved.
/// Locked Pro pick card. Renders the full GameCard layout (real team
/// logos, team names, score/VS area, AI PICKS footer with mini-ring) but
/// blurred so the user can sense the pick exists, then overlays a
/// centered lime "UNLOCK WITH PRO" capsule as the focal CTA. Tap →
/// presents the paywall.
struct LockedPickCard: View {
    let pick: Pick
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            ZStack {
                // ─── Real card content, blurred ────────────────
                VStack(spacing: 0) {
                    // Top row — league kicker + AI confidence chip
                    HStack {
                        Text(scheduledTopLine)
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(2.2)
                            .foregroundColor(Color(hex: "#B9B7B0"))
                        Spacer()
                        ConfChip(percent: pick.probability,
                                 hot: pick.probability >= 80)
                    }
                    .padding(.bottom, 14)

                    // Teams row — real logos + names, will be blurred
                    HStack(alignment: .center, spacing: 12) {
                        VStack(spacing: 6) {
                            TeamLogo(sport: pick.sport,
                                     team: pick.awayTeam,
                                     size: .big)
                            Text(teamShortName(pick.awayTeam, sport: pick.sport))
                                .font(.anton(16))
                                .foregroundColor(Color(hex: "#F5F3EE"))
                        }
                        .frame(maxWidth: .infinity)

                        Text("VS")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(hex: "#6E6F75"))

                        VStack(spacing: 6) {
                            TeamLogo(sport: pick.sport,
                                     team: pick.homeTeam,
                                     size: .big)
                            Text(teamShortName(pick.homeTeam, sport: pick.sport))
                                .font(.anton(16))
                                .foregroundColor(Color(hex: "#F5F3EE"))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Divider + AI PICKS footer (mirrors GameCard)
                    Divider()
                        .background(Color(hex: "#22252B"))
                        .padding(.top, 14)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI PICKS")
                                .font(.archivoNarrow(10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(Color(hex: "#B9B7B0"))
                            Text(pick.displayPick.uppercased())
                                .font(.anton(17))
                                .tracking(0.17)
                                .foregroundColor(Color(hex: "#D4FF3A"))
                        }
                        Spacer()
                        MiniRing(percent: pick.probability)
                    }
                    .padding(.top, 12)
                }
                // The blur happens here — entire card content goes
                // soft so the user can see structure + crests but
                // can't read the pick or score.
                .blur(radius: 7)
                .opacity(0.6)

                // ─── Centered Unlock CTA — never blurred ────────
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                    Text("UNLOCK WITH PRO")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#0A0B0D"))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(hex: "#D4FF3A"))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "#D4FF3A").opacity(0.5),
                        radius: 14, x: 0, y: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                // Same gradient + 4-shadow stack as GameCard so the
                // locked card doesn't look like a different surface.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#14161a"), Color(hex: "#0e0f12")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color(hex: "#22252B"), lineWidth: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            .mask(LinearGradient(colors: [.white, .clear],
                                                 startPoint: .top, endPoint: .center))
                    )
                    .shadow(color: .black.opacity(0.7), radius: 10, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    /// Same scheduled-top-line mapping as GameCard.
    private var scheduledTopLine: String {
        let league = displayLeague(pick.league)
        switch league {
        case "EPL": return "EPL · MATCHDAY"
        case "NFL": return "NFL · PRIMETIME"
        case "MLB": return "MLB · TODAY"
        case "NBA": return "NBA · TONIGHT"
        case "NHL": return "NHL · TONIGHT"
        case "UFC": return "UFC · MAIN CARD"
        case "F1":  return "F1 · RACE WEEKEND"
        case "IPL": return "IPL · MATCH DAY"
        default:
            // Cryptic leagues get a country flag so the card is self-explanatory.
            if let flag = leagueFlag(pick.league) { return "\(league) \(flag)" }
            return league
        }
    }
}

// MARK: - Empty + Profile placeholder

struct EmptyTodayState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 38))
                .foregroundColor(Color(hex: "#6E6F75"))
            Text("NO GAMES FOR TODAY")
                .font(.archivoNarrow(13, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text("New picks drop daily by 5:00 AM ET")
                .font(.archivo(12, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}


// MARK: - Preview

#Preview {
    Pick1HomeHiFi()
        .preferredColorScheme(.dark)
}
