// StreakCard.swift
// "Share your streak" — the record-level viral loop.
//
// ShareWin covers a single winning pick; this covers the thing the brand
// actually sells: the AI's running record. The streak is counted on the
// AI's #1 pick of each day (highest model probability among graded picks
// for that game_date) — consecutive days won, ending at the most recent
// graded day. That's the "one pick a day" promise turned into a number
// worth posting.
//
// The card always shows the all-time record (wins–losses + accuracy from
// PerformanceStats), losses included — transparency IS the positioning.
// When the streak is ≥ 2 it becomes the hero; otherwise the record is.
// Users with settled tracked bets get their own record on the card too.
//
// Sharing completes the same reward loop as ShareWin: free users get 24h
// of Premium via claim_share_reward (server-capped, one per 7 days).

import SwiftUI
import UIKit

// MARK: - Streak math

enum StreakMath {
    /// Consecutive days the AI's top pick won, counting back from the
    /// most recent day that has a graded top pick. 0 if that day lost.
    static func topPickDayStreak(picks: [Pick]) -> Int {
        // game_date → top graded pick of that day (max model probability).
        var topByDay: [String: Pick] = [:]
        for p in picks where p.isWin || p.isLoss {
            if let cur = topByDay[p.gameDate] {
                if p.probability > cur.probability { topByDay[p.gameDate] = p }
            } else {
                topByDay[p.gameDate] = p
            }
        }
        // ISO yyyy-MM-dd sorts correctly as a string.
        let days = topByDay.keys.sorted(by: >)
        var streak = 0
        for day in days {
            guard let top = topByDay[day], top.isWin else { break }
            streak += 1
        }
        return streak
    }
}

// MARK: - The card image

/// The branded record card — dark canvas, P1 wordmark, streak hero (or
/// record hero when there's no streak), all-time AI record with losses
/// shown, and the user's own tracked record when they have one.
struct StreakShareCard: View {
    let streak: Int
    let aiStats: PerformanceStats.Stats?
    let personal: BetTracker.Summary?

    private let lime = Color(hex: "#C6FF34")
    private let ink = Color(hex: "#171717")

    private var showStreakHero: Bool { streak >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Pick1Wordmark(size: 22)
                Spacer()
                if let s = aiStats {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 8, weight: .heavy))
                        Text("\(s.accuracy)%")
                            .font(.archivoNarrow(10, weight: .bold)).tracking(1.2)
                    }
                    .foregroundColor(ink)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(lime))
                }
            }

            if showStreakHero {
                // ── Streak hero ────────────────────────────────────
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(streak)")
                        .font(.anton(56)).foregroundColor(lime)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(lime)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(t(.sc_day_streak))
                        .font(.anton(18)).foregroundColor(.white)
                    Text(t(.sc_top_pick_note))
                        .font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                        .foregroundColor(Color(hex: "#8A8D94"))
                }
            } else if let s = aiStats {
                // ── Record hero (no active streak to flex — and we
                //    don't fake one; the record carries the card) ────
                Text("\(s.wins)–\(s.losses)")
                    .font(.anton(50)).foregroundColor(lime)
                Text(t(.sc_ai_record))
                    .font(.archivoNarrow(11, weight: .bold)).tracking(1.6)
                    .foregroundColor(Color(hex: "#8A8D94"))
            }

            // ── All-time record strip (always visible with the streak
            //    hero: losses on the card is the whole point) ────────
            if showStreakHero, let s = aiStats {
                divider
                HStack {
                    Text(t(.sc_ai_record))
                        .font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                        .foregroundColor(Color(hex: "#8A8D94"))
                    Spacer()
                    Text("\(s.wins)–\(s.losses)")
                        .font(.mono(14, weight: .bold)).foregroundColor(.white)
                }
            }

            // ── The user's own tracked record ──────────────────────
            if let p = personal, p.settled > 0 {
                divider
                HStack {
                    Text(t(.sc_my_record))
                        .font(.archivoNarrow(10, weight: .bold)).tracking(1.6)
                        .foregroundColor(Color(hex: "#8A8D94"))
                    Spacer()
                    Text("\(p.wins)–\(p.losses)")
                        .font(.mono(14, weight: .bold)).foregroundColor(.white)
                    if p.staked > 0 {
                        Text(p.profit >= 0
                             ? "+$\(Int(p.profit.rounded()))"
                             : "-$\(Int(abs(p.profit).rounded()))")
                            .font(.mono(14, weight: .bold))
                            .foregroundColor(p.profit >= 0 ? lime : Color(hex: "#FF5A5A"))
                    }
                }
            }

            Text(t(.sw_disclaimer))
                .font(.archivo(8, weight: .medium))
                .foregroundColor(Color(hex: "#6E6F75"))
                .lineLimit(2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "#1D1D1D"))
                .overlay(
                    LinearGradient(colors: [lime.opacity(0.16), .clear],
                                   startPoint: .topLeading, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                )
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(lime.opacity(0.45), lineWidth: 1.2))
        )
    }

    private var divider: some View {
        Rectangle().fill(Color(hex: "#2F2F2F")).frame(height: 1)
    }
}

