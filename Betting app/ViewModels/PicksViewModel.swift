//
//  PicksViewModel.swift
//  Betting app
//
//  Created by Ethan on 3/30/26.
//

import Combine
import Foundation
import Supabase

@MainActor
class PicksViewModel: ObservableObject {

    // MARK: - Published state

    /// Picks for today (game_date == today). Drives the "Today's Picks" feed.
    @Published var todayPicks: [Pick] = []

    /// Picks from yesterday — graded by the AI pipeline overnight. Drives
    /// the "Yesterday's Results" card so users see W/L from the prior day.
    @Published var yesterdayPicks: [Pick] = []

    /// Rolling 30-day pick history used for win-rate, streaks, and stats.
    /// Includes today + yesterday picks (deduped on `id`).
    @Published var historyPicks: [Pick] = []

    /// Realtime in-play scores keyed by `game_id` (joins to picks).
    @Published var liveScores: [LiveScore] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSport: String = "all"

    // Backwards-compat alias — older views read `picks`.
    var picks: [Pick] { effectiveTodayPicks }

    /// "Today's picks", with a graceful fallback when the AI pipeline
    /// hasn't filled in today's batch yet (off-hours, between cron
    /// ticks, or when the Railway worker is down).
    ///
    /// Falls back in this order so the user *always* sees content:
    ///   1. Today's picks (if any).
    ///   2. Yesterday's picks (most recent slate — usually 6–12 picks).
    ///   3. The freshest non-empty day from `historyPicks`.
    ///
    /// This is what every UI surface should render. The raw
    /// `todayPicks` is still available for screens that strictly need
    /// "only today" semantics (live grading, etc.).
    var effectiveTodayPicks: [Pick] {
        if !todayPicks.isEmpty { return todayPicks }
        if !yesterdayPicks.isEmpty { return yesterdayPicks }
        // Fall back to the most-recent day from history.
        let byDay = Dictionary(grouping: historyPicks, by: { $0.gameDate })
        if let latest = byDay.keys.sorted(by: >).first,
           let bucket = byDay[latest] {
            return bucket
        }
        return []
    }

    private let supabase = SupabaseManager.client

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// All sports the AI pipeline produces predictions for.
    /// Order matches the user's preferred chip order.
    let sports = [
        "all",
        "football", "basketball", "baseball", "f1",
        "combat",   "soccer",     "cricket",  "hockey",
    ]

    // MARK: - Filters

    /// Picks for today, filtered by `selectedSport`. Routes through
    /// `effectiveTodayPicks` so the user always sees content even when
    /// today's batch hasn't been generated yet.
    var filteredTodayPicks: [Pick] {
        let base = effectiveTodayPicks
        if selectedSport == "all" { return base }
        return base.filter { $0.sport == selectedSport }
    }

    /// Backwards-compat alias for older views.
    var filteredPicks: [Pick] { filteredTodayPicks }

    /// Yesterday's picks, filtered by `selectedSport`.
    var filteredYesterdayPicks: [Pick] {
        if selectedSport == "all" { return yesterdayPicks }
        return yesterdayPicks.filter { $0.sport == selectedSport }
    }

    /// History picks, filtered by `selectedSport` (used for stats).
    var filteredHistoryPicks: [Pick] {
        if selectedSport == "all" { return historyPicks }
        return historyPicks.filter { $0.sport == selectedSport }
    }

    // MARK: - Free-tier filter
    //
    // Free users see exactly ONE pick per sport: the highest-confidence
    // pick (probability) of the day. If `selectedSport` is something
    // other than "all", we still surface only that single best pick for
    // the chosen sport.

    /// One pick per sport — the AI's most confident call. Used as the
    /// Free-tier feed. Uses `effectiveTodayPicks` so Free users still
    /// see picks during off-hours / pipeline outages.
    var freeTierTodayPicks: [Pick] {
        let bySport = Dictionary(grouping: effectiveTodayPicks,
                                 by: { $0.sport })
        let topPerSport = bySport.values.compactMap {
            $0.max(by: { $0.probability < $1.probability })
        }
        return topPerSport.sorted { $0.probability > $1.probability }
    }

    /// Free-tier list filtered by `selectedSport` chip.
    var freeTierFilteredPicks: [Pick] {
        if selectedSport == "all" { return freeTierTodayPicks }
        return freeTierTodayPicks.filter { $0.sport == selectedSport }
    }

    /// Returns the picks the user is allowed to see. Pro users get
    /// `filteredTodayPicks`; Free users get `freeTierFilteredPicks`.
    func visiblePicks(isPro: Bool) -> [Pick] {
        isPro ? filteredTodayPicks : freeTierFilteredPicks
    }

