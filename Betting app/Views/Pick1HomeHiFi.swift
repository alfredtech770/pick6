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
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(AuthManager.self) private var auth

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
                                    Task { await auth.signOut() }
                                })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingNav(tab: $tab, liveCount: liveCount)
                // Flush with the safe-area bottom edge — sits as low
                // as possible without entering the home-indicator
                // gesture zone. (User has asked for "lower" multiple
                // times; this is the floor without breaking iOS
                // gesture handling.)
                .padding(.bottom, 0)
        }
        .preferredColorScheme(.dark)
        .task { await vm.startLiveSession() }
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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Button(action: { if let t = topPick { onTapPick(t) } }) {
                    if let top = topPick {
                        HeroCard(pick: top, isLive: isLive(top))
                    } else {
                        HeroCard.empty
                    }
                }
                .buttonStyle(.plain)

                StatsRow(streak: vm.currentStreak,
                         best: vm.longestStreak,
                         accuracy: vm.winRate,
                         pickCount: vm.effectiveTodayPicks.count)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                SportFilter(vm: vm, onLongPress: { onTapSport($0) })
                    .padding(.top, 4)

                // Section header — title matches the design
                // ("TODAY'S GAMES") with a SEE ALL → CTA. The CTA is
                // only enabled when a specific sport is selected, since
                // the SportHub is per-sport. When ALL is selected, the
                // CTA renders as a passive caption nudging the user to
                // pick a sport first.
                SectionHeader(
                    title: isPro ? "TODAY'S GAMES" : "FREE PICKS · TOP PER SPORT",
                    cta: isPro ? "SEE ALL →" : nil,
                    onTapCTA: (isPro && vm.selectedSport != "all")
                        ? { onTapSport(vm.selectedSport) }
                        : nil
                )
                .padding(.horizontal, 20)
                .padding(.top, 18)

                LazyVStack(spacing: 10) {
                    let visible = vm.visiblePicks(isPro: isPro)
                    if vm.isLoading && visible.isEmpty {
                        ProgressView().tint(Color(hex: "#D4FF3A"))
                            .padding(.top, 40)
                    } else if visible.isEmpty {
                        EmptyTodayState()
                            .padding(.top, 40)
                    } else {
                        ForEach(visible.indices, id: \.self) { idx in
                            let pick = visible[idx]
                            Button { onTapPick(pick) } label: {
                                GameCard(pick: pick, isLive: isLive(pick), score: liveScore(for: pick))
                            }
                            .buttonStyle(.plain)
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
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
}

// MARK: - Hero card

struct HeroCard: View {
    let pick: Pick?
    let isLive: Bool

    static var empty: HeroCard { HeroCard(pick: nil, isLive: false) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Lime gradient background
            heroGradient
                .clipShape(BottomRoundedShape(radius: 32))

            // Diagonal stripe overlay — near-vertical (100° from horizontal),
            // 41pt pitch, very faint dark lines (per spec opacity 0.03).
            DiagonalStripe()
                .clipShape(BottomRoundedShape(radius: 32))
                .allowsHitTesting(false)

            // Top sheen — tight inset edge (≈8% of height), per spec
            // `inset 0 2px 0 rgba(255,255,255,0.35)`.
            LinearGradient(
                colors: [Color.white.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.08)
            )
            .clipShape(BottomRoundedShape(radius: 32))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 22) {
                heroTopBar
                heroBody
            }
            .padding(.horizontal, 22)
            .padding(.top, 56)        // status-bar inset
            .padding(.bottom, 32)
        }
        // Single soft lime-green glow under the hero (spec
        // `0 20px 40px -10px rgba(168,224,0,0.35)`).
        .shadow(color: Color(hex: "#a8e000").opacity(0.35), radius: 12, x: 0, y: 16)
    }

    private var heroGradient: some View {
        // Radial as in CSS: 140% 120% at 110% -20%, eaff7a → D4FF3A → a8e000
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
            HeroPill()
        }
    }

    private var heroBody: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("★ TOP PICK · TONIGHT")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Color.black.opacity(0.6))
                    .padding(.bottom, -8)  // tighten spec gap of 6 vs VStack's 14

                // Two-line headline (50pt Anton, line-height 0.86 → spec).
                // SwiftUI clamps lineSpacing to ≥0, so split the lines into
                // a VStack with negative spacing to actually achieve the
                // tight stadium-scoreboard line-height the design specifies.
                // Empty state ("NO PICKS / YET") uses extra-tight spacing
                // so the two short words read as one block, not as a
                // sentence with a gap.
                VStack(alignment: .leading, spacing: pick == nil ? -28 : -7) {
                    ForEach(headlineLines, id: \.self) { line in
                        Text(line)
                            .font(.anton(50))
                            .tracking(-0.7)
                            .foregroundColor(Color(hex: "#0A0B0D"))
                            .lineLimit(1)
                            // Long team names ("PHILADELPHIA 76ERS") still
                            // overflow even after teamShortName trimming —
                            // shrink down to ~30pt when needed instead of
                            // truncating to "BOSTON…".
                            .minimumScaleFactor(0.6)
                    }
                }

                HeroMetaPill(time: timeText, channel: channelText)
            }

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                HiFiConfidenceRing(percent: pick?.probability ?? 0,
                               color: Color(hex: "#0A0B0D"),
                               trackColor: Color.black.opacity(0.15),
                               size: 110,
                               stroke: 6,
                               numberColor: Color(hex: "#0A0B0D"))
                CrestPair(home: pick?.homeTeam, away: pick?.awayTeam, sport: pick?.sport ?? "")
            }
            .frame(width: 130)
        }
    }

    private var headlineText: String {
        guard let pick = pick else { return "NO PICKS\nYET" }
        // "AWAY OVER HOME" if pick is away; "HOME OVER AWAY" if pick is home.
        // Use teamShortName so "BOSTON CELTICS" / "PHILADELPHIA 76ERS" don't
        // overflow the 50pt Anton at our hero width — we just want
        // "CELTICS / OVER 76ERS".
        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
            || pick.homeTeam.lowercased().contains(pick.pick.lowercased())
        let other = pickedHome ? pick.awayTeam : pick.homeTeam
        let pickShort = teamShortName(pick.pick).uppercased()
        let otherShort = teamShortName(other).uppercased()
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
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text("PICK")
                .font(.anton(34))
                .tracking(-0.34)
                .foregroundColor(Color(hex: "#0A0B0D"))

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "#0A0B0D"))
                    .frame(width: 30, height: 30)
                Text("1")
                    .font(.anton(22))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                    .padding(.bottom, 2)
            }
            .padding(.leading, 4)
        }
    }
}

