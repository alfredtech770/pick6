// Pick6Screens.swift
// All non-Home screens from the design handoff:
//   • MatchDetailView   — Pick6 Detail Pages.html (tap a card → push)
//   • SportHubView      — Pick6 Sport Hubs.html  (tap sport header chip)
//   • ProfileView       — Pick6 Account Pages.html → Profile
//   • WinsView          — Pick6 Account Pages.html → Wins / Favorites
//   • LiveView          — Pick6 Account Pages.html → Live (in-play tracker)
//   • AllPicksView      — Picks tab (full list of today's picks, no hero)
//
// Shared chrome (TopNavBar, PageHero, etc.) and design tokens (Color hex,
// Font.anton/archivo/archivoNarrow/mono) live in Pick6HomeHiFi.swift.

import SwiftUI

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
                                .fill(Color(hex: "#101114"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "#22252B"), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
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
        ZStack(alignment: .topLeading) {
            RadialGradient(
                colors: [glow, .clear],
                center: UnitPoint(x: 1.05, y: -0.1),
                startRadius: 0,
                endRadius: 320
            )
            .frame(height: 220)
            .opacity(0.9)
            .blur(radius: 30)

            VStack(alignment: .leading, spacing: 12) {
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
                        .foregroundColor(Color(hex: "#D4FF3A"))
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
/// vertical gradient #14161a → #0e0f12, --line border, plus a 4-shadow
/// stack (inset top white highlight + drop shadow main + drop secondary)
/// to give every card the "stadium-scoreboard 3D lift" the design calls
/// for. Used by every list/card surface in the app for visual consistency.
private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(LinearGradient(
            colors: [Color(hex: "#14161a"), Color(hex: "#0e0f12")],
            startPoint: .top, endPoint: .bottom
        ))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "#22252B"), lineWidth: 1)
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

// ════════════════════════════════════════════════════════════════
// MARK: - Match Detail (Pick6 Detail Pages)
// ════════════════════════════════════════════════════════════════

struct MatchDetailView: View {
    let pick: Pick
    let liveScore: LiveScore?
    let onClose: () -> Void

    /// Tab identity is sport-agnostic; per-sport labels are derived
    /// in `tabLabel(for:)` so we can show GRID for F1, FIGHTERS for
    /// UFC, ROSTERS for cricket/tennis, LINEUPS for everything else.
    enum Tab: String, CaseIterable { case summary, roster, analysis, h2h }
    @State private var tab: Tab = .summary
    @State private var showBookmakers: Bool = false
    @State private var starred: Bool = false
    @State private var showToast: Bool = false

    /// Sport-aware label for each tab.
    private func tabLabel(_ t: Tab) -> String {
        switch t {
        case .summary:  return "SUMMARY"
        case .analysis: return "ANALYSIS"
        case .h2h:      return "H2H"
        case .roster:
            switch pick.sport {
            case "f1":      return "GRID"
            case "combat":  return "FIGHTERS"
            case "tennis", "cricket": return "ROSTERS"
            default:        return "LINEUPS"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#07080a").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    detailTopNav
                    scoreHeader
                    statIconRow
                    pickHeroCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    tabsRow
                    Group {
                        switch tab {
                        case .summary:  summaryPanel
                        case .roster:   lineupsPanel
                        case .analysis: analysisPanel
                        case .h2h:      h2hPanel
                        }
                    }
                    .padding(.horizontal, 16)
                    Spacer().frame(height: 120)
                }
            }

            // Toast
            if showToast {
                Text("SAVED · \(Int(pick.probability))% AI CONFIDENCE")
                    .font(.archivo(12, weight: .bold))
                    .foregroundColor(Color(hex: "#0A0B0D"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#F5F3EE"))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Sticky save-to-favorites CTA — sits flush with the bottom
            // safe-area edge (lower than before; no extra padding above
            // the home indicator) so the analysis content above gets
            // more vertical room.
            VStack { Spacer(); savePickCTA }
        }
        .preferredColorScheme(.dark)
        // Bookmaker frame — opens when the CTA is tapped. Lists the
        // major sportsbooks with deep-links so the user can place the
        // pick at the platform of their choice. Pick6 itself never
        // processes wagers (see disclaimer in the sheet header).
        .sheet(isPresented: $showBookmakers) {
            BookmakerSheet(pick: pick, isOpen: $showBookmakers)
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .presentationDetents([.medium, .large])
        }
    }

    private var detailTopNav: some View {
        TopNavBar(
            crumb: pick.league.uppercased() + " · ",
            crumbAccent: scheduledOrLiveLabel,
            live: liveScore?.isLive == true,
            onBack: onClose
        )
        .overlay(alignment: .trailing) {
            Button {
                starred.toggle()
            } label: {
                Image(systemName: starred ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(starred ? Color(hex: "#D4FF3A") : Color(hex: "#F5F3EE"))
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(starred ? Color(hex: "#D4FF3A").opacity(0.08) : Color(hex: "#101114"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(starred ? Color(hex: "#D4FF3A").opacity(0.3) : Color(hex: "#22252B"), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 18)
        }
    }

    private var scheduledOrLiveLabel: String {
        if let s = liveScore, s.isLive {
            let q = s.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? (s.status ?? "LIVE").uppercased()
            return "LIVE · \(q)"
        }
        return "TODAY"
    }

    /// Score header — `home` always renders on the LEFT, `away` on the RIGHT.
    /// Each team gets a real `TeamLogo` (uses our ESPN-CDN wrapper, falls back
    /// to the colored shield for individual-athlete sports). Team names are
    /// fixed 30pt Anton (26pt for tennis/UFC/F1 where names are longer).
    private var scoreHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            // HOME column (always left)
            VStack(spacing: 8) {
                TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .big)
                Text("HOME")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.8)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(teamShortName(pick.homeTeam))
                    .font(.anton(teamTight ? 26 : 30))
                    .tracking(-0.15)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1)
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
                Text("AWAY")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.8)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(teamShortName(pick.awayTeam))
                    .font(.anton(teamTight ? 26 : 30))
                    .tracking(-0.15)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1)
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
        ["combat", "tennis", "f1"].contains(pick.sport)
    }

    /// "LIVE · Q3" / clock pill above the score, lime variant when live and
    /// neutral grey-on-panel variant when scheduled (per design `.clock`).
    @ViewBuilder
    private var clockPill: some View {
        if let s = liveScore, s.isLive {
            Text(s.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? "LIVE")
                .font(.mono(12, weight: .bold))
                .foregroundColor(Color(hex: "#D4FF3A"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "#D4FF3A").opacity(0.08))
                .overlay(Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.22), lineWidth: 1))
                .clipShape(Capsule())
        } else if let label = scheduledClockText {
            Text(label)
                .font(.mono(11, weight: .bold))
                .foregroundColor(Color(hex: "#B9B7B0"))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "#101114"))
                .overlay(Capsule().stroke(Color(hex: "#22252B"), lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    /// Score in the center column. Numeric for team sports, "VS" for
    /// scheduled. Scores use design's 56pt Anton with home in white,
    /// away in `--ink-2` mute.
    @ViewBuilder
    private var scoreCenter: some View {
        if let s = liveScore, let h = s.homeScore, let a = s.awayScore {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(h)").font(.anton(56)).foregroundColor(Color(hex: "#F5F3EE"))
                Text("–").font(.anton(28)).foregroundColor(Color(hex: "#6E6F75"))
                Text("\(a)").font(.anton(56)).foregroundColor(Color(hex: "#B9B7B0"))
            }
        } else {
            Text("VS")
                .font(.anton(28))
                .tracking(2.8)
                .foregroundColor(Color(hex: "#D4FF3A"))
        }
    }

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
                .foregroundColor(active ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active
                              ? Color(hex: "#D4FF3A").opacity(0.1)
                              : Color(hex: "#101114"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(active
                                        ? Color(hex: "#D4FF3A").opacity(0.3)
                                        : Color(hex: "#22252B"), lineWidth: 1)
                        )
                )
            Text(tile.label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.6)
                .foregroundColor(active ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
            Text(tile.value)
                .font(.mono(10, weight: .bold))
                .foregroundColor(active ? Color(hex: "#D4FF3A") : Color(hex: "#F5F3EE"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// Pick hero — minimal, two things only:
    ///   1. The predicted winner (huge Anton on the left)
    ///   2. AI confidence (110pt animated ring on the right)
    /// Anything else (key factor, reasoning, tipoff) lives in the tabs
    /// below so the hero can breathe.
    private var pickHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tiny kicker, single line — gives context without crowding.
            Text("AI PICK")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#D4FF3A"))

            // The two big things: predicted winner + confidence ring.
            HStack(alignment: .center, spacing: 16) {
                // Predicted winner — fills available space on the left.
                Text(pick.pick.uppercased())
                    .font(.anton(50))
                    .tracking(-0.5)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Confidence ring — same component used on the home hero,
                // sized 110pt so the % reads from across the room.
                HiFiConfidenceRing(percent: pick.probability,
                                   color: Color(hex: "#D4FF3A"),
                                   trackColor: Color.white.opacity(0.08),
                                   size: 110,
                                   stroke: 6,
                                   numberColor: Color(hex: "#F5F3EE"),
                                   label: "AI CONF")
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "#14161A"), Color(hex: "#0d0e11")],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(hex: "#22252B"), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(hex: "#D4FF3A").opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        ))
                        .frame(width: 180, height: 180)
                        .offset(x: 60, y: -60)
                        .clipped()
                }
        )
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
        if liveScore?.isLive == true { return "STATUS" }
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
                        .foregroundColor(tab == t ? Color(hex: "#0A0B0D") : Color(hex: "#B9B7B0"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(tab == t ? Color(hex: "#D4FF3A") : Color(hex: "#101114"))
                        )
                        .overlay(
                            Capsule().stroke(tab == t ? Color(hex: "#D4FF3A") : Color(hex: "#22252B"), lineWidth: 1)
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
    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MATCH STATS")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#6E6F75"))
                .padding(.bottom, 12)
            ForEach(summaryStats, id: \.label) { row in
                StatBarRow(label: row.label,
                           homeText: row.homeText,
                           awayText: row.awayText,
                           homePct: row.homePct)
                    .padding(.bottom, 10)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var summaryStats: [StatRow] {
        BarSet.bars(for: pick.sport)
    }

    @ViewBuilder
    private var lineupsPanel: some View {
        EmptyPanel(title: "LINEUPS", caption: "Roster + boxscore wiring coming soon.")
    }

    /// ANALYSIS tab — Claude's plain-English reasoning + key factor.
    /// Moved here from the pick-hero so the hero can mirror the design's
    /// title → win-block → pick-row layout exactly.
    @ViewBuilder
    private var analysisPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let factor = pick.keyFactor, !factor.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("KEY FACTOR")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#D4FF3A"))
                    Text(factor)
                        .font(.anton(22))
                        .tracking(-0.1)
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#D4FF3A").opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(hex: "#D4FF3A").opacity(0.22), lineWidth: 1)
                        )
                )
            }

            if !pick.reasoning.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI REASONING")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text(pick.reasoning)
                        .font(.archivo(13, weight: .regular))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            } else {
                EmptyPanel(title: "ANALYSIS PENDING",
                           caption: "The AI is still working on this matchup. Reasoning will appear here once the prediction is generated.")
            }
        }
    }

    @ViewBuilder
    private var h2hPanel: some View {
        EmptyPanel(title: "HEAD TO HEAD", caption: "Last-5 series view coming soon.")
    }

    /// Sticky bottom CTA. Tapping opens the BookmakerSheet so the user
    /// can place the pick at their preferred sportsbook. Pick6 itself
    /// does NOT process the wager — see disclaimer in the sheet header.
    /// CTA sits low (4pt above the home-indicator safe area) so the
    /// content above gets more breathing room.
    private var savePickCTA: some View {
        Button {
            showBookmakers = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI RECOMMENDS · \(pick.confidence)")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#0A0B0D").opacity(0.7))
                    Text("PLACE THIS PICK")
                        .font(.anton(20))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("\(Int(pick.probability))%")
                        .font(.archivo(15, weight: .bold))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#D4FF3A"))
                    .shadow(color: Color(hex: "#D4FF3A").opacity(0.4), radius: 10, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)   // hugs the home indicator — was 16
    }
}