    /// Picks beyond the Free-tier cap. Free users see these as locked
    /// "Unlock with Pro" placeholders; Pro users never call this.
    var lockedTodayPicks: [Pick] {
        let visibleIds = Set(freeTierTodayPicks.map { $0.id })
        return filteredTodayPicks.filter { !visibleIds.contains($0.id) }
    }

    // MARK: - Stats (over the rolling 30-day history)

    /// Settled = W or L (not pending). All-time win rate over the window.
    var winRate: Double {
        let settled = filteredHistoryPicks.filter { !$0.isPending }
        guard !settled.isEmpty else { return 0 }
        let wins = settled.filter { $0.isWin }.count
        return Double(wins) / Double(settled.count) * 100
    }

    var totalWins: Int { filteredHistoryPicks.filter { $0.isWin }.count }
    var totalLosses: Int { filteredHistoryPicks.filter { $0.isLoss }.count }
    var totalPending: Int { filteredHistoryPicks.filter { $0.isPending }.count }

    // MARK: - Accuracy (home-screen "ACCURACY" tile)
    //
    // The home tile is global — it should show the AI's overall hit
    // rate regardless of which sport chip is selected. Wired through
    // these helpers instead of `winRate` so the number doesn't jump
    // around when the user filters chips.

    /// AI hit rate over all settled picks (across every sport). Drives
    /// the big number on the AccuracyTile.
    var accuracyAll: Double {
        let settled = historyPicks.filter { !$0.isPending }
        guard !settled.isEmpty else { return 0 }
        let wins = settled.filter { $0.isWin }.count
        return Double(wins) / Double(settled.count) * 100
    }

