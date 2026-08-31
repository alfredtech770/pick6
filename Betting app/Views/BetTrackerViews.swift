// BetTrackerViews.swift
// UI for the personal bet tracker: the stake-entry sheet shown from a
// pick's OUR CALL panel, and the P&L summary card shown in Profile.

import SwiftUI

// MARK: - Track sheet (stake entry)

struct TrackBetSheet: View {
    let pick: Pick
    let accent: Color
    let onTrack: (Double?) -> Void
    var isTracked: Bool = false
    var onUntrack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var stakeText: String = ""

    private let quick: [Double] = [10, 25, 50, 100]

    private var stake: Double? {
        let cleaned = stakeText.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v > 0 else { return nil }
        return v
    }

    private var odds: Double { pick.marketOdds ?? pick.impliedOddsForPayout ?? 1.9 }

    /// Reference stake the projection falls back to before the user picks
    /// one. Never submitted: `stake` stays nil until they actually choose,
    /// so "track without a stake" still logs no stake and nobody's ROI gets
    /// a $100 bet they did not make.
    private static let referenceStake: Double = 100

    private var projected: Double { (stake ?? Self.referenceStake) * odds }
    private var hasStake: Bool { stake != nil }

    @State private var confirming = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isTracked ? t(.rd_tracking) : t(.rd_track_your_pick))
                    .font(.archivoNarrow(11, weight: .bold)).tracking(2.0)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.pick)
                    .font(.anton(22)).foregroundColor(Color(hex: "#F5F3EE"))
            }

            // The money, at the top and always on screen.
            //
            // It used to be a small line UNDER the amount field that appeared
            // only once something had been typed, so the sheet opened blank
            // on the one number the whole app is built around. Seeded with
            // the $100 reference and muted until the stake is real, it now
            // answers "what do I get" before being asked.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("$\(Int((stake ?? Self.referenceStake).rounded()))")
                    .font(.anton(26))
                    .foregroundColor(hasStake ? Color(hex: "#F5F3EE") : Color(hex: "#6E6F75"))
                    .contentTransition(.numericText())
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text("$\(Int(projected.rounded()))")
                    .font(.anton(38))
                    .foregroundColor(hasStake ? accent : Color(hex: "#8A8D94"))
                    .contentTransition(.numericText())
                    .shadow(color: accent.opacity(hasStake ? 0.4 : 0), radius: 14)
                Spacer(minLength: 0)
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: stake)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1E1E1E")))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(accent.opacity(hasStake ? 0.35 : 0.08), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Text(hasStake ? t(.rd_bt_to_return).uppercased()
                              : "\(t(.rd_bt_to_return).uppercased()) · $100")
                    .font(.archivoNarrow(8, weight: .bold)).tracking(1.3)
                    .foregroundColor(Color(hex: "#6E6F75"))
                    .padding(.top, 9).padding(.trailing, 12)
            }

            // Quick stake chips. Tapping one springs the number above rather
            // than snapping it, which is the whole point of putting the money
            // where the thumb already is.
            HStack(spacing: 8) {
                ForEach(quick, id: \.self) { amt in
                    let on = stakeText == String(Int(amt))
                    Button {
                        Haptics.tap()
                        amountFocused = false
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            stakeText = on ? "" : String(Int(amt))
                        }
                    } label: {
                        Text("$\(Int(amt))")
                            .font(.archivo(14, weight: .bold))
                            .foregroundColor(on ? Color(hex: "#171717") : Color(hex: "#B9B7B0"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(on ? accent : Color(hex: "#242424")))
                            .scaleEffect(on ? 1.05 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Text("$").font(.anton(20)).foregroundColor(Color(hex: "#6E6F75"))
                TextField(t(.rd_bt_amount), text: $stakeText)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .font(.anton(20)).foregroundColor(Color(hex: "#F5F3EE"))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#242424")))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accent.opacity(amountFocused ? 0.5 : 0), lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: amountFocused)

            Spacer(minLength: 0)

            // The confirm morphs into a tick before the sheet leaves, so the
            // action is acknowledged on the control that performed it rather
            // than by the sheet simply vanishing.
            Button {
                guard !confirming else { return }
                Haptics.success()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { confirming = true }
                onTrack(stake)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { dismiss() }
            } label: {
                Group {
                    if confirming {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .heavy))
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    } else {
                        Text(stake == nil ? t(.rd_bt_track_without_stake) : t(.rd_bt_track_bet))
                            .font(.archivoNarrow(13, weight: .bold)).tracking(1.6)
                    }
                }
                .foregroundColor(Color(hex: "#171717"))
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(accent))
                .scaleEffect(confirming ? 0.97 : 1)
            }
            .buttonStyle(.plain)
            .disabled(confirming)

            if isTracked, let onUntrack {
                Button {
                    Haptics.tap()
                    onUntrack()
                    dismiss()
                } label: {
                    Text("STOP TRACKING")
                        .font(.archivoNarrow(12, weight: .bold)).tracking(1.5)
                        .foregroundColor(Color(hex: "#FF5A5A"))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#171717").ignoresSafeArea())
    }
}

// MARK: - Profile P&L card

struct MyBetsCard: View {
    let picks: [Pick]
    var onBrowse: () -> Void = {}
    @StateObject private var tracker = BetTracker.shared
    @State private var showStreakShare = false

    var body: some View {
        let s = tracker.summary(picks: picks)
        Group {
            if s.tracked == 0 {
                emptyState
            } else {
                filledCard(s)
            }
        }
        .task { if !tracker.loaded { await tracker.load() } }
        .sheet(isPresented: $showStreakShare) {
            StreakShareSheet(picks: picks)
                .relocalizesOnLanguageChange()
                .presentationDetents([.fraction(0.78), .large])
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#6E6F75"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t(.rd_bt_ledger))
                        .font(.archivoNarrow(11, weight: .bold)).tracking(1.6)
                        .foregroundColor(Color(hex: "#B9B7B0"))
                    Text(t(.rd_bt_empty))
                        .font(.archivo(12)).foregroundColor(Color(hex: "#6E6F75"))
                }
                Spacer()
            // No tracked bets yet — the AI's streak/record card is still
            // shareable (and still pays the 24h-Premium reward).
                Button {
                    Haptics.tap()
                    showStreakShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.776, green: 1.0, blue: 0.204))
                        .padding(10)
                        .background(Circle().fill(Color(hex: "#242424")))
                }
                .buttonStyle(.plain)
            }
            Button {
                Analytics.emptyStateAction(screen: "profile_ledger")
                onBrowse()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus.circle.fill")
                    Text("TRACK YOUR FIRST PICK")
                        .font(.archivoNarrow(11, weight: .bold)).tracking(1.4)
                }
                .foregroundColor(Color(hex: "#171717"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: "#C6FF34")))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1E1E1E")))
    }

    private func filledCard(_ s: BetTracker.Summary) -> some View {
        let win = Color(red: 0.776, green: 1.0, blue: 0.204)
        let loss = Color(hex: "#FF5A5A")
        let profitColor = s.profit >= 0 ? win : loss
        let hitRate = s.settled > 0 ? Int((Double(s.wins) / Double(s.settled) * 100).rounded()) : 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(t(.rd_bt_ledger))
                    .font(.archivoNarrow(11, weight: .bold)).tracking(1.6)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                Spacer()
                Text(t(.rd_bt_n_tracked, count: s.tracked))
                    .font(.archivoNarrow(9, weight: .bold)).tracking(1.2)
                    .foregroundColor(Color(hex: "#6E6F75"))
            }

            // Headline P&L
            if s.staked > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.profit >= 0 ? "+$\(Int(s.profit.rounded()))" : "-$\(Int(abs(s.profit).rounded()))")
                        .font(.anton(34)).foregroundColor(profitColor)
                    if let roi = s.roiPct {
                        Text("\(roi >= 0 ? "+" : "")\(Int(roi.rounded()))% ROI")
                            .font(.archivo(13, weight: .bold)).foregroundColor(profitColor.opacity(0.85))
                    }
                }
                Text("\(t(.rd_bt_on)) $\(Int(s.staked.rounded())) \(t(.rd_bt_staked_across, count: s.settled))")
                    .font(.archivo(11)).foregroundColor(Color(hex: "#6E6F75"))
            }

            // Record row
            HStack(spacing: 0) {
                statCell(t(.rd_bt_record), "\(s.wins)-\(s.losses)", Color(hex: "#F5F3EE"))
                divider
                statCell(t(.rd_bt_hit_rate), s.settled > 0 ? "\(hitRate)%" : "—", win)
                divider
                statCell(t(.rd_bt_pending), "\(s.tracked - s.settled)", Color(hex: "#B9B7B0"))
            }
            .padding(.top, 2)

            // Share the record → streak card (free users earn 24h Premium)
            Button {
                Haptics.tap()
                showStreakShare = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .bold))
                    Text(t(.sc_share_record_cta))
                        .font(.archivoNarrow(12, weight: .bold)).tracking(1.6)
                }
                .foregroundColor(win)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(win.opacity(0.45), lineWidth: 1))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1E1E1E")))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "#292929"), lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Color(hex: "#292929")).frame(width: 1, height: 30)
    }

    private func statCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.anton(19)).foregroundColor(color)
            Text(label).font(.archivoNarrow(8, weight: .bold)).tracking(1.2)
                .foregroundColor(Color(hex: "#6E6F75"))
        }
        .frame(maxWidth: .infinity)
    }
}
