package com.pick1.app.data

import com.pick1.app.data.model.Pick
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Personal bet tracking — port of `BetTracker.swift`.
 *
 * Reads/writes the SAME `user_bets` table as iOS (owner-only RLS), so a
 * user's ledger follows them across platforms. Results inherit from the
 * pick's win/loss grade: profit = stake x (odds - 1) on wins, -stake on
 * losses. Stake is optional — a bet tracked without an amount still counts
 * toward the personal record, just not the dollar P&L.
 */
@Serializable
data class UserBet(
    val id: String,
    @SerialName("pick_id") val pickId: String,
    val stake: Double? = null,
    @SerialName("odds_at_bet") val oddsAtBet: Double? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

data class BetSummary(
    val tracked: Int = 0,
    val settled: Int = 0,
    val wins: Int = 0,
    val losses: Int = 0,
    val staked: Double = 0.0,     // settled bets that carried a stake
    val profit: Double = 0.0,     // net across settled staked bets
) {
    val roiPct: Double? get() = if (staked > 0) profit / staked * 100 else null
    val pending: Int get() = tracked - settled
    val hitRate: Int? get() = if (settled > 0) ((wins.toDouble() / settled) * 100).toInt() else null
}

class BetRepository {

    suspend fun load(): Map<String, UserBet> =
        runCatching {
            Supabase.client.from("user_bets").select().decodeList<UserBet>()
                .associateBy { it.pickId }
        }.getOrDefault(emptyMap())

    suspend fun track(pick: Pick, stake: Double?): Boolean = runCatching {
        val uid = Supabase.client.auth.currentUserOrNull()?.id ?: return false
        Supabase.client.from("user_bets").insert(
            mapOf(
                "user_id" to uid,
                "pick_id" to pick.id,
                "stake" to stake?.toString(),
                "odds_at_bet" to pick.decimalOdds.toString(),
            )
        )
        true
    }.getOrDefault(false)

    /** Compute the personal record against the picks the bets refer to. */
    fun summary(bets: Collection<UserBet>, picks: List<Pick>): BetSummary {
        val byId = picks.associateBy { it.id }
        var tracked = 0; var settled = 0; var wins = 0; var losses = 0
        var staked = 0.0; var profit = 0.0
        for (bet in bets) {
            val pick = byId[bet.pickId] ?: continue
            tracked++
            if (pick.isPending) continue
            settled++
            if (pick.isWin) wins++ else if (pick.isLoss) losses++
            val stake = bet.stake ?: continue
            if (stake <= 0) continue
            val odds = bet.oddsAtBet ?: pick.marketOdds ?: 1.9
            staked += stake
            profit += if (pick.isWin) stake * (odds - 1) else -stake
        }
        return BetSummary(tracked, settled, wins, losses, staked, profit)
    }
}

// ── Calibration ──────────────────────────────────────────────────────

/**
 * A stated-confidence band vs the actual hit rate, straight from the public
 * `calibration_bands` view. Port of `CalibrationBand` in CalibrationView.swift.
 */
@Serializable
data class CalibrationBand(
    val band: String,
    val n: Int,
    val wins: Int,
    @SerialName("actual_pct") val actualPct: Double,
    @SerialName("avg_stated") val avgStated: Double,
)

class CalibrationRepository {
    suspend fun bands(): List<CalibrationBand> =
        runCatching {
            Supabase.client.from("calibration_bands").select()
                .decodeList<CalibrationBand>()
                .sortedByDescending { it.avgStated }   // highest confidence first
        }.getOrDefault(emptyList())

    /** The "within N points" honesty headline, weighted by sample size. */
    fun avgGapText(bands: List<CalibrationBand>): String? {
        if (bands.isEmpty()) return null
        val totalN = bands.sumOf { it.n }
        if (totalN <= 0) return null
        val weighted = bands.sumOf { kotlin.math.abs(it.avgStated - it.actualPct) * it.n } / totalN
        return weighted.toInt().toString()
    }
}
