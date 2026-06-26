// AthleteResolver.swift
// Dynamic athlete → (headshot, country flag) resolution.
//
// The hardcoded ID maps in TeamLogo.swift only cover ~118 fighters, so any
// fighter (or tennis player) outside the list fell back to a silhouette.
// This resolver fixes that for EVERYONE: when a name isn't in the map, it
// asks ESPN's public search API for the athlete ID, then ESPN's core API
// for the country flag. Results are cached in-memory + persisted, so each
// athlete is resolved once and then paints instantly.
//
// Everything is best-effort: any failure just leaves the existing
// silhouette + initials placeholder. No new build/runtime dependency —
// the app already hot-links these same ESPN image hosts.

import Foundation
import Combine

@MainActor
final class AthleteResolver: ObservableObject {
    static let shared = AthleteResolver()

    struct Info: Codable, Equatable {
        var headshot: String?
        var flag: String?
    }

    private var cache: [String: Info] = [:]
    private let defaultsKey = "pick1.athleteInfo.v1"

    private init() { load() }

    private func key(_ sport: String, _ name: String) -> String {
        sport + "|" + AthleteHeadshotLookup.norm(name)
    }

    /// Synchronous cache hit (nil if not resolved yet).
    func cached(sport: String, name: String) -> Info? { cache[key(sport, name)] }

    /// Resolve (and cache) the headshot + flag for an athlete. Returns the
    /// cached value instantly when present.
    func resolve(sport: String, name: String) async -> Info {
        let k = key(sport, name)
        if let hit = cache[k] { return hit }

        // 1. Athlete ID — hardcoded map first (instant), else ESPN search.
        var id = AthleteHeadshotLookup.athleteId(sport: sport, name: name)
        if id == nil { id = await searchAthleteId(sport: sport, name: name) }

        var info = Info(headshot: nil, flag: nil)
        if let id {
            info.headshot = "https://a.espncdn.com/i/headshots/\(headshotPath(sport))/players/full/\(id).png"
            info.flag = await fetchFlag(sport: sport, id: id)
        }
        cache[k] = info
        save()
        return info
    }

    // MARK: - ESPN lookups

    /// ESPN site search → first `player` result matching the sport.
    /// uid shape is "s:3301~a:4029275" — we pull the `a:` athlete id.
    private func searchAthleteId(sport: String, name: String) async -> String? {
        guard let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://site.api.espn.com/apis/search/v2?query=\(q)&limit=8")
        else { return nil }
        let want = espnSport(sport)
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return nil }
            for r in results {
                guard let contents = r["contents"] as? [[String: Any]] else { continue }
                for c in contents {
                    guard (c["type"] as? String) == "player",
                          (c["sport"] as? String) == want,
                          let uid = c["uid"] as? String,
                          let range = uid.range(of: "a:") else { continue }
                    let id = String(uid[range.upperBound...])
                    if !id.isEmpty, id.allSatisfy(\.isNumber) { return id }
                }
            }
        } catch { }
        return nil
    }

    /// ESPN core API → the athlete's country flag image href.
    private func fetchFlag(sport: String, id: String) async -> String? {
        guard let url = URL(string:
            "https://sports.core.api.espn.com/v2/sports/\(espnSport(sport))/athletes/\(id)?lang=en")
        else { return nil }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let flag = json["flag"] as? [String: Any],
                  let href = flag["href"] as? String else { return nil }
            return href
        } catch { return nil }
    }

    // MARK: - Sport mapping

    /// ESPN's `sport` value in search results / core-API path.
    private func espnSport(_ sport: String) -> String {
        switch sport {
        case "combat": return "mma"
        case "tennis": return "tennis"
        case "f1":     return "racing"
        case "golf":   return "golf"
        default:       return sport
        }
    }

    /// ESPN headshot CDN sub-path (matches AthleteHeadshotLookup).
    private func headshotPath(_ sport: String) -> String {
        switch sport {
        case "combat": return "mma"
        case "f1":     return "rpm"
        case "tennis": return "tennis"
        case "golf":   return "golf"
        default:       return "mma"
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: Info].self, from: data)
        else { return }
        cache = decoded
    }
    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
