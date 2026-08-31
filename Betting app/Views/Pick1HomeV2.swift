//  Pick1HomeV2.swift
//  "Home v2 — Switch Style"
//
//  The full v2 home, in the mockup's order: streak + coin pill, Today/Live
//  switch, yesterday's proof strip, daily spin, XP bar, the sport carousel,
//  the featured pick, "Back it", the longshot teaser, tomorrow's locked pick,
//  tonight's list, the miss nudge, the leaderboard and the shop row.
//
//  Real data: the streak, the proof strip, every sport card, the featured
//  pick and its Signals, the longshot, tomorrow's teaser, the whole Upcoming
//  list, and the missed-wins count.
//
//  NOT real: the coin balance, XP / levels / leagues, the daily spin, the
//  staking amounts, and the leaderboard names. Those are six product systems
//  with no Supabase tables behind them; every value comes from
//  `GamificationV2Placeholders` in Pick1BlocksV2.swift, which is where to look
//  before any of this goes in front of a user.
//
//  Type and color come from the existing stack (Font.anton/archivo/
//  archivoNarrow/mono, Color.p1*) — v2 retuned the palette tokens in
//  Pick1Theme.swift rather than introducing a parallel one.

import SwiftUI

// MARK: - Section heading

/// Anton title + right-aligned mute caption. The design pairs every section
/// with a short label rather than a subtitle line, which keeps the vertical
/// rhythm tight on a phone.
struct P1SectionHeadV2: View {
    let title: String
    var caption: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.anton(19))
                .foregroundStyle(Color.p1Foreground)
            Spacer(minLength: 12)
            if let caption {
                Text(caption.uppercased())
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(1.54)                     // 0.14em at 11pt
                    .foregroundStyle(Color.p1Mute)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

// MARK: - Top bar

/// The mark inside the lime disc: the design's lightning bolt, traced from the
/// SVG path in the mockup (`M22 3L8 23h9l-3 14L30 16h-9z` on a 40×40 box). It
/// is not the numeral "1" — that was my substitution, and it changed the
/// brand's silhouette.
struct P1BoltMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 40.0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(22, 3))
        path.addLine(to: p(8, 23))
        path.addLine(to: p(17, 23))
        path.addLine(to: p(14, 37))
        path.addLine(to: p(30, 16))
        path.addLine(to: p(21, 16))
        path.closeSubpath()
        return path
    }
}

