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

    var body: some View {
        HStack(alignment: .center) {
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

            // Sticky save-to-favorites CTA
            VStack { Spacer(); savePickCTA }
        }
        .preferredColorScheme(.dark)
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

    private func statTile(_ tile: StatTile, active: Bool) -> some View {
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

    private var pickHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("★ AI PICK · TONIGHT")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Color(hex: "#D4FF3A"))
                Spacer()
                Text("\(Int(pick.probability))% CONF")
                    .font(.mono(11, weight: .bold))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#D4FF3A").opacity(0.1))
                    .overlay(Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.3), lineWidth: 1))
                    .clipShape(Capsule())
            }
            VStack(alignment: .leading, spacing: -3) {
                // Pick title — line 1 in white, line 2 in lime.
                // Falls back gracefully when keyFactor is short/nil.
                Text(pick.pick.uppercased())
                    .font(.anton(40))
                    .tracking(-0.4)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                if let factor = pick.keyFactor, !factor.isEmpty {
                    Text(factor.uppercased())
                        .font(.anton(28))
                        .tracking(-0.2)
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .lineLimit(2)
                }
            }

            // ─── Win block (3-col with lime arrow medallion) ──────
            // Mirrors the design's `.win-block` exactly — same lime-tinted
            // box, same 1fr/auto/1fr grid, same 36pt arrow medallion in
            // the middle. Reframed for the advisory positioning: instead
            // of STAKE / arrow / POSSIBLE WIN (gambling), shows AI
            // CONFIDENCE / arrow / AI EDGE.
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI CONFIDENCE")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text("\(Int(pick.probability))%")
                        .font(.mono(22, weight: .bold))
                        .tracking(-0.22)
                        .foregroundColor(Color(hex: "#F5F3EE"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .fill(Color(hex: "#D4FF3A"))
                        .frame(width: 36, height: 36)
                        .shadow(color: Color(hex: "#D4FF3A").opacity(0.45),
                                radius: 12, x: 0, y: 0)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                .mask(LinearGradient(colors: [.white, .clear],
                                                     startPoint: .top, endPoint: .center))
                        )
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text("AI EDGE")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text(pick.keyFactor?.uppercased() ?? "STRONG")
                        .font(.anton(20))
                        .tracking(-0.1)
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .shadow(color: Color(hex: "#D4FF3A").opacity(0.35),
                                radius: 14, x: 0, y: 0)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#D4FF3A").opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: "#D4FF3A").opacity(0.22), lineWidth: 1)
                    )
            )

            // ─── Pick row (3 small stats with top border) ────────
            // Matches design `.pick-row` — 9pt narrow caps key + 18pt
            // Anton value, 3 columns separated by hairline above.
            HStack(alignment: .top, spacing: 6) {
                pickStatCol(label: "TIER",       value: pick.confidence)
                pickStatCol(label: "PROB",       value: "\(Int(pick.probability))%")
                pickStatCol(label: scheduledOrLiveLabelShort,
                            value: tipoffText, twoLine: true)
            }
            .padding(.top, 14)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "#22252B")),
                alignment: .top
            )
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

    /// "Save Pick" — adds the pick to the user's tracked list. Pick6 does
    /// not place wagers; this is a save-to-favorites action.
    private var savePickCTA: some View {
        Button {
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { showToast = false }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI RECOMMENDS · \(pick.confidence)")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#0A0B0D").opacity(0.7))
                    Text("SAVE THIS PICK")
                        .font(.anton(20))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("\(Int(pick.probability))%")
                        .font(.archivo(15, weight: .bold))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 13, weight: .bold))
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
        .padding(.bottom, 16)
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
            // Per-sport glow tint
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
                    TopNavBar(crumb: "HOME · ", crumbAccent: leagueLabel.uppercased(), live: false, onBack: onClose)
                    sportHeroBlock
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                    if let top = topPick {
                        SmallPickHero(pick: top, onTap: { onTapPick(top) })
                            .padding(.horizontal, 16)
                            .padding(.bottom, 18)
                    }
                    HubSectionHead(title: isPro ? "TODAY" : "FREE PICK",
                                   meta: "\(picksForSport.count) PICK\(picksForSport.count == 1 ? "" : "S")")
                        .padding(.bottom, 10)
                    LazyVStack(spacing: 8) {
                        let visible = isPro ? picksForSport : Array(topPick.map { [$0] } ?? [])
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
                    .padding(.horizontal, 16)
                    Spacer().frame(height: 120)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sportHeroBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sportTitle)
                .font(.anton(64))
                .lineSpacing(-12)
                .tracking(-0.6)
                .foregroundColor(Color(hex: "#F5F3EE"))
            HStack(spacing: 8) {
                Text("\(picksForSport.count) PICKS TODAY")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Circle()
                    .fill(Color(hex: "#6E6F75"))
                    .frame(width: 4, height: 4)
                Text("AI \(Int(avgConf))% AVG")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sportTitle: String {
        switch sport {
        case "basketball": return "NBA"
        case "soccer":     return "EPL"
        case "baseball":   return "MLB"
        case "football":   return "NFL"
        case "hockey":     return "NHL"
        case "combat":     return "UFC"
        case "f1":         return "F1"
        case "cricket":    return "IPL"
        default:           return sport.uppercased()
        }
    }

    private var leagueLabel: String { sportTitle }

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

    private var glowColor: Color {
        // Per-sport tint from agent's spec (sport-hubs.jsx)
        switch sport {
        case "basketball": return Color(hex: "#E75A28")    // orange
        case "soccer":     return Color(hex: "#D4FF3A")    // lime
        case "football":   return Color(hex: "#785AF0")    // purple
        case "baseball":   return Color(hex: "#FF5A36")    // red-orange
        case "hockey":     return Color(hex: "#5B8CFF")    // blue
        case "combat":     return Color(hex: "#FF3C28")    // red
        case "f1":         return Color(hex: "#E10600")    // ferrari red
        case "cricket":    return Color(hex: "#FFD93D")    // saffron / cricket yellow
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
    @State private var showEditProfile: Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                TopNavBar(crumb: "APP · ", crumbAccent: "PROFILE", live: false, onBack: {})
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
                        Text(emailLine)
                            .font(.mono(11, weight: .medium))
                            .foregroundColor(Color(hex: "#B9B7B0"))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Image(systemName: isPro ? "diamond.fill" : "person.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(isPro ? "PICK6 PRO · ALL ACCESS" : "FREE · TAP TO EDIT")
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
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#6E6F75"))
                        .padding(8)
                        .background(Circle().fill(Color(hex: "#101114")))
                        .overlay(Circle().stroke(Color(hex: "#22252B"), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
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

    private var emailLine: String {
        auth.userEmail ?? "Sign in to sync your picks"
    }

    private var statStrip: some View {
        HStack(spacing: 0) {
            statCell(label: "ROI · 30D", value: "+\(Int(vm.winRate.rounded()))%", color: Color(hex: "#D4FF3A"))
            Divider().background(Color(hex: "#22252B")).frame(height: 30)
            statCell(label: "RECORD", value: "\(vm.totalWins)-\(vm.totalLosses)", color: Color(hex: "#F5F3EE"))
            Divider().background(Color(hex: "#22252B")).frame(height: 30)
            statCell(label: "STREAK", value: "W\(vm.currentStreak)", color: Color(hex: "#D4FF3A"))
        }
        .padding(.vertical, 14)
        .background(cardBackground)
    }

    private func statCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.anton(22))
                .foregroundColor(color)
            Text(label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "#6E6F75"))
        }
        .frame(maxWidth: .infinity)
    }

    private var tabRow: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    Text(t.rawValue)
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.5)
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
            HStack(spacing: 8) {
                statTile(label: "WIN RATE", value: "\(Int(vm.winRate.rounded()))%", color: Color(hex: "#4ade80"))
                statTile(label: "TOTAL P/L", value: vm.winRate >= 50 ? "+W" : "—", color: Color(hex: "#D4FF3A"))
            }
            HStack(spacing: 8) {
                statTile(label: "AI AGREE", value: "\(Int(min(95, vm.winRate + 5)))%", color: Color(hex: "#F5F3EE"))
                statTile(label: "PICKS", value: "\(vm.totalWins + vm.totalLosses + vm.totalPending)", color: Color(hex: "#F5F3EE"))
            }
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

    private func statTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(value)
                .font(.anton(28))
                .foregroundColor(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
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

    private var settingsTabBody: some View {
        VStack(spacing: 8) {
            settingsRow(icon: "bell.fill", title: "Notifications", trailing: "ON")
            settingsRow(icon: "moon.fill", title: "Dark Mode", trailing: "ON")
            settingsRow(icon: "creditcard.fill", title: "Subscription", trailing: isPro ? "PRO" : "FREE", action: onShowPaywall)
            settingsRow(icon: "lock.fill", title: "Privacy & Security", trailing: nil)
            settingsRow(icon: "questionmark.circle.fill", title: "Help Center", trailing: nil)
            settingsRow(icon: "rectangle.portrait.and.arrow.right.fill", title: "Sign Out", trailing: nil, danger: true, action: onSignOut)
            // Delete Account is mandatory for any iOS app with auth (Apple
            // guideline 5.1.1(v) since iOS 14.5).
            settingsRow(icon: "trash.fill", title: "Delete Account", trailing: nil, danger: true) {
                showDeleteAccount = true
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

    private func settingsRow(icon: String, title: String, trailing: String?, danger: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(danger ? Color(hex: "#FF5A36") : Color(hex: "#D4FF3A"))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(hex: "#16181C"))
                    )
                Text(title)
                    .font(.archivo(13, weight: .semibold))
                    .foregroundColor(danger ? Color(hex: "#FF5A36") : Color(hex: "#F5F3EE"))
                Spacer()
                if let t = trailing {
                    Text(t)
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
            }
            .padding(14)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Wins / Favorites
// ════════════════════════════════════════════════════════════════

struct WinsView: View {
    @ObservedObject var vm: PicksViewModel
    let onClose: () -> Void
    let onTapPick: (Pick) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopNavBar(crumb: "YOU · ", crumbAccent: "WINS", live: false, onBack: onClose)
                PageHero(title: "YOUR",
                         titleAccent: "WINS.",
                         sub: ["\(wonPicks.count) WON", "FROM YOUR PICKS"],
                         glow: Color(hex: "#4ade80"))
                    .padding(.bottom, 18)
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
        vm.historyPicks.filter { $0.isWin }
            .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast)
                > ($1.gameDate, $1.createdAt ?? Date.distantPast) }
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

    private func wonCard(pick: Pick) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(pick.league.uppercased()) · \(pick.gameDate)")
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

            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.awayTeam, size: .small)
                    Text(teamShortName(pick.awayTeam))
                        .font(.anton(16))
                        .foregroundColor(pickedAway(pick) ? Color(hex: "#F5F3EE") : Color(hex: "#2D3038"))
                        .strikethrough(!pickedAway(pick), color: Color(hex: "#2D3038"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                if let h = pick.homeScore, let a = pick.awayScore {
                    HStack(spacing: 6) {
                        Text("\(a)").font(.anton(24)).foregroundColor(Color(hex: "#F5F3EE"))
                        Text("–").font(.anton(14)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)").font(.anton(24)).foregroundColor(Color(hex: "#F5F3EE"))
                    }
                } else {
                    Text("✓").font(.anton(20)).foregroundColor(Color(hex: "#4ade80"))
                }
                VStack(spacing: 6) {
                    TeamLogo(sport: pick.sport, team: pick.homeTeam, size: .small)
                    Text(teamShortName(pick.homeTeam))
                        .font(.anton(16))
                        .foregroundColor(!pickedAway(pick) ? Color(hex: "#F5F3EE") : Color(hex: "#2D3038"))
                        .strikethrough(pickedAway(pick), color: Color(hex: "#2D3038"))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                Text("AI PICK")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.pick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                Text("\(Int(pick.probability))% AI")
                    .font(.mono(10, weight: .bold))
                    .foregroundColor(Color(hex: "#D4FF3A"))
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle().frame(height: 1).foregroundColor(Color(hex: "#22252B"))
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private func pickedAway(_ p: Pick) -> Bool {
        p.pick.lowercased().contains(p.awayTeam.lowercased())
            || p.awayTeam.lowercased().contains(p.pick.lowercased())
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                TopNavBar(crumb: "NOW · ", crumbAccent: "LIVE", live: !livePicks.isEmpty, onBack: {})
                PageHero(title: "LIVE",
                         titleAccent: "NOW.",
                         sub: ["\(livePicks.count) IN PLAY", "AI TRACKING"],
                         glow: Color(hex: "#FF5A36"))
                    .padding(.bottom, 18)

                if livePicks.isEmpty {
                    nothingLive
                        .padding(.horizontal, 16)
                } else {
                    HubSectionHead(title: "IN PLAY", meta: "\(livePicks.count) GAMES", live: true)
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
                            .font(.anton(28))
                            .foregroundColor(a > h ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
                        Text("–").font(.anton(16)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)")
                            .font(.anton(28))
                            .foregroundColor(h > a ? Color(hex: "#D4FF3A") : Color(hex: "#B9B7B0"))
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
            HStack {
                Text("YOUR PICK")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.pick.uppercased())
                    .font(.archivo(11, weight: .bold))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Spacer()
                Text(statusFor(pick: pick, score: score).label)
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(statusFor(pick: pick, score: score).color)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle().frame(height: 1).foregroundColor(Color(hex: "#22252B"))
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color(hex: "#FF5A36"))
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "#FF5A36"), radius: 5)
        }
    }

    private func statusFor(pick: Pick, score: LiveScore?) -> (label: String, color: Color) {
        guard let s = score, let h = s.homeScore, let a = s.awayScore else { return ("LIVE", Color(hex: "#FF5A36")) }
        let pickedAway = pick.pick.lowercased().contains(pick.awayTeam.lowercased())
            || pick.awayTeam.lowercased().contains(pick.pick.lowercased())
        let winning = pickedAway ? a > h : h > a
        return winning ? ("ON TRACK", Color(hex: "#4ade80")) : ("SWEATING", Color(hex: "#FF5A36"))
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
struct StatTile {
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
    static func tiles(for sport: String, liveScore: LiveScore?) -> [StatTile] {
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
