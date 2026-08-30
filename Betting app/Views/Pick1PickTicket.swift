//  Pick1PickTicket.swift
//  The pick, as a ticket. Header of the match detail page.
//
//  WHY A TICKET.
//
//  The old header spent a full screen on four facts: two crests, the call,
//  the confidence, and a price. Worse, the largest and most glowing element
//  on the page was "1.82x FAIR ODDS", which is what we print when there is
//  NO market quote — meaning the biggest thing on screen was the confidence
//  figure from two lines above, restated as a price. The percentage appeared
//  three times and the track action twice.
//
//  A ticket fixes the hierarchy by having an obvious subject. It states the
//  call once, the terms once, and stamps its own outcome. Everything that
//  argues FOR the call (factors, market read, form, props) belongs below it,
//  which is why the detail page now reads as ticket first, evidence after.
//
//  ON NOT BEING A SPORTSBOOK. Pick1 does not take bets, and that distinction
//  is load-bearing for the ads. So this is a record of a call, not a wager:
//  the action is TRACK, never "place", the money line is what $100 WOULD
//  return, and no state of this view ever implies a stake was taken.

import SwiftUI

// MARK: - Shape

/// Rounded card with a notch bitten out of each side, at `notchY` from the
/// top. Drawn as one continuous path rather than by subtracting circles, so
/// the stroked outline follows the bite instead of drawing two full circles
/// hanging off the edges.
struct P1TicketShape: Shape {
    var notchY: CGFloat
    var notchR: CGFloat = 9
    var radius: CGFloat = 20

    func path(in r: CGRect) -> Path {
        var p = Path()
        let y = r.minY + notchY

        p.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + radius),
                       control: CGPoint(x: r.maxX, y: r.minY))

        // Right bite. Sweeping anti-clockwise in view space curves the arc
        // back into the card, which is the bite; clockwise would balloon it
        // outwards into a tab.
        p.addLine(to: CGPoint(x: r.maxX, y: y - notchR))
        p.addArc(center: CGPoint(x: r.maxX, y: y), radius: notchR,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)

        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: r.maxX - radius, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - radius),
                       control: CGPoint(x: r.minX, y: r.maxY))

        // Left bite, mirrored.
        p.addLine(to: CGPoint(x: r.minX, y: y + notchR))
        p.addArc(center: CGPoint(x: r.minX, y: y), radius: notchR,
                 startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)

        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addQuadCurve(to: CGPoint(x: r.minX + radius, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// The perforation the notches sit on.
private struct Perforation: View {
    var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .overlay(
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.white.opacity(0.18))
                    .frame(height: 1)
            )
    }
}

// MARK: - Ticket

struct P1PickTicket: View {
    let pick: Pick
    /// Live/final score when there is one, so a settled ticket carries the
    /// result rather than a stale kickoff time.
    var homeScore: Int?
    var awayScore: Int?
    var isLive: Bool = false
    /// "AI PREDICTED SCORE 1-2" or the graded equivalent, already composed
    /// by the detail page so the two never disagree.
    var scoreLine: (icon: String, text: String, color: Color)?
    var confidence: String
    var loggedAt: String
    var onTrack: () -> Void = {}
    var isTracking: Bool = false

    /// Stub height, and therefore where the bite lands.
    private let stub: CGFloat = 52

    private var settled: Bool { pick.isWin || pick.isLoss }

    /// A stable, short, human-readable id. Real tickets have numbers; this
    /// one is derived from the pick's UUID so it never changes and never
    /// collides in practice.
    private var serial: String {
        let hex = pick.id.uuidString.replacingOccurrences(of: "-", with: "")
        return String(hex.prefix(4)).uppercased()
    }

    private var opponent: String {
        let called = pick.pick.lowercased()
        let home = pick.homeTeam, away = pick.awayTeam
        return called.contains(home.lowercased()) ? away : home
    }

    private var isFieldEvent: Bool {
        pick.sport == "f1" || pick.sport == "golf"
            || pick.awayTeam.lowercased() == "field" || pick.homeTeam.lowercased() == "field"
    }

    private var hasMarketOdds: Bool { (pick.marketOdds ?? 0) > 1.0 }
    private var odds: Double { pick.marketOdds ?? pick.impliedOddsForPayout ?? 0 }

    private var stampText: String? {
        if pick.isWin { return "WIN" }
        if pick.isLoss { return "LOSS" }
        return nil
    }
    private var stampColor: Color { pick.isWin ? V4.win : V4.hot }

