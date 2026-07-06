// Pick1PickWidget.swift
// Home-screen widget: today's highest-confidence pick. Fetches directly
// from Supabase's public REST endpoint in the timeline provider — the
// picks table is a public "select using (true)" ledger, so no App Group /
// shared container / signing capability is needed (a network fetch in the
// widget process is enough). Refreshes a few times a day.

import WidgetKit
import SwiftUI

private let wlime = Color(red: 0.831, green: 1.0, blue: 0.227)
private let wink  = Color(red: 0.027, green: 0.031, blue: 0.039)

// MARK: - Model + fetch

struct WidgetPick: Decodable {
    let pick: String
    let sport: String
    let league: String
    let probability: Int
    let home_team: String?
    let away_team: String?
}

struct PickEntry: TimelineEntry {
    let date: Date
    let pick: WidgetPick?
}

private enum PickFetcher {
    static let base = "https://lgnjawngkiamlngcffrk.supabase.co/rest/v1/picks"
    static let anon = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxnbmphd25na2lhbWxuZ2NmZnJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczNzE5MTIsImV4cCI6MjA5Mjk0NzkxMn0.JgIspzgxL3YaMuq_I5gdvh67AJN09kimJSOnM_uJaD4"

    static func todaysTopPick() async -> WidgetPick? {
        let today = ISO8601DateFormatter.dateOnly.string(from: Date())
        var comps = URLComponents(string: base)!
        comps.queryItems = [
            .init(name: "select", value: "pick,sport,league,probability,home_team,away_team"),
            .init(name: "game_date", value: "gte.\(today)"),
            .init(name: "result", value: "eq.pending"),
            .init(name: "order", value: "probability.desc"),
            .init(name: "limit", value: "1"),
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let rows = try? JSONDecoder().decode([WidgetPick].self, from: data)
        else { return nil }
        return rows.first
    }
}

private extension ISO8601DateFormatter {
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()
}

// MARK: - Timeline

struct PickProvider: TimelineProvider {
    func placeholder(in context: Context) -> PickEntry {
        PickEntry(date: Date(), pick: WidgetPick(pick: "Celtics ML", sport: "basketball",
                  league: "NBA", probability: 81, home_team: "Celtics", away_team: "Lakers"))
    }

    func getSnapshot(in context: Context, completion: @escaping (PickEntry) -> Void) {
        Task { completion(PickEntry(date: Date(), pick: await PickFetcher.todaysTopPick())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PickEntry>) -> Void) {
        Task {
            let pick = await PickFetcher.todaysTopPick()
            // Refresh every ~3h — the daily pick is set at 5am ET; a few
            // checks cover late grading + tomorrow's drop without draining
            // the widget refresh budget.
            let next = Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date().addingTimeInterval(10800)
            completion(Timeline(entries: [PickEntry(date: Date(), pick: pick)], policy: .after(next)))
        }
    }
}

// MARK: - Views

struct Pick1PickWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PickEntry

    var body: some View {
        ZStack {
            wink
            if let p = entry.pick {
                content(p)
            } else {
                emptyState
            }
        }
    }

    private func sportEmoji(_ s: String) -> String {
        switch s {
        case "basketball": return "🏀"; case "baseball": return "⚾️"
        case "hockey": return "🏒"; case "football": return "🏈"
        case "soccer": return "⚽️"; case "combat": return "🥊"
        case "f1": return "🏎️"; case "golf": return "⛳️"
        case "cricket": return "🏏"; case "tennis": return "🎾"
        default: return "🎯"
        }
    }

    private func content(_ p: WidgetPick) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("P1").font(.system(size: 10, weight: .heavy)).foregroundColor(wink)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(wlime))
                Text(p.league.uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(1.2)
                    .foregroundColor(.gray)
                Spacer()
                Text(sportEmoji(p.sport)).font(.system(size: 13))
            }

            Spacer(minLength: 4)

            Text("TODAY'S TOP PICK")
                .font(.system(size: 9, weight: .heavy)).tracking(1.4)
                .foregroundColor(wlime.opacity(0.9))
            Text(p.pick)
                .font(.system(size: family == .systemSmall ? 19 : 24, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(2).minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            if family != .systemSmall, let h = p.home_team, let a = p.away_team {
                Text("\(a) @ \(h)")
                    .font(.system(size: 11, weight: .medium)).foregroundColor(.gray)
                    .lineLimit(1).padding(.top, 1)
            }

            Spacer(minLength: 6)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(p.probability)%").font(.system(size: 22, weight: .heavy)).foregroundColor(wlime)
                Text("AI CONFIDENCE").font(.system(size: 9, weight: .bold)).tracking(1.0)
                    .foregroundColor(.gray).baselineOffset(1)
            }
        }
        .padding(14)
        .widgetURL(URL(string: "pick1://today"))
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("P1").font(.system(size: 16, weight: .heavy)).foregroundColor(wink)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(wlime))
            Text("Today's pick drops soon")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(14)
    }
}

struct Pick1PickWidget: Widget {
    let kind = "Pick1PickWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PickProvider()) { entry in
            Pick1PickWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Pick")
        .description("Pick1's highest-confidence call of the day.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
