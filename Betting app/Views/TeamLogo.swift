// TeamLogo.swift
// Renders a real team logo (NBA, NFL, MLB, NHL, EPL) with an automatic
// fallback to the colored shield crest from Pick1HomeHiFi.swift if the
// logo can't be resolved.
//
// Logo source
// ───────────
// Hot-linked from ESPN's public team-logo CDN
//   https://a.espncdn.com/i/teamlogos/{league}/500/{abbrev}.png
//
// This is what most independent sports apps do — ESPN allows hot-linking
// and the URLs are stable. Logos themselves remain trademarked by the
// teams/leagues, so for paid commercial apps the long-term right move is
// to license through SportsLogos.net or similar (~$200-500/yr) and ship
// the logos in the asset catalog. For v1 the CDN approach is fine.
//
// For sports where picks are individual athletes (ATP, UFC, F1) we don't
// have stable per-athlete imagery, so we keep the colored shield crest.

import SwiftUI
import UIKit

// ════════════════════════════════════════════════════════════════════
// MARK: - CachedImage — the one image loader behind every logo / flag /
//         headshot. Fixes the "a couple are always missing" problem.
// ════════════════════════════════════════════════════════════════════
//
// SwiftUI's AsyncImage keeps no decoded in-memory cache and never
// retries: every time a card scrolls back on screen it re-requests, and
// any transient CDN hiccup leaves that one slot stuck on the placeholder
// — which reads as "missing". CachedImage fixes all three:
//   1. Decoded UIImages live in a process-wide NSCache, so once a logo
//      has loaded it paints instantly forever after — no re-flash.
//   2. Transient failures retry a few times with backoff before giving
//      up, so a single dropped request doesn't blank a badge.
//   3. The caller's branded fallback shows until the real image is
//      ready — the slot is never empty.
// Drop-in shaped like AsyncImage(url:content:placeholder:).

/// Process-wide decoded-image cache (keyed by absolute URL).
enum ImageMemoryCache {
    static let shared: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 600            // plenty for a full slate of crests
        return c
    }()
}

struct CachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let img = uiImage {
                content(Image(uiImage: img))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    @MainActor
    private func load() async {
        guard let url else { uiImage = nil; return }
        let key = url as NSURL
        if let cached = ImageMemoryCache.shared.object(forKey: key) {
            uiImage = cached
            return
        }
        // Recycled cell with a new URL: drop the stale image so the
        // placeholder shows instead of the previous team's logo.
        uiImage = nil
        for attempt in 0..<3 {
            if Task.isCancelled { return }
            do {
                var req = URLRequest(url: url)
                req.cachePolicy = .returnCacheDataElseLoad   // reuse prefetched bytes
                req.timeoutInterval = 12
                let (data, _) = try await URLSession.shared.data(for: req)
                if let img = UIImage(data: data) {
                    ImageMemoryCache.shared.setObject(img, forKey: key)
                    if !Task.isCancelled { uiImage = img }
                    return
                }
                return   // got bytes but not an image — don't hammer the CDN
            } catch {
                if Task.isCancelled { return }
                // brief backoff, then retry the transient failure
                try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 350_000_000)
            }
        }
    }
}

/// Real team-crest URLs captured by the pipeline from ESPN (keyed by
/// normalized team name). Populated from loaded picks on each refresh,
/// so TeamLogo resolves any team's actual logo without a hardcoded
/// name→id map. In-memory only; repopulated every launch.
enum TeamLogoStore {
    private static var map: [String: String] = [:]

    static func normKey(_ name: String) -> String {
        name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    static func register(picks: [Pick]) {
        for p in picks {
            if let h = p.homeLogo, !h.isEmpty { map[normKey(p.homeTeam)] = h }
            if let a = p.awayLogo, !a.isEmpty { map[normKey(p.awayTeam)] = a }
        }
    }

    static func url(for team: String) -> URL? {
        guard let s = map[normKey(team)] else { return nil }
        return URL(string: s)
    }
}

struct TeamLogo: View {
    let sport: String
    let team: String
    let size: Crest.Size

    /// Dynamically-resolved logo (ESPN search) when the pipeline + hardcoded
    /// maps miss — e.g. WNBA, EuroLeague, NCAA, KBO/NPB.
    @State private var resolvedURL: URL?

    /// Instant logo from the pipeline-captured URL or the hardcoded maps.
    private var staticURL: URL? {
        TeamLogoStore.url(for: team) ?? TeamLogoLookup.url(sport: sport, team: team)
    }

    var body: some View {
        // Individual-athlete sports (UFC / F1 / Tennis) — render the
        // athlete's headshot in a circle instead of a team crest.
        if AthleteHeadshot.isIndividual(sport: sport) {
            AthleteHeadshot(sport: sport, name: team, size: size)
        } else if sport == "soccer" || sport == "cricket",
                  let code = wcFlagCode(for: nationalTeamBase(team)) {
            // National teams (Summer Football, international cricket) —
            // country flag, not a club crest. Squad suffixes are
            // stripped first ("England Women" → England 🏴). Clubs and
            // IPL franchises miss the country map and fall through to
            // the ESPN/crest path below.
            WCFlag(code: code)
                .frame(width: size.w * 0.92, height: size.w * 0.62)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .frame(width: size.w, height: size.h)
        } else {
            teamCrest
        }
    }

