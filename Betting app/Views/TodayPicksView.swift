//
//  TodayPicksView.swift
//  Betting app
//
//  Created by Ethan on 3/30/26.
//

import SwiftUI

struct TodayPicksView: View {
    @StateObject private var vm = PicksViewModel()

    var body: some View {
        ZStack {
            Color(hex: "#030305").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // Header — date + streak + live indicator
                    headerSection

                    // Stats bar — wins / losses / win rate / pending (30-day)
                    statsBar

                    // Yesterday's results card (only when there's data)
                    if !vm.filteredYesterdayPicks.isEmpty {
                        yesterdayCard
                    }

                    // Sport filter
                    sportFilter

                    // Today's picks list
                    todaySectionHeader

                    if vm.isLoading {
                        ProgressView()
                            .tint(Color(hex: "#22C55E"))
                            .padding(.top, 60)
                    } else if vm.filteredPicks.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.filteredPicks) { pick in
                            PickCardView(pick: pick)
                        }
                    }
                }
                .padding(.top)
                .padding(.bottom, 40)
            }
        }
        .task {
            await vm.startLiveSession()
        }
    }

    // MARK: - Header
    var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S PICKS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .kerning(2)

                Text(formattedDate)
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(.white)
            }
            Spacer()

            // Streak badge — visible when there's a current streak
            if vm.currentStreak > 0 {
                streakBadge
            }

            // Live indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: "#22C55E"))
                    .frame(width: 8, height: 8)
                    .opacity(vm.totalPending > 0 ? 1 : 0.3)
                Text("LIVE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#22C55E"))
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Streak badge
    var streakBadge: some View {
        HStack(spacing: 4) {
            Text("🔥")
                .font(.system(size: 14))
            Text("\(vm.currentStreak)")
                .font(.caption)
                .fontWeight(.black)
                .foregroundColor(Color(hex: "#FF8000"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(hex: "#FF8000").opacity(0.12))
        .overlay(
            Capsule().stroke(Color(hex: "#FF8000").opacity(0.4), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    // MARK: - Yesterday's results
    var yesterdayCard: some View {
        let wins = vm.yesterdayWins
        let losses = vm.yesterdayLosses
        let pending = vm.filteredYesterdayPicks.filter { $0.isPending }.count
        let total = wins + losses
        let rate = vm.yesterdayWinRate

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YESTERDAY")
                    .font(.caption2)
                    .fontWeight(.black)
                    .kerning(2)
                    .foregroundColor(.gray)
                Spacer()
                if let r = rate {
                    Text(String(format: "%.0f%% win rate", r))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(r >= 60 ? Color(hex: "#22C55E") : Color(hex: "#FF8000"))
                }
            }

            HStack(spacing: 12) {
                yesterdayChip(value: "\(wins)", label: total == 1 ? "Win" : "Wins", color: "#22C55E")
                yesterdayChip(value: "\(losses)", label: losses == 1 ? "Loss" : "Losses", color: "#FF4444")
                if pending > 0 {
                    yesterdayChip(value: "\(pending)", label: "Pending", color: "#6B7280")
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#0f1117"))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
    }

    func yesterdayChip(value: String, label: String, color: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .foregroundColor(Color(hex: color))
            Text(label.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .kerning(1)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - "Today's picks" section header
    var todaySectionHeader: some View {
        HStack {
            Text("TODAY")
                .font(.caption2)
                .fontWeight(.black)
                .kerning(2)
                .foregroundColor(.gray)
            Spacer()
            if vm.totalPending > 0 {
                Text("\(vm.totalPending) pending")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Stats Bar
    var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(vm.totalWins)", label: "Wins", color: "#22C55E")
            Divider().background(Color.gray.opacity(0.3)).frame(height: 30)
            statItem(value: "\(vm.totalLosses)", label: "Losses", color: "FF4444")
            Divider().background(Color.gray.opacity(0.3)).frame(height: 30)
            statItem(value: String(format: "%.0f%%", vm.winRate),
                     label: "Win Rate", color: "22C55E")
            Divider().background(Color.gray.opacity(0.3)).frame(height: 30)
            statItem(value: "\(vm.totalPending)", label: "Pending", color: "6B7280")
        }
        .padding(.vertical, 16)
        .background(Color(hex: "#0f1117"))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    func statItem(value: String, label: String, color: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.black)
                .foregroundColor(Color(hex: "#\(color)"))
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sport Filter
    var sportFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(vm.sports, id: \.self) { sport in
                    Button {
                        vm.selectedSport = sport
                    } label: {
                        Text(sport == "all" ? "All" : sport.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                vm.selectedSport == sport ? .black : .gray
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                vm.selectedSport == sport
                                    ? Color(hex: "#22C55E")
                                    : Color(hex: "#0f1117")
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty State
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Picks generating...")
                .font(.headline)
                .foregroundColor(.white)
            Text("New picks drop 3× daily — 9am, 3pm, 9pm ET")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }
}
