import SwiftUI

// MARK: Odds tab
// The market's game lines (spread, total, to win) laid out like a scores
// app's odds board, with PICK1's side of each market lit in green, then every
// market PICK1 called on the game with its price and, after the final, its
// result. The card on top adds it up: how many calls won and what they paid
// on a $100-a-pick basis. Prices are context only: no bookmaker logo, link or
// bet button, PICK1 tracks predictions.

nonisolated struct P1GameLines: Sendable {
    var provider: String?
    var awaySpread: Double?
    var homeSpread: Double?
    var awaySpreadOdds: Int?
    var homeSpreadOdds: Int?
    var total: Double?
    var overOdds: Int?
    var underOdds: Int?
    var awayMoneyline: Int?
    var homeMoneyline: Int?

    var isEmpty: Bool { awayMoneyline == nil && total == nil && awaySpread == nil }

    static func parse(_ d: [String: Any]) -> P1GameLines? {
        guard let pc = (d["pickcenter"] as? [[String: Any]])?.first else { return nil }
        func int(_ v: Any?) -> Int? { (v as? NSNumber).map { Int($0.doubleValue.rounded()) } }
        var l = P1GameLines()
        l.provider = (pc["provider"] as? [String: Any])?["name"] as? String
        let away = pc["awayTeamOdds"] as? [String: Any] ?? [:]
        let home = pc["homeTeamOdds"] as? [String: Any] ?? [:]
        l.awayMoneyline = int(away["moneyLine"])
        l.homeMoneyline = int(home["moneyLine"])
        l.awaySpreadOdds = int(away["spreadOdds"])
        l.homeSpreadOdds = int(home["spreadOdds"])
        if let spread = (pc["spread"] as? NSNumber)?.doubleValue {
            let s = abs(spread)
            let awayFav = (away["favorite"] as? Bool) ?? false
            l.awaySpread = awayFav ? -s : s
            l.homeSpread = awayFav ? s : -s
        }
        l.total = (pc["overUnder"] as? NSNumber)?.doubleValue
        l.overOdds = int(pc["overOdds"])
        l.underOdds = int(pc["underOdds"])
        return l.isEmpty ? nil : l
    }
}