/// Streak pill · wordmark · profile. The coin pill from the mockup sits to the
/// right of the streak; it is omitted here because there is no coin ledger,
/// as is the profile button's "L2" level badge.
struct P1TopBarV2: View {
    let streak: Int
    var coinBalance: Int? = nil
    var initials: String = "P1"
    var onBrandTap: () -> Void = {}
    var onCoinTap: () -> Void = {}
    var onProfileTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 7) {
                if streak > 0 {
                    HStack(spacing: 7) {
                        Text("🔥").font(.system(size: 13))
                        Text("\(streak)")
                            .font(.mono(13, weight: .bold))
                            .foregroundStyle(Color.p1Foreground)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.p1Panel))
                    .overlay(Capsule().strokeBorder(Color.p1Line, lineWidth: 1))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Current streak: \(streak) wins in a row")
                }
                if let coinBalance {
                    P1CoinPillV2(balance: coinBalance, onTap: onCoinTap)
                }
                if streak <= 0 && coinBalance == nil {
                    // Keep the wordmark optically centered when both are absent.
                    Color.clear.frame(width: 44, height: 1)
                }
            }

            Spacer(minLength: 8)

            Button(action: onBrandTap) {
                VStack(spacing: 6) {
                    P1BoltMark()
                        .fill(Color.p1LimeInk)
                        .frame(width: 38 * 0.62, height: 38 * 0.62)   // svg is 62% of the disc
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(
                                LinearGradient(colors: [Color.p1Lime, Color(hex: "#8FC218")],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing)
                            )
                        )
                        .shadow(color: Color.p1Lime.opacity(0.4), radius: 12)
                    Text("PICK1")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(3.0)                  // 0.3em at 10pt
                        .foregroundStyle(Color.p1Ink2)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(action: onProfileTap) {
                Text(initials)
                    .font(.anton(14))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [Color.p1Violet, Color(hex: "#4C2A9E")],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                    )
                    .overlay(Circle().strokeBorder(Color.p1Line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Your profile")
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }
}

// MARK: - The switch

enum P1HomeTabV2: String, CaseIterable, Identifiable {
    case today, live
    var id: String { rawValue }
    var title: String { self == .today ? "Today" : "Live" }
}

/// The design's signature control. Not a segmented pill — two centered labels
/// where the state is carried by a dot: lime with a glow when the tab is
/// selected, solid hot-orange on Live whenever anything is in play. That means
/// Live can signal activity while Today is selected, which a standard picker
/// cannot express.
struct P1TabsV2: View {
    @Binding var selection: P1HomeTabV2
    var liveCount: Int = 0
    @Namespace private var glow

    var body: some View {
        HStack(spacing: 22) {
            ForEach(P1HomeTabV2.allCases) { tab in
                let isOn = tab == selection
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(tab.title.uppercased())
                            .font(.archivoNarrow(13, weight: .bold))
                            .tracking(1.3)              // 0.1em at 13pt
                            .foregroundStyle(isOn ? Color.p1Foreground : Color.p1Mute)
                        dot(for: tab, isOn: isOn)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func dot(for tab: P1HomeTabV2, isOn: Bool) -> some View {
        if tab == .live && liveCount > 0 {
            Circle()
                .fill(Color.p1Hot)
                .frame(width: 7, height: 7)
                .matchedGeometryEffect(id: "dot-live", in: glow)
        } else if isOn {
            Circle()
                .fill(Color.p1Lime)
                .frame(width: 7, height: 7)
                .shadow(color: Color.p1Lime, radius: 4)
                .matchedGeometryEffect(id: "dot-on", in: glow)
        } else {
            Color.clear.frame(width: 7, height: 7)
        }
    }
}

// MARK: - Proof strip

/// Yesterday's settled call, stated with the score. This is the design's
/// "show the record" beat — it only renders when there is a real settled
/// result to point at, never as an empty shell.
struct P1ProofStripV2: View {
    let pick: Pick

    private var scoreLine: String? {
        guard let h = pick.homeScore, let a = pick.awayScore else { return nil }
        return "\(max(h, a))–\(min(h, a))"
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("✓")
                .font(.archivo(13, weight: .black))
                .foregroundStyle(Color.p1Ink)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.p1Win))

            (
                Text("Yesterday's pick: ")
                    .foregroundStyle(Color.p1Foreground)
                + Text(pick.pick)
                    .foregroundStyle(Color.p1Win)
                + Text(scoreLine.map { " ✓ Won \($0)" } ?? " ✓ Won")
                    .foregroundStyle(Color.p1Win)
            )
            .font(.archivoNarrow(12.5, weight: .bold))
            .tracking(0.5)
            .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Win.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.p1Win.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }
}

// MARK: - Featured pick

/// One pill from the featured card's meta row: a mono value with an Archivo
/// Narrow caption beside it, on an ink capsule.
struct P1MetaPillV2: View {
    let value: String
    let caption: String
    var valueColor: Color = .p1Lime

    var body: some View {
        HStack(spacing: 7) {
            Text(value)
                .font(.mono(12, weight: .bold))
                .foregroundStyle(valueColor)
            Text(caption.uppercased())
                .font(.archivoNarrow(11, weight: .semibold))
                .tracking(0.88)                         // 0.08em at 11pt
                .foregroundStyle(Color.p1Ink2)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.p1Ink))
        .overlay(Capsule().strokeBorder(Color.p1Line, lineWidth: 1))
    }
}

/// One "Signals" meter: colored dot + factor name + the real data point, a
/// track, and the model's 0-100 read. Fed by `pick.factors`, so the bars carry
/// actual reasoning rather than decorative widths.
struct P1SignalRowV2: View {
    let factor: PickFactor
    let color: Color
    @State private var filled = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 9, height: 9)
                Text(factor.label)
                    .font(.archivo(13, weight: .bold))
                    .foregroundStyle(Color.p1Foreground)
                    .lineLimit(1)
                Text(factor.value)
                    .font(.archivo(11, weight: .semibold))
                    .foregroundStyle(Color.p1Mute)
                    .lineLimit(1)
            }
            // 118 is the mockup's *minimum*, not a fixed width — pinning it
            // there clipped real factor names ("Ranking gap") to "Ranking…".
            .frame(minWidth: 118, maxWidth: 178, alignment: .leading)
            .layoutPriority(1)
            .minimumScaleFactor(0.7)

            GeometryReader { geo in
                Capsule().fill(Color.p1Panel2)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [color, color.opacity(0.8)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: filled ? geo.size.width * CGFloat(factor.strength) / 100 : 0)
                    }
            }
            .frame(height: 7)

            Text("\(factor.strength)%")
                .font(.mono(12, weight: .bold))
                .foregroundStyle(Color.p1Foreground)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.top, 13)
        .onAppear {
            withAnimation(.timingCurve(0.25, 0.8, 0.25, 1, duration: 1.1)) { filled = true }
        }
    }
}

/// The hero card: a lime aura bleeding from the top-right corner, the
/// "<pick>: over / <opponent>" headline with the opponent in lime, the
/// reasoning line, two meta pills, and the Signals meters. Radius 28 and the
/// panel→near-black gradient are what separate it from the flat rows below.
struct P1FeaturedPickV2: View {
    let pick: Pick
    var onTap: () -> Void = {}

    /// The design's signal palette, in order.
    private static let signalColors = [Color(hex: "#FF7A2F"), Color.p1Violet, Color(hex: "#2F9BFF")]

    /// The side the model did NOT call — the lime half of the headline.
    private var opponent: String {
        pick.pick.caseInsensitiveCompare(pick.homeTeam) == .orderedSame ? pick.awayTeam : pick.homeTeam
    }

