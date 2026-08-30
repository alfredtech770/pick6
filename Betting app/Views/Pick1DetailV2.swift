//  Pick1DetailV2.swift
//  "Home v2 — Switch Style" — the Match Detail screen
//
//  The mockup's second phone, in its order: back / brand / favourite header,
//  the big matchup hero, the two-face panel, the call card with its Signals
//  meters, the Projections card (predicted score + market rows, locked past
//  the second row), and the factor grid.
//
//  This screen is the best-backed of the whole redesign: `predicted_score`,
//  `betting_props`, `factors` and the captured crest/headshot URLs are all
//  real pipeline output. Two mockup details have no data behind them and are
//  handled where they occur: the venue line and the "LOGGED 6:30 AM" pill.

import SwiftUI

// MARK: - Face panel

/// Two overlapping circular portraits, the called side ringed in lime. Uses
/// the app's existing resolver, so it shows the real crest or headshot the
/// pipeline captured rather than a placeholder disc.
struct P1FacesV2: View {
    let pick: Pick

    private var calledIsHome: Bool {
        pick.pick.caseInsensitiveCompare(pick.homeTeam) == .orderedSame
    }
    private var called: String { calledIsHome ? pick.homeTeam : pick.awayTeam }
    private var other: String { calledIsHome ? pick.awayTeam : pick.homeTeam }

    var body: some View {
        HStack(spacing: 0) {
            face(called, isCalled: true).zIndex(2)
            Text("VS")
                .font(.anton(14))
                .foregroundStyle(Color.p1Mute)
                .padding(.horizontal, 12)
                .zIndex(4)
            face(other, isCalled: false).offset(x: -14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 38)
        .padding(.horizontal, 20)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.p1Panel))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.p1Line, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private func face(_ name: String, isCalled: Bool) -> some View {
        ZStack {
            TeamLogo(sport: pick.sport, team: name, size: .big)
                .frame(width: 92, height: 92)
                .background(Circle().fill(Color.p1Ink))
                .clipShape(Circle())
            Circle()
                .strokeBorder(isCalled ? Color.p1Lime : Color.p1Line, lineWidth: 3)
                .frame(width: 100, height: 100)
                .shadow(color: isCalled ? Color.p1Lime.opacity(0.35) : .clear, radius: 10)
        }
        .frame(width: 92, height: 92)
        .overlay(alignment: .bottom) {
            Text(name.uppercased())
                .font(.archivoNarrow(9, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(isCalled ? Color.p1Lime : Color.p1Mute)
                .lineLimit(1)
                .fixedSize()
                .offset(y: 22)
        }
    }
}

// MARK: - Market row

struct P1MarketRowV2: View {
    let prop: BettingProp
    let isLocked: Bool
    var isHighReturn: Bool = false
    var onTap: () -> Void = {}

    private var strength: Int { prop.probability ?? 50 }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(prop.label.uppercased())
                            .font(.archivoNarrow(9, weight: .bold))
                            .tracking(1.44)
                            .foregroundStyle(Color.p1Mute)
                        if isHighReturn {
                            Text("🔥 HIGH RETURN")
                                .font(.archivoNarrow(8, weight: .bold))
                                .tracking(0.96)
                                .foregroundStyle(Color.p1Hot)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(Color.p1Hot.opacity(0.12)))
                                .overlay(Capsule().strokeBorder(Color.p1Hot.opacity(0.4), lineWidth: 1))
                        }
                    }
                    Text(prop.value)
                        .font(.anton(16))
                        .foregroundStyle(Color.p1Foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 3)
                        .blur(radius: isLocked ? 6 : 0)

                    GeometryReader { geo in
                        Capsule().fill(Color.p1Panel2)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(LinearGradient(colors: [Color(hex: "#9DC72C"), Color.p1Lime],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(strength) / 100)
                            }
                    }
                    .frame(height: 4)
                    .padding(.top, 7)
                    .blur(radius: isLocked ? 6 : 0)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(strength)%")
                        .font(.mono(15, weight: .bold))
                        .foregroundStyle(Color.p1Lime)
                        .blur(radius: isLocked ? 6 : 0)
                    Text("MODEL")
                        .font(.archivoNarrow(8, weight: .bold))
                        .tracking(1.12)
                        .foregroundStyle(Color.p1Mute)
                }
                .frame(minWidth: 64, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Ink))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.p1Line, lineWidth: 1))
            .overlay {
                if isLocked {
                    Text("🔒 PREMIUM")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.54)
                        .foregroundStyle(Color.p1Lime)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.p1Ink.opacity(0.25)))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen

struct Pick1DetailV2: View {
    let pick: Pick
    @EnvironmentObject private var subs: SubscriptionManager
    @EnvironmentObject private var favorites: FavoritesStore
    var onBack: () -> Void = {}
    var onUnlock: () -> Void = {}
    /// Arrive with the bet drawer already open.
    var startWithBetDrawer: Bool = false

    private static let signalColors = [Color(hex: "#FF7A2F"), Color.p1Violet, Color(hex: "#2F9BFF"), Color.p1Lime]

    private var calledIsHome: Bool {
        pick.pick.caseInsensitiveCompare(pick.homeTeam) == .orderedSame
    }
    private var called: String { calledIsHome ? pick.homeTeam : pick.awayTeam }
    private var other: String { calledIsHome ? pick.awayTeam : pick.homeTeam }

    /// "2-1" is stored home-first. The hero panel puts the called side first,
    /// so the pair is flipped when the call is the away team, otherwise the
    /// lime number would sit over the wrong crest.
    private var projectedScore: (called: String, other: String)? {
        guard let s = pick.predictedScore else { return nil }
        let parts = s.split(separator: "-").map(String.init)
        guard parts.count == 2 else { return nil }
        return calledIsHome ? (parts[0], parts[1]) : (parts[1], parts[0])
    }

