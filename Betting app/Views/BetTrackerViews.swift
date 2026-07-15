// BetTrackerViews.swift
// UI for the personal bet tracker: the stake-entry sheet shown from a
// pick's OUR CALL panel, and the P&L summary card shown in Profile.

import SwiftUI

// MARK: - Track sheet (stake entry)

struct TrackBetSheet: View {
    let pick: Pick
    let accent: Color
    let onTrack: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var stakeText: String = ""

    private let quick: [Double] = [10, 25, 50, 100]

    private var stake: Double? {
        let cleaned = stakeText.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v > 0 else { return nil }
        return v
    }

    private var odds: Double { pick.marketOdds ?? pick.impliedOddsForPayout ?? 1.9 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t(.rd_bt_track_this))
                    .font(.archivoNarrow(11, weight: .bold)).tracking(2.0)
                    .foregroundColor(Color(hex: "#6E6F75"))
                Text(pick.pick)
                    .font(.anton(22)).foregroundColor(Color(hex: "#F5F3EE"))
            }

            Text(t(.rd_bt_stake_sub))
                .font(.archivo(13)).foregroundColor(Color(hex: "#8A8D94"))

            // Quick stake chips
            HStack(spacing: 8) {
                ForEach(quick, id: \.self) { amt in
                    Button {
                        stakeText = String(Int(amt))
                    } label: {
                        Text("$\(Int(amt))")
                            .font(.archivo(14, weight: .bold))
                            .foregroundColor(stakeText == String(Int(amt)) ? Color(hex: "#0A0B0D") : Color(hex: "#B9B7B0"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(stakeText == String(Int(amt)) ? accent : Color(hex: "#16181D")))
                    }
                }
            }

            // Custom amount
            HStack(spacing: 8) {
                Text("$").font(.anton(20)).foregroundColor(Color(hex: "#6E6F75"))
                TextField(t(.rd_bt_amount), text: $stakeText)
                    .keyboardType(.decimalPad)
                    .font(.anton(20)).foregroundColor(Color(hex: "#F5F3EE"))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#16181D")))

            if let s = stake {
                HStack {
                    Text(t(.rd_bt_to_return)).font(.archivoNarrow(9, weight: .bold)).tracking(1.4)
                        .foregroundColor(Color(hex: "#6E6F75"))
                    Spacer()
                    Text("$\(Int((s * odds).rounded()))")
                        .font(.anton(18)).foregroundColor(accent)
                }
            }

            Spacer(minLength: 0)

            Button {
                onTrack(stake); dismiss()
            } label: {
                Text(stake == nil ? t(.rd_bt_track_without_stake) : t(.rd_bt_track_bet))
                    .font(.archivoNarrow(13, weight: .bold)).tracking(1.6)
                    .foregroundColor(Color(hex: "#0A0B0D"))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(accent))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#0A0B0D").ignoresSafeArea())
    }
}

// MARK: - Profile P&L card

struct MyBetsCard: View {
    let picks: [Pick]
    @StateObject private var tracker = BetTracker.shared

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
    }

    private var emptyState: some View {
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
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#101216")))
    }

    private func filledCard(_ s: BetTracker.Summary) -> some View {
        let win = Color(red: 0.831, green: 1.0, blue: 0.227)
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
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#101216")))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: "#1C1F25"), lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Color(hex: "#1C1F25")).frame(width: 1, height: 30)
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