    /// "the Lakers" reads right for a club and wrong for a person, so the
    /// article is only used for team sports. The name is shortened the same
    /// way the first line is — "MEDVEDEV: OVER / MARCO TRUNGELLITI" mixed a
    /// short name with a full one inside one headline.
    private var opponentPhrase: String {
        let short = teamShortName(opponent, sport: pick.sport)
        // The mockup's "the Lakers" only works on a plural nickname. Keying it
        // off the sport was still wrong: the shortener returns abbreviations
        // for MLB, which produced "the MIA". Test the actual string instead —
        // an article is right only when the name reads as a plural, which
        // rules out abbreviations, "Cesena" and every player name.
        let isPlural = short.count > 3 && short.hasSuffix("s") && short != short.uppercased()
        return isPlural ? "the \(short)" : short
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                (
                    Text("\(pick.shortDisplayPick): over\n".uppercased())
                        .foregroundStyle(Color.p1Foreground)
                    + Text(opponentPhrase.uppercased())
                        .foregroundStyle(Color.p1Lime)
                )
                .font(.anton(29))
                .lineSpacing(-2)
                .minimumScaleFactor(0.75)

                if let factor = pick.keyFactor, !factor.isEmpty {
                    Text(factor)
                        .font(.archivo(13))
                        .lineSpacing(3)
                        .foregroundStyle(Color.p1Ink2)
                        .frame(maxWidth: 250, alignment: .leading)
                        .padding(.top, 8)
                }

                HStack(spacing: 8) {
                    P1MetaPillV2(value: "◆ \(Int(pick.probability.rounded()))%", caption: "AI conf")
                    if let time = pick.startTimeDisplay {
                        P1MetaPillV2(value: "\(time) ET", caption: pick.league, valueColor: Color.p1Foreground)
                    } else {
                        P1MetaPillV2(value: pick.league, caption: pick.sport, valueColor: Color.p1Foreground)
                    }
                }
                .padding(.top, 14)

                // Omitted entirely when the pipeline captured no factors for
                // this pick — an empty "Signals" header with no meters under it
                // reads as a loading failure.
                if let factors = pick.factors, !factors.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("SIGNALS")
                                .font(.anton(16))
                                .foregroundStyle(Color.p1Foreground)
                            Text("UNLOCKED")
                                .font(.archivoNarrow(11, weight: .bold))
                                .tracking(1.54)
                                .foregroundStyle(Color.p1Mute)
                        }
                        ForEach(Array(factors.prefix(3).enumerated()), id: \.element.id) { i, f in
                            P1SignalRowV2(factor: f, color: Self.signalColors[i % Self.signalColors.count])
                        }
                    }
                    .padding(.top, 18)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color.p1Panel, Color(hex: "#0E0F12")],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay(alignment: .topTrailing) {
                // The aura. Drawn inside the clip so it fades at the corner
                // instead of forming a visible disc.
                Circle()
                    .fill(
                        RadialGradient(colors: [Color.p1Lime.opacity(0.16), .clear],
                                       center: .center, startRadius: 0, endRadius: 150)
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: 100, y: -100)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.p1Line, lineWidth: 1)
            )
            // The card's lime under-glow — subtle, but it is what lifts the
            // hero off the ground plane in the mockup.
            .shadow(color: Color.p1Lime.opacity(0.18), radius: 30, y: 24)
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sport carousel

/// One sport's slate for today, summarised. The carousel is a *sport*
/// switcher, not a list of picks — that switch is the whole point of the
/// "Switch Style" layout, so the numbers on each card have to describe the
/// sport (how many leagues, how many picks, how strong the best call is)
/// rather than any single fixture.
struct P1SportSummaryV2: Identifiable {
    let sport: String
    let picks: [Pick]
    /// Leagues this sport has produced picks in recently. Used for the card's
    /// meta line on days the sport has nothing on, so an out-of-season card
    /// still says what it covers instead of reading as broken.
    var knownLeagues: Int = 0

    var id: String { sport }
    /// The sport's strongest call today — drives the card's badge and its
    /// sub-pill, and becomes the featured pick when the sport is selected.
    var top: Pick? { picks.max(by: { $0.probability < $1.probability }) }
    var leagueCount: Int { picks.isEmpty ? knownLeagues : Set(picks.map(\.league)).count }

    /// "5 LEAGUES · 12 PICKS" on a live sport. On an idle one the pick count
    /// is dropped: "1 LEAGUE · 0 PICKS" reads as a fault rather than as a
    /// sport that simply is not playing today.
    var metaLine: String {
        let l = "\(leagueCount) LEAGUE\(leagueCount == 1 ? "" : "S")"
        guard !picks.isEmpty else { return l + " COVERED" }
        return l + " · \(picks.count) PICK\(picks.count == 1 ? "" : "S")"
    }

    /// Bespoke card artwork, when one exists for this sport. The art already
    /// carries the sport name, so a card that has one does not draw its own
    /// title. Sports without art fall back to the gradient + emoji treatment.
    var artName: String? {
        switch sport {
        case "baseball": return "sportcard_baseball"
        case "golf":     return "sportcard_golf"
        default:         return nil
        }
    }