    /// Real crest when we have a URL (pipeline / hardcoded / dynamically
    /// resolved), otherwise the colored shield. Kicks off a dynamic ESPN
    /// lookup when the fast paths miss so unmapped leagues still get a
    /// real logo instead of a generic shield.
    @ViewBuilder
    private var teamCrest: some View {
        Group {
            if let url = staticURL ?? resolvedURL {
                CachedImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(size == .big ? 4 : 2)
                        .frame(width: size.w, height: size.h)
                } placeholder: {
                    Crest(team: team, size: size)
                }
            } else {
                // Colored shield while the dynamic lookup runs / if it fails.
                Crest(team: team, size: size)
            }
        }
        .task(id: team) {
            guard staticURL == nil else { return }
            resolvedURL = TeamLogoResolver.shared.cached(sport: sport, team: team)
            if resolvedURL == nil {
                resolvedURL = await TeamLogoResolver.shared.resolve(sport: sport, team: team)
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - LeagueLogo — real league crest for sport-hub league chips
// ════════════════════════════════════════════════════════════════

/// Renders a league's real crest (UEFA Champions League, Bundesliga,
/// La Liga, NBA, NFL …) hot-linked from ESPN's public league-logo CDN —
/// the same approach `TeamLogo` already uses for team crests. Leagues
/// ESPN doesn't serve a logo for (NCAAF, CFL, the tennis tours, F1)
/// fall back to a clean branded tile: a white sport SF Symbol on the
/// league's brand-color swatch.
///
/// All endpoints were curl-probed (HTTP 200) before mapping; see
/// `LeagueLogoLookup.url(_:)`.
struct LeagueLogo: View {
    let leagueId: String
    /// SF Symbol used when there's no ESPN logo for this league.
    let fallbackSymbol: String
    /// Brand color for the fallback tile background.
    let swatch: Color
    var size: CGFloat = 18

    var body: some View {
        if let url = LeagueLogoLookup.url(leagueId) {
            CachedImage(url: url) { image in
                // League marks are designed for a light ground, so sit
                // them on a small white tile regardless of the chip's
                // active/inactive state.
                image
                    .resizable()
                    .scaledToFit()
                    .padding(2)
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white)
                    )
            } placeholder: {
                fallbackTile
            }
            .frame(width: size, height: size)
        } else {
            fallbackTile
        }
    }

    private var fallbackTile: some View {
        Image(systemName: fallbackSymbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(swatch)
            )
    }
}

/// Maps a Pick1 league id → an ESPN CDN league-logo URL. Endpoints
/// confirmed live (HTTP 200) by curl probe:
///   • Soccer  https://a.espncdn.com/i/leaguelogos/soccer/500/{espnId}.png
///   • US      https://a.espncdn.com/i/teamlogos/leagues/500/{slug}.png
///   • Cricket https://a.espncdn.com/i/leaguelogos/cricket/500/{espnId}.png
/// Anything not mapped returns nil → LeagueLogo draws the branded
/// SF-symbol fallback tile instead.
enum LeagueLogoLookup {
    static func url(_ leagueId: String) -> URL? {
        let path: String?
        switch leagueId {
        // ── Soccer (ESPN numeric competition IDs) ──
        case "ucl":        path = "leaguelogos/soccer/500/2"
        case "epl":        path = "leaguelogos/soccer/500/23"
        case "laliga":     path = "leaguelogos/soccer/500/15"
        case "bundesliga": path = "leaguelogos/soccer/500/10"
        case "seriea":     path = "leaguelogos/soccer/500/12"
        case "mls":        path = "leaguelogos/soccer/500/19"
        case "ligue1":     path = "leaguelogos/soccer/500/9"
        case "ligamx":     path = "leaguelogos/soccer/500/22"
        // ── US major leagues ──
        case "nba":        path = "teamlogos/leagues/500/nba"
        case "nfl":        path = "teamlogos/leagues/500/nfl"
        case "mlb":        path = "teamlogos/leagues/500/mlb"
        case "nhl":        path = "teamlogos/leagues/500/nhl"
        case "xfl":        path = "teamlogos/leagues/500/xfl"
        case "ufc":        path = "teamlogos/leagues/500/ufc"
        case "wnba":       path = "teamlogos/leagues/500/wnba"
        // ── Cricket ──
        case "ipl":        path = "leaguelogos/cricket/500/8048"
        // No ESPN logo: gleague, ncaab, euroleague, ncaaf, cfl,
        // npb, kbo, khl, ahl, ncaa, bbl, t20i, test, atp, wta,
        // slam, f1 → branded fallback tile.
        default:           path = nil
        }
        guard let path else { return nil }
        return URL(string: "https://a.espncdn.com/i/\(path).png")
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - AthleteHeadshot — circular face for individual sports
// ════════════════════════════════════════════════════════════════

/// Circular athlete headshot for sports where the "team" is actually a
/// single person — UFC fighters, F1 drivers, ATP players. Uses ESPN's
/// athlete-headshot CDN when we have an ID for the name, otherwise
/// renders a clean profile-circle placeholder (silhouette or initials)
/// instead of the team-style colored shield.
struct AthleteHeadshot: View {
    let sport: String
    let name: String
    let size: Crest.Size

    static func isIndividual(sport: String) -> Bool {
        switch sport {
        case "combat", "f1", "tennis", "golf": return true
        default: return false
        }
    }

    /// Resolved headshot + country flag (dynamic, cached). Seeded
    /// synchronously from cache so a known athlete paints with no flash.
    @State private var info: AthleteResolver.Info?

    /// Best headshot URL: dynamically-resolved first, then the hardcoded
    /// map, then nil (→ silhouette placeholder).
    private var headshotURL: URL? {
        if let s = info?.headshot, let u = URL(string: s) { return u }
        return AthleteHeadshotLookup.url(sport: sport, name: name)
    }

    var body: some View {
        ZStack {
            // Always-present background ring + fill so the headshot
            // sits inside a clean profile circle.
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#22252B"), Color(hex: "#101114")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .overlay(Circle().stroke(Color(hex: "#2D3038"), lineWidth: 1))

            if let url = headshotURL {
                CachedImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
                .clipShape(Circle())
            } else {
                placeholder
            }
        }
        .frame(width: dimension, height: dimension)
        .clipShape(Circle())
        // Country flag badge, bottom-trailing — appears once resolved.
        .overlay(alignment: .bottomTrailing) { flagBadge }
        .task(id: name) {
            info = AthleteResolver.shared.cached(sport: sport, name: name)
            if info?.headshot == nil || info?.flag == nil {
                info = await AthleteResolver.shared.resolve(sport: sport, name: name)
            }
        }
    }

    /// Small circular country flag pinned to the headshot corner.
    @ViewBuilder
    private var flagBadge: some View {
        if let f = info?.flag, let u = URL(string: f) {
            let d = dimension * 0.36
            CachedImage(url: u) { img in
                img.resizable().scaledToFill()
            } placeholder: { Color.clear }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(hex: "#0A0B0D"), lineWidth: 1.5))
            .offset(x: 1, y: 1)
        }
    }

    /// Square (so the circle reads as a profile pic rather than a tall
    /// crest). Slight bump from the team-crest height so faces have
    /// breathing room.
    private var dimension: CGFloat {
        size == .big ? 72 : 44
    }

