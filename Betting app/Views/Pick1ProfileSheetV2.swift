//  Pick1ProfileSheetV2.swift
//  "Home v2 — Switch Style" — the profile sheet (`.psheet` in the mockup)
//
//  Header, three stat tiles, "Your picks", "Rewards", "Settings".
//
//  The header, the stat tiles and the picks list run on real data. The Rewards
//  section does not: streak shields, longshot unlocks and league points are
//  part of the gamification systems that have no backend, so their values come
//  from `GamificationV2Placeholders` like every other invented number.

import SwiftUI

struct P1ProfileRowV2: View {
    let emoji: String
    let title: String
    let subtitle: String
    let value: String
    var valueColor: Color = .p1Lime
    var onTap: (() -> Void)?

    var body: some View {
        let row = HStack(spacing: 12) {
            Text(emoji).font(.system(size: 19))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.archivoNarrow(13, weight: .bold))
                    .foregroundStyle(Color.p1Foreground)
                Text(subtitle.uppercased())
                    .font(.archivoNarrow(10.5, weight: .bold))
                    .tracking(0.63)
                    .foregroundStyle(Color.p1Mute)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.mono(12, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.p1Line, lineWidth: 1))

        if let onTap {
            Button(action: onTap) { row.contentShape(RoundedRectangle(cornerRadius: 14)) }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}

struct P1StatTileV2: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.anton(24))
                .foregroundStyle(Color.p1Lime)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(1.26)
                .foregroundStyle(Color.p1Mute)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.p1Panel))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.p1Line, lineWidth: 1))
    }
}

struct Pick1ProfileSheetV2: View {
    @ObservedObject var vm: PicksViewModel
    @EnvironmentObject private var subs: SubscriptionManager
    @Environment(AuthManager.self) private var auth: AuthManager?
    var onClose: () -> Void = {}
    var onManagePremium: () -> Void = {}

    private let placeholders = GamificationV2Placeholders.shared

    private var displayName: String {
        let name = auth?.displayName ?? ""
        return name.isEmpty ? "Pick1 member" : name
    }

    private var initials: String {
        let words = displayName.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" })
        if words.count >= 2 { return words.prefix(2).map { String($0.prefix(1)) }.joined().uppercased() }
        return String(displayName.prefix(2)).uppercased()
    }

    /// This calendar month's settled record, in ET (the pipeline's zone), so
    /// the tile matches the dates shown on every pick.
    private var monthRecord: (w: Int, l: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date()))
        let picks = vm.historyPicks.filter { p in
            guard !p.isPending, let start, let d = p.gameDateValue else { return false }
            return d >= start
        }
        return (picks.filter(\.isWin).count, picks.filter(\.isLoss).count)
    }

    private var recentPicks: [Pick] {
        Array((vm.todayPicks + vm.historyPicks).prefix(6))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(colors: [Color(hex: "#1D2026"), Color.p1Ink],
                           center: .init(x: 0.5, y: -0.08), startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        Text(initials)
                            .font(.anton(24))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                Circle().fill(
                                    LinearGradient(colors: [Color.p1Violet, Color(hex: "#4C2A9E")],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            )
                            .shadow(color: Color.p1Violet.opacity(0.4), radius: 15)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.uppercased())
                                .font(.anton(26))
                                .foregroundStyle(Color.p1Foreground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            (
                                Text("Member · ".uppercased()).foregroundStyle(Color.p1Mute)
                                + Text(subs.isPro ? "Premium".uppercased() : "Free".uppercased())
                                    .foregroundStyle(Color.p1Lime)
                            )
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.54)
                        }
                    }

                    HStack(spacing: 10) {
                        P1StatTileV2(value: "\(vm.currentStreak)", label: "Day streak")
                        P1StatTileV2(value: "\(Int(vm.winRate.rounded()))%", label: "Hit rate")
                        P1StatTileV2(value: "\(monthRecord.w)-\(monthRecord.l)", label: "This month")
                    }
                    .padding(.top, 20)

                    section("Your picks") {
                        ForEach(recentPicks) { p in
                            P1ProfileRowV2(emoji: emoji(p.sport),
                                           title: p.shortDisplayPick,
                                           subtitle: subtitleFor(p),
                                           value: resultLabel(p),
                                           valueColor: resultColor(p))
                        }
                    }

                    section("Rewards") {
                        P1ProfileRowV2(emoji: "🛡️", title: "Streak shields",
                                       subtitle: "Protect a missed day",
                                       value: "× \(placeholders.streakShields)")
                        P1ProfileRowV2(emoji: "🎯", title: "Longshot unlocks",
                                       subtitle: "From daily spins",
                                       value: "× \(placeholders.longshotUnlocks)")
                        P1ProfileRowV2(emoji: "⭐", title: "League points",
                                       subtitle: "\(placeholders.leagueName) · rank \(placeholders.leagueRank)",
                                       value: placeholders.leaguePoints.formatted())
                    }

                    section("Settings") {
                        P1ProfileRowV2(emoji: "🔔", title: "Notifications",
                                       subtitle: "Daily pick alert",
                                       value: "›", valueColor: Color.p1Mute) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        P1ProfileRowV2(emoji: "💎", title: subs.isPro ? "Manage Premium" : "Get Premium",
                                       subtitle: subs.isPro ? "Manage in the App Store" : "Every sport · every market",
                                       value: "›", valueColor: Color.p1Mute,
                                       onTap: onManagePremium)
                        P1ProfileRowV2(emoji: "🎁", title: "Referral code",
                                       subtitle: "Give 3 days · get 3 days",
                                       value: placeholders.referralCode)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 22)
                .padding(.top, 70)
            }

            Button(action: onClose) {
                Text("✕")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.p1Foreground)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.p1Panel))
                    .overlay(Circle().strokeBorder(Color.p1Line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 66)
            .padding(.trailing, 20)
            .accessibilityLabel("Close")
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.anton(16))
                .foregroundStyle(Color.p1Foreground)
                .padding(.bottom, 2)
            content()
        }
        .padding(.top, 20)
    }

    private func subtitleFor(_ p: Pick) -> String {
        if let h = p.homeScore, let a = p.awayScore, !p.isPending {
            return "\(p.gameDate) · \(max(h, a))–\(min(h, a))"
        }
        return [p.localizedScheduleDisplay, p.league].compactMap { $0 }.joined(separator: " · ")
    }

    private func resultLabel(_ p: Pick) -> String {
        if p.isWin { return "✓ WON" }
        if p.isLoss { return "✗ LOST" }
        return "PENDING"
    }

    private func resultColor(_ p: Pick) -> Color {
        if p.isWin { return .p1Win }
        if p.isLoss { return .p1Hot }
        return .p1Lime
    }

    private func emoji(_ sport: String) -> String {
        switch sport {
        case "basketball": return "🏀"; case "baseball": return "⚾️"
        case "hockey": return "🏒";     case "football": return "🏈"
        case "soccer": return "⚽️";     case "combat": return "🥊"
        case "f1": return "🏎️";         case "golf": return "⛳️"
        case "cricket": return "🏏";    case "tennis": return "🎾"
        default: return "🎯"
        }
    }
}
