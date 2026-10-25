import Foundation

struct P1BookQuote {
    let odds: Double
    let source: String
    static func forPick(_ pick: Pick) -> Self? {
        if let best = pick.oddsBooks?.filter({ $0.odds.isFinite && $0.odds > 1 }).max(by: { $0.odds < $1.odds }) {
            return Self(odds: best.odds, source: best.book)
        }
        if let odds = pick.marketOdds, odds.isFinite, odds > 1 {
            return Self(odds: odds, source: pick.oddsSource ?? "Market")
        }
        return nil
    }
}


// Calendar dates in the same timezone used by the prediction worker.
enum P1BookDays {
    static var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }
    static func key(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    static func dates(picks: [Pick], now: Date = Date()) -> [String] {
        let today = key(now)
        let base = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: now).map { key($0) } }
        return Array(Set(base + picks.map(\.gameDate).filter { $0 >= today })).sorted()
    }
    static func label(_ day: String, now: Date = Date()) -> String {
        if day == key(now) { return "Today" }
        if day == key(calendar.date(byAdding: .day, value: 1, to: now)!) { return "Tomorrow" }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: day) else { return day }
        f.dateFormat = "EEE d"; return f.string(from: date)
    }
}
