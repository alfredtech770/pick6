import SwiftUI

// MARK: Spread banner
// Cross promotion for Spread, the sports prop firm (thesharpfund.fly.dev):
// pass a challenge, bet the firm's money, keep up to 80% of the profit.
// Spread's own brand on purpose (black, green #3DFF9A, SPREAD wordmark) so it
// reads as a partner product, not as a PICK1 feature. Dismissable.
// Switched remotely: on while the "spread" row in Supabase affiliate_partners is enabled
// (P1AffiliateStore.spreadOn). Turning that row off hides every Spread surface at once,
// without a release. The -previewSpreadBanner launch arg forces it on in Debug builds only.

enum P1SpreadPromo {
    @MainActor static var enabled: Bool {
        #if DEBUG
        if CommandLine.arguments.contains("-previewSpreadBanner") { return true }
        #endif
        return P1AffiliateStore.shared.spreadOn
    }
    static let url = URL(string: "https://thesharpfund.fly.dev/p1?utm_source=pick1&utm_medium=app&utm_campaign=banner")!
    /// The free first bet: one pick on a $10K account, no fee. Spread's own numbers (src/freebet.js).
    static let winPct = 50, lossPct = 35, maxStake = 500.0
    /// The odds Spread takes on a single (LIMITS in Spread's rules.js): -300 to +1000.
    static func takes(_ odds: Double) -> Bool { odds >= 1.3333 && odds <= 11.0 }
    static func winLink(campaign: String) -> URL {
        URL(string: "https://thesharpfund.fly.dev/p1?utm_source=pick1&utm_medium=app&utm_campaign=\(campaign)")!
    }

    /// "Place this pick" hands the pick itself to Spread: /p1 finds the same game on
    /// Spread's board, and once the user has a Challenge the pick waits in their bet slip.
    /// One winner pick only; a watchlist or a plain game opens the general offer.
    static func link(for selections: [P1Selection]) -> URL {
        guard selections.count == 1, let s = selections.first,
              let home = s.spreadHome, let away = s.spreadAway, let pick = s.spreadPick,
              var c = URLComponents(string: "https://thesharpfund.fly.dev/p1") else { return url }
        c.queryItems = [
            URLQueryItem(name: "h", value: home), URLQueryItem(name: "a", value: away), URLQueryItem(name: "p", value: pick),
            URLQueryItem(name: "utm_source", value: "pick1"), URLQueryItem(name: "utm_medium", value: "app"), URLQueryItem(name: "utm_campaign", value: "place_pick"),
        ]
        return c.url ?? url
    }
}

/// Compact version for the bet sheet: the same offer, one row.
struct P1SpreadSlipCard: View {
    var url: URL = P1SpreadPromo.url
    @Environment(\.openURL) private var openURL
    private let green = Color(hex: "#3DFF9A")

    var body: some View {
        Button {
            Analytics.track("spread_cta_tapped", ["source": "bet_sheet", "pick": url.path == "/p1"])
            openURL(url)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image("SpreadWordmark").resizable().renderingMode(.template).scaledToFit()
                            .frame(height: 10).foregroundStyle(.white.opacity(0.9))
                        Text("NEW").font(.system(size: 8, weight: .heavy)).tracking(0.7)
                            .foregroundStyle(Color(hex: "#03140A")).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(green, in: Capsule())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Your first bet is").font(.system(size: 17, weight: .heavy)).foregroundStyle(.white)
                        Text("free").font(.system(size: 26, weight: .black)).foregroundStyle(green)
                    }
                    Text("One pick on a $10,000 account. No fee, no card.")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right.circle.fill").font(.system(size: 28)).foregroundStyle(green)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                ZStack {
                    Color(hex: "#0B0D0C")
                    RadialGradient(colors: [green.opacity(0.25), .clear], center: .trailing, startRadius: 4, endRadius: 200)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(green.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Spread")
    }
}

struct P1SpreadBanner: View {
    @Environment(\.openURL) private var openURL
    var onOpen: (() -> Void)? = nil
    var onClose: () -> Void = {}

    private let green = Color(hex: "#3DFF9A")
    private let ink = Color(hex: "#03140A")

