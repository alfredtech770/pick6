// Pick1GameLiveActivity.swift
// The Live Activity UI — Lock Screen / banner + Dynamic Island, Apple
// Sports style, in Pick1's dark + acid-green look.

import ActivityKit
import WidgetKit
import SwiftUI

private let lime = Color(red: 0.831, green: 1.0, blue: 0.227)   // #D4FF3A
private let ink  = Color(red: 0.027, green: 0.031, blue: 0.039) // #07080A

struct Pick1GameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Pick1GameAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(ink)
                .activitySystemActionForegroundColor(lime)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    teamPill(context.attributes.homeAbbr, score: context.state.homeScore,
                             win: context.state.homeScore > context.state.awayScore)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    teamPill(context.attributes.awayAbbr, score: context.state.awayScore,
                             win: context.state.awayScore > context.state.homeScore)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.statusLine)
                        .font(.caption2).bold()
                        .foregroundColor(context.state.isFinal ? .gray : lime)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 5) {
                        Image(systemName: context.state.pickHitting ? "checkmark.seal.fill" : "target")
                            .font(.caption2)
                            .foregroundColor(context.state.pickHitting ? lime : .gray)
                        Text(context.attributes.pickText)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Text(context.attributes.homeAbbr).font(.caption2).bold()
            } compactTrailing: {
                Text("\(context.state.homeScore)-\(context.state.awayScore)")
                    .font(.caption2).bold()
                    .foregroundColor(context.state.pickHitting ? lime : .white)
            } minimal: {
                Text("\(context.state.homeScore)-\(context.state.awayScore)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(lime)
            }
            .keylineTint(lime)
            .widgetURL(URL(string: "pick1://game/\(context.attributes.gameId)"))
        }
    }

    @ViewBuilder
    private func teamPill(_ abbr: String, score: Int, win: Bool) -> some View {
        VStack(spacing: 2) {
            Text(abbr).font(.caption).bold().foregroundColor(.white)
            Text("\(score)").font(.title3).bold()
                .foregroundColor(win ? lime : .white)
        }
    }
}

/// Lock Screen / banner presentation.
struct LockScreenView: View {
    let context: ActivityViewContext<Pick1GameAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(context.attributes.league.uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(1.4)
                    .foregroundColor(.gray)
                Spacer()
                Text(context.state.statusLine)
                    .font(.system(size: 10, weight: .bold)).tracking(1)
                    .foregroundColor(context.state.isFinal ? .gray : lime)
            }
            HStack(alignment: .center) {
                teamColumn(context.attributes.homeTeam, score: context.state.homeScore,
                           win: context.state.homeScore > context.state.awayScore)
                Text("–").font(.title2).foregroundColor(.gray).padding(.horizontal, 6)
                teamColumn(context.attributes.awayTeam, score: context.state.awayScore,
                           win: context.state.awayScore > context.state.homeScore)
            }
            HStack(spacing: 6) {
                Image(systemName: context.state.pickHitting ? "checkmark.seal.fill" : "target")
                    .font(.caption2)
                    .foregroundColor(context.state.pickHitting ? lime : .gray)
                Text("Your pick: \(context.attributes.pickText)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                if context.state.pickHitting && !context.state.isFinal {
                    Text("HITTING").font(.system(size: 9, weight: .heavy)).tracking(1)
                        .foregroundColor(ink)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(lime))
                }
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func teamColumn(_ name: String, score: Int, win: Bool) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.system(size: 15, weight: .bold))
                .foregroundColor(.white).lineLimit(1)
            Text("\(score)").font(.system(size: 22, weight: .heavy))
                .foregroundColor(win ? lime : .white)
        }
        .frame(maxWidth: .infinity)
    }
}