    /// Last-N settled picks (newest first). Used for "recent record"
    /// + delta vs the prior N. Default N = 10 → "9-1 LAST 10".
    func recentSettled(_ n: Int = 10) -> [Pick] {
        Array(
            historyPicks
                .filter { !$0.isPending }
                .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast)
                        > ($1.gameDate, $1.createdAt ?? Date.distantPast) }
                .prefix(n)
        )
    }

    /// W-L record over the last N settled picks (newest first).
    func recentRecord(_ n: Int = 10) -> (wins: Int, losses: Int) {
        let recent = recentSettled(n)
        return (recent.filter { $0.isWin }.count,
                recent.filter { $0.isLoss }.count)
    }

    /// Hit rate of the last N settled picks. Nil when there's nothing
    /// settled yet.
    func recentHitRate(_ n: Int = 10) -> Double? {
        let recent = recentSettled(n)
        guard !recent.isEmpty else { return nil }
        let wins = recent.filter { $0.isWin }.count
        return Double(wins) / Double(recent.count) * 100
    }

    /// Delta = recent N hit-rate minus prior N hit-rate, in percentage
    /// points. Positive when the AI is heating up, negative when cooling.
    /// Nil if either window is empty.
    func accuracyDelta(window: Int = 10) -> Double? {
        let settled = historyPicks
            .filter { !$0.isPending }
            .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast)
                    > ($1.gameDate, $1.createdAt ?? Date.distantPast) }
        guard settled.count >= window * 2 else {
            // Fall back to recent vs all-time when the prior window is
            // too thin — still gives a meaningful trend signal early.
            guard let recent = recentHitRate(window) else { return nil }
            return recent - accuracyAll
        }
        let recent = Array(settled.prefix(window))
        let prior = Array(settled.dropFirst(window).prefix(window))
        let recentRate = Double(recent.filter { $0.isWin }.count) / Double(recent.count) * 100
        let priorRate  = Double(prior.filter  { $0.isWin }.count) / Double(prior.count)  * 100
        return recentRate - priorRate
    }

    /// Mood for the AccuracyTile — drives color + badge text.
    /// Bullish triggers at 9/10 territory and above (≥80%).
    enum AccuracyMood {
        case bullish    // ≥ 80%  — "ON FIRE", lime, ↑ pill
        case strong     // 60-79% — lime number, no badge
        case neutral    // 50-59% — white, mute delta
        case cold       // < 50%  — mute, red delta
        case empty      // no settled picks yet
    }

    var accuracyMood: AccuracyMood {
        let settled = historyPicks.filter { !$0.isPending }
        guard !settled.isEmpty else { return .empty }
        switch accuracyAll {
        case 80...:  return .bullish
        case 60..<80: return .strong
        case 50..<60: return .neutral
        default:      return .cold
        }
    }

    // MARK: - This week

    /// Picks settled (W or L) since Monday of the current week.
    /// Used by the home "WINS THIS WEEK" tile.
    private var settledThisWeekPicks: [Pick] {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2   // Monday
        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start
        else { return [] }
        let fmt: DateFormatter = {
            let f = DateFormatter()
            f.calendar = cal
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()
        // game_date is stored as ISO yyyy-MM-dd; compare strings safely
        // by parsing.
        return historyPicks.filter { p in
            guard !p.isPending,
                  let date = fmt.date(from: p.gameDate)
            else { return false }
            return date >= weekStart
        }
    }

    var winsThisWeek: Int { settledThisWeekPicks.filter { $0.isWin }.count }
    var lossesThisWeek: Int { settledThisWeekPicks.filter { $0.isLoss }.count }
    var gamesThisWeek: Int { settledThisWeekPicks.count }

    /// Last 10 settled picks as W/L booleans (true = W). Most-recent
    /// first. Used to render the segmented "last 10" bar on the
    /// AccuracyTile.
    var last10Results: [Bool] {
        recentSettled(10).map { $0.isWin }
    }

    /// Last 14 days of daily hit-rate (0...100). Drives the sparkline
    /// on the AccuracyTile. Days with no settled picks fall through
    /// using the prior day's value so the line stays continuous.
    var accuracySparkline: [Double] {
        let days = 14
        let cal = Calendar(identifier: .iso8601)
        let isoFmt: DateFormatter = {
            let f = DateFormatter()
            f.calendar = cal
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()
        let today = Date()
        var values: [Double] = []
        var lastKnown: Double = accuracyAll
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today)
            else { continue }
            let key = isoFmt.string(from: day)
            let dayPicks = historyPicks.filter { $0.gameDate == key && !$0.isPending }
            if dayPicks.isEmpty {
                values.append(lastKnown)
            } else {
                let wins = dayPicks.filter { $0.isWin }.count
                let rate = Double(wins) / Double(dayPicks.count) * 100
                values.append(rate)
                lastKnown = rate
            }
        }
        return values
    }

    // MARK: - Yesterday recap

    /// Wins from yesterday's settled picks.
    var yesterdayWins: Int {
        filteredYesterdayPicks.filter { $0.isWin }.count
    }

    /// Losses from yesterday's settled picks.
    var yesterdayLosses: Int {
        filteredYesterdayPicks.filter { $0.isLoss }.count
    }

    /// Yesterday's win rate, or nil if nothing was settled.
    var yesterdayWinRate: Double? {
        let settled = filteredYesterdayPicks.filter { !$0.isPending }
        guard !settled.isEmpty else { return nil }
        return Double(settled.filter { $0.isWin }.count) / Double(settled.count) * 100
    }

    // MARK: - Streaks

    /// Current streak of consecutive winning picks, starting from the most
    /// recently *settled* pick and walking backwards. A loss (or no settled
    /// picks at all) returns 0. Pending picks are skipped — they don't
    /// break the streak, they're just not yet known.
    var currentStreak: Int {
        let settled = filteredHistoryPicks
            .filter { !$0.isPending }
            .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast) > ($1.gameDate, $1.createdAt ?? Date.distantPast) }
        var streak = 0
        for pick in settled {
            if pick.isWin { streak += 1 } else { break }
        }
        return streak
    }

    /// Longest winning streak found anywhere in the rolling window.
    var longestStreak: Int {
        let settled = filteredHistoryPicks
            .filter { !$0.isPending }
            .sorted { ($0.gameDate, $0.createdAt ?? Date.distantPast) < ($1.gameDate, $1.createdAt ?? Date.distantPast) }
        var best = 0
        var run  = 0
        for pick in settled {
            if pick.isWin {
                run += 1
                if run > best { best = run }
            } else {
                run = 0
            }
        }
        return best
    }

    /// Day-level streak: consecutive days where AT LEAST ONE pick won.
    /// Picture-friendly version of "win streak" for the UI hero.
    var dayStreak: Int {
        // Group settled picks by day, keep days with at least one win.
        let byDay = Dictionary(grouping: filteredHistoryPicks.filter { !$0.isPending },
                               by: { $0.gameDate })
        let winningDays: [String] = byDay
            .filter { _, picks in picks.contains(where: { $0.isWin }) }
            .keys
            .sorted(by: >)  // most recent first
        // Walk back from today/yesterday, requiring no gap.
        var streak = 0
        let cal = Calendar(identifier: .iso8601)
        var cursor = Date()
        let fmt = ISO8601DateFormatter()
        for _ in 0..<60 {  // hard stop after 60 days
            let dayStr = String(fmt.string(from: cursor).prefix(10))
            if winningDays.contains(dayStr) {
                streak += 1
                cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } else if streak == 0 {
                // Tolerate today not yet having results — start counting at yesterday.
                cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                if streak == 0 {
                    let yesterdayStr = String(fmt.string(from: cursor).prefix(10))
                    if !winningDays.contains(yesterdayStr) {
                        return 0
                    }
                    streak += 1
                    cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                }
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Fetchers

    /// Pulls today's picks, yesterday's picks, and a rolling 30-day window
    /// in parallel. Cheap on Supabase (`game_date` is indexed).
    func loadAll() async {
        isLoading = true
        errorMessage = nil
        async let today    = fetchPicks(forDate: Self.dateString(daysAgo: 0))
        async let yest     = fetchPicks(forDate: Self.dateString(daysAgo: 1))
        async let history  = fetchPicks(sinceDaysAgo: 30)
        async let scores   = fetchLiveScoresInner()
        let (t, y, h, s)   = await (today, yest, history, scores)
        self.todayPicks      = t
        self.yesterdayPicks  = y
        self.historyPicks    = h
        self.liveScores      = s
        isLoading = false
    }

    private func fetchPicks(forDate dateString: String) async -> [Pick] {
        do {
            let resp: [Pick] = try await supabase
                .from("picks")
                .select()
                .eq("game_date", value: dateString)
                .order("probability", ascending: false)
                .execute()
                .value
            return resp
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    private func fetchPicks(sinceDaysAgo days: Int) async -> [Pick] {
        let since = Self.dateString(daysAgo: days)
        do {
            let resp: [Pick] = try await supabase
                .from("picks")
                .select()
                .gte("game_date", value: since)
                .order("game_date", ascending: false)
                .execute()
                .value
            return resp
        } catch {
            errorMessage = error.localizedDescription
            return []
        }
    }

    private func fetchLiveScoresInner() async -> [LiveScore] {
        do {
            let resp: [LiveScore] = try await supabase
                .from("live_scores")
                .select()
                .execute()
                .value
            return resp
        } catch {
            return []
        }
    }

    // Convenience for older callers.
    func fetchTodayPicks() async {
        let resp = await fetchPicks(forDate: Self.dateString(daysAgo: 0))
        self.todayPicks = resp
    }

    func fetchLiveScores() async {
        self.liveScores = await fetchLiveScoresInner()
    }

    // MARK: - Realtime

    func subscribeToPickUpdates() async {
        let today = Self.dateString(daysAgo: 0)
        let channel = supabase.realtimeV2.channel("picks_realtime")

        // Today's row updates → refresh today + history (a graded result
        // also affects streak math).
        let updateSub = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "picks",
            filter: "game_date=eq.\(today)"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                if let updated = try? action.decodeRecord(as: Pick.self, decoder: self.decoder) {
                    self.applyPickUpdate(updated)
                }
            }
        }
        _ = updateSub

        // Inserts (new picks land mid-day from a fresh pipeline run).
        let insertSub = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "picks",
            filter: "game_date=eq.\(today)"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                if let inserted = try? action.decodeRecord(as: Pick.self, decoder: self.decoder) {
                    self.applyPickInsert(inserted)
                }
            }
        }
        _ = insertSub

        await channel.subscribe()
    }

    func subscribeToLiveScores() async {
        let channel = supabase.realtimeV2.channel("scores_realtime")

        let insertSub = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "live_scores"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                if let s = try? action.decodeRecord(as: LiveScore.self, decoder: self.decoder) {
                    self.updateScoreInList(s)
                }
            }
        }
        _ = insertSub

        let updateSub = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "live_scores"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }
                if let s = try? action.decodeRecord(as: LiveScore.self, decoder: self.decoder) {
                    self.updateScoreInList(s)
                }
            }
        }
        _ = updateSub

        await channel.subscribe()
    }

    // MARK: - Helpers

    private func applyPickUpdate(_ updated: Pick) {
        if let i = todayPicks.firstIndex(where: { $0.id == updated.id }) {
            todayPicks[i] = updated
        }
        if let i = historyPicks.firstIndex(where: { $0.id == updated.id }) {
            historyPicks[i] = updated
        } else {
            historyPicks.append(updated)
        }
    }

    private func applyPickInsert(_ inserted: Pick) {
        if !todayPicks.contains(where: { $0.id == inserted.id }) {
            todayPicks.insert(inserted, at: 0)
        }
        if !historyPicks.contains(where: { $0.id == inserted.id }) {
            historyPicks.insert(inserted, at: 0)
        }
    }

    private func updateScoreInList(_ updated: LiveScore) {
        if let i = liveScores.firstIndex(where: { $0.gameId == updated.gameId }) {
            liveScores[i] = updated
        } else {
            liveScores.append(updated)
        }
    }

    private static func dateString(daysAgo: Int) -> String {
        let cal = Calendar(identifier: .iso8601)
        let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "America/New_York")  // match pipeline TZ
        return fmt.string(from: date)
    }

    // MARK: - Lifecycle

    /// Single entry point for views: fetches today/yesterday/history and
    /// subscribes to realtime updates.
    func startLiveSession() async {
        await loadAll()
        await subscribeToPickUpdates()
        await subscribeToLiveScores()
    }
}