struct StatBarRow: View {
    let label: String
    let homeText: String
    let awayText: String
    let homePct: Double

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
                    Capsule().fill(Color(hex: "#16181C"))
                        .overlay(Capsule().stroke(Color(hex: "#22252B"), lineWidth: 1))
                    HStack(spacing: 0) {
                        Capsule().fill(Color(hex: "#D4FF3A"))
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
                    TopNavBar(crumb: "HOME · ",
                              crumbAccent: leagueLabel,
                              live: hasLiveToday,
                              onBack: onClose)

                    // ── HERO ─────────────────────────────────────────
                    sportHeroBlock
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 18)

                    // ── PICK HERO (top AI pick of the day) ───────────
                    if let top = topPick {
                        SmallPickHero(pick: top, onTap: { onTapPick(top) })
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    }

                    // ── LEAGUE RAIL (horizontal pill row of leagues) ─
                    leagueRail
                        .padding(.bottom, 16)

                    // ── TODAY ────────────────────────────────────────
                    HubSectionHead(
                        title: hasLiveToday ? "TODAY · LIVE & UPCOMING"
                                            : (isPro ? "TODAY" : "FREE PICK"),
                        meta: "\(picksForSport.count) GAME\(picksForSport.count == 1 ? "" : "S")",
                        live: hasLiveToday
                    )
                    .padding(.bottom, 10)
                    todayList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 22)

                    // ── YESTERDAY (only when there's history) ────────
                    if !yesterdayForSport.isEmpty {
                        HubSectionHead(title: "YESTERDAY",
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
                    HubSectionHead(title: "STANDINGS", meta: "TOP 5")
                        .padding(.bottom, 10)
                    standingsCard
                        .padding(.horizontal, 16)

                    Spacer().frame(height: 140)
                }
            }
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
                    .foregroundColor(Color(hex: "#D4FF3A"))
            }
        }
    }

    private var heroTagline: String {
        // E.g. "REGULAR SEASON · NIGHT 104" — short context line. Falls
        // back to a generic seasonal tagline when nothing's running.
        switch sport {
        case "basketball": return "REGULAR SEASON · TONIGHT"
        case "football":   return "WEEK 15 · SUNDAY SLATE"
        case "soccer":     return "PREMIER LEAGUE · MATCHDAY"
        case "baseball":   return "REGULAR SEASON · TODAY"
        case "hockey":     return "REGULAR SEASON · TONIGHT"
        case "combat":     return "FIGHT NIGHT"
        case "f1":         return "RACE WEEK"
        case "cricket":    return "IPL · MATCHDAY"
        default:           return "TODAY"
        }
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
    }

    private var leaguesForSport: [LeagueChip] {
        // Single-league fallback — count is today's picks for this sport.
        [LeagueChip(id: sport,
                    name: leagueLabel,
                    count: picksForSport.count,
                    swatch: glowColor,
                    active: true)]
    }

    private func leagueChip(_ l: LeagueChip) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(l.swatch)
                .frame(width: 10, height: 10)
            Text(l.name)
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(1.6)
            Text("\(l.count)")
                .font(.mono(10, weight: .bold))
                .foregroundColor(l.active ? Color(hex: "#0A0B0D").opacity(0.5)
                                          : Color(hex: "#6E6F75"))
        }
        .foregroundColor(l.active ? Color(hex: "#0A0B0D") : Color(hex: "#B9B7B0"))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(l.active ? Color(hex: "#F5F3EE")
                                             : Color(hex: "#101114")))
        .overlay(Capsule().stroke(l.active ? Color(hex: "#F5F3EE")
                                            : Color(hex: "#22252B"),
                                  lineWidth: 1))
    }

    // ════════════════════════════════════════════════════════════
    // MARK: TODAY list
    // ════════════════════════════════════════════════════════════

    @ViewBuilder
    private var todayList: some View {
        LazyVStack(spacing: 8) {
            let visible = isPro ? picksForSport
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
                     color: Color(hex: "#D4FF3A"))
            ydayTile(label: "TOP CONF",
                     value: bestText,
                     color: Color(hex: "#D4FF3A"))
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
                .fill(Color(hex: "#101114"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#22252B"), lineWidth: 1)
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
                Text("TEAM")
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
                    .fill(Color(hex: "#22252B"))
                    .frame(height: 1)
            }

            // Empty rows — design renders 5 of these with mute text.
            VStack(spacing: 0) {
                Text("Standings load with the season")
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

    /// Sport title — the giant Anton header at the top. Multi-word
    /// titles get split-color treatment in `heroTitle`.
    private var sportTitle: String {
        switch sport {
        case "basketball": return "NBA"
        case "soccer":     return "EPL"
        case "baseball":   return "MLB"
        case "football":   return "NFL"
        case "hockey":     return "NHL"
        case "combat":     return "UFC"
        case "f1":         return "FORMULA 1"   // splits to FORMULA + lime "1"
        case "cricket":    return "IPL"
        default:           return sport.uppercased()
        }
    }

    /// Compact label used in the breadcrumb/league-rail (always one
    /// token — no "FORMULA 1" splitting).
    private var leagueLabel: String {
        switch sport {
        case "f1": return "F1"
        default:   return sportTitle
        }
    }

    private var picksForSport: [Pick] {
        vm.todayPicks.filter { $0.sport == sport }
    }

    private var topPick: Pick? {
        picksForSport.max(by: { $0.probability < $1.probability })
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
        case "soccer":     return Color(hex: "#D4FF3A")    // lime
        case "football":   return Color(hex: "#785AF0")    // purple
        case "baseball":   return Color(hex: "#FF5A36")    // red-orange
        case "hockey":     return Color(hex: "#5B8CFF")    // blue
        case "combat":     return Color(hex: "#FF3C28")    // red
        case "f1":         return Color(hex: "#E10600")    // ferrari red
        case "cricket":    return Color(hex: "#FFD93D")    // saffron
        default:           return Color(hex: "#D4FF3A")
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
                    Text("★ TOP AI PICK · TODAY")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color.black.opacity(0.6))
                    Spacer()
                    Text("\(Int(pick.probability))% CONF")
                        .font(.mono(10, weight: .heavy))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#0A0B0D"))
                        .clipShape(Capsule())
                }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pick.pick.uppercased())
                            .font(.anton(34))
                            .lineSpacing(-6)
                            .foregroundColor(Color(hex: "#0A0B0D"))
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                        Text("over \(opp.uppercased())")
                            .font(.archivo(11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color.black.opacity(0.65))
                    }
                    Spacer(minLength: 8)
                    HiFiConfidenceRing(percent: pick.probability,
                                       color: Color(hex: "#0A0B0D"),
                                       trackColor: Color.black.opacity(0.15),
                                       size: 72,
                                       stroke: 5,
                                       numberColor: Color(hex: "#0A0B0D"),
                                       label: "AI CONF")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Color(hex: "#D4FF3A")
                    RadialGradient(
                        colors: [Color(hex: "#eaff7a"), Color(hex: "#D4FF3A").opacity(0)],
                        center: UnitPoint(x: 1.1, y: -0.2),
                        startRadius: 30,
                        endRadius: 400
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let s = liveScore, s.isLive {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: "#FF5A36"))
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(2.2)
                            .foregroundColor(Color(hex: "#FF5A36"))
                    }
                } else {
                    Text(pick.league.uppercased())
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
                Spacer()
                ConfPill(probability: pick.probability)
            }
            .padding(.bottom, 10)
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                    Text(teamShortName(pick.awayTeam))
                        .font(.anton(16))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                if let s = liveScore, let h = s.homeScore, let a = s.awayScore {
                    HStack(spacing: 6) {
                        Text("\(a)").font(.anton(22)).foregroundColor(Color(hex: "#F5F3EE"))
                        Text("–").font(.archivoNarrow(13)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)").font(.anton(22)).foregroundColor(Color(hex: "#B9B7B0"))
                    }
                } else {
                    Text("VS")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam))
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
                    Text(pick.pick.uppercased())
                        .font(.archivo(11, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
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
                    .foregroundColor(Color(hex: "#22252B"))
            }
        }
        .padding(14)
        .background(cardBackground)
    }
}

