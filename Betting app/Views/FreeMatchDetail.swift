// FreeMatchDetail.swift
// The FREE user's game detail — the "tease" page (2026-07 design).
// Structure: matchup header → RECENT FORM (free, real data) → PICK1'S
// CALL (locked gold card) → WHY · CONFIDENCE BREAKDOWN (locked rows) →
// gold trial-aware unlock CTA. Every piece of visible data is real; the
// AI's side and reasoning are what's behind the lock.

import SwiftUI

struct FreeMatchDetailView: View {
    let pick: Pick
    let onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subs: SubscriptionManager
    /// Star → the same favorites rail as the pro detail ("Track your Pick").
    @EnvironmentObject private var favorites: FavoritesStore
    @StateObject private var betTracker = BetTracker.shared
    @State private var showTrackSheet = false

    private var isTracking: Bool {
        favorites.contains(pick.id) || betTracker.isTracked(pick.id)
    }

    private let gold = Color(hex: "#E8C64A")
    private let lime = Color(hex: "#C6FF34")

    var body: some View {
        GeometryReader { geo in
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    matchupCard
                    recentForm
                    pick1sCall
                    whyBreakdown
                }
            .frame(width: UIScreen.main.bounds.width)
                .padding(.horizontal, 18)
                .padding(.top, 14)
                // Clear the sticky CTA bar so the last section never hides.
                .padding(.bottom, 130)
                // Pin the content box to the container width — same fix as
                // MatchDetailView: any child wider than the screen otherwise
                // lets the vertical ScrollView pan sideways. Clamped, the
                // page can only scroll up/down; overflow clips.
                .frame(width: geo.size.width)
            }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
        }
        .background(Color(hex: "#171717").ignoresSafeArea())
        // Sticky unlock bar — pinned while the page scrolls, with a fade
        // into the content above.
        .overlay(alignment: .bottom) {
            unlockCTA
                .padding(.horizontal, 18)
                .padding(.top, 26)
                .padding(.bottom, 14)
                .background(
                    LinearGradient(colors: [Color(hex: "#171717").opacity(0),
                                            Color(hex: "#171717").opacity(0.94),
                                            Color(hex: "#171717")],
                                   startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                )
        }
        .sheet(isPresented: $showTrackSheet) {
            TrackBetSheet(
                pick: pick,
                accent: lime,
                onTrack: { stake in
                    favorites.set(pick, on: true)
                    Task { await betTracker.track(pick: pick, stake: stake) }
                },
                isTracked: isTracking,
                onUntrack: {
                    favorites.set(pick, on: false)
                    Analytics.pickUntracked(league: pick.league, sport: pick.sport)
                    Task { await betTracker.untrack(pickId: pick.id) }
                }
            )
            .presentationDetents([.height(isTracking ? 420 : 360)])
            .onAppear {
                Analytics.trackSheetViewed(league: pick.league, alreadyTracked: isTracking)
            }
        }
        .task { if !betTracker.loaded { await betTracker.load() } }
    }

    // ── Top bar ──────────────────────────────────────────────────────
    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: "#242424")))
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                Haptics.tap()
                showTrackSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isTracking ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 13, weight: .bold))
                    Text(isTracking ? t(.rd_tracking) : t(.rd_track_your_pick))
                        .font(.archivoNarrow(10, weight: .bold)).tracking(1.2)
                }
                .foregroundColor(isTracking ? Color(hex: "#171717") : lime)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(Capsule().fill(isTracking ? lime : Color(hex: "#242424"))
                    .overlay(Capsule().stroke(lime.opacity(isTracking ? 0 : 0.5), lineWidth: 1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }

    // ── Matchup header card (shared component) ───────────────────────
    private var matchupCard: some View { MatchupHeaderCard(pick: pick) }

    // ── RECENT FORM (shared section body) ────────────────────────────
    private var recentForm: some View { RecentFormSection(pick: pick, chip: "FREE") }

    private var recentFormLegacyBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead("RECENT FORM", chip: "FREE", chipColor: lime, chipInk: Color(hex: "#171717"))
            if let sc = pick.soccerComparison,
               let aBadges = formBadges(sc.away?.record), let hBadges = formBadges(sc.home?.record) {
                formRow(team: pick.awayTeam, badges: aBadges)
                formRow(team: pick.homeTeam, badges: hBadges)
            } else if let facts = pick.matchupFacts, !facts.isEmpty {
                // No parseable per-team form — show the real matchup facts.
                ForEach(facts.prefix(3)) { f in
                    HStack {
                        Text(f.label.uppercased())
                            .font(.archivoNarrow(11, weight: .bold)).tracking(0.8)
                            .foregroundColor(Color(hex: "#9A9B9F"))
                        Spacer(minLength: 12)
                        Text(f.value)
                            .font(.archivo(13, weight: .bold)).foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1E1E1E"))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#292929"), lineWidth: 1)))
                }
            } else {
                formRow(team: pick.awayTeam, badges: nil)
                formRow(team: pick.homeTeam, badges: nil)
            }
        }
    }

    /// "W-D-L" count record → badge letters (composition is real; we don't
    /// have the game-by-game order, so render wins first).
    private func formBadges(_ record: String?) -> [Character]? {
        guard let record else { return nil }
        let parts = record.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let (w, d, l) = (parts[0], parts[1], parts[2])
        guard w + d + l > 0 else { return nil }
        var out: [Character] = []
        out.append(contentsOf: Array(repeating: "W", count: w))
        out.append(contentsOf: Array(repeating: "D", count: d))
        out.append(contentsOf: Array(repeating: "L", count: l))
        return Array(out.prefix(5))
    }

    private func formRow(team: String, badges: [Character]?) -> some View {
        HStack(spacing: 12) {
            TeamLogo(sport: pick.sport, team: team, size: .small)
            Text(short(team).capitalized)
                .font(.archivo(15, weight: .bold)).foregroundColor(.white)
            Spacer(minLength: 10)
            if let badges {
                HStack(spacing: 5) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { _, c in
                        Text(String(c))
                            .font(.archivoNarrow(11, weight: .bold))
                            .foregroundColor(c == "L" ? .white : Color(hex: "#171717"))
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(
                                c == "W" ? Color(hex: "#34D26B")
                                : c == "D" ? Color(hex: "#3A3D44")
                                : Color(hex: "#E8563F")))
                    }
                }
            } else {
                Text("—").foregroundColor(Color(hex: "#6E6F75"))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1E1E1E"))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#292929"), lineWidth: 1)))
    }

    // ── PICK1'S CALL (locked) ────────────────────────────────────────
    private var pick1sCall: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead("PICK1'S CALL", chip: "PREMIUM", chipColor: Color(hex: "#2A230F"), chipInk: gold)
            Button { Haptics.tap(); onUnlock() } label: {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(gold)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().stroke(gold.opacity(0.7), lineWidth: 1.2))
                    HStack(spacing: 12) {
                        blurBlob(width: 74)
                        Text(t(.rd_see_pick1s_call))
                            .font(.anton(20)).foregroundColor(.white)
                        blurBlob(width: 52)
                    }
                    Text(t(.rd_free_lock_copy))
                        .font(.archivo(13)).foregroundColor(Color(hex: "#CDb98A").opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 18)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#241D0B"), Color(hex: "#151107")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 20)
                            .stroke(gold.opacity(0.45), lineWidth: 1))
                )
                .pressableScale(0.99)
            }
            .buttonStyle(.plain)
        }
    }

    /// Soft gold blur blob — stands in for the hidden pick text.
    private func blurBlob(width: CGFloat) -> some View {
        Capsule()
            .fill(gold.opacity(0.5))
            .frame(width: width, height: 16)
            .blur(radius: 7)
    }

    // ── WHY · CONFIDENCE BREAKDOWN (locked) ──────────────────────────
    private var whyBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHead("WHY · CONFIDENCE BREAKDOWN", chip: "PREMIUM", chipColor: Color(hex: "#2A230F"), chipInk: gold)
            ForEach(whyRows, id: \.self) { title in
                Button { Haptics.tap(); onUnlock() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(gold)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .stroke(gold.opacity(0.5), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.archivo(14, weight: .bold)).foregroundColor(.white)
                            Text(t(.rd_hidden))
                                .font(.archivo(11)).foregroundColor(Color(hex: "#6E6F75"))
                        }
                        Spacer(minLength: 10)
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(gold.opacity(0.25))
                                    .frame(width: 12, height: 7)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1E1E1E"))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#292929"), lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Sport-appropriate hidden-factor titles.
    private var whyRows: [String] {
        switch pick.sport {
        case "soccer":     return ["Form & momentum", "Expected goals edge", "Injuries & lineups"]
        case "baseball":   return ["Pitching matchup", "Bullpen & recent form", "Lineups & injuries"]
        case "basketball": return ["Form & momentum", "Matchup edge", "Injuries & rotations"]
        case "football":   return ["Form & momentum", "Matchup edge", "Injuries & depth chart"]
        case "hockey":     return ["Goaltending matchup", "Form & special teams", "Injuries & lines"]
        case "combat":     return ["Style matchup", "Reach & record edge", "Camp & weight cut"]
        case "f1":         return ["Qualifying pace", "Race pace & tyres", "Track history"]
        default:           return ["Form & momentum", "Statistical edge", "Injuries & availability"]
        }
    }

    // ── CTA ──────────────────────────────────────────────────────────
    private var unlockCTA: some View {
        VStack(spacing: 9) {
            Button { Haptics.tap(); onUnlock() } label: {
                Text(subs.introOfferEligible ? t(.rd_unlock_pick_trial) : t(.rd_unlock_pick))
                    .font(.anton(17)).kerning(0.3)
                    .foregroundColor(Color(hex: "#14110A"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(LinearGradient(colors: [Color(hex: "#F2D468"), gold],
                                             startPoint: .top, endPoint: .bottom)))
                    .pressableScale(0.985)
            }
            .buttonStyle(.plain)
            Text(subs.introOfferEligible
                 ? "then $14.99/wk · cancel anytime"
                 : "plans from $2.99 · cancel anytime")
                .font(.mono(10, weight: .medium))
                .foregroundColor(Color(hex: "#8A8D94"))
        }
        .padding(.top, 4)
    }

    // ── Helpers ──────────────────────────────────────────────────────
    private func sectionHead(_ title: String, chip: String, chipColor: Color, chipInk: Color) -> some View {
        HStack {
            Text(title).font(.anton(19)).foregroundColor(.white)
            Spacer()
            Text(chip)
                .font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                .foregroundColor(chipInk)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(chipColor))
        }
    }
    private func short(_ team: String) -> String {
        teamShortName(team, sport: pick.sport).uppercased()
    }
    private var dayLabel: String {
        let todayFmt = DateFormatter()
        todayFmt.dateFormat = "yyyy-MM-dd"
        todayFmt.timeZone = TimeZone(identifier: "America/New_York")
        let today = todayFmt.string(from: Date())
        if pick.gameDate == today { return "TODAY" }
        let tomorrow = todayFmt.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        return pick.gameDate == tomorrow ? "TOMORROW" : pick.gameDate
    }
    /// Was an emoji map. Sport marks now come from `P1Symbol` so every
    /// surface draws one stroke weight in the app's own colours.
    private var sportSymbol: String { P1Symbol.sport(pick.sport) }
}