    /// Initials over a soft gradient — used when we don't have a real
    /// headshot URL or the load fails.
    private var placeholder: some View {
        ZStack {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .padding(size == .big ? 18 : 11)
                .foregroundColor(Color(hex: "#6E6F75"))
            // Initials overlay so each athlete still feels distinct
            // even without a real photo.
            VStack {
                Spacer()
                Text(initials)
                    .font(.archivoNarrow(size == .big ? 11 : 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(Color(hex: "#B9B7B0"))
                    .padding(.bottom, size == .big ? 6 : 3)
            }
        }
    }

    /// 2-3 letter initials from the athlete's name. "Alex Pereira" →
    /// "AP"; single-token names ("Verstappen") → first 3 letters.
    private var initials: String {
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2,
           let first = parts.first?.first,
           let last  = parts.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(3)).uppercased()
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Athlete headshot lookup
// ════════════════════════════════════════════════════════════════

enum AthleteHeadshotLookup {
    /// Returns an ESPN headshot URL for the given (sport, name) when
    /// we have an athlete ID for it. Lookup is fuzzy on last-name to
    /// catch "Volk" / "Volkanovski" / "Alexander Volkanovski".
    static func url(sport: String, name: String) -> URL? {
        switch sport {
        case "combat":
            guard let id = lookup(in: ufcIds, name: name) else { return nil }
            return URL(string: "https://a.espncdn.com/i/headshots/mma/players/full/\(id).png")
        case "f1":
            // F1 + NASCAR share ESPN's "rpm" (racing) headshot path, so
            // both driver tables resolve through the same case.
            guard let id = lookup(in: f1Ids, name: name)
                        ?? lookup(in: nascarIds, name: name) else { return nil }
            return URL(string: "https://a.espncdn.com/i/headshots/rpm/players/full/\(id).png")
        case "tennis":
            guard let id = lookup(in: tennisIds, name: name) else { return nil }
            return URL(string: "https://a.espncdn.com/i/headshots/tennis/players/full/\(id).png")
        default:
            return nil
        }
    }

    /// The ESPN athlete ID for a (sport, name), from the hardcoded maps —
    /// the instant fast-path the dynamic `AthleteResolver` tries before
    /// hitting ESPN's search API.
    static func athleteId(sport: String, name: String) -> String? {
        switch sport {
        case "combat": return lookup(in: ufcIds, name: name)
        case "f1":     return lookup(in: f1Ids, name: name) ?? lookup(in: nascarIds, name: name)
        case "tennis": return lookup(in: tennisIds, name: name)
        default:       return nil
        }
    }

    /// Normalize a name the same way the ID tables are keyed: lowercase,
    /// strip accents, and drop any non-alphanumeric (apostrophes, periods,
    /// hyphens) so "O'Malley", "Hülkenberg", and "Stenhouse Jr." all match.
    static func norm(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
            .joined()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Match against the table by full normalized name, then last-name
    /// (after dropping Jr./Sr./III suffixes), then first name.
    private static func lookup(in table: [String: String], name: String) -> String? {
        let full = norm(name)
        if full.isEmpty { return nil }
        if let hit = table[full] { return hit }
        var tokens = full.split(separator: " ").map(String.init)
        let suffixes: Set<String> = ["jr", "sr", "ii", "iii", "iv", "v"]
        while tokens.count > 1, suffixes.contains(tokens.last!) { tokens.removeLast() }
        if let last = tokens.last, let hit = table[last] { return hit }
        if let first = tokens.first, let hit = table[first] { return hit }
        return nil
    }
}

// MARK: - Athlete IDs (ESPN)
//
// Verified-working IDs only — every entry below was confirmed to
// resolve to a real headshot via the ESPN CDN. When a pick's athlete
// isn't in the table, AthleteHeadshot renders the silhouette +
// initials placeholder instead (still much cleaner than the
// team-style colored shield it used to fall through to).
//
// To add more IDs: hit ESPN's athlete-search API or use the
// pipeline's sportsdata.io headshot URL when we wire that field
// into the picks model.

private let ufcIds: [String: String] = [
    "adesanya": "4285679", "israel adesanya": "4285679",
    "volkanovski": "3949584", "alexander volkanovski": "3949584",
    "blachowicz": "2506250", "jan blachowicz": "2506250",
    "figueiredo": "4189320", "deiveson figueiredo": "4189320",
    "usman": "3088812", "kamaru usman": "3088812",
    "ngannou": "3933168", "francis ngannou": "3933168",
    "oliveira": "2504169", "charles oliveira": "2504169",
    "namajunas": "3032973", "rose namajunas": "3032973",
    "randamie": "2552777", "germaine de randamie": "2552777",
    "poirier": "2506549", "dustin poirier": "2506549",
    "nunes": "2516131", "amanda nunes": "2516131",
    "cyborg": "2354564", "cris cyborg": "2354564",
    "weili": "4350762", "zhang weili": "4350762",
    "holm": "3028404", "holly holm": "3028404",
    "miocic": "2504951", "stipe miocic": "2504951",
    "andrade": "3024395", "jessica andrade": "3024395",
    "volkov": "2993650", "alexander volkov": "2993650",
    "lewis": "2560713", "derrick lewis": "2560713",
    "gane": "4426000", "ciryl gane": "4426000",
    "nemkov": "3955014", "vadim nemkov": "3955014",
    "blaydes": "3922557", "curtis blaydes": "3922557",
    "rozenstruik": "4410084", "jairzinho rozenstruik": "4410084",
    "overeem": "2335516", "alistair overeem": "2335516",
    "reyes": "4233039", "dominick reyes": "4233039",
    "costa": "4080826", "paulo costa": "4080826",
    "sterling": "3031559", "aljamain sterling": "3031559",
    "bader": "2335530", "ryan bader": "2335530",
    "teixeira": "2504929", "glover teixeira": "2504929",
    "prochzka": "3156612", "ji prochzka": "3156612",
    "cannonier": "3154860", "jared cannonier": "3154860",
    "rakic": "4079314", "aleksandar rakic": "4079314",
    "vettori": "4001851", "marvin vettori": "4001851",
    "whittaker": "3009717", "robert whittaker": "3009717",
    "cerminara": "4026490", "katlyn cerminara": "4026490",
    "thiago santos": "3045798",
    "anderson": "3112020", "corey anderson": "3112020",
    "shevchenko": "2554705", "valentina shevchenko": "2554705",
    "brunson": "2560056", "derek brunson": "2560056",
    "covington": "3088810", "colby covington": "3088810",
    "hermansson": "3074102", "jack hermansson": "3074102",
    "till": "3897436", "darren till": "3897436",
    "mousasi": "2431313", "gegard mousasi": "2431313",
    "chandler": "2504988", "michael chandler": "2504988",
    "gaethje": "3022345", "justin gaethje": "3022345",
    "edwards": "3152929", "leon edwards": "3152929",
    "luque": "3045887", "vicente luque": "3045887",
    "burns": "3090197", "gilbert burns": "3090197",
    "macdonald": "2501814", "rory macdonald": "2501814",
    "masvidal": "2500857", "jorge masvidal": "2500857",
    "thompson": "2615077", "stephen thompson": "2615077",
    "lima": "2500691", "douglas lima": "2500691",
    "dariush": "3085551", "beneil dariush": "3085551",
    "chiesa": "2960681", "michael chiesa": "2960681",
    "hooker": "3109135", "dan hooker": "3109135",
    "makhachev": "3332412", "islam makhachev": "3332412",
    "ortega": "3045737", "brian ortega": "3045737",
    "holloway": "2614933", "max holloway": "2614933",
    "barboza": "2526299", "edson barboza": "2526299",
    "gillespie": "4021934", "gregor gillespie": "4021934",
    "yair rodriguez": "3155420",
    "emmett": "4011299", "josh emmett": "4011299",
    "pitbull": "2532870", "patricio pitbull": "2532870",
    "yan": "4293517", "petr yan": "4293517",
    "kattar": "3164030", "calvin kattar": "3164030",
    "sandhagen": "4294504", "cory sandhagen": "4294504",
    "anjos": "2335687", "rafael dos anjos": "2335687",
    "felder": "3099985", "paul felder": "3099985",
    "jung": "2501685", "chan sung jung": "2501685",
    "garbrandt": "3163637", "cody garbrandt": "3163637",
    "font": "3090451", "rob font": "3090451",
    "aldo": "2447641", "jos aldo": "2447641",
    "moreno": "3027545", "brandon moreno": "3027545",
    "adriano moraes": "3081236",
    "perez": "3155425", "alex perez": "3155425",
    "munhoz": "3045734", "pedro munhoz": "3045734",
    "marlon moraes": "2553310",
    "assuncao": "2354364", "raphael assuncao": "2354364",
    "askarov": "4064692", "askar askarov": "4064692",
    "edgar": "2335694", "frankie edgar": "2335694",
    "royval": "4239928", "brandon royval": "4239928",
    "karafrance": "4243885", "kai karafrance": "4243885",
    "pantoja": "2560746", "alexandre pantoja": "2560746",
    "johnson": "2512089", "demetrious johnson": "2512089",
    "yana santos": "3154898",
    "aldana": "3136286", "irene aldana": "3136286",
    "pea": "2951361", "julianna pea": "2951361",
    "bontorin": "4280789", "rogerio bontorin": "4280789",
    "gadelha": "3011878", "claudia gadelha": "3011878",
    "maia": "3022348", "jennifer maia": "3022348",
    "tecia pennington": "3032972",
    "raquel pennington": "2995167",
    "watersongomez": "2951504", "michelle watersongomez": "2951504",
    "murphy": "3075001", "lauren murphy": "3075001",
    "dern": "4021217", "mackenzie dern": "4021217",
    "marina rodriguez": "4379258",
    "xiaonan": "4275487", "yan xiaonan": "4275487",
    "macfarlane": "3924103", "ilimalei macfarlane": "3924103",
    "chiasson": "4334306", "macy chiasson": "4334306",
    "vieira": "4039865", "ketlen vieira": "4039865",
    "calvillo": "4085155", "cynthia calvillo": "4085155",
    "esparza": "2559934", "carla esparza": "2559934",
    "wood": "3028064", "joanne wood": "3028064",
    "velasquez": "4257422", "juliana velasquez": "4257422",
    "carmouche": "2554674", "liz carmouche": "2554674",
    "omalley": "4205093", "sean omalley": "4205093",
    "pereira": "4705658", "alex pereira": "4705658",
    "plessis": "3166126", "dricus du plessis": "3166126",
    "topuria": "4350812", "ilia topuria": "4350812",
    "aspinall": "4010976", "tom aspinall": "4010976",
    "chimaev": "4684751", "khamzat chimaev": "4684751",
    "dvalishvili": "3948572", "merab dvalishvili": "3948572",
    "evloev": "4029275", "movsar evloev": "4029275",
    "ankalaev": "4273399", "magomed ankalaev": "4273399",
    "muhammad": "3172112", "belal muhammad": "3172112",
    "tsarukyan": "4419372", "arman tsarukyan": "4419372",
    "jones": "2335639", "jon jones": "2335639",
    "pimblett": "4008549", "paddy pimblett": "4008549",
    "rakhmonov": "4020699", "shavkat rakhmonov": "4020699",
]

private let f1Ids: [String: String] = [
    // Full 2026 grid — every ID verified to resolve on ESPN's CDN
    // (/i/headshots/rpm/players/full/<id>.png) and confirmed against
    // the athlete's real name via ESPN's racing API.
    "hamilton":   "868",   "lewis hamilton":     "868",
    "leclerc":    "5498",  "charles leclerc":    "5498",
    "verstappen": "4665",  "max verstappen":     "4665",
    "tsunoda":    "5652",  "yuki tsunoda":       "5652",
    "norris":     "5579",  "lando norris":       "5579",
    "piastri":    "5752",  "oscar piastri":      "5752",
    "russell":    "5503",  "george russell":     "5503",
    "antonelli":  "5829",  "kimi antonelli":     "5829", "andrea kimi antonelli": "5829",
    "alonso":     "348",   "fernando alonso":    "348",
    "stroll":     "4775",  "lance stroll":       "4775",
    "sainz":      "4686",  "carlos sainz":       "4686",
    "albon":      "5592",  "alexander albon":    "5592", "alex albon": "5592",
    "gasly":      "5501",  "pierre gasly":       "5501",
    "doohan":     "5746",  "jack doohan":        "5746",
    "colapinto":  "5823",  "franco colapinto":   "5823",
    "lawson":     "5741",  "liam lawson":        "5741",
    "hadjar":     "5790",  "isack hadjar":       "5790",
    "ocon":       "4678",  "esteban ocon":       "4678",
    "bearman":    "5789",  "oliver bearman":     "5789", "ollie bearman": "5789",
    "hulkenberg": "4396",  "nico hulkenberg":    "4396", "nico hülkenberg": "4396", "hülkenberg": "4396",
    "bortoleto":  "5835",  "gabriel bortoleto":  "5835",
    "zhou":       "5682",  "guanyu zhou":        "5682", "zhou guanyu": "5682",
    "bottas":     "4520",  "valtteri bottas":    "4520",
    "perez":      "4472",  "sergio perez":       "4472", "sergio pérez": "4472", "pérez": "4472",
]

/// NASCAR Cup Series driver IDs — same ESPN "rpm" headshot path as F1,
/// every ID verified to resolve on the CDN and name-matched against
/// ESPN's racing API. Keyed by last name + full name (fuzzy lookup
/// also catches first/last token).
private let nascarIds: [String: String] = [
    "larson":     "4539",  "kyle larson":        "4539",
    "byron":      "4721",  "william byron":      "4721",
    "elliott":    "4574",  "chase elliott":      "4574",
    "bowman":     "4555",  "alex bowman":        "4555",
    "hamlin":     "747",   "denny hamlin":       "747",
    "bell":       "4700",  "christopher bell":   "4700",
    "gibbs":      "5651",  "ty gibbs":           "5651",
    "reddick":    "4577",  "tyler reddick":      "4577",
    "wallace":    "4534",  "bubba wallace":      "4534",
    "blaney":     "4531",  "ryan blaney":        "4531",
    "logano":     "4319",  "joey logano":        "4319",
    "cindric":    "4718",  "austin cindric":     "4718",
    "keselowski": "626",   "brad keselowski":    "626",
    "buescher":   "4480",  "chris buescher":     "4480",
    "preece":     "4585",  "ryan preece":        "4585",
    "chastain":   "4495",  "ross chastain":      "4495",
    "suarez":     "4645",  "daniel suarez":      "4645",
    "briscoe":    "4773",  "chase briscoe":      "4773",
    "jones":      "4777",  "erik jones":         "4777",
    "hocevar":    "5610",  "carson hocevar":     "5610",
    "dillon":     "4332",  "austin dillon":      "4332",
    "berry":      "4656",  "josh berry":         "4656",
    "gilliland":  "4782",  "todd gilliland":     "4782",
    "mcdowell":   "4729",  "michael mcdowell":   "4729",
    "stenhouse":  "4351",  "ricky stenhouse jr.": "4351", "ricky stenhouse": "4351",
    "allmendinger":"805",  "aj allmendinger":    "805",
    "nemechek":   "4612",  "john hunter nemechek":"4612",
    "gragson":    "4768",  "noah gragson":       "4768",
    "custer":     "4634",  "cole custer":        "4634",
]

/// Verified ATP tennis IDs (mined from ESPN search.image URLs and
/// confirmed against the headshot CDN at /tennis/players/full/).
private let tennisIds: [String: String] = [
    "djokovic":      "296",      "novak djokovic":     "296",
    "alcaraz":       "3782",     "carlos alcaraz":     "3782",
    "sinner":        "3623",     "jannik sinner":      "3623",
    "zverev":        "2375",     "alexander zverev":   "2375",
    "tsitsipas":     "2869",     "stefanos tsitsipas": "2869",
    "medvedev":      "2383",     "daniil medvedev":    "2383",
    "rublev":        "2642",     "andrey rublev":      "2642",
    "ruud":          "2989",     "casper ruud":        "2989",
    "fritz":         "2946",     "taylor fritz":       "2946",
    "schwartzman":   "2324",     "diego schwartzman":  "2324",
    "tiafoe":        "2708",     "frances tiafoe":     "2708",
    "shapovalov":    "2860",     "denis shapovalov":   "2860",
    "auger-aliassime":"3209",    "felix auger-aliassime":"3209",
    "paul":          "2964",     "tommy paul":         "2964",
    "dimitrov":      "1287",     "grigor dimitrov":    "1287",
    "de minaur":     "2651",     "alex de minaur":     "2651", "minaur": "2651",
    "musetti":       "3764",     "lorenzo musetti":    "3764",
    "khachanov":     "2367",     "karen khachanov":    "2367",
    "hurkacz":       "2726",     "hubert hurkacz":     "2726",
    // WTA — current top women so women's picks aren't all silhouettes
    "swiatek":       "3730",     "iga swiatek":        "3730",
    "sabalenka":     "3038",     "aryna sabalenka":    "3038",
    "gauff":         "3626",     "coco gauff":         "3626",
    "rybakina":      "3126",     "elena rybakina":     "3126",
    "pegula":        "2113",     "jessica pegula":     "2113",
    "keys":          "1556",     "madison keys":       "1556",
    "kasatkina":     "2191",     "daria kasatkina":    "2191",
]

// ════════════════════════════════════════════════════════════════
// MARK: - Lookup
// ════════════════════════════════════════════════════════════════

enum TeamLogoLookup {
    /// Returns an ESPN CDN URL for the given (sport, team), or nil if
    /// we can't map it. Nil falls back to the colored crest.
    static func url(sport: String, team: String) -> URL? {
        // Direct-URL table first — covers leagues with no ESPN CDN path
        // (KBO, NPB, Major League Cricket, UCL qualifiers, West Indies).
        // Every URL curl-verified 200 before being added.
        if let direct = directLogoURLs[TeamLogoStore.normKey(team)] {
            return URL(string: direct)
        }
        let leagueSlug: String
        let table: [String: String]
        switch sport {
        case "basketball":
            // NBA first, then WNBA — names never collide (Hawks/Dream,
            // Warriors/Valkyries) so the sequential try is safe.
            if let ab = abbreviation(in: nbaAbbrevs, team: team) {
                return URL(string: "https://a.espncdn.com/i/teamlogos/nba/500/\(ab).png")
            }
            if let ab = abbreviation(in: wnbaAbbrevs, team: team) {
                return URL(string: "https://a.espncdn.com/i/teamlogos/wnba/500/\(ab).png")
            }
            return nil
        case "football":
            leagueSlug = "nfl"
            table = nflAbbrevs
        case "baseball":
            leagueSlug = "mlb"
            table = mlbAbbrevs
        case "hockey":
            leagueSlug = "nhl"
            table = nhlAbbrevs
        case "soccer":
            // Soccer uses team IDs not 3-letter codes, look up directly.
            return soccerLogoURL(team: team)
        case "cricket":
            // IPL uses ESPN cricket team IDs — same name-keyed lookup
            // approach as soccer.
            return cricketLogoURL(team: team)
        default:
            return nil
        }

        guard let abbrev = abbreviation(in: table, team: team) else { return nil }
        return URL(string: "https://a.espncdn.com/i/teamlogos/\(leagueSlug)/500/\(abbrev).png")
    }

    /// Tries multiple normalisations of the input team string against the
    /// dictionary so we hit on "Cavaliers", "CLE", "Cleveland Cavaliers",
    /// "cleveland-cavaliers", etc. Returns the lowercase ESPN abbreviation.
    private static func abbreviation(in table: [String: String], team: String) -> String? {
        var trimmed = team.trimmingCharacters(in: .whitespacesAndNewlines)
        // Drop parenthetical qualifiers — Summer League split squads
        // arrive as "Golden State Warriors (Blue)".
        if let paren = trimmed.firstIndex(of: "(") {
            trimmed = String(trimmed[..<paren]).trimmingCharacters(in: .whitespaces)
        }
        if trimmed.isEmpty { return nil }
        let lower = trimmed.lowercased()
        if let direct = table[lower] { return direct }
        // If the input is already a 2–4 char abbreviation, try it as-is.
        if lower.count <= 4, lower.allSatisfy({ $0.isLetter }) {
            // Ensure it matches a value in the table — only return known ones.
            if table.values.contains(lower) { return lower }
        }
        // Split on whitespace; try last token (e.g. "Brooklyn Nets" → "nets")
        let last = lower.split(separator: " ").last.map(String.init) ?? lower
        if let hit = table[last] { return hit }
        // Try first token (e.g. "Detroit Tigers" → "detroit")
        let first = lower.split(separator: " ").first.map(String.init) ?? lower
        if let hit = table[first] { return hit }
        // Progressively drop trailing tokens so suffixed names still hit
        // ("golden state warriors gold" → "golden state warriors").
        var tokens = lower.split(separator: " ").map(String.init)
        while tokens.count > 2 {
            tokens.removeLast()
            if let hit = table[tokens.joined(separator: " ")] { return hit }
        }
        return nil
    }

    // MARK: - Soccer (URL by team-name → ESPN team ID)

    private static func soccerLogoURL(team: String) -> URL? {
        let key = team.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let id: String
        switch true {
        case key.contains("arsenal"):                 id = "359"
        case key.contains("aston villa"):             id = "362"
        case key.contains("bournemouth"):             id = "349"
        case key.contains("brentford"):               id = "337"
        case key.contains("brighton"):                id = "331"
        case key.contains("burnley"):                 id = "379"
        case key.contains("chelsea"):                 id = "363"
        case key.contains("crystal palace"):          id = "384"
        case key.contains("everton"):                 id = "368"
        case key.contains("fulham"):                  id = "370"
        case key.contains("ipswich"):                 id = "373"
        case key.contains("leicester"):               id = "375"
        case key.contains("liverpool"):               id = "364"
        case key.contains("manchester city"),
             key.contains("man city"):                id = "382"
        case key.contains("manchester united"),
             key.contains("man united"),
             key.contains("man utd"):                 id = "360"
        case key.contains("newcastle"):               id = "361"
        case key.contains("nottingham forest"),
             key.contains("forest"):                  id = "393"
        case key.contains("southampton"):             id = "376"
        case key.contains("tottenham"),
             key.contains("spurs"):                   id = "367"
        case key.contains("west ham"):                id = "371"
        case key.contains("wolves"),
             key.contains("wolverhampton"):           id = "380"
        default:
            return nil
        }
        return URL(string: "https://a.espncdn.com/i/teamlogos/soccer/500/\(id).png")
    }

    // MARK: - Cricket (IPL — name → ESPN team ID)

    /// IPL franchise IDs verified against ESPN's cricket CDN
    /// (a.espncdn.com/i/teamlogos/cricket/500/{id}.png). Mined from
    /// ESPN's search API and confirmed each one returns 200.
    private static func cricketLogoURL(team: String) -> URL? {
        let key = team.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let id: String
        switch true {
        case key.contains("mumbai"):                            id = "335978"
        case key.contains("chennai"),
             key.contains("super kings"),
             key == "csk":                                       id = "335974"
        case key.contains("royal challengers"),
             key.contains("bangalore"),
             key.contains("bengaluru"),
             key == "rcb":                                       id = "335970"
        case key.contains("kolkata"),
             key.contains("knight riders"),
             key == "kkr":                                       id = "335971"
        case key.contains("delhi"),
             key.contains("capitals"),
             key == "dc":                                        id = "335975"
        case key.contains("punjab"),
             key.contains("kings xi"),
             key == "pbks":                                      id = "335973"
        case key.contains("rajasthan"),
             key.contains("royals"),
             key == "rr":                                        id = "335977"
        case key.contains("sunrisers"),
             key.contains("hyderabad"),
             key == "srh":                                       id = "628333"
        case key.contains("gujarat"),
             key.contains("titans"),
             key == "gt":                                        id = "1298769"
        case key.contains("lucknow"),
             key.contains("super giants"),
             key == "lsg":                                       id = "1298768"
        default:
            return nil
        }
        return URL(string: "https://a.espncdn.com/i/teamlogos/cricket/500/\(id).png")
    }
}

// ════════════════════════════════════════════════════════════════
// MARK: - Per-league abbreviation tables
// ════════════════════════════════════════════════════════════════

/// WNBA — full 15-team 2026 league including the Valkyries, Portland
/// Fire, and Toronto Tempo expansion sides. Every abbreviation was
/// curl-probed against a.espncdn.com/i/teamlogos/wnba/500/{ab}.png
/// (all HTTP 200).
private let wnbaAbbrevs: [String: String] = [
    "atlanta dream": "atl",          "dream": "atl",
    "chicago sky": "chi",            "sky": "chi",
    "connecticut sun": "conn",       "sun": "conn",
    "dallas wings": "dal",           "wings": "dal",
    "golden state valkyries": "gs",  "valkyries": "gs",
    "indiana fever": "ind",          "fever": "ind",
    "las vegas aces": "lv",          "aces": "lv",
    "los angeles sparks": "la",      "sparks": "la",
    "minnesota lynx": "min",         "lynx": "min",
    "new york liberty": "ny",        "liberty": "ny",
    "phoenix mercury": "phx",        "mercury": "phx",
    "portland fire": "por",          "fire": "por",
    "seattle storm": "sea",          "storm": "sea",
    "toronto tempo": "tor",          "tempo": "tor",
    "washington mystics": "wsh",     "mystics": "wsh",
]

/// Leagues with no ESPN CDN path — badges hosted by TheSportsDB
/// (free hotlink, same approach as the dynamic resolver but pinned so
/// these teams NEVER fall back to a colored shield). Keyed by
/// `TeamLogoStore.normKey` (lowercased, punctuation stripped) so
/// "KIA Tigers"/"Kia Tigers" and "Nippon-Ham"/"Nippon Ham" all hit.
/// Every URL curl-verified HTTP 200.
private let directLogoURLs: [String: String] = [
    // ── KBO ──
    "doosan bears":   "https://r2.thesportsdb.com/images/media/team/badge/2qo9zp1740573854.png",
    "hanwha eagles":  "https://r2.thesportsdb.com/images/media/team/badge/7aztmc1740573842.png",
    "kia tigers":     "https://r2.thesportsdb.com/images/media/team/badge/2z389i1648069353.png",
    "kiwoom heroes":  "https://r2.thesportsdb.com/images/media/team/badge/qcj18p1589709259.png",
    "kt wiz":         "https://r2.thesportsdb.com/images/media/team/badge/qk8erg1589709962.png",
    "lg twins":       "https://r2.thesportsdb.com/images/media/team/badge/ajpsiq1648069368.png",
    "lotte giants":   "https://r2.thesportsdb.com/images/media/team/badge/p7q92w1742225576.png",
    "nc dinos":       "https://r2.thesportsdb.com/images/media/team/badge/6gwcg81589708218.png",
    "samsung lions":  "https://r2.thesportsdb.com/images/media/team/badge/5u6k511589709673.png",
    "ssg landers":    "https://r2.thesportsdb.com/images/media/team/badge/kii9pd1742225451.png",
    // ── NPB (incl. the short-name variants the pipeline emits) ──
    "chiba lotte marines":     "https://r2.thesportsdb.com/images/media/team/badge/na10tn1576008207.png",
    "chunichi dragons":        "https://r2.thesportsdb.com/images/media/team/badge/jli5jv1576009060.png",
    "fukuoka softbank hawks":  "https://r2.thesportsdb.com/images/media/team/badge/ampozy1576009547.png",
    "hanshin tigers":          "https://r2.thesportsdb.com/images/media/team/badge/h2jhos1576009994.png",
    "hokkaido nippon ham fighters": "https://r2.thesportsdb.com/images/media/team/badge/qxgzq01576011016.png",
    "nippon ham fighters":     "https://r2.thesportsdb.com/images/media/team/badge/qxgzq01576011016.png",
    "hiroshima toyo carp":     "https://r2.thesportsdb.com/images/media/team/badge/bv50e51576010505.png",
    "hiroshima carp":          "https://r2.thesportsdb.com/images/media/team/badge/bv50e51576010505.png",
    "orix buffaloes":          "https://r2.thesportsdb.com/images/media/team/badge/53lv6f1576011517.png",
    "saitama seibu lions":     "https://r2.thesportsdb.com/images/media/team/badge/onmvow1576012163.png",
    "seibu lions":             "https://r2.thesportsdb.com/images/media/team/badge/onmvow1576012163.png",
    "tohoku rakuten golden eagles": "https://r2.thesportsdb.com/images/media/team/badge/qx24pm1576012656.png",
    "rakuten golden eagles":   "https://r2.thesportsdb.com/images/media/team/badge/qx24pm1576012656.png",
    "tokyo yakult swallows":   "https://r2.thesportsdb.com/images/media/team/badge/ryyku01576013231.png",
    "yakult swallows":         "https://r2.thesportsdb.com/images/media/team/badge/ryyku01576013231.png",
    "yokohama dena baystars":  "https://r2.thesportsdb.com/images/media/team/badge/fuhqf21576013789.png",
    "yokohama baystars":       "https://r2.thesportsdb.com/images/media/team/badge/fuhqf21576013789.png",
    "yomiuri giants":          "https://r2.thesportsdb.com/images/media/team/badge/0qyqs41576014298.png",
    // ── Major League Cricket (US franchises) ──
    "los angeles knight riders": "https://r2.thesportsdb.com/images/media/team/badge/6q2cnq1689146300.png",
    "mi new york":               "https://r2.thesportsdb.com/images/media/team/badge/i4lxb71689146303.png",
    "san francisco unicorns":    "https://r2.thesportsdb.com/images/media/team/badge/k6pv961689146306.png",
    "seattle orcas":             "https://r2.thesportsdb.com/images/media/team/badge/wg325p1689146309.png",
    "texas super kings":         "https://r2.thesportsdb.com/images/media/team/badge/777fr51689161316.png",
    "washington freedom":        "https://r2.thesportsdb.com/images/media/team/badge/ro0khs1750233280.png",
    // ── International cricket sides with no country flag ──
    "west indies":         "https://r2.thesportsdb.com/images/media/team/badge/1x0a681646775209.png",
    "west indies women":   "https://r2.thesportsdb.com/images/media/team/badge/1x0a681646775209.png",
    // ── UCL qualifier clubs the feeds surface ──
    "kairat almaty":         "https://r2.thesportsdb.com/images/media/team/badge/sz5y1m1579285078.png",
    "sutjeska":              "https://r2.thesportsdb.com/images/media/team/badge/jgxq3z1565903948.png",
    "universitatea craiova": "https://r2.thesportsdb.com/images/media/team/badge/1jdz2y1579793710.png",
    // Not in ESPN or SportsDB — Wikipedia-hosted crest (stable hotlink).
    "ml vitebsk": "https://upload.wikimedia.org/wikipedia/en/c/c3/FC_Vitebsk_Logo.png",
    "vitebsk":    "https://upload.wikimedia.org/wikipedia/en/c/c3/FC_Vitebsk_Logo.png",
]

private let nbaAbbrevs: [String: String] = [
    // Atlantic
    "boston celtics": "bos",     "celtics": "bos",     "bos": "bos",
    "brooklyn nets": "bkn",      "nets": "bkn",         "bkn": "bkn",
    "new york knicks": "ny",     "knicks": "ny",        "ny": "ny",     "nyk": "ny",
    "philadelphia 76ers": "phi", "76ers": "phi",        "sixers": "phi", "phi": "phi",
    "toronto raptors": "tor",    "raptors": "tor",      "tor": "tor",
    // Central
    "chicago bulls": "chi",      "bulls": "chi",        "chi": "chi",
    "cleveland cavaliers": "cle","cavaliers": "cle",    "cavs": "cle",   "cle": "cle",
    "detroit pistons": "det",    "pistons": "det",      "det": "det",
    "indiana pacers": "ind",     "pacers": "ind",       "ind": "ind",
    "milwaukee bucks": "mil",    "bucks": "mil",        "mil": "mil",
    // Southeast
    "atlanta hawks": "atl",      "hawks": "atl",        "atl": "atl",
    "charlotte hornets": "cha",  "hornets": "cha",      "cha": "cha",
    "miami heat": "mia",         "heat": "mia",         "mia": "mia",
    "orlando magic": "orl",      "magic": "orl",        "orl": "orl",
    "washington wizards": "wsh", "wizards": "wsh",      "wsh": "wsh",   "was": "wsh",
    // Northwest
    "denver nuggets": "den",     "nuggets": "den",      "den": "den",
    "minnesota timberwolves": "min", "timberwolves": "min", "wolves": "min", "min": "min",
    "oklahoma city thunder": "okc", "thunder": "okc",   "okc": "okc",
    "portland trail blazers": "por", "blazers": "por",  "trail blazers": "por", "por": "por",
    "utah jazz": "utah",         "jazz": "utah",        "utah": "utah", "uta": "utah",
    // Pacific
    "golden state warriors": "gs", "warriors": "gs",    "gs": "gs",     "gsw": "gs",
    "los angeles clippers": "lac", "clippers": "lac",   "lac": "lac",
    "los angeles lakers": "lal", "lakers": "lal",       "lal": "lal",   "la lakers": "lal",
    "phoenix suns": "phx",       "suns": "phx",         "phx": "phx",
    "sacramento kings": "sac",   "kings": "sac",        "sac": "sac",
    // Southwest
    "dallas mavericks": "dal",   "mavericks": "dal",    "mavs": "dal",  "dal": "dal",
    "houston rockets": "hou",    "rockets": "hou",      "hou": "hou",
    "memphis grizzlies": "mem",  "grizzlies": "mem",    "mem": "mem",
    "new orleans pelicans": "no","pelicans": "no",      "no": "no",     "nop": "no",
    "san antonio spurs": "sa",   "spurs": "sa",         "sa": "sa",     "sas": "sa",
]

private let nflAbbrevs: [String: String] = [
    // AFC East
    "buffalo bills": "buf",      "bills": "buf",        "buf": "buf",
    "miami dolphins": "mia",     "dolphins": "mia",     "mia": "mia",
    "new england patriots": "ne","patriots": "ne",      "ne": "ne",
    "new york jets": "nyj",      "jets": "nyj",         "nyj": "nyj",
    // AFC North
    "baltimore ravens": "bal",   "ravens": "bal",       "bal": "bal",
    "cincinnati bengals": "cin", "bengals": "cin",      "cin": "cin",
    "cleveland browns": "cle",   "browns": "cle",       "cle": "cle",
    "pittsburgh steelers": "pit","steelers": "pit",     "pit": "pit",
    // AFC South
    "houston texans": "hou",     "texans": "hou",       "hou": "hou",
    "indianapolis colts": "ind", "colts": "ind",        "ind": "ind",
    "jacksonville jaguars": "jax", "jaguars": "jax",    "jags": "jax",  "jax": "jax",
    "tennessee titans": "ten",   "titans": "ten",       "ten": "ten",
    // AFC West
    "denver broncos": "den",     "broncos": "den",      "den": "den",
    "kansas city chiefs": "kc",  "chiefs": "kc",        "kc": "kc",
    "las vegas raiders": "lv",   "raiders": "lv",       "lv": "lv",
    "los angeles chargers": "lac","chargers": "lac",    "lac": "lac",
    // NFC East
    "dallas cowboys": "dal",     "cowboys": "dal",      "dal": "dal",
    "new york giants": "nyg",    "giants": "nyg",       "nyg": "nyg",
    "philadelphia eagles": "phi","eagles": "phi",       "phi": "phi",
    "washington commanders": "wsh","commanders": "wsh", "wsh": "wsh",
    // NFC North
    "chicago bears": "chi",      "bears": "chi",        "chi": "chi",
    "detroit lions": "det",      "lions": "det",        "det": "det",
    "green bay packers": "gb",   "packers": "gb",       "gb": "gb",
    "minnesota vikings": "min",  "vikings": "min",      "min": "min",
    // NFC South
    "atlanta falcons": "atl",    "falcons": "atl",      "atl": "atl",
    "carolina panthers": "car",  "panthers": "car",     "car": "car",
    "new orleans saints": "no",  "saints": "no",        "no": "no",
    "tampa bay buccaneers": "tb","buccaneers": "tb",    "bucs": "tb",   "tb": "tb",
    // NFC West
    "arizona cardinals": "ari",  "cardinals": "ari",    "ari": "ari",
    "los angeles rams": "lar",   "rams": "lar",         "lar": "lar",
    "san francisco 49ers": "sf", "49ers": "sf",         "niners": "sf", "sf": "sf",
    "seattle seahawks": "sea",   "seahawks": "sea",     "sea": "sea",
]

private let mlbAbbrevs: [String: String] = [
    // AL East
    "baltimore orioles": "bal",  "orioles": "bal",      "bal": "bal",
    "boston red sox": "bos",     "red sox": "bos",      "bos": "bos",
    "new york yankees": "nyy",   "yankees": "nyy",      "nyy": "nyy",
    "tampa bay rays": "tb",      "rays": "tb",          "tb": "tb",
    "toronto blue jays": "tor",  "blue jays": "tor",    "jays": "tor",  "tor": "tor",
    // AL Central
    "chicago white sox": "chw",  "white sox": "chw",    "chw": "chw",
    "cleveland guardians": "cle","guardians": "cle",    "cle": "cle",
    "detroit tigers": "det",     "tigers": "det",       "det": "det",
    "kansas city royals": "kc",  "royals": "kc",        "kc": "kc",
    "minnesota twins": "min",    "twins": "min",        "min": "min",
    // AL West
    "houston astros": "hou",     "astros": "hou",       "hou": "hou",
    "los angeles angels": "laa", "angels": "laa",       "laa": "laa",
    "oakland athletics": "ath",  "athletics": "ath",    "as": "ath",    "ath": "ath", "oak": "ath",
    "seattle mariners": "sea",   "mariners": "sea",     "sea": "sea",
    "texas rangers": "tex",      "rangers": "tex",      "tex": "tex",
    // NL East
    "atlanta braves": "atl",     "braves": "atl",       "atl": "atl",
    "miami marlins": "mia",      "marlins": "mia",      "mia": "mia",
    "new york mets": "nym",      "mets": "nym",         "nym": "nym",
    "philadelphia phillies": "phi","phillies": "phi",   "phi": "phi",
    "washington nationals": "wsh","nationals": "wsh",   "nats": "wsh", "wsh": "wsh",
    // NL Central
    "chicago cubs": "chc",       "cubs": "chc",         "chc": "chc",
    "cincinnati reds": "cin",    "reds": "cin",         "cin": "cin",
    "milwaukee brewers": "mil",  "brewers": "mil",      "mil": "mil",
    "pittsburgh pirates": "pit", "pirates": "pit",      "pit": "pit",
    "st. louis cardinals": "stl","cardinals": "stl",    "stl": "stl",
    // NL West
    "arizona diamondbacks": "ari","diamondbacks": "ari","dbacks": "ari","ari": "ari",
    "colorado rockies": "col",   "rockies": "col",      "col": "col",
    "los angeles dodgers": "lad","dodgers": "lad",      "lad": "lad",
    "san diego padres": "sd",    "padres": "sd",        "sd": "sd",
    "san francisco giants": "sf","sf": "sf",
]

private let nhlAbbrevs: [String: String] = [
    // Atlantic
    "boston bruins": "bos",      "bruins": "bos",       "bos": "bos",
    "buffalo sabres": "buf",     "sabres": "buf",       "buf": "buf",
    "detroit red wings": "det",  "red wings": "det",    "det": "det",
    "florida panthers": "fla",   "panthers": "fla",     "fla": "fla",
    "montreal canadiens": "mtl", "canadiens": "mtl",    "habs": "mtl",  "mtl": "mtl", "mon": "mtl",
    "ottawa senators": "ott",    "senators": "ott",     "ott": "ott",
    "tampa bay lightning": "tb", "lightning": "tb",     "tb": "tb",
    "toronto maple leafs": "tor","maple leafs": "tor",  "leafs": "tor", "tor": "tor",
    // Metropolitan
    "carolina hurricanes": "car","hurricanes": "car",   "canes": "car", "car": "car",
    "columbus blue jackets": "cbj","blue jackets": "cbj","cbj": "cbj",
    "new jersey devils": "nj",   "devils": "nj",        "nj": "nj",     "njd": "nj",
    "new york islanders": "nyi", "islanders": "nyi",    "nyi": "nyi",
    "new york rangers": "nyr",   "rangers": "nyr",      "nyr": "nyr",
    "philadelphia flyers": "phi","flyers": "phi",       "phi": "phi",
    "pittsburgh penguins": "pit","penguins": "pit",     "pens": "pit",  "pit": "pit",
    "washington capitals": "wsh","capitals": "wsh",     "caps": "wsh",  "wsh": "wsh",
    // Central
    "chicago blackhawks": "chi", "blackhawks": "chi",   "chi": "chi",
    "colorado avalanche": "col", "avalanche": "col",    "avs": "col",   "col": "col",
    "dallas stars": "dal",       "stars": "dal",        "dal": "dal",
    "minnesota wild": "min",     "wild": "min",         "min": "min",
    "nashville predators": "nsh","predators": "nsh",    "preds": "nsh", "nsh": "nsh",
    "st. louis blues": "stl",    "blues": "stl",        "stl": "stl",
    "utah hockey club": "uta",   "utah": "uta",         "uta": "uta",   "ut": "uta",
    "winnipeg jets": "wpg",      "jets": "wpg",         "wpg": "wpg",
    // Pacific
    "anaheim ducks": "ana",      "ducks": "ana",        "ana": "ana",
    "calgary flames": "cgy",     "flames": "cgy",       "cgy": "cgy",
    "edmonton oilers": "edm",    "oilers": "edm",       "edm": "edm",
    "los angeles kings": "la",   "kings": "la",         "la": "la",     "lak": "la",
    "san jose sharks": "sj",     "sharks": "sj",        "sj": "sj",     "sjs": "sj",
    "seattle kraken": "sea",     "kraken": "sea",       "sea": "sea",
    "vancouver canucks": "van",  "canucks": "van",      "van": "van",
    "vegas golden knights": "vgk","golden knights": "vgk","vgk": "vgk", "veg": "vgk",
]

// ════════════════════════════════════════════════════════════════
// MARK: - LogoPrefetch — warm the cache so crests/headshots/league
//        logos render instantly instead of flashing the placeholder
// ════════════════════════════════════════════════════════════════

/// `TeamLogo`/`AthleteHeadshot`/`LeagueLogo` use `AsyncImage`, which
/// shows a placeholder (colored crest / profile circle / fallback tile)
/// while the network image loads — that's the "placeholder badge" flash
/// the user sees. Prefetching the URLs into `URLCache.shared` before the
/// cards appear means AsyncImage finds them already cached and paints
/// the real logo on first render.
///
/// Call `LogoPrefetch.warm(picks:scores:)` after a slate loads, and
/// `LogoPrefetch.bootCache()` once at app launch to give the cache
/// enough room.
enum LogoPrefetch {

    /// Bump the shared URL cache so dozens of small logo PNGs persist
    /// across launches (ESPN logos are tiny — a few KB each).
    static func bootCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,   // 32 MB RAM
            diskCapacity: 128 * 1024 * 1024     // 128 MB disk
        )
    }

    /// Fire-and-forget GETs for every logo URL referenced by the given
    /// picks (team crests or athlete headshots) and their leagues, so
    /// they land in URLCache.shared before the views ask for them.
    static func warm(picks: [Pick]) {
        var urls = Set<URL>()
        for p in picks {
            if AthleteHeadshot.isIndividual(sport: p.sport) {
                if let u = AthleteHeadshotLookup.url(sport: p.sport, name: p.homeTeam) { urls.insert(u) }
                if let u = AthleteHeadshotLookup.url(sport: p.sport, name: p.awayTeam) { urls.insert(u) }
            } else {
                if let u = TeamLogoLookup.url(sport: p.sport, team: p.homeTeam) { urls.insert(u) }
                if let u = TeamLogoLookup.url(sport: p.sport, team: p.awayTeam) { urls.insert(u) }
                // National-team flag images (soccer / cricket) — warm
                // them with everything else so flags never pop in.
                if p.sport == "soccer" || p.sport == "cricket" {
                    for team in [p.homeTeam, p.awayTeam] {
                        if let code = wcFlagCode(for: nationalTeamBase(team)),
                           let u = flagImageURL(for: code) { urls.insert(u) }
                    }
                }
            }
        }
        warm(urls: urls)
    }

    /// Prefetch a set of arbitrary logo URLs (used by the Summer Football hub
    /// for any async crests, and internally by `warm(picks:)`).
    static func warm(urls: Set<URL>) {
        guard !urls.isEmpty else { return }
        for url in urls {
            // URLSession.shared shares URLCache.shared with AsyncImage,
            // so this populates the exact cache AsyncImage reads from.
            var req = URLRequest(url: url)
            req.cachePolicy = .returnCacheDataElseLoad
            URLSession.shared.dataTask(with: req).resume()
        }
    }
}
