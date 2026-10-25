// Pick1GameLiveActivity.swift
// The Live Activity UI — Lock Screen / banner + Dynamic Island, Apple
// Sports style, in Pick1's dark + acid-green look.

import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

private let lime = Color(red: 0.776, green: 1.0, blue: 0.204)   // #C6FF34
private let ink  = Color(red: 0.027, green: 0.031, blue: 0.039) // #07080A

/// The team mark for the Live Activity: real crest if we shipped one,
/// else a country flag emoji, else a sport SF Symbol. Never empty.
@ViewBuilder
private func liveTeamMark(logoPNG: Data?, flag: String?, sport: String, size: CGFloat) -> some View {
    if let d = logoPNG, let ui = UIImage(data: d) {
        Image(uiImage: ui).resizable().scaledToFit().frame(width: size, height: size)
    } else if let flag, !flag.isEmpty {
        Text(flag).font(.system(size: size * 0.92))
    } else {
        Image(systemName: liveSportSymbol(sport))
            .font(.system(size: size * 0.66, weight: .semibold))
            .foregroundColor(.white.opacity(0.85))
            .frame(width: size, height: size)
    }
}

private func liveSportSymbol(_ sport: String) -> String {
    switch sport {
    case "basketball": return "basketball.fill"
    case "baseball":   return "baseball.fill"
    case "hockey":     return "hockey.puck.fill"
    case "football":   return "football.fill"
    case "soccer":     return "soccerball"
    case "combat":     return "figure.boxing"
    case "f1":         return "car.fill"
    case "golf":       return "figure.golf"
    case "cricket":    return "figure.cricket"
    default:           return "sportscourt.fill"
    }
}

/// Team colour from hex, or a neutral when the activity predates colours.
private func liveTint(_ hex: String?, _ fallback: Color) -> Color {
    guard let hex, hex.count == 6, let v = UInt64(hex, radix: 16) else { return fallback }
    return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

/// "LIVE · Q3 5:12" splits into the pulse word and the clock.
private struct LiveStatus {
    let live: Bool
    let final: Bool
    let main: String
    let sub: String
    init(_ context: ActivityViewContext<Pick1GameAttributes>) {
        let line = context.state.statusLine
        final = context.state.isFinal
        live = !final && line.uppercased().hasPrefix("LIVE")
        if final {
            main = "Final"; sub = ""
        } else if live {
            main = "Live"
            sub = line.components(separatedBy: "·").dropFirst().joined(separator: "·").trimmingCharacters(in: .whitespaces)
        } else if let d = context.attributes.startDate {
            main = d.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            sub = d.formatted(date: .omitted, time: .shortened)
        } else {
            main = line.capitalized; sub = ""
        }
    }
}

struct Pick1GameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Pick1GameAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(xCard)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(gameURL(context))
        } dynamicIsland: { context in
            let status = LiveStatus(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandTeam(logo: context.attributes.awayLogoPNG, flag: context.attributes.awayFlag,
                               sport: context.attributes.sport, code: context.attributes.awayAbbr,
                               score: context.state.awayScore, other: context.state.homeScore, context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandTeam(logo: context.attributes.homeLogoPNG, flag: context.attributes.homeFlag,
                               sport: context.attributes.sport, code: context.attributes.homeAbbr,
                               score: context.state.homeScore, other: context.state.awayScore, context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(status.main).font(.system(size: 13, weight: .bold))
                            .foregroundColor(status.live ? .red : .white)
                        if !status.sub.isEmpty {
                            Text(status.sub).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.75))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    PickStrip(context: context, compact: true)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    liveTeamMark(logoPNG: context.attributes.awayLogoPNG, flag: context.attributes.awayFlag,
                                 sport: context.attributes.sport, size: 16)
                    Text("\(context.state.awayScore)").font(.system(size: 13, weight: .bold)).monospacedDigit()
                }
            } compactTrailing: {
                HStack(spacing: 4) {
                    Text("\(context.state.homeScore)").font(.system(size: 13, weight: .bold)).monospacedDigit()
                    liveTeamMark(logoPNG: context.attributes.homeLogoPNG, flag: context.attributes.homeFlag,
                                 sport: context.attributes.sport, size: 16)
                }
            } minimal: {
                Text("\(context.state.awayScore)-\(context.state.homeScore)")
                    .font(.system(size: 11, weight: .bold)).monospacedDigit()
                    .foregroundColor(context.state.pickHitting ? lime : .white)
            }
            .keylineTint(liveTint(context.attributes.homeColor, lime))
            .widgetURL(gameURL(context))
        }
    }

    private func gameURL(_ context: ActivityViewContext<Pick1GameAttributes>) -> URL? {
        let key = context.attributes.gameId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: "pick1://game?key=\(key)")
    }

    @ViewBuilder
    private func islandTeam(logo: Data?, flag: String?, sport: String, code: String, score: Int, other: Int,
                            context: ActivityViewContext<Pick1GameAttributes>) -> some View {
        let started = context.state.isFinal || LiveStatus(context).live
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                liveTeamMark(logoPNG: logo, flag: flag, sport: sport, size: 26)
                Text(code).font(.system(size: 11, weight: .bold)).foregroundColor(.white).lineLimit(1)
            }
            if started {
                Text("\(score)").font(.system(size: 24, weight: .bold)).monospacedDigit()
                    .foregroundColor(context.state.isFinal && score < other ? .white.opacity(0.5) : .white)
            }
        }
    }
}

