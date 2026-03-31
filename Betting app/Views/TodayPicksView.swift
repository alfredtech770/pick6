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

                    // Header
                    headerSection

                    // Stats bar
                    statsBar

                    // Sport filter
                    sportFilter

                    // Picks list
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
        HStack {
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
            Text("New picks drop at 10am, 2pm, 6pm and 10pm")
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