    private var props: [BettingProp] { pick.bettingProps ?? [] }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: "#1D2026"), Color.p1Ink],
                           center: .init(x: 0.5, y: -0.08), startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    hero
                    P1FacesV2(pick: pick)
                    callCard
                    projections
                    if let factors = pick.factors, !factors.isEmpty {
                        factorGrid(factors)
                    }
                    Color.clear.frame(height: 120)   // clearance for the bet drawer
                }
                .padding(.top, 8)
            }
        }
        .overlay(alignment: .bottom) {
            // Only for calls that are still open — there is nothing to log
            // on a game that has already been graded.
            if pick.isPending {
                P1BetDrawer(pick: pick, startExpanded: startWithBetDrawer)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            circleButton("‹", action: onBack)
            Spacer(minLength: 8)
            VStack(spacing: 6) {
                P1BoltMark()
                    .fill(Color.p1LimeInk)
                    .frame(width: 38 * 0.62, height: 38 * 0.62)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [Color.p1Lime, Color(hex: "#8FC218")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .shadow(color: Color.p1Lime.opacity(0.4), radius: 12)
                Text("PICK1")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(3.0)
                    .foregroundStyle(Color.p1Ink2)
            }
            Spacer(minLength: 8)
            let isFav = favorites.contains(pick.id)
            circleButton(isFav ? "♥" : "♡", tint: isFav ? Color.p1Hot : Color.p1Foreground) {
                favorites.toggle(pick)
            }
        }
        .padding(.horizontal, 22)
    }

    private func circleButton(_ glyph: String, tint: Color = .p1Foreground, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 17))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.p1Panel))
                .overlay(Circle().strokeBorder(Color.p1Line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 0) {
            Text("\(pick.league.uppercased()) · MONEYLINE")
                .font(.archivoNarrow(11, weight: .bold))
                .tracking(3.74)                         // 0.34em at 11pt
                .foregroundStyle(Color.p1Mute)

            (
                Text("\(teamShortName(called, sport: pick.sport).uppercased())\n")
                    .foregroundStyle(Color.p1Foreground)
                + Text("vs \(teamShortName(other, sport: pick.sport))".uppercased())
                    .foregroundStyle(Color.p1Lime)
            )
            .font(.anton(52))
            .lineSpacing(-8)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)
            .shadow(color: Color.p1Lime.opacity(0.25), radius: 30)
            .padding(.top, 8)

            // The mockup's third field here is the venue. Nothing in `picks`
            // stores one, so the line carries the kickoff and league only
            // rather than inventing a stadium.
            HStack(spacing: 8) {
                Circle().fill(Color.p1Lime).frame(width: 7, height: 7)
                    .shadow(color: Color.p1Lime, radius: 4)
                Text(([pick.localizedScheduleDisplay, pick.league].compactMap { $0 }.joined(separator: " · ")).uppercased())
                    .font(.mono(11, weight: .bold))
                    .tracking(1.54)
                    .foregroundStyle(Color.p1Ink2)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 8)
    }

    // MARK: Call card

    private var callCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(pick.displayPick.uppercased())
                .font(.anton(29))
                .foregroundStyle(Color.p1Lime)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            if !pick.reasoning.isEmpty {
                Text(pick.reasoning)
                    .font(.archivo(13))
                    .lineSpacing(4)
                    .foregroundStyle(Color.p1Ink2)
                    .padding(.top, 8)
            }

            HStack(spacing: 8) {
                P1MetaPillV2(value: "◆ \(Int(pick.probability.rounded()))%", caption: "AI conf")
                // "LOGGED 6:30 AM" in the mockup. `created_at` is the real
                // publication time, so the pill states when the call actually
                // went on the record instead of a fixed hour.
                if let created = pick.createdAt {
                    P1MetaPillV2(value: created.formatted(date: .omitted, time: .shortened),
                                 caption: "logged", valueColor: Color.p1Foreground)
                }
            }
            .padding(.top, 14)

            if let factors = pick.factors, !factors.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("SIGNALS")
                            .font(.anton(16))
                            .foregroundStyle(Color.p1Foreground)
                        Text(subs.isPro ? "UNLOCKED" : "PREVIEW")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            LinearGradient(colors: [Color.p1Panel, Color(hex: "#0E0F12")],
                           startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(RadialGradient(colors: [Color.p1Violet.opacity(0.16), .clear],
                                     center: .center, startRadius: 0, endRadius: 130))
                .frame(width: 260, height: 260)
                .offset(x: -90, y: -90)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.p1Line, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    // MARK: Projections

    @ViewBuilder
    private var projections: some View {
        if projectedScore != nil || !props.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("PROJECTIONS")
                            .font(.anton(17))
                            .foregroundStyle(Color.p1Foreground)
                        Text("(AI MODEL)")
                            .font(.archivoNarrow(11, weight: .bold))
                            .tracking(1.32)
                            .foregroundStyle(Color.p1Mute)
                    }
                    Spacer(minLength: 8)
                    Text(pick.league.uppercased())
                        .font(.mono(11, weight: .bold))
                        .tracking(0.88)
                        .foregroundStyle(Color.p1Mute)
                }

                if let score = projectedScore {
                    VStack(spacing: 2) {
                        HStack(spacing: 12) {
                            scoreTeam(called, isCalled: true)
                            (
                                Text(score.called).foregroundStyle(Color.p1Lime)
                                + Text("–\(score.other)").foregroundStyle(Color.p1Foreground)
                            )
                            .font(.anton(40))
                            .tracking(1.2)
                            .fixedSize()
                            scoreTeam(other, isCalled: false)
                        }
                        Text("PREDICTED FINAL SCORE")
                            .font(.archivoNarrow(10, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(Color.p1Mute)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.p1Ink))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.p1Line, lineWidth: 1))
                    .padding(.top, 18)
                }

                VStack(spacing: 8) {
                    ForEach(Array(props.enumerated()), id: \.element.id) { i, prop in
                        // The mockup locks everything past the second row for
                        // free users; Pro sees the lot.
                        P1MarketRowV2(prop: prop,
                                      isLocked: i >= 2 && !subs.isPro,
                                      isHighReturn: (prop.odds ?? 0) >= 2.5) {
                            if i >= 2 && !subs.isPro { onUnlock() }
                        }
                    }
                }
                .padding(.top, 12)
            }
            .padding(22)
            .background(RoundedRectangle(cornerRadius: 26).fill(Color.p1Panel))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.p1Line, lineWidth: 1))
            .padding(.horizontal, 18)
            .padding(.top, 18)
        }
    }

    private func scoreTeam(_ name: String, isCalled: Bool) -> some View {
        VStack(spacing: 7) {
            TeamLogo(sport: pick.sport, team: name, size: .small)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.p1Panel2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(teamShortName(name, sport: pick.sport).uppercased())
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(isCalled ? Color.p1Ink2 : Color.p1Mute)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Factor grid

    private func factorGrid(_ factors: [PickFactor]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("FACTORS")
                        .font(.anton(17))
                        .foregroundStyle(Color.p1Foreground)
                    Text("(ANALYZED)")
                        .font(.archivoNarrow(11, weight: .bold))
                        .tracking(1.32)
                        .foregroundStyle(Color.p1Mute)
                }
                Spacer(minLength: 8)
                Text("◆ \(factors.count)")
                    .font(.mono(12, weight: .bold))
                    .foregroundStyle(Color.p1Lime)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                      spacing: 18) {
                ForEach(factors) { f in
                    VStack(spacing: 8) {
                        Text("\(f.strength)")
                            .font(.mono(13, weight: .bold))
                            .foregroundStyle(Color.p1Lime)
                            .frame(width: 54, height: 54)
                            .background(
                                Circle().fill(
                                    LinearGradient(colors: [Color(hex: "#23262C"), Color(hex: "#141619")],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            )
                            .overlay(Circle().strokeBorder(Color.p1Line, lineWidth: 1))
                            .shadow(color: .black.opacity(0.35), radius: 9, y: 8)
                        Text(f.label.uppercased())
                            .font(.archivoNarrow(10.5, weight: .semibold))
                            .tracking(0.63)
                            .foregroundStyle(Color.p1Ink2)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(.top, 20)
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 26).fill(Color.p1Panel))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(Color.p1Line, lineWidth: 1))
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }
}
