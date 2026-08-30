//  Pick1HomeV4.swift
//  "Home v4 — Glow Style"
//
//  A denser rebuild of the home. Three things change the information design
//  versus v2, and all three are improvements worth naming:
//
//  1. THE SPORT SELECTOR IS ORBS, NOT CARDS. v2 used 290×363 tiles, so a
//     "selector" showed one and a half options. v4 uses 56pt circles and puts
//     seven sports on screen at once, which is what a selector is for. The
//     off state is desaturated, the on state gets a lime ring and a glow.
//  2. THE PICKS ARE ROWS. One hero card carries the day's best call, and
//     everything else is a compact row. v2 gave every pick a card, which meant
//     scrolling to see the slate.
//  3. GLOW CARRIES HIERARCHY, NOT SIZE. The ground drops to #07080a and
//     importance is signalled by glow and colour rather than by area.
//
//  Real data throughout: the orbs are the sports with a slate today, the hero
//  is that sport's strongest call with its real `factors`, the rows are the
//  rest of the board, Live reads `live_scores`, and Results reads the settled
//  history. The coin pill, the "back it" chip, the backer count and the
//  paybar countdown have no backend and follow `showUnbacked`, the same switch
//  as v2.

import SwiftUI
import StoreKit

// MARK: - v4 palette
//
// v4 sits on a darker ground than v2 and adds gold. Kept out of Pick1Theme so
// the v2 screens keep the palette they were designed against, but internal
// rather than private: the match detail page is styled against these same
// tokens so the two screens read as one app.
enum V4 {
    static let ink = Color(hex: "#07080A")
    static let lift = Color(hex: "#181C23")
    static let panelTop = Color(hex: "#1B1F27")
    static let panelBot = Color(hex: "#0B0D11")
    static let rowTop = Color(hex: "#14171D")
    static let line = Color.white.opacity(0.09)
    static let mute = Color(hex: "#63666D")
    static let ink2 = Color(hex: "#B9B7B0")
    static let gold = Color(hex: "#FFD84D")
    static let win = Color(hex: "#4ADE80")
    static let hot = Color(hex: "#FF5A36")
    static let hotSoft = Color(hex: "#FF8A6C")

    /// Per-sport glow, used on the row emoji and the card bloom.
    static func glow(_ sport: String) -> Color {
        switch sport {
        case "basketball": return Color(hex: "#3EC96F")
        case "soccer":     return Color(hex: "#C9FF43")
        case "hockey":     return Color(hex: "#4F8DFF")
        case "tennis":     return Color(hex: "#B98CFF")
        case "football":   return Color(hex: "#E2543E")
        case "baseball":   return Color(hex: "#FF6FA0")
        case "combat":     return Color(hex: "#FF9F43")
        case "f1":         return Color(hex: "#8FA3BF")
        case "golf":       return Color(hex: "#48E0A0")
        case "cricket":    return Color(hex: "#22C9B7")
        default:           return Color.p1Lime
        }
    }

    /// The three factor-bar gradients, in order.
    static let barGradients: [[Color]] = [
        [Color(hex: "#FF7A3C"), Color(hex: "#FFD84D")],
        [Color(hex: "#8B5CF6"), Color(hex: "#C4A8FF")],
        [Color(hex: "#3AA5FF"), Color(hex: "#7EE7FF")],
    ]
}

func v4Emoji(_ sport: String) -> String {
    switch sport {
    case "basketball": return "🏀"; case "baseball": return "⚾️"
    case "hockey": return "🏒";     case "football": return "🏈"
    case "soccer": return "⚽️";     case "combat": return "🥊"
    case "f1": return "🏎️";         case "golf": return "⛳️"
    case "cricket": return "🏏";    case "tennis": return "🎾"
    case "rugby", "afl": return "🏉"
    default: return "🎯"
    }
}

/// The ten sports Pick1 covers, in the order Ethan set them. This is the
/// authority: a sport not on this list is not shown, whatever the pipeline
/// happens to have generated.
let P1_SPORTS: [String] = [
    "basketball", "football", "soccer", "hockey", "baseball",
    "combat", "f1", "tennis", "cricket", "golf",
]

/// Display names, also Ethan's: "Fight" not MMA, "Race" not Racing or F1.
func v4Name(_ sport: String) -> String {
    switch sport {
    case "basketball": return "Basketball"; case "baseball": return "Baseball"
    case "hockey": return "Hockey";         case "football": return "Football"
    case "soccer": return "Soccer";         case "combat": return "Fight"
    case "f1": return "Race";               case "golf": return "Golf"
    case "cricket": return "Cricket";       case "tennis": return "Tennis"
    default: return sport.capitalized
    }
}

// MARK: - Top bar

struct P1V4TopBar: View {
    var coins: Int?
    var onCoinTap: () -> Void = {}