struct HeroPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: "#0A0B0D"))
                .frame(width: 6, height: 6)
            Text("AI · LIVE")
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(2)
                .foregroundColor(Color(hex: "#0A0B0D"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.12))
        .overlay(
            Capsule().stroke(Color.black.opacity(0.2), lineWidth: 1)
        )
        .clipShape(Capsule())
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
                .trim(from: 0, to: max(0.05, min(1, percent / 100)))
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.0), value: percent)

            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(percent.rounded()))")
                        .font(.anton(36))
                        .foregroundColor(numberColor)
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
    }
}

// MARK: - Crests

struct CrestPair: View {
    let home: String?
    let away: String?
    var sport: String = ""

    var body: some View {
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
func teamShortName(_ team: String) -> String {
    let trimmed = team.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count <= 12 { return trimmed.uppercased() }
    if let last = trimmed.split(separator: " ").last, last.count <= 12 {
        return String(last).uppercased()
    }
    return crestAbbrev(trimmed)
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
    let streak: Int
    let best: Int
    let accuracy: Double
    let pickCount: Int

    var body: some View {
        HStack(spacing: 10) {
            StreakTile(streak: streak, best: best)
            AccuracyTile(accuracy: accuracy, delta: nil)
        }
    }
}

struct StreakTile: View {
    let streak: Int
    let best: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                Text("STREAK")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(streak)")
                    .font(.anton(72))
                    .foregroundColor(Color(hex: "#D4FF3A"))
                    .tracking(-1.4)
                Text(streak == 1 ? "day" : "days")
                    .font(.archivo(18, weight: .bold))
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }
            // 10-segment progress bar
            HStack(spacing: 3) {
                ForEach(0..<10) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(i < min(streak, 10) ? Color(hex: "#D4FF3A") : Color(hex: "#2D3038"))
                        .frame(height: 5)
                }
            }
            HStack {
                Text("BEST: \(best)")
                    .font(.mono(10, weight: .medium))
                    .foregroundColor(Color(hex: "#6E6F75"))
                Spacer()
                if best > streak {
                    Text("↑ \(best - streak) TO RECORD")
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground)
    }
}

