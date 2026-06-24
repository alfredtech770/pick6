// LiveActivityManager.swift
// Drives Pick1 game Live Activities (the Apple Sports–style Lock Screen /
// Dynamic Island card). Starts one when a game the user has a pick on goes
// live, updates it as scores change, and ends it at final. Each Activity's
// APNs push token is uploaded to `live_activity_tokens` so the pipeline can
// push score updates while the app is backgrounded.

import Foundation
import ActivityKit
import Supabase

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var activities: [String: Activity<Pick1GameAttributes>] = [:]   // gameId → activity
    private var tokenTasks: [String: Task<Void, Never>] = [:]

    /// Whether the user has Live Activities enabled in Settings.
    var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Reconcile from the current live slate: start activities for live
    /// favorited games, update existing ones, end finished ones.
    func sync(favoritePickGameIds: Set<String>, picks: [Pick], scores: [LiveScore]) {
        guard enabled else { return }
        let scoreByGame = Dictionary(scores.compactMap { s in s.gameId.isEmpty ? nil : (s.gameId, s) },
                                     uniquingKeysWith: { a, _ in a })

        for pick in picks {
            guard let gid = pick.gameId, favoritePickGameIds.contains(gid),
                  let score = scoreByGame[gid] else { continue }
            if score.isFinal {
                update(pick: pick, score: score)   // show FINAL once
                end(gameId: gid)
            } else if score.isLive {
                startOrUpdate(pick: pick, score: score)
            }
        }
        // End activities whose game is no longer live/favorited.
        for gid in activities.keys where !favoritePickGameIds.contains(gid) {
            end(gameId: gid)
        }
    }

    func startOrUpdate(pick: Pick, score: LiveScore) {
        guard enabled, let gid = pick.gameId else { return }
        let state = contentState(pick: pick, score: score)
        if let existing = activities[gid] {
            Task { await existing.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(1800))) }
            return
        }
        guard score.isLive else { return }
        let attrs = Pick1GameAttributes(
            homeTeam: teamShortName(pick.homeTeam, sport: pick.sport),
            awayTeam: teamShortName(pick.awayTeam, sport: pick.sport),
            homeAbbr: abbr(pick.homeTeam, sport: pick.sport),
            awayAbbr: abbr(pick.awayTeam, sport: pick.sport),
            league: displayLeague(pick.league),
            pickText: pick.displayPick,
            gameId: gid)
        do {
            let act = try Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(1800)),
                pushType: .token)
            activities[gid] = act
            observePushToken(act, gameId: gid)
        } catch {
            // Activity request can fail if the user disabled them mid-flight.
        }
    }

    private func update(pick: Pick, score: LiveScore) {
        guard let gid = pick.gameId, let act = activities[gid] else { return }
        let state = contentState(pick: pick, score: score)
        Task { await act.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end(gameId: String) {
        guard let act = activities[gameId] else { return }
        tokenTasks[gameId]?.cancel(); tokenTasks[gameId] = nil
        activities[gameId] = nil
        Task {
            await act.end(nil, dismissalPolicy: .after(Date().addingTimeInterval(900)))
            await deleteToken(gameId: gameId)
        }
    }

    // MARK: - Content

    private func contentState(pick: Pick, score: LiveScore) -> Pick1GameAttributes.ContentState {
        let h = score.homeScore ?? 0
        let a = score.awayScore ?? 0
        let pl = pick.pick.lowercased()
        let pickedHome = pl.contains(pick.homeTeam.lowercased())
        let pickedAway = pl.contains(pick.awayTeam.lowercased())
        let hitting: Bool
        if pickedHome { hitting = h >= a }
        else if pickedAway { hitting = a >= h }
        else { hitting = false }
        let status: String
        if score.isFinal { status = "FINAL" }
        else if let q = score.quarter, !q.isEmpty { status = "LIVE · \(q)" }
        else { status = "LIVE" }
        return .init(homeScore: h, awayScore: a, statusLine: status,
                     pickHitting: hitting, isFinal: score.isFinal)
    }

    private func abbr(_ team: String, sport: String) -> String {
        let short = teamShortName(team, sport: sport)
        return String(short.prefix(3)).uppercased()
    }

    // MARK: - Push token → Supabase

    private func observePushToken(_ act: Activity<Pick1GameAttributes>, gameId: String) {
        tokenTasks[gameId] = Task {
            for await tokenData in act.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                await uploadToken(gameId: gameId, token: token)
            }
        }
    }

    private struct TokenRow: Encodable { let user_id: String; let game_id: String; let token: String }

    private func uploadToken(gameId: String, token: String) async {
        guard let uid = SupabaseManager.client.auth.currentSession?.user.id else { return }
        do {
            try await SupabaseManager.client.from("live_activity_tokens")
                .upsert(TokenRow(user_id: uid.uuidString, game_id: gameId, token: token),
                        onConflict: "game_id")
                .execute()
        } catch { }
    }

    private func deleteToken(gameId: String) async {
        do {
            try await SupabaseManager.client.from("live_activity_tokens")
                .delete().eq("game_id", value: gameId).execute()
        } catch { }
    }
}
