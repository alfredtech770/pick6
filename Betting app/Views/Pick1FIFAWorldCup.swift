// Pick1FIFAWorldCup.swift
//
// FIFA World Cup 2026 surface, ported pixel-faithfully from the Claude
// Design handoff (`Pick6 Home HiFi.html` → .wc-banner, and
// `FIFA World Cup In-App.html` → the full hub screen).
//
// Two public views:
//   • FIFAWorldCupBanner — the gold-bordered navy banner that sits on
//     the Home feed between the stats row and the sport filter. Tapping
//     it opens the hub.
//   • FIFAWorldCupHubView — the full in-app World Cup hub (hero,
//     day rail, featured opening match, today's slate, group standings,
//     bottom CTA).
//
// The hub content is static showcase data matching the design exactly
// — there is no live FIFA data pipeline; the design is a fixed mock.

import SwiftUI

// MARK: - World Cup palette (from the design's :root overrides)

enum WC {
    static let navy       = Color(hex: "#0C1F4D")
    static let blue       = Color(hex: "#326AC1")
    static let deep       = Color(hex: "#08163A")
    static let gold       = Color(hex: "#D4AF37")
    static let goldBright = Color(hex: "#FFD84D")
    static let red        = Color(hex: "#E30613")

    // Shared Pick1 tokens reused by the design
    static let accent    = Color(hex: "#D4FF3A")
    static let accentInk = Color(hex: "#0A0B0D")
    static let bg        = Color(hex: "#0A0B0D")
    static let panel     = Color(hex: "#101114")
    static let line      = Color(hex: "#22252B")
    static let ink       = Color(hex: "#F5F3EE")
    static let ink2      = Color(hex: "#B9B7B0")
    static let mute      = Color(hex: "#6E6F75")
    static let hot       = Color(hex: "#FF5A36")
}

// MARK: - Home banner  (.wc-banner)