// MARK: - Shared matchup components (free tease + premium detail)

/// The blue-tinted matchup header: league · day kicker, big team marks with
/// names under each, VS between, day + real kickoff line.
struct MatchupHeaderCard: View {
    let pick: Pick

    /// Golf / F1 are field events: `away_team` is "Field" and `home_team`
    /// is the tournament/race, so a two-column "X VS Field" header showed
    /// two grey silhouettes. Instead we feature the PICKED competitor
    /// (pick.pick) with their headshot, and name the event underneath.
    private var isFieldEvent: Bool {
        pick.sport == "f1" || pick.sport == "golf"
            || pick.awayTeam.lowercased() == "field"
            || pick.homeTeam.lowercased() == "field"
    }

    var body: some View {
        VStack(spacing: 14) {
            // League + day is metadata, not an action, so it reads in the
            // home's muted grey rather than in an accent. The sport still
            // shows, as the bloom behind this card.
            Text("\(pick.league.uppercased()) · \(dayLabel)")
                .font(.archivoNarrow(11, weight: .bold)).tracking(2.4)
                .foregroundColor(V4.ink2)
            if isFieldEvent {
                // Single featured competitor + event name.
                VStack(spacing: 10) {
                    AthleteHeadshot(sport: pick.sport, name: pick.pick, size: .big)
                    Text(pick.shortDisplayPick.uppercased())
                        .font(.anton(22)).foregroundColor(.white)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: 240)
                    Text(eventName.uppercased())
                        .font(.archivoNarrow(11, weight: .bold)).tracking(1.4)
                        .foregroundColor(V4.mute)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: 260)
                }
            } else {
                HStack(alignment: .top, spacing: 26) {
                    column(pick.awayTeam)
                    Text("VS")
                        .font(.anton(20)).foregroundColor(V4.mute)
                        .padding(.top, 26)
                    column(pick.homeTeam)
                }
            }
            Text(pick.localizedScheduleDisplay ?? dayLabel)
                .font(.mono(11, weight: .bold)).tracking(1.2)
                .foregroundColor(V4.mute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [V4.panelTop, V4.panelBot],
                                     startPoint: .top, endPoint: .bottom))
                // Sport identity is a bloom, not a tint — the same move the
                // home makes on its orbs and hero card.
                .overlay(alignment: .top) {
                    Ellipse()
                        .fill(RadialGradient(colors: [V4.glow(pick.sport).opacity(0.20), .clear],
                                             center: .center, startRadius: 0, endRadius: 130))
                        .frame(width: 300, height: 190)
                        .offset(y: -80)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(V4.line, lineWidth: 1))
        )
    }

    /// The tournament / race name for a field event — whichever side
    /// isn't the "Field" placeholder.
    private var eventName: String {
        if pick.homeTeam.lowercased() == "field" { return pick.awayTeam }
        if pick.awayTeam.lowercased() == "field" { return pick.homeTeam }
        return pick.homeTeam
    }

    private func column(_ team: String) -> some View {
        VStack(spacing: 10) {
            TeamLogo(sport: pick.sport, team: team, size: .big)
            Text(teamShortName(team, sport: pick.sport).uppercased())
                .font(.anton(18)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(maxWidth: 120)
        }
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        let today = f.string(from: Date())
        if pick.gameDate == today { return "TODAY" }
        let tomorrow = f.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        return pick.gameDate == tomorrow ? "TOMORROW" : pick.gameDate
    }
}

