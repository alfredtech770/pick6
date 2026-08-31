// Pick1Screens.swift
// All non-Home screens from the design handoff:
//   • MatchDetailView   — Pick6 Detail Pages.html (tap a card → push)
//   • SportHubView      — Pick6 Sport Hubs.html  (tap sport header chip)
//   • ProfileView       — Pick6 Account Pages.html → Profile
//   • WinsView          — Pick6 Account Pages.html → Wins / Favorites
//   • LiveView          — Pick6 Account Pages.html → Live (in-play tracker)
//   • AllPicksView      — Picks tab (full list of today's picks, no hero)
//
// Shared chrome (TopNavBar, PageHero, etc.) and design tokens (Color hex,
// Font.anton/archivo/archivoNarrow/mono) live in Pick1HomeHiFi.swift.

import SwiftUI
import UserNotifications

// ════════════════════════════════════════════════════════════════
// MARK: - Shared chrome
// ════════════════════════════════════════════════════════════════

/// Top nav: 38pt back chip + breadcrumb + 38pt spacer.
struct TopNavBar: View {
    let crumb: String
    let crumbAccent: String?
    let live: Bool
    let onBack: () -> Void
    /// Hide the leading chevron when this view is a primary tab (Profile,
    /// Wins, Live) — there's nowhere to go "back" to. Sheets that push on
    /// top of the tab stack (MatchDetail, SportHub) keep the chevron.
    var showBack: Bool = true

    var body: some View {
        HStack(alignment: .center) {
            if showBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "#1D1D1D"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            } else {
                // Invisible spacer so the centered crumb stays centered.
                Color.clear.frame(width: 38, height: 38)
            }
            Spacer()
            HStack(spacing: 6) {
                if live {
                    Circle()
                        .fill(Color(hex: "#FF5A36"))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color(hex: "#FF5A36"), radius: 4)
                }
                Text(crumb)
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Color(hex: "#6E6F75"))
                if let accent = crumbAccent {
                    Text(accent)
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
            }
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }
}

/// Big page hero used on Profile/Wins/Live: 72pt Anton title with one
/// word colored lime + sublabel chips and a per-screen radial glow.
struct PageHero: View {
    let title: String           // "YOUR"
    let titleAccent: String     // "WINS." (rendered in lime)
    let sub: [String]           // chips separated by mute dots
    let glow: Color             // per-screen radial glow tint

    var body: some View {
        // Layout is driven by the title + sub-chips; the radial glow
        // is a `.background` so it bleeds behind the text without
        // claiming an extra ~125pt of empty space below the sub line
        // (which the previous `.frame(height: 220)` on the gradient
        // forced into the layout).
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.anton(72))
                    .lineSpacing(-12)
                    .tracking(-0.7)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text(titleAccent)
                    .font(.anton(72))
                    .lineSpacing(-12)
                    .tracking(-0.7)
                    .foregroundColor(Color(hex: "#C6FF34"))
            }
            .padding(.top, 6)

            HStack(spacing: 8) {
                ForEach(Array(sub.enumerated()), id: \.offset) { i, item in
                    if i > 0 {
                        Circle()
                            .fill(Color(hex: "#6E6F75"))
                            .frame(width: 4, height: 4)
                    }
                    Text(item)
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            RadialGradient(
                colors: [glow, .clear],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0,
                endRadius: 220
            )
            .frame(width: 380, height: 280)
            .opacity(0.9)
            .blur(radius: 30)
            .offset(x: 60, y: -40)
            .allowsHitTesting(false)
        }
    }
}

/// Section header — Anton 22pt + meta row.
struct HubSectionHead: View {
    let title: String
    let meta: String?
    let live: Bool

    init(title: String, meta: String? = nil, live: Bool = false) {
        self.title = title
        self.meta = meta
        self.live = live
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.anton(22))
                .tracking(-0.05)
                .foregroundColor(Color(hex: "#F5F3EE"))
            Spacer()
            if let meta = meta {
                HStack(spacing: 6) {
                    if live {
                        Circle()
                            .fill(Color(hex: "#FF5A36"))
                            .frame(width: 6, height: 6)
                    }
                    Text(meta)
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// Reusable card background — matches the design spec for `.gcard`:
/// vertical gradient #14161a → #1B1B1B, --line border, plus a 4-shadow
/// stack (inset top white highlight + drop shadow main + drop secondary)
/// to give every card the "stadium-scoreboard 3D lift" the design calls
/// for. Used by every list/card surface in the app for visual consistency.
private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(LinearGradient(
            colors: [V4.panelTop, V4.panelBot],
            startPoint: .top, endPoint: .bottom
        ))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(V4.line, lineWidth: 1)
        )
        // Inset top highlight — a 1pt bright stroke faded to clear in the
        // top half of the card. Mimics CSS `inset 0 1px 0 rgba(255,255,255,0.07)`.
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear],
                                     startPoint: .top, endPoint: .center))
        )
        .shadow(color: .black.opacity(0.7), radius: 10, x: 0, y: 10)
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
}

/// State-tinted "receipt" frame — the 2026-07 home-redesign card
/// language (see WinReceiptCard / LockedSlateCard): tinted dark fill +
/// accent wash from the top-left + accent stroke. Used by the tracking
/// (Picks) and Live pages so their frames match the new home.
private func receiptCardBackground(accent: Color, fill: String) -> some View {
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color(hex: fill))
        .overlay(
            LinearGradient(colors: [accent.opacity(0.13), .clear],
                           startPoint: .topLeading, endPoint: .center)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
}

/// Per-state receipt frame: won = brand lime, lost = red, live =
/// orange. Upcoming / awaiting rows keep the quiet scoreboard card so
/// settled outcomes pop against them.
@ViewBuilder
func stateCardBackground(_ state: PickRenderState) -> some View {
    switch state {
    case .won:  receiptCardBackground(accent: Color(hex: "#C6FF34"), fill: "#111309")
    case .lost: receiptCardBackground(accent: Color(hex: "#FF5A5A"), fill: "#130E0E")
    case .live: receiptCardBackground(accent: Color(hex: "#FF5A36"), fill: "#130F0C")
    case .awaitingResult, .upcoming: cardBackground
    }
}

/// "TODAY · 7:30 PM" / "TOMORROW · 12:30 AM" / "FRI · 8:20 PM" —
/// kickoff label used in score-areas of cards when the game hasn't
/// started yet. Module-level so both CompactPickCard and
/// MatchDetailView can call it without duplication.
func kickoffTimeText(_ kickoff: Date) -> String {
    let cal = Calendar.current
    let dayPart: String
    if cal.isDateInToday(kickoff)         { dayPart = "TODAY" }
    else if cal.isDateInTomorrow(kickoff) { dayPart = "TOMORROW" }
    else {
        let f = DateFormatter(); f.dateFormat = "EEE"
        dayPart = f.string(from: kickoff).uppercased()
    }
    let f = DateFormatter(); f.dateFormat = "h:mm a"
    return "\(dayPart) · \(f.string(from: kickoff))"
}

// ════════════════════════════════════════════════════════════════
// MARK: - Match Detail (Pick6 Detail Pages)
// ════════════════════════════════════════════════════════════════

struct MatchDetailView: View {
    let pick: Pick
    let liveScore: LiveScore?
    let onClose: () -> Void
    /// Present already showing the stake sheet. Set when the user arrived by
    /// tapping TRACK on a Home v4 game row: they picked the action, so making
    /// them find the bar again is friction.
    var openTrackSheet: Bool = false

    /// Tab identity follows the Detail Pages design: SUMMARY · LINEUPS ·
    /// ODDS · H2H. The `lineups` slot is sport-aware via `tabLabel(_:)`
    /// so it reads GRID for racing, FIGHTERS for MMA, ROSTERS for tennis
    /// or cricket, and LINEUPS otherwise.
    // Tabs reduced to the two backed by REAL data: the AI's actual
    // analysis (reasoning + key factor + confidence, from the pick)
    // and odds. The old LINEUPS / H2H tabs were hardcoded placeholder
    // rosters and fake past-game results — removed rather than ship
    // fabricated content in a sports app.
    enum Tab: String, CaseIterable { case ourCall, summary, stats }
    @State private var tab: Tab = .ourCall
    @State private var showToast: Bool = false
    @StateObject private var betTracker = BetTracker.shared
    @State private var showTrackSheet = false
    @State private var showShareWin = false

    /// Persistent favorites (drives the Wins/Picks tab list). Replaces
    /// the prior local `@State starred` flag — that flag was per-sheet
    /// and didn't survive the sheet closing, which is why favorited
    /// matches never appeared in the Wins page.
    @EnvironmentObject private var favorites: FavoritesStore
    private var starred: Bool { favorites.contains(pick.id) }
    private var isTracking: Bool { starred || betTracker.isTracked(pick.id) }

    private func tabLabel(_ which: Tab) -> String {
        switch which {
        case .ourCall: return t(.rd_our_call)
        case .summary: return t(.rd_ai_analysis)
        case .stats:
            // Sport-adaptive stats label.
            switch pick.sport {
            case "combat": return t(.rd_fighters)
            case "f1", "golf": return t(.rd_field)
            case "tennis": return t(.rd_players)
            default: return t(.rd_team_stats)
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
        ZStack(alignment: .top) {
            Color(hex: "#07080a").ignoresSafeArea()

            // The content column is pinned to exactly the container width.
            // scrollBounceBehavior alone wasn't enough: any row rendering
            // even a point wider than the screen (long team names, tracked
            // type, fixed tiles) grew the scroll content box sideways and
            // the whole page panned left/right on diagonal swipes. With the
            // frame clamped, horizontal movement is impossible no matter
            // what a child renders; overflow just clips.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    detailTopNav
                    // The pick, as a ticket. One object states the call, the
                    // terms and its own outcome; everything below it argues
                    // for the call. This replaces three separate blocks (the
                    // matchup header, the PICK1'S CALL heading and the hero
                    // card) that between them printed the confidence three
                    // times and the track action twice.
                    P1PickTicket(pick: pick,
                                 homeScore: liveScore?.homeScore ?? pick.homeScore,
                                 awayScore: liveScore?.awayScore ?? pick.awayScore,
                                 isLive: liveScore?.isLive ?? false,
                                 scoreLine: scorePredictionLine,
                                 confidence: confidenceDisplay,
                                 loggedAt: loggedTimeText)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)

                    // What the ticket does not have room for, kept as a quiet
                    // strip rather than dropped: edge versus the market, and
                    // the clock.
                    HStack(spacing: 0) {
                        ForEach(Array(pickHeroStats.enumerated()), id: \.element.label) { i, stat in
                            if i > 0 { Rectangle().fill(V4.line).frame(width: 1, height: 22) }
                            VStack(spacing: 3) {
                                Text(stat.label)
                                    .font(.archivoNarrow(8.5, weight: .bold)).tracking(1.4)
                                    .foregroundColor(Color(hex: "#6E6F75"))
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text(stat.value)
                                        .font(.anton(15))
                                        .foregroundColor(Color(hex: "#F5F3EE"))
                                    if let suffix = stat.suffix {
                                        Text(suffix)
                                            .font(.mono(9, weight: .semibold))
                                            .foregroundColor(Color(hex: "#B9B7B0"))
                                    }
                                }
                                .lineLimit(1).minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    // Won pick → the share-your-gains viral loop. Free
                    // users earn 24h of Premium for a completed share.
                    if pick.isWin {
                        Button {
                            Haptics.tap()
                            showShareWin = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                Text(t(.sw_share_win))
                                    .font(.anton(15)).kerning(0.4)
                            }
                            .foregroundColor(Color(hex: "#171717"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 13)
                                .fill(Color(hex: "#C6FF34")))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 22)
                    }
                    // "What is this league" descriptor — only shows for
                    // leagues whose code isn't self-explanatory (KBO, NPB,
                    // EuroLeague, …), so users know what they're looking at.
                    if let blurb = leagueBlurb(pick.league) {
                        Text(blurb)
                            .font(.archivo(11, weight: .medium))
                            .foregroundColor(Color(hex: "#8A8D94"))
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 12)
                    }
                    // (RECENT FORM lives in the TEAM STATS tab — not repeated here.)
                    // The PICK1'S CALL heading and `pickHeroCard` used to sit
                    // here. Both are now the ticket above: the heading named a
                    // section whose only content was the card, and the card
                    // restated the call the header had just made.
                    // The "WHY <team>" factor panel used to sit here. Removed
                    // at Ethan's request 2026-08-25: the same `pick.factors`
                    // already drive the home hero's "why the AI likes it", and
                    // the OUR CALL tab below carries the reasoning in prose.
                    tabsRow
                    Group {
                        switch tab {
                        case .ourCall:
                            ourCallPanel
                        case .summary:
                            VStack(spacing: 14) {
                                summaryPanel
                                projectionPanel
                            }
                        case .stats:
                            // Sport-adaptive stats: race podium (F1/golf),
                            // tale of the tape (MMA), form guide (soccer),
                            // grounded matchup facts (everything else).
                            VStack(spacing: 14) {
                                if isRaceEvent, let drivers = pick.fieldOdds, !drivers.isEmpty {
                                    racePodiumPanel(drivers)
                                } else if pick.sport == "combat", pick.taleOfTape != nil {
                                    taleOfTapePanel
                                } else if pick.sport == "soccer", pick.soccerComparison != nil {
                                    formGuidePanel
                                    matchupPanel
                                } else {
                                    matchupPanel
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    Spacer().frame(height: 120)
                }
                // Hard width pin: an overwide child (long factor value,
                // wide table) must clip, never widen the scrollable content
                // — a wider content size is what made the page pannable
                // sideways.
                .frame(width: UIScreen.main.bounds.width)
                .frame(width: geo.size.width)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)

            // Toast
            if showToast {
                Text(t(.card_saved_toast, count: Int(pick.probability)))
                    .font(.archivo(12, weight: .bold))
                    .foregroundColor(Color(hex: "#171717"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#F5F3EE"))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

        }
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            unifiedTrackBar
        }
        .onAppear { if openTrackSheet { showTrackSheet = true } }
        .sheet(isPresented: $showTrackSheet) {
            TrackBetSheet(
                pick: pick,
                accent: sportAccent,
                onTrack: { stake in startTracking(stake: stake) },
                isTracked: isTracking,
                onUntrack: { stopTracking() }
            )
            .presentationDetents([.height(isTracking ? 420 : 360)])
            .onAppear {
                Analytics.trackSheetViewed(league: pick.league, alreadyTracked: isTracking)
            }
        }
        .task { if !betTracker.loaded { await betTracker.load() } }
        // Engagement signal → PostHog (pick_viewed) + Meta (ViewContent,
        // content_type = league). Fires once whenever a pick detail opens,
        // from any screen that presents MatchDetailView.
        .onAppear { Analytics.pickViewed(league: pick.league) }
    }

    private var detailTopNav: some View {
        // Back arrow only. This used to carry a TRACK YOUR PICK capsule as a
        // trailing overlay, which meant the same action sat on screen twice
        // at once: here, and in the sticky bar that is pinned to the bottom
        // on every scroll position. The sticky bar wins, because it is
        // reachable with a thumb and never scrolls away.
        TopNavBar(
            crumb: "",
            crumbAccent: "",
            live: false,
            onBack: onClose
        )
    }

    /// Authoritative state for this whole detail surface. Drives the
    /// top-nav crumb suffix, the clock pill, and the score center column
    /// so they all agree (e.g. all four read AWAITING for a yesterday's-
    /// MLB pick that the grader hasn't seen yet).
    private var state: PickRenderState {
        pick.renderState(liveScore: liveScore)
    }

    /// The action colour, and it is lime on every sport.
    ///
    /// This used to be a per-sport accent (UFC red, NFL purple, NHL blue…)
    /// so each detail page "read distinctly". Against the v4 home that
    /// backfired: opening a fight pick turned the whole page red while the
    /// home it came from was lime on ink, and the two screens stopped
    /// looking like the same app. v4 already carries sport identity the
    /// right way — as a *glow*, not as a tint — so identity moves to
    /// `sportGlow` and the accent goes back to the brand.
    private var sportAccent: Color { Color.p1Lime }

    /// Sport identity, used only for blooms and washes behind content —
    /// never for text or fills. Same source as the home's orbs.
    private var sportGlow: Color { V4.glow(pick.sport) }

    /// Dark ink that reads well on top of `sportAccent` (all the
    /// accents are bright enough that near-black text/icons sit on
    /// them cleanly, matching the original lime-on-ink treatment).
    private var sportAccentInk: Color { Color(hex: "#171717") }

    private var scheduledOrLiveLabel: String {
        switch state {
        case .live:
            if let s = liveScore {
                let q = s.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? (s.status ?? "LIVE").uppercased()
                return "\(t(.card_live)) · \(q)"
            }
            return "LIVE"
        case .awaitingResult: return "AWAITING"
        case .won:            return "FINAL · W"
        case .lost:           return "FINAL · L"
        case .upcoming:       return "TODAY"
        }
    }

    /// Race events (F1/NASCAR) use the field-odds frame instead of a
    /// two-competitor matchup card.
    private var isRaceEvent: Bool { pick.sport == "f1" || pick.sport == "golf" }

    /// Podium-probabilities frame: every contending driver with their
    /// win and podium (top-3) chances, ranked, the AI's pick highlighted.
    /// Replaces the nonsensical "driver vs Field" stat rows for races.
    private func racePodiumPanel(_ raw: [DriverOdds]) -> some View {
        let drivers = raw.sorted { $0.win > $1.win }
        let maxWin = max(1, drivers.map { $0.win }.max() ?? 1)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(t(.rd_podium_probs))
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                Text("\(drivers.count) DRIVERS")
                    .font(.mono(9, weight: .bold))
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
            .padding(.bottom, 4)
            HStack {
                Text(t(.rd_win_podium_chance))
                    .font(.mono(9, weight: .medium))
                    .foregroundColor(Color(hex: "#6E6F75"))
                Spacer()
                Text(t(.rd_win_word))
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.4)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(width: 44, alignment: .trailing)
                Text(t(.rd_podium_word))
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.4)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.bottom, 10)
            VStack(spacing: 8) {
                ForEach(Array(drivers.enumerated()), id: \.element.id) { idx, d in
                    let isPicked = d.name.caseInsensitiveCompare(pick.pick) == .orderedSame
                        || pick.pick.localizedCaseInsensitiveContains(d.name)
                    HStack(spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.mono(11, weight: .heavy))
                            .foregroundColor(isPicked ? sportAccent : Color(hex: "#6E6F75"))
                            .frame(width: 18, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.name.uppercased())
                                .font(.archivo(12, weight: .bold))
                                .foregroundColor(isPicked ? sportAccent : Color(hex: "#F5F3EE"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: "#1A1C20"))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isPicked ? sportAccent : Color(hex: "#3A3D44"))
                                        .frame(width: geo.size.width * CGFloat(d.win / maxWin),
                                               height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        Text("\(Int(d.win.rounded()))%")
                            .font(.mono(12, weight: .heavy))
                            .foregroundColor(isPicked ? sportAccent : Color(hex: "#F5F3EE"))
                            .frame(width: 44, alignment: .trailing)
                        Text("\(Int(d.podium.rounded()))%")
                            .font(.mono(12, weight: .bold))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: "#1D1D1D"))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
        )
    }

    /// Score header — `home` always renders on the LEFT, `away` on the RIGHT.
    /// Each team gets a real `TeamLogo` (uses our ESPN-CDN wrapper, falls back
    /// to the colored shield for individual-athlete sports). Team names are
    /// fixed 30pt Anton (26pt for tennis/UFC/F1 where names are longer).
    /// Field events (F1, golf) aren't head-to-head — "CHAMPIONSHIP VS
    /// FIELD" reads as nonsense — so they get a single-competitor header:
    /// the picked driver/golfer + the event name.
    private var scoreHeader: some View {
        if isRaceEvent { return AnyView(fieldEventHeader) }
        return AnyView(twoColumnHeader)
    }

    private var fieldEventHeader: some View {
        VStack(spacing: 8) {
            AthleteHeadshot(sport: pick.sport, name: pick.pick, size: .big)
            Text(t(.rd_our_pick_to_win))
                .font(.archivoNarrow(10, weight: .bold)).tracking(2.8)
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(teamShortName(pick.pick, sport: pick.sport))
                .font(.anton(30)).tracking(-0.15)
                .foregroundColor(Color(hex: "#F5F3EE"))
                .lineLimit(1).minimumScaleFactor(0.45).allowsTightening(true)
            Text(pick.homeTeam.uppercased())
                .font(.archivoNarrow(11, weight: .bold)).tracking(1.4)
                .foregroundColor(sportAccent)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 18)
    }

    private var twoColumnHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            // HOME column (always left)
            VStack(spacing: 8) {
                TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .big)
                Text(t(.rd_home_label))
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.8)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(teamShortName(pick.homeTeam, sport: pick.sport))
                    .font(.anton(teamTight ? 26 : 30))
                    .tracking(-0.15)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity)

            // CENTER score / VS column
            VStack(spacing: 8) {
                clockPill
                scoreCenter
            }

