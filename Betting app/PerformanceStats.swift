// PerformanceStats.swift
// The AI's real, all-time graded track record — the social-proof number
// shown on the paywall. Pulled from the `app_performance()` Postgres
// function (server-computed over the whole picks table) and cached so the
// paywall always has something to show, even offline / pre-fetch.

import Foundation
import Combine
import Supabase

@MainActor
final class PerformanceStats: ObservableObject {
    static let shared = PerformanceStats()

    struct Stats: Codable, Equatable {
        let wins: Int
        let losses: Int
        let accuracy: Int   // whole-percent win rate over graded picks
        let total: Int      // graded picks (win + loss)
    }

    @Published private(set) var stats: Stats?
    private let cacheKey = "pick1.perfStats.v1"

    private init() { load() }

    /// Refresh from the server. Best-effort — keeps the cached value on
    /// failure so the paywall never shows an empty strip.
    func refresh() async {
        struct Row: Decodable { let wins: Int; let losses: Int; let accuracy: Int; let total: Int }
        do {
            let rows: [Row] = try await SupabaseManager.client
                .rpc("app_performance")
                .execute()
                .value
            if let r = rows.first {
                let s = Stats(wins: r.wins, losses: r.losses, accuracy: r.accuracy, total: r.total)
                stats = s
                save(s)
            }
        } catch {
            // Keep whatever we had cached.
        }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: cacheKey),
           let s = try? JSONDecoder().decode(Stats.self, from: d) {
            stats = s
        }
    }
    private func save(_ s: Stats) {
        if let d = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(d, forKey: cacheKey)
        }
    }
}