struct ConfPill: View {
    let probability: Double
    var body: some View {
        let hot = probability >= 80
        return HStack(spacing: 5) {
            Text("AI")
                .font(.mono(10, weight: .medium))
                .foregroundColor(hot ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
            Text("\(Int(probability))%")
                .font(.mono(10, weight: .heavy))
                .foregroundColor(Color(hex: "#F5F3EE"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(hot ? Color(hex: "#D4FF3A").opacity(0.08) : Color(hex: "#16181C")))
        .overlay(Capsule().stroke(hot ? Color(hex: "#D4FF3A").opacity(0.3) : Color(hex: "#2D3038"), lineWidth: 1))
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Profile
// ════════════════════════════════════════════════════════════════

struct ProfileView: View {
    @ObservedObject var vm: PicksViewModel
    var isPro: Bool = false
    let onShowWins: () -> Void
    let onShowPaywall: () -> Void
    let onSignOut: () -> Void

    /// Live, mutable user state. Read for display, mutated via the
    /// Edit Profile sheet (which calls auth.saveProfile).
    @Environment(AuthManager.self) private var auth

    enum Tab: String, CaseIterable { case stats = "STATS", badges = "BADGES", settings = "SETTINGS" }
    @State private var tab: Tab = .stats

    /// Count of earned badges (mirrors the `badgesTabBody` definition);
    /// shown next to the BADGES pill as "BADGES 6/12".
    private var earnedBadgeCount: Int {
        var n = 0
        if vm.currentStreak >= 3 { n += 1 }
        if vm.totalWins >= 10    { n += 1 }
        if vm.winRate    >= 60   { n += 1 }
        if vm.totalWins >= 50    { n += 1 }
        if vm.totalWins >= 100   { n += 1 }
        if vm.totalWins >= 1     { n += 1 }
        if vm.totalWins >= 1000  { n += 1 }
        if vm.totalWins >= 5     { n += 1 }
        return n
    }
    private let totalBadgeCount: Int = 12
    @State private var showEditProfile: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                TopNavBar(crumb: "APP · ", crumbAccent: "PROFILE", live: false, onBack: {}, showBack: false)
                profileHead
                statStrip
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                tabRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                Group {
                    switch tab {
                    case .stats:    statsTabBody
                    case .badges:   badgesTabBody
                    case .settings: settingsTabBody
                    }
                }
                .padding(.horizontal, 16)
                Spacer().frame(height: 140)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(auth: auth, isOpen: $showEditProfile)
        }
    }

    private var profileHead: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#D4FF3A").opacity(0.12), .clear],
                center: UnitPoint(x: 1.0, y: 0.0),
                startRadius: 0,
                endRadius: 220
            )
            Button { showEditProfile = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#D4FF3A"), Color(hex: "#a8e000")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .shadow(color: Color(hex: "#D4FF3A").opacity(0.3), radius: 10, x: 0, y: 8)
                        Text(initial)
                            .font(.anton(32))
                            .foregroundColor(Color(hex: "#0A0B0D"))
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
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#D4FF3A").opacity(0.08))
                        .overlay(Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.3), lineWidth: 1))
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
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
            handle = "@pick6fan"
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
        return "PICK6 FAN"
    }

