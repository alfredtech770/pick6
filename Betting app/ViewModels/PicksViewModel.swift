//
//  PicksViewModel.swift
//  Betting app
//
//  Created by Ethan on 3/30/26.
//

import Combine
import Foundation
import Supabase

@MainActor
class PicksViewModel: ObservableObject {

    @Published var picks: [Pick] = []
    @Published var liveScores: [LiveScore] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSport: String = "all"

    private let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://jisbgspvllgwtfgoeihx.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imppc2Jnc3B2bGxnd3RmZ29laWh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNjM4NzEsImV4cCI6MjA4OTkzOTg3MX0.hMiiTCHQj5-hjtb6gFL_X9lGmHw4baCk4_0j9RNoIFs"
    )

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // Sports filter options
    let sports = ["all", "basketball", "hockey", "soccer", "tennis", "mma"]

    // Filtered picks based on selected sport
    var filteredPicks: [Pick] {
        if selectedSport == "all" { return picks }
        return picks.filter { $0.sport == selectedSport }
    }

    // Stats
    var winRate: Double {
        let settled = picks.filter { !$0.isPending }
        guard !settled.isEmpty else { return 0 }
        let wins = settled.filter { $0.isWin }.count
        return Double(wins) / Double(settled.count) * 100
    }

    var totalWins: Int { picks.filter { $0.isWin }.count }
    var totalLosses: Int { picks.filter { $0.isLoss }.count }
    var totalPending: Int { picks.filter { $0.isPending }.count }

    // MARK: - Fetch today's picks
    func fetchTodayPicks() async {
        isLoading = true
        errorMessage = nil

        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)

        do {
            let response: [Pick] = try await supabase
                .from("picks")
                .select()
                .eq("game_date", value: String(today))
                .order("probability", ascending: false)
                .execute()
                .value

            self.picks = response
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching picks:", error)
        }

        isLoading = false
    }

    // MARK: - Fetch live scores
    func fetchLiveScores() async {
        do {
            let response: [LiveScore] = try await supabase
                .from("live_scores")
                .select()
                .execute()
                .value

            self.liveScores = response
        } catch {
            print("Error fetching live scores:", error)
        }
    }

    // MARK: - Realtime subscription for picks
    func subscribeToPickUpdates() async {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let channel = supabase.realtimeV2.channel("picks_realtime")

        let subscription = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "picks",
            filter: "game_date=eq.\(today)"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                if let updated = try? action.decodeRecord(as: Pick.self, decoder: self.decoder) {
                    self.updatePickInList(updated)
                }
            }
        }
        _ = subscription

        await channel.subscribe()
    }

    // MARK: - Realtime subscription for live scores
    func subscribeToLiveScores() async {
        let channel = supabase.realtimeV2.channel("scores_realtime")

        let insertSub = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "live_scores"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                if let updated = try? action.decodeRecord(as: LiveScore.self, decoder: self.decoder) {
                    self.updateScoreInList(updated)
                }
            }
        }
        _ = insertSub

        let updateSub = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "live_scores"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                if let updated = try? action.decodeRecord(as: LiveScore.self, decoder: self.decoder) {
                    self.updateScoreInList(updated)
                }
            }
        }
        _ = updateSub

        await channel.subscribe()
    }

    // MARK: - Helpers
    private func updatePickInList(_ updated: Pick) {
        if let index = picks.firstIndex(where: { $0.id == updated.id }) {
            picks[index] = updated
        }
    }

    private func updateScoreInList(_ updated: LiveScore) {
        if let index = liveScores.firstIndex(where: { $0.gameId == updated.gameId }) {
            liveScores[index] = updated
        } else {
            liveScores.append(updated)
        }
    }

    // MARK: - Start everything
    func startLiveSession() async {
        await fetchTodayPicks()
        await fetchLiveScores()
        await subscribeToPickUpdates()
        await subscribeToLiveScores()
    }
}