// MARK: - Sheet

struct StreakShareSheet: View {
    let picks: [Pick]

    @EnvironmentObject private var subs: SubscriptionManager
    @StateObject private var perf = PerformanceStats.shared
    @StateObject private var tracker = BetTracker.shared

    @State private var showShare = false
    @State private var rewardGranted = false
    @State private var shareImage: UIImage?

    private let lime = Color(hex: "#C6FF34")

    private var streak: Int { StreakMath.topPickDayStreak(picks: picks) }
    private var personal: BetTracker.Summary? {
        tracker.bets.isEmpty ? nil : tracker.summary(picks: picks)
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color(hex: "#3A3A3A"))
                .frame(width: 42, height: 5).padding(.top, 10)

            Text(t(.sc_share_streak))
                .font(.anton(26)).foregroundColor(.white)

            // Live preview of the exact card that gets shared.
            StreakShareCard(streak: streak, aiStats: perf.stats, personal: personal)
                .frame(maxWidth: 340)

            if rewardGranted {
                Text(t(.sw_reward_done))
                    .font(.archivoNarrow(13, weight: .bold)).tracking(1.2)
                    .foregroundColor(lime)
            } else if !subs.isPro {
                Text(t(.sw_reward_hint))
                    .font(.archivo(12, weight: .medium))
                    .foregroundColor(Color(hex: "#B9B7B0"))
            }

            Button {
                Haptics.tap()
                shareImage = renderCard()
                showShare = true
            } label: {
                Text(t(.sw_share_cta))
                    .font(.anton(17)).kerning(0.4)
                    .foregroundColor(Color(hex: "#171717"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(lime))
            }
            .padding(.horizontal, 24)

            Text(t(.sw_disclaimer))
                .font(.archivo(10, weight: .medium))
                .foregroundColor(Color(hex: "#6E6F75"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#171717"))
        .presentationBackground(Color(hex: "#171717"))
        .presentationDragIndicator(.visible)
        .task {
            if perf.stats == nil { await perf.refresh() }
            if !tracker.loaded { await tracker.load() }
            Analytics.streakCardOpened(streak: streak)
        }
        .sheet(isPresented: $showShare) {
            if let img = shareImage {
                ShareActivitySheet(items: [img]) { completed in
                    guard completed else {
                        Analytics.streakCardShared(streak: streak, granted: false)
                        return
                    }
                    Haptics.success()
                    if !subs.isPro {
                        Task {
                            let granted = await subs.claimShareReward()
                            Analytics.streakCardShared(streak: streak, granted: granted)
                            if granted {
                                withAnimation { rewardGranted = true }
                            }
                        }
                    } else {
                        Analytics.streakCardShared(streak: streak, granted: false)
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    /// Rasterize at 3x for a crisp share image.
    @MainActor
    private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(content:
            StreakShareCard(streak: streak, aiStats: perf.stats, personal: personal)
                .frame(width: 340)
                .background(Color(hex: "#171717"))
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}
