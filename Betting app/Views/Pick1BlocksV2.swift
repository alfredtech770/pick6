//  Pick1BlocksV2.swift
//  "Home v2 — Switch Style" — the engagement blocks
//
//  Ports the mockup's remaining home modules: the coin pill, the daily-spin
//  row, the XP / league bar, the "Back tonight's pick" staking card, the
//  longshot teaser, tomorrow's locked pick, the miss nudge, the weekly
//  leaderboard, and the rewards-shop row.
//
//  ⚠️ READ THIS BEFORE SHIPPING ANY OF IT.
//
//  Six product systems drive these blocks — a coin ledger, XP/levels, a daily
//  spin, streak shields, a staking loop and a weekly leaderboard — and NONE of
//  them exist in Supabase. There is no table, no edge function and no write
//  path for any of it. Every number below therefore comes from
//  `GamificationV2Placeholders`, which is deliberately one struct in one file
//  so it is obvious what is real and what is scaffolding.
//
//  These blocks render only behind `-showHomeV2`. Putting them in front of
//  users as-is would show a coin balance that never changes, a leaderboard of
//  invented people, and a "Back it" button that stakes nothing.

import SwiftUI

// MARK: - Placeholder state

/// Everything the mockup hard-codes and no backend provides.
struct GamificationV2Placeholders {
    var coinBalance = 2_450
    var level = 2
    var leagueName = "Diamond League"
    var xp = 1_240
    var xpTarget = 2_000
    var spinDay = 8
    var spinUsed = false
    var streakShields = 2
    var longshotUnlocks = 1
    var leaguePoints = 1_240
    var leagueRank = 14
    var referralCode = "PICK13"
    var missedWins = 3
    var missedReturn = "5.8×"
    var leaders: [(rank: Int, initials: String, name: String, meta: String, hitRate: Int, isMe: Bool)] = [
        (1, "DK", "Dan K.", "Gold L4 · 12-1 this week", 92, false),
        (2, "SR", "Sofia R.", "Diamond L3 · 10-2 this week", 83, false),
        (14, "ME", "You", "Diamond L2 · 6-2 this week", 75, true),
    ]

    static let shared = GamificationV2Placeholders()
}

private let coinGold = Color(hex: "#FFD84D")
private let violetSoft = Color(hex: "#C4A8FF")

// MARK: - Coin pill

struct P1CoinPillV2: View {
    let balance: Int
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text("🪙").font(.system(size: 11))
                Text(balance.formatted(.number.grouping(.automatic)))
                    .font(.mono(11, weight: .bold))
                    .foregroundStyle(coinGold)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [coinGold.opacity(0.18), coinGold.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .overlay(Capsule().strokeBorder(coinGold.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Daily spin

struct P1DailySpinV2: View {
    let day: Int
    let used: Bool
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text("🎁")
                    .font(.system(size: 24))
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(
                            LinearGradient(colors: [Color.p1Lime, Color(hex: "#8FC218")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .grayscale(used ? 0.4 : 0)
                    .shadow(color: Color.p1Lime.opacity(0.3), radius: 10, y: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text("DAILY SPIN")
                        .font(.anton(16))
                        .foregroundStyle(Color.p1Foreground)
                    (
                        Text("Day \(day) streak · ".uppercased())
                            .foregroundStyle(Color.p1Mute)
                        + Text(used ? "come back tomorrow".uppercased() : "spin for today's reward".uppercased())
                            .foregroundStyle(used ? Color.p1Mute : Color.p1Lime)
                    )
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(0.88)
                    .lineLimit(1)
                    // Inter is wider than Archivo Narrow was, so this needs
                    // more headroom to shrink before it truncates.
                    .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 8)

                Text(used ? "DONE" : "SPIN")
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.p1Ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.p1Lime))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(
                    LinearGradient(colors: [Color(hex: "#1C1F24"), Color(hex: "#101114")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.p1Lime.opacity(0.35), lineWidth: 1)
            )
            .opacity(used ? 0.6 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(used)
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }
}

// MARK: - XP / league bar

struct P1XPRowV2: View {
    let level: Int
    let league: String
    let xp: Int
    let target: Int
    @State private var filled = false

    var body: some View {
        HStack(spacing: 10) {
            Text("💎 L\(level)")
                .font(.anton(15))
                .foregroundStyle(Color.p1Lime)
                .fixedSize()

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(league.uppercased())
                    Spacer(minLength: 8)
                    Text("\(xp.formatted()) / \(target.formatted()) XP · L\(level + 1)")
                }
                .font(.mono(9, weight: .bold))
                .tracking(0.72)
                .foregroundStyle(Color.p1Mute)

                GeometryReader { geo in
                    Capsule().fill(.white.opacity(0.08))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(colors: [Color.p1Lime, Color(hex: "#7EE000")],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: filled ? geo.size.width * CGFloat(xp) / CGFloat(max(target, 1)) : 0)
                        }
                }
                .frame(height: 7)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "#15171C")))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.p1Line, lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.bottom, 14)
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 1.2)) { filled = true }
        }
    }
}