    var body: some View {
        VStack(spacing: 0) {

            // ── Stub ────────────────────────────────────────────────
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    P1BoltMark()
                        .fill(V4.ink)
                        .frame(width: 8, height: 8)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.p1Lime))
                    Text("#\(serial)")
                        .font(.mono(11, weight: .bold))
                        .foregroundStyle(V4.ink2)
                }
                Spacer(minLength: 8)
                Text([pick.league.uppercased(), pick.localizedScheduleDisplay]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.mono(9.5, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(V4.mute)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 18)
            .frame(height: stub)

            Perforation().padding(.horizontal, 14)

            // ── The call ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    if isFieldEvent {
                        AthleteHeadshot(sport: pick.sport, name: pick.pick, size: .small)
                    } else {
                        TeamLogo(sport: pick.sport, team: pick.pick, size: .small)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(teamShortName(pick.pick, sport: pick.sport))
                            .font(.anton(30)).tracking(-0.2)
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.45)
                        Text(isFieldEvent
                             ? "\(t(.tk_to_win)) · \(pick.homeTeam.uppercased())"
                             : "\(t(.tk_to_win)) · vs \(teamShortName(opponent, sport: pick.sport))")
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(V4.mute)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Spacer(minLength: 8)

                    // The outcome stamp lives in the call row rather than
                    // floating over the card. As an overlay it landed on the
                    // score-prediction pill and ate the end of it; as a
                    // layout sibling it cannot collide, and the team name
                    // shrinks to make room instead.
                    if let stampText {
                        Text(stampText)
                            .font(.anton(22))
                            .tracking(1.6)
                            .foregroundStyle(stampColor)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(stampColor.opacity(0.75), lineWidth: 2.5))
                            .rotationEffect(.degrees(-9))
                            .fixedSize()
                            .accessibilityLabel(stampText)
                    }
                }
                .padding(.top, 16)

                // ── Terms ───────────────────────────────────────────
                HStack(alignment: .top, spacing: 0) {
                    term(t(.tk_confidence), "\(Int(pick.probability.rounded()))%",
                         sub: confidence, color: V4.win)

                    Rectangle().fill(V4.line).frame(width: 1, height: 34)

                    if let h = homeScore, let a = awayScore, settled || isLive {
                        term(isLive ? "SCORE" : "FINAL", "\(h)–\(a)",
                             sub: nil, color: .white, trailing: true)
                    } else if hasMarketOdds {
                        // A real, executable price. This is the only case that
                        // earns the big money treatment.
                        term(t(.tk_returns), "$\(Int((100 * odds).rounded()))",
                             sub: (pick.oddsSource ?? t(.rd_market_odds)).uppercased(),
                             color: Color.p1Lime, trailing: true)
                    } else {
                        // No quote to compare against. Say so plainly instead
                        // of printing our own probability back as a price.
                        term(t(.tk_no_market_short), String(format: "%.2fx", odds),
                             sub: t(.rd_est_from_conf), color: V4.ink2, trailing: true)
                    }
                }
                .padding(.top, 18)
                .overlay(alignment: .top) {
                    Rectangle().fill(V4.line).frame(height: 1).padding(.top, 8)
                }

                if let scoreLine {
                    HStack(spacing: 7) {
                        Image(systemName: scoreLine.icon)
                            .font(.system(size: 11, weight: .bold))
                        Text(scoreLine.text)
                            .font(.archivoNarrow(10, weight: .bold)).tracking(1.3)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(scoreLine.color)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(scoreLine.color.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(scoreLine.color.opacity(0.32), lineWidth: 1))
                    .padding(.top, 14)
                }

                Text("\(t(.tk_logged).uppercased()) \(loggedAt)")
                    .font(.mono(9, weight: .medium))
                    .tracking(0.8)
                    .foregroundStyle(V4.mute)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(
            P1TicketShape(notchY: stub)
                .fill(LinearGradient(colors: [V4.panelTop, V4.panelBot],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    // Sport identity as a bloom, same rule as everywhere else.
                    Ellipse()
                        .fill(RadialGradient(colors: [V4.glow(pick.sport).opacity(0.22), .clear],
                                             center: .center, startRadius: 0, endRadius: 140))
                        .frame(width: 320, height: 200)
                        .offset(y: -70)
                        .clipShape(P1TicketShape(notchY: stub))
                }
        )
        .overlay(
            P1TicketShape(notchY: stub)
                .stroke(settled ? stampColor.opacity(0.4) : Color.p1Lime.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: Color.p1Lime.opacity(settled ? 0 : 0.10), radius: 22)
    }

    @ViewBuilder
    private func term(_ label: String, _ value: String,
                      sub: String?, color: Color, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.archivoNarrow(9, weight: .bold)).tracking(1.5)
                .foregroundStyle(V4.mute)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value)
                .font(.anton(26))
                .foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
            if let sub {
                Text(sub.uppercased())
                    .font(.mono(8, weight: .bold)).tracking(0.6)
                    .foregroundStyle(V4.mute)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        .padding(.horizontal, trailing ? 0 : 0)
    }
}
