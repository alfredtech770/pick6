// BetTracker.swift
// Personal bet tracking — the user's own P&L on Pick1 calls.
//
// The app's core promise is "track everything"; this turns the public
// ledger into the USER's ledger. Tapping "Track bet" on a pick stores a
// row in `user_bets` (owner-only RLS); results inherit from the pick's
// win/loss grade, profit = stake × (odds − 1) on wins, −stake on losses.
// Stake is optional — a bet tracked without an amount still counts toward
// the personal record, just not the dollar P&L.

import Foundation
import Combine
import Supabase

struct UserBet: Codable, Identifiable, Hashable {
    let id: UUID
    let pickId: UUID
    let stake: Double?
    let oddsAtBet: Double?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case pickId = "pick_id"
        case stake
        case oddsAtBet = "odds_at_bet"
        case createdAt = "created_at"
    }
}

@MainActor
final class BetTracker: ObservableObject {
    static let shared = BetTracker()
    private init() {}

    /// pickId → bet. Drives instant "tracked" state on detail pages.
    @Published private(set) var bets: [UUID: UserBet] = [:]
    @Published private(set) var loaded = false

    private var client: SupabaseClient { SupabaseManager.client }

    func isTracked(_ pickId: UUID) -> Bool { bets[pickId] != nil }

    func load() async {
        guard client.auth.currentSession != nil else { return }
        do {
            let rows: [UserBet] = try await client.from("user_bets")
                .select("id, pick_id, stake, odds_at_bet, created_at")
                .execute().value
            bets = Dictionary(rows.map { ($0.pickId, $0) }, uniquingKeysWith: { a, _ in a })
            loaded = true
        } catch { /* non-fatal — tracker UI just shows untracked */ }
    }

    /// Track a pick, locking in today's odds. Upserts so re-tracking with a
    /// different stake just updates the row.
    func track(pick: Pick, stake: Double?) async {
        guard let uid = client.auth.currentSession?.user.id else { return }
        struct Row: Encodable {
            let user_id: String, pick_id: String
            let stake: Double?, odds_at_bet: Double?
        }
        let odds = pick.marketOdds ?? pick.impliedOddsForPayout
        do {
            try await client.from("user_bets")
                .upsert(Row(user_id: uid.uuidString, pick_id: pick.id.uuidString,
                            stake: stake, odds_at_bet: odds),
                        onConflict: "user_id,pick_id")
                .execute()
            await load()
            Analytics.track("bet_tracked", ["sport": pick.sport, "stake": stake ?? 0])
        } catch { }
    }

    func untrack(pickId: UUID) async {
        do {
            try await client.from("user_bets").delete()
                .eq("pick_id", value: pickId.uuidString).execute()
            bets[pickId] = nil
        } catch { }
    }

    // MARK: - P&L

    struct Summary {
        var tracked = 0
        var settled = 0
        var wins = 0
        var losses = 0
        var staked: Double = 0        // settled bets with a stake
        var profit: Double = 0        // net across settled staked bets
        var roiPct: Double? { staked > 0 ? profit / staked * 100 : nil }
    }

    /// Compute the personal record against the picks the bets refer to.
    func summary(picks: [Pick]) -> Summary {
        let byId = Dictionary(picks.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var s = Summary()
        for bet in bets.values {
            guard let pick = byId[bet.pickId] else { continue }
            s.tracked += 1
            guard !pick.isPending else { continue }
            s.settled += 1
            if pick.isWin { s.wins += 1 } else if pick.isLoss { s.losses += 1 }
            guard let stake = bet.stake, stake > 0 else { continue }
            let odds = bet.oddsAtBet ?? pick.marketOdds ?? 1.9
            s.staked += stake
            s.profit += pick.isWin ? stake * (odds - 1) : -stake
        }
        return s
    }
}

extension Pick {
    /// Fallback decimal odds when no market quote exists — derived from the
    /// model's own probability (used only for payout math, labeled as such).
    var impliedOddsForPayout: Double? {
        probability > 0 ? (100.0 / Double(probability)) : nil
    }
}