/// RECENT FORM: soccer W/D/L badges from grounded records, or the real
/// matchup facts for every other sport. `chip` labels the section (FREE on
/// the tease, hidden when nil on premium).
struct RecentFormSection: View {
    let pick: Pick
    var chip: String? = nil
    private let lime = Color(hex: "#C6FF34")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t(.rd_recent_form)).font(.anton(19)).foregroundColor(.white)
                Spacer()
                if let chip {
                    Text(chip)
                        .font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                        .foregroundColor(Color(hex: "#171717"))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Capsule().fill(lime))
                }
            }
            if let sc = pick.soccerComparison,
               let a = badges(sc.away?.record), let h = badges(sc.home?.record) {
                row(team: pick.awayTeam, badges: a)
                row(team: pick.homeTeam, badges: h)
            } else if let facts = pick.matchupFacts, !facts.isEmpty {
                ForEach(facts.prefix(3)) { f in
                    HStack {
                        Text(f.label.uppercased())
                            .font(.archivoNarrow(11, weight: .bold)).tracking(0.8)
                            .foregroundColor(Color(hex: "#9A9B9F"))
                        Spacer(minLength: 12)
                        Text(f.value)
                            .font(.archivo(13, weight: .bold)).foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1E1E1E"))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#292929"), lineWidth: 1)))
                }
            }
        }
    }

    private func badges(_ record: String?) -> [Character]? {
        guard let record else { return nil }
        let parts = record.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts.reduce(0, +) > 0 else { return nil }
        var out: [Character] = []
        out.append(contentsOf: Array(repeating: "W", count: parts[0]))
        out.append(contentsOf: Array(repeating: "D", count: parts[1]))
        out.append(contentsOf: Array(repeating: "L", count: parts[2]))
        return Array(out.prefix(5))
    }

    private func row(team: String, badges: [Character]) -> some View {
        HStack(spacing: 12) {
            TeamLogo(sport: pick.sport, team: team, size: .small)
            Text(teamShortName(team, sport: pick.sport).capitalized)
                .font(.archivo(15, weight: .bold)).foregroundColor(.white)
            Spacer(minLength: 10)
            HStack(spacing: 5) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, c in
                    Text(String(c))
                        .font(.archivoNarrow(11, weight: .bold))
                        .foregroundColor(c == "L" ? .white : Color(hex: "#171717"))
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(
                            c == "W" ? Color(hex: "#34D26B")
                            : c == "D" ? Color(hex: "#3A3D44")
                            : Color(hex: "#E8563F")))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1E1E1E"))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#292929"), lineWidth: 1)))
    }
}