/// The real PICK1 wordmark: "PICK" in Anton next to the lime "1" tile.
private struct LiveWordmark: View {
    var size: CGFloat = 15
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
            Text("PICK").font(.custom("Anton-Regular", size: size)).foregroundColor(.white)
            Text("1").font(.custom("Anton-Regular", size: size * 0.62)).foregroundColor(ink)
                .frame(width: size * 1.05, height: size * 1.05)
                .background(RoundedRectangle(cornerRadius: size * 0.235, style: .continuous).fill(lime))
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] + size * 0.3 }
        }
        .accessibilityLabel("PICK1")
    }
}

/// Where PICK1's call stands, in one plain sentence.
private enum LiveSentence {
    enum Mood { case good, bad, neutral }

    static func make(_ context: ActivityViewContext<Pick1GameAttributes>) -> (String, Mood) {
        let a = context.attributes, s = context.state
        let status = LiveStatus(context)
        let solo = ["tennis", "combat", "golf", "f1"].contains(a.sport)
        func verb(_ team: String, _ plural: String, _ single: String) -> String { "\(team) \(solo ? single : plural)" }
        var side = a.pickSide
        if side == nil, !a.pickText.isEmpty {
            let p = a.pickText.lowercased()
            if p.contains(a.homeTeam.lowercased()) || p.contains(a.homeAbbr.lowercased()) { side = "home" }
            else if p.contains(a.awayTeam.lowercased()) || p.contains(a.awayAbbr.lowercased()) { side = "away" }
        }
        let team = side == "home" ? a.homeTeam : side == "away" ? a.awayTeam : nil
        let mine = side == "home" ? s.homeScore : s.awayScore
        let theirs = side == "home" ? s.awayScore : s.homeScore
        let hs = s.homeScore, aws = s.awayScore
        // Tennis scores count sets: "2 sets to 0" reads better than "2-0".
        func sc(_ x: Int, _ y: Int) -> String {
            a.sport == "tennis" ? "\(x) \(x == 1 ? "set" : "sets") to \(y)" : "\(x)-\(y)"
        }

        if status.final {
            if let team {
                if mine > theirs { return ("PICK1 called it. \(verb(team, "win", "wins")) \(sc(mine, theirs)).", .good) }
                if mine < theirs { return ("\(verb(team, "lose", "loses")) \(sc(mine, theirs)). PICK1 missed this one.", .bad) }
                return ("It ends level at \(sc(mine, theirs)).", .neutral)
            }
            if hs == aws { return ("It ends level at \(sc(hs, aws)).", .neutral) }
            let winner = hs > aws ? a.homeTeam : a.awayTeam
            return ("\(verb(winner, "win", "wins")) \(sc(max(hs, aws), min(hs, aws))).", .neutral)
        }
        if status.live {
            if let team {
                if mine > theirs { return ("\(verb(team, "lead", "leads")) \(sc(mine, theirs)). PICK1's pick is ahead.", .good) }
                if mine < theirs { return ("\(verb(team, "trail", "trails")) \(sc(mine, theirs)). Still time to turn it around.", .bad) }
                return ("All square at \(sc(mine, theirs)). PICK1 backs \(team).", .neutral)
            }
            if hs == aws { return ("All square at \(sc(hs, aws)).", .neutral) }
            let leader = hs > aws ? a.homeTeam : a.awayTeam
            return ("\(verb(leader, "lead", "leads")) \(sc(max(hs, aws), min(hs, aws))).", .neutral)
        }
        // The start time is already in the middle of the card.
        if let team {
            if let p = a.pickProbability { return ("PICK1 gives \(team) a \(p)% chance to win.", .neutral) }
            return ("PICK1 backs \(team) to win.", .neutral)
        }
        return ("PICK1 has not called this game.", .neutral)
    }
}