// MARK: - Back it

/// The staking card. `onStake` is intentionally a no-op at the call site:
/// there is no coin ledger to debit and no settlement job to credit a win, so
/// the button must not appear to do something it cannot do.
struct P1BackItV2: View {
    let pick: Pick
    @State private var stake = 250
    private let stakes = [100, 250, 500, 1000]

    private var payout: Int { Int(Double(stake) * pick.decimalOdds) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("🪙 BACK TONIGHT'S PICK")
                    .font(.anton(17))
                    .foregroundStyle(Color.p1Foreground)
                Spacer(minLength: 8)
                Text("\(pick.shortDisplayPick.uppercased()) · \(Int(pick.probability.rounded()))%")
                    .font(.mono(9, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(Color.p1Mute)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                ForEach(stakes, id: \.self) { s in
                    Button { stake = s } label: {
                        Text(s.formatted())
                            .font(.mono(12, weight: .bold))
                            .foregroundStyle(s == stake ? Color.p1Ink : coinGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(s == stake ? coinGold : coinGold.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(s == stake ? coinGold : coinGold.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)

            HStack {
                Text("If it hits, you win")
                    .font(.archivoNarrow(12, weight: .bold))
                    .foregroundStyle(Color.p1Mute)
                Spacer(minLength: 8)
                Text("🪙 \(payout.formatted())")
                    .font(.anton(20))
                    .foregroundStyle(Color.p1Win)
            }
            .padding(.top, 12)

            Text("BACK IT · \(stake.formatted()) 🪙")
                .font(.anton(15))
                .tracking(0.6)
                .foregroundStyle(Color.p1Ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(coinGold))
                .padding(.top, 12)

            Text("PICK1 COINS · NO CASH VALUE · REDEEM FOR REWARDS ONLY")
                .font(.mono(8.5, weight: .bold))
                .tracking(0.34)
                .foregroundStyle(Color.p1Mute)
                .multilineTextAlignment(.center)
                .padding(.top, 9)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: "#15171C")))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(coinGold.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }
}

// MARK: - Longshot teaser

/// The mockup blurs the headline to tease a locked pick. Here the blur covers
/// a *real* long-odds call from today's board, so unlocking it reveals
/// something that actually exists.
struct P1LongshotV2: View {
    let pick: Pick
    var isLocked: Bool = true
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text("🎯 LONGSHOT OF THE DAY · HIGH RETURN")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(violetSoft)
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Capsule().fill(Color.p1Violet.opacity(0.18)))
                    .overlay(Capsule().strokeBorder(Color.p1Violet.opacity(0.5), lineWidth: 1))

                Text("\(pick.shortDisplayPick.uppercased()) \(String(format: "%.1f×", pick.decimalOdds))")
                    .font(.anton(24))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 12)
                    .blur(radius: isLocked ? 7 : 0)

                Text("\(pick.league.uppercased()) · \(Int(pick.probability.rounded()))% MODEL PROBABILITY")
                    .font(.archivoNarrow(12, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.p1Ink2)
                    .padding(.top, 5)
                    .blur(radius: isLocked ? 5 : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                LinearGradient(colors: [Color(hex: "#2A1148"), Color(hex: "#0E0F12")],
                               startPoint: .topLeading, endPoint: .bottom)
            )
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(RadialGradient(colors: [Color.p1Violet.opacity(0.28), .clear],
                                         center: .center, startRadius: 0, endRadius: 130))
                    .frame(width: 260, height: 260)
                    .offset(x: 90, y: -90)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .trailing) {
                if isLocked {
                    VStack(spacing: 4) {
                        Text("🔒").font(.system(size: 22))
                        Text("PREMIUM")
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(violetSoft)
                    }
                    .padding(.trailing, 18)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.p1Violet.opacity(0.45), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }
}

// MARK: - Tomorrow's pick

struct P1TomorrowV2: View {
    let headline: String
    let meta: String
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text("🌙 TOMORROW'S PICK · DROPS TONIGHT 9 PM")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(Color(hex: "#B9A6FF"))
                    .lineLimit(2)
                    // Clearance for the premium badge pinned to this corner.
                    .padding(.trailing, 150)

                Text(headline)
                    .font(.anton(22))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.top, 6)
                    .blur(radius: 7)

                Text(meta)
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 6)
                    .blur(radius: 5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                LinearGradient(colors: [Color(hex: "#1A1440"), Color(hex: "#0E0B24")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(alignment: .bottomTrailing) {
                Text("🌙")
                    .font(.system(size: 64))
                    .opacity(0.5)
                    .offset(x: -6, y: 18)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                Text("🔒 PREMIUM SEES IT FIRST")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color(hex: "#D9CCFF"))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.p1Violet.opacity(0.25)))
                    .overlay(Capsule().strokeBorder(Color.p1Violet.opacity(0.6), lineWidth: 1))
                    .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.p1Violet.opacity(0.45), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }
}

// MARK: - Nudge

struct P1NudgeV2: View {
    let icon: String
    let leading: String
    let highlight: String
    let trailing: String
    let cta: String
    var tint: Color = .p1Hot
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(icon).font(.system(size: 22))
                (
                    Text(leading).foregroundStyle(Color.p1Foreground)
                    + Text(highlight).foregroundStyle(tint == .p1Hot ? Color(hex: "#FF7A5C") : coinGold)
                    + Text(trailing).foregroundStyle(Color.p1Foreground)
                )
                .font(.archivoNarrow(12.5, weight: .semibold))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(cta)
                    .font(.anton(13))
                    .foregroundStyle(tint == .p1Hot ? Color.p1Lime : coinGold)
                    .fixedSize()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(
                    LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(0.4), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }
}

// MARK: - Leaderboard

struct P1LeaderboardV2: View {
    let rows: [(rank: Int, initials: String, name: String, meta: String, hitRate: Int, isMe: Bool)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("THIS WEEK'S LEADERS")
                    .font(.anton(19))
                    .foregroundStyle(Color.p1Foreground)
                Text("BY HIT RATE")
                    .font(.mono(9, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(Color.p1Mute)
            }
            .padding(.bottom, 2)

            ForEach(rows, id: \.rank) { r in
                HStack(spacing: 11) {
                    Text("\(r.rank)")
                        .font(.anton(16))
                        .foregroundStyle(r.isMe ? Color.p1Lime : Color.p1Mute)
                        .frame(minWidth: 22, alignment: .leading)
                    Text(r.initials)
                        .font(.anton(11))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(
                                LinearGradient(colors: [Color(hex: "#2A2F3A"), Color(hex: "#171A21")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        )
                        .overlay(Circle().strokeBorder(Color.p1Line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.name)
                            .font(.archivoNarrow(13, weight: .bold))
                            .foregroundStyle(Color.p1Foreground)
                        Text(r.meta)
                            .font(.archivoNarrow(10, weight: .semibold))
                            .foregroundStyle(Color.p1Mute)
                    }
                    Spacer(minLength: 8)
                    Text("\(r.hitRate)%")
                        .font(.anton(19))
                        .foregroundStyle(Color.p1Win)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(r.isMe
                              ? AnyShapeStyle(LinearGradient(colors: [Color.p1Lime.opacity(0.10), .clear],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color(hex: "#15171C")))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(r.isMe ? Color.p1Lime.opacity(0.5) : Color.p1Line, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }
}

// MARK: - Rewards shop

struct P1ShopSheetV2: View {
    let balance: Int
    var onClose: () -> Void = {}

    private let items: [(emoji: String, title: String, note: String, cost: Int)] = [
        ("🎯", "Longshot unlock", "Today's high-return call · instant", 1_500),
        ("🛡️", "Streak shield", "Protects one missed day", 2_000),
        ("💎", "7 days of Premium", "Every sport · every market", 5_000),
        ("🧢", "Pick1 cap", "Free shipping · members only", 12_000),
        ("👕", "Team jersey", "Any club · official · free shipping", 25_000),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.p1Ink.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    (
                        Text("REWARDS ").foregroundStyle(Color.p1Foreground)
                        + Text("SHOP").foregroundStyle(Color.p1Lime)
                    )
                    .font(.anton(30))

                    HStack {
                        Text("YOUR BALANCE")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.p1Mute)
                        Spacer(minLength: 8)
                        Text("🪙 \(balance.formatted())")
                            .font(.mono(13, weight: .bold))
                            .foregroundStyle(coinGold)
                    }
                    .padding(.top, 14)

                    VStack(spacing: 8) {
                        ForEach(items, id: \.title) { item in
                            HStack(spacing: 12) {
                                Text(item.emoji).font(.system(size: 19))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.archivoNarrow(13, weight: .bold))
                                        .foregroundStyle(Color.p1Foreground)
                                    Text(item.note.uppercased())
                                        .font(.archivoNarrow(10.5, weight: .bold))
                                        .tracking(0.63)
                                        .foregroundStyle(Color.p1Mute)
                                }
                                Spacer(minLength: 8)
                                Text("🪙 \(item.cost.formatted())")
                                    .font(.mono(12, weight: .bold))
                                    .foregroundStyle(balance >= item.cost ? coinGold : Color.p1Mute)
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Panel))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.p1Line, lineWidth: 1))
                            .opacity(balance >= item.cost ? 1 : 0.55)
                        }
                    }
                    .padding(.top, 16)

                    Text("COINS ARE EARNED FREE BY BACKING PICKS, STREAKS & SPINS.\nNO PURCHASE · NO CASH VALUE · NOT REDEEMABLE FOR MONEY.")
                        .font(.mono(8.5, weight: .bold))
                        .tracking(0.34)
                        .lineSpacing(4)
                        .foregroundStyle(Color.p1Mute)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)
            }

            Button(action: onClose) {
                Text("✕")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.p1Foreground)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.p1Panel))
                    .overlay(Circle().strokeBorder(Color.p1Line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
        .preferredColorScheme(.dark)
    }
}