struct AccuracyTile: View {
    let accuracy: Double
    let delta: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                    Text("ACCURACY")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
                Spacer()
                if let d = delta {
                    Text(d >= 0 ? "↑ \(Int(d.rounded()))%" : "↓ \(Int((-d).rounded()))%")
                        .font(.mono(10, weight: .bold))
                        .foregroundColor(Color(hex: "#D4FF3A"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#D4FF3A").opacity(0.12))
                        .overlay(
                            Capsule().stroke(Color(hex: "#D4FF3A").opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(accuracy.rounded()))")
                    .font(.anton(72))
                    .foregroundColor(Color(hex: "#F5F3EE"))
                    .tracking(-1.4)
                Text("%")
                    .font(.archivo(18, weight: .bold))
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }
            // Sparkline placeholder — flat until we have day-over-day data
            SparklineView()
                .frame(height: 26)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground)
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
    let points: [CGFloat] = [20, 16, 18, 14, 15, 10, 12, 8, 10, 6, 4]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxY = points.max() ?? 1
            let minY = points.min() ?? 0
            let span = max(maxY - minY, 1)
            let step = w / CGFloat(max(points.count - 1, 1))
            let coords: [CGPoint] = points.enumerated().map { i, p in
                CGPoint(x: CGFloat(i) * step, y: h - ((p - minY) / span) * h)
            }
            // Fill
            Path { p in
                p.move(to: CGPoint(x: 0, y: h))
                for c in coords { p.addLine(to: c) }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            }
            .fill(Color(hex: "#D4FF3A").opacity(0.1))
            // Line
            Path { p in
                p.move(to: coords[0])
                for c in coords.dropFirst() { p.addLine(to: c) }
            }
            .stroke(Color(hex: "#D4FF3A"), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
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
                    HiFiSportChip(label: leagueLabel(sport),
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

    /// All 8 sport chips, always visible. Order matches the user's
    /// preferred order (Football, Basketball, Baseball, F1, Combat,
    /// Soccer, Cricket, Hockey). Tapping a sport with no picks today
    /// shows the empty state — better discovery than hiding the chip.
    private var visibleSports: [String] {
        ["football", "basketball", "baseball", "f1", "combat", "soccer", "cricket", "hockey"]
    }

    private func leagueLabel(_ sport: String) -> String {
        switch sport {
        case "basketball": return "NBA"
        case "football":   return "NFL"
        case "soccer":     return "EPL"
        case "baseball":   return "MLB"
        case "hockey":     return "NHL"
        case "combat":     return "UFC"
        case "f1":         return "F1"
        case "cricket":    return "IPL"
        default:           return sport.uppercased()
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

    var body: some View {
        VStack(spacing: 0) {
            // Top row
            HStack {
                if isLive, let s = score {
                    LivePulseBadge(label: livePulseText(s))
                    Text(pick.league)
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "#6E6F75"))
                } else {
                    Text(scheduledTopLine)
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.2)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                }
                Spacer()
                ConfChip(percent: pick.probability, hot: pick.probability >= 80)
            }
            .padding(.bottom, 14)

            // Teams + score
            HStack(alignment: .center, spacing: 14) {
                TeamColumn(team: pick.awayTeam, isAway: true, sport: pick.sport)
                ScoreView(pick: pick, isLive: isLive, score: score)
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
                    Text(pick.pick.uppercased())
                        .font(.anton(17))
                        .tracking(0.17)
                        .foregroundColor(Color(hex: "#D4FF3A"))
                }
                Spacer()
                MiniRing(percent: pick.probability)
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            // `.gcard` per spec: vertical gradient bg #14161a → #0e0f12,
            // line border, inset top highlight, drop-shadow stack.
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

    private var scheduledTopLine: String {
        let league = pick.league.uppercased()
        switch league {
        case "EPL": return "EPL · MATCHDAY"
        case "NFL": return "NFL · PRIMETIME"
        case "MLB": return "MLB · TODAY"
        case "NBA": return "NBA · TONIGHT"
        case "NHL": return "NHL · TONIGHT"
        case "UFC": return "UFC · MAIN CARD"
        case "F1":  return "F1 · RACE WEEKEND"
        case "IPL": return "IPL · MATCH DAY"
        default:    return league
        }
    }

    private func livePulseText(_ s: LiveScore) -> String {
        let q = s.quarter.flatMap { Int($0) }.map { "Q\($0)" } ?? (s.status ?? "LIVE").uppercased()
        return "LIVE · \(q)"
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
            Text(teamShortName(team))
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
    let isLive: Bool
    let score: LiveScore?

    var body: some View {
        if isLive, let s = score, let h = s.homeScore, let a = s.awayScore {
            HStack(spacing: 8) {
                Text("\(a)").font(.anton(28)).tracking(-0.28)
                    .foregroundColor(Color(hex: "#F5F3EE"))
                Text("–").font(.archivoNarrow(16, weight: .bold))
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text("\(h)").font(.anton(28)).tracking(-0.28)
                    .foregroundColor(pickWon(home: h, away: a, pick: pick) ? Color(hex: "#D4FF3A") : Color(hex: "#F5F3EE"))
            }
        } else {
            VStack(spacing: 2) {
                Text("VS")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(timeText)
                    .font(.mono(11, weight: .bold))
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }
        }
    }

    private var timeText: String {
        // Use createdAt as a placeholder for tip/start time in absence of an explicit field
        guard let date = pick.createdAt else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func pickWon(home: Int, away: Int, pick: Pick) -> Bool {
        let pickedHome = pick.pick.lowercased().contains(pick.homeTeam.lowercased())
            || pick.homeTeam.lowercased().contains(pick.pick.lowercased())
        return pickedHome ? home > away : away > home
    }
}

struct MiniRing: View {
    let percent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "#2D3038"), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.05, min(1, percent / 100)))
                .stroke(Color(hex: "#D4FF3A"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent.rounded()))")
                .font(.mono(11, weight: .heavy))
                .foregroundColor(Color(hex: "#F5F3EE"))
        }
        .frame(width: 38, height: 38)
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

    var body: some View {
        HStack(spacing: 2) {
            NavItem(icon: "house",
                    label: "Home",
                    isActive: tab == .home) { tab = .home }
            NavItem(icon: "star",
                    label: "Picks",
                    isActive: tab == .picks) { tab = .picks }
            LiveNavItem(isActive: tab == .live,
                        liveCount: liveCount) { tab = .live }
            NavItem(icon: "person",
                    label: "Profile",
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
        .glassEffect(
            .regular
                .tint(Color(hex: "#16181C").opacity(0.55)),
            in: .capsule
        )
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
                    Text("7-day free trial")
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
                ZStack {
                    Color(hex: "#D4FF3A")
                    RadialGradient(
                        colors: [Color(hex: "#eaff7a"), Color(hex: "#D4FF3A").opacity(0)],
                        center: UnitPoint(x: 1.1, y: -0.2),
                        startRadius: 30,
                        endRadius: 350
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color(hex: "#a8e000").opacity(0.35), radius: 14, x: 0, y: 12)
        }
        .buttonStyle(.plain)
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
                            Text(teamShortName(pick.awayTeam))
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
                            Text(teamShortName(pick.homeTeam))
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
                            Text(pick.pick.uppercased())
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
        let league = pick.league.uppercased()
        switch league {
        case "EPL": return "EPL · MATCHDAY"
        case "NFL": return "NFL · PRIMETIME"
        case "MLB": return "MLB · TODAY"
        case "NBA": return "NBA · TONIGHT"
        case "NHL": return "NHL · TONIGHT"
        case "UFC": return "UFC · MAIN CARD"
        case "F1":  return "F1 · RACE WEEKEND"
        case "IPL": return "IPL · MATCH DAY"
        default:    return league
        }
    }
}

// MARK: - Empty + Profile placeholder

struct EmptyTodayState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.fill")
                .font(.system(size: 38))
                .foregroundColor(Color(hex: "#6E6F75"))
            Text("PICKS GENERATING")
                .font(.archivoNarrow(13, weight: .bold))
                .tracking(2.2)
                .foregroundColor(Color(hex: "#F5F3EE"))
            Text("New picks drop 3× daily — 5am, 12pm, 7pm ET")
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
