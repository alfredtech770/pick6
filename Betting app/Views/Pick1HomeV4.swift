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
    static let ink = Color(hex: "#1A1A1C")
    static let lift = Color(hex: "#1A1A1C")
    static let panelTop = Color(hex: "#303032")
    static let panelBot = Color(hex: "#222224")
    static let rowTop = Color(hex: "#262628")
    static let line = Color(hex: "#454548").opacity(0.6)
    static let mute = Color(hex: "#A5A5AA")
    static let ink2 = Color(hex: "#DADADD")
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
        case "afl":        return Color(hex: "#D6E04A")
        case "rugby":      return Color(hex: "#5BC8FF")
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


/// The twelve sports Pick1 covers, in the order Ethan set them. This is the
/// authority: a sport not on this list is not shown, whatever the pipeline
/// happens to have generated.
///
/// Adding a sport here is only half the job. The pipeline keeps its own
/// `APP_SPORTS` set, and anything missing from THAT one is run last, after
/// the daily budget has already been spent on the visible sports. Rugby sat
/// in that gap and produced zero picks in the life of the product.
let P1_SPORTS: [String] = [
    "basketball", "football", "soccer", "hockey", "baseball",
    "f1", "tennis",
]

/// Display names, also Ethan's: "Fight" not MMA, "Race" not Racing or F1.
func v4Name(_ sport: String) -> String {
    if sport == Pick1HomeV4.allSports { return "All" }
    switch sport {
    case "basketball": return "Basketball"; case "baseball": return "Baseball"
    case "hockey": return "Hockey";         case "football": return "Football"
    case "soccer": return "Soccer";         case "combat": return "Fight"
    case "f1": return "Race";               case "golf": return "Golf"
    case "cricket": return "Cricket";       case "tennis": return "Tennis"
    case "rugby": return "Rugby"
    // "Aussie" alone named the nationality, not the sport. The orb label is
    // one line inside 62pt, so the full "Australian Football" cannot be set
    // here; this is the longest form that still reads at the rail's 8.5pt.
    case "afl": return "Aus Football"
    default: return sport.capitalized
    }
}

// MARK: - Top bar

struct P1V4TopBar: View {
    var coins: Int?
    var onCoinTap: () -> Void = {}
    /// Profile lives here now. The floating bottom nav is gone, so this is
    /// the only route to it, which is also why it is a labelled target and
    /// not a bare avatar.
    var onProfile: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            // The canonical wordmark, the same component the splash draws,
            // rather than a second lockup invented for this bar. It sits
            // hard against the leading edge: a 34pt clear spacer used to
            // precede it, left over from when the mark was centred and that
            // spacer balanced the avatar opposite. Once the mark moved left
            // the spacer had nothing to balance and just indented the brand.
            VStack(alignment: .leading, spacing: 3) {
                Pick1Wordmark(size: 28)
                Text("PREDICT. COMPARE. BET.")
                    .font(.archivoNarrow(9, weight: .bold))
                    .tracking(1.3).foregroundStyle(V4.ink2)
            }

            Spacer(minLength: 8)

