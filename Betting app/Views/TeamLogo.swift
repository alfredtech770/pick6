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

struct TeamLogo: View {
    let sport: String
    let team: String
    let size: Crest.Size

    var body: some View {
        // Individual-athlete sports (UFC / F1 / Tennis) — render the
        // athlete's headshot in a circle instead of a team crest.
        if AthleteHeadshot.isIndividual(sport: sport) {
            AthleteHeadshot(sport: sport, name: team, size: size)
        } else if let url = TeamLogoLookup.url(sport: sport, team: team) {
            AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(size == .big ? 4 : 2)
                        .frame(width: size.w, height: size.h)
                case .empty:
                    // While loading, show the colored crest so we don't pop
                    Crest(team: team, size: size)
                case .failure:
                    Crest(team: team, size: size)
                @unknown default:
                    Crest(team: team, size: size)
                }
            }
        } else {
            // Team sport with no logo mapping — keep colored shield.
            Crest(team: team, size: size)
        }
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
        case "combat", "f1", "tennis": return true
        default: return false
        }
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

            if let url = AthleteHeadshotLookup.url(sport: sport, name: name) {
                AsyncImage(url: url,
                           transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
                .clipShape(Circle())
            } else {
                placeholder
            }
        }
        .frame(width: dimension, height: dimension)
        .clipShape(Circle())
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
            guard let id = lookup(in: f1Ids, name: name) else { return nil }
            return URL(string: "https://a.espncdn.com/i/headshots/rpm/players/full/\(id).png")
        case "tennis":
            guard let id = lookup(in: tennisIds, name: name) else { return nil }
            return URL(string: "https://a.espncdn.com/i/headshots/tennis/players/full/\(id).png")
        default:
            return nil
        }
    }

    /// Try direct + last-token + first-token matches against the table.
    private static func lookup(in table: [String: String], name: String) -> String? {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.isEmpty { return nil }
        if let hit = table[lower] { return hit }
        let last  = lower.split(separator: " ").last.map(String.init) ?? lower
        if let hit = table[last] { return hit }
        let first = lower.split(separator: " ").first.map(String.init) ?? lower
        if let hit = table[first] { return hit }
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
    "jones":      "2335639",  "jon jones":             "2335639",
    "adesanya":   "4285679",  "israel adesanya":       "4285679",
    "volkanovski":"3949584",  "alexander volkanovski": "3949584",
    "makhachev":  "3332412",  "islam makhachev":       "3332412",
    "edwards":    "3041602",  "leon edwards":          "3041602",
    "usman":      "3088812",  "kamaru usman":          "3088812",
    "ngannou":    "3933168",  "francis ngannou":       "3933168",
    "poirier":    "2506549",  "dustin poirier":        "2506549",
    "oliveira":   "2504169",  "charles oliveira":      "2504169",
]

private let f1Ids: [String: String] = [
    "hamilton":   "868",   "lewis hamilton":     "868",
    "leclerc":    "5499",  "charles leclerc":    "5499",
    "zhou":       "5588",  "guanyu zhou":        "5588",
]

/// Tennis IDs not yet verified — table left empty; AthleteHeadshot
/// renders the placeholder for tennis picks until we wire a real
/// source. (ESPN's tennis CDN path may differ from /tennis/.)
private let tennisIds: [String: String] = [:]

// ════════════════════════════════════════════════════════════════
// MARK: - Lookup
// ════════════════════════════════════════════════════════════════

enum TeamLogoLookup {
    /// Returns an ESPN CDN URL for the given (sport, team), or nil if
    /// we can't map it. Nil falls back to the colored crest.
    static func url(sport: String, team: String) -> URL? {
        let leagueSlug: String
        let table: [String: String]
        switch sport {
        case "basketball":
            leagueSlug = "nba"
            table = nbaAbbrevs
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
        let trimmed = team.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

// ════════════════════════════════════════════════════════════════
// MARK: - Per-league abbreviation tables
// ════════════════════════════════════════════════════════════════

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
