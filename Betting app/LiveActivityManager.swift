// LiveActivityManager.swift
// Drives Pick1 game Live Activities (the Apple Sports–style Lock Screen /
// Dynamic Island card). Starts one when a game the user has a pick on goes
// live, updates it as scores change, and ends it at final. Each Activity's
// APNs push token is uploaded to `live_activity_tokens` so the pipeline can
// push score updates while the app is backgrounded.

import Foundation
import ActivityKit
import Supabase
import UIKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private var activities: [String: Activity<Pick1GameAttributes>] = [:]   // gameId → activity
    private var tokenTasks: [String: Task<Void, Never>] = [:]
    private var creating: Set<String> = []   // gameIds with an in-flight start
    /// Which side PICK1 called on each tracked game, uploaded with the token
    /// so the server can say whether the call is hitting.
    private var pickSides: [String: String] = [:]

    // MARK: - Any game, from the ESPN board

    func isTracking(_ game: P1Game) -> Bool {
        guard let key = game.alertKey else { return false }
        return activities[key] != nil || creating.contains(key)
    }

    /// Lock Screen / Dynamic Island card for any game on the board, with or
    /// without a PICK1 call. The team-alerts job pushes every score to it.
    func track(game: P1Game, pick: Pick?, locked: Bool) {
        guard enabled, let key = game.alertKey, game.phase == .live || game.phase == .pre,
              activities[key] == nil, !creating.contains(key) else { return }
        creating.insert(key)
        let call = locked ? nil : pick
        let side: String? = call.flatMap { p in
            P1GameMatch.same(game.home, p.pick, sport: game.sport) ? "home"
                : P1GameMatch.same(game.away, p.pick, sport: game.sport) ? "away" : nil
        }
        Task {
            defer { creating.remove(key) }
            // ActivityKit refuses attributes over 4096 bytes, and the two
            // crests are most of it: shrink them until the whole set fits.
            func attributes(_ home: Data?, _ away: Data?) -> Pick1GameAttributes {
                Pick1GameAttributes(
                    homeTeam: game.home.short, awayTeam: game.away.short,
                    homeAbbr: game.home.code, awayAbbr: game.away.code,
                    league: game.league, pickText: call?.displayPick ?? "",
                    gameId: key, sport: game.sport,
                    homeLogoPNG: home, awayLogoPNG: away,
                    homeColor: game.home.color, awayColor: game.away.color,
                    homeRecord: game.home.record, awayRecord: game.away.record,
                    startDate: game.date, pickSide: side,
                    pickProbability: call.map { Int($0.probability.rounded()) })
            }
            var attrs = attributes(nil, nil)
            for side in [40, 36, 32, 28, 24] as [CGFloat] {
                let home = await liveLogoData(game.home.logo, target: side)
                let away = await liveLogoData(game.away.logo, target: side)
                // Both crests or a smaller size: one logo and one sport icon looks broken.
                if (game.home.logo != nil && home == nil) || (game.away.logo != nil && away == nil) { continue }
                let candidate = attributes(home, away)
                if let size = try? JSONEncoder().encode(candidate).count, size < 3900 { attrs = candidate; break }
            }
            let h = game.home.score ?? 0, a = game.away.score ?? 0
            let status = game.phase == .live
                ? (game.detail.isEmpty ? "LIVE" : "LIVE · \(game.detail)")
                : "STARTS \(game.date.formatted(date: .omitted, time: .shortened))"
            // Hitting means ahead, not level: 0-0 is nobody's call yet.
            let hitting = side == "home" ? h > a : side == "away" ? a > h : false
            let state = Pick1GameAttributes.ContentState(homeScore: h, awayScore: a, statusLine: status,
                                                         pickHitting: hitting && game.phase == .live, isFinal: false)
            do {
                let act = try Activity.request(attributes: attrs,
                                               content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(1800)),
                                               pushType: .token)
                activities[key] = act
                if let side { pickSides[key] = side }
                observePushToken(act, gameId: key)
            } catch { }
        }
    }

    func stopTracking(_ game: P1Game) {
        guard let key = game.alertKey else { return }
        end(gameId: key)
    }

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
        for gid in activities.keys where !gid.hasPrefix("espn|") && !favoritePickGameIds.contains(gid) {
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
        guard score.isLive, !creating.contains(gid) else { return }
        creating.insert(gid)
        // Download + shrink the crests and resolve flags BEFORE requesting,
        // so the Lock Screen / Dynamic Island shows real logos, not just text.
        Task {
            let homePNG = await liveLogoData(pick.homeLogo)
            let awayPNG = await liveLogoData(pick.awayLogo)
            let (hFlag, aFlag) = flags(for: pick)
            defer { creating.remove(gid) }
            guard activities[gid] == nil else { return }
            let attrs = Pick1GameAttributes(
                homeTeam: teamShortName(pick.homeTeam, sport: pick.sport),
                awayTeam: teamShortName(pick.awayTeam, sport: pick.sport),
                homeAbbr: abbr(pick.homeTeam, sport: pick.sport),
                awayAbbr: abbr(pick.awayTeam, sport: pick.sport),
                league: displayLeague(pick.league),
                pickText: pick.displayPick,
                gameId: gid,
                sport: pick.sport,
                homeLogoPNG: homePNG, awayLogoPNG: awayPNG,
                homeFlag: hFlag, awayFlag: aFlag)
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
    }

    /// Download a crest and downscale it to a tiny PNG the Live Activity can
    /// carry. ActivityKit payloads are size-capped, so anything that doesn't
    /// shrink under the budget is dropped (the widget falls back to a flag
    /// or sport symbol).
    private func liveLogoData(_ urlString: String?, target: CGFloat = 44) async -> Data? {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let img = UIImage(data: data) else { return nil }
            let longest = max(img.size.width, img.size.height, 1)
            let scale = min(target / longest, 1)
            let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            guard let cg = img.cgImage, let png = TinyPNG.encode(cg, side: Int(target)) else { return nil }
            if png.count > 1100 { return nil }
            return png
        } catch { return nil }
    }

    /// Country flag emoji for national-team sports.
    private func flags(for pick: Pick) -> (String?, String?) {
        guard pick.sport == "soccer" || pick.sport == "cricket" else { return (nil, nil) }
        func f(_ team: String) -> String? {
            guard let code = wcFlagCode(for: nationalTeamBase(team)) else { return nil }
            return emojiFlag(for: code)
        }
        return (f(pick.homeTeam), f(pick.awayTeam))
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

    private struct TokenRow: Encodable {
        let user_id: String; let game_id: String; let token: String
        let pick_side: String?; let environment: String
    }

    private func uploadToken(gameId: String, token: String) async {
        guard let uid = SupabaseManager.client.auth.currentSession?.user.id else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        do {
            try await SupabaseManager.client.from("live_activity_tokens")
                .upsert(TokenRow(user_id: uid.uuidString, game_id: gameId, token: token,
                                 pick_side: pickSides[gameId], environment: environment),
                        onConflict: "token")
                .execute()
        } catch { }
    }

    private func deleteToken(gameId: String) async {
        guard let uid = SupabaseManager.client.auth.currentSession?.user.id else { return }
        pickSides[gameId] = nil
        do {
            try await SupabaseManager.client.from("live_activity_tokens")
                .delete().eq("game_id", value: gameId).eq("user_id", value: uid.uuidString).execute()
        } catch { }
    }
}