/// The line under the scores.
private struct PickStrip: View {
    let context: ActivityViewContext<Pick1GameAttributes>
    var compact = false
    var body: some View {
        let (text, mood) = LiveSentence.make(context)
        HStack(spacing: 8) {
            Image(systemName: mood == .good ? "checkmark.circle.fill" : mood == .bad ? "arrow.down.circle.fill" : "sparkles")
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundColor(mood == .good ? lime : mood == .bad ? Color(red: 1, green: 0.35, blue: 0.35) : lime)
            Text(text)
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2).minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The X frame palette, same values as the in-app board (P1Board).
private let xCard = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255)   // #141414
private let xPill = Color(red: 0x23 / 255, green: 0x23 / 255, blue: 0x23 / 255)   // #232323
private let xGray = Color(red: 0x8B / 255, green: 0x8B / 255, blue: 0x8B / 255)   // #8B8B8B

/// Lock Screen / banner presentation, laid out like the top of the game
/// page on a symmetric grid: crest columns of equal width on both sides,
/// scores in fixed slots, the status in the exact middle, PICK1's sentence
/// in a pill underneath.
struct LockScreenView: View {
    let context: ActivityViewContext<Pick1GameAttributes>

    private var status: LiveStatus { LiveStatus(context) }
    private var started: Bool { status.live || status.final }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                LiveWordmark(size: 15)
                Spacer()
                Text(context.attributes.league.uppercased())
                    .font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundColor(xGray)
            }
            HStack(spacing: 0) {
                crest(logo: context.attributes.awayLogoPNG, flag: context.attributes.awayFlag, code: context.attributes.awayAbbr)
                    .frame(maxWidth: .infinity)
                number(context.state.awayScore, other: context.state.homeScore, record: context.attributes.awayRecord)
                    .frame(width: 56, alignment: .center)
                center.frame(width: 92)
                number(context.state.homeScore, other: context.state.awayScore, record: context.attributes.homeRecord)
                    .frame(width: 56, alignment: .center)
                crest(logo: context.attributes.homeLogoPNG, flag: context.attributes.homeFlag, code: context.attributes.homeAbbr)
                    .frame(maxWidth: .infinity)
            }
            PickStrip(context: context)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(xPill))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(xCard)
    }

    private var center: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                if status.live { Circle().fill(Color.red).frame(width: 6, height: 6) }
                Text(status.main).font(.system(size: 15, weight: .bold))
                    .foregroundColor(status.live ? .red : .white)
            }
            if !status.sub.isEmpty {
                Text(status.sub).font(.system(size: 12, weight: .medium)).foregroundColor(xGray)
            }
        }
        .lineLimit(1).minimumScaleFactor(0.75)
        .multilineTextAlignment(.center)
    }

    private func crest(logo: Data?, flag: String?, code: String) -> some View {
        VStack(spacing: 5) {
            liveTeamMark(logoPNG: logo, flag: flag, sport: context.attributes.sport, size: 34)
                .frame(width: 36, height: 36)
            Text(code).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func number(_ score: Int, other: Int, record: String?) -> some View {
        Text(started ? "\(score)" : (record ?? ""))
            .font(.system(size: started ? 30 : 15, weight: started ? .bold : .semibold))
            .monospacedDigit()
            .foregroundColor(started ? (status.final && score < other ? xGray : .white) : xGray)
            .lineLimit(1).minimumScaleFactor(0.6)
    }
}