    var body: some View {
        HStack {
            if let coins {
                Button(action: onCoinTap) {
                    HStack(spacing: 6) {
                        Text("🪙").font(.system(size: 10))
                        Text(coins.formatted())
                            .font(.mono(11, weight: .bold))
                            .foregroundStyle(V4.gold)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(V4.gold.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(V4.gold.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 34, height: 1)
            }

            Spacer(minLength: 8)

            VStack(spacing: 3) {
                P1BoltMark()
                    .fill(V4.ink)
                    .frame(width: 19, height: 19)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [Color.p1Lime, Color(hex: "#8FC218")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .shadow(color: Color.p1Lime.opacity(0.5), radius: 13)
                Text("PICK1")
                    .font(.archivoNarrow(8, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(V4.mute)
            }

            Spacer(minLength: 8)

            // No avatar here: the floating nav already owns Profile, and two
            // routes to the same screen made the top bar look busier than it
            // needed to be. The spacer keeps the bolt optically centred.
            Color.clear.frame(width: 34, height: 1)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }
}

// MARK: - Segment

enum P1V4Tab: String, CaseIterable, Identifiable {
    case tonight, live, yours, results
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tonight: return "Tonight"
        case .live:    return "Live"
        case .yours:   return "Your Picks"
        case .results: return "Results"
        }
    }
}

struct P1V4Segment: View {
    @Binding var selection: P1V4Tab

    var body: some View {
        HStack(spacing: 14) {
            ForEach(P1V4Tab.allCases) { tab in
                let on = tab == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = tab }
                } label: {
                    HStack(spacing: 6) {
                        if on {
                            Circle().fill(Color.p1Lime).frame(width: 5, height: 5)
                        }
                        Text(tab.title.uppercased())
                            .font(.archivoNarrow(12, weight: .bold))
                            .tracking(0.96)
                            .foregroundStyle(on ? .white : V4.mute)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}

// MARK: - Orb selector

struct P1V4Orb: View {
    let sport: String
    let isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(v4Emoji(sport))
                    .font(.system(size: 23))
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [V4.panelTop, V4.panelBot],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .overlay(Circle().strokeBorder(isOn ? Color.p1Lime : V4.line, lineWidth: 1.5))
                    // Off-state orbs are drained rather than dimmed, so the
                    // selected sport is the only colour in the row.
                    .saturation(isOn ? 1 : 0.45)
                    .shadow(color: isOn ? Color.p1Lime.opacity(0.45) : .clear, radius: 13)
                    .scaleEffect(isOn ? 1.12 : 1)

                Text(v4Name(sport).uppercased())
                    .font(.archivoNarrow(8.5, weight: .bold))
                    .tracking(0.85)
                    .foregroundStyle(isOn ? Color.p1Lime : V4.mute)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 6)

                Circle()
                    .fill(Color.p1Lime)
                    .frame(width: 5, height: 5)
                    .opacity(isOn ? 1 : 0)
                    .padding(.top, 4)
            }
            .frame(width: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(v4Name(sport))
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Factor bar

struct P1V4FactorRow: View {
    let icon: String
    let label: String
    let note: String
    let value: Int
    let colors: [Color]
    @State private var filled = false

    var body: some View {
        HStack(spacing: 9) {
            Text(icon).font(.system(size: 13)).frame(width: 18)
            (
                Text(label).foregroundStyle(.white)
                + Text(note.isEmpty ? "" : " \(note)").foregroundStyle(V4.mute)
            )
            .font(.archivoNarrow(11.5, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            // The mockup's notes were short ("(last 10)"). Real factor values
            // are data points ("Snell 2.1 ERA"), so the label column needs
            // roughly half the row before the bar gets what is left.
            .frame(width: 148, alignment: .leading)

            GeometryReader { geo in
                Capsule().fill(.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                            .frame(width: filled ? geo.size.width * CGFloat(value) / 100 : 0)
                    }
            }
            .frame(height: 6)

            Text("\(value)%")
                .font(.mono(11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.top, 10)
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 1.0)) { filled = true }
        }
    }
}

// MARK: - Hero pick

struct P1V4Hero: View {
    let pick: Pick
    var showUnbacked: Bool
    var backers: Int
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                Text("⚡ TODAY'S #1 PICK")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(Color.p1Lime)

                Text(pick.displayPick.uppercased())
                    .font(.anton(26))
                    .foregroundStyle(.white)
                    .lineSpacing(-3)
                    .lineLimit(3)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: 240, alignment: .leading)
                    .padding(.top, 8)

                if showUnbacked {
                    HStack(spacing: 8) {
                        Text("🪙 250 · BACK IT")
                            .font(.mono(10, weight: .bold))
                            .foregroundStyle(V4.gold)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(V4.gold.opacity(0.10)))
                            .overlay(Capsule().strokeBorder(V4.gold.opacity(0.4), lineWidth: 1))
                        Text("+ \(backers) BACKING")
                            .font(.mono(9, weight: .bold))
                            .foregroundStyle(V4.mute)
                    }
                    .padding(.top, 12)
                }

                if let factors = pick.factors, !factors.isEmpty {
                    Text("WHY THE AI LIKES IT")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.54)
                        .foregroundStyle(V4.ink2)
                        .padding(.top, 20)

                    ForEach(Array(factors.prefix(3).enumerated()), id: \.element.id) { i, f in
                        P1V4FactorRow(icon: ["🔥", "🧠", "💧"][i % 3],
                                      label: f.label,
                                      note: f.value.isEmpty ? "" : "(\(f.value))",
                                      value: f.strength,
                                      colors: V4.barGradients[i % V4.barGradients.count])
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [V4.panelTop, V4.panelBot],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(LinearGradient(colors: [Color.p1Lime.opacity(0.10), .clear],
                                                 startPoint: .topLeading, endPoint: .center))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.p1Lime.opacity(0.35), lineWidth: 1)
            )
            // The confidence number and the floating art both sit outside the
            // padded content, top-right, exactly as in the mockup.
            // The mockup floats the sport's ball over this corner. Dropped:
            // it landed on the confidence figure, and the sport is already
            // stated by the selected orb directly above the card.
            .overlay(alignment: .topTrailing) {
                // Negative spacing on purpose. Anton reserves a full line box
                // at 44pt but its digits have almost no descender, so ~9pt of
                // that box is empty air under the number. Left at a positive
                // spacing the label floated well clear of the figure it
                // belongs to. This closes the gap optically rather than
                // metrically, which is what the eye reads.
                VStack(alignment: .trailing, spacing: -7) {
                    (
                        Text("\(Int(pick.probability.rounded()))").font(.anton(44))
                        + Text("%").font(.anton(17))
                    )
                    .foregroundStyle(Color.p1Lime)
                    .shadow(color: Color.p1Lime.opacity(0.5), radius: 12)
                    Text("AI CONFIDENCE")
                        .font(.archivoNarrow(8, weight: .bold))
                        .tracking(1.28)
                        .foregroundStyle(V4.mute)
                }
                .padding(.top, 16)
                .padding(.trailing, 18)
            }
            .shadow(color: Color.p1Lime.opacity(0.12), radius: 25)
            .padding(.horizontal, 22)
            .padding(.top, 26)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game row

/// A game card, not a list row. The compact row buried the two things that
/// actually make someone act: who the model backs, and what the pick returns.
/// Both now get their own band, and the payout is stated in money rather than
/// as a bare multiple.
struct P1V4GameRow: View {
    let pick: Pick
    var isLocked: Bool = false
    /// Marks the call on today's board that would return the most on the
    /// reference stake. It is deliberately NOT presented as the best pick:
    /// the biggest return is by definition the least likely call, which is
    /// why the win probability sits right beside it at the same weight.
    var isBiggestWin: Bool = false
    var onTap: () -> Void = {}
    var onTrack: () -> Void = {}

    /// The reference stake the return is quoted against. $100 is the same
    /// anchor the production detail uses, so the two screens agree.
    private static let referenceStake: Double = 100

    /// F1 and golf are field events, not head-to-head: the pipeline writes
    /// `<event> vs Field`, so neither column is an opponent. Deriving the
    /// call from home/away there rendered the card as "FIELD · vs BMW
    /// Championship". The production detail already special-cases these two
    /// (`isRaceEvent`); the card has to as well.
    private var isFieldEvent: Bool { pick.sport == "f1" || pick.sport == "golf" }

    private var calledIsHome: Bool {
        pick.pick.caseInsensitiveCompare(pick.homeTeam) == .orderedSame
    }
    private var called: String {
        isFieldEvent ? pick.pick : (calledIsHome ? pick.homeTeam : pick.awayTeam)
    }
    /// The event for a field sport, the opponent otherwise.
    private var other: String {
        if isFieldEvent {
            // "Field" is a placeholder, never a name to show.
            return pick.homeTeam.caseInsensitiveCompare("field") == .orderedSame
                ? pick.awayTeam : pick.homeTeam
        }
        return calledIsHome ? pick.awayTeam : pick.homeTeam
    }
    private var returns: Int { Int((Self.referenceStake * pick.decimalOdds).rounded()) }

    /// Real book quote or the model's implied price. Saying which is the
    /// difference between a number a user can act on and one they cannot.
    private var oddsNote: String {
        if let src = pick.oddsSource, pick.marketOdds != nil {
            return "\(String(format: "%.2f", pick.decimalOdds))× · \(src.uppercased())"
        }
        return "\(String(format: "%.2f", pick.decimalOdds))× · IMPLIED"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                crests

                VStack(alignment: .leading, spacing: 4) {
                    Text(teamShortName(called, sport: pick.sport).uppercased())
                        .font(.anton(21))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .blur(radius: isLocked ? 8 : 0)

                    Text(metaLine)
                        .font(.mono(9, weight: .bold))
                        .tracking(0.54)
                        .foregroundStyle(V4.mute)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 1) {
                    (
                        Text("\(Int(pick.probability.rounded()))").font(.anton(26))
                        + Text("%").font(.anton(12))
                    )
                    .foregroundStyle(V4.win)
                    .blur(radius: isLocked ? 8 : 0)
                    Text("WIN PROB")
                        .font(.archivoNarrow(7.5, weight: .bold))
                        .tracking(1.05)
                        .foregroundStyle(V4.mute)
                }
            }

            Rectangle().fill(V4.line)
                .frame(height: 1)
                .padding(.top, 13)

            // Money left, action right. Giving the return the full width made
            // it the biggest thing on screen but also made the card enormous
            // and loose; paired with the button it stays the subject of the
            // card while the whole thing reads in one glance.
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("$100")
                            .font(.anton(17))
                            .foregroundStyle(V4.mute)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(V4.mute)
                        Text("$\(returns)")
                            .font(.anton(33))
                            .foregroundStyle(Color.p1Lime)
                            .shadow(color: Color.p1Lime.opacity(0.4), radius: 11)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .blur(radius: isLocked ? 8 : 0)
                    }
                    // The multiplier and its source. "$100 →" already says
                    // what the figure is, so the old "$100 RETURNS" caption
                    // above it was saying the same thing twice.
                    Text(oddsNote)
                        .font(.mono(8.5, weight: .bold))
                        .foregroundStyle(V4.mute)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .blur(radius: isLocked ? 8 : 0)
                }

                Spacer(minLength: 6)

                if isLocked {
                    HStack(spacing: 6) {
                        Text("🔒").font(.system(size: 12))
                        Text("UNLOCK")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(V4.ink)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(Color.p1Lime))
                } else {
                    Button(action: onTrack) {
                        Text("TRACK THIS")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(V4.ink)
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .background(Capsule().fill(Color.p1Lime))
                            .shadow(color: Color.p1Lime.opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: isBiggestWin ? [V4.gold.opacity(0.10), V4.panelBot]
                                         : [V4.rowTop, V4.panelBot],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(isBiggestWin ? V4.gold.opacity(0.5) : V4.line, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if isBiggestWin && !isLocked {
                Text("BIGGEST WIN")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(V4.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(V4.gold))
                    .offset(x: -14, y: -8)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { isLocked ? onTrack() : onTap() }
    }

    private var crests: some View {
        ZStack(alignment: .leading) {
            // No second portrait on a field event: there is no opponent, and
            // stacking a placeholder shield behind the golfer invented one.
            if !isFieldEvent {
                TeamLogo(sport: pick.sport, team: other, size: .small)
                    .frame(width: 35, height: 35)
                    .background(Circle().fill(V4.panelBot))
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(V4.line, lineWidth: 1))
                    .offset(x: 23)
            }
            TeamLogo(sport: pick.sport, team: called, size: .small)
                .frame(width: 40, height: 40)
                .background(Circle().fill(V4.panelBot))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.p1Lime.opacity(0.85), lineWidth: 1.5))
                .shadow(color: Color.p1Lime.opacity(0.4), radius: 6)
        }
        .frame(width: isFieldEvent ? 43 : 63, height: 42, alignment: .leading)
        .blur(radius: isLocked ? 6 : 0)
    }

    private var metaLine: String {
        let time = pick.startTimeDisplay.map { " · \($0)" } ?? ""
        if isLocked { return "\(pick.league.uppercased())\(time) · PREMIUM" }
        // "TO WIN THE BMW CHAMPIONSHIP" rather than "vs BMW Championship".
        if isFieldEvent { return "TO WIN · \(other.uppercased())\(time)" }
        return "vs \(teamShortName(other, sport: pick.sport)) · \(pick.league.uppercased())\(time)"
    }
}

// MARK: - Locked teaser

struct P1V4LockMore: View {
    let hidden: [Pick]
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(spacing: 3) {
                    ForEach(hidden.prefix(3)) { p in
                        HStack {
                            Text("\(p.shortDisplayPick) · \(p.league)")
                            Spacer(minLength: 8)
                            Text("\(Int(p.probability.rounded()))%")
                        }
                        .font(.anton(12))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    }
                }
                .blur(radius: 5)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("🔒 \(hidden.count) MORE PICKS\nCALLED TODAY")
                    .font(.anton(11))
                    .tracking(0.44)
                    .foregroundStyle(V4.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(Color.p1Lime))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.p1Lime.opacity(0.03)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.p1Lime.opacity(0.4),
                                  style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live card

struct P1V4LiveCard: View {
    let pick: Pick
    let score: LiveScore
    var tint: Color

    private var calledIsHome: Bool {
        pick.pick.caseInsensitiveCompare(pick.homeTeam) == .orderedSame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(v4Emoji(pick.sport)) \(pick.league.uppercased()) · YOUR PICK: \(pick.shortDisplayPick.uppercased()) · \(Int(pick.probability.rounded()))%")
                    .lineLimit(1).minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                if let q = score.quarter ?? score.status {
                    Text(q.uppercased()).lineLimit(1)
                }
            }
            .font(.mono(8, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(V4.mute)

            HStack {
                team(score.awayTeam, isPick: !calledIsHome)
                Spacer(minLength: 8)
                VStack(spacing: 4) {
                    Text("\(score.awayScore ?? 0)–\(score.homeScore ?? 0)")
                        .font(.anton(40))
                        .foregroundStyle(.white)
                        .fixedSize()
                    if let q = score.quarter, !q.isEmpty {
                        Text(q.uppercased())
                            .font(.mono(9, weight: .bold))
                            .tracking(0.9)
                            .foregroundStyle(V4.hotSoft)
                    }
                }
                Spacer(minLength: 8)
                team(score.homeTeam, isPick: calledIsHome)
            }
            .padding(.top, 16)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#171B22"), V4.panelBot],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [tint.opacity(0.08), .clear],
                                             startPoint: .topLeading, endPoint: .center))
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    private func team(_ name: String, isPick: Bool) -> some View {
        VStack(spacing: 3) {
            Text(teamShortName(name, sport: pick.sport).uppercased())
                .font(.anton(21))
                .foregroundStyle(isPick ? Color.p1Lime : .white)
                .shadow(color: isPick ? Color.p1Lime.opacity(0.5) : .clear, radius: 9)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text((isPick ? "▸ " : "") + name.uppercased())
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(V4.mute)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(width: 82)
    }
}

// MARK: - Result row

struct P1V4ResultRow: View {
    let pick: Pick
    var isHighlight: Bool = false

    private var scoreLine: String? {
        guard let h = pick.homeScore, let a = pick.awayScore else { return nil }
        return "\(max(h, a))–\(min(h, a))"
    }

    var body: some View {
        HStack(spacing: 11) {
            Text(v4Emoji(pick.sport))
                .font(.system(size: 19))
                .shadow(color: V4.glow(pick.sport).opacity(0.7), radius: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(pick.shortDisplayPick.uppercased())
                    .font(.anton(13.5))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                // The score is stated plainly. Prefixing it with "WON" printed
                // "WON 108-87" on rows the chip beside it marks as a LOSS.
                Text([scoreLine,
                      "CALLED AT \(Int(pick.probability.rounded()))%",
                      pick.league.uppercased()].compactMap { $0 }.joined(separator: " · "))
                    .font(.mono(8.5, weight: .bold))
                    .tracking(0.43)
                    .foregroundStyle(V4.mute)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(pick.isWin ? "WIN" : "LOSS")
                .font(.anton(13))
                .tracking(0.52)
                .foregroundStyle(pick.isWin ? V4.win : V4.hotSoft)
                .padding(.horizontal, 13).padding(.vertical, 7)
                .background(Capsule().fill((pick.isWin ? V4.win : V4.hot).opacity(0.11)))
                .overlay(Capsule().strokeBorder((pick.isWin ? V4.win : V4.hot).opacity(0.45), lineWidth: 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: isHighlight ? [V4.gold.opacity(0.08), V4.panelBot] : [V4.rowTop, V4.panelBot],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isHighlight ? V4.gold.opacity(0.45) : V4.line, lineWidth: 1)
        )
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }
}

// MARK: - Your-picks row

/// One row of the user's own slate.
///
/// The results row could not be reused: this list mixes picks that have not
/// played yet with settled ones, and when the user tracked a stake the row
/// has to say what that stake stands to return, or actually returned. A
/// starred-but-never-tracked pick simply has no money line.
struct P1V4YourRow: View {
    let pick: Pick
    /// nil when the pick was starred rather than tracked with a stake.
    let bet: UserBet?

    private var odds: Double? {
        let o = bet?.oddsAtBet ?? pick.marketOdds ?? pick.impliedOddsForPayout
        return (o ?? 0) > 1 ? o : nil
    }

    private func money(_ v: Double) -> String { "$\(Int(v.rounded()))" }

    /// What the stake is worth. Forward-looking while the game is pending,
    /// settled profit or loss afterwards. Nil when there is no stake to
    /// talk about, which is most starred picks.
    private var stakeLine: String? {
        guard let stake = bet?.stake, stake > 0, let odds else { return nil }
        if pick.isPending { return "\(money(stake)) → \(money(stake * odds))" }
        return pick.isWin ? "+\(money(stake * (odds - 1)))" : "−\(money(stake))"
    }

    private var chip: (String, Color) {
        if pick.isPending { return ("TO PLAY", V4.gold) }
        return pick.isWin ? ("WIN", V4.win) : ("LOSS", V4.hot)
    }

    var body: some View {
        HStack(spacing: 11) {
            Text(v4Emoji(pick.sport))
                .font(.system(size: 19))
                .shadow(color: V4.glow(pick.sport).opacity(0.7), radius: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(pick.shortDisplayPick.uppercased())
                    .font(.anton(13.5))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text([pick.league.uppercased(),
                      "CALLED AT \(Int(pick.probability.rounded()))%",
                      bet == nil ? "STARRED" : "TRACKED"].joined(separator: " · "))
                    .font(.mono(8.5, weight: .bold))
                    .tracking(0.43)
                    .foregroundStyle(V4.mute)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(chip.0)
                    .font(.anton(12))
                    .tracking(0.52)
                    .foregroundStyle(chip.1)
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Capsule().fill(chip.1.opacity(0.11)))
                    .overlay(Capsule().strokeBorder(chip.1.opacity(0.45), lineWidth: 1))
                if let stakeLine {
                    Text(stakeLine)
                        .font(.mono(10, weight: .bold))
                        .foregroundStyle(pick.isPending ? Color.p1Lime
                                         : (pick.isWin ? V4.win : V4.hotSoft))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [V4.rowTop, V4.panelBot],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(V4.line, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 22)
        .padding(.top, 10)
    }
}

// MARK: - Pay bar

struct P1V4PayBar: View {
    let perDay: String
    var sports: Int
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("GO PREMIUM · \(perDay)/DAY")
                        .font(.anton(16))
                        .tracking(0.32)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    Text("→").font(.anton(16))
                }
                .foregroundStyle(V4.ink)

                Text("\(sports) SPORTS · ALL MARKETS · PUBLIC LEDGER")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(0.36)
                    .foregroundStyle(V4.ink.opacity(0.65))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [Color.p1Lime, Color(hex: "#9FDC16")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .shadow(color: Color.p1Lime.opacity(0.35), radius: 25, y: 18)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
    }
}

// MARK: - Screen

struct Pick1HomeV4: View {
    @ObservedObject var vm: PicksViewModel
    @EnvironmentObject private var subs: SubscriptionManager
    /// The two stores behind "Your Picks": tracked bets (with a stake and
    /// locked-in odds) and starred picks (no money attached).
    @StateObject private var betTracker = BetTracker.shared
    @EnvironmentObject private var favorites: FavoritesStore

    var onSelectPick: (Pick) -> Void = { _ in }
    /// Opens the pick with its bet drawer already expanded.
    var onTrackPick: (Pick) -> Void = { _ in }
    var onUpgrade: () -> Void = {}
    /// Space owned by whatever sits under this screen. The production shell
    /// floats a nav pill over the bottom, so both the scroll content and the
    /// sticky paybar have to clear it; standalone the default 0 is right.
    var bottomInset: CGFloat = 0

    @State private var tab: P1V4Tab = .tonight
    @State private var selectedSport: String?

    /// Real entitlement, with the same DEBUG-only `-forcePro` override the
    /// production home carries so the Pro surfaces stay reviewable on the
    /// simulator. Compiled out of Release, so it can never grant Pro to a
    /// real user.
    private var isPro: Bool {
        #if DEBUG
        // `-forceFree` is checked first so it wins on a comped account, which
        // is the only way to actually see the locked state on this simulator.
        if CommandLine.arguments.contains("-forceFree") { return false }
        if CommandLine.arguments.contains("-forcePro") { return true }
        #endif
        return subs.isPro
    }

    /// The free tier, taken from the view model rather than redefined here:
    /// one pick per sport, the highest-confidence call of that sport. v4
    /// previously showed free users the hero plus two more, which was more
    /// generous than production and would have handed away the paid product.
    private var freeIds: Set<UUID> { Set(vm.freeTierTodayPicks.map(\.id)) }
    private func locked(_ p: Pick) -> Bool { !isPro && !freeIds.contains(p.id) }

    /// Same discipline as v2: one switch for everything with no table behind
    /// it. The coin pill, the "back it" chip and the backer count are the only
    /// invented values on this screen.
    static let showUnbacked = false

    // MARK: Data

    /// Sports with a slate today, strongest first, so the orb row opens on
    /// the day's real edge instead of a fixed order.
    private var sports: [String] {
        Dictionary(grouping: vm.todayPicks.filter { P1_SPORTS.contains($0.sport) },
                   by: \.sport)
            .map { (sport: $0.key, best: $0.value.map(\.probability).max() ?? 0) }
            .sorted { $0.best > $1.best }
            .map(\.sport)
    }
    private var activeSport: String? { selectedSport.flatMap { sports.contains($0) ? $0 : nil } ?? sports.first }
    private var sportPicks: [Pick] {
        guard let s = activeSport else { return [] }
        return vm.todayPicks.filter { $0.sport == s }.sorted { $0.probability > $1.probability }
    }

    /// Today's board, restricted to the ten covered sports. Used anywhere the
    /// screen counts or scans picks rather than reading the selected sport.
    private var coveredToday: [Pick] { vm.todayPicks.filter { P1_SPORTS.contains($0.sport) } }
    private var hero: Pick? { sportPicks.first }
    private var rest: [Pick] { Array(sportPicks.dropFirst()) }

    /// Within the selected sport the hero IS the free pick, so everything
    /// under it is locked for a free user. Rows still render, blurred, because
    /// a visible locked slate converts better than a hidden one.
    /// The unlocked call on today's board that returns the most on the
    /// reference stake. Nil when there is nothing to compare, or when the
    /// whole board pays about the same, in which case crowning one card
    /// would be noise dressed as a signal.
    private var biggestWinId: UUID? {
        let board = visibleRest
        #if DEBUG
        // The badge needs a board of at least two to mean anything, and a
        // thin slate often has one. Review hook, like the others here.
        if CommandLine.arguments.contains("-forceBiggestWin") { return board.first?.id }
        #endif
        guard board.count > 1,
              let top = board.max(by: { $0.decimalOdds < $1.decimalOdds }),
              let low = board.min(by: { $0.decimalOdds < $1.decimalOdds }),
              top.decimalOdds >= low.decimalOdds * 1.15
        else { return nil }
        return top.id
    }

    private var visibleRest: [Pick] { rest.filter { !locked($0) } }
    private var hiddenRest: [Pick] { rest.filter { locked($0) } }

    private var liveNow: [(pick: Pick, score: LiveScore)] {
        let live = vm.liveScores.filter(\.isLive)
        return coveredToday.compactMap { p in
            guard !locked(p) else { return nil }
            guard let gid = p.gameId, let s = live.first(where: { $0.gameId == gid }) else { return nil }
            return (p, s)
        }
    }

    private var settled: [Pick] {
        vm.historyPicks.filter { !$0.isPending }
            .sorted { ($0.gameDateValue ?? .distantPast) > ($1.gameDateValue ?? .distantPast) }
    }

    /// Wins in the last 7 days the user could not have seen.
    ///
    /// Counting every win was wrong and produced "you missed 55 winning picks
    /// this week", which is both false and self-evidently so. A free user gets
    /// the top call of each sport each day, so what they actually missed is
    /// the settled wins that were NOT their sport's best call on that day.
    private var missedWins: Int {
        guard !isPro else { return 0 }
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        let recent = settled.filter { ($0.gameDateValue ?? .distantPast) >= weekAgo }
        // Rebuild what was free on each day: top pick per (day, sport).
        var freeThatDay = Set<UUID>()
        for (_, dayPicks) in Dictionary(grouping: recent, by: \.gameDate) {
            for (_, sportPicks) in Dictionary(grouping: dayPicks, by: \.sport) {
                if let top = sportPicks.max(by: { $0.probability < $1.probability }) {
                    freeThatDay.insert(top.id)
                }
            }
        }
        return recent.filter { $0.isWin && !freeThatDay.contains($0.id) }.count
    }

    private var perDay: String {
        guard let m = subs.products.first(where: { $0.id.hasSuffix("monthly") }) else { return "$1.33" }
        return (m.price / 30).formatted(m.priceFormatStyle)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            RadialGradient(colors: [V4.lift, V4.ink],
                           center: .init(x: 0.5, y: -0.06), startRadius: 0, endRadius: 540)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    P1V4TopBar(coins: Self.showUnbacked ? 2_450 : nil)

                    P1V4Segment(selection: $tab)

                    switch tab {
                    case .tonight: tonight
                    case .live:    live
                    case .yours:   yours
                    case .results: results
                    }

                    if tab != .tonight {
                        Color.clear.frame(height: 24 + bottomInset)
                    } else {
                        Color.clear.frame(height: 24)
                    }
                }
                .padding(.top, 10)
            }

            // Sticky conversion bar, pinned rather than scrolled away. Free
            // users only.
            if !isPro && tab == .tonight && !coveredToday.isEmpty {
                VStack {
                    Spacer()
                    P1V4PayBar(perDay: perDay, sports: max(sports.count, 1), onTap: onUpgrade)
                        .padding(.bottom, 12 + bottomInset)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { if subs.products.isEmpty { await subs.reloadProducts() } }
        .task { if !betTracker.loaded { await betTracker.load() } }
    }

    // MARK: Tonight

    @ViewBuilder private var tonight: some View {
        if !sports.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(sports, id: \.self) { s in
                        P1V4Orb(sport: s, isOn: s == activeSport) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedSport = s
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 6)
            }
        }

        if let hero {
            P1V4Hero(pick: hero,
                     showUnbacked: Self.showUnbacked,
                     backers: 312) { onSelectPick(hero) }
        }

        if !rest.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                (
                    Text("TODAY'S ").foregroundStyle(.white)
                    + Text("GAMES").foregroundStyle(Color.p1Lime)
                )
                .font(.anton(18))
                Spacer(minLength: 8)
                Text("ALL CALLED BY 6 AM")
                    .font(.mono(9, weight: .bold))
                    .tracking(0.72)
                    .foregroundStyle(V4.mute)
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)

            VStack(spacing: 12) {
                ForEach(visibleRest) { p in
                    P1V4GameRow(pick: p,
                                isBiggestWin: p.id == biggestWinId,
                                onTap: { onSelectPick(p) },
                                onTrack: { onTrackPick(p) })
                }
                // The first two locked calls stay on screen, blurred, so the
                // free user can see there is more rather than being told.
                ForEach(hiddenRest.prefix(2)) { p in
                    P1V4GameRow(pick: p, isLocked: true, onTap: onUpgrade)
                }
                if hiddenRest.count > 2 {
                    P1V4LockMore(hidden: Array(hiddenRest.dropFirst(2)), onTap: onUpgrade)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
        }

        if !isPro, missedWins > 0 {
            HStack(spacing: 12) {
                Text("😬").font(.system(size: 20))
                (
                    Text("You missed ").foregroundStyle(.white)
                    + Text("\(missedWins) winning picks").foregroundStyle(V4.hotSoft)
                    + Text(" this week. Premium saw them all.").foregroundStyle(.white)
                )
                .font(.archivoNarrow(12, weight: .semibold))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("Unlock →").font(.anton(12)).foregroundStyle(Color.p1Lime).fixedSize()
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(
                    LinearGradient(colors: [V4.hot.opacity(0.14), V4.hot.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(V4.hot.opacity(0.45), lineWidth: 1))
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .onTapGesture { onUpgrade() }
        }

        if coveredToday.isEmpty && !vm.isLoading {
            emptyState("No slate today", "The model publishes the day's board each morning.")
        }

        // Clearance for the sticky paybar and, in the shell, the nav pill.
        Color.clear.frame(height: (!isPro && !coveredToday.isEmpty ? 96 : 12) + bottomInset)
    }

    // MARK: Live

    @ViewBuilder private var live: some View {
        HStack(spacing: 6) {
            Circle().fill(V4.hot).frame(width: 7, height: 7)
            Text("\(liveNow.count) PICK\(liveNow.count == 1 ? "" : "S") LIVE NOW")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(V4.hotSoft)
        }
        .padding(.horizontal, 13).padding(.vertical, 6)
        .background(Capsule().fill(V4.hot.opacity(0.12)))
        .overlay(Capsule().strokeBorder(V4.hot.opacity(0.5), lineWidth: 1))
        .frame(maxWidth: .infinity)
        .padding(.top, 18)

        if liveNow.isEmpty {
            emptyState("Nothing in play", "Live scores appear here once one of today's calls kicks off.")
        } else {
            ForEach(liveNow, id: \.score.id) { item in
                P1V4LiveCard(pick: item.pick, score: item.score, tint: V4.glow(item.pick.sport))
            }
        }
    }

    // MARK: Results

    // MARK: Your picks

    /// Every pick the user has a stake in, one way or the other: the ones
    /// they tracked and the ones they starred, newest first. Resolved against
    /// today, yesterday and history so a pick that has not migrated into
    /// `historyPicks` yet still shows up.
    private var mine: [(pick: Pick, bet: UserBet?)] {
        var byId: [UUID: Pick] = [:]
        for p in vm.historyPicks   { byId[p.id] = p }
        for p in vm.yesterdayPicks { byId[p.id] = p }
        for p in vm.todayPicks     { byId[p.id] = p }

        let ids = Set(betTracker.bets.keys).union(favorites.ids)
        return ids.compactMap { id -> (pick: Pick, bet: UserBet?)? in
            guard let p = byId[id] else { return nil }
            return (p, betTracker.bets[id])
        }
        // Still-to-play first — those are the ones the user can still act
        // on — then the settled ones newest first.
        .sorted {
            if $0.pick.isPending != $1.pick.isPending { return $0.pick.isPending }
            return $0.pick.gameDate > $1.pick.gameDate
        }
    }

    @ViewBuilder private var yours: some View {
        let rows = mine
        let settledMine = rows.filter { !$0.pick.isPending }
        let wins = settledMine.filter { $0.pick.isWin }.count
        let losses = settledMine.filter { $0.pick.isLoss }.count
        let summary = betTracker.summary(picks: vm.historyPicks + vm.yesterdayPicks + vm.todayPicks)

        HStack(spacing: 10) {
            resultBox("\(rows.count)", "On your slate")
            resultBox("\(wins)-\(losses)", "Your record")
            // Only claim a P&L when real stakes were entered. Otherwise show
            // the hit rate, which is true whether or not money was involved.
            if let roi = summary.roiPct, summary.staked > 0 {
                resultBox("\(roi >= 0 ? "+" : "")\(Int(roi.rounded()))%", "Your ROI")
            } else {
                resultBox(settledMine.isEmpty ? "—" : "\(Int((Double(wins) / Double(max(settledMine.count, 1)) * 100).rounded()))%",
                          "Hit rate")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)

        if rows.isEmpty {
            emptyState("Nothing on your slate yet",
                       "Track a call from Tonight, or tap the star on any pick, and it lands here with its result.")
        } else {
            ForEach(rows, id: \.pick.id) { row in
                Button { onSelectPick(row.pick) } label: {
                    P1V4YourRow(pick: row.pick, bet: row.bet)
                }
                .buttonStyle(.plain)
            }
            if summary.staked > 0 {
                Text("P&L COUNTS ONLY THE BETS YOU ENTERED A STAKE FOR")
                    .font(.mono(8, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(V4.mute)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
            }
        }
    }

    // MARK: Results

    @ViewBuilder private var results: some View {
        HStack(spacing: 10) {
            resultBox("\(vm.totalWins)/\(settled.count)", "Picks won")
            resultBox("\(Int(vm.winRate.rounded()))%", "Hit rate")
            resultBox("🔥 \(vm.currentStreak)", "Win streak")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)

        if settled.isEmpty {
            emptyState("No settled calls yet", "Every pick is logged before kickoff and graded here once it lands.")
        } else {
            // Tappable. These were static rows, so the public record — the
            // thing the whole product is sold on — was the one list in the
            // app you could not open. Every other pick surface opens its
            // detail; this one now does too.
            ForEach(Array(settled.prefix(20).enumerated()), id: \.element.id) { i, p in
                Button { onSelectPick(p) } label: {
                    P1V4ResultRow(pick: p, isHighlight: i == 0 && p.isWin)
                }
                .buttonStyle(.plain)
            }
            Text("EVERY CALL LOGGED BEFORE KICKOFF · WINS AND LOSSES · FOREVER")
                .font(.mono(8, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(V4.mute)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, 16)
        }
    }

    private func resultBox(_ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.anton(26))
                .foregroundStyle(Color.p1Lime)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label.uppercased())
                .font(.archivoNarrow(8, weight: .bold))
                .tracking(0.96)
                .foregroundStyle(V4.mute)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [V4.rowTop, V4.panelBot],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(V4.line, lineWidth: 1))
    }

    private func emptyState(_ title: String, _ body: String) -> some View {
        VStack(spacing: 8) {
            Text(title.uppercased())
                .font(.anton(18))
                .foregroundStyle(.white)
            Text(body)
                .font(.archivo(13))
                .foregroundStyle(V4.mute)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 34).padding(.vertical, 40)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(V4.line, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        )
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }
}

#if DEBUG
/// `-showHomeV4`
struct Pick1HomeV4DebugHost: View {
    @StateObject private var vm = PicksViewModel()
    @State private var detailPick: Pick?
    @State private var openBetDrawer = false
    @State private var showPaywall = false

    var body: some View {
        Pick1HomeV4(vm: vm,
                    onSelectPick: { openBetDrawer = false; detailPick = $0 },
                    onTrackPick: { openBetDrawer = true; detailPick = $0 },
                    onUpgrade: { showPaywall = true })
            .task { await vm.loadAll() }
            .fullScreenCover(item: $detailPick) { p in
                Pick1DetailV2(pick: p,
                              onBack: { detailPick = nil },
                              onUnlock: { detailPick = nil; showPaywall = true },
                              startWithBetDrawer: openBetDrawer)
            }
            .fullScreenCover(isPresented: $showPaywall) {
                Pick1PaywallV2(vm: vm, onClose: { showPaywall = false })
            }
    }
}
#endif