            // The coin pill, when it returns, belongs beside the profile
            // rather than in front of the brand.
            if let coins {
                Button(action: onCoinTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(coins.formatted())
                            .font(.mono(11, weight: .bold))
                    }
                    .foregroundStyle(V4.gold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(V4.gold.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(V4.gold.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
            }

            Button(action: onProfile) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(V4.ink2)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [V4.panelTop, V4.panelBot],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .overlay(Circle().strokeBorder(V4.line, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Profile")
        }
        .padding(.leading, 18)
        .padding(.trailing, 22)
        .padding(.top, 8)
    }
}

// MARK: - Segment

enum P1V4Tab: String, CaseIterable, Identifiable {
    case tonight, live, yours, results
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tonight: return "Picks"
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
                            Circle().fill(Color.p1Primary).frame(width: 5, height: 5)
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
                .buttonStyle(PressableButtonStyle())
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
    /// False for a sport with nothing on the board. It still appears, because
    /// the ten sports are the product's coverage claim, but it reads as quiet
    /// rather than pretending to hold something.
    var hasPicks: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Group {
                    if sport == Pick1HomeV4.allSports {
                        // Not a sport, so not a sport mark. A grid reads as
                        // "everything at once" without implying a discipline.
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(isOn ? Color.p1Primary : V4.ink2)
                            // Same reach as P1SportMark's (size * 0.32), so
                            // ALL does not glow harder than the sports next
                            // to it. The glyph is square, so an oversized
                            // shadow on it reads as a boxy halo.
                            .shadow(color: isOn ? Color.p1Primary.opacity(0.55) : .clear,
                                    radius: 21 * 0.32)
                    } else {
                        P1SportMark(sport: sport, size: 23, glowing: isOn, active: isOn)
                    }
                }
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [V4.panelTop, V4.panelBot],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .overlay(Circle().strokeBorder(isOn ? Color.p1Primary : V4.line, lineWidth: 1.5))
                    .opacity(hasPicks ? 1 : 0.45)
                    // Radius 13 put the halo's reach at roughly 3pt (the
                    // 1.12 scale) plus ~26pt of falloff, well past the rail's
                    // 18pt of headroom, so the selected orb's glow was sliced
                    // off flat along the top edge.
                    .shadow(color: isOn ? Color.p1Primary.opacity(0.45) : .clear, radius: 9)
                    .scaleEffect(isOn ? 1.12 : 1)

                Text(v4Name(sport).uppercased())
                    .font(.archivoNarrow(8.5, weight: .bold))
                    .tracking(0.85)
                    .foregroundStyle(isOn ? Color.p1Primary : V4.mute)
                    .opacity(hasPicks ? 1 : 0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 6)

                Circle()
                    .fill(Color.p1Primary)
                    .frame(width: 5, height: 5)
                    .opacity(isOn ? 1 : 0)
                    .padding(.top, 4)
            }
            .frame(width: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(v4Name(sport))
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Factor bar

struct P1V4FactorRow: View {
    /// SF Symbol name, derived from `label` by `P1Symbol.factor(_:)`. It used
    /// to be an emoji picked by row index, which meant the glyph never had
    /// anything to do with the row it sat on.
    let icon: String
    let label: String
    let note: String
    let value: Int
    let colors: [Color]
    @State private var filled = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colors.first ?? Color.p1Lime)
                .frame(width: 18)
                .accessibilityHidden(true)

            // Label above, value below. They used to share one 148pt line
            // with the value in brackets, which produced nested parentheses
            // ("Market prior (1.43 at DK (~66% no-vig))") and truncated
            // mid-word on anything real. Two lines cost nothing here and the
            // value is the part a reader is checking.
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.archivoNarrow(11.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.75)
                if !note.isEmpty {
                    Text(note)
                        .font(.mono(9, weight: .medium))
                        .foregroundStyle(V4.mute)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .frame(width: 152, alignment: .leading)

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
    /// Required when the ALL board is selected: without the selected sport orb
    /// as context, the card must name its own sport.
    var showSport: Bool = false
    /// Whether this game is already starred. Drives the FOLLOW pill.
    var isStarred: Bool = false
    var onTap: () -> Void = {}
    /// The star, on the card itself. Added 2026-09-17: 74% of subscribers
    /// never favourited a game, and conversion runs 15% for them against
    /// 34% for people with three or more actions. Favouriting used to live
    /// only behind the detail screen's star; this is the first surface every
    /// new user lands on, so the action now sits where the eyes already are.
    var onStar: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .black))
                    Text(showSport
                         ? "TODAY'S #1 PICK · \(v4Name(pick.sport).uppercased())"
                         : "TODAY'S #1 PICK")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(2.0)
                }
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
                        P1V4FactorRow(icon: P1Symbol.factor(f.label),
                                      label: f.label,
                                      note: f.value,
                                      value: f.strength,
                                      colors: V4.barGradients[i % V4.barGradients.count])
                    }
                }

                // FOLLOW pill. A plain tap gesture rather than a nested
                // Button: a Button inside a .plain Button's label loses its
                // tap to the parent on iOS more often than not, and this is
                // the one tap on the screen that has to land every time. The
                // copy says what the star DOES, because a bare star on a
                // sports card reads as "rate this" to a new user.
                HStack(spacing: 6) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .font(.system(size: 11, weight: .bold))
                    Text(isStarred ? "FOLLOWING · ALERTS ON" : "FOLLOW THIS GAME · GET ALERTS")
                        .font(.archivoNarrow(10, weight: .bold))
                        .tracking(1.4)
                }
                .foregroundStyle(isStarred ? V4.ink : Color.p1Lime)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(isStarred ? Color.p1Lime : Color.p1Lime.opacity(0.10)))
                .overlay(Capsule().strokeBorder(Color.p1Lime.opacity(isStarred ? 0 : 0.45), lineWidth: 1))
                .padding(.top, 18)
                .contentShape(Capsule())
                .onTapGesture(perform: onStar)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isStarred ? "Following this game" : "Follow this game and get alerts")
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
                    .strokeBorder(V4.line, lineWidth: 1)
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
        .buttonStyle(PressableButtonStyle())
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
    /// Show the discipline on mixed-sport boards. League alone is not enough:
    /// casual users should not have to know that ATP means tennis or MLS means
    /// soccer to understand the card.
    var showSport: Bool = false
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

                    HStack(spacing: 5) {
                        P1SportMark(sport: pick.sport, size: 10)
                        Text(metaLine)
                            .font(.mono(9, weight: .bold))
                            .tracking(0.54)
                            .foregroundStyle(V4.mute)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
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
                        Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                        Text("UNLOCK")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(V4.ink)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(Color.p1Lime))
                } else if pick.isPending {
                    Button(action: onTrack) {
                        Text("SEE PARTNERS")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.1)
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .background(Capsule().fill(Color.p1Primary))
                            .shadow(color: Color.p1Primary.opacity(0.15), radius: 10, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())
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

    /// A time for today's games, a DATE for anything further out.
    ///
    /// F1 and golf are generated days before the event and merged into the
    /// same board as today's slate, so a Grand Prix eleven days away was
    /// rendering as "9 AM" underneath the heading "TODAY'S GAMES". A bare
    /// time reads as today; for a future event that is simply false, and it
    /// is the kind of false a user notices the morning nothing happens.
    private var whenLabel: String {
        let time = pick.startTimeDisplay.map { " · \($0)" } ?? ""
        guard !pick.isToday, let d = pick.gameDateValue else { return time }
        let day = d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)
                                .locale(LocalizationManager.shared.displayLocale))
        return " · \(day.uppercased())"
    }

    private var metaLine: String {
        let time = whenLabel
        let sport = showSport ? "\(v4Name(pick.sport).uppercased()) · " : ""
        if isLocked { return "\(sport)\(pick.league.uppercased())\(time) · PREMIUM" }
        // "TO WIN THE BMW CHAMPIONSHIP" rather than "vs BMW Championship".
        if isFieldEvent { return "\(sport)TO WIN · \(other.uppercased())\(time)" }
        return "\(sport)vs \(teamShortName(other, sport: pick.sport)) · \(pick.league.uppercased())\(time)"
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

                Text("\(Image(systemName: "lock.fill"))  \(hidden.count) MORE PICKS\nCALLED TODAY")
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
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Live card

struct P1V4LiveCard: View {
    let pick: Pick
    let score: LiveScore
    var tint: Color
    /// A free user sees the game and the live score; what is withheld is the
    /// AI's call on it, which is the thing being sold.
    var isLocked: Bool = false

    private var calledIsHome: Bool {
        pick.pick.caseInsensitiveCompare(pick.homeTeam) == .orderedSame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(isLocked
                     ? "\(pick.league.uppercased()) · PICK LOCKED"
                     : "\(pick.league.uppercased()) · YOUR PICK: \(pick.shortDisplayPick.uppercased()) · \(Int(pick.probability.rounded()))%")
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
            Text((isPick && !isLocked ? "▸ " : "") + name.uppercased())
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
    /// Wins AND losses are shareable. A record you can only pass on when it
    /// flatters you is not a record, and publishing the misses is the one
    /// claim this product actually makes about itself.
    var onShare: (() -> Void)? = nil

    private var scoreLine: String? {
        guard let h = pick.homeScore, let a = pick.awayScore else { return nil }
        return "\(max(h, a))–\(min(h, a))"
    }

    /// Hypothetical payout including stake, using captured prices only.
    private var returnLine: String {
        guard !pick.isPending, let quote = P1BookQuote.forPick(pick) else { return "—" }
        return "$" + String(Int((pick.isWin ? quote.odds * 100 : 0).rounded()))
    }

    private var verdict: (label: String, color: Color) {
        if pick.isPending { return ("AWAITING", V4.gold) }
        return pick.isWin ? ("WIN", V4.win) : ("LOSS", V4.hotSoft)
    }

    var body: some View {
        HStack(spacing: 11) {
            P1SportMark(sport: pick.sport, size: 18)

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

            // The MONEY is the headline and the verdict is the caption.
            // "WIN" in a capsule with the amount whispering underneath had
            // the hierarchy backwards: everyone already knows a green row
            // won, what they came to read is what it was worth. A stated
            // reference stake, not a suggestion — the app tracks calls, it
            // never asks anyone to place one.
            VStack(alignment: .trailing, spacing: 1) {
                Text(returnLine)
                    .font(.anton(22))
                    .foregroundStyle(verdict.color)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(verdict.label + (P1BookQuote.forPick(pick) == nil ? " · NO PRICE" : " · RETURN"))
                    .font(.archivoNarrow(8.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(V4.mute)
            }

            if let onShare {
                Button {
                    Haptics.tap()
                    onShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(V4.mute)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(V4.panelBot))
                        .overlay(Circle().strokeBorder(V4.line, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(pick.isWin ? "Share this win" : "Share this loss")
            }
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
            P1SportMark(sport: pick.sport, size: 18)

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
        .buttonStyle(PressableButtonStyle())
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
    var onProfile: () -> Void = {}
    var onUpgrade: () -> Void = {}
    /// Space owned by whatever sits under this screen. The production shell
    /// floats a nav pill over the bottom, so both the scroll content and the
    /// sticky paybar have to clear it; standalone the default 0 is right.
    var bottomInset: CGFloat = 0

    @State private var tab: P1V4Tab = .tonight
    @State private var selectedSport: String?
    @State private var resultSearch = ""
    /// The settled call being shared, win or loss.
    @State private var shareResult: Pick?
    @State private var bookSearch = ""
    @State private var bookPage: P1ExplorePage?
    @State private var selectedDay = P1BookDays.key()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collapsedLeagues = Set<String>()
    @State private var slipMessage: String?
    @State private var slipFeedback = 0
    @State private var isSlipPage: Bool = {
        #if DEBUG
        return CommandLine.arguments.contains("-showPickSlip")
        #else
        return false
        #endif
    }()
    @AppStorage("sportsbookSlipIDs") private var savedSlipIDs = ""

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

    /// One highest-confidence pick per league and calendar day, independent of the selected tab.
    private var freeIds: Set<UUID> {
        var unique: [UUID: Pick] = [:]
        for pick in coveredToday + vm.historyPicks + vm.yesterdayPicks { unique[pick.id] = pick }
        return Set(Dictionary(grouping: Array(unique.values), by: { $0.gameDate + "|" + $0.sport + "|" + $0.league.lowercased() })
            .values.compactMap { group in
                group.sorted {
                    if $0.probability != $1.probability { return $0.probability > $1.probability }
                    return $0.id.uuidString < $1.id.uuidString
                }.first?.id
            })
    }
    private func locked(_ p: Pick) -> Bool { !isPro && !freeIds.contains(p.id) }

    /// Same discipline as v2: one switch for everything with no table behind
    /// it. The coin pill, the "back it" chip and the backer count are the only
    /// invented values on this screen.
    static let showUnbacked = false

    // MARK: Data

    /// Sports with a slate today, strongest first, so the orb row opens on
    /// the day's real edge instead of a fixed order.
    /// Sports that have at least one call on the board, best first.
    private var stockedSports: [String] {
        Dictionary(grouping: vm.todayPicks.filter { P1_SPORTS.contains($0.sport) },
                   by: \.sport)
            .map { (sport: $0.key, best: $0.value.map(\.probability).max() ?? 0) }
            .sorted { $0.best > $1.best }
            .map(\.sport)
    }

    /// Sentinel for the "everything" orb. Not a sport, and deliberately not a
    /// value that could ever collide with one from the pipeline.
    static let allSports = "__all__"

    /// The rail: ALL first, then all ten, always.
    ///
    /// It used to list only the sports with picks, so on a normal day three
    /// or four of the ten simply did not exist in the UI. A user told the app
    /// covers ten sports counted five and concluded they were missing. Quiet
    /// sports now appear, drained and unglowing, and say why when tapped —
    /// which also stops the rail's length changing every morning.
    ///
    /// ALL leads it because the per-sport filter was mandatory: there was no
    /// way to see the day whole, and the default landed on whichever sport
    /// happened to hold the highest-confidence call, which for golf is a
    /// board of one.
    private var sports: [String] {
        let stocked = stockedSports
        return [Self.allSports] + stocked + P1_SPORTS.filter { !stocked.contains($0) }
    }

    private func hasPicks(_ sport: String) -> Bool {
        sport == Self.allSports ? !coveredToday.isEmpty : stockedSports.contains(sport)
    }
    private var activeSport: String? {
        selectedSport.flatMap { sports.contains($0) ? $0 : nil } ?? Self.allSports
    }
    private var sportPicks: [Pick] {
        guard let s = activeSport else { return [] }
        if s == Self.allSports {
            return coveredToday.sorted { $0.probability > $1.probability }
        }
        return vm.todayPicks.filter { $0.sport == s }.sorted { $0.probability > $1.probability }
    }

    /// Today's board, restricted to the ten covered sports. Used anywhere the
    /// screen counts or scans picks rather than reading the selected sport.
    private var coveredToday: [Pick] { vm.todayPicks.filter { P1_SPORTS.contains($0.sport) } }
    /// The headline call on whatever board is being looked at.
    ///
    /// For a PRO user that is the highest-confidence call, as it always was.
    /// For a FREE user it is the biggest RETURN, because the hero is the one
    /// call they get to see and confidence hands them the shortest price in
    /// the app: a 97% favourite at -10000 returns almost nothing and sells
    /// nothing. The board they are shown should be the one that makes them
    /// want tomorrow's.
    private var hero: Pick? {
        guard !isPro else { return sportPicks.first }
        return sportPicks.max(by: { $0.decimalOdds < $1.decimalOdds })
    }

    /// Everything except the hero. Matched by id rather than by dropping the
    /// first element, because for a free user the hero is no longer first.
    private var rest: [Pick] { sportPicks.filter { $0.id != hero?.id } }

    /// The whole day's board minus the hero, best first.
    private var boardRest: [Pick] {
        coveredToday
            .filter { $0.id != hero?.id }
            .sorted { $0.probability > $1.probability }
    }

    /// What actually fills the games list.
    ///
    /// A sport with exactly ONE call today leaves `rest` empty, and the games
    /// section used to be gated on that, so the page rendered a hero and then
    /// a wall of black. Golf is the standing case: one tournament pick, whose
    /// confidence is frequently the day's highest, which also makes it the
    /// DEFAULT sport. On 31 Aug the app opened on Scheffler at 95% and showed
    /// no games at all while eleven picks sat in the board behind it.
    ///
    /// Rather than hide the day, fall back to the rest of it, and say so in
    /// the heading so the list never silently means something other than what
    /// the selected sport implies.
    private var shownRest: [Pick] { rest.isEmpty ? boardRest : rest }
    private var restIsWholeBoard: Bool { rest.isEmpty && !boardRest.isEmpty }

    /// The line beside the games heading. Three cases, and the difference
    /// matters: a sport with nothing must not be described as having "one
    /// call", which is what a single condition here used to do the moment
    /// quiet sports became selectable.
    private var restMetaLine: String {
        guard restIsWholeBoard else { return "ALL CALLED BY 6 AM" }
        let name = v4Name(activeSport ?? "").uppercased()
        return sportPicks.isEmpty
            ? "NO \(name) CALLS TODAY"
            : "\(name) HAS ONE CALL TODAY"
    }

    /// Within the selected sport the hero IS the free pick, so everything
    /// under it is locked for a free user. Rows still render, blurred, because
    /// a visible locked slate converts better than a hidden one.
    /// The unlocked call on today's board that returns the most on the
    /// reference stake. Nil when there is nothing to compare, or when the
    /// whole board pays about the same, in which case crowning one card
    /// would be noise dressed as a signal.
    private var biggestWinId: UUID? {
        // MUST read `openBoard`, never `visibleRest`. `visibleRest` pins this
        // pick to the front, so reading it back here is a cycle: the property
        // asks for the ordering that is asking for it, and SwiftUI recurses
        // until the stack dies. It crashed on launch the first time.
        let board = openBoard
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

    /// The unlocked board in its natural order, best call first. The single
    /// source both the badge and the pinned ordering read.
    private var openBoard: [Pick] { shownRest.filter { !locked($0) } }

    /// The unlocked board, with the biggest payout pinned first.
    ///
    /// Pinned, not re-sorted. Sorting the whole list by return would put the
    /// least likely calls at the top and the safest at the bottom, which is
    /// the opposite of how the model ranks them and reads as advice we do not
    /// give. Lifting the one card to the front makes the money findable
    /// without inverting the board into a risk-first list; the win
    /// probability travels with it, as it does everywhere else.
    private var visibleRest: [Pick] {
        let open = openBoard
        guard let topId = biggestWinId,
              let i = open.firstIndex(where: { $0.id == topId }), i > 0
        else { return open }
        var reordered = open
        reordered.insert(reordered.remove(at: i), at: 0)
        return reordered
    }
    private var hiddenRest: [Pick] { shownRest.filter { locked($0) } }

    /// EVERY game in play, locked or not.
    ///
    /// This used to drop locked picks outright, which meant a free user's
    /// LIVE tab was empty while games were being played, and the counter
    /// above it read "0 PICKS LIVE NOW" during a full slate. Cutting the free
    /// tier to a single call made that near-total. A live score is not the
    /// paid product — the CALL is — so the game and the scoreline are shown
    /// to everyone and only the pick itself stays behind the paywall.
    /// A score is only LIVE if it was refreshed recently.
    ///
    /// `live_scores` currently holds 32 rows stuck at InProgress since 18
    /// August: the pipeline stopped refreshing them mid-game and nothing ever
    /// moved them to Final. Status alone would show those as in play forever.
    /// The live loop ticks every couple of minutes while games are on, so
    /// anything untouched for two hours is a stalled row, not a match.
    private static let liveStaleAfter: TimeInterval = 2 * 3600

    private var liveNow: [(pick: Pick, score: LiveScore)] {
        let live = vm.liveScores.filter {
            guard $0.isLive else { return false }
            guard let u = $0.updatedAt else { return true }
            return Date().timeIntervalSince(u) < Self.liveStaleAfter
        }
        return coveredToday.compactMap { p in
            guard let gid = p.gameId, let s = live.first(where: { $0.gameId == gid }) else { return nil }
            return (p, s)
        }
    }

    private var settled: [Pick] {
        // game_date is "yyyy-MM-dd", which sorts as text exactly as it does as a
        // date. Parsing it inside the comparator cost thousands of formatter
        // calls per render, and this runs on every live-score tick.
        vm.historyPicks.filter { !$0.isPending && P1_SPORTS.contains($0.sport) }
            .sorted { $0.gameDate > $1.gameDate }
    }

    /// Every prediction whose game is in the past, plus any current-day call
    /// that has already settled. This intentionally includes ungraded past
    /// games so the public ledger never makes a published call disappear.
    private var pastPredictions: [Pick] {
        let today = Calendar.current.startOfDay(for: Date())
        return vm.historyPicks
            .filter { pick in
                if !pick.isPending { return true }
                return (pick.gameDateValue ?? .distantFuture) < today
            }
            .sorted {
                ($0.gameDate, $0.createdAt ?? .distantPast)
                    > ($1.gameDate, $1.createdAt ?? .distantPast)
            }
    }

    private var searchedPastPredictions: [Pick] {
        let needle = resultSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return pastPredictions }
        return pastPredictions.filter { pick in
            // `sport` carries the raw key ("afl") and v4Name the shown label
            // ("Aus Football"), so the words a user actually types for this
            // sport, "australian" and "aussie", match neither. Alias them.
            ([pick.homeTeam, pick.awayTeam, pick.pick, pick.displayPick,
              pick.league, pick.sport, v4Name(pick.sport), pick.gameDate]
             + (pick.sport == "afl" ? ["australian football", "aussie rules"] : []))
                .contains { $0.localizedCaseInsensitiveContains(needle) }
        }
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
        guard let m = subs.products.first(where: { $0.id.hasSuffix("monthly") }) else { return "$0.50" }
        return (m.price / 30).formatted(m.priceFormatStyle)
    }

    private var slipIDs: Set<String> { Set(savedSlipIDs.split(separator: ",").map(String.init)) }
    private var slipPicks: [Pick] {
        let free = freeIds
        var seen = Set<UUID>()
        return (coveredToday + vm.historyPicks).filter {
            P1_SPORTS.contains($0.sport) && seen.insert($0.id).inserted && slipIDs.contains($0.id.uuidString) && (isPro || free.contains($0.id))
        }
    }
    private func toggleSlip(_ pick: Pick) {
        guard !locked(pick) else { onUpgrade(); return }
        var ids = slipIDs
        let adding = !ids.contains(pick.id.uuidString)
        if adding { ids.insert(pick.id.uuidString) } else { ids.remove(pick.id.uuidString) }
        withAnimation(reduceMotion ? nil : Pick1Springs.snappy) {
            savedSlipIDs = ids.sorted().joined(separator: ",")
            slipMessage = adding ? "Added to your watchlist" : "Removed from your watchlist"
        }
        slipFeedback += 1
        P1ArenaAudio.play("pick1-click")
        Analytics.track(adding ? "pick_slip_added" : "pick_slip_removed", ["pick_id": pick.id.uuidString])
    }
    private func removeSlip(_ pick: Pick) {
        var ids = slipIDs; ids.remove(pick.id.uuidString)
        savedSlipIDs = ids.sorted().joined(separator: ",")
    }
    private struct BookLeague: Identifiable {
        let id: String
        let name: String
        let sport: String
        let picks: [Pick]
    }
    @State private var favoritesOnly = false
    @AppStorage("pick1FavoriteTeamsBannerHidden") private var favBannerHidden = false
    @StateObject private var board = P1ScoreboardStore()
    @State private var openGame: P1GameRow?
    @State private var showSearch = false
    @State private var showTeams = false
    private var bookPicks: [Pick] {
        sportPicks.filter {
            $0.gameDate == selectedDay && (!favoritesOnly || favorites.follows($0)) && (bookSearch.isEmpty || [$0.homeTeam, $0.awayTeam, $0.league].contains(where: { $0.localizedCaseInsensitiveContains(bookSearch) }))
        }
    }
    private var unlockedBookPicks: [Pick] {
        bookPicks.filter { !locked($0) }.sorted {
            if $0.isPending != $1.isPending { return $0.isPending }
            if $0.probability != $1.probability { return $0.probability > $1.probability }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
    private var bookLeagues: [BookLeague] {
        Dictionary(grouping: isPro ? bookPicks : bookPicks.filter { locked($0) }, by: { $0.sport + "|" + $0.league }).map { key, picks in
            BookLeague(id: key, name: p1LeagueLabel(picks[0]), sport: picks[0].sport,
                       picks: picks.sorted { ($0.isPending ? 0 : 1, $0.gameDate, $0.startTime ?? "") < ($1.isPending ? 0 : 1, $1.gameDate, $1.startTime ?? "") })
        }.sorted {
            let aOpen = $0.picks.contains { $0.isPending }, bOpen = $1.picks.contains { $0.isPending }
            if aOpen != bOpen { return aOpen }
            let a = $0.picks.map(\.probability).max() ?? 0
            let b = $1.picks.map(\.probability).max() ?? 0
            return a == b ? $0.id < $1.id : a > b
        }
    }

    // MARK: Body
    var body: some View {
        TabView(selection: Binding<String>(
            get: { isSlipPage ? "slip" : tab.rawValue },
            set: { value in
                isSlipPage = value == "slip"
                if let next = P1V4Tab(rawValue: value) { tab = next }
            }
        )) {
            bookTabContent(.tonight)
                .tabItem { Label("Sports", systemImage: "house.fill") }.tag(P1V4Tab.tonight.rawValue)
            bookTabContent(.live)
                .tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }.tag(P1V4Tab.live.rawValue)
            watchlistPage
                .tabItem { Label("Watchlist", systemImage: "list.bullet.rectangle.fill") }
                .badge(slipPicks.count).tag("slip")
                .animation(reduceMotion ? nil : Pick1Springs.bouncy, value: slipPicks.count)
            bookTabContent(.yours)
                .tabItem { Label("My picks", systemImage: "bookmark.fill") }.tag(P1V4Tab.yours.rawValue)
            bookTabContent(.results)
                .tabItem { Label("Results", systemImage: "chart.line.uptrend.xyaxis") }.tag(P1V4Tab.results.rawValue)
        }
        .tint(Color.p1Lime)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedDay)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: tab)
        .animation(reduceMotion ? nil : Pick1Springs.smooth, value: selectedSport)
        .animation(reduceMotion ? nil : Pick1Springs.snappy, value: savedSlipIDs)
        .sensoryFeedback(.selection, trigger: selectedDay)
        .sensoryFeedback(.selection, trigger: slipFeedback)
        .overlay(alignment: .bottom) {
            if let slipMessage {
                Label(slipMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Capsule().fill(Color.p1Panel2).shadow(color: .black.opacity(0.3), radius: 12))
                    .padding(.bottom, 84).allowsHitTesting(false)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: slipFeedback) {
            guard slipMessage != nil else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { slipMessage = nil }
        }
        .background(Color.p1Ink.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .sheet(item: $bookPage) { page in
            P1ExploreScreen(page: page, games: coveredToday, picks: coveredToday.filter { !locked($0) }, onOpen: { p in bookPage = nil; if locked(p) { onUpgrade() } else { onSelectPick(p) } }, onAdd: toggleSlip)
        }
        .sheet(item: $shareResult) { p in ShareWinSheet(pick: p) }
        .task(id: selectedDay) { await board.follow(day: selectedDay) }
        .onReceive(NotificationCenter.default.publisher(for: .pick1OpenGame)) { _ in openPendingGame() }
        .task { openPendingGame(); favorites.syncAllTeams() }
        .task { await P1AffiliateStore.shared.load() }
        .onChange(of: board.games(P1BookDays.key())) { _, _ in autoTrackLive() }
        .fullScreenCover(item: $openGame) { row in
            P1GameDetail(row: liveRow(row), locked: row.pick.map(locked) ?? false,
                         watching: row.pick.map { slipIDs.contains($0.id.uuidString) } ?? false,
                         onAnalysis: { p in
                             openGame = nil
                             Task { try? await Task.sleep(for: .milliseconds(450)); onSelectPick(p) }
                         },
                         onWatch: toggleSlip,
                         onUnlock: {
                             openGame = nil
                             Task { try? await Task.sleep(for: .milliseconds(450)); onUpgrade() }
                         },
                         actions: gameActions)
                .environmentObject(favorites)
        }
        .sheet(isPresented: $showTeams) {
            P1ManageTeamsSheet().environmentObject(favorites)
        }
        .sheet(isPresented: $showSearch) {
            P1SearchScreen(games: gameRows(selectedDay) + (selectedDay == P1BookDays.key() ? [] : gameRows(P1BookDays.key())),
                           actions: gameActions)
                .environmentObject(favorites)
        }
        .task { if subs.products.isEmpty { await subs.reloadProducts() } }
        .task { if !betTracker.loaded { await betTracker.load() } }
    }

    private func bookTabContent(_ page: P1V4Tab) -> some View {
        VStack(spacing: 0) {
            P1BookHeader(onProfile: onProfile, onTeams: { showTeams = true }, onSearch: { showSearch = true }, onPage: { bookPage = $0 })
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    switch page {
                    case .tonight: tonight
                    case .live: live
                    case .yours: yours
                    case .results: results
                    }
                    Color.clear.frame(height: 16)
                }
            }
            .refreshable {
                if page == .tonight || page == .live {
                    await board.load(page == .live ? P1BookDays.key() : selectedDay, force: true)
                }
            }
        }.background(Color.black.ignoresSafeArea())
    }

    // MARK: Tonight

    @ViewBuilder private var tonight: some View {
        P1SportTabs(sports: boardSports, active: tabSport) { selectedSport = $0 }
            .padding(.top, 2).padding(.bottom, 14)
        if selectedDay >= P1BookDays.key() { conversionBanner(gameRows(selectedDay)) }
        if !favBannerHidden {
            P1FavoriteTeamsBanner(teams: favoriteTeams, active: favoritesOnly,
                                  onTap: {
                                      if favorites.teams.isEmpty && favorites.leagues.isEmpty { showTeams = true }
                                      else { favoritesOnly.toggle() }
                                  },
                                  onClose: { favBannerHidden = true; favoritesOnly = false })
                .padding(.horizontal, 16).padding(.bottom, 14)
        }
        let rows = dayRows
        let featured = rows.filter { row in row.pick.map { !locked($0) } ?? false }
            .sorted { ($0.game.phase.rawValue, $0.game.date) < ($1.game.phase.rawValue, $1.game.date) }
        P1FeaturedGames(rows: Array(featured.prefix(6)), onOpen: { openGame = $0 })
            .padding(.bottom, featured.isEmpty ? 0 : 16)
        P1DayChips(days: boardDays, selected: $selectedDay,
                   liveDays: board.games(P1BookDays.key()).contains { $0.phase == .live } ? [P1BookDays.key()] : [])
            .padding(.bottom, 16)
        P1DateDivider(day: selectedDay).padding(.bottom, 14)
        if rows.isEmpty && (board.loading.contains(selectedDay) || vm.isLoading) {
            P1LoadingCards()
        } else if rows.isEmpty {
            emptyState(favoritesOnly ? "No games for your teams" : "No games on this day",
                       (board.failures[selectedDay] ?? 0) > 0 ? "Some schedules did not load. Pull down to refresh." : "Pick another day or another sport.")
        } else {
            P1AllGamesList(rows: rows, isLocked: locked, isWatching: { slipIDs.contains($0.id.uuidString) },
                           onOpen: { openGame = $0 },
                           onWatch: toggleSlip, onUnlock: onUpgrade)
                .id(selectedDay + tabSport)
        }
        if !isPro, rows.contains(where: { $0.pick != nil }) {
            Button(action: onUpgrade) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(Color.p1Lime)
                    Text(offer.cta).font(.system(size: 13, weight: .semibold))
                    Spacer(); Image(systemName: "chevron.right")
                }.foregroundStyle(.white).padding(14)
                    .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
            }.buttonStyle(PressableButtonStyle()).padding(.horizontal, 16).padding(.bottom, 12)
        }
        Text("Scores and schedules from ESPN, times in your timezone. PICK1 shows its call under each game it analysed.")
            .font(.system(size: 10)).foregroundStyle(P1Board.secondary)
            .padding(.horizontal, 16).padding(.top, 4)
    }

    // MARK: All games

    /// Fixed order for the text tabs, so they never shuffle between mornings.
    private var boardSports: [String] { [Self.allSports, "football", "basketball", "hockey", "baseball", "soccer", "tennis", "f1"] }
    private var tabSport: String { selectedSport.flatMap { boardSports.contains($0) ? $0 : nil } ?? Self.allSports }
    /// Three days back for results, six ahead for the schedule.
    private var boardDays: [String] {
        (-3...6).compactMap { P1BookDays.calendar.date(byAdding: .day, value: $0, to: Date()).map { P1BookDays.key($0) } }
    }
    private var allPicks: [Pick] {
        var seen = Set<UUID>()
        return (vm.todayPicks + vm.yesterdayPicks + vm.historyPicks).filter { seen.insert($0.id).inserted }
    }
    private func gameRows(_ day: String) -> [P1GameRow] {
        P1GameMatch.rows(games: board.games(day), picks: allPicks, scores: vm.liveScores, day: day)
    }
    private func followsGame(_ row: P1GameRow) -> Bool {
        if let p = row.pick, favorites.follows(p) { return true }
        if favorites.leagues.contains(row.game.league) { return true }
        return favorites.teams.contains { team in
            P1GameMatch.same(row.game.home, team, sport: row.game.sport) || P1GameMatch.same(row.game.away, team, sport: row.game.sport)
        }
    }
    private var dayRows: [P1GameRow] {
        gameRows(selectedDay)
            .filter { tabSport == Self.allSports || $0.game.sport == tabSport }
            .filter { !favoritesOnly || followsGame($0) }
    }
    /// Followed teams with the sport their crest comes from.
    private var favoriteTeams: [(name: String, sport: String)] {
        let picks = allPicks
        return favorites.teams.sorted().map { team in
            let sport = picks.first { $0.homeTeam == team || $0.awayTeam == team }?.sport
                ?? board.games(P1BookDays.key()).first { $0.home.name == team || $0.away.name == team }?.sport
                ?? "soccer"
            return (team, sport)
        }
    }

    /// Callbacks for game and team pages opened anywhere below the home
    /// screen. Leaving for the analysis or the paywall closes them all first.
    // MARK: Conversion

    /// The upgrade pitch from the real StoreKit offer: the weekly plan, with
    /// its intro price only when this user is still eligible for it.
    private var offer: P1Offer {
        guard let weekly = subs.products.first(where: { $0.id.hasSuffix("weekly") }) else { return P1Offer() }
        if subs.introOfferEligible, let intro = weekly.subscription?.introductoryOffer {
            if intro.paymentMode == .freeTrial {
                return P1Offer(cta: "Start your free trial", terms: "Free, then \(weekly.displayPrice)/week. Cancel anytime.")
            }
            return P1Offer(cta: "Start for \(intro.displayPrice)",
                           terms: "First week \(intro.displayPrice), then \(weekly.displayPrice)/week. Cancel anytime.")
        }
        return P1Offer(cta: "Unlock for \(weekly.displayPrice)/week", terms: "Cancel anytime.")
    }

    /// PICK1's real 30-day record in a league, shown only when it sells.
    private func leagueRecord(_ pick: Pick) -> String? {
        let cutoff = P1BookDays.key(Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())
        let graded = allPicks.filter { $0.league == pick.league && $0.gameDate >= cutoff && ($0.isWin || $0.isLoss) }
        let w = graded.filter(\.isWin).count
        guard graded.count >= 10, Double(w) / Double(graded.count) >= 0.55 else { return nil }
        return "PICK1 in \(p1LeagueLabel(pick)): \(w)-\(graded.count - w) over the last 30 days"
    }

    /// Locked live games where PICK1's (hidden) side is ahead right now.
    private func leadingLocked(_ rows: [P1GameRow]) -> Int {
        rows.filter { row in
            guard row.game.phase == .live, let p = row.pick, locked(p),
                  let hs = row.game.home.score, let aws = row.game.away.score else { return false }
            let onHome = P1GameMatch.same(row.game.home, p.pick, sport: row.game.sport)
            let onAway = P1GameMatch.same(row.game.away, p.pick, sport: row.game.sport)
            guard onHome != onAway else { return false }
            return onHome ? hs > aws : aws > hs
        }.count
    }

    /// Free users only: what they are missing today, in real numbers.
    @ViewBuilder private func conversionBanner(_ rows: [P1GameRow]) -> some View {
        let lockedCount = rows.filter { $0.pick.map { $0.isPending && locked($0) } ?? false }.count
        if !isPro, lockedCount > 0 {
            let leading = leadingLocked(rows)
            let weekCut = P1BookDays.key(Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date())
            let week = settled.filter { $0.gameDate >= weekCut && ($0.isWin || $0.isLoss) }
            let wins = week.filter(\.isWin).count
            let o = offer
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill").foregroundStyle(Color.p1Lime)
                    Text(lockedCount == 1 ? "1 PICK1 call is locked" : "\(lockedCount) PICK1 calls are locked")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                }
                if leading > 0 {
                    HStack(spacing: 6) {
                        P1LivePulse()
                        Text(leading == 1 ? "PICK1 is leading 1 live game right now" : "PICK1 is leading \(leading) live games right now")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.p1Lime)
                    }
                } else if week.count >= 10, Double(wins) / Double(week.count) >= 0.55 {
                    Text("PICK1 went \(wins)-\(week.count - wins) this week, every call public.")
                        .font(.system(size: 14)).foregroundStyle(P1Board.secondary)
                }
                Button(action: onUpgrade) {
                    Text(o.cta).font(.system(size: 17, weight: .bold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 48).background(Capsule().fill(Color.p1Lime))
                }.buttonStyle(PressableButtonStyle())
                if !o.terms.isEmpty {
                    Text(o.terms).font(.system(size: 12)).foregroundStyle(P1Board.secondary).frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(Color.p1Lime.opacity(0.35)))
            .padding(.horizontal, 16).padding(.bottom, 14)
        }
    }

    private var gameActions: P1GameActions {
        P1GameActions(
            offer: offer, leagueRecord: { leagueRecord($0) },
            picks: allPicks, isLocked: { locked($0) }, isWatching: { slipIDs.contains($0.id.uuidString) },
            onAnalysis: { p in
                openGame = nil; showSearch = false
                Task { try? await Task.sleep(for: .milliseconds(500)); onSelectPick(p) }
            },
            onWatch: { toggleSlip($0) },
            onUnlock: {
                openGame = nil; showSearch = false
                Task { try? await Task.sleep(for: .milliseconds(500)); onUpgrade() }
            })
    }

    /// A tapped team alert names its game ("espn|path|id|day"): jump to that
    /// day and open the page once the board has it.
    private func openPendingGame() {
        guard let key = P1DeepLink.pendingGameKey else { return }
        let parts = key.split(separator: "|").map(String.init)
        guard parts.count == 4 else { P1DeepLink.pendingGameKey = nil; return }
        let id = parts[2], day = parts[3]
        tab = .tonight; isSlipPage = false; selectedDay = day
        Task {
            for _ in 0..<20 {
                await board.load(day)
                if let row = gameRows(day).first(where: { $0.game.id == id }) {
                    P1DeepLink.pendingGameKey = nil
                    openGame = row
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            P1DeepLink.pendingGameKey = nil
        }
    }

    /// Starred and watched calls get their Lock Screen card as soon as the
    /// game starts, the way the old pick-keyed sync did, but on ESPN's feed.
    private func autoTrackLive() {
        for row in gameRows(P1BookDays.key()) where row.game.phase == .live {
            guard let pick = row.pick, !locked(pick),
                  favorites.contains(pick.id) || slipIDs.contains(pick.id.uuidString),
                  !LiveActivityManager.shared.isTracking(row.game) else { continue }
            LiveActivityManager.shared.track(game: row.game, pick: pick, locked: false)
        }
    }

    /// The open game page follows the board, so its score keeps moving.
    private func liveRow(_ row: P1GameRow) -> P1GameRow {
        for day in [selectedDay, P1BookDays.key()] {
            if let fresh = gameRows(day).first(where: { $0.id == row.id }) { return fresh }
        }
        return row
    }

    // MARK: Live

    @ViewBuilder private var live: some View {
        let rows = gameRows(P1BookDays.key()).filter { $0.game.phase == .live }
        HStack(alignment: .firstTextBaseline) {
            Text("Live").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            Spacer()
            if !rows.isEmpty { Text(p1GamesCount(rows.count)).font(.system(size: 12)).foregroundStyle(P1Board.secondary) }
        }.padding(16)
        conversionBanner(rows)
        if rows.isEmpty && board.loading.contains(P1BookDays.key()) {
            P1LoadingCards()
        } else if rows.isEmpty {
            emptyState("No live games right now", "Every game in progress shows here with its live score, and the PICK1 call when there is one.")
        } else {
            P1AllGamesList(rows: rows, isLocked: locked, isWatching: { slipIDs.contains($0.id.uuidString) },
                           onOpen: { openGame = $0 },
                           onWatch: toggleSlip, onUnlock: onUpgrade, preview: 50)
        }
    }

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

        let ids = Set(betTracker.bets.keys).union(byId.values.filter { favorites.follows($0) }.map(\.id))
        return ids.compactMap { id -> (pick: Pick, bet: UserBet?)? in
            guard let p = byId[id], P1_SPORTS.contains(p.sport), !locked(p) else { return nil }
            return (p, betTracker.bets[id])
        }
        .sorted {
            if $0.pick.isPending != $1.pick.isPending { return $0.pick.isPending }
            return $0.pick.gameDate > $1.pick.gameDate
        }
    }

    @ViewBuilder private var yours: some View {
        let rows = mine
        let settledMine = rows.filter { $0.pick.isWin || $0.pick.isLoss }
        let wins = settledMine.filter { $0.pick.isWin }.count
        let summary = betTracker.summary(picks: vm.historyPicks + vm.yesterdayPicks + vm.todayPicks)

        pageTitle("My picks", rows.isEmpty ? nil : "\(rows.count) on your slate")
        HStack(spacing: 10) {
            statTile("\(rows.filter { $0.pick.isPending }.count)", "Still to play")
            statTile("\(wins)-\(settledMine.count - wins)", "Your record")
            if let roi = summary.roiPct, summary.staked > 0 {
                statTile("\(roi >= 0 ? "+" : "")\(Int(roi.rounded()))%", "Your ROI", tint: roi >= 0 ? Color.p1Lime : Color.p1Red)
            } else {
                statTile(settledMine.isEmpty ? "–" : "\(Int((Double(wins) / Double(settledMine.count) * 100).rounded()))%", "Hit rate")
            }
        }.padding(.horizontal, 16).padding(.bottom, 18)

        if rows.isEmpty {
            boardEmpty(icon: "bookmark", title: "Nothing on your slate yet",
                       body: "Track a PICK1 call or star a game and it lands here, with the live score and then the result.",
                       action: ("Browse today's games", { tab = .tonight }))
        } else {
            let open = rows.filter { $0.pick.isPending }
            let done = rows.filter { !$0.pick.isPending }
            if !open.isEmpty { pickSection("Still to play", open) }
            if !done.isEmpty { pickSection("Settled", done) }
            if summary.staked > 0 {
                Text("Profit and ROI count only the picks you entered a stake for.")
                    .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
                    .padding(.horizontal, 16).padding(.top, 4)
            }
        }
    }

    private func pickSection(_ title: String, _ rows: [(pick: Pick, bet: UserBet?)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            ForEach(pickRows(rows.map(\.pick)), id: \.game.id) { row in
                VStack(alignment: .leading, spacing: 6) {
                    P1GameListRow(row: row, locked: false,
                                  watching: row.pick.map { slipIDs.contains($0.id.uuidString) } ?? false,
                                  onOpen: { openGame = row },
                                  onWatch: { if let p = row.pick { toggleSlip(p) } }, onUnlock: onUpgrade)
                    if let p = row.pick, let bet = rows.first(where: { $0.pick.id == p.id })?.bet, let stake = bet.stake, stake > 0 {
                        betLine(p, bet: bet, stake: stake).padding(.horizontal, 6)
                    }
                }
            }
        }.padding(.horizontal, 16).padding(.bottom, 20)
    }

    private func betLine(_ p: Pick, bet: UserBet, stake: Double) -> some View {
        let odds = bet.oddsAtBet ?? p.decimalOdds
        let amount = stake.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        return HStack(spacing: 6) {
            Image(systemName: "dollarsign.circle.fill").foregroundStyle(P1Board.secondary)
            Text("Your stake \(amount) at \(String(format: "%.2f", odds))")
                .foregroundStyle(P1Board.secondary)
            Spacer()
            if p.isWin {
                Text(P1Odds.money(stake * (odds - 1))).foregroundStyle(Color.p1Lime)
            } else if p.isLoss {
                Text(P1Odds.money(-stake)).foregroundStyle(Color.p1Red)
            } else {
                Text("To win " + P1Odds.money(stake * (odds - 1)).dropFirst()).foregroundStyle(.white)
            }
        }.font(.system(size: 12, weight: .semibold)).monospacedDigit()
    }

    // MARK: Watchlist

    private var watchlistPage: some View {
        VStack(spacing: 0) {
            P1BookHeader(onProfile: onProfile, onTeams: { showTeams = true }, onSearch: { showSearch = true }, onPage: { bookPage = $0 })
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let picks = slipPicks.sorted { ($0.isPending ? 0 : 1, $0.gameDate) < ($1.isPending ? 0 : 1, $1.gameDate) }
                    pageTitle("Watchlist", picks.isEmpty ? nil : p1GamesCount(picks.count))
                    if picks.isEmpty {
                        boardEmpty(icon: "eye", title: "Nothing on your watchlist",
                                   body: "Tap the eye on any game with a PICK1 call. It stays here with its live score, then its graded result.",
                                   action: ("Browse today's games", { isSlipPage = false; tab = .tonight }))
                    } else {
                        let rows = pickRows(picks)
                        let live = rows.filter { $0.game.phase == .live }
                        let next = rows.filter { $0.game.phase == .pre }
                        let done = rows.filter { $0.game.phase == .final || $0.game.phase == .off }
                        if !live.isEmpty { watchSection("Live now", live) }
                        if !next.isEmpty { watchSection("Upcoming", next) }
                        if !done.isEmpty { watchSection("Settled", done) }
                        let open = picks.filter { $0.isPending }
                        if !open.isEmpty {
                            P1PlaceButton(open.count > 1 ? "Place your watchlist (\(open.count))" : "Place this pick",
                                          selections: open.map(\.handoffSelection), source: "watchlist")
                                .padding(.horizontal, 16).padding(.bottom, 12)
                        }
                    }
                    Color.clear.frame(height: 16)
                }
            }
        }.background(Color.black.ignoresSafeArea())
    }

    private func watchSection(_ title: String, _ rows: [P1GameRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            ForEach(rows, id: \.game.id) { row in
                P1GameListRow(row: row, locked: false, watching: true,
                              onOpen: { openGame = row },
                              onWatch: { if let p = row.pick { removeSlip(p) } }, onUnlock: onUpgrade)
            }
        }.padding(.horizontal, 16).padding(.bottom, 20)
    }

    // MARK: Results

    @State private var resultsSport = Pick1HomeV4.allSports
    @State private var resultDayLimit = 10

    /// Net on $100 per priced call over the last 30 days, losses included.
    private func net30(_ picks: [Pick]) -> (net: Double, priced: Int, hit: Double, breakEven: Double) {
        let cutoff = P1BookDays.key(Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date())
        let priced = picks.filter { ($0.isWin || $0.isLoss) && $0.gameDate >= cutoff }.compactMap { p -> (Pick, Double)? in
            guard let q = P1BookQuote.forPick(p) else { return nil }
            return (p, q.odds)
        }
        let wins = priced.filter { $0.0.isWin }
        let hit = priced.isEmpty ? 0 : Double(wins.count) / Double(priced.count) * 100
        // The hit rate a flat $100 needs to break even at these prices.
        let avgWinPrice = wins.isEmpty ? 0 : wins.map(\.1).reduce(0, +) / Double(wins.count)
        let breakEven = avgWinPrice > 1 ? 100 / avgWinPrice : 0
        return (priced.reduce(0) { $0 + ($1.0.isWin ? 100 * ($1.1 - 1) : -100) }, priced.count, hit, breakEven)
    }

    @ViewBuilder private var results: some View {
        // The record covers the sports the app shows, like every other surface.
        let list = searchedPastPredictions.filter {
            P1_SPORTS.contains($0.sport) && (resultsSport == Self.allSports || $0.sport == resultsSport)
        }
        let graded = list.filter { $0.isWin || $0.isLoss }
        let wins = graded.filter(\.isWin).count
        let money = net30(list)

        pageTitle("Results", "Every call, graded in public")
        P1SportTabs(sports: boardSports, active: resultsSport) { resultsSport = $0; resultDayLimit = 10 }
            .padding(.bottom, 16)
        HStack(spacing: 10) {
            statTile("\(wins)-\(graded.count - wins)", "All-time record")
            statTile(graded.isEmpty ? "–" : "\(Int((Double(wins) / Double(graded.count) * 100).rounded()))%", "All-time hit rate")
            statTile(money.priced == 0 ? "–" : P1Odds.money(money.net), "Last 30 days",
                     tint: money.net >= 0 ? Color.p1Lime : Color.p1Red)
        }.padding(.horizontal, 16)
        if money.priced > 0 {
            moneyExplainer(money)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 16)
        }

        resultSearchField.padding(.horizontal, 16).padding(.bottom, 18)

        if pastPredictions.isEmpty {
            boardEmpty(icon: "chart.line.uptrend.xyaxis", title: "No settled calls yet",
                       body: "Every pick is logged before kickoff and graded here once it lands.", action: nil)
        } else if list.isEmpty {
            boardEmpty(icon: "magnifyingglass", title: "No matching games",
                       body: "Try a team, player, league, sport or date.", action: nil)
        } else {
            let byDay = Dictionary(grouping: list, by: \.gameDate)
            let days = byDay.keys.sorted(by: >)
            ForEach(days.prefix(resultDayLimit), id: \.self) { day in
                let dayPicks = byDay[day] ?? []
                let dayWins = dayPicks.filter(\.isWin).count, dayLosses = dayPicks.filter(\.isLoss).count
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        P1DateDivider(day: day).padding(.horizontal, -16)
                    }
                    if dayWins + dayLosses > 0 {
                        Text("\(dayWins)-\(dayLosses) that day")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(P1Board.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(pickRows(dayPicks), id: \.game.id) { row in
                        P1GameListRow(row: row, locked: row.pick.map { $0.isPending && locked($0) } ?? false,
                                      watching: row.pick.map { slipIDs.contains($0.id.uuidString) } ?? false,
                                      onOpen: { openGame = row },
                                      onWatch: { if let p = row.pick { toggleSlip(p) } }, onUnlock: onUpgrade)
                            .contextMenu {
                                if let p = row.pick, !p.isPending {
                                    Button { shareResult = p } label: { Label("Share this result", systemImage: "square.and.arrow.up") }
                                }
                            }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 18)
            }
            if days.count > resultDayLimit {
                Button { resultDayLimit += 10 } label: {
                    P1BoardPill(title: "Show earlier days", icon: "chevron.down")
                }.buttonStyle(PressableButtonStyle()).padding(.horizontal, 16)
            }
            Text("Every call is logged before kickoff and stays here, wins and losses, for good.")
                .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
                .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                .padding(.horizontal, 16).padding(.top, 16)
        }
    }

    /// Why a winning record can still be a losing $100 line: PICK1 mostly
    /// backs favourites, which pay little when they win.
    private func moneyExplainer(_ m: (net: Double, priced: Int, hit: Double, breakEven: Double)) -> some View {
        let profit = m.net >= 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: profit ? "arrow.up.right.circle.fill" : "info.circle.fill")
                    .foregroundStyle(profit ? Color.p1Lime : .white)
                Text(profit ? "Winning record, winning prices" : "More wins than losses, but favourites pay little")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            Text(profit
                 ? "Over the last 30 days PICK1 won \(Int(m.hit.rounded()))% of its \(m.priced) priced calls, above the \(Int(m.breakEven.rounded()))% these prices need, so $100 on each one is up \(P1Odds.money(m.net).dropFirst())."
                 : "Over the last 30 days PICK1 won \(Int(m.hit.rounded()))% of its \(m.priced) priced calls. Most were favourites, and at their prices a win returns about $\(Int((100 / max(m.breakEven, 1) * 100 - 100).rounded())) on $100 while a loss costs the full $100. Breaking even needs about \(Int(m.breakEven.rounded()))% wins.")
                .font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("$100 on every call with a captured market price, wins and losses. A simulation, not user earnings.")
                .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }

    private var resultSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .semibold)).foregroundStyle(P1Board.secondary)
            TextField("Search a team, player, league or date", text: $resultSearch)
                .font(.system(size: 15)).foregroundStyle(.white)
                .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
            if !resultSearch.isEmpty {
                Button { resultSearch = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(P1Board.secondary) }
                    .buttonStyle(PressableButtonStyle()).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14).frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 14).fill(P1Board.card))
    }

    // MARK: Shared page pieces

    /// The picks as game rows: the ESPN game when the board has it (live
    /// score, crests, records), the pick alone otherwise.
    private func pickRows(_ picks: [Pick]) -> [P1GameRow] {
        P1GameMatch.rowsFor(picks: picks, games: { board.games($0) }, scores: vm.liveScores)
    }

    private func pageTitle(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
            if let subtitle { Text(subtitle).font(.system(size: 14)).foregroundStyle(P1Board.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 16)
    }

    private func statTile(_ value: String, _ label: String, tint: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                .frame(height: 28, alignment: .leading)
            Text(label).font(.system(size: 12)).foregroundStyle(P1Board.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }

    private func boardEmpty(icon: String, title: String, body: String, action: (String, () -> Void)?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.p1Lime)
                .frame(width: 58, height: 58).background(Circle().fill(P1Board.pill))
            Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(body).font(.system(size: 14)).foregroundStyle(P1Board.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action: action.1) {
                    Text(action.0).font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 20).frame(height: 42).background(Capsule().fill(Color.white))
                }.buttonStyle(PressableButtonStyle()).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, 30)
        .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
        .padding(.horizontal, 16).padding(.top, 4)
    }

    private func emptyState(_ title: String, _ body: String) -> some View {
        boardEmpty(icon: "sportscourt", title: title, body: body, action: nil)
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
            .task {
                await vm.loadAll()
                if CommandLine.arguments.contains("-showMatchDetail") { detailPick = vm.todayPicks.filter { $0.isPending }.max(by: { ($0.bettingProps?.count ?? 0) < ($1.bettingProps?.count ?? 0) }) ?? vm.todayPicks.first }
                if CommandLine.arguments.contains("-showPickSlip"), let first = vm.todayPicks.first {
                    UserDefaults.standard.set(first.id.uuidString, forKey: "sportsbookSlipIDs")
                }
            }
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