    /// The sports Pick1's pipeline actually covers, in the mockup's order.
    /// Rugby and AFL are in the mockup but not in the pipeline, so they are
    /// left out rather than shown as cards that can never fill.
    static let all = ["basketball", "soccer", "football", "hockey", "tennis",
                      "baseball", "combat", "cricket", "f1", "golf"]

    var displayName: String {
        switch sport {
        case "basketball": return "Basketball"
        // The mockup used "Football" for soccer and "Football US" for the NFL.
        // Side by side in the carousel both cards read "FOOTBALL…" and the
        // second truncates, so neither is identifiable.
        case "soccer":     return "Soccer"
        case "football":   return "Football"
        case "hockey":     return "Hockey"
        case "tennis":     return "Tennis"
        case "baseball":   return "Baseball"
        case "combat":     return "MMA"
        case "cricket":    return "Cricket"
        case "rugby":      return "Rugby"
        case "f1":         return "F1"
        case "golf":       return "Golf"
        case "afl":        return "AFL"
        default:           return sport.capitalized
        }
    }

    var emoji: String {
        switch sport {
        case "basketball": return "🏀"; case "baseball": return "⚾️"
        case "hockey": return "🏒";     case "football": return "🏈"
        case "soccer": return "⚽️";     case "combat": return "🥊"
        case "f1": return "🏎️";         case "golf": return "⛳️"
        case "cricket": return "🏏";    case "tennis": return "🎾"
        case "rugby": return "🏉";      case "afl": return "🏉"
        default: return "🎯"
        }
    }

    /// The design's eight card washes. Baseball and MMA share one in the
    /// mockup, which collides on any day the board has both (MLB + UFC is a
    /// normal August slate) — MMA gets its own deep red here so two adjacent
    /// cards never read as the same sport.
    var gradient: [Color] {
        switch sport {
        case "football":   return [Color(hex: "#FF7A2F"), Color(hex: "#D92E12")]
        case "basketball": return [Color(hex: "#3FBF6F"), Color(hex: "#0E7A3A")]
        case "soccer":     return [Color(hex: "#7C5CF6"), Color(hex: "#3D1E9E")]
        case "hockey":     return [Color(hex: "#2F9BFF"), Color(hex: "#0F4FB3")]
        case "tennis":     return [Color(hex: "#F5B52E"), Color(hex: "#C26A08")]
        case "baseball":   return [Color(hex: "#EF4A6E"), Color(hex: "#A3123A")]
        case "cricket":    return [Color(hex: "#22C9B7"), Color(hex: "#0A7A70")]
        case "f1":         return [Color(hex: "#8A94A6"), Color(hex: "#3C4454")]
        case "golf":       return [Color(hex: "#3FBF6F"), Color(hex: "#0E7A3A")]
        case "combat":     return [Color(hex: "#C2321F"), Color(hex: "#5E0A0A")]
        default:           return [Color(hex: "#8A94A6"), Color(hex: "#3C4454")]
        }
    }
}

/// The generated stand-in for a sport with no bespoke artwork.
///
/// The two commissioned cards (baseball, golf) are built from a gradient, a
/// diagonal gloss band, a halftone dot field in the top-right, and a large
/// object bleeding off the bottom edge. The old generated card had only the
/// gradient and a 118pt emoji, which at 290×363 left a dead zone through the
/// middle and made every un-illustrated sport look unfinished next to the two
/// that were. This rebuilds the same four layers so the whole carousel reads
/// as one set.
struct P1GeneratedCardArt: View {
    let gradient: [Color]
    let emoji: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)

            // Halftone field, top-right. Dots grow toward the right edge and
            // fade downward, matching the artwork's screen-printed feel.
            Canvas { ctx, size in
                let step = size.width / 22
                let cols = Int(size.width / step)
                let rows = Int(size.height * 0.52 / step)
                for r in 0..<rows {
                    for c in 0..<cols {
                        let fx = Double(c) / Double(max(cols - 1, 1))   // 0 left → 1 right
                        let fy = Double(r) / Double(max(rows - 1, 1))   // 0 top → 1 down
                        // Only the right half carries dots, and they die out
                        // as they fall, so the field never fights the emoji.
                        let strength = max(0, (fx - 0.45) / 0.55) * (1 - fy * 0.85)
                        guard strength > 0.02 else { continue }
                        let radius = step * 0.42 * strength
                        let rect = CGRect(x: CGFloat(c) * step + step / 2 - radius,
                                          y: CGFloat(r) * step + step / 2 - radius,
                                          width: radius * 2, height: radius * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.28 * strength)))
                    }
                }
            }
            .allowsHitTesting(false)

            // The object. Sized off the card rather than a fixed point value,
            // so it keeps filling the lower half whatever `width` becomes.
            Text(emoji)
                .font(.system(size: width * 0.72))
                .shadow(color: .black.opacity(0.4), radius: 18, y: 16)
                .offset(x: width * 0.10, y: height * 0.10)

            // Diagonal gloss across the upper-left, drawn last so it sits over
            // the object like a sheet of glass, exactly as in the artwork.
            LinearGradient(stops: [
                .init(color: .white.opacity(0.00), location: 0.00),
                .init(color: .white.opacity(0.13), location: 0.30),
                .init(color: .white.opacity(0.13), location: 0.46),
                .init(color: .white.opacity(0.00), location: 0.47),
            ], startPoint: .topTrailing, endPoint: .bottomLeading)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
        .clipped()
    }
}