    var body: some View {
        Button { if let onOpen { onOpen() } else { openURL(P1SpreadPromo.url) } } label: {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image("SpreadWordmark").resizable().renderingMode(.template).scaledToFit()
                                .frame(height: 13).foregroundStyle(.white)
                            Text("NEW").font(.system(size: 9, weight: .heavy)).tracking(0.8)
                                .foregroundStyle(ink).padding(.horizontal, 6).padding(.vertical, 3)
                                .background(green, in: Capsule())
                        }
                        Text("Your first bet is")
                            .font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                            .padding(.top, 4)
                        Text("FREE")
                            .font(.system(size: 44, weight: .black)).foregroundStyle(green)
                            .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
                            .shadow(color: green.opacity(0.35), radius: 12)
                        Text("One pick on a $10,000 account. No fee, no card.")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 14) {
                        equityCurve.frame(width: 70, height: 96)
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 30)).foregroundStyle(green)
                    }
                }
                .padding(.leading, 18).padding(.trailing, 14).padding(.vertical, 16)

                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55)).frame(width: 30, height: 30)
                }
                .buttonStyle(.plain).accessibilityLabel("Hide")
            }
            .background(
                ZStack {
                    Color(hex: "#0B0D0C")
                    RadialGradient(colors: [green.opacity(0.28), .clear], center: .bottomTrailing, startRadius: 4, endRadius: 220)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(green.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Spread")
    }

    /// A funded account climbing past its profit target.
    private var equityCurve: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pts: [CGFloat] = [0.78, 0.70, 0.74, 0.58, 0.62, 0.46, 0.50, 0.34, 0.22, 0.12]
            let path = Path { p in
                for (i, y) in pts.enumerated() {
                    let pt = CGPoint(x: w * CGFloat(i) / CGFloat(pts.count - 1), y: h * y)
                    i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                }
            }
            ZStack(alignment: .topLeading) {
                Path { p in p.move(to: CGPoint(x: 0, y: h * 0.2)); p.addLine(to: CGPoint(x: w, y: h * 0.2)) }
                    .stroke(green.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                Text("TARGET").font(.system(size: 7.5, weight: .heavy)).tracking(0.6)
                    .foregroundStyle(green.opacity(0.7)).offset(x: 0, y: h * 0.2 - 12)
                path.stroke(green, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                    .shadow(color: green.opacity(0.6), radius: 6)
                Circle().fill(green).frame(width: 7, height: 7)
                    .position(x: w, y: h * pts.last!)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Spread pick card
// In "Place this pick": asks Spread (/api/p1/check) whether it offers this exact game and at
// what price. When it does, the card names the pick and Spread's live price and opens /p1,
// where the pick waits in the bet slip. When it does not (or the check fails), the general
// offer card shows instead, so the sheet never shows a pick Spread cannot take.

struct P1SpreadQuote: Decodable, Equatable {
    let ok: Bool
    let odds: Double?
    let label: String?
    let game: String?
}

struct P1SpreadPickCard: View {
    let selection: P1Selection
    @Environment(\.openURL) private var openURL
    @State private var quote: P1SpreadQuote?
    private let green = Color(hex: "#3DFF9A")
    private let ink = Color(hex: "#03140A")

    private var link: URL { P1SpreadPromo.link(for: [selection]) }

    var body: some View {
        Group {
            if let q = quote, q.ok, let odds = q.odds {
                pickCard(label: q.label ?? selection.value, odds: odds)
            } else {
                P1SpreadSlipCard(url: link)
            }
        }
        .task(id: selection.id) { await check() }
    }

    private func check() async {
        guard let home = selection.spreadHome, let away = selection.spreadAway, let pick = selection.spreadPick,
              var c = URLComponents(string: "https://thesharpfund.fly.dev/api/p1/check") else { quote = P1SpreadQuote(ok: false, odds: nil, label: nil, game: nil); return }
        c.queryItems = [URLQueryItem(name: "h", value: home), URLQueryItem(name: "a", value: away), URLQueryItem(name: "p", value: pick)]
        guard let u = c.url else { return }
        var req = URLRequest(url: u); req.timeoutInterval = 4
        let q = (try? await URLSession.shared.data(for: req)).flatMap { try? JSONDecoder().decode(P1SpreadQuote.self, from: $0.0) }
        withAnimation(.easeOut(duration: 0.2)) { quote = q ?? P1SpreadQuote(ok: false, odds: nil, label: nil, game: nil) }
    }

    private func pickCard(label: String, odds: Double) -> some View {
        let stake = P1SpreadPromo.maxStake
        let win = (stake * (odds - 1)).rounded()
        return Button {
            Analytics.track("spread_cta_tapped", ["source": "bet_sheet", "pick": true, "priced": true, "free_bet": true])
            openURL(link)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image("SpreadWordmark").resizable().renderingMode(.template).scaledToFit()
                        .frame(height: 10).foregroundStyle(.white.opacity(0.9))
                    Text("FREE BET").font(.system(size: 8, weight: .heavy)).tracking(0.7)
                        .foregroundStyle(ink).padding(.horizontal, 5).padding(.vertical, 2)
                        .background(green, in: Capsule())
                    Spacer()
                    Text("No fee, no card").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bet this pick free on Spread").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                        Text(label).font(.system(size: 19, weight: .heavy)).foregroundStyle(.white)
                            .lineLimit(2).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.2f", odds)).font(.system(size: 26, weight: .black)).foregroundStyle(green).monospacedDigit()
                        Text("LIVE PRICE").font(.system(size: 8, weight: .heavy)).tracking(0.6).foregroundStyle(.white.opacity(0.5))
                    }
                }
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("$\(Int(stake)) wins $\(Int(win).formatted())")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white).monospacedDigit()
                        Text("Win it: \(P1SpreadPromo.winPct)% off a funded Challenge")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(green.opacity(0.85))
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 5) {
                        Text("Bet it free").font(.system(size: 14, weight: .heavy))
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundStyle(ink).padding(.horizontal, 14).padding(.vertical, 9)
                    .background(green, in: Capsule())
                }
                .padding(.top, 2)
            }
            .padding(16)
            .background(
                ZStack {
                    Color(hex: "#0B0D0C")
                    RadialGradient(colors: [green.opacity(0.22), .clear], center: .topTrailing, startRadius: 4, endRadius: 220)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(green.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Spread with this pick in the bet slip, free")
    }
}

// MARK: Spread win card
// After a PICK1 pick wins: the proof, in Spread's terms. "Celtics won. $500 on Spread was +$140.
// Your next pick is free." Only for a win at a price Spread takes, so the number is one a trader
// could really have made there. Shown on the home board in place of the general banner, once per
// win: closing it hides that win and brings the banner back.

struct P1SpreadWinCard: View {
    let pick: Pick
    var onClose: () -> Void = {}
    @Environment(\.openURL) private var openURL
    private let green = Color(hex: "#3DFF9A")
    private let ink = Color(hex: "#03140A")

    private var profit: Int { Int((P1SpreadPromo.maxStake * (pick.decimalOdds - 1)).rounded()) }
    private var score: String? {
        guard let h = pick.homeScore, let a = pick.awayScore else { return nil }
        return "\(pick.awayTeam) \(a) - \(h) \(pick.homeTeam)"
    }

    var body: some View {
        Button {
            Analytics.track("spread_cta_tapped", ["source": "win_card", "free_bet": true])
            openURL(P1SpreadPromo.winLink(campaign: "win_card"))
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(green)
                        Text("PICK1 CALLED IT").font(.system(size: 10, weight: .heavy)).tracking(0.8).foregroundStyle(green)
                        if let score { Text("· \(score)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.55)).lineLimit(1) }
                    }
                    Text("\(pick.displayPick) won.")
                        .font(.system(size: 22, weight: .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("+$\(profit.formatted())").font(.system(size: 34, weight: .black)).foregroundStyle(green).monospacedDigit()
                            .shadow(color: green.opacity(0.35), radius: 10)
                        Text("on a $\(Int(P1SpreadPromo.maxStake)) Spread bet").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                    }
                    HStack(spacing: 10) {
                        Image("SpreadWordmark").resizable().renderingMode(.template).scaledToFit()
                            .frame(height: 10).foregroundStyle(.white.opacity(0.85))
                        Spacer(minLength: 0)
                        HStack(spacing: 5) {
                            Text("Your next pick is free").font(.system(size: 14, weight: .heavy))
                            Image(systemName: "arrow.right").font(.system(size: 12, weight: .heavy))
                        }
                        .foregroundStyle(ink).padding(.horizontal, 14).padding(.vertical, 9)
                        .background(green, in: Capsule())
                    }
                    .padding(.top, 2)
                }
                .padding(16)

                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55)).frame(width: 30, height: 30)
                }
                .buttonStyle(.plain).accessibilityLabel("Hide")
            }
            .background(
                ZStack {
                    Color(hex: "#0B0D0C")
                    RadialGradient(colors: [green.opacity(0.26), .clear], center: .topTrailing, startRadius: 4, endRadius: 240)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(green.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Spread for a free bet")
    }
}
