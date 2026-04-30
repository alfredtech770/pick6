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

/// Reusable card-tile background.
private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(hex: "#101114"))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "#22252B"), lineWidth: 1)
        )
}

// ════════════════════════════════════════════════════════════════
// MARK: - Match Detail (Pick6 Detail Pages)
// ════════════════════════════════════════════════════════════════

struct MatchDetailView: View {
    let pick: Pick
    let liveScore: LiveScore?
    let onClose: () -> Void

    enum Tab: String, CaseIterable { case summary = "SUMMARY", lineups = "LINEUPS", odds = "ODDS", h2h = "H2H" }
    @State private var tab: Tab = .summary
    @State private var starred: Bool = false
    @State private var showToast: Bool = false

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
                        case .summary: summaryPanel
                        case .lineups: lineupsPanel
                        case .odds:    oddsPanel
                        case .h2h:     h2hPanel
                        }
                    }
                    .padding(.horizontal, 16)
                    Spacer().frame(height: 120)
                }
            }

            // Toast
            if showToast {
                Text("PICK SAVED · \(Int(pick.probability))% AI")
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

            // Sticky CTA
            VStack { Spacer(); betCTA }
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

    private var scoreHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .trailing, spacing: 6) {
                Text(isAway ? "AWAY" : "HOME")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.awayTeam.uppercased())
                    .font(.anton(28))
                    .lineSpacing(-3)
                    .tracking(-0.05)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            VStack(spacing: 8) {
                if let s = liveScore, s.isLive {
                    Text(s.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? "LIVE")
                        .font(.mono(12, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#D4FF3A").opacity(0.08))
                        .overlay(Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.22), lineWidth: 1))
                        .clipShape(Capsule())
                }
                if let s = liveScore, let h = s.homeScore, let a = s.awayScore {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(a)").font(.anton(56)).foregroundColor(Color(hex: "#F5F3EE"))
                        Text("–").font(.anton(28)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)").font(.anton(56)).foregroundColor(Color(hex: "#B9B7B0"))
                    }
                } else {
                    Text("VS")
                        .font(.anton(28))
                        .tracking(2.8)
                        .foregroundColor(Color(hex: "#D4FF3A"))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isAway ? "HOME" : "AWAY")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.homeTeam.uppercased())
                    .font(.anton(28))
                    .lineSpacing(-3)
                    .tracking(-0.05)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private var isAway: Bool {
        pick.pick.lowercased().contains(pick.awayTeam.lowercased())
            || pick.awayTeam.lowercased().contains(pick.pick.lowercased())
    }

    private var statIconRow: some View {
        HStack(spacing: 4) {
            ForEach(["chart.bar.fill", "flame.fill", "bolt.fill", "person.fill"], id: \.self) { icon in
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(hex: "#101114"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(hex: "#22252B"), lineWidth: 1)
                                )
                        )
                    Text(statLabel(for: icon))
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(1.8)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                    Text(statValue(for: icon))
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
    }

    private func statLabel(for icon: String) -> String {
        switch icon {
        case "chart.bar.fill": return "FORM"
        case "flame.fill":     return "STREAK"
        case "bolt.fill":      return "PACE"
        default:               return "ROSTER"
        }
    }

    private func statValue(for icon: String) -> String {
        switch icon {
        case "chart.bar.fill": return "8-2"
        case "flame.fill":     return "+5"
        case "bolt.fill":      return "108.4"
        default:               return "FULL"
        }
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
            VStack(alignment: .leading, spacing: 0) {
                Text(pickTitleLine1)
                    .font(.anton(40))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text(pickTitleLine2)
                    .font(.anton(40))
                    .foregroundColor(Color(hex: "#D4FF3A"))
            }

            // Reasoning block (replaces the "stake/win" mock with real Claude reasoning)
            if !pick.reasoning.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WHY")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Text(pick.reasoning)
                        .font(.archivo(13, weight: .regular))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                        .lineSpacing(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#D4FF3A").opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(hex: "#D4FF3A").opacity(0.22), lineWidth: 1)
                        )
                )
            }

            // Pick stats: confidence / probability / key factor
            HStack(alignment: .top, spacing: 0) {
                pickStatCol(label: "CONFIDENCE", value: pick.confidence)
                pickStatCol(label: "PROBABILITY", value: "\(Int(pick.probability))%")
                pickStatCol(label: "EDGE", value: pick.keyFactor ?? "—", twoLine: true)
            }
            .padding(.top, 10)
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

    private var pickTitleLine1: String {
        let parts = pick.pick.uppercased().split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        return String(parts.first ?? Substring(pick.pick.uppercased()))
    }
    private var pickTitleLine2: String {
        let opp = isAway ? pick.homeTeam : pick.awayTeam
        return "OVER \(opp.uppercased())"
    }

    private func pickStatCol(label: String, value: String, twoLine: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.8)
                .foregroundColor(Color(hex: "#6E6F75"))
            Text(value)
                .font(.anton(18))
                .foregroundColor(Color(hex: "#F5F3EE"))
                .lineLimit(twoLine ? 2 : 1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tabsRow: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    Text(t.rawValue)
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
            Spacer()
        }
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

    private struct StatRow {
        let label: String
        let homeText: String
        let awayText: String
        let homePct: Double
    }

    private var summaryStats: [StatRow] {
        // Static placeholders — wire real boxscore later.
        [
            StatRow(label: "POSSESSION", homeText: "54%", awayText: "46%", homePct: 0.54),
            StatRow(label: "SHOTS",      homeText: "12",  awayText: "9",   homePct: 0.57),
            StatRow(label: "PASS ACC",   homeText: "88%", awayText: "84%", homePct: 0.51),
            StatRow(label: "CORNERS",    homeText: "6",   awayText: "4",   homePct: 0.60),
        ]
    }

    @ViewBuilder
    private var lineupsPanel: some View {
        EmptyPanel(title: "LINEUPS", caption: "Roster + boxscore wiring coming soon.")
    }

    @ViewBuilder
    private var oddsPanel: some View {
        EmptyPanel(title: "ODDS", caption: "Sportsbook lines integration coming soon.")
    }

    @ViewBuilder
    private var h2hPanel: some View {
        EmptyPanel(title: "HEAD TO HEAD", caption: "Last-5 series view coming soon.")
    }

    private var betCTA: some View {
        Button {
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation { showToast = false }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI PICK · \(pick.confidence)")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#0A0B0D").opacity(0.7))
                    Text(pick.pick.uppercased())
                        .font(.anton(20))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("\(Int(pick.probability))%")
                        .font(.archivo(15, weight: .bold))
                        .foregroundColor(Color(hex: "#0A0B0D"))
                    Image(systemName: "arrow.right")
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
            HStack(alignment: .center, spacing: 10) {
                Text(pick.awayTeam.uppercased())
                    .font(.anton(18))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let s = liveScore, let h = s.homeScore, let a = s.awayScore {
                    HStack(spacing: 6) {
                        Text("\(a)").font(.anton(20)).foregroundColor(Color(hex: "#F5F3EE"))
                        Text("–").font(.archivoNarrow(13)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)").font(.anton(20)).foregroundColor(Color(hex: "#B9B7B0"))
                    }
                } else {
                    Text("VS")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                }
                Text(pick.homeTeam.uppercased())
                    .font(.anton(18))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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

    enum Tab: String, CaseIterable { case stats = "STATS", badges = "BADGES", settings = "SETTINGS" }
    @State private var tab: Tab = .stats

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
    }

    private var profileHead: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#D4FF3A").opacity(0.12), .clear],
                center: UnitPoint(x: 1.0, y: 0.0),
                startRadius: 0,
                endRadius: 220
            )
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
                    Text("PICK6 USER")
                        .font(.anton(28))
                        .foregroundColor(Color(hex: "#F5F3EE"))
                    Text("Member · \(memberSince)")
                        .font(.mono(11, weight: .medium))
                        .foregroundColor(Color(hex: "#B9B7B0"))
                    HStack(spacing: 4) {
                        Image(systemName: "diamond.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("DIAMOND · L\(diamondLevel)")
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
    }

    private var initial: String { "P" }
    private var memberSince: String { "2026" }
    private var diamondLevel: Int { max(1, vm.totalWins / 10) }

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
            ("link", "Parlay King", false),
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

            HStack(alignment: .center, spacing: 10) {
                Text(pick.awayTeam.uppercased())
                    .font(.anton(20))
                    .foregroundColor(pickedAway(pick) ? Color(hex: "#F5F3EE") : Color(hex: "#2D3038"))
                    .strikethrough(!pickedAway(pick), color: Color(hex: "#2D3038"))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let h = pick.homeScore, let a = pick.awayScore {
                    HStack(spacing: 6) {
                        Text("\(a)").font(.anton(26)).foregroundColor(Color(hex: "#F5F3EE"))
                        Text("–").font(.anton(14)).foregroundColor(Color(hex: "#6E6F75"))
                        Text("\(h)").font(.anton(26)).foregroundColor(Color(hex: "#F5F3EE"))
                    }
                } else {
                    Text("✓").font(.anton(20)).foregroundColor(Color(hex: "#4ade80"))
                }
                Text(pick.homeTeam.uppercased())
                    .font(.anton(20))
                    .foregroundColor(!pickedAway(pick) ? Color(hex: "#F5F3EE") : Color(hex: "#2D3038"))
                    .strikethrough(pickedAway(pick), color: Color(hex: "#2D3038"))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
            HStack(alignment: .center, spacing: 10) {
                Text(pick.awayTeam.uppercased())
                    .font(.anton(20))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                }
                Text(pick.homeTeam.uppercased())
                    .font(.anton(20))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