            // AWAY column (always right)
            VStack(spacing: 8) {
                TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .big)
                Text(t(.rd_away_label))
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.8)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(teamShortName(pick.awayTeam, sport: pick.sport))
                    .font(.anton(teamTight ? 26 : 30))
                    .tracking(-0.15)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    /// Sport-specific layouts use slightly tighter Anton (26pt vs 30pt)
    /// because individual-athlete names tend to be longer.
    private var teamTight: Bool {
        // Cricket and soccer carry long national-team names
        // ("SRI LANKA W") — start them at the tighter size too.
        ["combat", "tennis", "f1", "cricket", "soccer"].contains(pick.sport)
    }

    /// Clock pill above the score. Per-state styling:
    ///   .live           → lime "Q3" / "LIVE" pill (active)
    ///   .awaitingResult → amber AWAITING pill (clear signal the pick
    ///                     is not yet graded, no fake kickoff time)
    ///   .won            → lime FINAL · W pill
    ///   .lost           → red FINAL · L pill
    ///   .upcoming       → neutral grey kickoff string (design's .clock)
    @ViewBuilder
    private var clockPill: some View {
        switch state {
        case .live:
            Text(liveScore?.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? "LIVE")
                .font(.mono(12, weight: .bold))
                .foregroundColor(Color(hex: "#C6FF34"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "#C6FF34").opacity(0.08))
                .overlay(Capsule().stroke(Color(hex: "#C6FF34").opacity(0.22), lineWidth: 1))
                .clipShape(Capsule())
        case .awaitingResult:
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text(t(.card_awaiting))
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(Color(hex: "#F59E0B"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: "#F59E0B").opacity(0.08))
            .overlay(Capsule().stroke(Color(hex: "#F59E0B").opacity(0.22), lineWidth: 1))
            .clipShape(Capsule())
        case .won:
            Text(t(.rd_final_w))
                .font(.mono(11, weight: .bold))
                .foregroundColor(Color(hex: "#4ADE80"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "#4ADE80").opacity(0.08))
                .overlay(Capsule().stroke(Color(hex: "#4ADE80").opacity(0.22), lineWidth: 1))
                .clipShape(Capsule())
        case .lost:
            Text(t(.rd_final_l))
                .font(.mono(11, weight: .bold))
                .foregroundColor(Color(hex: "#FF5A36"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "#FF5A36").opacity(0.08))
                .overlay(Capsule().stroke(Color(hex: "#FF5A36").opacity(0.22), lineWidth: 1))
                .clipShape(Capsule())
        case .upcoming:
            if let label = scheduledClockText {
                Text(label)
                    .font(.mono(11, weight: .bold))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#1D1D1D"))
                    .overlay(Capsule().stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
                    .clipShape(Capsule())
            }
        }
    }

    /// Score in the center column. Per-state:
    ///   .live / .won / .lost → numeric box score (from live_scores or,
    ///                          for graded picks, pick.home/awayScore)
    ///   .awaitingResult       → amber hourglass + AWAITING (no fake VS)
    ///   .upcoming             → "VS" + kickoff time
    @ViewBuilder
    private var scoreCenter: some View {
        switch state {
        case .live, .won, .lost:
            // Prefer the live_scores row (fresher), fall back to the
            // box-score stored on the graded pick row.
            let h = liveScore?.homeScore ?? pick.homeScore
            let a = liveScore?.awayScore ?? pick.awayScore
            if let h, let a {
                // Single-line score row. Three Texts in a HStack used to
                // wrap to 3 lines on basketball (3-digit scores in a
                // narrow center column) — fixedSize forces SwiftUI to
                // honor the natural width, and lineLimit + minimumScaleFactor
                // keep "112-108" readable in tight space.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(h)")
                        .font(.anton(46))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                    Text("–")
                        .font(.anton(32))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .lineLimit(1)
                    Text("\(a)")
                        .font(.anton(46))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                        .lineLimit(1)
                }
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: true, vertical: false)
            } else {
                Text(state == .live ? "LIVE" : "FINAL")
                    .font(.anton(28))
                    .tracking(2.8)
                    .foregroundColor(state == .live
                                     ? Color(hex: "#FF5A36")
                                     : Color(hex: "#B9B7B0"))
            }

        case .awaitingResult:
            VStack(spacing: 6) {
                Image(systemName: "hourglass")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text(t(.card_awaiting))
                    .font(.anton(20))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text(t(.rd_pending_grade))
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }

        case .upcoming:
            VStack(spacing: 4) {
                Text("VS")
                    .font(.anton(28))
                    .tracking(2.8)
                    .foregroundColor(Color(hex: "#C6FF34"))
                if let kickoff = liveScore?.startTime {
                    Text(kickoffTimeText(kickoff))
                        .font(.mono(11, weight: .bold))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
            }
        }
    }

    // (kickoffTimeText moved to module scope below so CompactPickCard
    //  can use it too.)

    /// Localized weekday + time string for scheduled games (e.g. "SUN · 8:20 PM").
    private var scheduledClockText: String? {
        guard let date = pick.createdAt else { return nil }
        let f = DateFormatter()
        f.dateFormat = "EEE · h:mm a"
        return f.string(from: date).uppercased()
    }

    /// Stat icon row — 4-6 sport-specific tiles. Tile 0 always renders
    /// in the lime "active" state per the design.
    private var statIconRow: some View {
        let tiles = StatTiles.tiles(for: pick.sport, liveScore: liveScore)
        return HStack(spacing: 4) {
            ForEach(tiles.indices, id: \.self) { i in
                statTile(tiles[i], active: i == 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
    }

    private func statTile(_ tile: MatchStatTile, active: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: tile.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(active ? sportAccent : Color(hex: "#B9B7B0"))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active
                              ? sportAccent.opacity(0.1)
                              : Color(hex: "#1D1D1D"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(active
                                        ? sportAccent.opacity(0.3)
                                        : Color(hex: "#2F2F2F"), lineWidth: 1)
                        )
                )
            Text(tile.label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.6)
                .foregroundColor(active ? sportAccent : Color(hex: "#B9B7B0"))
            Text(tile.value)
                .font(.mono(10, weight: .bold))
                .foregroundColor(active ? sportAccent : Color(hex: "#F5F3EE"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// Pick hero — mirrors the design's `.pick-card.hero`. Three blocks
    /// stacked top-to-bottom inside a single dark card with a lime
    /// radial bloom in the corner:
    ///   1. Pick head (kicker on the left, conf badge on the right)
    ///   2. Big Anton title with the second word emphasised in lime
    ///   3. Expected return block — single hero stat (lime panel)
    ///   4. Pick row — three stat columns (ODDS / EDGE / TIPOFF), divided
    private var pickHeroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mock layout: AI PICKS label → NAME + WIN% on one baseline →
            // divider → LOGGED time · Confidence tier.
            HStack {
                Text(t(.rd_ai_picks))
                    .font(.archivoNarrow(10, weight: .bold)).tracking(2.4)
                    .foregroundColor(Color(hex: "#8A8D94"))
                Spacer()
            }
            .padding(.bottom, 2)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(pick.shortDisplayPick.uppercased())
                    .font(.anton(40)).tracking(-0.4)
                    .foregroundColor(sportAccent)
                    .lineLimit(1).minimumScaleFactor(0.45)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: -2) {
                    Text("\(Int(pick.probability))%")
                        .font(.anton(40)).tracking(-0.4)
                        .foregroundColor(V4.win)
                    Text(t(.rd_win_prob))
                        .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            }
            Rectangle().fill(V4.line).frame(height: 1)
                .padding(.top, 12)
            HStack {
                Text("\(t(.rd_logged)) \(loggedTimeText)")
                    .font(.mono(10, weight: .bold)).tracking(1.2)
                    .foregroundColor(Color(hex: "#8A8D94"))
                Spacer()
                (Text(t(.rd_confidence_prefix)).foregroundColor(Color(hex: "#8A8D94"))
                 + Text(confidenceDisplay).foregroundColor(sportAccent))
                    .font(.mono(11, weight: .bold))
            }
            .padding(.top, 10)
            .padding(.top, 4)

            // Potential payout — the number users actually understand:
            // the odds multiplier and what $100 turns into. (The old
            // "EXPECTED RETURN −6.0% vs market consensus" read as
            // analyst jargon; AI edge now lives in the stat row.)
            VStack(alignment: .center, spacing: 4) {
                Text(hasMarketOdds ? t(.rd_potential_payout) : "MODEL FAIR PRICE")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(payoutMultiplierText)
                    .font(.anton(44))
                    .tracking(-0.4)
                    .foregroundColor(sportAccent)
                    .shadow(color: sportAccent.opacity(0.35),
                            radius: 8, x: 0, y: 0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(payoutSubText)
                    .font(.archivoNarrow(11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Text(payoutSourceText)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(sportAccent.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(sportAccent.opacity(0.22), lineWidth: 1)
                    )
            )
            .padding(.top, 16)

            // Score prediction + (after grading) how accurate it was.
            // This answers "did we just call the winner, or the score?"
            if let scoreLine = scorePredictionLine {
                HStack(spacing: 8) {
                    Image(systemName: scoreLine.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(scoreLine.color)
                    Text(scoreLine.text)
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(scoreLine.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(scoreLine.color.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(scoreLine.color.opacity(0.3), lineWidth: 1)
                )
                .padding(.top, 10)
            }

            // Pick row — three stat columns, divided
            HStack(spacing: 6) {
                ForEach(pickHeroStats, id: \.label) { s in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.label)
                            .font(.archivoNarrow(9, weight: .bold))
                            .tracking(1.8)
                            .foregroundColor(Color(hex: "#6E6F75"))
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text(s.value)
                                .font(.anton(18))
                                .foregroundColor(Color(hex: "#F5F3EE"))
                            if let suffix = s.suffix {
                                Text(suffix)
                                    .font(.mono(10, weight: .semibold))
                                    .foregroundColor(Color(hex: "#B9B7B0"))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(V4.line)
                    .frame(height: 1)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [V4.panelTop, V4.panelBot],
                    startPoint: .top, endPoint: .bottom
                ))
                // Accent glow FIRST, then clip everything to the card shape
                // (the old .clipped() only trimmed to the circle's square
                // frame, letting the glow bleed past the rounded corner)…
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(RadialGradient(
                            colors: [sportGlow.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        ))
                        .frame(width: 180, height: 180)
                        .offset(x: 60, y: -60)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                // …stroke last so the border isn't half-clipped.
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(V4.line, lineWidth: 1)
                )
        )
    }

    // ─── Pick hero data helpers ────────────────────────────────────

    /// Kicker varies by game state — "AI PICK · LIVE" while the game is
    /// in progress, "AI PICK · PREGAME" before tipoff. Mirrors the design's
    /// `.pick-head .k` content variation across the EPL/NFL/UFC mocks.
    private var pickKicker: String {
        if liveScore?.isLive == true { return "AI PICK · LIVE" }
        return "AI PICK · PREGAME"
    }

    /// First word of the pick (e.g. "ARSENAL" of "ARSENAL TO HOLD LEAD").
    /// Falls back to the whole pick string if there's no whitespace.
    private var pickTitleHead: String {
        let words = pick.shortDisplayPick.uppercased().split(separator: " ")
        guard words.count > 1 else { return pick.displayPick.uppercased() }
        // Take the first 1-2 words as the head segment so the lime tail
        // gets a meaningful phrase rather than just the last word.
        let headCount = words.count >= 4 ? 2 : 1
        return words.prefix(headCount).joined(separator: " ")
    }

    /// Remaining words of the pick, displayed in lime under the head.
    private var pickTitleTail: String {
        let words = pick.shortDisplayPick.uppercased().split(separator: " ")
        guard words.count > 1 else { return "" }
        let headCount = words.count >= 4 ? 2 : 1
        return words.dropFirst(headCount).joined(separator: " ")
    }

    /// Decimal odds for the EV calculation and the odds stat column.
    /// REAL market odds (Polymarket / sportsbook, captured by the
    /// pipeline at generation time) when available; otherwise falls
    /// back to odds implied by the AI's own confidence — which makes
    /// expected return read ~0 by construction, so the market quote
    /// is what gives this number its meaning.
    private var decimalOdds: Double {
        if let market = pick.marketOdds, market > 1.0 { return market }
        // Fallback: avoid divide-by-zero at extremes; sensible band.
        let p = max(0.40, min(0.90, pick.probability / 100.0))
        return max(1.20, 1.0 / p)
    }

    /// True when decimalOdds is a real market quote.
    private var hasMarketOdds: Bool { (pick.marketOdds ?? 0) > 1.0 }

    /// One-line score-prediction status for the hero card.
    /// Pregame:  "AI PREDICTED SCORE  2-1"
    /// Graded:   exact hit / winner-only / miss, with the actual final.
    private var scorePredictionLine: (icon: String, text: String, color: Color)? {
        let lime = Color(hex: "#C6FF34")
        let green = Color(hex: "#22C55E")
        let mute = Color(hex: "#6E6F75")
        if pick.isPending {
            guard let pred = pick.predictedScore else { return nil }
            return ("target", "\(t(.rd_predicted_score))  \(pred)", lime)
        }
        guard let acc = pick.predictionAccuracy else { return nil }
        let final = (pick.homeScore != nil && pick.awayScore != nil)
            ? "\(pick.homeScore!)-\(pick.awayScore!)" : "—"
        let pred = pick.predictedScore ?? "—"
        switch acc {
        case .exactScore:
            return ("scope", "EXACT SCORE HIT · PREDICTED \(pred) · FINAL \(final)", green)
        case .winnerCorrect:
            return pick.predictedScore == nil
                ? ("checkmark.circle.fill", "WINNER CORRECT · FINAL \(final)", lime)
                : ("checkmark.circle.fill", "WINNER CORRECT · PREDICTED \(pred) · FINAL \(final)", lime)
        case .missed:
            return ("xmark.circle", "MISSED · PREDICTED \(pred) · FINAL \(final)", mute)
        }
    }

    /// Expected return % = (AI confidence × decimal odds − 1) × 100.
    /// With real market odds this is the AI's genuine projected edge
    /// over the market price; with the implied fallback it reads as
    /// "fairly priced" — pure analytics framing, no dollar amounts.
    private var expectedReturnPercent: Double {
        let aiProb = pick.probability / 100.0
        return (aiProb * decimalOdds - 1.0) * 100.0
    }

    /// Always-signed formatted string, e.g. "+24.7%" or "-3.2%".
    private var expectedReturnText: String {
        guard hasMarketOdds else { return "—" }
        return String(format: "%+.1f%%", expectedReturnPercent)
    }

    /// "1.83x" — the payout multiplier on the picked outcome.
    /// "$100 → $165" — the number users actually feel. Leads the box.
    private var payoutMultiplierText: String {
        hasMarketOdds
            ? "$100 → $\(Int((100 * decimalOdds).rounded()))"
            : String(format: "%.2fx FAIR ODDS", decimalOdds)
    }

    /// Multiplier demoted to the support line.
    private var payoutSubText: String {
        t(.rd_odds_if_hits).replacingOccurrences(of: "{x}", with: String(format: "%.2f", decimalOdds))
    }

    /// Where the multiplier comes from — a real market or our estimate.
    private var payoutSourceText: String {
        hasMarketOdds
            ? "\(t(.rd_market_odds)) · \((pick.oddsSource ?? "MARKET").uppercased())"
            : t(.rd_est_from_conf)
    }

    /// Lime accent when the AI sees positive edge, muted ink otherwise
    /// so a negative number doesn't shout at the user.
    private var expectedReturnColor: Color {
        guard hasMarketOdds else { return Color(hex: "#B9B7B0") }
        return expectedReturnPercent >= 0 ? sportAccent : Color(hex: "#B9B7B0")
    }

    /// Three stat columns rendered below the win block. The labels
    /// vary by sport so each detail page reads natively (PACE for
    /// basketball, xG for soccer, REACH for combat, etc.).
    /// Three hero-card columns — all REAL, derived from the pick:
    /// implied odds (from probability), confidence tier, and the live/
    /// kickoff status. Replaces the old per-sport fabricated stats
    /// (PACE / xG / REACH / WEATHER…) which had no data source.
    private var pickHeroStats: [PickHeroStat] {
        let oddsStr = String(format: "%.2f", decimalOdds)
        let statusLabel: String
        let statusValue: String
        switch state {
        case .live:
            statusLabel = t(.rd_status)
            statusValue = tipoffText            // "Q3" / "LIVE"
        case .won, .lost:
            statusLabel = "RESULT"
            statusValue = state == .won ? "WON" : "LOST"
        case .awaitingResult:
            statusLabel = t(.rd_status)
            statusValue = "FINAL"
        case .upcoming:
            statusLabel = "TIP-OFF"
            statusValue = tipoffText            // scheduled time
        }
        // Label the odds column honestly: a real market quote shows its
        // source ("DRAFTKINGS" / "POLYMARKET"); the confidence-derived
        // fallback keeps the old IMPLIED ODDS label.
        // The payout hero already shows the multiplier — this column
        // carries the AI's edge vs the market price instead ("+13%"
        // when our probability beats what the odds imply).
        let _ = oddsStr
        return [
            .init(label: t(.rd_ai_edge),    value: expectedReturnText, suffix: nil),
            .init(label: t(.rd_confidence_label), value: "\(Int(pick.probability))", suffix: "%"),
            .init(label: statusLabel,  value: statusValue, suffix: nil),
        ]
    }

    private func pickStatCol(label: String, value: String, twoLine: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.6)
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(value)
                .font(.anton(18))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .lineLimit(twoLine ? 2 : 1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Compact label for the 3rd pick-row column. "LIVE", "TONIGHT",
    /// "TOMORROW", or the day-of-week, depending on the game state.
    private var scheduledOrLiveLabelShort: String {
        if liveScore?.isLive == true { return t(.rd_status) }
        return "TIPOFF"
    }

    /// Short scheduled time string for the 3rd pick-row column.
    /// Live: shows the quarter / period; scheduled: shows the time.
    private var tipoffText: String {
        if let s = liveScore, s.isLive {
            return s.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? "LIVE"
        }
        guard let date = pick.createdAt else { return "TODAY" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// Tabs row — centered (per design `.tabs { justify-content: center }`),
    /// labels are sport-aware via `tabLabel(:)`.
    private var tabsRow: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    Text(tabLabel(t))
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(tab == t ? Color(hex: "#171717") : Color(hex: "#B9B7B0"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(tab == t ? sportAccent : Color(hex: "#1D1D1D"))
                        )
                        .overlay(
                            Capsule().stroke(tab == t ? sportAccent : Color(hex: "#2F2F2F"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    /// AI ANALYSIS — the real, model-generated reasoning behind the
    /// pick (from pick.reasoning), plus the key factor and confidence.
    /// This is the app's actual product, and it's genuine data — unlike
    /// the old "MATCH STATS" bars, which were hardcoded placeholders.
    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Key factor chip (the short tagline, e.g. "Cole 2.34 ERA vs LAD")
            if let factor = pick.keyFactor, !factor.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(sportAccent)
                    Text(factor.uppercased())
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(sportAccent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(sportAccent.opacity(0.10)))
                .overlay(Capsule().stroke(sportAccent.opacity(0.30), lineWidth: 1))
                .padding(.bottom, 14)
            }

            Text(t(.rd_why_ai_likes))
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#6E6F75"))
                .padding(.bottom, 10)

            Text(pick.reasoning.isEmpty
                 ? "The model surfaced this pick from its daily run across the slate. Detailed reasoning will appear here once generated."
                 : pick.reasoning)
                .font(.archivo(14, weight: .regular))
                .foregroundColor(Color(hex: "#E7E4DC"))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            // Confidence row — real probability + tier.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.rd_ai_confidence))
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2.0)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text("\(Int(pick.probability))%  ·  \(confidenceTierLabel)")
                        .font(.anton(18))
                        .foregroundColor(sportAccent)
                }
                Spacer()
            }
            .padding(.top, 4)
            .overlay(alignment: .top) {
                Rectangle().fill(Color(hex: "#2F2F2F")).frame(height: 1)
                    .padding(.top, -10)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    /// MATCHUP — real, web-search-backed supporting facts the AI
    /// pipeline generated for this pick (recent form, head-to-head,
    /// key injury, a decisive stat). Only rendered when the pick
    /// actually carries facts, so older picks — or a degraded pipeline
    /// run — simply omit the card rather than showing an empty shell or
    /// fabricated rows.
    @ViewBuilder
    private var matchupPanel: some View {
        if let facts = pick.matchupFacts, !facts.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(sportAccent)
                    Text(t(.rd_matchup))
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                .padding(.bottom, 12)

                ForEach(Array(facts.enumerated()), id: \.offset) { idx, fact in
                    HStack(alignment: .top, spacing: 12) {
                        Text(fact.label.uppercased())
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(Color(hex: "#9A9B9F"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(fact.value)
                            .font(.archivo(13, weight: .semibold))
                            .foregroundColor(Color(hex: "#F5F3EE"))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .top) {
                        if idx > 0 {
                            Rectangle().fill(Color(hex: "#2F2F2F")).frame(height: 1)
                        }
                    }
                }

                Text(t(.rd_verified_web))
                    .font(.archivoNarrow(8, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(Color(hex: "#4A4B50"))
                    .padding(.top, 12)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    /// PROJECTION — the few confident betting calls the model surfaced
    /// (combat: how it ends + rounds; team sports: projected total +
    /// winning margin). Coin-flips are dropped upstream, so this only
    /// renders when there's at least one call worth showing.
    @ViewBuilder
    private var projectionPanel: some View {
        if let props = pick.bettingProps, !props.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(sportAccent)
                    Text(t(.rd_projection))
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                .padding(.bottom, 12)

                ForEach(Array(props.enumerated()), id: \.offset) { idx, prop in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prop.label.uppercased())
                                .font(.archivoNarrow(11, weight: .bold))
                                .tracking(0.6)
                                .foregroundColor(Color(hex: "#9A9B9F"))
                            if let hint = prop.hint, !hint.isEmpty {
                                Text(hint.uppercased())
                                    .font(.archivoNarrow(8, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(Color(hex: "#5A5B60"))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(prop.value)
                            .font(.archivo(14, weight: .bold))
                            .foregroundColor(sportAccent)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) {
                        if idx > 0 { Rectangle().fill(Color(hex: "#2F2F2F")).frame(height: 1) }
                    }
                }

                Text(t(.rd_ai_projection_disc))
                    .font(.archivoNarrow(8, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(Color(hex: "#4A4B50"))
                    .padding(.top, 12)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    /// TALE OF THE TAPE — ESPN-sourced side-by-side comparison for combat
    /// (physicals + career stats). Replaces the generic MATCHUP list for
    /// fights with real, grounded numbers; the stronger side of each row
    /// is highlighted in the sport accent.
    @ViewBuilder
    private var taleOfTapePanel: some View {
        if let tot = pick.taleOfTape, let a = tot.a, let b = tot.b {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.boxing")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(sportAccent)
                    Text(t(.rd_tale_of_tape))
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                .padding(.bottom, 14)

                // Fighter name + record columns
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(totLast(a.name)).font(.anton(16)).foregroundColor(Color(hex: "#F5F3EE"))
                        if let r = a.record { Text(r).font(.archivoNarrow(11, weight: .bold)).foregroundColor(sportAccent) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("VS").font(.archivoNarrow(10, weight: .bold)).foregroundColor(Color(hex: "#4A4B50"))
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(totLast(b.name)).font(.anton(16)).foregroundColor(Color(hex: "#F5F3EE"))
                        if let r = b.record { Text(r).font(.archivoNarrow(11, weight: .bold)).foregroundColor(sportAccent) }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.bottom, 10)

                totRow("REACH", a.reach, b.reach, betterHigher: true)
                totRow("HEIGHT", a.height, b.height)
                totRow("AGE", a.age.map { "\($0)" }, b.age.map { "\($0)" }, betterHigher: false)
                totRow("STANCE", a.stance, b.stance)

                if a.career != nil || b.career != nil {
                    Text(t(.rd_career))
                        .font(.archivoNarrow(9, weight: .bold)).tracking(2.0)
                        .foregroundColor(Color(hex: "#4A4B50"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14).padding(.bottom, 2)
                    totRow("STRIKES / MIN", a.career?.strLPM, b.career?.strLPM, betterHigher: true)
                    totRow("STR. ACCURACY", totPct(a.career?.strAcc), totPct(b.career?.strAcc), betterHigher: true)
                    totRow("TAKEDOWNS / 15", a.career?.tdAvg, b.career?.tdAvg, betterHigher: true)
                    totRow("TD ACCURACY", totPct(a.career?.tdAcc), totPct(b.career?.tdAcc), betterHigher: true)
                }

                if let wc = tot.weightClass {
                    Text(wc.uppercased())
                        .font(.archivoNarrow(9, weight: .bold)).tracking(1.6)
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }

                Text(t(.rd_verified_espn_stats))
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.6)
                    .foregroundColor(Color(hex: "#4A4B50"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    /// FORM GUIDE — ESPN-grounded soccer team comparison (group position,
    /// points, record, goals, recent form), the soccer analog of the
    /// combat Tale of the Tape. Stronger side highlighted in accent.
    @ViewBuilder
    private var formGuidePanel: some View {
        if let comp = pick.soccerComparison, let h = comp.home, let a = comp.away {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "soccerball")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(sportAccent)
                    Text(t(.rd_form_guide))
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                .padding(.bottom, 14)

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text((h.name ?? "—").uppercased()).font(.anton(15)).foregroundColor(Color(hex: "#F5F3EE"))
                        if let g = h.group { Text(g.uppercased()).font(.archivoNarrow(9, weight: .bold)).tracking(1.0).foregroundColor(sportAccent) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("VS").font(.archivoNarrow(10, weight: .bold)).foregroundColor(Color(hex: "#4A4B50"))
                    VStack(alignment: .trailing, spacing: 2) {
                        Text((a.name ?? "—").uppercased()).font(.anton(15)).foregroundColor(Color(hex: "#F5F3EE"))
                        if let g = a.group { Text(g.uppercased()).font(.archivoNarrow(9, weight: .bold)).tracking(1.0).foregroundColor(sportAccent) }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.bottom, 10)

                totRow("POSITION", h.position, a.position, betterHigher: false)
                totRow("POINTS", h.points, a.points, betterHigher: true)
                totRow("RECORD W-D-L", h.record, a.record)
                totRow("GOALS GF-GA", goalsStr(h), goalsStr(a))
                if h.form != nil || a.form != nil {
                    totRow("RECENT FORM", spacedForm(h.form), spacedForm(a.form))
                }

                Text(t(.rd_verified_espn))
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.6)
                    .foregroundColor(Color(hex: "#4A4B50"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    private func goalsStr(_ t: SoccerTeam) -> String? {
        guard t.goalsFor != nil || t.goalsAgainst != nil else { return nil }
        return "\(t.goalsFor ?? "—")-\(t.goalsAgainst ?? "—")"
    }
    private func spacedForm(_ f: String?) -> String? {
        guard let f, !f.isEmpty else { return nil }
        return f.map { String($0) }.joined(separator: " ")
    }

    private func totLast(_ name: String?) -> String {
        guard let n = name, let l = n.split(separator: " ").last else { return (name ?? "—").uppercased() }
        return String(l).uppercased()
    }
    private func totPct(_ v: String?) -> String? {
        guard let v, let d = Double(v) else { return nil }
        return "\(Int(d.rounded()))%"
    }
    private func totNum(_ v: String?) -> Double? {
        guard let v else { return nil }
        return Double(v.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression))
    }

    @ViewBuilder
    private func totRow(_ label: String, _ av: String?, _ bv: String?, betterHigher: Bool? = nil) -> some View {
        let aHi: Bool = {
            guard let bh = betterHigher, let an = totNum(av), let bn = totNum(bv), an != bn else { return false }
            return bh ? an > bn : an < bn
        }()
        let bHi: Bool = {
            guard let bh = betterHigher, let an = totNum(av), let bn = totNum(bv), an != bn else { return false }
            return bh ? bn > an : bn < an
        }()
        HStack(spacing: 10) {
            Text(av ?? "—")
                .font(.archivo(13, weight: .bold))
                .foregroundColor(aHi ? sportAccent : Color(hex: "#E7E4DC"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(.archivoNarrow(9, weight: .bold)).tracking(1.0)
                .foregroundColor(Color(hex: "#6E6F75"))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(bv ?? "—")
                .font(.archivo(13, weight: .bold))
                .foregroundColor(bHi ? sportAccent : Color(hex: "#E7E4DC"))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(Color(hex: "#1A1C20")).frame(height: 1)
        }
    }

    /// Human label for the pick's confidence tier.
    private var confidenceTierLabel: String {
        switch pick.confidenceTier {
        case .high:   return "HIGH CONVICTION"
        case .medium: return "SOLID EDGE"
        case .low:    return "LEAN"
        }
    }

    private var summaryStats: [StatRow] {
        BarSet.bars(for: pick.sport)
    }

    /// LINEUPS panel — players grouped under a sport-aware title with
    /// number, name + role, and a stat. Mirrors design's `.lineup-card`.
    @ViewBuilder
    private var lineupsPanel: some View {
        let players = lineupPlayers(for: pick)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lineupTitle.uppercased())
                    .font(.anton(18))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                Text(lineupKicker)
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
            .padding(.bottom, 12)

            ForEach(players.indices, id: \.self) { i in
                let p = players[i]
                HStack(spacing: 10) {
                    Text(p.num)
                        .font(.mono(11, weight: .bold))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .frame(width: 24, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                            .font(.archivo(13, weight: .semibold))
                            .foregroundColor(Color(hex: "#F5F3EE"))
                        Text(p.role)
                            .font(.archivo(10))
                            .tracking(0.4)
                            .foregroundColor(Color(hex: "#6E6F75"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(p.stat)
                        .font(.anton(18))
                        .foregroundColor(p.hot ? Color(hex: "#C6FF34")
                                                : Color(hex: "#F5F3EE"))
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) {
                    if i > 0 {
                        Rectangle()
                            .fill(Color(hex: "#2F2F2F"))
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    /// OUR CALL — the actionable read: who we're backing, our confidence,
    /// the confident props, and a VALUE check (our probability vs the
    /// market's implied probability) so the edge is visible — not just a
    /// price list. A prediction, deliberately NOT framed as financial advice.
    private var ourCallPanel: some View {
        let ourPct = Int(pick.probability.rounded())
        let impliedPct: Int? = pick.marketOdds.flatMap { $0 > 1.0 ? Int((100.0 / $0).rounded()) : nil }
        let payout = pick.marketOdds ?? (ourPct > 0 ? 100.0 / Double(ourPct) : 1.0)

        return VStack(alignment: .leading, spacing: 0) {
            // 1. Who we're backing + our confidence
            Text(t(.rd_were_backing))
                .font(.archivoNarrow(10, weight: .bold)).tracking(2.4)
                .foregroundColor(Color(hex: "#6E6F75"))
            HStack(alignment: .center, spacing: 8) {
                Text(pick.pick.uppercased())
                    .font(.anton(22))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(ourPct)%")
                    .font(.anton(22))
                    .foregroundColor(sportAccent)
            }
            .padding(.top, 6)
            Text(confidenceTierLabel)
                .font(.archivoNarrow(9, weight: .bold)).tracking(1.6)
                .foregroundColor(sportAccent)
                .padding(.top, 2).padding(.bottom, 14)

            // 2. VALUE check — our read vs the market's implied probability
            if let imp = impliedPct {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t(.rd_our_read)).font(.archivoNarrow(9, weight: .bold)).tracking(1.4).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(ourPct)%").font(.anton(20)).foregroundColor(Color(hex: "#F5F3EE"))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(t(.rd_market_implied)).font(.archivoNarrow(9, weight: .bold)).tracking(1.4).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(imp)%").font(.anton(20)).foregroundColor(Color(hex: "#B9B7B0"))
                    }.frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Rectangle().fill(V4.line).frame(height: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(V4.line).frame(height: 1) }
                valueVerdict(edge: ourPct - imp).padding(.top, 12)
            } else {
                Text(t(.rd_no_market_line))
                    .font(.archivo(12)).foregroundColor(Color(hex: "#8A8D94"))
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { Rectangle().fill(Color(hex: "#2F2F2F")).frame(height: 1) }
            }

            // 3. More predictions — the per-sport prop markets (exact score,
            // BTTS, player props, totals…). Newer rows carry probability +
            // real odds → show the confidence % and a projected-return chip;
            // legacy rows fall back to the plain label/value line.
            if let props = pick.bettingProps, !props.isEmpty {
                Text("\(t(.rd_more_predictions)) · \(props.count)")
                    .font(.archivoNarrow(9, weight: .bold)).tracking(2.0)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .padding(.top, 16).padding(.bottom, 6)
                // Big, unmissable market cards: WHAT to bet (the call, in
                // display type), HOW confident we are, and WHAT $100 turns
                // into — the three things a bettor needs to act.
                VStack(spacing: 10) {
                    ForEach(Array(props.enumerated()), id: \.offset) { _, prop in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prop.label.uppercased())
                                .font(.archivoNarrow(11, weight: .bold)).tracking(1.4)
                                .foregroundColor(Color(hex: "#9A9B9F"))
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(prop.value.uppercased())
                                    .font(.anton(24))
                                    .foregroundColor(Color(hex: "#F5F3EE"))
                                    .lineLimit(1).minimumScaleFactor(0.55)
                                Spacer(minLength: 8)
                                if let prob = prop.probability {
                                    Text("\(prob)%")
                                        .font(.anton(24))
                                        .foregroundColor(V4.win)
                                }
                            }
                            HStack(spacing: 8) {
                                if let hint = prop.hint {
                                    Text(hint)
                                        .font(.archivo(11.5)).foregroundColor(Color(hex: "#8A8D94"))
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 6)
                                // A return on EVERY market, and the two kinds
                                // look different on purpose. A real book quote
                                // is money a user can go and get, so it gets
                                // the solid pill. An estimate derived from our
                                // own probability is not, so it is outlined and
                                // says EST. Making them look identical would be
                                // the same error the ticket header used to make.
                                if let money = prop.returnOnHundred,
                                   let q = prop.quotedOdds {
                                    if q.isMarket {
                                        Text(money)
                                            .font(.mono(12, weight: .bold))
                                            .foregroundColor(Color(hex: "#171717"))
                                            .padding(.horizontal, 9).padding(.vertical, 5)
                                            .background(Capsule().fill(sportAccent))
                                    } else {
                                        HStack(spacing: 5) {
                                            Text(money)
                                            Text("EST").foregroundColor(Color(hex: "#6E6F75"))
                                        }
                                        .font(.mono(12, weight: .bold))
                                        .foregroundColor(Color(hex: "#B9B7B0"))
                                        .padding(.horizontal, 9).padding(.vertical, 5)
                                        .background(Capsule().strokeBorder(V4.line, lineWidth: 1))
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Neutral card, one accent element — the home's game-card
                        // language. A wall of accent-tinted cards was exactly what
                        // made this page shout compared with the home.
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient(colors: [V4.rowTop, V4.panelBot],
                                                     startPoint: .top, endPoint: .bottom))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(V4.line, lineWidth: 1))
                        )
                    }
                }
            }

            // 3b. Line shopping — where to get the best price. Only when the
            // pipeline captured multiple real book quotes.
            if let books = pick.oddsBooks, books.count >= 2 {
                Text(t(.rd_best_line_books, count: books.count))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(2.0)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .padding(.top, 16).padding(.bottom, 4)
                ForEach(Array(books.enumerated()), id: \.offset) { i, b in
                    HStack {
                        if i == 0 {
                            Text("★").font(.system(size: 11)).foregroundColor(sportAccent)
                        }
                        Text(b.book.uppercased())
                            .font(.archivoNarrow(11, weight: .bold)).tracking(0.6)
                            .foregroundColor(i == 0 ? Color(hex: "#F5F3EE") : Color(hex: "#9A9B9F"))
                        Spacer()
                        Text(String(format: "%.2f", b.odds))
                            .font(.archivo(13, weight: .bold))
                            .foregroundColor(i == 0 ? sportAccent : Color(hex: "#B9B7B0"))
                        if i == 0 {
                            Text(t(.rd_best)).font(.archivoNarrow(8, weight: .bold)).tracking(1.0)
                                .foregroundColor(Color(hex: "#171717"))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(sportAccent))
                        }
                    }
                    .padding(.vertical, 6)
                }
                Text(t(.rd_no_bets))
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.0)
                    .foregroundColor(Color(hex: "#4A4B50")).padding(.top, 2)
            }

            // 4. Market return when executable odds exist; otherwise show
            // the model's fair price without implying a sportsbook payout.
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasMarketOdds ? t(.rd_potential_return) : "MODEL FAIR PRICE")
                        .font(.archivoNarrow(9, weight: .bold)).tracking(1.6).foregroundColor(Color(hex: "#6E6F75"))
                    Text(pick.oddsSource.map { "LINE VIA \($0.uppercased())" } ?? "DERIVED FROM MODEL CONFIDENCE")
                        .font(.archivoNarrow(8, weight: .bold)).tracking(1.0).foregroundColor(Color(hex: "#4A4B50"))
                }
                Spacer()
                Text(hasMarketOdds
                     ? "$100 → $\(Int((payout * 100).rounded()))"
                     : String(format: "%.2fx", payout))
                    .font(.anton(18)).foregroundColor(sportAccent)
            }
            .padding(.top, 16)
            .overlay(alignment: .top) { Rectangle().fill(Color(hex: "#2F2F2F")).frame(height: 1).padding(.top, 8) }

            Text(t(.rd_not_advice))
                .font(.archivoNarrow(8, weight: .bold)).tracking(1.2)
                .foregroundColor(Color(hex: "#4A4B50"))
                .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .sheet(isPresented: $showShareWin) {
            ShareWinSheet(pick: pick)
                .relocalizesOnLanguageChange()
                .presentationDetents([.fraction(0.78), .large])
        }
    }

    private var unifiedTrackBar: some View {
        Button { showTrackSheet = true } label: {
            HStack(spacing: 9) {
                Image(systemName: isTracking ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(isTracking ? "TRACKING · TAP TO EDIT" : t(.rd_track_your_pick))
                    .font(.archivoNarrow(13, weight: .bold)).tracking(1.5)
                Spacer()
                Text("\(Int(pick.probability.rounded()))%")
                    .font(.anton(18))
            }
            .foregroundColor(isTracking ? sportAccent : Color(hex: "#171717"))
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 15)
                .fill(isTracking ? Color(hex: "#202124") : sportAccent)
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(sportAccent.opacity(isTracking ? 0.55 : 0), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func startTracking(stake: Double?) {
        favorites.set(pick, on: true)
        Haptics.success()
        Task { await betTracker.track(pick: pick, stake: stake) }
    }

    private func stopTracking() {
        favorites.set(pick, on: false)
        Analytics.pickUntracked(league: pick.league, sport: pick.sport)
        Haptics.selection()
        Task { await betTracker.untrack(pickId: pick.id) }
    }

    /// Human confidence word — uses the stored value when it's a word,
    /// else derives the tier from probability (legacy rows stored glyphs).
    private var confidenceDisplay: String {
        let raw = pick.confidence.lowercased()
        if ["high", "medium", "low"].contains(raw) { return raw.capitalized }
        switch pick.confidenceTier {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    /// "6:30 AM" — when the pipeline logged this pick (ET).
    private var loggedTimeText: String {
        guard let d = pick.createdAt else { return "PRE-GAME" }
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f.string(from: d)
    }

    /// WHY {TEAM} · BREAKDOWN — meter rows from the pipeline's factor
    /// ratings (real data points; strength is the model's own 0-100 read).
    private func valueVerdict(edge: Int) -> some View {
        let isValue = edge >= 6
        let isNoEdge = edge <= -6
        let label = isValue ? "\(t(.rd_value_label)) · +\(edge)%" : (isNoEdge ? "\(t(.rd_no_edge)) · \(edge)%" : t(.rd_fair_price))
        let sub = isValue ? t(.rd_value_sub)
            : (isNoEdge ? t(.rd_no_edge_sub)
                        : t(.rd_fair_price_body))
        let fg = isValue ? Color(hex: "#171717") : (isNoEdge ? Color(hex: "#F0A8A0") : Color(hex: "#E7E4DC"))
        let bg = isValue ? sportAccent : (isNoEdge ? Color(hex: "#2A1416") : Color(hex: "#232323"))
        return VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.archivoNarrow(12, weight: .bold)).tracking(1.4).foregroundColor(fg)
            Text(sub).font(.archivo(11)).foregroundColor(isValue ? Color(hex: "#171717").opacity(0.7) : Color(hex: "#8A8D94"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(bg))
    }

    /// ODDS panel — legacy price list, no longer shown (replaced by the
    /// OUR CALL tab) but kept for reference.
    @ViewBuilder
    private var oddsPanel: some View {
        let rows = oddsRows(for: pick)
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                let o = rows[i]
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(o.label)
                            .font(.archivo(13, weight: .semibold))
                            .foregroundColor(Color(hex: "#F5F3EE"))
                        if !o.sub.isEmpty {
                            Text(o.sub)
                                .font(.archivo(10))
                                .tracking(0.4)
                                .foregroundColor(Color(hex: "#6E6F75"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !o.line.isEmpty {
                        Text(o.line)
                            .font(.mono(11, weight: .bold))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: "#232323"))
                            )
                    }

                    Text(o.price)
                        .font(.anton(18))
                        .tracking(-0.2)
                        .foregroundColor(o.cold ? Color(hex: "#F5F3EE")
                                                 : Color(hex: "#171717"))
                        .frame(minWidth: 56)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(o.cold ? Color(hex: "#232323")
                                              : Color(hex: "#C6FF34"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(o.cold ? Color(hex: "#2F2F2F") : .clear,
                                                lineWidth: 1)
                                )
                                .shadow(color: o.cold ? .clear
                                                       : Color(hex: "#C6FF34").opacity(0.4),
                                        radius: 6, x: 0, y: 4)
                        )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    if i < rows.count - 1 {
                        Rectangle()
                            .fill(Color(hex: "#2F2F2F"))
                            .frame(height: 1)
                    }
                }
            }
        }
        .background(cardBackground)
    }

    /// H2H panel — 3-column summary at the top, then game list. Mirrors
    /// design's `.h2h-card` with `.h2h-summary` + `.h2h-row` layout.
    @ViewBuilder
    private var h2hPanel: some View {
        let h2h = headToHead(for: pick)
        VStack(spacing: 0) {
            // 3-column summary
            HStack(alignment: .top, spacing: 10) {
                ForEach(h2h.summary.indices, id: \.self) { i in
                    let s = h2h.summary[i]
                    VStack(spacing: 2) {
                        Text("\(s.n)")
                            .font(.anton(32))
                            .foregroundColor(s.lime ? Color(hex: "#C6FF34")
                                                    : Color(hex: "#F5F3EE"))
                        Text(s.label)
                            .font(.archivoNarrow(9, weight: .bold))
                            .tracking(2.2)
                            .foregroundColor(Color(hex: "#6E6F75"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(hex: "#2F2F2F"))
                    .frame(height: 1)
            }

            // Game list
            ForEach(h2h.games.indices, id: \.self) { i in
                let g = h2h.games[i]
                HStack(spacing: 8) {
                    Text(g.date)
                        .font(.mono(10))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .frame(width: 50, alignment: .leading)
                    Text(g.home)
                        .font(.archivo(12, weight: g.winner == "h" ? .bold : .regular))
                        .foregroundColor(g.winner == "h" ? Color(hex: "#C6FF34")
                                                          : Color(hex: "#B9B7B0"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(g.hScore)–\(g.aScore)")
                        .font(.anton(18))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .padding(.horizontal, 6)
                    Text(g.away)
                        .font(.archivo(12, weight: g.winner == "a" ? .bold : .regular))
                        .foregroundColor(g.winner == "a" ? Color(hex: "#C6FF34")
                                                          : Color(hex: "#B9B7B0"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(g.comp)
                        .font(.mono(10))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    if i > 0 {
                        Rectangle()
                            .fill(Color(hex: "#2F2F2F"))
                            .frame(height: 1)
                    }
                }
            }
            .padding(.top, 10)
        }
        .padding(16)
        .background(cardBackground)
    }

    // ─── Lineup helpers ────────────────────────────────────────

    private var lineupTitle: String {
        switch pick.sport {
        case "f1":      return "STARTING GRID"
        case "combat":  return "TALE OF THE TAPE"
        case "tennis":  return "MATCHUP"
        case "cricket": return "PLAYING XI"
        default:        return "\(pick.homeTeam.uppercased()) · STARTERS"
        }
    }

    private var lineupKicker: String {
        switch pick.sport {
        case "f1":      return "GRID"
        case "combat":  return t(.rd_fighters)
        case "tennis":  return t(.rd_players)
        default:        return "STARTERS"
        }
    }

    private func lineupPlayers(for pick: Pick) -> [LineupRow] {
        switch pick.sport {
        case "basketball":
            return [
                .init(num: "1", name: pick.homeTeam, role: "ROSTER · STARTER", stat: "PG", hot: true),
                .init(num: "2", name: "Starter SG", role: "GUARD", stat: "SG"),
                .init(num: "3", name: "Starter SF", role: "WING", stat: "SF"),
                .init(num: "4", name: "Starter PF", role: "FORWARD", stat: "PF"),
                .init(num: "5", name: "Starter C", role: "CENTER", stat: "C"),
            ]
        case "soccer":
            return [
                .init(num: "1", name: "Goalkeeper", role: "GK", stat: "0.7", hot: false),
                .init(num: "9", name: "Striker", role: "ST · CAPTAIN", stat: "1G", hot: true),
                .init(num: "10", name: "Playmaker", role: "CAM", stat: "0.8 xG"),
                .init(num: "7", name: "Right Wing", role: "RW", stat: "0.4 xG"),
                .init(num: "11", name: "Left Wing", role: "LW", stat: "0.3 xG"),
                .init(num: "5", name: "Defensive Mid", role: "CDM", stat: "92%"),
            ]
        case "football":
            return [
                .init(num: "QB", name: "Starting QB", role: "PASSER", stat: "—", hot: true),
                .init(num: "RB", name: "Starting RB", role: "RUSHER", stat: "—"),
                .init(num: "WR", name: "Top WR", role: "RECEIVER", stat: "—"),
                .init(num: "TE", name: "Tight End", role: "TE", stat: "—"),
                .init(num: "DT", name: "Defensive Tackle", role: "DEF", stat: "—"),
            ]
        case "combat":
            return [
                .init(num: "A", name: pick.homeTeam, role: "RECORD · LEAD", stat: "205 LB", hot: true),
                .init(num: "B", name: pick.awayTeam, role: "RECORD · CHALLENGER", stat: "205 LB"),
                .init(num: "★", name: "Striking Edge", role: "POWER · DISTANCE", stat: "A+"),
                .init(num: "♦", name: "Grappling Edge", role: "TAKEDOWN · GROUND", stat: "A"),
                .init(num: "⏱", name: "Avg Fight Time", role: "USUALLY ENDS EARLY", stat: "R2"),
            ]
        case "f1":
            return [
                .init(num: "P1", name: pick.homeTeam, role: "POLE · FRONT ROW", stat: "1:13.4", hot: true),
                .init(num: "P2", name: "P2 driver", role: "FRONT ROW", stat: "+0.142"),
                .init(num: "P3", name: "P3 driver", role: "ROW 2", stat: "+0.318"),
                .init(num: "P4", name: "P4 driver", role: "ROW 2", stat: "+0.421"),
                .init(num: "P5", name: "P5 driver", role: "ROW 3", stat: "+0.563"),
            ]
        case "tennis":
            return [
                .init(num: "1", name: pick.homeTeam, role: "SEED · FORM", stat: "FH", hot: true),
                .init(num: "2", name: pick.awayTeam, role: "SEED · FORM", stat: "FH"),
                .init(num: "★", name: "Surface", role: "GRASS · OUTDOOR", stat: "—"),
                .init(num: "✓", name: "1st Serve %", role: "SEASON AVG", stat: "68%"),
                .init(num: "⚡", name: "Aces / Match", role: "SEASON AVG", stat: "9.2"),
            ]
        case "cricket":
            return [
                .init(num: "1", name: "Opening Batter", role: "BATTING", stat: "—", hot: true),
                .init(num: "2", name: "Opening Batter", role: "BATTING", stat: "—"),
                .init(num: "3", name: "No. 3", role: "ANCHOR", stat: "—"),
                .init(num: "4", name: "Captain", role: "BATTING", stat: "—"),
                .init(num: "5", name: "All-rounder", role: "BAT/BOWL", stat: "—"),
                .init(num: "6", name: "Strike Bowler", role: "BOWLING", stat: "—"),
            ]
        case "hockey":
            return [
                .init(num: "C", name: "First Line C", role: "CENTER", stat: "—", hot: true),
                .init(num: "LW", name: "First Line LW", role: "FORWARD", stat: "—"),
                .init(num: "RW", name: "First Line RW", role: "FORWARD", stat: "—"),
                .init(num: "D", name: "Top Pair", role: "DEFENSE", stat: "—"),
                .init(num: "G", name: "Starting Goalie", role: "GOALIE", stat: ".932"),
            ]
        default:
            return [
                .init(num: "1", name: pick.homeTeam, role: "PROJECTED LINEUP", stat: "—"),
                .init(num: "2", name: pick.awayTeam, role: "PROJECTED LINEUP", stat: "—"),
            ]
        }
    }

    // ─── Odds helpers ──────────────────────────────────────────

    private func oddsRows(for pick: Pick) -> [OddsRow] {
        let primaryOdds = String(format: "%.2f", decimalOdds)
        let altOdds = String(format: "%.2f", max(2.10, decimalOdds + 0.50))
        switch pick.sport {
        case "basketball", "football", "hockey":
            return [
                .init(label: "MONEYLINE", sub: pick.homeTeam.uppercased(), line: "", price: primaryOdds, cold: false),
                .init(label: "MONEYLINE", sub: pick.awayTeam.uppercased(), line: "", price: altOdds, cold: true),
                .init(label: "SPREAD", sub: "\(pick.homeTeam.uppercased()) -2.5", line: "-2.5", price: "1.85", cold: false),
                .init(label: "TOTAL", sub: "OVER", line: "O 218.5", price: "1.90", cold: false),
                .init(label: "TOTAL", sub: "UNDER", line: "U 218.5", price: "1.92", cold: true),
            ]
        case "soccer":
            return [
                .init(label: "MATCH RESULT", sub: "\(pick.homeTeam.uppercased()) WIN", line: "", price: primaryOdds, cold: false),
                .init(label: "DRAW", sub: "", line: "", price: "4.20", cold: true),
                .init(label: "\(pick.awayTeam.uppercased()) WIN", sub: "", line: "", price: altOdds, cold: true),
                .init(label: "OVER 2.5 GOALS", sub: "", line: "2.5", price: "2.10", cold: false),
                .init(label: "BTTS · YES", sub: "", line: "", price: "1.35", cold: false),
            ]
        case "baseball":
            return [
                .init(label: "MONEYLINE", sub: pick.homeTeam.uppercased(), line: "", price: primaryOdds, cold: false),
                .init(label: "MONEYLINE", sub: pick.awayTeam.uppercased(), line: "", price: altOdds, cold: true),
                .init(label: "RUN LINE", sub: "\(pick.homeTeam.uppercased()) -1.5", line: "-1.5", price: "2.50", cold: false),
                .init(label: "TOTAL RUNS", sub: "OVER", line: "O 7.5", price: "1.90", cold: false),
                .init(label: "TOTAL RUNS", sub: "UNDER", line: "U 7.5", price: "1.95", cold: true),
            ]
        case "combat":
            return [
                .init(label: "FIGHT WINNER", sub: pick.homeTeam.uppercased(), line: "", price: primaryOdds, cold: false),
                .init(label: "FIGHT WINNER", sub: pick.awayTeam.uppercased(), line: "", price: altOdds, cold: true),
                .init(label: "METHOD", sub: "KO/TKO", line: "", price: "3.10", cold: false),
                .init(label: "METHOD", sub: "DECISION", line: "", price: "4.50", cold: true),
                .init(label: "DISTANCE", sub: "UNDER 2.5 RDS", line: "U 2.5", price: "2.25", cold: false),
            ]
        case "f1":
            return [
                .init(label: "RACE WINNER", sub: pick.homeTeam.uppercased(), line: "", price: primaryOdds, cold: false),
                .init(label: "POLE POSITION", sub: pick.homeTeam.uppercased(), line: "", price: "2.20", cold: false),
                .init(label: "FASTEST LAP", sub: pick.homeTeam.uppercased(), line: "", price: "3.20", cold: true),
                .init(label: "PODIUM FINISH", sub: pick.homeTeam.uppercased(), line: "", price: "1.45", cold: false),
                .init(label: "WINNING MARGIN", sub: "OVER 5.0s", line: "5.0", price: "2.10", cold: true),
            ]
        case "tennis":
            return [
                .init(label: "MATCH WINNER", sub: pick.homeTeam.uppercased(), line: "", price: primaryOdds, cold: false),
                .init(label: "MATCH WINNER", sub: pick.awayTeam.uppercased(), line: "", price: altOdds, cold: true),
                .init(label: "GAMES SPREAD", sub: "\(pick.homeTeam.uppercased()) -3.5", line: "-3.5", price: "1.85", cold: false),
                .init(label: "TOTAL GAMES", sub: "OVER", line: "O 21.5", price: "1.90", cold: false),
                .init(label: "FIRST SET", sub: pick.homeTeam.uppercased(), line: "", price: "1.60", cold: false),
            ]
        case "cricket":
            return [
                .init(label: "MATCH WINNER", sub: pick.homeTeam.uppercased(), line: "", price: primaryOdds, cold: false),
                .init(label: "MATCH WINNER", sub: pick.awayTeam.uppercased(), line: "", price: altOdds, cold: true),
                .init(label: "TOTAL RUNS", sub: "OVER", line: "O 320.5", price: "1.85", cold: false),
                .init(label: "TOP BATTER", sub: pick.homeTeam.uppercased(), line: "", price: "3.00", cold: false),
            ]
        default:
            return [
                .init(label: "AI PICK", sub: pick.displayPick.uppercased(), line: "", price: primaryOdds, cold: false),
            ]
        }
    }

    // ─── H2H helpers ───────────────────────────────────────────

    private func headToHead(for pick: Pick) -> H2HData {
        switch pick.sport {
        case "combat":
            return H2HData(
                summary: [
                    .init(n: 1, label: "\(pick.homeTeam.uppercased()) WINS", lime: true),
                    .init(n: 0, label: "DRAWS", lime: false),
                    .init(n: 0, label: "\(pick.awayTeam.uppercased()) WINS", lime: false),
                ],
                games: [
                    .init(date: "—", home: pick.homeTeam, away: pick.awayTeam, hScore: "W", aScore: "L", winner: "h", comp: "MAIN"),
                    .init(date: "—", home: pick.homeTeam, away: "Prev opp", hScore: "KO", aScore: "—", winner: "h", comp: "PRELIM"),
                    .init(date: "—", home: pick.awayTeam, away: "Prev opp", hScore: "KO", aScore: "—", winner: "h", comp: "PRELIM"),
                ]
            )
        case "f1":
            return H2HData(
                summary: [
                    .init(n: 4, label: "WINS · 2025", lime: true),
                    .init(n: 6, label: "PODIUMS", lime: false),
                    .init(n: 12, label: "POLES", lime: false),
                ],
                games: [
                    .init(date: "MAY 26", home: "Monaco", away: "GP", hScore: "P1", aScore: "—", winner: "h", comp: "RACE"),
                    .init(date: "MAY 18", home: "Imola", away: "GP", hScore: "P1", aScore: "—", winner: "h", comp: "RACE"),
                    .init(date: "MAY 04", home: "Miami", away: "GP", hScore: "P2", aScore: "—", winner: "", comp: "RACE"),
                ]
            )
        default:
            return H2HData(
                summary: [
                    .init(n: 3, label: "\(teamShortName(pick.homeTeam, sport: pick.sport).uppercased()) WINS", lime: true),
                    .init(n: 1, label: "DRAWS", lime: false),
                    .init(n: 1, label: "\(teamShortName(pick.awayTeam, sport: pick.sport).uppercased()) WINS", lime: false),
                ],
                games: [
                    .init(date: "OCT 27", home: teamShortName(pick.homeTeam, sport: pick.sport), away: teamShortName(pick.awayTeam, sport: pick.sport), hScore: "3", aScore: "1", winner: "h", comp: "REG"),
                    .init(date: "MAY 14", home: teamShortName(pick.awayTeam, sport: pick.sport), away: teamShortName(pick.homeTeam, sport: pick.sport), hScore: "2", aScore: "2", winner: "", comp: "REG"),
                    .init(date: "FEB 04", home: teamShortName(pick.homeTeam, sport: pick.sport), away: teamShortName(pick.awayTeam, sport: pick.sport), hScore: "3", aScore: "1", winner: "h", comp: "REG"),
                    .init(date: "DEC 23", home: teamShortName(pick.awayTeam, sport: pick.sport), away: teamShortName(pick.homeTeam, sport: pick.sport), hScore: "1", aScore: "1", winner: "", comp: "REG"),
                    .init(date: "APR 09", home: teamShortName(pick.awayTeam, sport: pick.sport), away: teamShortName(pick.homeTeam, sport: pick.sport), hScore: "2", aScore: "2", winner: "", comp: "REG"),
                ]
            )
        }
    }

}

// MARK: - MatchDetailView supporting data

/// One column in the pick-hero's bottom 3-stat row.
struct PickHeroStat {
    let label: String
    let value: String
    let suffix: String?
}

/// One row in the LINEUPS panel.
struct LineupRow {
    let num: String
    let name: String
    let role: String
    let stat: String
    var hot: Bool = false
}

/// One row in the ODDS panel.
struct OddsRow {
    let label: String
    let sub: String
    let line: String
    let price: String
    let cold: Bool
}

/// H2H panel data — 3-column summary at the top + game list below.
struct H2HData {
    let summary: [Summary]
    let games: [Game]

    struct Summary {
        let n: Int
        let label: String
        let lime: Bool
    }

    struct Game {
        let date: String
        let home: String
        let away: String
        let hScore: String
        let aScore: String
        let winner: String   // "h" / "a" / "" (draw)
        let comp: String
    }
}

struct StatBarRow: View {
    let label: String
    let homeText: String
    let awayText: String
    let homePct: Double
    /// Home-side bar fill. Defaults to lime so any other caller is
    /// unaffected; the match-detail Summary passes the sport accent.
    var accent: Color = Color(hex: "#C6FF34")

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(homeText)
                    .font(.mono(12, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                Text(label)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Spacer()
                Text(awayText)
                    .font(.mono(12, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
            }
            GeometryReader { geo in
                let w = geo.size.width
                let homeWidth = w * homePct
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#232323"))
                        .overlay(Capsule().stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
                    HStack(spacing: 0) {
                        Capsule().fill(accent)
                            .frame(width: homeWidth)
                        Capsule().fill(Color(hex: "#F5F3EE").opacity(0.85))
                    }
                    .clipShape(Capsule())
                }
            }
            .frame(height: 5)
        }
    }
}

private struct EmptyPanel: View {
    let title: String
    let caption: String
    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text(caption)
                .font(.archivo(12, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Sport Hub
// ════════════════════════════════════════════════════════════════

struct SportHubView: View {
    let sport: String
    @ObservedObject var vm: PicksViewModel
    var isPro: Bool = true
    let onClose: () -> Void
    let onTapPick: (Pick) -> Void
    var onUnlock: () -> Void = {}

    /// Active league filter (a real pick.league key like "EPL"/"WC").
    /// Nil = show every league for the sport.
    @State private var selectedLeague: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#07080a").ignoresSafeArea()
            // Per-sport glow tint — radial gradient anchored top-right
            // matches design `.hero::before` (per-sport `--sport-glow`).
            RadialGradient(
                colors: [glowColor.opacity(0.25), .clear],
                center: UnitPoint(x: 1.05, y: -0.1),
                startRadius: 0,
                endRadius: 380
            )
            .frame(height: 320)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    TopNavBar(crumb: t(.rd_crumb_home),
                              crumbAccent: leagueLabel,
                              live: hasLiveToday,
                              onBack: onClose)

                    // ── HERO ─────────────────────────────────────────
                    sportHeroBlock
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 18)

                    // ── PICK HERO (top AI pick of the day) ───────────
                    // Same featured-frame component as the home screen
                    // (HeroCard, embedded mode) so the design — dark
                    // surface, animated acid border, two-line headline,
                    // lime confidence ring, crest pair — is identical
                    // across Home and every sport page.
                    if let top = topPick {
                        Button { onTapPick(top) } label: {
                            HeroCard(pick: top,
                                     isLive: liveScore(for: top)?.isLive == true,
                                     embedded: true)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }

                    // ── LEAGUE RAIL (horizontal pill row of leagues) ─
                    leagueRail
                        .padding(.bottom, 16)

                    // ── TODAY ────────────────────────────────────────
                    HubSectionHead(
                        title: (sport == "f1") ? "RACE FIELD"
                             : (sport == "golf") ? "THE FIELD"
                             : (hasLiveToday ? "TODAY · LIVE & UPCOMING"
                                             : (isPro ? "TODAY" : "FREE PICK")),
                        meta: ((sport == "f1" || sport == "golf") && (featuredRace?.fieldOdds?.isEmpty == false))
                             ? "\(featuredRace!.fieldOdds!.count) \(sport == "golf" ? "CONTENDERS" : "DRIVERS")"
                             : "\(filteredPicksForSport.count) GAME\(filteredPicksForSport.count == 1 ? "" : "S")",
                        live: hasLiveToday
                    )
                    .padding(.bottom, 10)
                    Group {
                        if (sport == "f1" || sport == "golf"), let race = featuredRace,
                           let drivers = race.fieldOdds, !drivers.isEmpty {
                            raceDriverCards(race: race, drivers: drivers)
                        } else {
                            todayList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)

                    // ── YESTERDAY (only when there's history) ────────
                    if !yesterdayForSport.isEmpty {
                        HubSectionHead(title: t(.rd_yesterday),
                                       meta: yesterdayMeta)
                            .padding(.bottom, 10)
                        yesterdaySum
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                        yesterdayList
                            .padding(.horizontal, 16)
                            .padding(.bottom, 22)
                    }

                    // ── STANDINGS placeholder ────────────────────────
                    HubSectionHead(title: t(.rd_standings), meta: t(.rd_top5))
                        .padding(.bottom, 10)
                    standingsCard
                        .padding(.horizontal, 16)

                    Spacer().frame(height: 140)
                }
            }
            // Pull-to-refresh removed — it re-ran loadAll and briefly emptied the slate.
        }
        .preferredColorScheme(.dark)
    }

    // ════════════════════════════════════════════════════════════
    // MARK: HERO (split-color title + sub line)
    // ════════════════════════════════════════════════════════════

    /// Hero block — `.hero` in the design. Anton 72pt title with the
    /// first word in `--ink` and any trailing words in lime (`--accent`).
    /// "NBA" stays fully white; "FORMULA 1" → FORMULA + lime "1".
    private var sportHeroBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            heroTitle
            HStack(spacing: 10) {
                if hasLiveToday {
                    Circle()
                        .fill(Color(hex: "#FF5A36"))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color(hex: "#FF5A36"), radius: 4)
                }
                Text(heroTagline)
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Circle()
                    .fill(Color(hex: "#6E6F75"))
                    .frame(width: 5, height: 5)
                Text(heroSub)
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var heroTitle: some View {
        let parts = sportTitle.split(separator: " ", maxSplits: 1).map(String.init)
        let head = parts.first ?? sportTitle
        let tail = parts.count > 1 ? parts[1] : nil
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(head)
                .font(.anton(72))
                .lineSpacing(-12)
                .tracking(-0.6)
                .foregroundColor(Color(hex: "#F5F3EE"))
            if let tail {
                Text(tail)
                    .font(.anton(72))
                    .lineSpacing(-12)
                    .tracking(-0.6)
                    .foregroundColor(Color(hex: "#C6FF34"))
            }
        }
    }

    private var heroTagline: String {
        // Derived from the leagues that actually have picks — the old
        // hardcoded per-sport lines claimed things like "WEEK 15 ·
        // SUNDAY SLATE" in June. Reads e.g. "SUMMER CUP · TODAY",
        // "CRICKET · TODAY", "UFC · UPCOMING".
        let upcoming = vm.upcomingEventPicks.filter { $0.sport == sport }
        let leagues = Set((picksForSport + upcoming).map { displayLeague($0.league) })
        if leagues.isEmpty { return "NO GAMES SCHEDULED" }
        let label = leagues.sorted().joined(separator: " · ")
        return picksForSport.isEmpty ? "\(label) · UPCOMING" : "\(label) · TODAY"
    }

    private var heroSub: String {
        let n = picksForSport.count
        if n == 0 { return "NO GAMES TODAY" }
        let avg = Int(avgConf.rounded())
        return "\(n) GAME\(n == 1 ? "" : "S") · AI \(avg)% AVG"
    }

    // ════════════════════════════════════════════════════════════
    // MARK: LEAGUE RAIL
    // ════════════════════════════════════════════════════════════

    /// Horizontal scroller of league pills with color swatch + name +
    /// JetBrains Mono count. Mirrors design `.league-rail`. We only
    /// have one league per sport in the data model right now, so the
    /// rail renders a single (active) chip. Wired so adding more
    /// leagues later just means extending `leaguesForSport`.
    private var leagueRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(leaguesForSport, id: \.id) { l in
                    leagueChip(l)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private struct LeagueChip {
        let id: String
        let name: String
        let count: Int
        let swatch: Color
        var active: Bool = false
        var league: String = ""
    }

    /// League chips derived from the REAL picks for this sport —
    /// label, count, and presence all come from data (today's slate +
    /// future-dated event picks), so the rail never shows leagues we
    /// don't cover or made-up counts. Tapping a chip filters the page;
    /// tapping the active chip clears the filter.
    private var leaguesForSport: [LeagueChip] {
        let active = picksForSport
            + vm.upcomingEventPicks.filter { $0.sport == sport }
        if !active.isEmpty {
            let grouped = Dictionary(grouping: active, by: { $0.league })
            return grouped
                .map { league, ps in
                    LeagueChip(id: chipLogoId(for: league),
                               name: displayLeague(league),
                               count: ps.count,
                               swatch: glowColor,
                               active: selectedLeague == league,
                               league: league)
                }
                .sorted { $0.count != $1.count ? $0.count > $1.count
                                               : $0.name < $1.name }
        }
        // Off-day / off-season: no live data for this sport. Keep the
        // rail present by showing the leagues we've covered recently
        // (30-day history), or the sport's primary league as a last
        // resort — count 0 is hidden by chipLabel.
        let recent = Set(vm.historyPicks
            .filter { $0.sport == sport }
            .map { $0.league })
        let leagues = recent.isEmpty ? [primaryLeague] : Array(recent)
        return leagues
            .map { league in
                LeagueChip(id: chipLogoId(for: league),
                           name: displayLeague(league),
                           count: 0,
                           swatch: glowColor,
                           active: false,
                           league: league)
            }
            .sorted { $0.name < $1.name }
    }

    /// The flagship league key per sport — rail fallback when there is
    /// no pick history at all (fresh install, off-season).
    private var primaryLeague: String {
        switch sport {
        case "basketball": return "NBA"
        case "football":   return "NFL"
        case "soccer":     return "EPL"
        case "baseball":   return "MLB"
        case "hockey":     return "NHL"
        case "combat":     return "UFC"
        case "f1":         return "F1"
        case "cricket":    return "IPL"
        case "tennis":     return "ATP"
        default:           return sport.uppercased()
        }
    }

    /// pick.league key → LeagueLogo id (ESPN crest where one exists).
    private func chipLogoId(for league: String) -> String {
        switch league.uppercased() {
        case "NBA": return "nba"
        case "NFL": return "nfl"
        case "MLB": return "mlb"
        case "NHL": return "nhl"
        case "EPL": return "epl"
        case "UFC": return "ufc"
        case "IPL": return "ipl"
        case "F1":  return "f1"
        case "LALIGA": return "laliga"
        case "SERIEA": return "seriea"
        case "BUNDESLIGA": return "bundesliga"
        case "LIGUE1": return "ligue1"
        case "UCL": return "ucl"
        case "MLS": return "mls"
        case "LIGAMX": return "ligamx"
        case "WNBA": return "wnba"
        case "EUROLEAGUE": return "euroleague"
        case "NCAAB": return "ncaab"
        case "KBO": return "kbo"
        case "NPB": return "npb"
        case "NASCAR": return "nascar"
        default:    return league.lowercased()   // WC etc. → symbol tile
        }
    }

    /// Today's picks narrowed to the selected league (nil = all).
    private var filteredPicksForSport: [Pick] {
        guard let l = selectedLeague else { return picksForSport }
        return picksForSport.filter { $0.league == l }
    }

    private func leagueChip(_ l: LeagueChip) -> some View {
        Button {
            Haptics.tap()
            selectedLeague = (selectedLeague == l.league) ? nil : l.league
        } label: {
            chipLabel(l)
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(_ l: LeagueChip) -> some View {
        HStack(spacing: 8) {
            // Real league crest (Champions League, Bundesliga, La
            // Liga, NBA, NFL …) hot-linked from ESPN's league-logo
            // CDN. Leagues ESPN doesn't serve (NCAAF, CFL, tennis
            // tours, F1) fall back to the sport SF Symbol on the
            // league's brand swatch — so every league still has a
            // distinct visual identity, never a bare colored square.
            LeagueLogo(leagueId: l.id,
                       fallbackSymbol: leagueSymbol(l.id),
                       swatch: l.swatch,
                       size: 18)
            Text(l.name)
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(1.6)
            if l.count > 0 {
                Text("\(l.count)")
                    .font(.mono(10, weight: .bold))
                    .foregroundColor(l.active ? Color(hex: "#171717").opacity(0.5)
                                              : Color(hex: "#6E6F75"))
            }
        }
        .foregroundColor(l.active ? Color(hex: "#171717") : Color(hex: "#B9B7B0"))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(l.active ? Color(hex: "#F5F3EE")
                                             : Color(hex: "#1D1D1D")))
        .overlay(Capsule().stroke(l.active ? Color(hex: "#F5F3EE")
                                            : Color(hex: "#2F2F2F"),
                                  lineWidth: 1))
    }

    /// SF Symbol for a league id. Falls back to the parent sport's
    /// symbol so sister leagues (G-League, NCAAF, KHL…) still read
    /// correctly, and a generic glyph for anything unmapped.
    private func leagueSymbol(_ leagueId: String) -> String {
        switch leagueId {
        case "nba", "gleague", "ncaab", "euroleague":
            return "basketball.fill"
        case "nfl", "ncaaf", "cfl", "xfl":
            return "football.fill"
        case "epl", "laliga", "bundesliga", "seriea", "ucl", "mls":
            return "soccerball"
        case "mlb", "npb", "kbo":
            return "baseball.fill"
        case "nhl", "khl", "ahl", "ncaa":
            return "hockey.puck.fill"
        case "ipl", "bbl", "t20i", "test":
            return "figure.cricket"
        case "atp", "wta", "slam":
            return "tennis.racket"
        case "f1":
            return "car.fill"
        case "combat", "ufc":
            return "figure.boxing"
        default:
            // Fall back to the active sport's symbol.
            switch sport {
            case "basketball": return "basketball.fill"
            case "football":   return "football.fill"
            case "soccer":     return "soccerball"
            case "baseball":   return "baseball.fill"
            case "hockey":     return "hockey.puck.fill"
            case "cricket":    return "figure.cricket"
            case "tennis":     return "tennis.racket"
            case "f1":         return "car.fill"
            case "combat":     return "figure.boxing"
            default:           return "sportscourt.fill"
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: TODAY list
    // ════════════════════════════════════════════════════════════

    @ViewBuilder
    /// 2026 F1 grid: driver → constructor accent color + team name.
    /// Used to brand each driver card. Falls back to a neutral grey.
    private func f1Team(_ name: String) -> (color: Color, team: String) {
        let n = name.lowercased()
        func hit(_ keys: [String]) -> Bool { keys.contains { n.contains($0) } }
        if hit(["antonelli", "russell"])              { return (Color(hex: "#27F4D2"), "MERCEDES") }
        if hit(["verstappen", "tsunoda"])             { return (Color(hex: "#3671C6"), "RED BULL") }
        if hit(["norris", "piastri"])                 { return (Color(hex: "#FF8000"), "McLAREN") }
        if hit(["leclerc", "hamilton"])               { return (Color(hex: "#E8002D"), "FERRARI") }
        if hit(["alonso", "stroll"])                  { return (Color(hex: "#229971"), "ASTON MARTIN") }
        if hit(["sainz", "albon"])                    { return (Color(hex: "#64C4FF"), "WILLIAMS") }
        if hit(["gasly", "doohan", "colapinto"])      { return (Color(hex: "#0093CC"), "ALPINE") }
        if hit(["lawson", "hadjar"])                  { return (Color(hex: "#6692FF"), "RB") }
        if hit(["ocon", "bearman"])                   { return (Color(hex: "#B6BABD"), "HAAS") }
        if hit(["hulkenberg", "bortoleto"])           { return (Color(hex: "#52E252"), "KICK SAUBER") }
        return (Color(hex: "#9AA0AA"), "F1")
    }

    /// NASCAR drivers identify by manufacturer — colour + badge by make
    /// (Chevrolet gold, Toyota red, Ford blue), generic fallback.
    private func nascarTeam(_ name: String) -> (color: Color, team: String) {
        let n = name.lowercased()
        func hit(_ keys: [String]) -> Bool { keys.contains { n.contains($0) } }
        // Chevrolet — Hendrick, Trackhouse, RCR, Spire, Kaulig
        if hit(["larson", "byron", "elliott", "bowman", "chastain",
                "suarez", "hocevar", "dillon", "allmendinger"]) {
            return (Color(hex: "#E5B83C"), "CHEVROLET")
        }
        // Toyota — Joe Gibbs Racing, 23XI, Legacy MC
        if hit(["hamlin", "bell", "gibbs", "reddick", "wallace",
                "briscoe", "nemechek"]) {
            return (Color(hex: "#EB1B2E"), "TOYOTA")
        }
        // Ford — Penske, RFK, Wood Brothers, Front Row
        if hit(["blaney", "logano", "cindric", "keselowski", "buescher",
                "preece", "berry", "gilliland", "mcdowell", "stenhouse",
                "gragson", "custer", "jones"]) {
            return (Color(hex: "#2D6FCF"), "FORD")
        }
        return (Color(hex: "#9AA0AA"), "NASCAR")
    }

    /// Pick the right constructor/manufacturer colour map for the series.
    private func driverTeam(_ name: String, league: String) -> (color: Color, team: String) {
        league.uppercased() == "NASCAR" ? nascarTeam(name) : f1Team(name)
    }

    /// One BIG card per driver — headshot, position, team color + name,
    /// win% (constructor-colored) and podium%. AI pick gets a glowing
    /// team-colored border. Tapping opens the full race detail.
    private func raceDriverCards(race: Pick, drivers: [DriverOdds]) -> some View {
        let sorted = drivers.sorted { $0.win > $1.win }
        let visible = isPro ? sorted : Array(sorted.prefix(3))
        let maxWin = max(1, sorted.map { $0.win }.max() ?? 1)
        return LazyVStack(spacing: 10) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { idx, d in
                let isPicked = race.pick.localizedCaseInsensitiveContains(d.name)
                    || d.name.localizedCaseInsensitiveContains(race.pick)
                let team = driverTeam(d.name, league: race.league)
                Button { onTapPick(race) } label: {
                    HStack(spacing: 14) {
                        Text("\(idx + 1)")
                            .font(.anton(26))
                            .foregroundColor(isPicked ? team.color : Color(hex: "#54585F"))
                            .frame(width: 30)
                        // Headshot ringed in the constructor color.
                        AthleteHeadshot(sport: "f1", name: d.name, size: .big)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(team.color, lineWidth: 2.5))
                            .shadow(color: team.color.opacity(0.4), radius: 6, x: 0, y: 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.name.uppercased())
                                .font(.anton(19))
                                .foregroundColor(Color(hex: "#F5F3EE"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(team.color)
                                    .frame(width: 14, height: 3)
                                Text(team.team)
                                    .font(.archivoNarrow(9, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundColor(team.color)
                                    .lineLimit(1)
                            }
                            if isPicked {
                                Text(t(.rd_ai_pick_race_winner))
                                    .font(.archivoNarrow(8, weight: .bold))
                                    .tracking(1.4)
                                    .foregroundColor(Color(hex: "#F5F3EE").opacity(0.7))
                            } else {
                                Text("\(t(.rd_podium_word)) \(Int(d.podium.rounded()))%")
                                    .font(.mono(9, weight: .medium))
                                    .foregroundColor(Color(hex: "#8A8F98"))
                            }
                        }
                        Spacer(minLength: 6)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(d.win.rounded()))%")
                                .font(.anton(30))
                                .foregroundColor(team.color)
                                .monospacedDigit()
                            Text(t(.rd_win_word))
                                .font(.archivoNarrow(8, weight: .bold)).tracking(1.8)
                                .foregroundColor(Color(hex: "#6E6F75"))
                            // mini win-share bar in team color
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "#1A1C20"))
                                .frame(width: 56, height: 4)
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(team.color)
                                        .frame(width: 56 * CGFloat(d.win / maxWin), height: 4)
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [team.color.opacity(isPicked ? 0.16 : 0.09),
                                             Color(hex: "#1B1B1B")],
                                    startPoint: .leading, endPoint: .trailing))
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(team.color.opacity(isPicked ? 0.75 : 0.30),
                                        lineWidth: isPicked ? 1.5 : 1)
                        }
                    )
                    // Constructor-colored left accent stripe.
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(team.color)
                            .frame(width: 4)
                            .padding(.vertical, 14)
                            .padding(.leading, 2)
                    }
                    .shadow(color: isPicked ? team.color.opacity(0.25) : .clear,
                            radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
            if !isPro, sorted.count > 3 {
                ProUnlockCard(lockedCount: sorted.count - 3, onUnlock: onUnlock)
            }
        }
    }

    private var todayList: some View {
        LazyVStack(spacing: 8) {
            let visible = isPro ? filteredPicksForSport
                                : Array(topPick.map { [$0] } ?? [])
            ForEach(visible) { p in
                Button { onTapPick(p) } label: {
                    CompactPickCard(pick: p, liveScore: liveScore(for: p))
                }
                .buttonStyle(.plain)
            }
            if !isPro {
                let lockedRest = picksForSport.filter { $0.id != topPick?.id }
                if !lockedRest.isEmpty {
                    ProUnlockCard(lockedCount: lockedRest.count, onUnlock: onUnlock)
                    ForEach(lockedRest.prefix(3)) { p in
                        LockedPickCard(pick: p, onUnlock: onUnlock)
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: YESTERDAY (sum + games)
    // ════════════════════════════════════════════════════════════

    private var yesterdayForSport: [Pick] {
        vm.yesterdayPicks.filter { $0.sport == sport }
    }

    private var yesterdayMeta: String {
        let total = yesterdayForSport.filter { !$0.isPending }.count
        if total == 0 { return "AWAITING RESULTS" }
        let wins = yesterdayForSport.filter { $0.isWin }.count
        let losses = yesterdayForSport.filter { $0.isLoss }.count
        let rate = total > 0 ? Int(Double(wins) / Double(total) * 100) : 0
        return "AI \(rate)% · \(wins)-\(losses)"
    }

    /// 3-tile yesterday summary — Record, Hit Rate, Top Bet.
    /// Mirrors design `.yday-sum > .yday-tile`.
    private var yesterdaySum: some View {
        let settled = yesterdayForSport.filter { !$0.isPending }
        let wins = settled.filter { $0.isWin }.count
        let losses = settled.filter { $0.isLoss }.count
        let total = max(1, wins + losses)
        let rate = Int(Double(wins) / Double(total) * 100)
        let best = settled.filter { $0.isWin }
            .max(by: { $0.probability < $1.probability })
        let bestText = best.map { "\(Int($0.probability))%" } ?? "—"
        return HStack(spacing: 8) {
            ydayTile(label: "RECORD",
                     value: "\(wins)-\(losses)",
                     color: Color(hex: "#4ade80"))
            ydayTile(label: "HIT RATE",
                     value: "\(rate)",
                     unit: "%",
                     color: Color(hex: "#C6FF34"))
            ydayTile(label: "TOP CONF",
                     value: bestText,
                     color: Color(hex: "#C6FF34"))
        }
    }

    private func ydayTile(label: String, value: String,
                          unit: String? = nil, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#6E6F75"))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.anton(26))
                    .foregroundColor(color)
                if let unit = unit {
                    Text(unit)
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#1D1D1D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var yesterdayList: some View {
        LazyVStack(spacing: 8) {
            ForEach(yesterdayForSport.prefix(5)) { p in
                Button { onTapPick(p) } label: {
                    CompactPickCard(pick: p, liveScore: nil)
                        .opacity(p.isPending ? 1.0 : 0.85)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: STANDINGS placeholder
    // ════════════════════════════════════════════════════════════

    /// Placeholder card for standings — we don't have a live standings
    /// feed yet, so we render the chrome (header strip + 5 mute rows)
    /// per design and label it "Coming soon". Data wires in later.
    private var standingsCard: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack {
                Text("#")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(width: 24, alignment: .leading)
                Text(t(.rd_team_col))
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("W")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(width: 30, alignment: .trailing)
                Text("L")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(width: 30, alignment: .trailing)
                Text(standingsTrailingHeader)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(hex: "#2F2F2F"))
                    .frame(height: 1)
            }

            // Empty rows — design renders 5 of these with mute text.
            VStack(spacing: 0) {
                Text(t(.rd_standings_load))
                    .font(.archivo(12, weight: .medium))
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            }
        }
        .background(cardBackground)
    }

    private var standingsTrailingHeader: String {
        // Design swaps this column per sport (PCT / DIV / POS / ATP).
        switch sport {
        case "f1":      return "POS"
        case "combat":  return "DIV"
        default:        return "PCT"
        }
    }

    // ════════════════════════════════════════════════════════════
    // MARK: Helpers
    // ════════════════════════════════════════════════════════════

    /// Sport title — the giant Anton header at the top. Now uses the
    /// SPORT category name (BASKETBALL, SOCCER, FOOTBALL) rather than
    /// a single league abbreviation. Each sport's hub then exposes its
    /// specific leagues (NBA, G-League, NCAAB, EuroLeague, etc.) below
    /// in the league rail.
    private var sportTitle: String {
        switch sport {
        case "basketball": return "BASKETBALL"
        case "soccer":     return "SOCCER"
        case "baseball":   return "BASEBALL"
        case "football":   return "FOOTBALL"
        case "hockey":     return "HOCKEY"
        case "combat":     return "MMA"
        case "f1":         return "RACING"
        case "cricket":    return "CRICKET"
        case "tennis":     return "TENNIS"
        default:           return sport.uppercased()
        }
    }

    /// Breadcrumb label — same as sportTitle now that sport-first naming
    /// is the rule everywhere. (Used to special-case FORMULA 1 → "F1".)
    private var leagueLabel: String { sportTitle }

    private var picksForSport: [Pick] {
        // Use effectiveTodayPicks so the hub renders the latest
        // available slate even when today's pipeline batch is empty.
        vm.effectiveTodayPicks.filter { $0.sport == sport }
    }

    private var topPick: Pick? {
        // Respect the league filter so selecting a league chip (e.g.
        // NASCAR on the racing page) re-points the hero + field at that
        // league. nil filter → whole-sport top pick, unchanged.
        filteredPicksForSport.max(by: { $0.probability < $1.probability })
    }

    /// Race whose driver field the RACE FIELD section renders: the
    /// highest-confidence race carrying field odds within the active
    /// league filter. Lets the racing page switch between F1 and NASCAR.
    private var featuredRace: Pick? {
        filteredPicksForSport
            .filter { $0.fieldOdds?.isEmpty == false }
            .max(by: { $0.probability < $1.probability })
    }

    private var avgConf: Double {
        let arr = picksForSport.map { $0.probability }
        return arr.isEmpty ? 0 : arr.reduce(0, +) / Double(arr.count)
    }

    private var hasLiveToday: Bool {
        picksForSport.contains { p in
            guard let gid = p.gameId,
                  let s = vm.liveScores.first(where: { $0.gameId == gid })
            else { return false }
            return s.isLive
        }
    }

    private var glowColor: Color {
        // Per-sport tint from agent's spec (sport-hubs.jsx SPORT_GLOW).
        switch sport {
        case "basketball": return Color(hex: "#E75A28")    // orange
        case "soccer":     return Color(hex: "#C6FF34")    // lime
        case "football":   return Color(hex: "#785AF0")    // purple
        case "baseball":   return Color(hex: "#FF5A36")    // red-orange
        case "hockey":     return Color(hex: "#5B8CFF")    // blue
        case "combat":     return Color(hex: "#FF3C28")    // red
        case "f1":         return Color(hex: "#E10600")    // ferrari red
        case "tennis":     return Color(hex: "#C6FF3A")    // yellow-green (matches detail accent)
        case "cricket":    return Color(hex: "#FFD93D")    // saffron
        default:           return Color(hex: "#C6FF34")
        }
    }

    private func liveScore(for pick: Pick) -> LiveScore? {
        guard let gid = pick.gameId else { return nil }
        return vm.liveScores.first { $0.gameId == gid }
    }
}

/// Small lime hero shown on Sport Hub above the today list.
struct SmallPickHero: View {
    let pick: Pick
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(t(.rd_top_ai_pick_today))
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color.black.opacity(0.6))
                    Spacer()
                    Text("\(Int(pick.probability))% CONF")
                        .font(.mono(10, weight: .heavy))
                        .foregroundColor(Color(hex: "#C6FF34"))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#171717"))
                        .clipShape(Capsule())
                }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pick.shortDisplayPick.uppercased())
                            .font(.anton(34))
                            .lineSpacing(-6)
                            .foregroundColor(Color(hex: "#171717"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                        Text("\(t(.rd_over_prefix))\(opp.uppercased())")
                            .font(.archivo(11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color.black.opacity(0.65))
                    }
                    Spacer(minLength: 8)
                    HiFiConfidenceRing(percent: pick.probability,
                                       color: Color(hex: "#171717"),
                                       trackColor: Color.black.opacity(0.15),
                                       size: 72,
                                       stroke: 5,
                                       numberColor: Color(hex: "#171717"),
                                       label: "AI CONF")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LimeGlassSurface(cornerRadius: 22))
            .shadow(color: Color(hex: "#a8e000").opacity(0.35), radius: 16, x: 0, y: 16)
        }
        .buttonStyle(.plain)
    }

    private var opp: String {
        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
            || pick.homeTeam.lowercased().contains(pick.pick.lowercased())
        return pickedHome ? pick.awayTeam : pick.homeTeam
    }
}

/// Compact 3-row pick card for sport hubs / picks lists.
struct CompactPickCard: View {
    let pick: Pick
    let liveScore: LiveScore?

    /// Single source of truth for what this card should look like —
    /// the same helper the home GameCard, the picks-tab outcome card,
    /// and the live tab all use. Switching the top row, center column
    /// and badge off `state` makes a past-pending pick render as
    /// AWAITING here too instead of "VS · 7:30 PM yesterday".
    private var state: PickRenderState {
        pick.renderState(liveScore: liveScore)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                topLeftBadge
                Spacer()
                ConfPill(probability: pick.probability)
            }
            .padding(.bottom, 10)
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                    Text(teamShortName(pick.awayTeam, sport: pick.sport))
                        .font(.anton(16))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                // Center column varies by state — numeric score for live
                // / settled, hourglass for awaitingResult, VS+kickoff for
                // upcoming. Mirrors ScoreView in Pick1HomeHiFi so every
                // surface renders identically.
                centerColumn
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam, sport: pick.sport))
                        .font(.anton(16))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            HStack {
                HStack(spacing: 6) {
                    Text("AI")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text(pick.shortDisplayPick.uppercased())
                        .font(.archivo(11, weight: .bold))
                        .foregroundColor(Color(hex: "#C6FF34"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
                Text(pick.keyFactor ?? "—")
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .lineLimit(1)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "#2F2F2F"))
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    /// Top-left state badge — pulse for live, amber AWAITING for past-
    /// pending, FINAL for graded, otherwise the league name as before.
    @ViewBuilder
    private var topLeftBadge: some View {
        switch state {
        case .live:
            HStack(spacing: 5) {
                Circle()
                    .fill(Color(hex: "#FF5A36"))
                    .frame(width: 6, height: 6)
                Text(t(.card_live))
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#FF5A36"))
            }
        case .awaitingResult:
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text(t(.card_awaiting))
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#F59E0B"))
            }
        case .won, .lost:
            Text("\(t(.card_final)) · \(displayLeague(pick.league))")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#B9B7B0"))
        case .upcoming:
            Text(displayLeague(pick.league))
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#B9B7B0"))
        }
    }

    /// Score / kickoff column — mirrors the home GameCard's ScoreView
    /// so the look is identical across surfaces.
    @ViewBuilder
    private var centerColumn: some View {
        switch state {
        case .live, .won, .lost:
            if let s = liveScore, let h = s.homeScore, let a = s.awayScore {
                HStack(spacing: 6) {
                    Text("\(a)").font(.anton(22)).foregroundColor(Color(hex: "#F5F3EE"))
                    Text("–").font(.anton(16)).foregroundColor(Color(hex: "#6E6F75"))
                    Text("\(h)").font(.anton(22)).foregroundColor(Color(hex: "#B9B7B0"))
                }
            } else if let h = pick.homeScore, let a = pick.awayScore {
                HStack(spacing: 6) {
                    Text("\(a)").font(.anton(22)).foregroundColor(Color(hex: "#F5F3EE"))
                    Text("–").font(.anton(16)).foregroundColor(Color(hex: "#6E6F75"))
                    Text("\(h)").font(.anton(22)).foregroundColor(Color(hex: "#B9B7B0"))
                }
            } else {
                Text(state == .live ? "LIVE" : "FINAL")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }
        case .awaitingResult:
            VStack(spacing: 3) {
                Image(systemName: "hourglass")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text(t(.card_awaiting))
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(Color(hex: "#F59E0B"))
            }
        case .upcoming:
            VStack(spacing: 2) {
                Text("VS")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                if let kickoff = liveScore?.startTime {
                    Text(kickoffTimeText(kickoff))
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
            }
        }
    }
}

struct ConfPill: View {
    let probability: Double
    var body: some View {
        let hot = probability >= 80
        return HStack(spacing: 5) {
            Text("AI")
                .font(.mono(10, weight: .medium))
                .foregroundColor(hot ? Color(hex: "#C6FF34") : Color(hex: "#B9B7B0"))
            Text("\(Int(probability))%")
                .font(.mono(10, weight: .heavy))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(hot ? Color(hex: "#C6FF34").opacity(0.08) : Color(hex: "#232323")))
        .overlay(Capsule().stroke(hot ? Color(hex: "#C6FF34").opacity(0.3) : Color(hex: "#3A3A3A"), lineWidth: 1))
        .animation(Pick1Springs.snappy, value: probability)
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Profile
// ════════════════════════════════════════════════════════════════

struct ProfileView: View {
    @ObservedObject var vm: PicksViewModel
    var isPro: Bool = false
    let onShowPaywall: () -> Void
    let onSignOut: () -> Void
    var onBrowsePicks: () -> Void = {}

    /// Live, mutable user state. Read for display, mutated via the
    /// Edit Profile sheet (which calls auth.saveProfile).
    @Environment(AuthManager.self) private var auth

    /// Drives every settings-row title to re-render in the user's
    /// language as soon as they pick one — no app restart.
    @Environment(LocalizationManager.self) private var loc

    /// Trial-aware upgrade copy (chip shows "3 DAYS FREE" only while this
    /// Apple ID is still intro-offer eligible).
    @EnvironmentObject private var subs: SubscriptionManager

    @State private var showEditProfile: Bool = false
    @State private var showDeleteAccountConfirm: Bool = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                TopNavBar(crumb: "APP · ", crumbAccent: "PROFILE", live: false, onBack: {}, showBack: false)
                    .overlay(alignment: .trailing) {
                        // Top-right Edit button — opens the
                        // EditProfileSheet (same destination as tapping
                        // the avatar row, but discoverable from the
                        // chrome). Mirrors the .star button on
                        // MatchDetailView's TopNavBar for consistency.
                        Button { showEditProfile = true } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#F5F3EE"))
                                .frame(width: 38, height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(hex: "#1D1D1D"))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit profile")
                        .padding(.trailing, 18)
                    }
                profileHead
                    .padding(.bottom, 18)
                // Profile is now settings-only — Account + Support
                // sections, no Stats / Badges tabs. Avatar header stays
                // on top so the user can identify which account they're
                // signed in as and reach Edit Profile.
                settingsTabBody
                    .padding(.horizontal, 16)
                Spacer().frame(height: 140)
            }
        }
        .alert("Delete your account?", isPresented: $showDeleteAccountConfirm) {
            Button(t(.profile_delete_account), role: .destructive) {
                // Same path as EditProfileSheet: delete_current_user RPC
                // (security definer pinned to auth.uid()), then bounce
                // to the welcome flow.
                Task {
                    let ok = await auth.deleteAccount()
                    if ok { onSignOut() }
                }
            }
            Button(t(.action_cancel), role: .cancel) {}
        } message: {
            Text(t(.profile_delete_alert_message))
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(
                auth: auth,
                isOpen: $showEditProfile,
                onDeleteAccount: {
                    // Real delete — calls the `delete_current_user`
                    // Postgres function (security definer, pinned to
                    // auth.uid()), which removes the auth.users row
                    // and cascades through profiles + any user-owned
                    // tables with ON DELETE CASCADE. On success, the
                    // local state is wiped and onSignOut() bounces
                    // the UI back to the welcome flow.
                    Task {
                        let ok = await auth.deleteAccount()
                        if ok { onSignOut() }
                    }
                }
            )
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet(selection: $appLanguage,
                                isOpen: $showLanguagePicker)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPrivacySecurity) {
            PrivacySecuritySheet(isOpen: $showPrivacySecurity)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showInvite) {
            InviteFriendsView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTerms) {
            LegalSheet(doc: .terms, isOpen: $showTerms)
                .presentationDragIndicator(.visible)
        }
        .task { await refreshNotificationStatus() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshNotificationStatus() }
        }
    }

    private var profileHead: some View {
        // Lime radial glow drawn as a *background* of the avatar row
        // instead of inside a sibling ZStack — the previous version
        // had the gradient as a sibling with .frame(height: 360),
        // which forced the whole header to be 360pt tall and left a
        // huge empty gap between the avatar and the Settings groups.
        // Using .background lets the glow bleed past the row's bounds
        // visually (via offset) without claiming any layout space.
        Button { showEditProfile = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#C6FF34"), Color(hex: "#a8e000")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: Color(hex: "#C6FF34").opacity(0.3), radius: 10, x: 0, y: 8)
                        Text(initial)
                            .font(.anton(32))
                            .foregroundColor(Color(hex: "#171717"))
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.anton(28))
                            .foregroundColor(Color(hex: "#F5F3EE"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(handleLine)
                            .font(.mono(11, weight: .medium))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Image(systemName: isPro ? "diamond.fill" : "circle.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(tierLabel)
                                .font(.archivoNarrow(9, weight: .bold))
                                .tracking(1.8)
                        }
                        .foregroundColor(Color(hex: "#C6FF34"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#C6FF34").opacity(0.08))
                        .overlay(Capsule().stroke(Color(hex: "#C6FF34").opacity(0.3), lineWidth: 1))
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            RadialGradient(
                colors: [Color(hex: "#C6FF34").opacity(0.22),
                         Color(hex: "#C6FF34").opacity(0.06),
                         .clear],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0,
                endRadius: 220
            )
            .frame(width: 380, height: 320)
            .blur(radius: 32)
            .offset(x: 80, y: -100)   // bleed past the row, top-right
            .allowsHitTesting(false)
        }
    }

    /// "@mchen · Member since 2026" — design's handle line. Falls back
    /// to email if firstName isn't set.
    private var handleLine: String {
        let handle: String
        if let e = auth.userEmail,
           let local = e.split(separator: "@").first {
            handle = "@" + String(local)
        } else if let f = auth.firstName?.lowercased() {
            handle = "@" + f
        } else {
            handle = "@pick1fan"
        }
        return "\(handle) · Member since 2026"
    }

    /// Tier label — "DIAMOND · L\(level)" for Pro, "ROOKIE · FREE" for
    /// Free. Level scales with total wins (1 + every 10 wins).
    private var tierLabel: String {
        let level = max(1, vm.totalWins / 10 + 1)
        return isPro ? "DIAMOND · L\(level)" : "ROOKIE · FREE"
    }

    private var initial: String {
        if let f = auth.firstName, let c = f.first { return String(c).uppercased() }
        if let e = auth.userEmail, let c = e.first { return String(c).uppercased() }
        return "P"
    }

    private var displayName: String {
        if let f = auth.firstName, !f.isEmpty,
           let l = auth.lastName,  !l.isEmpty {
            return "\(f) \(l)".uppercased()
        }
        if let e = auth.userEmail {
            return e.split(separator: "@").first.map { String($0).uppercased() } ?? e.uppercased()
        }
        return "PICK1 FAN"
    }

    @State private var notificationsOn: Bool = false
    @State private var showLanguagePicker: Bool = false
    @State private var showPrivacySecurity: Bool = false
    @State private var showInvite: Bool = false
    @State private var showTerms: Bool = false
    /// Persisted language preference. Stored as the BCP-47 region-less
    /// code ("en", "fr", "es" …); UI lookups use `languageCode` for the
    /// trailing pill and `languageSub` for the row's sub-label.
    @AppStorage("appLanguage") private var appLanguage: String = "en"

    /// Trailing pill text on the Language row — flag emoji + code
    /// (e.g. "🇫🇷 FR"). Reading both at a glance is faster than the
    /// code alone.
    private var languageCode: String {
        let lang = ProfileView.languages.first { $0.code == appLanguage }
        let flag = lang?.flag ?? ""
        return flag.isEmpty ? appLanguage.uppercased()
                            : "\(flag) \(appLanguage.uppercased())"
    }

    /// Sub-label under "Language" — the localized human name of the
    /// currently-selected language ("English", "Français", "Español"…).
    private var languageSub: String {
        ProfileView.languages.first { $0.code == appLanguage }?.name
            ?? "System default"
    }

    /// Languages we offer in the picker. Add more as we ship
    /// localizations — order is alphabetical by English name.
    /// Arabic uses Modern Standard / Literary Arabic (al-fuṣḥā), the
    /// pan-regional written form. We don't ship colloquial dialects.
    /// Flag choices: pan-language flags don't exist as Unicode emoji,
    /// so we pick the canonical "home" country (UK for English, Spain
    /// for Spanish, Portugal for Portuguese, Saudi Arabia for Arabic).
    static let languages: [(code: String, name: String, native: String, flag: String)] = [
        ("ar", "Arabic",      "العربية الفصحى", "🇸🇦"),
        ("en", "English",     "English",         "🇬🇧"),
        ("fr", "French",      "Français",        "🇫🇷"),
        ("de", "German",      "Deutsch",         "🇩🇪"),
        ("it", "Italian",     "Italiano",        "🇮🇹"),
        ("pt", "Portuguese",  "Português",       "🇵🇹"),
        ("es", "Spanish",     "Español",         "🇪🇸"),
    ]

    /// Hairline divider used between rows inside a grouped settings card.
    private var divider: some View {
        Rectangle()
            .fill(Color(hex: "#2F2F2F"))
            .frame(height: 1)
            .padding(.leading, 62)   // align past the icon tile
    }

    private var settingsTabBody: some View {
        VStack(spacing: 16) {
            // ── UPGRADE CTA (Free users only) ──────────────────────
            // Sits above ACCOUNT so it's the first thing a Free user
            // sees in Settings. Tap → paywall sheet. Pro users skip
            // this entirely; the Subscription row in ACCOUNT shows
            // their current tier instead.
            if !isPro {
                profileUpgradeCard
            }

            // ── MY BETS (personal P&L) ─────────────────────────────
            MyBetsCard(picks: vm.picks, onBrowse: onBrowsePicks)

            // ── ACCOUNT / PREFS ────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HubSectionHead(title: loc.t(.settings_account_section),
                               meta: loc.t(.settings_prefs_meta))
                    .padding(.horizontal, -20)   // cancel HubSectionHead's 20pt inset
                VStack(spacing: 0) {
                    settingsToggleRow(
                        icon: "bell.fill",
                        title: loc.t(.settings_notifications),
                        sub: loc.t(.settings_notifications_sub),
                        isOn: Binding(
                            get: { notificationsOn },
                            set: { updateNotificationPreference($0) }
                        )
                    )
                    divider
                    settingsLinkRow(
                        icon: "globe",
                        title: loc.t(.settings_language),
                        sub: languageSub,
                        trailing: languageCode,
                        action: { showLanguagePicker = true }
                    )
                    divider
                    settingsLinkRow(
                        icon: "creditcard.fill",
                        title: loc.t(.settings_subscription),
                        sub: isPro ? loc.t(.settings_subscription_sub_pro)
                                   : loc.t(.settings_subscription_sub_free),
                        trailing: isPro ? loc.t(.settings_subscription_pro)
                                        : loc.t(.settings_subscription_free),
                        action: onShowPaywall
                    )
                    divider
                    settingsLinkRow(
                        icon: "gift.fill",
                        title: loc.t(.referral_title),
                        sub: loc.t(.referral_subtitle),
                        trailing: nil,
                        action: { showInvite = true }
                    )
                    divider
                    settingsLinkRow(
                        icon: "lock.fill",
                        title: loc.t(.settings_privacy_security),
                        sub: "Sign-in · password",
                        trailing: nil,
                        action: { showPrivacySecurity = true }
                    )
                }
                .background(cardBackground)
            }

            // ── SUPPORT / HELP ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HubSectionHead(title: loc.t(.settings_support_section),
                               meta: loc.t(.settings_help_meta))
                    .padding(.horizontal, -20)
                VStack(spacing: 0) {
                    settingsLinkRow(
                        icon: "questionmark.circle.fill",
                        title: loc.t(.settings_help_center),
                        sub: "FAQs · contact us",
                        trailing: nil,
                        action: {
                            if let url = URL(string: "mailto:support@pick1.live") {
                                openURL(url)
                            }
                        }
                    )
                    divider
                    settingsLinkRow(
                        icon: "doc.text.fill",
                        title: loc.t(.settings_terms),
                        sub: "Service terms · effective Apr 30, 2026",
                        trailing: nil,
                        action: { showTerms = true }
                    )
                    divider
                    settingsLinkRow(
                        icon: "rectangle.portrait.and.arrow.right.fill",
                        title: loc.t(.settings_sign_out),
                        sub: "You'll stay logged in on web",
                        trailing: nil,
                        danger: true,
                        action: onSignOut
                    )
                    divider
                    // Account deletion must be discoverable from the
                    // top-level settings (App Review 5.1.1(v) — the
                    // EditProfileSheet copy alone was judged hidden).
                    settingsLinkRow(
                        icon: "trash.fill",
                        title: "Delete Account",
                        sub: "Permanently erase your account & data",
                        trailing: nil,
                        danger: true,
                        action: { showDeleteAccountConfirm = true }
                    )
                }
                .background(cardBackground)
            }
        }
    }

    // MARK: Upgrade CTA

    /// Profile-context upgrade card shown to Free users above the
    /// Settings groups. Mirrors ProUnlockCard's lime visual language
    /// (radial gradient + ink shadow) so the upsell feels consistent
    /// with the home-screen unlock affordance.
    private var profileUpgradeCard: some View {
        let ink = Color(hex: "#171717")
        // Benefit-led conversion card: concrete value checklist + price anchor
        // instead of a bare "UPGRADE" ask. Weekly carries a 3-day StoreKit
        // intro-offer trial again (2026-07); trial copy is eligibility-gated.
        return Button(action: onShowPaywall) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 6) {
                            Image(systemName: "diamond.fill")
                                .font(.system(size: 11, weight: .heavy))
                            Text(t(.rd_pick1_pro))
                                .font(.archivoNarrow(10, weight: .bold))
                                .tracking(2.4)
                        }
                        .foregroundColor(ink.opacity(0.7))

                        VStack(alignment: .leading, spacing: -7) {
                            Text(t(.rd_unlock))
                            Text(t(.rd_every_pick_line))
                        }
                        .font(.anton(28))
                        .foregroundColor(ink)
                    }
                    Spacer(minLength: 8)
                    // Trailing chevron pill — visually identical to the
                    // home unlock card's "→" affordance.
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(Color(hex: "#C6FF34"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(ink))
                }

                // Scannable value checklist — the "what you actually get."
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(["Every pick, all 9 sports",
                             "The reasoning behind each call",
                             "Best line across 6 sportsbooks"], id: \.self) { b in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(Color(hex: "#C6FF34"))
                                .frame(width: 17, height: 17)
                                .background(Circle().fill(ink))
                            Text(b)
                                .font(.archivo(13, weight: .bold))
                                .foregroundColor(ink.opacity(0.9))
                        }
                    }
                }

                // Price anchor + friction-killer. Leads with the trial when
                // this Apple ID is still eligible for it.
                HStack(spacing: 8) {
                    Text(subs.introOfferEligible ? "3 DAYS FREE · THEN $14.99/WK" : "FROM $14.99/WK")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(Color(hex: "#C6FF34"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(ink))
                    Text(t(.rd_cancel_anytime))
                        .font(.archivo(11, weight: .semibold))
                        .foregroundColor(ink.opacity(0.55))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LimeGlassSurface(cornerRadius: 22))
            .shadow(color: Color(hex: "#a8e000").opacity(0.35),
                    radius: 14, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: Settings rows

    /// Row with icon + title/sub + LimeToggle trailing. Used for
    /// Notifications, Dark Mode, etc.
    private func settingsToggleRow(icon: String, title: String,
                                    sub: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            settingsIconTile(icon, danger: false)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.archivo(13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text(sub)
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
            Spacer()
            LimeToggle(isOn: isOn)
        }
        .padding(14)
    }

    /// Mirror the real iOS authorization state. The prior toggle only
    /// changed local view state, so Profile could say alerts were enabled
    /// even when the system had denied them.
    private func updateNotificationPreference(_ wantsOn: Bool) {
        if wantsOn {
            Task {
                let granted = (try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
                notificationsOn = granted
                Analytics.notificationPermissionResult(granted: granted, source: "profile")
                if granted { PushManager.shared.registerIfAuthorized() }
            }
        } else {
            Analytics.track("notification_settings_opened", ["source": "profile_disable"])
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationsOn = true
        default:
            notificationsOn = false
        }
    }

    /// Row with icon + title/sub + chevron (or trailing label).
    /// Used for Subscription, Help, Sign Out, Delete, etc.
    private func settingsLinkRow(icon: String, title: String, sub: String,
                                  trailing: String?, danger: Bool = false,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                settingsIconTile(icon, danger: danger)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.archivo(13, weight: .semibold))
                        .foregroundColor(danger ? Color(hex: "#FF5A36")
                                                : Color(hex: "#F5F3EE"))
                    Text(sub)
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                Spacer()
                if let t = trailing {
                    Text(t)
                        .font(.mono(10, weight: .heavy))
                        .tracking(0.5)
                        .foregroundColor(Color(hex: "#C6FF34"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: "#C6FF34").opacity(0.10)))
                        .overlay(Capsule().stroke(Color(hex: "#C6FF34").opacity(0.28),
                                                   lineWidth: 1))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    /// 34×34 rounded icon tile, lime by default, hot-red for danger rows.
    private func settingsIconTile(_ icon: String, danger: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(danger ? Color(hex: "#FF5A36") : Color(hex: "#C6FF34"))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#232323"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
            )
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Wins / Favorites
// ════════════════════════════════════════════════════════════════

struct WinsView: View {
    @ObservedObject var vm: PicksViewModel
    let onClose: () -> Void
    let onTapPick: (Pick) -> Void
    var onBrowsePicks: () -> Void = {}

    /// Persistent favorites — populated by tapping the star on
    /// MatchDetailView. Driving the list off this store (instead of
    /// `result == "win"`) is what makes "favorites land in Wins."
    @EnvironmentObject private var favorites: FavoritesStore

    @State private var confirmingClear: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopNavBar(crumb: t(.rd_crumb_you), crumbAccent: t(.nav_picks).uppercased(), live: false, onBack: onClose, showBack: false)
                PageHero(title: t(.rd_your),
                         titleAccent: t(.rd_picks_word),
                         sub: [t(.rd_saved_matches, count: wonPicks.count),
                               t(.rd_tap_star_favorite)],
                         glow: Color(hex: "#C6FF34"))
                    .padding(.bottom, 6)

                favActionsRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                if wonPicks.isEmpty {
                    emptyState
                        .padding(.horizontal, 20)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(wonPicks) { p in
                            Button {
                                Haptics.tap()
                                onTapPick(p)
                            } label: {
                                wonCard(pick: p)
                                    .pressableScale(0.985)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Spacer().frame(height: 140)
            }
        }
        // Pull-to-refresh removed — it re-ran loadAll and briefly emptied the slate.
    }

    /// Favorited picks (any state — pending / win / loss) the user
    /// has starred. Picks that have since been deleted from the
    /// `picks` table just don't appear (favorites store retains the
    /// ID either way). Sorted newest first by game date.
    private var wonPicks: [Pick] {
        let favIds = favorites.ids
        // Search across history + today + yesterday so we don't miss
        // picks that haven't migrated to historyPicks yet.
        var byId: [UUID: Pick] = [:]
        for p in vm.historyPicks { byId[p.id] = p }
        for p in vm.todayPicks { byId[p.id] = p }
        for p in vm.yesterdayPicks { byId[p.id] = p }
        return favIds.compactMap { byId[$0] }
            .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast)
                > ($1.gameDate, $1.createdAt ?? Date.distantPast) }
    }

    /// Top-of-list count + "Clear all" button with 2-stage confirm flow
    /// (matches design `.fav-actions`).
    @ViewBuilder
    private var favActionsRow: some View {
        HStack {
            Text(t(.rd_matches_count, count: wonPicks.count))
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#6E6F75"))
            Spacer()
            if !wonPicks.isEmpty {
                if confirmingClear {
                    HStack(spacing: 8) {
                        Text(t(.rd_remove_all_q))
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color(hex: "#B9B7B0"))
                        Button(t(.action_cancel)) { confirmingClear = false }
                            .font(.archivoNarrow(10, weight: .bold))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                        Button {
                            favorites.clear()
                            confirmingClear = false
                        } label: {
                            Text(t(.rd_clear_all))
                                .font(.archivoNarrow(10, weight: .heavy))
                                .tracking(1.8)
                                .foregroundColor(Color(hex: "#171717"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(Color(hex: "#FF5A36")))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button { confirmingClear = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .bold))
                            Text(t(.rd_clear_all))
                                .font(.archivoNarrow(10, weight: .bold))
                                .tracking(1.8)
                        }
                        .foregroundColor(Color(hex: "#B9B7B0"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(hex: "#1D1D1D")))
                        .overlay(Capsule().stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(t(.rd_no_saved_title))
                .font(.anton(22))
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text(t(.rd_no_saved_sub))
                .font(.archivo(12, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
            Button {
                Analytics.emptyStateAction(screen: "my_picks")
                onBrowsePicks()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                    Text("BROWSE TODAY'S PICKS")
                        .font(.archivoNarrow(11, weight: .bold)).tracking(1.4)
                }
                .foregroundColor(Color(hex: "#171717"))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Color(hex: "#C6FF34")))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#3A3A3A"), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }

    /// Won card per spec: top tag + WON badge, mirrored team body
    /// (HOME left / SCORE / AWAY right with `flex-row-reverse` on
    /// AWAY column), strike-through on the LOSING team, dashed
    /// footer with AI PICK + key factor + remove-X button.
    /// Renders 4 distinct states based on `pick.result` + live data:
    ///   • win  → green "WON" badge, FINAL tag
    ///   • loss → red "LOST" badge, FINAL tag, predicted-team strikethrough
    ///   • live → orange "LIVE" badge with live score
    ///   • pending → mute "UPCOMING" badge, scheduled label
    private func wonCard(pick: Pick) -> some View {
        let live = vm.liveScores.first { $0.gameId == pick.gameId }
        // Single source of truth: PickRenderState centralizes the
        // win/loss/live/awaiting/upcoming decision so all three card
        // surfaces (Picks tab, Live tab, sport hub) match.
        let state = pick.renderState(liveScore: live)
        let isFinal = state == .won || state == .lost

        // For settled picks, strike the team opposite the user's pick.
        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
        let pickedAway = pick.pick.lowercased().contains(pick.awayTeam.lowercased())
        let homeStrike = state == .lost
            ? pickedHome
            : (state == .won && !pickedAway && (pick.homeScore ?? 0) < (pick.awayScore ?? 0))
        let awayStrike = state == .lost
            ? pickedAway
            : (state == .won && !pickedHome && (pick.awayScore ?? 0) < (pick.homeScore ?? 0))

        let topTag: String = {
            switch state {
            case .live:
                let q = live?.quarter.flatMap { Int($0) }
                    .map { "Q\($0)" } ?? "LIVE"
                return "\(pick.league.uppercased()) · LIVE · \(q)"
            case .won, .lost:
                return "\(pick.league.uppercased()) · \(relativeDate(pick.gameDate)) · FINAL"
            case .awaitingResult:
                return "\(pick.league.uppercased()) · \(relativeDate(pick.gameDate)) · AWAITING"
            case .upcoming:
                return "\(pick.league.uppercased()) · \(relativeDate(pick.gameDate)) · UPCOMING"
            }
        }()

        return VStack(spacing: 0) {
            HStack {
                Text(topTag)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Spacer()
                outcomeBadge(state: state)
            }
            .padding(.bottom, 12)

            // Mirrored layout: HOME left + SCORE center + AWAY right.
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 9) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam, sport: pick.sport))
                        .font(.anton(18))
                        .foregroundColor(homeStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(homeStrike, color: Color(hex: "#3A3A3A"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Score area: live score (if live), final score (if
                // settled), VS for upcoming/awaiting.
                Group {
                    if state == .live,
                       let s = live, let h = s.homeScore, let a = s.awayScore {
                        scoreText(home: h, away: a, homeMute: false, awayMute: false,
                                  liveAccent: true)
                    } else if isFinal,
                              let h = pick.homeScore, let a = pick.awayScore {
                        scoreText(home: h, away: a,
                                  homeMute: homeStrike, awayMute: awayStrike,
                                  liveAccent: false)
                    } else {
                        Text("VS").font(.archivoNarrow(11, weight: .bold))
                            .tracking(2).foregroundColor(Color(hex: "#6E6F75"))
                    }
                }

                HStack(spacing: 9) {
                    Text(teamShortName(pick.awayTeam, sport: pick.sport))
                        .font(.anton(18))
                        .foregroundColor(awayStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(awayStrike, color: Color(hex: "#3A3A3A"))
                        .lineLimit(1)
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Footer with dashed top border, AI PICK label, money line
            // (wins) or key factor + remove X.
            HStack(spacing: 8) {
                Text(t(.rd_ai_pick))
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.displayPick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                if state == .won {
                    // Same hypothetical money framing as Latest Wins.
                    Text("$100 → $\(Int((pick.decimalOdds * 100).rounded()))")
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#C6FF34"))
                } else {
                    Text("· \(pick.keyFactor ?? pick.league.uppercased())")
                        .font(.mono(10))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    favorites.toggle(pick)   // un-favorite
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#232323")))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                DashedLine()
                    .stroke(Color(hex: "#2F2F2F"),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
        }
        .padding(14)
        .background(stateCardBackground(state))
    }

    /// Outcome badge — colored capsule pinned right of the top tag
    /// row. Switches on PickRenderState so live / won / lost /
    /// awaiting / upcoming each get their own distinct treatment.
    @ViewBuilder
    private func outcomeBadge(state: PickRenderState) -> some View {
        switch state {
        case .live:
            HStack(spacing: 5) {
                Circle().fill(Color(hex: "#FF5A36")).frame(width: 6, height: 6)
                Text(t(.card_live))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#FF5A36"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#FF5A36").opacity(0.10))
            .overlay(Capsule().stroke(Color(hex: "#FF5A36").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .won:
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                Text(t(.rd_won))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#C6FF34"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#C6FF34").opacity(0.1))
            .overlay(Capsule().stroke(Color(hex: "#C6FF34").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .lost:
            HStack(spacing: 5) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .heavy))
                Text(t(.rd_lost))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#FF5A5A"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#FF5A5A").opacity(0.10))
            .overlay(Capsule().stroke(Color(hex: "#FF5A5A").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .awaitingResult:
            // Past kickoff, pipeline hasn't graded yet. Amber so
            // it doesn't masquerade as "this hasn't happened yet".
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                    .font(.system(size: 9, weight: .heavy))
                Text(t(.card_awaiting))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#B98C40"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#B98C40").opacity(0.10))
            .overlay(Capsule().stroke(Color(hex: "#B98C40").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .upcoming:
            Text(t(.live_section_upcoming))
                .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
                .foregroundColor(Color(hex: "#6E6F75"))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(hex: "#232323"))
                .overlay(Capsule().stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    /// Score row — 24pt Anton home / em-dash / 24pt Anton away. Mute
    /// the side that lost (settled) or render in lime when live.
    private func scoreText(home: Int, away: Int,
                           homeMute: Bool, awayMute: Bool,
                           liveAccent: Bool) -> some View {
        let lit = liveAccent ? Color(hex: "#FF5A36") : Color(hex: "#F5F3EE")
        return HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(home)")
                .font(.anton(24)).fontWeight(.black)
                .foregroundColor(homeMute ? Color(hex: "#6E6F75") : lit)
            Text("–")
                .font(.anton(14))
                .foregroundColor(Color(hex: "#6E6F75"))
            Text("\(away)")
                .font(.anton(24)).fontWeight(.black)
                .foregroundColor(awayMute ? Color(hex: "#6E6F75") : lit)
        }
    }

    /// "TODAY", "YESTERDAY", "2 DAYS AGO", or the date itself.
    private func relativeDate(_ ymd: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: ymd) else { return ymd.uppercased() }
        let cal = Calendar.current
        if cal.isDateInToday(d)     { return "TODAY" }
        if cal.isDateInYesterday(d) { return "YESTERDAY" }
        let days = cal.dateComponents([.day], from: d, to: Date()).day ?? 0
        return "\(days) DAYS AGO"
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Prediction history (won / lost track record)
// ════════════════════════════════════════════════════════════════

/// Tapping the WINS / ACCURACY tiles opens this sheet: every graded
/// pick we made — won or lost — newest first, each row tagged with the
/// payout the pick would have returned (green +X% for a win, the
/// foregone +X% in red for a loss). Pending picks are excluded; this is
/// strictly the settled track record.
struct PredictionHistoryView: View {
    @ObservedObject var vm: PicksViewModel
    @Environment(\.dismiss) private var dismiss

    /// All / Won / Lost filter.
    private enum Filter: String, CaseIterable { case all = "ALL", won = "WON", lost = "LOST" }
    @State private var filter: Filter = .all

    /// Localized label for a filter chip (rawValue stays the stable key).
    private func filterTitle(_ f: Filter) -> String {
        switch f {
        case .all:  return t(.rd_all_filter)
        case .won:  return t(.rd_won)
        case .lost: return t(.rd_lost)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            filterRow
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if visiblePicks.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        // Proof-of-honesty: stated confidence vs actual hit
                        // rate. Only on the ALL view so it isn't repeated.
                        if filter == .all {
                            CalibrationCard()
                                .padding(.bottom, 4)
                        }
                        ForEach(visiblePicks) { p in
                            historyRow(pick: p)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Color(hex: "#171717").ignoresSafeArea())
    }

    // MARK: data

    /// Settled picks across history + yesterday, de-duplicated by id,
    /// newest first. yesterdayPicks can hold freshly-graded rows that
    /// haven't migrated into historyPicks yet, so we merge both.
    private var settledPicks: [Pick] {
        var byId: [UUID: Pick] = [:]
        for p in vm.historyPicks where p.isWin || p.isLoss { byId[p.id] = p }
        for p in vm.yesterdayPicks where p.isWin || p.isLoss { byId[p.id] = p }
        // Follow the home sport filter: a sport-filtered home opens a
        // sport-filtered record; ALL shows everything.
        if vm.selectedSport != "all" {
            byId = byId.filter { $0.value.sport == vm.selectedSport }
        }
        return byId.values.sorted {
            ($0.gameDate, $0.createdAt ?? Date.distantPast)
                > ($1.gameDate, $1.createdAt ?? Date.distantPast)
        }
    }

    private var visiblePicks: [Pick] {
        switch filter {
        case .all:  return settledPicks
        case .won:  return settledPicks.filter { $0.isWin }
        case .lost: return settledPicks.filter { $0.isLoss }
        }
    }

    private var wonCount: Int { settledPicks.filter { $0.isWin }.count }
    private var lostCount: Int { settledPicks.filter { $0.isLoss }.count }

    // MARK: chrome

    private var grabber: some View {
        Capsule()
            .fill(Color(hex: "#3A3A3A"))
            .frame(width: 38, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(t(.rd_track))
                    .font(.anton(26)).foregroundColor(Color(hex: "#F5F3EE"))
                + Text(t(.rd_record))
                    .font(.anton(26)).foregroundColor(Color(hex: "#C6FF34"))
                Text("\(wonCount)–\(lostCount) \(t(.rd_on_graded))")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(hex: "#232323")))
                    .overlay(Circle().stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.self) { f in
                let count = f == .all ? settledPicks.count : (f == .won ? wonCount : lostCount)
                Button {
                    Haptics.tap()
                    filter = f
                } label: {
                    Text("\(filterTitle(f)) \(count)")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(filter == f ? Color(hex: "#171717") : Color(hex: "#B9B7B0"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(filter == f ? Color(hex: "#C6FF34") : Color(hex: "#1D1D1D"))
                        )
                        .overlay(
                            Capsule().stroke(filter == f ? Color.clear : Color(hex: "#2F2F2F"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 34))
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(t(.rd_no_graded_title))
                .font(.anton(20))
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text(t(.rd_no_graded_sub))
                .font(.archivo(12, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: row

    /// One settled pick: league · date tag, mirrored matchup with the
    /// final score, a W/L badge, and the payout tag — what the pick
    /// returned (win) or what it would have returned (loss).
    private func historyRow(pick: Pick) -> some View {
        let won = pick.isWin
        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
        let pickedAway = pick.pick.lowercased().contains(pick.awayTeam.lowercased())
        // Strike the team that didn't win.
        let homeWon = (pick.homeScore ?? 0) > (pick.awayScore ?? 0)
        let awayWon = (pick.awayScore ?? 0) > (pick.homeScore ?? 0)
        let homeStrike = !homeWon && (pick.homeScore != nil)
        let awayStrike = !awayWon && (pick.awayScore != nil)
        _ = (pickedHome, pickedAway)

        return VStack(spacing: 0) {
            HStack {
                Text("\(pick.league.uppercased()) · \(relativeGameDate(pick.gameDate)) · FINAL")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Spacer()
                resultBadge(won: won)
            }
            .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 9) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam, sport: pick.sport))
                        .font(.anton(17))
                        .foregroundColor(homeStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(homeStrike, color: Color(hex: "#3A3A3A"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let h = pick.homeScore, let a = pick.awayScore {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(h)").font(.anton(22)).fontWeight(.black)
                            .foregroundColor(homeStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        Text("–").font(.anton(13)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(a)").font(.anton(22)).fontWeight(.black)
                            .foregroundColor(awayStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                    }
                } else {
                    Text("VS").font(.archivoNarrow(11, weight: .bold))
                        .tracking(2).foregroundColor(Color(hex: "#6E6F75"))
                }

                HStack(spacing: 9) {
                    Text(teamShortName(pick.awayTeam, sport: pick.sport))
                        .font(.anton(17))
                        .foregroundColor(awayStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(awayStrike, color: Color(hex: "#3A3A3A"))
                        .lineLimit(1)
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Text(t(.rd_ai_pick))
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.displayPick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1)
                Spacer()
                payoutTag(pick: pick, won: won)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                DashedLine()
                    .stroke(Color(hex: "#2F2F2F"),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
        }
        .padding(14)
        .background(stateCardBackground(won ? .won : .lost))
    }

    @ViewBuilder
    private func resultBadge(won: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: won ? "checkmark" : "xmark")
                .font(.system(size: 9, weight: .heavy))
            Text(won ? "WON" : "LOST")
                .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
        }
        .foregroundColor(won ? Color(hex: "#C6FF34") : Color(hex: "#FF5A5A"))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background((won ? Color(hex: "#C6FF34") : Color(hex: "#FF5A5A")).opacity(0.1))
        .overlay(Capsule().stroke((won ? Color(hex: "#C6FF34") : Color(hex: "#FF5A5A")).opacity(0.3), lineWidth: 1))
        .clipShape(Capsule())
    }

    /// The money tag in the redesign's dollars-first framing: a win
    /// shows what a $100 backer took home (solid lime); a loss shows
    /// the same hypothetical return outlined in red — the missed win,
    /// explicit.
    @ViewBuilder
    private func payoutTag(pick: Pick, won: Bool) -> some View {
        let dollars = Int((pick.decimalOdds * 100).rounded())
        Text("$100 → $\(dollars)")
            .font(.mono(11, weight: .bold))
            .foregroundColor(won ? Color(hex: "#171717") : Color(hex: "#FF5A5A"))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(
                Capsule().fill(won ? Color(hex: "#C6FF34") : Color(hex: "#FF5A5A").opacity(0.12))
            )
            .overlay(
                Capsule().stroke(won ? Color.clear : Color(hex: "#FF5A5A").opacity(0.35), lineWidth: 1)
            )
    }

    /// "TODAY", "YESTERDAY", "N DAYS AGO" — local copy so the view is
    /// self-contained (WinsView keeps its own private one).
    private func relativeGameDate(_ ymd: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: ymd) else { return ymd.uppercased() }
        let cal = Calendar.current
        if cal.isDateInToday(d)     { return "TODAY" }
        if cal.isDateInYesterday(d) { return "YESTERDAY" }
        let days = cal.dateComponents([.day], from: d, to: Date()).day ?? 0
        return "\(days) DAYS AGO"
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Live (in-play tracker)
// ════════════════════════════════════════════════════════════════

struct LiveView: View {
    @ObservedObject var vm: PicksViewModel
    var isPro: Bool = true
    let onTapPick: (Pick) -> Void
    var onUnlock: () -> Void = {}
    var onBrowsePicks: () -> Void = {}

    @EnvironmentObject private var favorites: FavoritesStore
    /// Single filter on the Live page: everything live (default) vs
    /// just the user's starred picks. The old MY PICKS / ALL LIVE
    /// segmented tabs were cut — one FAVORITES toggle is the whole UI.
    @State private var favoritesOnly: Bool = {
        #if DEBUG
        // Sim review: land on the FAVORITES sub-view directly.
        return CommandLine.arguments.contains("-liveFavs")
        #else
        return false
        #endif
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopNavBar(crumb: t(.rd_crumb_now), crumbAccent: t(.card_live), live: !livePicks.isEmpty, onBack: {}, showBack: false)
                PageHero(title: t(.rd_live_word),
                         titleAccent: t(.rd_now_word),
                         sub: [t(.rd_games_n, count: livePicks.count),
                               t(.rd_picks_in_play, count: livePicks.count)],
                         glow: Color(hex: "#FF5A36"))
                    .padding(.bottom, 6)

                tabsRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                if let nextUp = nextUpcomingPick, favoritesOnly {
                    watchBanner(nextUp)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                tabBody
                    .padding(.horizontal, 16)

                Spacer().frame(height: 140)
            }
        }
        // Pull-to-refresh removed — it re-ran loadAll and briefly emptied the slate.
    }

    /// Active-tab content. All Live → today's in-progress games (across
    /// every league). My Picks → my favorites that are live OR settled
    /// today (with W/L/LIVE badges). Favorites → all my favorites,
    /// any state, sorted newest first (mirrors the Picks tab but
    /// scoped to recent activity).
    @ViewBuilder
    private var tabBody: some View {
        if favoritesOnly {
            favoritesRecentSection
        } else {
            allLiveSection
        }
    }

    /// "ALL LIVE" — every game across every league that's currently
    /// in progress, regardless of whether the user has it picked.
    @ViewBuilder
    private var allLiveSection: some View {
        if livePicks.isEmpty {
            nothingLive
        } else {
            HubSectionHead(title: t(.rd_in_play),
                           meta: t(.rd_n_live, count: livePicks.count),
                           live: true)
                .padding(.bottom, 10)
            LazyVStack(spacing: 8) {
                let visible = isPro ? livePicks
                                    : Array(livePicks.max(by: { $0.probability < $1.probability }).map { [$0] } ?? [])
                ForEach(visible) { p in
                    Button { onTapPick(p) } label: {
                        liveCard(pick: p, score: liveScore(for: p))
                    }.buttonStyle(.plain)
                }
                if !isPro {
                    let locked = livePicks.filter { p in
                        !visible.contains(where: { $0.id == p.id })
                    }
                    if !locked.isEmpty {
                        ProUnlockCard(lockedCount: locked.count, onUnlock: onUnlock)
                        ForEach(locked.prefix(3)) { p in
                            LockedPickCard(pick: p, onUnlock: onUnlock)
                        }
                    }
                }
            }
        }
    }

    /// "MY PICKS" — today's picks the user owns, grouped by render
    /// state (live → final → awaiting → upcoming). Filters use the
    /// same PickRenderState the card chrome uses, so a pick can't
    /// land in two sections at once or show in "Upcoming" when its
    /// game is actually over.
    @ViewBuilder
    private var myLiveAndRecentSection: some View {
        let myToday = vm.effectiveTodayPicks
        let stateOf: (Pick) -> PickRenderState = { p in
            p.renderState(liveScore: liveScore(for: p))
        }
        let myLive     = myToday.filter { stateOf($0) == .live }
        let mySettled  = myToday.filter { stateOf($0) == .won  || stateOf($0) == .lost }
        let myAwaiting = myToday.filter { stateOf($0) == .awaitingResult }
        let myUpcoming = myToday.filter { stateOf($0) == .upcoming }

        if myLive.isEmpty && mySettled.isEmpty
            && myAwaiting.isEmpty && myUpcoming.isEmpty {
            nothingLive
        } else {
            VStack(spacing: 16) {
                if !myLive.isEmpty {
                    section(title: t(.card_live),
                            meta: "\(myLive.count) IN PLAY",
                            live: true,
                            picks: myLive,
                            renderer: { liveCard(pick: $0, score: liveScore(for: $0)) })
                }
                if !mySettled.isEmpty {
                    section(title: t(.card_final),
                            meta: settledMetaToday(mySettled),
                            live: false,
                            picks: mySettled,
                            renderer: { settledCard(pick: $0) })
                }
                if !myAwaiting.isEmpty {
                    section(title: t(.card_awaiting),
                            meta: "\(myAwaiting.count) TO GRADE",
                            live: false,
                            picks: myAwaiting,
                            renderer: { settledCard(pick: $0) })
                }
                if !myUpcoming.isEmpty {
                    section(title: t(.live_section_upcoming),
                            meta: "\(myUpcoming.count) TODAY",
                            live: false,
                            picks: myUpcoming,
                            renderer: { liveCard(pick: $0, score: liveScore(for: $0)) })
                }
            }
        }
    }

    /// "FAVORITES" — every starred pick across the recent window
    /// (today + this week's settled + any pending that's live), with
    /// W/L badges so the user can scan past results too.
    @ViewBuilder
    private var favoritesRecentSection: some View {
        let favPicks = favoritePicks
        if favPicks.isEmpty {
            nothingFavs
        } else {
            HubSectionHead(title: t(.rd_favorites),
                           meta: t(.rd_n_saved, count: favPicks.count),
                           live: false)
                .padding(.bottom, 10)
            LazyVStack(spacing: 8) {
                ForEach(favPicks) { p in
                    Button { onTapPick(p) } label: {
                        if isLive(p) {
                            liveCard(pick: p, score: liveScore(for: p))
                        } else {
                            settledCard(pick: p)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    /// Generic section wrapper — header + LazyVStack of picks.
    @ViewBuilder
    private func section<R: View>(
        title: String, meta: String, live: Bool,
        picks: [Pick],
        @ViewBuilder renderer: @escaping (Pick) -> R
    ) -> some View {
        VStack(spacing: 8) {
            HubSectionHead(title: title, meta: meta, live: live)
                .padding(.bottom, 2)
                .padding(.horizontal, -16)   // cancel section's 16pt inset
            ForEach(picks) { p in
                Button { onTapPick(p) } label: {
                    renderer(p)
                }.buttonStyle(.plain)
            }
        }
    }

    private func settledMetaToday(_ picks: [Pick]) -> String {
        let w = picks.filter { $0.isWin }.count
        let l = picks.filter { $0.isLoss }.count
        return "\(w)-\(l) TODAY"
    }

    /// All favorited picks, newest first, scoped to the window the
    /// Live tab cares about (today + the 7-day rolling history).
    private var favoritePicks: [Pick] {
        let ids = favorites.ids
        var byId: [UUID: Pick] = [:]
        for p in vm.todayPicks      { byId[p.id] = p }
        for p in vm.yesterdayPicks  { byId[p.id] = p }
        for p in vm.historyPicks    { byId[p.id] = p }
        return ids.compactMap { byId[$0] }
            .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast)
                    > ($1.gameDate, $1.createdAt ?? Date.distantPast) }
    }

    /// Empty state for the Favorites sub-tab.
    private var nothingFavs: some View {
        VStack(spacing: 10) {
            Image(systemName: "star")
                .font(.system(size: 30))
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(t(.rd_no_saved_title))
                .font(.anton(20))
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text(t(.rd_no_saved_sub))
                .font(.archivo(12)).foregroundColor(Color(hex: "#6E6F75"))
        }
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity)
    }

    /// Wrapper around the WinsView outcomeCard pattern so the LiveView
    /// can render past favorites with the same W/L visual language.
    /// Forwards to a small inline implementation that's specific to
    /// this view's constraints (no remove-X, no FavoritesStore tie-in).
    @ViewBuilder
    private func settledCard(pick: Pick) -> some View {
        SettledOutcomeCard(pick: pick,
                           liveScore: liveScore(for: pick))
    }

    /// Single FAVORITES toggle — the only filter on the Live page.
    private var tabsRow: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                favoritesOnly.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: favoritesOnly ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .bold))
                    Text(t(.rd_favorites))
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.6)
                }
                .foregroundColor(favoritesOnly ? Color(hex: "#171717") : Color(hex: "#B9B7B0"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(favoritesOnly
                                           ? Color(hex: "#F5F3EE")
                                           : Color(hex: "#1D1D1D")))
                .overlay(Capsule().stroke(favoritesOnly
                                          ? Color(hex: "#F5F3EE")
                                          : Color(hex: "#2F2F2F"), lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    /// Lime-tinted next-up reminder banner. Only shows when there's a
    /// pick whose game tips off in the next ~60 minutes and isn't live.
    private func watchBanner(_ next: Pick) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(t(.rd_next_up)) · \(minutesUntil(next))")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Color(hex: "#C6FF34"))
                Text("\(teamShortName(next.homeTeam)) vs \(teamShortName(next.awayTeam))")
                    .font(.anton(20))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1)
                Text("\(next.league.uppercased()) · YOUR PICK: \(next.displayPick.uppercased())")
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .lineLimit(1)
            }
            Spacer()
            // "REMIND ME" pill removed for v1 — wiring local
            // notifications would require NSUserNotifications usage
            // strings + a permission prompt, neither of which we
            // ship today. The kickoff-time line above is enough
            // signal; the banner itself disappears once the game
            // is live.
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "#C6FF34").opacity(0.10),
                             Color(hex: "#C6FF34").opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#C6FF34").opacity(0.28), lineWidth: 1)
                )
        )
    }

    private var nextUpcomingPick: Pick? {
        // Closest upcoming pick (not currently live). Falls back to the
        // first non-live pick if we don't have a precise time.
        let upcoming = vm.todayPicks.filter { !isLive($0) }
        return upcoming.first
    }

    private func minutesUntil(_ pick: Pick) -> String {
        guard let date = pick.createdAt else { return "SOON" }
        let mins = max(0, Int(date.timeIntervalSinceNow / 60))
        if mins == 0 { return t(.rd_starting_now) }
        if mins < 60 { return "\(mins) MIN" }
        let h = mins / 60
        return "\(h)H \(mins % 60)M"
    }

    private var livePicks: [Pick] {
        vm.todayPicks.filter { isLive($0) }
    }

    private func liveScore(for pick: Pick) -> LiveScore? {
        guard let gid = pick.gameId else { return nil }
        return vm.liveScores.first { $0.gameId == gid }
    }
    private func isLive(_ p: Pick) -> Bool {
        liveScore(for: p)?.isLive == true
    }

    private var nothingLive: some View {
        VStack(spacing: 10) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(t(.rd_nothing_live))
                .font(.anton(22))
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text(t(.rd_nothing_live_sub))
                .font(.archivo(12, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
            if let next = nextUpcomingPick {
                Text("NEXT · \(next.localizedScheduleDisplay ?? "SOON")")
                    .font(.mono(10, weight: .bold)).tracking(1.1)
                    .foregroundColor(Color(hex: "#C6FF34"))
                    .padding(.top, 5)
            }
            Button {
                Analytics.emptyStateAction(screen: "live")
                onBrowsePicks()
            } label: {
                Text("BROWSE TODAY'S PICKS")
                    .font(.archivoNarrow(11, weight: .bold)).tracking(1.4)
                    .foregroundColor(Color(hex: "#171717"))
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(Color(hex: "#C6FF34")))
            }
            .buttonStyle(.plain)
            .padding(.top, 7)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity)
    }

    private func liveCard(pick: Pick, score: LiveScore?) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: "#FF5A36")).frame(width: 6, height: 6)
                    Text("\(t(.card_live)) · \(pick.league.uppercased())")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "#FF5A36"))
                }
                Spacer()
                if let s = score {
                    Text(s.quarter ?? s.status ?? "Q?")
                        .font(.mono(11, weight: .bold))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
            }
            .padding(.bottom, 12)
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                    Text(teamShortName(pick.awayTeam, sport: pick.sport))
                        .font(.anton(16))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                if let s = score, let h = s.homeScore, let a = s.awayScore {
                    // Winning team's score in white; the trailing team darker.
                    let winWhite = Color(hex: "#FFFFFF")
                    let loseDark = Color(hex: "#5C6069")
                    let tie      = Color(hex: "#B9B7B0")
                    HStack(spacing: 6) {
                        Text("\(a)")
                            .font(.anton(30))
                            .foregroundColor(a == h ? tie : (a > h ? winWhite : loseDark))
                        Text("–").font(.anton(16)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)")
                            .font(.anton(30))
                            .foregroundColor(a == h ? tie : (h > a ? winWhite : loseDark))
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("-").font(.anton(30)).foregroundColor(Color(hex: "#B9B7B0"))
                        Text("–").font(.anton(16)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("-").font(.anton(30)).foregroundColor(Color(hex: "#B9B7B0"))
                    }
                }
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam, sport: pick.sport))
                        .font(.anton(16))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            // Game-progress bar — 4pt lime fill that climbs with real elapsed
            // game time. TimelineView re-evaluates every 30s so it advances on
            // its own, not just when a score update arrives.
            TimelineView(.periodic(from: .now, by: 30)) { _ in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: "#2F2F2F"))
                        Capsule().fill(Color(hex: "#C6FF34"))
                            .frame(width: geo.size.width * gameProgress(score))
                            .animation(.easeOut(duration: 0.6), value: gameProgress(score))
                    }
                }
            }
            .frame(height: 4)
            .padding(.top, 12)

            HStack {
                Text(t(.rd_your_pick))
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.displayPick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                StatusPill(kind: statusKind(for: pick, score: score))
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                DashedLine()
                    .stroke(Color(hex: "#2F2F2F"),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
        }
        .padding(14)
        // 2026-07 redesign: the tinted receipt frame replaces the old
        // flat card + glowing side rail — same language as Latest Wins.
        .background(stateCardBackground(.live))
    }

    /// Approximates how far through the game we are (0.0 → 1.0). For
    /// sports with quarters/periods we read s.quarter; otherwise we
    /// fall back to a status heuristic.
    private func gameProgress(_ score: LiveScore?) -> CGFloat {
        guard let s = score else { return 0 }
        if (s.status ?? "").uppercased().contains("FINAL") { return 1.0 }
        guard s.isLive else { return 0.0 }
        // Primary: real wall-clock elapsed since kickoff over a typical game
        // length — so the bar climbs continuously as the game goes on.
        if let start = s.startTime {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > 0 {
                return max(0.04, min(0.97, CGFloat(elapsed / typicalGameDuration(s.sport))))
            }
        }
        // Fallback: period-based when we have a quarter but no usable start.
        if let qStr = s.quarter, let q = Int(qStr) {
            switch s.sport {
            case "basketball", "football": return min(0.95, CGFloat(q) * 0.25)
            case "hockey":                 return min(0.95, CGFloat(q) * 0.33)
            default:                       return min(0.95, CGFloat(q) * 0.25)
            }
        }
        return 0.5
    }

    /// Rough wall-clock length of a typical game per sport, used to map
    /// elapsed time → a 0…1 progress bar when there's no live clock feed.
    private func typicalGameDuration(_ sport: String) -> TimeInterval {
        switch sport {
        case "basketball": return 2.3 * 3600
        case "football":   return 3.1 * 3600
        case "soccer":     return 2.0 * 3600   // 90' + half-time + stoppage
        case "baseball":   return 3.1 * 3600
        case "hockey":     return 2.5 * 3600
        case "cricket":    return 3.6 * 3600   // T20
        case "f1":         return 2.0 * 3600
        case "combat":     return 1.5 * 3600
        default:           return 2.5 * 3600
        }
    }

    /// Helper to look up the pick that owns a given live_score row,
    /// for the gameProgress sport-aware switch above.
    private func pick(of score: LiveScore) -> Pick {
        vm.todayPicks.first(where: { $0.gameId == score.gameId })
            ?? vm.todayPicks.first
            ?? Pick(id: UUID(), createdAt: nil, sport: "basketball", league: "NBA",
                    gameDate: "", gameId: nil, homeTeam: "", awayTeam: "",
                    pick: "", probability: 0, confidence: "*", reasoning: "",
                    keyFactor: nil, matchupFacts: nil, result: "pending",
                    homeScore: nil, awayScore: nil,
                    marketOdds: nil, oddsSource: nil, predictedScore: nil,
                    homeLogo: nil, awayLogo: nil, fieldOdds: nil)
    }

    /// Status-pill 3-state classifier:
    /// .good = pick winning by ≥3 / .mid = winning by <3 or tied / .bad = trailing.
    private func statusKind(for pick: Pick, score: LiveScore?) -> StatusPill.Kind {
        guard let s = score, let h = s.homeScore, let a = s.awayScore else { return .mid }
        let pickedAway = pick.pick.lowercased().contains(pick.awayTeam.lowercased())
            || pick.awayTeam.lowercased().contains(pick.pick.lowercased())
        let pickScore = pickedAway ? a : h
        let oppScore  = pickedAway ? h : a
        let diff = pickScore - oppScore
        if diff >= 3 { return .good }
        if diff < 0  { return .bad }
        return .mid
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - All Picks (full list, used by Picks tab)
// ════════════════════════════════════════════════════════════════

struct AllPicksView: View {
    @ObservedObject var vm: PicksViewModel
    var isPro: Bool = true
    let onTapPick: (Pick) -> Void
    var onUnlock: () -> Void = {}

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                TopNavBar(crumb: t(.rd_crumb_today), crumbAccent: t(.nav_picks).uppercased(), live: false, onBack: {})
                PageHero(title: t(.rd_todays_word),
                         titleAccent: t(.rd_picks_word),
                         sub: [t(.rd_n_picks, count: vm.todayPicks.count), t(.rd_avg_conf, count: Int(avgConf))],
                         glow: Color(hex: "#C6FF34"))
                    .padding(.bottom, 18)
                SportFilter(vm: vm)
                    .padding(.bottom, 12)
                let visible = vm.visiblePicks(isPro: isPro)
                if visible.isEmpty {
                    Text(t(.rd_no_sport_picks))
                        .font(.archivo(12, weight: .regular))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .padding(.vertical, 60)
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(visible) { p in
                            Button { onTapPick(p) } label: {
                                CompactPickCard(pick: p, liveScore: liveScore(for: p))
                            }
                            .buttonStyle(.plain)
                        }
                        if !isPro && !vm.lockedTodayPicks.isEmpty {
                            ProUnlockCard(lockedCount: vm.lockedTodayPicks.count, onUnlock: onUnlock)
                            ForEach(vm.lockedTodayPicks.prefix(4)) { p in
                                LockedPickCard(pick: p, onUnlock: onUnlock)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Spacer().frame(height: 140)
            }
        }
    }

    private var avgConf: Double {
        let arr = vm.todayPicks.map { $0.probability }
        return arr.isEmpty ? 0 : arr.reduce(0, +) / Double(arr.count)
    }

    private func liveScore(for pick: Pick) -> LiveScore? {
        guard let gid = pick.gameId else { return nil }
        return vm.liveScores.first { $0.gameId == gid }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Language picker sheet
// ════════════════════════════════════════════════════════════════

/// Modal sheet listing the languages we offer. Tap one to set the
/// app's language preference and dismiss. Persists via the
/// `appLanguage` @AppStorage key on ProfileView. Localization wiring
/// happens at the app root once we ship localized string tables —
/// this sheet just records the user's choice.
struct LanguagePickerSheet: View {
    @Binding var selection: String
    @Binding var isOpen: Bool

    /// Live-translated UI labels — observed so the header text + Done
    /// button re-render the instant the user picks a new language
    /// without dismissing first.
    @Environment(LocalizationManager.self) private var loc

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(loc.t(.lang_picker_title))
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Spacer()
                    Button(loc.t(.action_done)) { isOpen = false }
                        .font(.archivo(13, weight: .bold))
                        .foregroundColor(Color(hex: "#C6FF34"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 18)

                // Language rows
                VStack(spacing: 0) {
                    ForEach(ProfileView.languages, id: \.code) { lang in
                        languageRow(lang)
                        if lang.code != ProfileView.languages.last?.code {
                            Rectangle()
                                .fill(Color(hex: "#2F2F2F"))
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(hex: "#1D1D1D"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22,
                                             style: .continuous)
                                .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                Spacer().frame(height: 40)
            }
        }
        .background(Color(hex: "#171717").ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func languageRow(_ lang: (code: String, name: String, native: String, flag: String)) -> some View {
        Button {
            // Push into both the AppStorage binding (for the trailing pill
            // on the settings row to update) AND the LocalizationManager
            // (which drives every t(...) lookup). Keeping the manager in
            // sync is what makes the change take effect mid-session.
            selection = lang.code
            loc.languageCode = lang.code
            Analytics.languageChanged(lang.code)
            isOpen = false
        } label: {
            HStack(spacing: 14) {
                // Flag tile — large emoji on a panel background. The
                // selected row gets a lime-tinted ring so the active
                // language reads at a glance.
                Text(lang.flag)
                    .font(.system(size: 22))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: "#232323"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selection == lang.code
                                    ? Color(hex: "#C6FF34").opacity(0.4)
                                    : Color(hex: "#2F2F2F"),
                                    lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.name)
                        .font(.archivo(13, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                    Text(lang.native)
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                Spacer()
                // Trailing: code pill always visible (so the user can
                // map flag → BCP-47 code), checkmark on the active row.
                Text(lang.code.uppercased())
                    .font(.mono(10, weight: .heavy))
                    .foregroundColor(selection == lang.code
                                     ? Color(hex: "#C6FF34")
                                     : Color(hex: "#6E6F75"))
                if selection == lang.code {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(Color(hex: "#C6FF34"))
                }
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Privacy & Security sheet
// ════════════════════════════════════════════════════════════════

/// Modal sheet for account security: shows the email used to sign
/// in (read-only — it's the credential), the current sign-in method,
/// and a Change Password form. Pick6 sign-in is passwordless by
/// default (email OTP / Sign in with Apple), but Supabase lets the
/// user attach a password as an additional auth path.
struct PrivacySecuritySheet: View {
    @Environment(AuthManager.self) private var auth
    @Binding var isOpen: Bool

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var saving: Bool = false
    @State private var localError: String?
    @State private var didSave: Bool = false

    private var canSave: Bool {
        newPassword.count >= 8
            && newPassword == confirmPassword
            && !saving
    }

    var body: some View {
        ZStack {
            Color(hex: "#07080a").ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sheetHeader
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 22)

                    // ── Account section ──────────────────────────
                    fieldLabel(t(.settings_account_section))
                    VStack(spacing: 0) {
                        infoRow(icon: "envelope.fill",
                                title: "Email",
                                value: auth.userEmail ?? "—")
                        Rectangle()
                            .fill(Color(hex: "#2F2F2F"))
                            .frame(height: 1)
                            .padding(.leading, 56)
                        infoRow(icon: "key.fill",
                                title: "Sign-in method",
                                value: "Magic link (one-time code)")
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#1D1D1D"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)

                    // ── Change password section ──────────────────
                    fieldLabel(t(.rd_profile_change_password))
                    Text(t(.rd_profile_password_help))
                        .font(.archivo(11, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)

                    passwordField($newPassword,
                                  placeholder: "New password",
                                  icon: "lock.fill")
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)
                    passwordField($confirmPassword,
                                  placeholder: "Confirm new password",
                                  icon: "lock.rotation")
                        .padding(.horizontal, 18)
                        .padding(.bottom, 6)

                    if !newPassword.isEmpty && newPassword.count < 8 {
                        helper("Password must be at least 8 characters.",
                               color: Color(hex: "#FF5A36"))
                    } else if !confirmPassword.isEmpty
                                && newPassword != confirmPassword {
                        helper("Passwords don't match.",
                               color: Color(hex: "#FF5A36"))
                    } else if didSave {
                        helper("Password updated.",
                               color: Color(hex: "#4ade80"))
                    }
                    if let err = localError ?? auth.error {
                        helper(err, color: Color(hex: "#FF5A36"))
                    }

                    Button(action: save) {
                        Group {
                            if saving {
                                ProgressView().tint(Color(hex: "#171717"))
                            } else {
                                Text(didSave ? "Update Password" : "Set Password")
                                    .font(.archivo(14, weight: .heavy))
                            }
                        }
                        .foregroundColor(Color(hex: "#171717"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSave ? Color(hex: "#C6FF34")
                                              : Color(hex: "#3A3A3A"))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        saving = true
        localError = nil
        didSave = false
        Task {
            await auth.updatePassword(newPassword)
            saving = false
            if auth.error == nil {
                didSave = true
                newPassword = ""
                confirmPassword = ""
            } else {
                localError = auth.error
            }
        }
    }

    private var sheetHeader: some View {
        HStack {
            Button { isOpen = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#1D1D1D"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            Spacer()
            Text(t(.settings_privacy_security))
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#B9B7B0"))
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.archivoNarrow(10, weight: .bold))
            .tracking(2.2)
            .foregroundColor(Color(hex: "#6E6F75"))
            .padding(.horizontal, 22)
            .padding(.bottom, 6)
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#C6FF34"))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#232323"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.archivo(13, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text(value)
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
    }

    private func passwordField(_ text: Binding<String>, placeholder: String,
                                icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#C6FF34"))
            SecureField("", text: text, prompt:
                Text(placeholder).foregroundColor(Color(hex: "#6E6F75")))
                .font(.archivo(14, weight: .medium))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .textContentType(.newPassword)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#1D1D1D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                )
        )
    }

    private func helper(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.archivo(11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 22)
            .padding(.top, 4)
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Legal sheet (Terms / Privacy)
// ════════════════════════════════════════════════════════════════

/// Renders a bundled legal markdown file (TERMS_OF_SERVICE.md or
/// PRIVACY_POLICY.md from the app's Resources directory) inside a
/// scrollable sheet. Falls back to a graceful "couldn't load"
/// message if the file isn't shipped (shouldn't happen in release).
struct LegalSheet: View {
    enum Document {
        case terms, privacy
        var title: String {
            switch self {
            case .terms:   return "TERMS OF SERVICE"
            case .privacy: return "PRIVACY POLICY"
            }
        }
        var fileName: String {
            switch self {
            case .terms:   return "TERMS_OF_SERVICE"
            case .privacy: return "PRIVACY_POLICY"
            }
        }
    }

    let doc: Document
    @Binding var isOpen: Bool

    var body: some View {
        ZStack {
            Color(hex: "#07080a").ignoresSafeArea()
            VStack(spacing: 0) {
                sheetHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let body = bodyText {
                            Text(.init(body))
                                .font(.archivo(13, weight: .regular))
                                .foregroundColor(Color(hex: "#B9B7B0"))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("\(t(.rd_legal_load_pre))\(doc.title.lowercased())\(t(.rd_legal_load_post))")
                                .font(.archivo(13, weight: .medium))
                                .foregroundColor(Color(hex: "#6E6F75"))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var bodyText: String? {
        guard let url = Bundle.main.url(forResource: doc.fileName,
                                         withExtension: "md")
        else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private var sheetHeader: some View {
        HStack {
            Button { isOpen = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#1D1D1D"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            Spacer()
            Text(doc.title)
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#B9B7B0"))
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Edit Profile sheet
// ════════════════════════════════════════════════════════════════

/// Modal sheet that lets users see + edit their profile data. Backed
/// by `AuthManager.saveProfile`, which upserts the row in Pick1's
/// `profiles` table. Email is shown but not editable here — it's
/// tied to the Apple ID / OTP-verified address.
struct EditProfileSheet: View {
    let auth: AuthManager
    @Binding var isOpen: Bool
    /// Fired when the user confirms account deletion. The host
    /// (ProfileView) signs the user out and returns them to the
    /// auth flow. Nil-able so the sheet can be presented without
    /// the delete affordance in contexts where it doesn't apply.
    var onDeleteAccount: (() -> Void)? = nil

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var saving: Bool = false
    @State private var localError: String?
    @State private var showDeleteAccount: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "#07080a").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sheetHeader
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 22)

                    // Avatar preview
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#C6FF34"), Color(hex: "#a8e000")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .shadow(color: Color(hex: "#C6FF34").opacity(0.3), radius: 14, x: 0, y: 12)
                            Text(initialPreview)
                                .font(.anton(46))
                                .foregroundColor(Color(hex: "#171717"))
                        }
                        .frame(width: 100, height: 100)
                        Spacer()
                    }
                    .padding(.bottom, 28)

                    // Email — read-only
                    fieldLabel(t(.rd_profile_email_label))
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Color(hex: "#6E6F75"))
                        Text(auth.userEmail ?? "—")
                            .font(.archivo(14, weight: .medium))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                            .lineLimit(1)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#1D1D1D"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                    // First / Last name
                    fieldLabel(t(.profile_first_name))
                    profileField(text: $firstName, placeholder: "First name", icon: "person.fill")
                    fieldLabel(t(.profile_last_name))
                    profileField(text: $lastName, placeholder: "Last name", icon: "person.fill")

                    // Phone
                    fieldLabel(t(.rd_profile_phone_label))
                    profileField(text: $phone, placeholder: "+1 (555) 555-1234",
                                 icon: "phone.fill", keyboard: .phonePad)

                    // DOB
                    fieldLabel(t(.profile_dob))
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(Color(hex: "#C6FF34"))
                        DatePicker("", selection: $dob,
                                   in: ...Date(),
                                   displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .datePickerStyle(.compact)
                            .accentColor(Color(hex: "#C6FF34"))
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#1D1D1D"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                    if let err = localError ?? auth.error {
                        Text(err)
                            .font(.archivo(12, weight: .regular))
                            .foregroundColor(Color(hex: "#FF5A36"))
                            .padding(.horizontal, 18)
                            .padding(.bottom, 8)
                    }

                    // Save CTA
                    Button(action: save) {
                        Group {
                            if saving {
                                ProgressView().tint(Color(hex: "#171717"))
                            } else {
                                Text(t(.rd_save_changes))
                                    .font(.archivo(14, weight: .heavy))
                            }
                        }
                        .foregroundColor(Color(hex: "#171717"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSave ? Color(hex: "#C6FF34") : Color(hex: "#3A3A3A"))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave || saving)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)

                    // ── DANGER ZONE — Delete Account ──────────────
                    // Mandatory for any iOS app with auth (Apple
                    // guideline 5.1.1(v) since iOS 14.5). Lives in
                    // the profile-info sheet alongside other
                    // identity actions so the support/help section
                    // stays focused on help rather than mixing
                    // destructive operations in.
                    if onDeleteAccount != nil {
                        Rectangle()
                            .fill(Color(hex: "#2F2F2F"))
                            .frame(height: 1)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 18)

                        deleteAccountRow
                            .padding(.horizontal, 18)
                            .padding(.bottom, 30)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            firstName = auth.firstName ?? ""
            lastName  = auth.lastName  ?? ""
            phone     = auth.whatsapp  ?? ""
        }
        .alert(LocalizationManager.shared.t(.profile_delete_alert_title), isPresented: $showDeleteAccount) {
            Button(LocalizationManager.shared.t(.action_cancel), role: .cancel) {}
            Button(LocalizationManager.shared.t(.profile_delete_alert_confirm), role: .destructive) {
                isOpen = false
                onDeleteAccount?()
            }
        } message: {
            Text(LocalizationManager.shared.t(.profile_delete_alert_message))
        }
    }

    private var deleteAccountRow: some View {
        Button {
            showDeleteAccount = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#FF5A36"))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: "#232323"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(t(.profile_delete_account))
                        .font(.archivo(13, weight: .semibold))
                        .foregroundColor(Color(hex: "#FF5A36"))
                    Text(t(.rd_delete_subtitle))
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#1D1D1D"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#FF5A36").opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var sheetHeader: some View {
        HStack {
            Button { isOpen = false } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#1D1D1D"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            Spacer()
            Text(t(.profile_edit_title))
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#B9B7B0"))
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.archivoNarrow(10, weight: .bold))
            .tracking(2.2)
            .foregroundColor(Color(hex: "#6E6F75"))
            .padding(.horizontal, 22)
            .padding(.bottom, 6)
    }

    private func profileField(text: Binding<String>, placeholder: String,
                              icon: String,
                              keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#C6FF34"))
            TextField("", text: text, prompt:
                Text(placeholder).foregroundColor(Color(hex: "#6E6F75")))
                .font(.archivo(14, weight: .medium))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(keyboard == .phonePad ? .never : .words)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#1D1D1D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#2F2F2F"), lineWidth: 1)
                )
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var initialPreview: String {
        if let c = firstName.first { return String(c).uppercased() }
        if let e = auth.userEmail, let c = e.first { return String(c).uppercased() }
        return "P"
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard canSave else { return }
        saving = true
        localError = nil
        Task {
            await auth.saveProfile(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName:  lastName.trimmingCharacters(in: .whitespaces),
                whatsapp:  phone.trimmingCharacters(in: .whitespaces),
                dateOfBirth: dob
            )
            saving = false
            if auth.error == nil {
                isOpen = false
            } else {
                localError = auth.error
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Match Detail support models + per-sport data
// ════════════════════════════════════════════════════════════════

/// One tile in the stat-icon row above the pick-hero card.
/// (Renamed from `StatTile` to avoid colliding with the SwiftUI
/// `StatTile` View used on the Profile → Stats tab.)
struct MatchStatTile {
    let icon: String
    let label: String
    let value: String
}

/// One row in the MATCH STATS card (horizontal bar with home/away values).
struct StatRow {
    let label: String
    let homeText: String
    let awayText: String
    let homePct: Double
}

/// Per-sport stat tiles for the icon row. Tile 0 always renders in the
/// lime "active" state per design. Values are reasonable defaults until
/// we wire a real boxscore feed — the design's spec values are already
/// stylized fixtures.
enum StatTiles {
    static func tiles(for sport: String, liveScore: LiveScore?) -> [MatchStatTile] {
        switch sport {
        case "basketball":
            return [
                .init(icon: "scope",                  label: "POINTS",  value: "88-91"),
                .init(icon: "circle.dashed",          label: "3-PT",    value: "11-13"),
                .init(icon: "arrow.up.and.down",      label: "REB",     value: "38-42"),
                .init(icon: "arrowshape.turn.up.right", label: "AST",   value: "21-25"),
                .init(icon: "arrow.uturn.backward",   label: "TO",      value: "9-7"),
                .init(icon: "person.3.fill",          label: "BENCH",   value: "24-31"),
            ]
        case "football":
            return [
                .init(icon: "chart.line.uptrend.xyaxis", label: "PROJ",    value: "27-24"),
                .init(icon: "scope",                     label: "TD %",   value: "68-64"),
                .init(icon: "ruler",                     label: "YDS/G",   value: "387"),
                .init(icon: "exclamationmark.shield",    label: "SACKS",   value: "3.2"),
                .init(icon: "cross.case",                label: "INJ",     value: "2-3"),
            ]
        case "baseball":
            return [
                .init(icon: "circle.fill",        label: "HITS",    value: "8-7"),
                .init(icon: "arrow.up.right.circle", label: "HR",   value: "2-1"),
                .init(icon: "xmark.circle",       label: "K",       value: "6-8"),
                .init(icon: "arrow.right.circle", label: "BASES",   value: "2-1"),
                .init(icon: "figure.walk",        label: "WALKS",   value: "3-2"),
                .init(icon: "exclamationmark.circle", label: "ERR", value: "0-1"),
            ]
        case "hockey":
            return [
                .init(icon: "scope",              label: "GOALS",   value: "3-2"),
                .init(icon: "target",             label: "SHOTS",   value: "28-24"),
                .init(icon: "shield.fill",        label: "SAVES",   value: "22-25"),
                .init(icon: "bolt.fill",          label: "PP G",    value: "1-0"),
                .init(icon: "exclamationmark.circle", label: "PIM", value: "6-10"),
                .init(icon: "figure.hockey",      label: "HITS",    value: "18-22"),
            ]
        case "soccer":
            return [
                .init(icon: "soccerball",         label: "GOALS",   value: "2-1"),
                .init(icon: "square.fill",        label: "YEL",     value: "3-2"),
                .init(icon: "square.fill",        label: "RED",     value: "0-1"),
                .init(icon: "flag.fill",          label: "CORNERS", value: "6-4"),
                .init(icon: "scope",              label: "PEN",     value: "1-0"),
                .init(icon: "person.2.fill",      label: "SUBS",    value: "2-3"),
            ]
        case "combat":
            return [
                .init(icon: "bolt.fill",          label: "STR/M",   value: "6.1-5.4"),
                .init(icon: "scope",              label: "ACC",     value: "58-51%"),
                .init(icon: "arrow.down.forward", label: "TD AVG",  value: "0.3-2.4"),
                .init(icon: "flame.fill",         label: "KO %",    value: "65-47%"),
                .init(icon: "ruler",              label: "REACH",   value: "79-75\""),
            ]
        case "f1":
            return [
                .init(icon: "1.circle.fill",      label: "POS",      value: "P1"),
                .init(icon: "stopwatch",          label: "FAST LAP", value: "1:12.4"),
                .init(icon: "wrench.fill",        label: "PIT",      value: "1-1"),
                .init(icon: "arrow.left.arrow.right", label: "GAP",  value: "+1.24"),
                .init(icon: "circle.grid.2x2",    label: "TYRES",    value: "MED"),
            ]
        case "cricket":
            return [
                .init(icon: "scope",              label: "RUNS",    value: "142-178"),
                .init(icon: "xmark.circle",       label: "WICKETS", value: "4-10"),
                .init(icon: "stopwatch",          label: "OVERS",   value: "14.3"),
                .init(icon: "arrow.up.circle",    label: "SIXES",   value: "7-9"),
                .init(icon: "rectangle.portrait", label: "FOURS",   value: "12-14"),
                .init(icon: "speedometer",        label: "RR",      value: "9.8/9.0"),
            ]
        default:
            return [
                .init(icon: "chart.bar.fill",  label: "FORM",   value: "8-2"),
                .init(icon: "flame.fill",      label: "STREAK", value: "+5"),
                .init(icon: "bolt.fill",       label: "PACE",   value: "108.4"),
                .init(icon: "person.fill",     label: "ROSTER", value: "FULL"),
            ]
        }
    }
}

/// Per-sport horizontal bar rows for the MATCH STATS card. Static
/// fixtures until a real boxscore feed is wired.
enum BarSet {
    static func bars(for sport: String) -> [StatRow] {
        switch sport {
        case "basketball":
            return [
                .init(label: "FG %",       homeText: "47%", awayText: "44%", homePct: 0.52),
                .init(label: "3-PT %",     homeText: "38%", awayText: "33%", homePct: 0.54),
                .init(label: "REBOUNDS",   homeText: "42",  awayText: "38",  homePct: 0.53),
                .init(label: "ASSISTS",    homeText: "25",  awayText: "21",  homePct: 0.54),
                .init(label: "TURNOVERS",  homeText: "7",   awayText: "9",   homePct: 0.44),
            ]
        case "football":
            return [
                .init(label: "OFF YDS/G",  homeText: "387", awayText: "352", homePct: 0.52),
                .init(label: "PPG",        homeText: "27",  awayText: "24",  homePct: 0.53),
                .init(label: "DEF YDS",    homeText: "318", awayText: "342", homePct: 0.48),
                .init(label: "TURNOVER ±", homeText: "+8",  awayText: "+3",  homePct: 0.55),
                .init(label: "3RD DOWN %", homeText: "44%", awayText: "39%", homePct: 0.53),
            ]
        case "baseball":
            return [
                .init(label: "HITS",       homeText: "8",   awayText: "7",   homePct: 0.53),
                .init(label: "RBI",        homeText: "5",   awayText: "4",   homePct: 0.55),
                .init(label: "OBP",        homeText: ".380", awayText: ".342", homePct: 0.53),
                .init(label: "LOB",        homeText: "6",   awayText: "8",   homePct: 0.43),
                .init(label: "PITCHES",    homeText: "94",  awayText: "108", homePct: 0.46),
            ]
        case "hockey":
            return [
                .init(label: "SHOTS",      homeText: "28",  awayText: "24",  homePct: 0.54),
                .init(label: "SAVE %",     homeText: ".920", awayText: ".895", homePct: 0.51),
                .init(label: "FACEOFF %",  homeText: "54%", awayText: "46%", homePct: 0.54),
                .init(label: "HITS",       homeText: "22",  awayText: "18",  homePct: 0.55),
                .init(label: "PP %",       homeText: "33%", awayText: "20%", homePct: 0.62),
            ]
        case "soccer":
            return [
                .init(label: "POSSESSION", homeText: "54%", awayText: "46%", homePct: 0.54),
                .init(label: "SHOTS",      homeText: "12",  awayText: "9",   homePct: 0.57),
                .init(label: "ON TARGET",  homeText: "5",   awayText: "3",   homePct: 0.62),
                .init(label: "PASS ACC",   homeText: "88%", awayText: "84%", homePct: 0.51),
            ]
        case "combat":
            return [
                .init(label: "STR/MIN",    homeText: "6.1", awayText: "5.4", homePct: 0.53),
                .init(label: "STR ACC",    homeText: "58%", awayText: "51%", homePct: 0.53),
                .init(label: "STR DEF",    homeText: "62%", awayText: "57%", homePct: 0.52),
                .init(label: "TD DEF",     homeText: "82%", awayText: "68%", homePct: 0.55),
                .init(label: "KO WINS",    homeText: "11",  awayText: "8",   homePct: 0.58),
            ]
        case "f1":
            return [
                .init(label: "AVG LAP",    homeText: "1:12.4", awayText: "1:12.7", homePct: 0.51),
                .init(label: "TOP SPEED",  homeText: "338",    awayText: "335",    homePct: 0.51),
                .init(label: "QUALI POS",  homeText: "P1",     awayText: "P2",     homePct: 0.55),
                .init(label: "SECTOR 1",   homeText: "23.1",   awayText: "23.4",   homePct: 0.51),
                .init(label: "TYRE LIFE",  homeText: "MED",    awayText: "HARD",   homePct: 0.50),
            ]
        case "cricket":
            return [
                .init(label: "RUNS",       homeText: "142",  awayText: "178",  homePct: 0.44),
                .init(label: "RUN RATE",   homeText: "9.8",  awayText: "9.0",  homePct: 0.52),
                .init(label: "BOUNDARY %", homeText: "42%",  awayText: "38%",  homePct: 0.52),
                .init(label: "DOT BALL %", homeText: "31%",  awayText: "36%",  homePct: 0.46),
                .init(label: "WICKETS",    homeText: "4",    awayText: "10",   homePct: 0.55),
            ]
        default:
            return [
                .init(label: "POSSESSION", homeText: "54%", awayText: "46%", homePct: 0.54),
                .init(label: "SHOTS",      homeText: "12",  awayText: "9",   homePct: 0.57),
                .init(label: "PASS ACC",   homeText: "88%", awayText: "84%", homePct: 0.51),
                .init(label: "CORNERS",    homeText: "6",   awayText: "4",   homePct: 0.60),
            ]
        }
    }
}


// ════════════════════════════════════════════════════════════════
// MARK: - SettledOutcomeCard
// ════════════════════════════════════════════════════════════════

/// Standalone card that renders a pick's outcome state — WIN / LOSS /
/// LIVE / UPCOMING — with score row + colored badge. Mirrors the
/// in-WinsView wonCard visual but lives at module scope so any view
/// (LiveView's Favorites tab, future Picks-tab variants) can render
/// it without depending on private helpers.
struct SettledOutcomeCard: View {
    let pick: Pick
    let liveScore: LiveScore?

    var body: some View {
        // Single source of truth — every per-card rendering decision
        // (badge, top tag, score row, strikethrough) derives from
        // this state.
        let state = pick.renderState(liveScore: liveScore)
        let isFinal = state == .won || state == .lost

        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
        let pickedAway = pick.pick.lowercased().contains(pick.awayTeam.lowercased())
        let homeStrike = state == .lost
            ? pickedHome
            : (state == .won && !pickedAway && (pick.homeScore ?? 0) < (pick.awayScore ?? 0))
        let awayStrike = state == .lost
            ? pickedAway
            : (state == .won && !pickedHome && (pick.awayScore ?? 0) < (pick.homeScore ?? 0))

        let topTag: String = {
            switch state {
            case .live:
                let q = liveScore?.quarter.flatMap { Int($0) }
                    .map { "Q\($0)" } ?? "LIVE"
                return "\(pick.league.uppercased()) · LIVE · \(q)"
            case .won, .lost:
                return "\(pick.league.uppercased()) · FINAL"
            case .awaitingResult:
                return "\(pick.league.uppercased()) · AWAITING"
            case .upcoming:
                return "\(pick.league.uppercased()) · UPCOMING"
            }
        }()

        return VStack(spacing: 0) {
            HStack {
                Text(topTag)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Spacer()
                badge(state: state)
            }
            .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 9) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam, sport: pick.sport))
                        .font(.anton(18))
                        .foregroundColor(homeStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(homeStrike, color: Color(hex: "#3A3A3A"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if state == .live,
                       let s = liveScore, let h = s.homeScore, let a = s.awayScore {
                        score(h: h, a: a, hMute: false, aMute: false, accent: Color(hex: "#FF5A36"))
                    } else if isFinal,
                              let h = pick.homeScore, let a = pick.awayScore {
                        score(h: h, a: a, hMute: homeStrike, aMute: awayStrike, accent: Color(hex: "#F5F3EE"))
                    } else {
                        Text("VS").font(.archivoNarrow(11, weight: .bold))
                            .tracking(2).foregroundColor(Color(hex: "#6E6F75"))
                    }
                }

                HStack(spacing: 9) {
                    Text(teamShortName(pick.awayTeam, sport: pick.sport))
                        .font(.anton(18))
                        .foregroundColor(awayStrike ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(awayStrike, color: Color(hex: "#3A3A3A"))
                        .lineLimit(1)
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Text(t(.rd_ai_pick))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.displayPick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                if state == .won {
                    Text("$100 → $\(Int((pick.decimalOdds * 100).rounded()))")
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#C6FF34"))
                } else {
                    Text(pick.keyFactor ?? pick.league.uppercased())
                        .font(.mono(10, weight: .medium))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .lineLimit(1)
                }
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                DashedLine()
                    .stroke(Color(hex: "#2F2F2F"),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
        }
        .padding(14)
        .background(stateCardBackground(state))
    }

    @ViewBuilder
    private func badge(state: PickRenderState) -> some View {
        switch state {
        case .live:
            HStack(spacing: 5) {
                Circle().fill(Color(hex: "#FF5A36")).frame(width: 6, height: 6)
                Text(t(.card_live)).font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#FF5A36"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#FF5A36").opacity(0.10))
            .overlay(Capsule().stroke(Color(hex: "#FF5A36").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .won:
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy))
                Text(t(.rd_won)).font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#C6FF34"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#C6FF34").opacity(0.10))
            .overlay(Capsule().stroke(Color(hex: "#C6FF34").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .lost:
            HStack(spacing: 5) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .heavy))
                Text(t(.rd_lost)).font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#FF5A5A"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#FF5A5A").opacity(0.10))
            .overlay(Capsule().stroke(Color(hex: "#FF5A5A").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .awaitingResult:
            // Past kickoff, pipeline hasn't graded yet. Mute amber
            // capsule — not a "this hasn't happened yet" UPCOMING.
            HStack(spacing: 5) {
                Image(systemName: "hourglass")
                    .font(.system(size: 9, weight: .heavy))
                Text(t(.card_awaiting))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
            }
            .foregroundColor(Color(hex: "#B98C40"))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: "#B98C40").opacity(0.10))
            .overlay(Capsule().stroke(Color(hex: "#B98C40").opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
        case .upcoming:
            Text(t(.live_section_upcoming))
                .font(.archivoNarrow(9, weight: .bold)).tracking(1.8)
                .foregroundColor(Color(hex: "#6E6F75"))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color(hex: "#232323"))
                .overlay(Capsule().stroke(Color(hex: "#2F2F2F"), lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    private func score(h: Int, a: Int, hMute: Bool, aMute: Bool,
                       accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(h)").font(.anton(24)).fontWeight(.black)
                .foregroundColor(hMute ? Color(hex: "#6E6F75") : accent)
            Text("–").font(.anton(14)).foregroundColor(Color(hex: "#6E6F75"))
            Text("\(a)").font(.anton(24)).fontWeight(.black)
                .foregroundColor(aMute ? Color(hex: "#6E6F75") : accent)
        }
    }
}