/// Gold-bordered navy gradient banner for the Home feed. Mirrors
/// `.wc-banner` from `Pick6 Home HiFi.html`: 135° blue→navy→deep
/// gradient, gold hairline border, gold radial glow top-right, a
/// red→gold→blue 2pt base stripe, trophy + 3-line copy + lime
/// circular chevron CTA.
struct FIFAWorldCupBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: { Haptics.tap(); onTap() }) {
            HStack(spacing: 12) {
                WCTrophy()
                    .frame(width: 32, height: 38)
                    .foregroundColor(WC.gold)

                VStack(alignment: .leading, spacing: 0) {
                    Text("FIFA · WORLD CUP 2026")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(WC.gold)
                        .padding(.bottom, 3)
                    // .l2 — "EVERY MATCH. EVERY CALL." with CALL. in gold
                    (Text("EVERY MATCH. EVERY ")
                        .foregroundColor(.white)
                     + Text("CALL.")
                        .foregroundColor(WC.gold))
                        .font(.anton(22))
                        .tracking(-0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("12 LIVE TODAY · OPENING TONIGHT 8PM ET")
                        .font(.mono(9, weight: .heavy))
                        .tracking(1.6)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle().fill(WC.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(WC.accentInk)
                }
                .frame(width: 38, height: 38)
                .shadow(color: WC.accent.opacity(0.5), radius: 12, x: 0, y: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(bannerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(WC.gold, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                // .wc-banner::after — red→gold→blue 2pt base stripe
                LinearGradient(colors: [WC.red, WC.gold, WC.blue],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 2)
            }
            .shadow(color: WC.blue.opacity(0.45), radius: 18, x: 0, y: 14)
            .pressableScale(0.99)
        }
        .buttonStyle(.plain)
    }

    private var bannerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [WC.blue, WC.navy, WC.deep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            // .wc-banner::before — radial gold glow, top-right
            RadialGradient(
                colors: [WC.gold.opacity(0.35), .clear],
                center: UnitPoint(x: 0.92, y: 0.12),
                startRadius: 0, endRadius: 130
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Trophy mark (from the design's inline SVG path, redrawn)

/// FIFA-style trophy glyph. The design uses one SVG path; SF Symbols'
/// `trophy.fill` reads the same at this scale and stays crisp.
struct WCTrophy: View {
    var body: some View {
        Image(systemName: "trophy.fill")
            .resizable()
            .scaledToFit()
    }
}

// MARK: - In-App Hub  (FIFA World Cup In-App.html)

struct FIFAWorldCupHubView: View {
    let onClose: () -> Void

    @State private var selectedDay: Int = 1   // "TODAY · 11" is index 1

    var body: some View {
        ZStack(alignment: .bottom) {
            WC.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topNav
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 14)

                    heroBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)

                    dayRail
                        .padding(.bottom, 16)

                    sectionHead(title: "OPENING", accent: "MATCH",
                                metaLive: true, meta: "8:00 PM ET")
                    featuredMatch
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    sectionHead(title: "TODAY'S", accent: "SLATE",
                                metaLive: false, meta: "11 MORE")
                    matchesList
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                    sectionHead(title: "GROUP", accent: "STANDINGS",
                                metaLive: false, meta: "AI PROJECTED")
                    groupGrid
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)

                    Color.clear.frame(height: 110)   // clears bottom CTA
                }
            }

            bottomCTA
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
    }

    // ── Top nav ─────────────────────────────────────────────────
    private var topNav: some View {
        HStack {
            Button(action: { Haptics.tap(); onClose() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WC.ink)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(WC.panel))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(WC.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            HStack(spacing: 8) {
                WCTrophy().frame(width: 10, height: 13).foregroundColor(WC.gold)
                Text("FIFA WORLD CUP 2026")
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(WC.gold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(LinearGradient(colors: [WC.navy, WC.blue],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(Capsule().stroke(WC.gold, lineWidth: 1))

            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WC.gold)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(WC.panel))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(WC.line, lineWidth: 1))
        }
    }

    // ── Hero banner (.wc-hero) ──────────────────────────────────
    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    WCTrophy().frame(width: 22, height: 28).foregroundColor(WC.gold)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FIFA · WORLD CUP")
                            .font(.anton(8))
                            .tracking(2.6)
                            .foregroundColor(WC.gold)
                        (Text("2026 ").foregroundColor(.white)
                         + Text("USA · CAN · MEX").foregroundColor(WC.gold))
                            .font(.anton(14))
                    }
                }
                Spacer()
                (Text("AI BY ").foregroundColor(.white.opacity(0.6))
                 + Text("PICK1").foregroundColor(WC.accent))
                    .font(.mono(8, weight: .heavy))
                    .tracking(1.8)
            }
            .padding(.bottom, 14)

            (Text("EVERY MATCH.\nEVERY ").foregroundColor(.white)
             + Text("CALL.").foregroundColor(WC.gold))
                .font(.anton(50))
                .tracking(-1.0)
                .lineSpacing(-12)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                .padding(.vertical, 6)

            Text("GROUP STAGE · MATCHDAY 1 OF 3 · LIVE")
                .font(.archivoNarrow(10, weight: .bold))
                .tracking(2.0)
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 2)

            HStack(spacing: 6) {
                heroStat("104", "Matches")
                heroStat("73%", "AI Hit")
                heroStat("12", "Today")
            }
            .padding(.top, 14)
        }
        .padding(.init(top: 18, leading: 20, bottom: 20, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: [WC.blue, WC.navy, WC.deep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [WC.gold.opacity(0.35), .clear],
                               center: UnitPoint(x: 0.95, y: 0.05),
                               startRadius: 0, endRadius: 180)
                    .allowsHitTesting(false)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WC.gold.opacity(0.4), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [WC.red, WC.gold, WC.blue],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 3)
        }
        .shadow(color: WC.blue.opacity(0.5), radius: 24, x: 0, y: 20)
    }

    private func heroStat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(.anton(22)).foregroundColor(WC.gold)
            Text(l.uppercased())
                .font(.archivoNarrow(8, weight: .bold))
                .tracking(1.8)
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(WC.gold.opacity(0.3), lineWidth: 1))
    }

    // ── Day rail ────────────────────────────────────────────────
    private struct DayItem { let d: String; let n: String; let cnt: String }
    private let days: [DayItem] = [
        .init(d: "FRI", n: "10", cnt: "3 done"),
        .init(d: "TODAY", n: "11", cnt: "12 live"),
        .init(d: "SAT", n: "12", cnt: "8 games"),
        .init(d: "SUN", n: "13", cnt: "12 games"),
        .init(d: "MON", n: "14", cnt: "10 games"),
        .init(d: "TUE", n: "15", cnt: "8 games"),
    ]

    private var dayRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    let active = i == selectedDay
                    Button {
                        Haptics.selection()
                        withAnimation(Pick1Springs.snappy) { selectedDay = i }
                    } label: {
                        VStack(spacing: 2) {
                            Text(day.d)
                                .font(.mono(9, weight: .heavy))
                                .tracking(1.4)
                                .foregroundColor(active ? WC.accentInk : WC.mute)
                            Text(day.n)
                                .font(.anton(18))
                                .foregroundColor(active ? WC.accentInk : WC.ink)
                            Text(day.cnt.uppercased())
                                .font(.mono(8, weight: .heavy))
                                .foregroundColor(active ? WC.accentInk : WC.mute)
                        }
                        .frame(minWidth: 56)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(active ? WC.accent : WC.panel)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(active ? WC.accent : WC.line, lineWidth: 1)
                        )
                        .shadow(color: active ? WC.accent.opacity(0.45) : .clear,
                                radius: active ? 10 : 0, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // ── Section head ────────────────────────────────────────────
    private func sectionHead(title: String, accent: String,
                             metaLive: Bool, meta: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            (Text(title + " ").foregroundColor(WC.ink)
             + Text(accent).foregroundColor(WC.accent))
                .font(.anton(18))
                .tracking(0.4)
            Spacer()
            HStack(spacing: 5) {
                if metaLive {
                    Circle().fill(WC.hot).frame(width: 6, height: 6)
                        .shadow(color: WC.hot, radius: 4)
                }
                Text(meta.uppercased())
                    .font(.archivoNarrow(10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(WC.mute)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    // ── Featured opening match ──────────────────────────────────
    private var featuredMatch: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9)).foregroundColor(WC.gold)
                    Text("GROUP A · SOFI STADIUM")
                        .font(.archivoNarrow(9, weight: .bold))
                        .tracking(2.0).foregroundColor(WC.gold)
                }
                Spacer()
                Text("★★★ TOP LOCK")
                    .font(.archivoNarrow(8, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(WC.navy)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(WC.gold))
            }
            .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 10) {
                featTeam("US", "USA", "FIFA #13 · HOST")
                Text("VS").font(.anton(22)).foregroundColor(WC.gold)
                featTeam("MX", "MEXICO", "FIFA #15 · HOST")
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("▸ AI PREDICTION")
                        .font(.archivoNarrow(8, weight: .bold))
                        .tracking(2.0).foregroundColor(WC.gold)
                    Text("USA TO WIN · O 2.5 GOALS")
                        .font(.anton(16)).foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    (Text("84").font(.anton(26))
                     + Text("%").font(.anton(13)))
                        .foregroundColor(WC.gold)
                    Text("CONFIDENCE")
                        .font(.archivoNarrow(8, weight: .bold))
                        .tracking(2.0).foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(WC.gold.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(WC.gold.opacity(0.4), lineWidth: 1))
        }
        .padding(16)
        .background(
            LinearGradient(colors: [WC.blue.opacity(0.18), WC.navy.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(WC.gold, lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            LinearGradient(colors: [WC.gold, .clear], startPoint: .top, endPoint: .bottom)
                .frame(width: 3)
        }
        .shadow(color: WC.gold.opacity(0.25), radius: 20, x: 0, y: 14)
    }

    private func featTeam(_ code: String, _ name: String, _ rank: String) -> some View {
        VStack(spacing: 6) {
            WCFlag(code: code).frame(width: 56, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 4)
            Text(name).font(.anton(17)).foregroundColor(.white).tracking(0.3)
            Text(rank).font(.mono(8, weight: .heavy)).tracking(0.8)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // ── Today's slate ───────────────────────────────────────────
    private struct MatchRow {
        let time: String; let group: String
        let fav: String; let dog: String
        let favCode: String; let dogCode: String
        let conf: String; let pick: String; let risk: Bool
    }
    private let matches: [MatchRow] = [
        .init(time: "5:00\nPM ET", group: "GROUP A", fav: "COLOMBIA", dog: "UGANDA",
              favCode: "CO", dogCode: "UG", conf: "87%", pick: "COL −2.5", risk: false),
        .init(time: "2:00\nPM ET", group: "GROUP B", fav: "ENGLAND", dog: "JAPAN",
              favCode: "EN", dogCode: "JP", conf: "72%", pick: "ENG ML", risk: false),
        .init(time: "11:00\nAM ET", group: "GROUP C", fav: "BRAZIL", dog: "GHANA",
              favCode: "BR", dogCode: "GH", conf: "79%", pick: "BRA −1.5", risk: false),
        .init(time: "12:00\nPM ET", group: "GROUP D", fav: "FRANCE", dog: "SPAIN",
              favCode: "FR", dogCode: "ES", conf: "58%", pick: "DRAW · U2.5", risk: true),
    ]

    private var matchesList: some View {
        VStack(spacing: 8) {
            ForEach(Array(matches.enumerated()), id: \.offset) { _, m in
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text(m.time).font(.mono(11, weight: .heavy))
                            .foregroundColor(WC.ink)
                            .multilineTextAlignment(.center)
                        Text(m.group).font(.archivoNarrow(8, weight: .bold))
                            .tracking(1.6).foregroundColor(WC.mute)
                    }
                    .frame(width: 52)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(WC.line).frame(width: 1)
                    }
                    .padding(.trailing, 4)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            WCFlag(code: m.favCode).frame(width: 28, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Text(m.fav).font(.archivo(12, weight: .bold))
                                .foregroundColor(WC.accent)
                        }
                        HStack(spacing: 8) {
                            WCFlag(code: m.dogCode).frame(width: 28, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            Text(m.dog).font(.archivo(12, weight: .bold))
                                .foregroundColor(WC.ink)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(m.conf)
                            .font(.mono(11, weight: .heavy))
                            .foregroundColor(m.risk ? Color(hex: "#FF8A90") : WC.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(m.risk ? WC.red.opacity(0.15) : WC.accent.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(m.risk ? WC.red.opacity(0.4) : WC.accent.opacity(0.3), lineWidth: 1)
                            )
                        Text(m.pick).font(.archivoNarrow(8, weight: .bold))
                            .tracking(1.6).foregroundColor(WC.mute)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(WC.panel))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(WC.line, lineWidth: 1))
            }
        }
    }

    // ── Group standings ─────────────────────────────────────────
    private struct GRow { let pos: String; let code: String; let nm: String; let pts: String; let top: Bool }
    private struct GroupBlock { let title: String; let sub: String; let rows: [GRow] }
    private let groups: [GroupBlock] = [
        .init(title: "GROUP A", sub: "USA · MEX", rows: [
            .init(pos: "1", code: "US", nm: "USA", pts: "9", top: true),
            .init(pos: "2", code: "MX", nm: "MEX", pts: "6", top: true),
            .init(pos: "3", code: "CA", nm: "CAN", pts: "4", top: false),
            .init(pos: "4", code: "UG", nm: "UGA", pts: "0", top: false),
        ]),
        .init(title: "GROUP B", sub: "ENG · NED", rows: [
            .init(pos: "1", code: "EN", nm: "ENG", pts: "9", top: true),
            .init(pos: "2", code: "NL", nm: "NED", pts: "7", top: true),
            .init(pos: "3", code: "PT", nm: "POR", pts: "3", top: false),
            .init(pos: "4", code: "JP", nm: "JPN", pts: "1", top: false),
        ]),
        .init(title: "GROUP C", sub: "BRA · GER", rows: [
            .init(pos: "1", code: "BR", nm: "BRA", pts: "9", top: true),
            .init(pos: "2", code: "DE", nm: "GER", pts: "6", top: true),
            .init(pos: "3", code: "AR", nm: "ARG", pts: "4", top: false),
            .init(pos: "4", code: "GH", nm: "GHA", pts: "0", top: false),
        ]),
        .init(title: "GROUP D", sub: "FRA · ESP", rows: [
            .init(pos: "1", code: "FR", nm: "FRA", pts: "7", top: true),
            .init(pos: "2", code: "ES", nm: "ESP", pts: "7", top: true),
            .init(pos: "3", code: "IT", nm: "ITA", pts: "3", top: false),
            .init(pos: "4", code: "IS", nm: "ISL", pts: "0", top: false),
        ]),
    ]

    private var groupGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(g.title).font(.anton(13)).foregroundColor(WC.accent).tracking(0.4)
                        Spacer()
                        Text(g.sub).font(.mono(7, weight: .heavy)).tracking(1.6)
                            .foregroundColor(WC.mute)
                    }
                    .padding(.bottom, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WC.line).frame(height: 1)
                    }
                    ForEach(Array(g.rows.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: 6) {
                            Text(r.pos).font(.anton(11))
                                .foregroundColor(r.top ? WC.accent : WC.mute)
                                .frame(width: 12)
                            WCFlag(code: r.code).frame(width: 16, height: 11)
                                .clipShape(RoundedRectangle(cornerRadius: 1))
                            Text(r.nm).font(.archivo(10, weight: .bold))
                                .foregroundColor(WC.ink)
                            Spacer()
                            Text(r.pts).font(.mono(10, weight: .heavy))
                                .foregroundColor(r.top ? WC.accent : .white.opacity(0.7))
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(WC.panel))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(WC.line, lineWidth: 1))
            }
        }
    }

    // ── Bottom CTA ──────────────────────────────────────────────
    private var bottomCTA: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOLLOW EVERY CALL")
                    .font(.archivoNarrow(8, weight: .bold))
                    .tracking(2.0).foregroundColor(WC.accentInk.opacity(0.7))
                Text("104 MATCHES · FREE")
                    .font(.anton(16)).foregroundColor(WC.accentInk).tracking(0.4)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("JOIN").font(.archivoNarrow(9, weight: .bold))
                    .tracking(2.0).foregroundColor(WC.accentInk)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(WC.accentInk)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(WC.accent))
        .shadow(color: WC.accent.opacity(0.4), radius: 14, x: 0, y: 8)
    }
}

