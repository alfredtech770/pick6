package com.pick1.app.ui.free

import com.pick1.app.data.model.Pick

/**
 * Selection logic for the free home, ported from `LatestWinsRail.results`
 * and `FreeSlateSection.slate`. Kept out of the composables so the rules are
 * testable and provably identical to iOS.
 */
object FreeFeed {

    /**
     * Settled picks in a deliberate ~80/20 win–loss mix: up to 8 wins, up to
     * 2 losses, losses interleaved after the 3rd and 7th win. Recent and
     * mostly winning, but visibly honest — the same trade-off iOS makes.
     *
     * Floor: if a quiet stretch leaves fewer than 6 wins, backfill with older
     * wins so the rail never thins out or vanishes.
     */
    fun latestWins(history: List<Pick>, sport: String): List<Pick> {
        val settled = history
            .filter { !it.isPending }
            .filter { sport == "all" || it.sport == sport }
            .sortedByDescending { it.gameDate }

        val winPool = settled.filter { it.isWin }.toMutableList()
        val wins = winPool.take(8)

        // <=20% of the rail: 1 loss for 4-7 wins, 2 for 8, none when few wins.
        val lossBudget = when {
            wins.size >= 8 -> 2
            wins.size >= 4 -> 1
            else -> 0
        }
        val losses = settled.filter { it.isLoss }.take(lossBudget)

        val out = mutableListOf<Pick>()
        var li = 0
        wins.forEachIndexed { i, w ->
            out += w
            if ((i == 2 || i == 6) && li < losses.size) {
                out += losses[li]; li++
            }
        }
        if (li < losses.size) out += losses.drop(li)
        return out
    }

    /** Today's slate minus the free hero pick — shown locked. */
    fun lockedSlate(today: List<Pick>, heroId: String?, sport: String): List<Pick> =
        today.filter { it.id != heroId && (sport == "all" || it.sport == sport) }

    /**
     * Net flat-$100 return across yesterday's settled slate: wins pay
     * (odds x 100 - 100), losses cost 100. Clamped at 0.
     */
    fun membersNet(yesterday: List<Pick>): Int {
        val settled = yesterday.filter { !it.isPending }
        val winnings = settled.filter { it.isWin }
            .sumOf { it.decimalOdds * 100 - 100 }
        val losses = settled.count { it.isLoss }
        return maxOf(0, (winnings - losses * 100).toInt())
    }
}