/// 196×264 gradient tile with the sport's emoji bleeding off the bottom
/// edge. Unselected cards sit at 0.94 scale — the size difference is what
/// makes the selected sport read as selected without a border or a checkmark.
struct P1SportCardV2: View {
    /// Card geometry in one place. The 0.80 ratio is the bespoke artwork's
    /// aspect, so those PNGs are never cropped, and the title reserve is
    /// derived from the width so it keeps tracking the artwork's own baked-in
    /// title whenever this size changes.
    static let width: CGFloat = 290
    static var height: CGFloat { (width / 0.80).rounded() }

    /// Where the artwork's own baked-in title sits, as fractions of the PNG.
    /// The art carries transparent padding, so its title is inset further than
    /// the card's own 18pt content padding — without correcting for that, the
    /// meta line sat left of the title and jammed against it.
    private static let contentPadding: CGFloat = 18
    private static let artTitleLeftFraction: CGFloat = 0.125
    private static let artTitleBottomFraction: CGFloat = 0.185
    static var artTitleReserve: CGFloat {
        max(0, (height * artTitleBottomFraction - contentPadding).rounded())
    }
    static var artTitleIndent: CGFloat {
        max(0, (width * artTitleLeftFraction - contentPadding).rounded())
    }

    let summary: P1SportSummaryV2
    let isSelected: Bool
    let isTopEdge: Bool
    var onTap: () -> Void = {}

    private var returnLabel: String? {
        guard let top = summary.top else { return nil }
        return String(format: "↑ %.1f× return", top.decimalOdds)
    }

    private var subLabel: String {
        guard let top = summary.top else { return "NO PICK TODAY" }
        let name = top.shortDisplayPick.uppercased()
        guard let time = top.localizedStartTimeDisplay else { return name }
        return "\(name) · \(time)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if summary.artName == nil {
                    Text(summary.displayName.uppercased())
                        .font(.anton(23))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                        // Clearance for the probability badge. Idle sports draw
                        // no badge, so reserving the corner there just forced
                        // "FOOTBALL US" onto two lines for nothing.
                        .padding(.trailing, summary.top == nil ? 0 : 64)
                } else {
                    // The artwork paints its own title; reserve its height so
                    // the meta line lands under it with the same breathing
                    // room the drawn titles get.
                    Color.clear.frame(height: Self.artTitleReserve)
                }