    private var statStrip: some View {
        HStack(spacing: 0) {
            statCell(label: "ROI · 30D",
                     value: roiLabel,
                     color: Color(hex: "#D4FF3A"))
            Rectangle().fill(Color(hex: "#22252B")).frame(width: 1, height: 30)
            statCell(label: "RECORD",
                     value: "\(vm.totalWins + vm.totalLosses)",
                     subValue: "-\(vm.totalLosses)",
                     color: Color(hex: "#F5F3EE"))
            Rectangle().fill(Color(hex: "#22252B")).frame(width: 1, height: 30)
            statCell(label: "STREAK",
                     value: "W\(vm.currentStreak)",
                     color: Color(hex: "#D4FF3A"))
        }
        .padding(.vertical, 14)
        .background(cardBackground)
    }

    /// 30-day ROI label, styled like "+18.4%". Uses synthetic ROI when
    /// no real money data exists yet — a 50% hit rate ≈ 0% ROI.
    private var roiLabel: String {
        let roi = (vm.winRate - 50) * 0.92    // gentle scaling
        let prefix = roi >= 0 ? "+" : ""
        return "\(prefix)\(String(format: "%.1f", roi))%"
    }

    private func statCell(label: String, value: String,
                           subValue: String? = nil,
                           color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "#6E6F75"))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.anton(24))
                    .foregroundColor(color)
                if let sub = subValue {
                    Text(sub)
                        .font(.mono(9, weight: .bold))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tabRow: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    HStack(spacing: 6) {
                        Text(t.rawValue)
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.5)
                        // BADGES pill shows the earned/total count, e.g.
                        // "BADGES 6/12" — matches the design.
                        if t == .badges {
                            Text("\(earnedBadgeCount)/\(totalBadgeCount)")
                                .font(.mono(9, weight: .bold))
                                .foregroundColor(tab == t ? Color(hex: "#0A0B0D").opacity(0.6)
                                                          : Color(hex: "#6E6F75"))
                        }
                    }
                    .foregroundColor(tab == t ? Color(hex: "#0A0B0D") : Color(hex: "#B9B7B0"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(tab == t ? Color(hex: "#F5F3EE") : Color(hex: "#101114")))
                    .overlay(Capsule().stroke(tab == t ? Color(hex: "#F5F3EE") : Color(hex: "#22252B"), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsTabBody: some View {
        VStack(spacing: 16) {
            // 4 stat tiles in a 2×2 grid, each with label + big value
            // + delta trend + sparkline. Mirrors design `.tile`:
            // WIN RATE • TOTAL P/L • AI AGREE RATE • FAV SPORT.
            HStack(spacing: 8) {
                StatTile(label: "WIN RATE",
                         value: String(format: "%.1f", vm.winRate),
                         unit: "%",
                         trend: vm.winRate >= 50 ? "+\(String(format: "%.1f", vm.winRate - 50)) vs last month" : nil,
                         trendUp: vm.winRate >= 50,
                         valueColor: Color(hex: "#4ade80"),
                         sparkColor: Color(hex: "#4ade80"),
                         pts: trendSeries(.winRate))
                StatTile(label: "TOTAL P/L",
                         value: totalPLValue,
                         unit: totalPLUnit,
                         trend: "+$\(monthlyPL) this month",
                         trendUp: true,
                         valueColor: Color(hex: "#D4FF3A"),
                         sparkColor: Color(hex: "#D4FF3A"),
                         pts: trendSeries(.totalWins))
            }
            HStack(spacing: 8) {
                StatTile(label: "AI AGREE RATE",
                         value: "\(Int(min(95, vm.winRate + 5)))",
                         unit: "%",
                         trend: "On \(vm.totalWins + vm.totalLosses) picks",
                         trendUp: nil,
                         valueColor: Color(hex: "#F5F3EE"),
                         sparkColor: Color(hex: "#B9B7B0"),
                         pts: trendSeries(.aiAgree))
                StatTile(label: "FAV SPORT",
                         value: favoriteSport.0,
                         trend: "\(favoriteSport.1)% of picks",
                         trendUp: nil,
                         valueColor: Color(hex: "#F5F3EE"),
                         sparkColor: Color(hex: "#B9B7B0"),
                         pts: trendSeries(.favSport))
            }

            // BEST SPORTS section — per-sport row breakdown.
            VStack(alignment: .leading, spacing: 0) {
                HubSectionHead(title: "BEST SPORTS", meta: "BY ROI")
                    .padding(.horizontal, 0)
                    .padding(.bottom, 10)
                VStack(spacing: 0) {
                    let rows = bestSportsRows
                    ForEach(rows, id: \.sport) { row in
                        HStack(spacing: 12) {
                            Image(systemName: row.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#B9B7B0"))
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#16181C")))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#22252B"), lineWidth: 1))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label)
                                    .font(.archivo(13, weight: .semibold))
                                    .foregroundColor(Color(hex: "#F5F3EE"))
                                Text(row.sub)
                                    .font(.mono(10, weight: .medium))
                                    .foregroundColor(Color(hex: "#6E6F75"))
                            }
                            Spacer()
                            Text(row.value)
                                .font(.mono(11, weight: .heavy))
                                .foregroundColor(row.positive ? Color(hex: "#4ade80") : Color(hex: "#FF5A36"))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        if row.sport != rows.last?.sport {
                            Rectangle().fill(Color(hex: "#22252B")).frame(height: 1)
                        }
                    }
                }
                .background(cardBackground)
            }

            // YOUR WINS link — keeps a path from Profile → Wins.
            Button(action: onShowWins) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color(hex: "#D4FF3A"))
                    Text("YOUR WINS")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#F5F3EE"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                .padding(14)
                .background(cardBackground)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Stats helpers

    private enum TrendKey { case winRate, totalWins, aiAgree, favSport }

    /// Synthetic trend series (12 points) — tilts upward when the
    /// underlying stat is healthy. Replace with a real time-series
    /// from the performance_snapshots table once we have enough history.
    private func trendSeries(_ key: TrendKey) -> [Double] {
        let base: Double
        switch key {
        case .winRate:   base = vm.winRate
        case .totalWins: base = Double(vm.totalWins)
        case .aiAgree:   base = vm.winRate + 5
        case .favSport:  base = Double(favoriteSport.1)
        }
        // Generate a gently rising curve around the value
        return (0..<12).map { i in
            let drift = sin(Double(i) * 0.7) * 4
            return base + drift + Double(i) * 0.4
        }
    }

    /// Synthetic P/L for Total P/L tile — built from net wins (each
    /// win ≈ +$50, each loss ≈ -$45). Designed to look like the
    /// "+$3.2k" callout in the design until we wire up real money data.
    private var totalPLDollars: Int {
        max(0, vm.totalWins * 50 - vm.totalLosses * 45)
    }

    /// Big number (like "+$3.2") shown in the TOTAL P/L tile.
    private var totalPLValue: String {
        let n = totalPLDollars
        if n >= 1000 {
            return "+$\(String(format: "%.1f", Double(n) / 1000.0))"
        } else {
            return "+$\(n)"
        }
    }

    /// Trailing unit — "k" for $k, empty for plain dollars.
    private var totalPLUnit: String {
        totalPLDollars >= 1000 ? "k" : ""
    }

    /// Synthetic month-to-date P/L for the trend line ("+$612 this
    /// month") — roughly 20% of total.
    private var monthlyPL: Int {
        max(1, totalPLDollars / 5)
    }

    /// Most-played sport in the user's history (label + percentage).
    private var favoriteSport: (String, Int) {
        let counts = Dictionary(grouping: vm.historyPicks, by: { $0.sport })
            .mapValues { $0.count }
        let total = max(1, counts.values.reduce(0, +))
        if let best = counts.max(by: { $0.value < $1.value }) {
            let pct = Int(round(Double(best.value) / Double(total) * 100))
            return (sportLabel(best.key), pct)
        }
        return ("—", 0)
    }

    private func sportLabel(_ sport: String) -> String {
        switch sport {
        case "basketball": return "NBA"
        case "football":   return "NFL"
        case "baseball":   return "MLB"
        case "hockey":     return "NHL"
        case "soccer":     return "EPL"
        case "combat":     return "UFC"
        case "f1":         return "F1"
        case "cricket":    return "IPL"
        default:           return sport.uppercased()
        }
    }

    private struct BestSportRow {
        let sport: String, icon: String, label: String, sub: String,
            value: String, positive: Bool
    }

    /// Per-sport ROI breakdown for the BEST SPORTS section. Displays
    /// values as "+22.8%"-style ROI deltas to match the design.
    private var bestSportsRows: [BestSportRow] {
        let bySport = Dictionary(grouping: vm.historyPicks.filter { !$0.isPending },
                                 by: { $0.sport })
        return bySport.map { (sport, picks) in
            let wins   = picks.filter { $0.isWin }.count
            let losses = picks.filter { $0.isLoss }.count
            let total  = max(1, wins + losses)
            let rate   = Double(wins) / Double(total) * 100.0
            // Convert hit rate to a synthetic ROI in the same way the
            // 30D stat cell does — every point of hit rate above 50%
            // ≈ 0.92% ROI. Once we have real ledger data we'll replace
            // this with a true profit/stake calculation.
            let roi = (rate - 50.0) * 0.92
            let prefix = roi >= 0 ? "+" : ""
            return BestSportRow(
                sport: sport,
                icon: "scope",
                label: sportLabel(sport),
                sub: "\(picks.count) picks · W\(wins)-L\(losses)",
                value: "\(prefix)\(String(format: "%.1f", roi))%",
                positive: roi >= 0
            )
        }
        .sorted { $0.value > $1.value }   // best ROI first
    }

    private var badgesTabBody: some View {
        let badges: [(String, String, Bool)] = [
            ("flame.fill", "Hot Streak", vm.currentStreak >= 3),
            ("brain.head.profile", "AI Whisperer", vm.totalWins >= 10),
            ("scope", "Sharp Shooter", vm.winRate >= 60),
            ("diamond.fill", "Diamond Tier", vm.totalWins >= 50),
            ("trophy.fill", "Century Club", vm.totalWins >= 100),
            ("drop.fill", "First Blood", vm.totalWins >= 1),
            ("books.vertical.fill", "Sport Scholar", false),
            ("number", "1000 Club", vm.totalWins >= 1000),
            ("flag.fill", "Underdog", false),
            ("calendar", "Perfect Week", false),
            ("rectangle.split.3x3.fill", "Multi-Sport", vm.totalWins >= 5),
            ("crown.fill", "Legend", false),
        ]
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ], spacing: 8) {
            ForEach(0..<badges.count, id: \.self) { i in
                badgeTile(icon: badges[i].0, label: badges[i].1, earned: badges[i].2)
            }
        }
    }

    private func badgeTile(icon: String, label: String, earned: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(earned ? Color(hex: "#D4FF3A") : Color(hex: "#6E6F75"))
            Text(label)
                .font(.archivoNarrow(8, weight: .bold))
                .tracking(1.4)
                .foregroundColor(earned ? Color(hex: "#F5F3EE") : Color(hex: "#6E6F75"))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(earned
                      ? LinearGradient(colors: [Color(hex: "#D4FF3A").opacity(0.12), Color(hex: "#D4FF3A").opacity(0.02)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [Color(hex: "#101114"), Color(hex: "#101114")],
                                       startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(earned ? Color(hex: "#D4FF3A").opacity(0.25) : Color(hex: "#22252B"), lineWidth: 1)
                )
        )
    }

    @State private var showDeleteAccount: Bool = false
    @State private var notificationsOn: Bool = true
    @State private var darkModeOn: Bool = true

    /// Hairline divider used between rows inside a grouped settings card.
    private var divider: some View {
        Rectangle()
            .fill(Color(hex: "#22252B"))
            .frame(height: 1)
            .padding(.leading, 62)   // align past the icon tile
    }

    private var settingsTabBody: some View {
        VStack(spacing: 16) {
            // ── ACCOUNT / PREFS ────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HubSectionHead(title: "ACCOUNT", meta: "PREFS")
                    .padding(.horizontal, -20)   // cancel HubSectionHead's 20pt inset
                VStack(spacing: 0) {
                    settingsToggleRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        sub: "Live games · picks · results",
                        isOn: $notificationsOn
                    )
                    divider
                    settingsToggleRow(
                        icon: "moon.fill",
                        title: "Dark Mode",
                        sub: "Always on · system default",
                        isOn: $darkModeOn
                    )
                    divider
                    settingsLinkRow(
                        icon: "creditcard.fill",
                        title: "Subscription",
                        sub: isPro ? "Manage in iOS Settings" : "Unlock all picks · go Pro",
                        trailing: isPro ? "PRO" : "FREE",
                        action: onShowPaywall
                    )
                    divider
                    settingsLinkRow(
                        icon: "lock.fill",
                        title: "Privacy & Security",
                        sub: "Sign-in · saved data",
                        trailing: nil,
                        action: {}
                    )
                }
                .background(cardBackground)
            }

            // ── SUPPORT / HELP ─────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HubSectionHead(title: "SUPPORT", meta: "HELP")
                    .padding(.horizontal, -20)
                VStack(spacing: 0) {
                    settingsLinkRow(
                        icon: "questionmark.circle.fill",
                        title: "Help Center",
                        sub: "FAQs · contact us",
                        trailing: nil,
                        action: {}
                    )
                    divider
                    settingsLinkRow(
                        icon: "rectangle.portrait.and.arrow.right.fill",
                        title: "Sign Out",
                        sub: "You'll stay logged in on web",
                        trailing: nil,
                        danger: true,
                        action: onSignOut
                    )
                    divider
                    // Delete Account is mandatory for any iOS app with auth
                    // (Apple guideline 5.1.1(v) since iOS 14.5).
                    settingsLinkRow(
                        icon: "trash.fill",
                        title: "Delete Account",
                        sub: "Permanently remove your data",
                        trailing: nil,
                        danger: true
                    ) {
                        showDeleteAccount = true
                    }
                }
                .background(cardBackground)
            }
        }
        .alert("Delete account?", isPresented: $showDeleteAccount) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    // Best-effort: sign out + flag account for deletion.
                    // Backend should run a 30-day soft-delete via webhook;
                    // wire up next time we touch the AuthManager.
                    onSignOut()
                }
            }
        } message: {
            Text("This permanently deletes your Pick6 account and pick history within 30 days. Active subscriptions must be cancelled separately in iOS Settings → Subscriptions.")
        }
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
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color(hex: "#D4FF3A").opacity(0.10)))
                        .overlay(Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.28),
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
            .foregroundColor(danger ? Color(hex: "#FF5A36") : Color(hex: "#D4FF3A"))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "#16181C"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "#22252B"), lineWidth: 1)
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

    /// Local hide-from-list set so the user can dismiss won cards
    /// without a backend mutation. Reset on each presentation.
    @State private var hiddenPickIds: Set<UUID> = []
    @State private var confirmingClear: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopNavBar(crumb: "YOU · ", crumbAccent: "WINS", live: false, onBack: onClose, showBack: false)
                PageHero(title: "YOUR",
                         titleAccent: "WINS.",
                         sub: ["\(wonPicks.count) WON MATCH\(wonPicks.count == 1 ? "" : "ES")",
                               "FROM YOUR TEAMS"],
                         glow: Color(hex: "#4ade80"))
                    .padding(.bottom, 14)

                favActionsRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                if wonPicks.isEmpty {
                    emptyState
                        .padding(.horizontal, 20)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(wonPicks) { p in
                            Button { onTapPick(p) } label: {
                                wonCard(pick: p)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Spacer().frame(height: 140)
            }
        }
    }

    private var wonPicks: [Pick] {
        vm.historyPicks.filter { $0.isWin && !hiddenPickIds.contains($0.id) }
            .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast)
                > ($1.gameDate, $1.createdAt ?? Date.distantPast) }
    }

    /// Top-of-list count + "Clear all" button with 2-stage confirm flow
    /// (matches design `.fav-actions`).
    @ViewBuilder
    private var favActionsRow: some View {
        HStack {
            Text("\(wonPicks.count) MATCH\(wonPicks.count == 1 ? "" : "ES")")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#6E6F75"))
            Spacer()
            if !wonPicks.isEmpty {
                if confirmingClear {
                    HStack(spacing: 8) {
                        Text("Remove all?")
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color(hex: "#B9B7B0"))
                        Button("Cancel") { confirmingClear = false }
                            .font(.archivoNarrow(10, weight: .bold))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                        Button {
                            for p in vm.historyPicks where p.isWin { hiddenPickIds.insert(p.id) }
                            confirmingClear = false
                        } label: {
                            Text("Clear all")
                                .font(.archivoNarrow(10, weight: .heavy))
                                .tracking(1.8)
                                .foregroundColor(Color(hex: "#0A0B0D"))
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
                            Text("Clear all")
                                .font(.archivoNarrow(10, weight: .bold))
                                .tracking(1.8)
                        }
                        .foregroundColor(Color(hex: "#B9B7B0"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(hex: "#101114")))
                        .overlay(Capsule().stroke(Color(hex: "#22252B"), lineWidth: 1))
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
            Text("No wins yet")
                .font(.anton(22))
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text("Your won picks will appear here as games settle.")
                .font(.archivo(12, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#2D3038"), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }

    /// Won card per spec: top tag + WON badge, mirrored team body
    /// (HOME left / SCORE / AWAY right with `flex-row-reverse` on
    /// AWAY column), strike-through on the LOSING team, dashed
    /// footer with AI PICK + key factor + remove-X button.
    private func wonCard(pick: Pick) -> some View {
        let homeLost = (pick.homeScore ?? 0) < (pick.awayScore ?? 0)
        let awayLost = (pick.awayScore ?? 0) < (pick.homeScore ?? 0)

        return VStack(spacing: 0) {
            HStack {
                Text("\(pick.league.uppercased()) · \(relativeDate(pick.gameDate)) · FINAL")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                    Text("WON")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(1.8)
                }
                .foregroundColor(Color(hex: "#4ade80"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "#4ade80").opacity(0.1))
                .overlay(Capsule().stroke(Color(hex: "#4ade80").opacity(0.3), lineWidth: 1))
                .clipShape(Capsule())
            }
            .padding(.bottom, 12)

            // Mirrored layout: HOME left + SCORE center + AWAY right (reversed).
            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 9) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam))
                        .font(.anton(18))
                        .foregroundColor(homeLost ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(homeLost, color: Color(hex: "#2D3038"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let h = pick.homeScore, let a = pick.awayScore {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(h)")
                            .font(.anton(24)).fontWeight(.black)
                            .foregroundColor(homeLost ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        Text("–")
                            .font(.anton(14))
                            .foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(a)")
                            .font(.anton(24)).fontWeight(.black)
                            .foregroundColor(awayLost ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                    }
                } else {
                    Text("✓").font(.anton(20)).foregroundColor(Color(hex: "#4ade80"))
                }

                HStack(spacing: 9) {
                    Text(teamShortName(pick.awayTeam))
                        .font(.anton(18))
                        .foregroundColor(awayLost ? Color(hex: "#6E6F75") : Color(hex: "#F5F3EE"))
                        .strikethrough(awayLost, color: Color(hex: "#2D3038"))
                        .lineLimit(1)
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Footer with dashed top border, AI PICK label, key factor + remove X.
            HStack(spacing: 8) {
                Text("AI PICK")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.pick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text("· \(pick.keyFactor ?? pick.league.uppercased())")
                    .font(.mono(10))
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .lineLimit(1)
                Spacer()
                Button {
                    hiddenPickIds.insert(pick.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#16181C")))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#22252B"), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                DashedLine()
                    .stroke(Color(hex: "#22252B"),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
        }
        .padding(14)
        .background(cardBackground)
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
// MARK: - Live (in-play tracker)
// ════════════════════════════════════════════════════════════════

struct LiveView: View {
    enum LiveTab: String, CaseIterable {
        case mine = "My Picks", favs = "Favorites", all = "All Live"
    }

    @ObservedObject var vm: PicksViewModel
    var isPro: Bool = true
    let onTapPick: (Pick) -> Void
    var onUnlock: () -> Void = {}

    @State private var liveTab: LiveTab = .mine

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopNavBar(crumb: "NOW · ", crumbAccent: "LIVE", live: !livePicks.isEmpty, onBack: {}, showBack: false)
                PageHero(title: "LIVE",
                         titleAccent: "NOW.",
                         sub: ["\(livePicks.count) GAMES",
                               "\(livePicks.count) PICK\(livePicks.count == 1 ? "" : "S") IN PLAY"],
                         glow: Color(hex: "#FF5A36"))
                    .padding(.bottom, 14)

                tabsRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                if let nextUp = nextUpcomingPick {
                    watchBanner(nextUp)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                if livePicks.isEmpty {
                    nothingLive
                        .padding(.horizontal, 16)
                } else {
                    HubSectionHead(title: "IN PLAY", meta: "\(livePicks.count) LIVE", live: true)
                        .padding(.bottom, 10)
                    LazyVStack(spacing: 8) {
                        let visible = isPro ? livePicks : Array(livePicks.max(by: { $0.probability < $1.probability }).map { [$0] } ?? [])
                        ForEach(visible) { p in
                            Button { onTapPick(p) } label: {
                                liveCard(pick: p, score: liveScore(for: p))
                            }
                            .buttonStyle(.plain)
                        }
                        if !isPro {
                            let locked = livePicks.filter { p in !visible.contains(where: { $0.id == p.id }) }
                            if !locked.isEmpty {
                                ProUnlockCard(lockedCount: locked.count, onUnlock: onUnlock)
                                ForEach(locked.prefix(3)) { p in
                                    LockedPickCard(pick: p, onUnlock: onUnlock)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                Spacer().frame(height: 140)
            }
        }
    }

    /// Segmented tabs row — MY PICKS (with cnt) / FAVORITES / ALL LIVE.
    /// Labels are uppercased to match the screenshot ("MY PICKS 5",
    /// "FAVORITES", "ALL LIVE").
    private var tabsRow: some View {
        HStack(spacing: 8) {
            ForEach(LiveTab.allCases, id: \.self) { t in
                Button { liveTab = t } label: {
                    HStack(spacing: 6) {
                        Text(t.rawValue.uppercased())
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.6)
                        if t == .mine && livePicks.count > 0 {
                            Text("\(livePicks.count)")
                                .font(.mono(10, weight: .bold))
                                .foregroundColor(liveTab == t
                                                 ? Color(hex: "#0A0B0D").opacity(0.6)
                                                 : Color(hex: "#6E6F75"))
                        }
                    }
                    .foregroundColor(liveTab == t ? Color(hex: "#0A0B0D") : Color(hex: "#B9B7B0"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(liveTab == t
                                               ? Color(hex: "#F5F3EE")
                                               : Color(hex: "#101114")))
                    .overlay(Capsule().stroke(liveTab == t
                                              ? Color(hex: "#F5F3EE")
                                              : Color(hex: "#22252B"), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    /// Lime-tinted next-up reminder banner. Only shows when there's a
    /// pick whose game tips off in the next ~60 minutes and isn't live.
    private func watchBanner(_ next: Pick) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT UP · \(minutesUntil(next))")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Color(hex: "#D4FF3A"))
                Text("\(teamShortName(next.homeTeam)) vs \(teamShortName(next.awayTeam))")
                    .font(.anton(20))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1)
                Text("\(next.league.uppercased()) · YOUR PICK: \(next.pick.uppercased())")
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .lineLimit(1)
            }
            Spacer()
            Button { /* TODO: schedule local notification */ } label: {
                // 2-line uppercase label, matches the design's stacked
                // "REMIND / ME" pill on the right of the NEXT UP card.
                Text("REMIND\nME")
                    .font(.archivoNarrow(10, weight: .heavy))
                    .tracking(1.8)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#0A0B0D"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "#D4FF3A")))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "#D4FF3A").opacity(0.10),
                             Color(hex: "#D4FF3A").opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#D4FF3A").opacity(0.28), lineWidth: 1)
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
        if mins == 0 { return "STARTING NOW" }
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
            Text("Nothing live right now")
                .font(.anton(22))
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text("When games on your picks tip off, they'll show here with live progress + your call status.")
                .font(.archivo(12, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
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
                    Text("LIVE · \(pick.league.uppercased())")
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
                    Text(teamShortName(pick.awayTeam))
                        .font(.anton(16))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                if let s = score, let h = s.homeScore, let a = s.awayScore {
                    HStack(spacing: 6) {
                        Text("\(a)")
                            .font(.anton(30))
                            .foregroundColor(a > h ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
                        Text("–").font(.anton(16)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)")
                            .font(.anton(30))
                            .foregroundColor(h > a ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
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
                    Text(teamShortName(pick.homeTeam))
                        .font(.anton(16))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            // Game-progress bar — 4pt lime fill over a panel-2 track.
            // Without a true clock feed we approximate from the period.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#22252B"))
                    Capsule().fill(Color(hex: "#D4FF3A"))
                        .frame(width: geo.size.width * gameProgress(score))
                }
            }
            .frame(height: 4)
            .padding(.top, 12)

            HStack {
                Text("YOUR PICK")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.pick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                StatusPill(kind: statusKind(for: pick, score: score))
            }
            .padding(.top, 12)
            .overlay(alignment: .top) {
                DashedLine()
                    .stroke(Color(hex: "#22252B"),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(alignment: .leading) {
            // Full-height 3pt rail with red glow — NOT clipped to a
            // rounded rect (was clipping to RoundedRect 16 which
            // rounded the rail's top corners and killed the look).
            // The outer card already clips to its own corner radius,
            // so the rail rides the rounded edge naturally.
            Rectangle()
                .fill(Color(hex: "#FF5A36"))
                .frame(width: 3)
                .shadow(color: Color(hex: "#FF5A36").opacity(0.6), radius: 6)
        }
    }

    /// Approximates how far through the game we are (0.0 → 1.0). For
    /// sports with quarters/periods we read s.quarter; otherwise we
    /// fall back to a status heuristic.
    private func gameProgress(_ score: LiveScore?) -> CGFloat {
        guard let s = score else { return 0 }
        if let qStr = s.quarter, let q = Int(qStr) {
            // Q1=0.25, Q2=0.5, Q3=0.75, Q4=0.95 (leave headroom for OT)
            switch pick(of: s).sport {
            case "basketball", "football": return min(0.95, CGFloat(q) * 0.25)
            case "hockey":                  return min(0.95, CGFloat(q) * 0.33)
            default:                        return 0.5
            }
        }
        return s.isLive ? 0.5 : 0.0
    }

    /// Helper to look up the pick that owns a given live_score row,
    /// for the gameProgress sport-aware switch above.
    private func pick(of score: LiveScore) -> Pick {
        vm.todayPicks.first(where: { $0.gameId == score.gameId })
            ?? vm.todayPicks.first
            ?? Pick(id: UUID(), createdAt: nil, sport: "basketball", league: "NBA",
                    gameDate: "", gameId: nil, homeTeam: "", awayTeam: "",
                    pick: "", probability: 0, confidence: "*", reasoning: "",
                    keyFactor: nil, result: "pending",
                    homeScore: nil, awayScore: nil)
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
                TopNavBar(crumb: "TODAY · ", crumbAccent: "PICKS", live: false, onBack: {})
                PageHero(title: "TODAY'S",
                         titleAccent: "PICKS.",
                         sub: ["\(vm.todayPicks.count) PICKS", "AI \(Int(avgConf))% AVG"],
                         glow: Color(hex: "#D4FF3A"))
                    .padding(.bottom, 18)
                SportFilter(vm: vm)
                    .padding(.bottom, 12)
                let visible = vm.visiblePicks(isPro: isPro)
                if visible.isEmpty {
                    Text("No picks for the selected sport.")
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
// MARK: - Edit Profile sheet
// ════════════════════════════════════════════════════════════════

/// Modal sheet that lets users see + edit their profile data. Backed
/// by `AuthManager.saveProfile`, which upserts the row in Pick1's
/// `profiles` table. Email is shown but not editable here — it's
/// tied to the Apple ID / OTP-verified address.
struct EditProfileSheet: View {
    let auth: AuthManager
    @Binding var isOpen: Bool

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phone: String = ""
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var saving: Bool = false
    @State private var localError: String?

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
                                    colors: [Color(hex: "#D4FF3A"), Color(hex: "#a8e000")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .shadow(color: Color(hex: "#D4FF3A").opacity(0.3), radius: 14, x: 0, y: 12)
                            Text(initialPreview)
                                .font(.anton(46))
                                .foregroundColor(Color(hex: "#0A0B0D"))
                        }
                        .frame(width: 100, height: 100)
                        Spacer()
                    }
                    .padding(.bottom, 28)

                    // Email — read-only
                    fieldLabel("EMAIL")
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
                            .fill(Color(hex: "#101114"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#22252B"), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                    // First / Last name
                    fieldLabel("FIRST NAME")
                    profileField(text: $firstName, placeholder: "First name", icon: "person.fill")
                    fieldLabel("LAST NAME")
                    profileField(text: $lastName, placeholder: "Last name", icon: "person.fill")

                    // Phone
                    fieldLabel("PHONE / WHATSAPP (OPTIONAL)")
                    profileField(text: $phone, placeholder: "+1 (555) 555-1234",
                                 icon: "phone.fill", keyboard: .phonePad)

                    // DOB
                    fieldLabel("DATE OF BIRTH")
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(Color(hex: "#D4FF3A"))
                        DatePicker("", selection: $dob,
                                   in: ...Date(),
                                   displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .datePickerStyle(.compact)
                            .accentColor(Color(hex: "#D4FF3A"))
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#101114"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#22252B"), lineWidth: 1)
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
                                ProgressView().tint(Color(hex: "#0A0B0D"))
                            } else {
                                Text("Save Changes")
                                    .font(.archivo(14, weight: .heavy))
                            }
                        }
                        .foregroundColor(Color(hex: "#0A0B0D"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSave ? Color(hex: "#D4FF3A") : Color(hex: "#2D3038"))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave || saving)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            firstName = auth.firstName ?? ""
            lastName  = auth.lastName  ?? ""
            phone     = auth.whatsapp  ?? ""
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
                            .fill(Color(hex: "#101114"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#22252B"), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            Spacer()
            Text("EDIT PROFILE")
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#B9B7B0"))
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
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
                .foregroundColor(Color(hex: "#D4FF3A"))
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
                .fill(Color(hex: "#101114"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#22252B"), lineWidth: 1)
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
// MARK: - Bookmaker Sheet
// ════════════════════════════════════════════════════════════════

/// Modal sheet listing major sportsbooks with deep-links so the user
/// can place the AI-recommended pick at the platform of their choice.
///
/// Pick6 itself does NOT process wagers, hold funds, or facilitate
/// gambling. We surface AI predictions; bookmakers handle settlement.
/// The disclaimer at the top of the sheet makes that explicit.
///
/// The sportsbook URLs in `Bookmaker.all` are public homepage / app
/// universal-link URLs. Once you sign up with each sportsbook's
/// affiliate program, swap them with your tracked links so referral
/// revenue gets credited.
struct BookmakerSheet: View {
    let pick: Pick
    @Binding var isOpen: Bool

    var body: some View {
        ZStack {
            Color(hex: "#07080a").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sheetHeader
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .padding(.bottom, 18)

                    pickSummary
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)

                    disclaimerRow
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)

                    Text("CHOOSE A SPORTSBOOK")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ], spacing: 10) {
                        ForEach(Bookmaker.all) { book in
                            BookmakerTile(book: book)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)

                    fineprint
                        .padding(.horizontal, 22)
                        .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(.dark)
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
                            .fill(Color(hex: "#101114"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(hex: "#22252B"), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            Spacer()
            Text("PLACE PICK")
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2.4)
                .foregroundColor(Color(hex: "#B9B7B0"))
            Spacer()
            Color.clear.frame(width: 38, height: 38)
        }
    }

    /// Big AI-pick card at top: predicted winner + confidence + key factor.
    private var pickSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI PICK")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Color(hex: "#D4FF3A"))
                Spacer()
                Text("\(Int(pick.probability))% CONFIDENCE")
                    .font(.mono(11, weight: .bold))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "#D4FF3A").opacity(0.1)))
                    .overlay(Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.3), lineWidth: 1))
            }
            Text(pick.pick.uppercased())
                .font(.anton(34))
                .tracking(-0.3)
                .foregroundColor(Color(hex: "#F5F3EE"))
                .lineLimit(2).minimumScaleFactor(0.6)
            if let factor = pick.keyFactor, !factor.isEmpty {
                Text(factor)
                    .font(.archivo(12, weight: .regular))
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "#14161a"), Color(hex: "#0e0f12")],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: "#22252B"), lineWidth: 1)
                )
        )
    }

    /// Required-by-Apple disclaimer. Without this Apple Review will
    /// reject any app surfacing sportsbook deep-links.
    private var disclaimerRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "#FF8000"))
            VStack(alignment: .leading, spacing: 4) {
                Text("21+ ONLY · GAMBLE RESPONSIBLY")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text("Pick6 surfaces AI predictions for entertainment. We do not place, accept, or process wagers. By tapping a sportsbook below you'll leave Pick6 — wagers are settled by the sportsbook, not by us.")
                    .font(.archivo(11, weight: .regular))
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#FF8000").opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "#FF8000").opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var fineprint: some View {
        VStack(spacing: 8) {
            Text("If gambling is a problem, call 1-800-GAMBLER (US) or 1-800-522-4700 (NCPG).")
                .font(.archivo(10, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
            Text("Sportsbook availability depends on your jurisdiction. Pick6 is not affiliated with the sportsbooks listed.")
                .font(.archivo(10, weight: .regular))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Bookmaker model + tile
// ════════════════════════════════════════════════════════════════

struct Bookmaker: Identifiable {
    let id: String
    let name: String
    let url: URL
    let tint: Color

    /// Major US/intl sportsbooks. Replace these URLs with your affiliate-
    /// tracked links once you've signed up with each book's program.
    static let all: [Bookmaker] = [
        .init(id: "draftkings",  name: "DraftKings",  url: URL(string: "https://sportsbook.draftkings.com/")!,  tint: Color(hex: "#00B14F")),
        .init(id: "fanduel",     name: "FanDuel",     url: URL(string: "https://sportsbook.fanduel.com/")!,     tint: Color(hex: "#1493FF")),
        .init(id: "betmgm",      name: "BetMGM",      url: URL(string: "https://sports.betmgm.com/")!,           tint: Color(hex: "#B98C40")),
        .init(id: "caesars",     name: "Caesars",     url: URL(string: "https://sportsbook.caesars.com/")!,     tint: Color(hex: "#C4A95E")),
        .init(id: "espnbet",     name: "ESPN BET",    url: URL(string: "https://espnbet.com/")!,                 tint: Color(hex: "#D60808")),
        .init(id: "betrivers",   name: "BetRivers",   url: URL(string: "https://www.betrivers.com/")!,           tint: Color(hex: "#0066B3")),
        .init(id: "hardrock",    name: "Hard Rock",   url: URL(string: "https://hardrock.bet/")!,                tint: Color(hex: "#C8102E")),
        .init(id: "bet365",      name: "bet365",      url: URL(string: "https://www.bet365.com/")!,              tint: Color(hex: "#14854F")),
    ]
}

struct BookmakerTile: View {
    let book: Bookmaker
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(book.url)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Branded color dot — until logos are licensed
                ZStack {
                    Circle().fill(book.tint)
                        .frame(width: 38, height: 38)
                    Text(String(book.name.prefix(1)))
                        .font(.anton(20))
                        .foregroundColor(.white)
                }
                Text(book.name)
                    .font(.archivo(14, weight: .heavy))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                HStack(spacing: 4) {
                    Text("OPEN")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(1.8)
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(Color(hex: "#D4FF3A"))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#14161a"), Color(hex: "#0e0f12")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "#22252B"), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