enum P1Odds {
    static func american(_ decimal: Double) -> String {
        guard decimal > 1 else { return "" }
        return decimal >= 2 ? "+\(Int(((decimal - 1) * 100).rounded()))" : "\(Int((-100 / (decimal - 1)).rounded()))"
    }
    static func american(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
    static func decimal(fromAmerican a: Int) -> Double { a > 0 ? 1 + Double(a) / 100 : 1 + 100 / Double(-a) }
    static func line(_ v: Double) -> String {
        let s = v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
        return v > 0 ? "+" + s : s
    }
    static func money(_ v: Double) -> String {
        (v >= 0 ? "+" : "-") + abs(v).formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

/// One call PICK1 made on this game: the main pick or one of its projections.
struct P1Call: Identifiable {
    let id: String
    let market: String
    let selection: String
    let decimal: Double?
    let isMarketPrice: Bool
    let probability: Int?
    let result: Bool?   // nil while pending or when the market cannot be graded
    let gradable: Bool

    var payout: Double? {
        guard let result, let decimal else { return nil }
        return result ? 100 * (decimal - 1) : -100
    }
}

enum P1CallGrader {
    private static func number(in s: String) -> Double? {
        let pattern = #"[+-]?\d+(\.\d+)?"#
        guard let r = s.range(of: pattern, options: .regularExpression) else { return nil }
        return Double(s[r])
    }

    /// Which team a free text names: "49ERS +1.5", "Levski Sofia win".
    private static func side(in text: String, game: P1Game) -> P1GameSide? {
        let t = " " + text.lowercased().replacingOccurrences(of: ".", with: " ") + " "
        func hit(_ s: P1GameSide) -> Bool {
            [s.name, s.short].contains { $0.count > 2 && t.contains(" " + $0.lowercased()) }
                || (s.code.count >= 2 && t.contains(" " + s.code.lowercased() + " "))
        }
        let h = hit(game.home), a = hit(game.away)
        return h == a ? nil : (h ? game.home : game.away)
    }

    /// True won, false lost, nil not decided (pending, push, or a market we
    /// cannot read from the final score and box score).
    static func grade(label: String, value: String, game: P1Game, extras: P1GameExtras?) -> (Bool?, Bool) {
        let l = label.lowercased(), v = value.lowercased()
        let over = v.hasPrefix("over") || v.hasPrefix("o ")
        let under = v.hasPrefix("under") || v.hasPrefix("u ")
        let yes = v.hasPrefix("yes"), no = v.hasPrefix("no")
        let final = game.phase == .final
        let hs = Double(game.home.score ?? 0), aws = Double(game.away.score ?? 0)
        func ou(_ actual: Double, _ line: Double?) -> Bool? {
            guard let line, actual != line else { return nil }
            return over ? actual > line : under ? actual < line : nil
        }

        if ["moneyline winner", "winner", "match winner", "match result"].contains(l), !v.contains(where: \.isNumber) {
            guard let s = side(in: value, game: game) else { return (nil, false) }
            guard final, hs != aws else { return (nil, true) }
            return ((s.name == game.home.name) == (hs > aws), true)
        }
        if l.contains("team total"), over || under, let team = side(in: label, game: game) {
            guard final else { return (nil, true) }
            return (ou(team.name == game.home.name ? hs : aws, number(in: value) ?? number(in: label)), true)
        }
        if l.contains("spread") || l.contains("handicap") || l.contains("run line") || l.contains("puck line") {
            guard let s = side(in: value, game: game), let line = number(in: value) else { return (nil, false) }
            guard final else { return (nil, true) }
            let margin = (s.name == game.home.name ? hs - aws : aws - hs) + line
            return (margin == 0 ? nil : margin > 0, true)
        }
        if l.contains("both teams score"), yes || no, let n = number(in: label) {
            guard final else { return (nil, true) }
            let both = hs >= n && aws >= n
            return (yes ? both : !both, true)
        }
        if l.hasPrefix("total") || l.contains(" total points") || l.contains("total goals") || l.contains("total runs"), over || under {
            guard final else { return (nil, true) }
            return (ou(hs + aws, number(in: value) ?? number(in: label)), true)
        }
        // Player lines, read from the box score: "Brock Purdy passing yards O/U 245.5".
        let stats: [(String, String?, String)] = [
            ("passing yards", "passing", "YDS"), ("rushing yards", "rushing", "YDS"), ("receiving yards", "receiving", "YDS"),
            ("passing touchdowns", "passing", "TD"), ("receptions", "receiving", "REC"),
            ("points", nil, "PTS"), ("rebounds", nil, "REB"), ("assists", nil, "AST"),
        ]
        if over || under, let stat = stats.first(where: { l.contains($0.0) }) {
            guard final else { return (nil, true) }
            guard let extras else { return (nil, true) }
            let groups = (extras.awayBox + extras.homeBox).filter { g in stat.1 == nil || g.title.lowercased().contains(stat.1!) }
            for g in groups {
                guard let col = g.labels.firstIndex(of: stat.2) else { continue }
                for row in g.rows {
                    let last = row.name.split(separator: " ").last.map { String($0).lowercased() } ?? ""
                    guard last.count > 2, l.contains(last), col < row.stats.count else { continue }
                    let raw = row.stats[col].split(separator: "-").first.map(String.init) ?? row.stats[col]
                    guard let actual = Double(raw) else { continue }
                    return (ou(actual, number(in: value) ?? number(in: label)), true)
                }
            }
            return (nil, true)
        }
        return (nil, false)
    }

    static func calls(pick: Pick, game: P1Game, extras: P1GameExtras?) -> [P1Call] {
        var out: [P1Call] = []
        let main = grade(label: "Winner", value: pick.pick, game: game, extras: extras)
        let mainResult: Bool? = pick.isPending ? main.0 : (pick.isWin ? true : pick.isLoss ? false : nil)
        out.append(P1Call(id: "main", market: "To win", selection: pick.displayPick,
                          decimal: pick.marketOdds.flatMap { $0 > 1 ? $0 : nil } ?? pick.decimalOdds,
                          isMarketPrice: (pick.marketOdds ?? 0) > 1, probability: Int(pick.probability.rounded()),
                          result: mainResult, gradable: true))
        for (i, prop) in (pick.bettingProps ?? []).enumerated() {
            let l = prop.label.lowercased()
            // The full-game winner projection is the main call again.
            if ["moneyline winner", "winner", "match winner"].contains(l) { continue }
            let g = grade(label: prop.label, value: prop.value, game: game, extras: extras)
            let quote = prop.quotedOdds
            out.append(P1Call(id: "p\(i)", market: prop.label, selection: prop.value,
                              decimal: quote?.value, isMarketPrice: quote?.isMarket ?? false,
                              probability: prop.probability, result: g.0, gradable: g.1))
        }
        return out
    }
}

struct P1OddsTab: View {
    let game: P1Game
    let pick: Pick?
    let locked: Bool
    let extras: P1GameExtras?
    var offer = P1Offer()
    var onUnlock: () -> Void = {}

    private var lines: P1GameLines? { extras?.lines }
    private var calls: [P1Call] {
        guard let pick, !locked else { return [] }
        return P1CallGrader.calls(pick: pick, game: game, extras: extras)
    }

    var body: some View {
        VStack(spacing: 14) {
            if let pick, locked {
                let all = P1CallGrader.calls(pick: pick, game: game, extras: extras)
                let upside = all.compactMap { $0.decimal.map { 100 * ($0 - 1) } }.reduce(0, +)
                card {
                    Label("PICK1 on this game", systemImage: "lock.fill").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color.p1Lime)
                    Text("\(all.count) calls, \(P1Odds.money(upside)) if they all hit")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    Text("Premium lights up PICK1's side of every market below, then grades each one at the final whistle.")
                        .font(.system(size: 14)).foregroundStyle(P1Board.secondary)
                    Button(action: onUnlock) {
                        Text(offer.cta).font(.system(size: 17, weight: .bold)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 50).background(Capsule().fill(Color.p1Lime))
                    }.buttonStyle(PressableButtonStyle())
                    if !offer.terms.isEmpty {
                        Text(offer.terms).font(.system(size: 12)).foregroundStyle(P1Board.secondary).frame(maxWidth: .infinity)
                    }
                }
            } else if !calls.isEmpty {
                totalCard
                if let pick, pick.isPending, game.phase != .final {
                    P1PlaceButton(calls.count > 1 ? "Place PICK1's \(calls.count) calls" : "Place this pick",
                                  selections: calls.map { c in
                                      P1Selection(id: c.id, market: c.market, value: c.selection, probability: c.probability,
                                                  game: "\(game.away.short) @ \(game.home.short)",
                                                  books: c.id == "main" ? (pick.oddsBooks ?? [])
                                                    : (pick.bettingProps?.first { $0.label == c.market && $0.value == c.selection }?.oddsBooks ?? []))
                                  }, source: "game_odds")
                }
            }
            if let lines { gameLines(lines) }
            if !calls.isEmpty {
                card {
                    Text("PICK1 calls").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    ForEach(calls) { call in
                        callRow(call)
                        if call.id != calls.last?.id { Rectangle().fill(P1Board.pill).frame(height: 1) }
                    }
                }
            }
            if lines == nil && pick == nil {
                card { Text("No market prices for this game yet.").font(.system(size: 14)).foregroundStyle(P1Board.secondary) }
            }
            Text("Market prices shown for context\(lines?.provider.map { ", current game lines from \($0) via ESPN" } ?? ""). Each PICK1 call carries the price when it was published. Returns on a $100-a-pick basis. PICK1 is a prediction tracker, not a sportsbook.")
                .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
        }
    }

    // MARK: Total

    private var totalCard: some View {
        let decided = calls.filter { $0.result != nil }
        let won = decided.filter { $0.result == true }
        let net = decided.compactMap(\.payout).reduce(0, +)
        let pendingUpside = calls.filter { $0.result == nil && $0.gradable }.compactMap { $0.decimal.map { 100 * ($0 - 1) } }.reduce(0, +)
        let estimated = calls.contains { !$0.isMarketPrice }
        return card {
            HStack(alignment: .firstTextBaseline) {
                Text("PICK1 on this game").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text("\(calls.count) calls").font(.system(size: 13)).foregroundStyle(P1Board.secondary)
            }
            if decided.isEmpty {
                Text(game.phase == .final ? "These markets cannot be graded from the box score yet." : "If every call hits")
                    .font(.system(size: 13)).foregroundStyle(P1Board.secondary)
                Text(P1Odds.money(pendingUpside)).font(.system(size: 34, weight: .bold)).foregroundStyle(Color.p1Lime).monospacedDigit()
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(P1Odds.money(net)).font(.system(size: 34, weight: .bold))
                        .foregroundStyle(net >= 0 ? Color.p1Lime : Color.p1Red).monospacedDigit()
                    Text("\(won.count) of \(decided.count) won").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }
                if decided.count < calls.count {
                    Text("\(calls.count - decided.count) more still open or not gradable").font(.system(size: 12)).foregroundStyle(P1Board.secondary)
                }
            }
            Text("$100 on each PICK1 call\(estimated ? ", estimated prices where no market quote was found" : "").")
                .font(.system(size: 11)).foregroundStyle(P1Board.secondary)
        }
    }

    // MARK: Game lines

    private func gameLines(_ l: P1GameLines) -> some View {
        let showPick = pick != nil && !locked
        let pickHome = showPick && P1GameMatch.same(game.home, pick!.pick, sport: game.sport)
        let pickAway = showPick && P1GameMatch.same(game.away, pick!.pick, sport: game.sport)
        let props = showPick ? (pick!.bettingProps ?? []) : []
        let spreadProp = props.first { $0.label.lowercased().contains("spread") }
        let spreadSide = spreadProp.flatMap { p in sideName(in: p.value) }
        let totalProp = props.first { p in let x = p.label.lowercased(); return x.hasPrefix("total") && !x.contains("team") }
        let totalOver = totalProp.map { $0.value.lowercased().hasPrefix("o") }
        func graded(_ p: BettingProp?) -> Bool? { p.flatMap { P1CallGrader.grade(label: $0.label, value: $0.value, game: game, extras: extras).0 } }
        let mlResult = calls.first?.result, spreadResult = graded(spreadProp), totalResult = graded(totalProp)
        return card {
            HStack {
                Text("Game lines").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Spacer()
                ForEach(["Spread", "Total", "To win"], id: \.self) { h in
                    Text(h).font(.system(size: 12)).foregroundStyle(P1Board.secondary).frame(width: 64)
                }
            }
            lineRow(game.away, spread: l.awaySpread, spreadOdds: l.awaySpreadOdds, totalTop: l.total.map { "O \(P1Odds.line($0).replacingOccurrences(of: "+", with: ""))" },
                    totalOdds: l.overOdds, ml: l.awayMoneyline,
                    spreadOn: spreadSide == game.away.name, totalOn: totalOver == true, mlOn: pickAway,
                    results: (spreadResult, totalResult, mlResult))
            lineRow(game.home, spread: l.homeSpread, spreadOdds: l.homeSpreadOdds, totalTop: l.total.map { "U \(P1Odds.line($0).replacingOccurrences(of: "+", with: ""))" },
                    totalOdds: l.underOdds, ml: l.homeMoneyline,
                    spreadOn: spreadSide == game.home.name, totalOn: totalOver == false, mlOn: pickHome,
                    results: (spreadResult, totalResult, mlResult))
            if showPick {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.p1Lime).frame(width: 10, height: 10)
                    Text("PICK1's side").font(.system(size: 11)).foregroundStyle(P1Board.secondary)
                }
            }
        }
    }

    private func sideName(in text: String) -> String? {
        let t = text.lowercased()
        let h = [game.home.short, game.home.name, game.home.code].contains { $0.count > 1 && t.contains($0.lowercased()) }
        let a = [game.away.short, game.away.name, game.away.code].contains { $0.count > 1 && t.contains($0.lowercased()) }
        return h == a ? nil : (h ? game.home.name : game.away.name)
    }

    private func lineRow(_ side: P1GameSide, spread: Double?, spreadOdds: Int?, totalTop: String?, totalOdds: Int?, ml: Int?,
                         spreadOn: Bool, totalOn: Bool, mlOn: Bool, results: (Bool?, Bool?, Bool?)) -> some View {
        HStack(spacing: 8) {
            Text(side.code).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            cell(top: spread.map(P1Odds.line), bottom: spreadOdds.map(P1Odds.american), on: spreadOn, result: spreadOn ? results.0 : nil)
            cell(top: totalTop, bottom: totalOdds.map(P1Odds.american), on: totalOn, result: totalOn ? results.1 : nil)
            cell(top: nil, bottom: ml.map(P1Odds.american), on: mlOn, result: mlOn ? results.2 : nil)
        }
    }

    /// The price box: line on top, price under it; lime when it is PICK1's side.
    private func cell(top: String?, bottom: String?, on: Bool, result: Bool? = nil) -> some View {
        VStack(spacing: 1) {
            if let top { Text(top).font(.system(size: 12)).foregroundStyle(on ? Color.p1Lime.opacity(0.85) : P1Board.secondary) }
            Text(bottom ?? "–").font(.system(size: 14, weight: .bold)).foregroundStyle(on ? Color.p1Lime : .white)
        }
        .monospacedDigit()
        .frame(width: 64, height: 46)
        .background(RoundedRectangle(cornerRadius: 10).fill(on ? Color.p1Lime.opacity(0.14) : P1Board.pill))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(on ? Color.p1Lime : .clear, lineWidth: 1.2))
        .overlay(alignment: .topTrailing) {
            if let result {
                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 13)).foregroundStyle(result ? Color.p1Lime : Color.p1Red)
                    .background(Circle().fill(Color.black)).offset(x: 5, y: -5)
            }
        }
    }

    // MARK: Calls

    private func callRow(_ call: P1Call) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(call.market).font(.system(size: 13)).foregroundStyle(P1Board.secondary).lineLimit(2)
                Text(call.selection).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                Group {
                    if let r = call.result, let pay = call.payout {
                        Text((r ? "Won · " : "Lost · ") + P1Odds.money(pay)).foregroundStyle(r ? Color.p1Lime : Color.p1Red)
                    } else if game.phase == .final && !call.gradable {
                        Text("Result not graded").foregroundStyle(P1Board.secondary)
                    } else if let d = call.decimal {
                        Text("Pays " + P1Odds.money(100 * (d - 1)) + " on $100" + (call.probability.map { " · model \($0)%" } ?? ""))
                            .foregroundStyle(P1Board.secondary)
                    }
                }.font(.system(size: 12, weight: .semibold))
            }
            Spacer()
            VStack(spacing: 2) {
                cell(top: nil, bottom: call.decimal.map(P1Odds.american), on: true, result: call.result)
                if !call.isMarketPrice && call.decimal != nil {
                    Text("est.").font(.system(size: 9)).foregroundStyle(P1Board.secondary)
                }
            }
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(RoundedRectangle(cornerRadius: P1Board.radius).fill(P1Board.card))
            .overlay(RoundedRectangle(cornerRadius: P1Board.radius).strokeBorder(P1Board.edge))
    }
}