                // No trailing clearance here: this line sits *below* the
                // badge, and reserving 64pt for it truncated "1 LEAGUE · 13
                // PICKS" to "13 PI…" on a 196pt card.
                Text(summary.metaLine)
                    .font(.archivoNarrow(11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 5)
                    // Line up with the artwork's title rather than the card edge.
                    .padding(.leading, summary.artName == nil ? 0 : Self.artTitleIndent)

                Spacer(minLength: 12)

                if isTopEdge {
                    Text("👑 TOP EDGE")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1.0)
                        .foregroundStyle(Color.p1Ink)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Color.p1Lime))
                        .shadow(color: Color.p1Lime.opacity(0.5), radius: 7, y: 4)
                        .padding(.bottom, 7)
                }

                Text(subLabel)
                    .font(.mono(10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.p1Ink.opacity(0.4)))

                if let returnLabel {
                    Text(returnLabel)
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(Color.p1Ink)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(Color.p1Lime))
                        .shadow(color: Color.p1Lime.opacity(0.35), radius: 6, y: 4)
                        .padding(.top, 5)
                }
            }
            .padding(18)
            .frame(width: Self.width, height: Self.height, alignment: .leading)
            // The art has to sit BETWEEN the wash and the text: stacked
            // `.background` modifiers push each new layer further back, which
            // buried the emoji under the gradient and left the card blank.
            .background {
                Group {
                    if let art = summary.artName {
                        // Scaled to fill so the card body reaches every edge;
                        // the PNG's transparent outer glow is what gets
                        // cropped, not the artwork.
                        Image(art)
                            .resizable()
                            .scaledToFill()
                    } else {
                        P1GeneratedCardArt(gradient: summary.gradient,
                                           emoji: summary.emoji,
                                           width: Self.width,
                                           height: Self.height)
                    }
                }
                .allowsHitTesting(false)
            }
            .saturation(summary.picks.isEmpty ? 0.25 : 1)
            .overlay(alignment: .topTrailing) {
                if let top = summary.top {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("◆")
                            .font(.mono(13, weight: .bold))
                            .foregroundStyle(Color.p1Lime)
                        Text("\(Int(top.probability.rounded()))")
                            .font(.anton(34))
                            .foregroundStyle(.white)
                        + Text("%")
                            .font(.anton(16))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
                    .padding(.top, 12)
                    .padding(.trailing, 14)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            // Only the generated cards get a hairline edge. Artwork brings its
            // own border and glow, and stroking over it read as a frame
            // sitting on top of the illustration.
            .overlay {
                if summary.artName == nil {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(0.45), radius: 20, y: 18)
            .scaleEffect(isSelected ? 1.0 : 0.94)
            .opacity(isSelected ? 1.0 : 0.85)
            // Without this the tap target is only the drawn glyphs, so most of
            // the card (the wash and the art) is dead to touch.
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.displayName), \(summary.picks.count) picks today")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Empty sport

/// The mockup's dashed `.empty` panel, shown when the selected sport has no
/// slate today. It replaces the featured card rather than sitting beside it,
/// which is what the mockup's `renderBelow()` does.
struct P1SportEmptyStateV2: View {
    let summary: P1SportSummaryV2

    var body: some View {
        VStack(spacing: 0) {
            Text(summary.emoji).font(.system(size: 40))
            Text("NO \(summary.displayName.uppercased()) TODAY")
                .font(.anton(18))
                .foregroundStyle(Color.p1Foreground)
                .padding(.top, 10)
            Text("THE MODEL PUBLISHES A SLATE WHEN THIS SPORT IS IN SEASON")
                .font(.archivoNarrow(12, weight: .bold))
                .tracking(0.96)
                .foregroundStyle(Color.p1Mute)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.p1Line, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        )
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }
}

// MARK: - Upcoming row

/// 26×26 rounded tile carrying a team's short code, as in the mockup. The
/// design gives every club its own brand gradient; there are no team colors in
/// Supabase, so the two tiles take the sport's wash at two depths — same
/// shape, and the two sides still read as distinct.
struct P1TeamTileV2: View {
    let name: String
    let colors: [Color]

    /// "Kansas City Chiefs" → KC, "Lazio" → LAZ, "Daniil Medvedev" → DM.
    private var code: String {
        let words = name.split(separator: " ").filter { $0.count > 1 }
        if words.count >= 2 {
            return words.prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
        }
        return String(name.prefix(3)).uppercased()
    }

    var body: some View {
        Text(code)
            .font(.anton(10))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: colors,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
    }
}

/// The mockup's game row: stacked team tiles on the left, a rule-separated
/// kickoff column, and the model's call right-aligned — "AI PICK", the side in
/// lime, and the confidence in the settled-win green.
struct P1UpcomingRowV2: View {
    let pick: Pick
    let tint: [Color]
    var isSelected: Bool = false
    var onTap: () -> Void = {}

    private var deepTint: [Color] { tint.map { $0.opacity(0.55) } }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        P1TeamTileV2(name: pick.awayTeam, colors: tint)
                        Text(pick.awayTeam)
                            .font(.anton(15))
                            .foregroundStyle(Color.p1Foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    HStack(spacing: 10) {
                        P1TeamTileV2(name: pick.homeTeam, colors: deepTint)
                        Text(pick.homeTeam)
                            .font(.anton(15))
                            .foregroundStyle(Color.p1Foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let time = pick.startTimeDisplay {
                    Text(time.replacingOccurrences(of: " ", with: "\n") + "\nET")
                        .font(.mono(10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.p1Mute)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 52)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Color.p1Line).frame(width: 1)
                        }
                }

                VStack(alignment: .trailing, spacing: 0) {
                    Text("AI PICK")
                        .font(.archivoNarrow(8, weight: .bold))
                        .tracking(1.28)                 // 0.16em at 8pt
                        .foregroundStyle(Color.p1Mute)
                    Text(pick.shortDisplayPick)
                        .font(.anton(14))
                        .foregroundStyle(Color.p1Lime)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(Int(pick.probability.rounded()))%")
                        .font(.anton(26))
                        .foregroundStyle(Color.p1Win)
                        .padding(.top, 2)
                }
                .frame(minWidth: 72, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.p1Panel))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.p1Lime.opacity(0.55) : Color.p1Line, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen

/// DEBUG-only harness so v2 can be reviewed on the simulator before it is
/// wired into the shell. Launch with `-showHomeV2`, matching the existing
/// `-showHomeUnauthenticated` / `-openPaywall` review hooks. Compiled out of
/// Release.
#if DEBUG
struct Pick1HomeV2DebugHost: View {
    @StateObject private var vm = PicksViewModel()
    @State private var showProfile = false
    @State private var detailPick: Pick?

    var body: some View {
        Pick1HomeV2(vm: vm,
                    onSelectPick: { detailPick = $0 },
                    onProfile: { showProfile = true })
            .task { await vm.loadAll() }
            .fullScreenCover(isPresented: $showProfile) {
                Pick1ProfileSheetV2(vm: vm, onClose: { showProfile = false })
            }
            .fullScreenCover(item: $detailPick) { p in
                Pick1DetailV2(pick: p, onBack: { detailPick = nil })
            }
    }
}

/// `-showWinBackV2` and `-showProfileV2` review hosts.
struct Pick1WinBackV2DebugHost: View {
    @StateObject private var vm = PicksViewModel()

    var body: some View {
        Pick1WinBackV2(vm: vm, lapsedOn: Date().addingTimeInterval(-30 * 86_400))
            .task { await vm.loadAll() }
    }
}

struct Pick1ProfileV2DebugHost: View {
    @StateObject private var vm = PicksViewModel()

    var body: some View {
        Pick1ProfileSheetV2(vm: vm)
            .task { await vm.loadAll() }
    }
}
#endif

struct Pick1HomeV2: View {
    @ObservedObject var vm: PicksViewModel
    @State private var tab: P1HomeTabV2 = .today
    /// Nil until the board loads, then the sport holding the day's best call.
    /// Everything below the carousel is scoped to this — that scoping is the
    /// design, not a filter bolted onto it.
    @State private var selectedSport: String?
    /// Optional so the DEBUG host still renders if the manager is ever not
    /// injected — the mockup's "MJ" is just the signed-in user's initials.
    @Environment(AuthManager.self) private var auth: AuthManager?
    @EnvironmentObject private var subs: SubscriptionManager
    @State private var showShop = false
    private let gamification = GamificationV2Placeholders.shared
    var onSelectPick: (Pick) -> Void = { _ in }
    var onProfile: () -> Void = {}

    private var initials: String {
        guard let name = auth?.displayName, !name.isEmpty else { return "P1" }
        let words = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" })
        if words.count >= 2 {
            return words.prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    /// Today's board grouped by sport, strongest sport first. Ordering by the
    /// best available call (rather than a fixed list) puts the day's real edge
    /// at the front of the carousel, where it is seen without scrolling.
    private var sports: [P1SportSummaryV2] {
        let today = Dictionary(grouping: vm.todayPicks, by: \.sport)
        // League coverage per sport, taken from history so a sport with an
        // empty slate still describes itself.
        let leagues = Dictionary(grouping: vm.historyPicks, by: \.sport)
            .mapValues { Set($0.map(\.league)).count }

        let all = P1SportSummaryV2.all.map { sport in
            P1SportSummaryV2(sport: sport,
                             picks: today[sport] ?? [],
                             knownLeagues: leagues[sport] ?? 0)
        }
        // Sports with a slate come first, strongest edge leading. The rest
        // keep the canonical order so the carousel does not reshuffle daily.
        let live = all.filter { !$0.picks.isEmpty }
            .sorted { ($0.top?.probability ?? 0) > ($1.top?.probability ?? 0) }
        let idle = all.filter { $0.picks.isEmpty }
        return live + idle
    }

    /// Only ever a sport that actually has a slate, unless the user taps an
    /// idle card — then it is that one, and the screen shows the empty state.
    private var activeSport: P1SportSummaryV2? {
        sports.first { $0.sport == selectedSport } ?? sports.first
    }

    /// Yesterday's strongest settled win *in the selected sport*. Nil when
    /// that sport produced no win, in which case the strip is absent rather
    /// than showing another sport's result under this one's card.
    private var proofPick: Pick? {
        guard let sport = activeSport?.sport else { return nil }
        return vm.yesterdayPicks
            .filter { $0.sport == sport && $0.result.lowercased() == "win" }
            .max(by: { $0.probability < $1.probability })
    }

    private var featured: Pick? { activeSport?.top }

    /// Games actually in progress. `vm.liveScores` is the whole live_scores
    /// table — scheduled and final rows included — so counting it directly
    /// reported "1000 in play" and pinned the Live dot permanently on.
    private var liveNow: [LiveScore] { vm.liveScores.filter(\.isLive) }

    private var rest: [Pick] {
        guard let picks = activeSport?.picks else { return [] }
        guard let featured else { return picks }
        return picks.filter { $0.id != featured.id }
    }

    /// The longest-odds call on today's whole board — the real pick behind the
    /// mockup's blurred "longshot of the day".
    private var longshot: Pick? {
        vm.todayPicks.filter { $0.probability < 55 }.min(by: { $0.probability < $1.probability })
            ?? vm.todayPicks.min(by: { $0.probability < $1.probability })
    }

    /// Tomorrow's board if the pipeline has already published it. Blurred
    /// either way, so the teaser never claims a pick that does not exist.
    private var tomorrow: (headline: String, meta: String)? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        guard let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else { return nil }
        let picks = vm.todayPicks.filter { ($0.gameDateValue ?? .distantPast) >= next }
        guard let best = picks.max(by: { $0.probability < $1.probability }) else { return nil }
        return (best.shortDisplayPick, "◆ \(Int(best.probability.rounded()))% AI CONF · \(best.league)")
    }

    /// Wins from the last 7 days a free user could not see.
    private var missedWins: Int {
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        return vm.historyPicks.filter { $0.isWin && ($0.gameDateValue ?? .distantPast) >= weekAgo }.count
    }

    /// Everything with no Supabase table behind it, grouped and pushed below
    /// the real content. It stays on the screen because the mockup calls for
    /// it, but it no longer occupies the space above the fold that today's
    /// picks need. Flip `showUnbackedBlocks` to false to drop it entirely.
    @ViewBuilder private var unbackedBlocks: some View {
        if Self.showUnbackedBlocks {
            P1SectionHeadV2(title: "Rewards", caption: "Coming soon")

            P1DailySpinV2(day: gamification.spinDay, used: gamification.spinUsed)

            P1XPRowV2(level: gamification.level, league: gamification.leagueName,
                      xp: gamification.xp, target: gamification.xpTarget)
                .padding(.top, 14)

            if let featured {
                P1BackItV2(pick: featured)
            }

            P1LeaderboardV2(rows: gamification.leaders)

            P1NudgeV2(icon: "🎁",
                      leading: "Rewards shop, redeem coins for ",
                      highlight: "Premium time, gear & unlocks",
                      trailing: "",
                      cta: "Shop →",
                      tint: Color(hex: "#FFC83C")) { showShop = true }
        }
    }

    /// One switch for the whole gamification layer. False ships a home made
    /// only of things the app can actually prove.
    static let showUnbackedBlocks = false

    var body: some View {
        ZStack {
            // The screen ground: a soft lift behind the status bar, falling to
            // ink — this is what stops the featured card's aura reading as a
            // sticker on a flat background.
            RadialGradient(colors: [Color(hex: "#1D2026"), Color.p1Ink],
                           center: .init(x: 0.5, y: -0.08),
                           startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // The coin pill belongs to the same unbacked set as the
                    // spin and the leaderboard, so it follows the same switch.
                    P1TopBarV2(streak: vm.currentStreak,
                               coinBalance: Self.showUnbackedBlocks ? gamification.coinBalance : nil,
                               initials: initials,
                               onCoinTap: { showShop = true },
                               onProfileTap: onProfile)

                    P1TabsV2(selection: $tab, liveCount: liveNow.count)
                        .frame(maxWidth: .infinity)

                    if tab == .today {
                        // The product leads. The mockup opened with the daily
                        // spin and the XP bar, which put two invented widgets
                        // in the only two slots visible without scrolling and
                        // pushed the actual picks below the fold. They are now
                        // grouped at the bottom under `unbackedBlocks`.
                        if !sports.isEmpty {
                            let bestSport = sports.first?.sport
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(sports) { s in
                                        P1SportCardV2(summary: s,
                                                      isSelected: s.sport == activeSport?.sport,
                                                      isTopEdge: s.sport == bestSport) {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                selectedSport = s.sport
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 22)
                                .padding(.top, 14)
                                .padding(.bottom, 18)
                            }
                        }

                        // Sits under the carousel, not above it: the strip is
                        // scoped to the selected sport, so it only makes sense
                        // once that sport has been chosen.
                        if let proofPick {
                            P1ProofStripV2(pick: proofPick)
                        }

                        if let featured {
                            P1FeaturedPickV2(pick: featured) { onSelectPick(featured) }
                        } else if let idle = activeSport {
                            P1SportEmptyStateV2(summary: idle)
                        }

                        if let longshot {
                            P1LongshotV2(pick: longshot, isLocked: !subs.isPro) {
                                onSelectPick(longshot)
                            }
                        }

                        if let tomorrow {
                            P1TomorrowV2(headline: tomorrow.headline, meta: tomorrow.meta)
                        }

                        if !rest.isEmpty {
                            P1SectionHeadV2(title: "Upcoming",
                                            caption: activeSport?.displayName ?? "Tonight")
                            VStack(spacing: 10) {
                                ForEach(rest) { p in
                                    P1UpcomingRowV2(pick: p,
                                                    tint: activeSport?.gradient ?? [Color.p1Line2, Color.p1Panel2]) {
                                        onSelectPick(p)
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                        }

                        if !subs.isPro, missedWins > 0 {
                            P1NudgeV2(icon: "😬",
                                      leading: "You missed ",
                                      highlight: "\(missedWins) winning picks",
                                      trailing: " this week. Premium members saw them all.",
                                      cta: "See what's next →",
                                      onTap: onProfile)
                        }

                        unbackedBlocks

                        if vm.todayPicks.isEmpty && !vm.isLoading {
                            P1SectionHeadV2(title: "No picks yet", caption: "Check back")
                            Text("The model publishes the day's board each morning.")
                                .font(.archivo(13))
                                .foregroundStyle(Color.p1Ink2)
                                .padding(.horizontal, 22)
                        }
                    } else {
                        P1SectionHeadV2(title: "Live", caption: "\(liveNow.count) in play")
                        if liveNow.isEmpty {
                            Text("Nothing in play right now.")
                                .font(.archivo(13))
                                .foregroundStyle(Color.p1Ink2)
                                .padding(.horizontal, 22)
                        }
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 12)
                .fullScreenCover(isPresented: $showShop) {
                    P1ShopSheetV2(balance: gamification.coinBalance) { showShop = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
