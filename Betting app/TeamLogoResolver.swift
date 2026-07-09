// TeamLogoResolver.swift
// Dynamic team-logo resolution — the team counterpart to AthleteResolver.
//
// Team crests come from (1) pipeline-captured URLs (TeamLogoStore) and
// (2) hardcoded abbreviation maps (NBA/NFL/MLB/NHL + soccer/cricket IDs).
// Anything those miss — WNBA, EuroLeague, NCAA, KBO/NPB, etc. — used to
// fall straight to the generic colored crest. This resolver fills that
// gap: it asks ESPN's public search API for the team's real logo and
// caches it, so every league gets its actual crest instead of a shield.
//
// Best-effort: any failure just leaves the colored Crest (no regression).

import Foundation
import Combine

@MainActor
final class TeamLogoResolver: ObservableObject {
    static let shared = TeamLogoResolver()

    // Value is the logo URL string; "" means "resolved, none found" so we
    // don't re-hit the network for a team ESPN doesn't know. Negative
    // entries are SESSION-ONLY — a transient network failure must not be
    // persisted as "this team has no logo" forever (that's exactly how
    // the Atlanta Dream got stuck on the generic shield across launches).
    private var cache: [String: String] = [:]
    private let defaultsKey = "pick1.teamLogo.v2"

    private init() {
        load()
        // One-time migration: v1 persisted failed lookups as "" and
        // re-served them forever. Drop the whole poisoned store.
        UserDefaults.standard.removeObject(forKey: "pick1.teamLogo.v1")
    }

    private func key(_ sport: String, _ team: String) -> String {
        sport + "|" + TeamLogoStore.normKey(team)
    }

    func cached(sport: String, team: String) -> URL? {
        guard let s = cache[key(sport, team)], !s.isEmpty else { return nil }
        return URL(string: s)
    }

    func resolve(sport: String, team: String) async -> URL? {
        let k = key(sport, team)
        if let s = cache[k] { return s.isEmpty ? nil : URL(string: s) }
        // ESPN covers US majors + WNBA/NCAA/MLS; TheSportsDB fills the
        // gaps ESPN doesn't index (KBO, NPB, EuroLeague, KHL, lower
        // soccer, …) so smaller leagues still get a real crest.
        var url = await searchESPN(sport: sport, team: team)
        if url == nil { url = await searchSportsDB(sport: sport, team: team) }
        cache[k] = url?.absoluteString ?? ""
        save()
        return url
    }

    /// TheSportsDB search → team badge. Free, broad international coverage.
    private func searchSportsDB(sport: String, team: String) async -> URL? {
        guard let q = team.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.thesportsdb.com/api/v1/json/3/searchteams.php?t=\(q)")
        else { return nil }
        let want = sportsDBSport(sport)
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 8
            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let teams = json["teams"] as? [[String: Any]] else { return nil }
            // Prefer the same-sport match; else first team with a badge.
            func badge(_ t: [String: Any]) -> URL? {
                if let s = t["strBadge"] as? String, let u = URL(string: s) { return u }
                if let s = t["strTeamBadge"] as? String, let u = URL(string: s) { return u }
                return nil
            }
            if let match = teams.first(where: { ($0["strSport"] as? String) == want }),
               let u = badge(match) { return u }
            for t in teams { if let u = badge(t) { return u } }
        } catch { }
        return nil
    }

    private func sportsDBSport(_ sport: String) -> String {
        switch sport {
        case "basketball": return "Basketball"
        case "football":   return "American Football"
        case "baseball":   return "Baseball"
        case "hockey":     return "Ice Hockey"
        case "soccer":     return "Soccer"
        case "cricket":    return "Cricket"
        default:           return sport
        }
    }

    /// ESPN site search → first `team` result matching the sport, taking
    /// its logo image.
    private func searchESPN(sport: String, team: String) async -> URL? {
        guard let q = team.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
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
                    guard (c["type"] as? String) == "team",
                          (c["sport"] as? String) == want else { continue }
                    if let img = c["image"] as? [String: Any],
                       let s = img["default"] as? String, let u = URL(string: s) { return u }
                    if let s = c["image"] as? String, let u = URL(string: s) { return u }
                }
            }
        } catch { }
        return nil
    }

    private func espnSport(_ sport: String) -> String {
        // App sport → ESPN `sport` string in search results.
        switch sport {
        case "basketball": return "basketball"
        case "football":   return "football"
        case "baseball":   return "baseball"
        case "hockey":     return "hockey"
        case "soccer":     return "soccer"
        case "cricket":    return "cricket"
        default:           return sport
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        cache = decoded
    }
    private func save() {
        // Persist positive hits only — misses stay in-memory so the next
        // launch retries them (the miss may have been a network blip).
        let positives = cache.filter { !$0.value.isEmpty }
        if let data = try? JSONEncoder().encode(positives) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
