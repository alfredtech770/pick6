//  Pick1Symbols.swift
//  The app's icon vocabulary.
//
//  WHY THIS EXISTS.
//
//  Pick1 was drawing its icons with emoji. Two problems with that, one
//  cosmetic and one substantive.
//
//  Cosmetic: emoji are full-colour artwork from a font Apple controls. They
//  ignore the app's palette entirely, so a strict lime-on-ink product had
//  eleven arbitrary colour schemes scattered through it, and they redraw
//  between iOS versions.
//
//  Substantive: the factor rows on the home hero picked their emoji BY INDEX
//  — `["🔥", "🧠", "💧"][i % 3]` — so the brain sat next to "Returning
//  starters" for no reason at all. An icon that does not track its content is
//  worse than no icon, because it invites the reader to find a meaning that
//  is not there. `factor(_:)` below reads the label and picks accordingly.
//
//  Everything resolves to an SF Symbol, tinted by the caller. That gives one
//  stroke weight, one optical size, correct scaling with Dynamic Type, and
//  colours drawn from V4 rather than from Apple's artwork.

import SwiftUI
import UIKit

enum P1Symbol {

    // MARK: - Existence check
    //
    // `Image(systemName:)` renders NOTHING for a name the running OS does not
    // know, silently. Some of the sport glyphs below are recent additions, so
    // every name is checked once and falls back rather than leaving a hole in
    // the layout.
    private static var known: [String: Bool] = [:]
    private static let lock = NSLock()

    static func resolve(_ name: String, fallback: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if let ok = known[name] { return ok ? name : fallback }
        let ok = UIImage(systemName: name) != nil
        known[name] = ok
        return ok ? name : fallback
    }

    // MARK: - Sports

    /// One glyph per sport Pick1 covers. Tint with `V4.glow(sport)` so the
    /// sport still reads as itself without importing a second colour system.
    static func sport(_ sport: String) -> String {
        let name: String
        switch sport {
        case "basketball": name = "basketball.fill"
        case "football":   name = "football.fill"
        case "soccer":     name = "soccerball"
        case "hockey":     name = "hockey.puck.fill"
        case "baseball":   name = "baseball.fill"
        case "combat":     name = "figure.boxing"
        case "f1":         name = "flag.pattern.checkered"
        case "tennis":     name = "tennis.racket"
        case "cricket":    name = "cricket.ball.fill"
        case "golf":       name = "figure.golf"
        case "rugby":      name = "figure.rugby"
        case "afl":        name = "figure.australian.football"
        default:           name = "sportscourt.fill"
        }
        return resolve(name, fallback: "sportscourt.fill")
    }

    // MARK: - Factors

    /// The icon for one "why the AI likes it" row, chosen from what the row
    /// actually says. Matching is on the label because that is the part the
    /// pipeline writes as a short, stable phrase ("Recent form", "Key
    /// injury", "Market prior"); the value beside it is free text.
    ///
    /// Ordering matters: injury before form, because "form" appears inside
    /// phrases like "form since the injury".
    static func factor(_ label: String) -> String {
        let l = label.lowercased()
        let name: String

        if l.contains("injur") || l.contains("absent") || l.contains("suspend")
            || l.hasSuffix(" out") || l.contains("availab") || l.contains("squad") {
            name = "cross.case.fill"
        } else if l.contains("starter") || l.contains("lineup") || l.contains("line-up")
            || l.contains("returning") || l.contains("roster") || l.contains("personnel")
            || l.contains("pitcher") || l.contains("goalie") {
            name = "person.2.fill"
        } else if l.contains("market") || l.contains("odds") || l.contains("price")
            || l.contains("line") || l.contains("implied") || l.contains("vig") {
            name = "chart.line.uptrend.xyaxis"
        } else if l.contains("h2h") || l.contains("head-to-head") || l.contains("head to head")
            || l.contains("meeting") || l.contains("record vs") {
            name = "arrow.left.arrow.right"
        } else if l.contains("home") || l.contains("away") || l.contains("venue")
            || l.contains("ground") || l.contains("stadium") || l.contains("crowd") {
            name = "house.fill"
        } else if l.contains("rest") || l.contains("fatigue") || l.contains("back-to-back")
            || l.contains("travel") || l.contains("layoff") || l.contains("schedule") {
            name = "bed.double.fill"
        } else if l.contains("weather") || l.contains("wind") || l.contains("rain")
            || l.contains("temp") || l.contains("pitch condition") {
            name = "cloud.rain.fill"
        } else if l.contains("rank") || l.contains("seed") || l.contains("table")
            || l.contains("standing") || l.contains("position") {
            name = "list.number"
        } else if l.contains("defen") || l.contains("clean sheet") || l.contains("concede")
            || l.contains("keeper") {
            name = "shield.lefthalf.filled"
        } else if l.contains("attack") || l.contains("offens") || l.contains("scoring")
            || l.contains("goals") || l.contains("points") {
            name = "target"
        } else if l.contains("reach") || l.contains("height") || l.contains("weight")
            || l.contains("physical") {
            name = "ruler.fill"
        } else if l.contains("finish") || l.contains("knockdown") || l.contains("ko")
            || l.contains("submission") || l.contains("grappl") || l.contains("strik") {
            name = "bolt.fill"
        } else if l.contains("form") || l.contains("streak") || l.contains("momentum")
            || l.contains("run") || l.contains("recent") {
            name = "flame.fill"
        } else if l.contains("qualif") || l.contains("grid") || l.contains("pace")
            || l.contains("lap") || l.contains("track") {
            name = "stopwatch.fill"
        } else {
            name = "chart.bar.fill"
        }
        return resolve(name, fallback: "chart.bar.fill")
    }
}

// MARK: - Sport glyph

/// A sport's mark, sized and tinted consistently wherever it appears.
///
/// Replaces the `v4Emoji(_:)` string that every pick surface used to render.
/// `glow` carries the sport identity, which is the same rule the rest of v4
/// follows: colour signals the sport, never the layout.
struct P1SportMark: View {
    let sport: String
    var size: CGFloat = 19
    var glowing: Bool = true
    /// Off-state orbs desaturate rather than dim, so the selected sport is the
    /// only colour in the row.
    var active: Bool = true

    private var tint: Color { V4.glow(sport) }

    var body: some View {
        Image(systemName: P1Symbol.sport(sport))
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(active ? tint : tint.opacity(0.55))
            .saturation(active ? 1 : 0.35)
            .shadow(color: glowing && active ? tint.opacity(0.55) : .clear,
                    radius: size * 0.32)
            .accessibilityHidden(true)
    }
}