// MARK: - Simplified country flags

/// Lightweight flag renderer matching the design's simplified inline
/// SVG flags. Not heraldically exact — deliberately the same stylized
/// blocks the mock uses so the implementation matches the design.
struct WCFlag: View {
    let code: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            switch code {
            case "US":
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            Rectangle().fill(i % 2 == 0 ? Color(hex: "#BF0A30") : .white)
                        }
                    }
                    Rectangle().fill(Color(hex: "#002868"))
                        .frame(width: w * 0.4, height: h * 0.54)
                }
            case "MX":
                HStack(spacing: 0) {
                    Color(hex: "#006233"); Color.white; Color(hex: "#CE1126")
                }
            case "CO":
                VStack(spacing: 0) {
                    Color(hex: "#FCD116").frame(height: h * 0.5)
                    Color(hex: "#003893").frame(height: h * 0.25)
                    Color(hex: "#CE1126")
                }
            case "UG":
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Color(hex: "#FCD116"); Color(hex: "#CE1126")
                    }
                    Color.black.frame(width: w * 0.34)
                }
            case "EN":
                ZStack {
                    Color.white
                    Rectangle().fill(Color(hex: "#CE1126")).frame(width: w * 0.16)
                    Rectangle().fill(Color(hex: "#CE1126")).frame(height: h * 0.22)
                }
            case "JP":
                ZStack {
                    Color.white
                    Circle().fill(Color(hex: "#BC002D"))
                        .frame(width: h * 0.6, height: h * 0.6)
                }
            case "BR":
                ZStack {
                    Color(hex: "#FEDF00")
                    Diamond().fill(Color(hex: "#009B3A"))
                        .frame(width: w * 0.72, height: h * 0.78)
                    Circle().fill(Color(hex: "#002776"))
                        .frame(width: h * 0.42, height: h * 0.42)
                }
            case "GH":
                VStack(spacing: 0) { Color.black; Color(hex: "#CE1126"); Color(hex: "#FCD116") }
            case "FR":
                HStack(spacing: 0) { Color(hex: "#0055A4"); Color.white; Color(hex: "#EF4135") }
            case "ES":
                VStack(spacing: 0) {
                    Color(hex: "#AA151B").frame(height: h * 0.25)
                    Color(hex: "#F1BF00")
                    Color(hex: "#AA151B").frame(height: h * 0.25)
                }
            case "CA":
                ZStack {
                    Color.white
                    HStack(spacing: 0) {
                        Color(hex: "#D52B1E").frame(width: w * 0.25)
                        Spacer()
                        Color(hex: "#D52B1E").frame(width: w * 0.25)
                    }
                }
            case "NL":
                VStack(spacing: 0) { Color(hex: "#AE1C28"); Color.white; Color(hex: "#21468B") }
            case "PT":
                ZStack(alignment: .leading) {
                    Color(hex: "#FF0000")
                    Color(hex: "#006600").frame(width: w * 0.4)
                }
            case "DE":
                VStack(spacing: 0) { Color.black; Color(hex: "#DD0000"); Color(hex: "#FFCE00") }
            case "AR":
                VStack(spacing: 0) { Color(hex: "#75AADB"); Color.white; Color(hex: "#75AADB") }
            case "IT":
                HStack(spacing: 0) { Color(hex: "#009246"); Color.white; Color(hex: "#CE2B37") }
            case "IS":
                VStack(spacing: 0) {
                    Color(hex: "#EF2B2D"); Color(hex: "#0072CE"); Color.white
                }
            default:
                Color(hex: "#2A2A2E")
            }
        }
    }
}

/// Diamond used by the Brazil flag.
private struct Diamond: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}
