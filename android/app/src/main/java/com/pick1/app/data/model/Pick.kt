package com.pick1.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.roundToInt

/**
 * A single AI prediction — mirrors `Betting app/Models/Pick.swift` and the
 * `picks` table the pipeline writes. Field names match the Postgres columns
 * so the same rows decode identically on both platforms.
 */
@Serializable
data class Pick(
    val id: String,
    @SerialName("created_at") val createdAt: String? = null,
    val sport: String,
    val league: String,
    @SerialName("game_date") val gameDate: String,
    @SerialName("game_id") val gameId: String? = null,
    @SerialName("home_team") val homeTeam: String,
    @SerialName("away_team") val awayTeam: String,
    val pick: String,
    val probability: Double,
    val confidence: String,
    val reasoning: String,
    @SerialName("key_factor") val keyFactor: String? = null,
    @SerialName("matchup_facts") val matchupFacts: List<MatchupFact>? = null,
    val result: String = "pending",              // pending | win | loss
    @SerialName("home_score") val homeScore: Int? = null,
    @SerialName("away_score") val awayScore: Int? = null,
    @SerialName("market_odds") val marketOdds: Double? = null,
    @SerialName("odds_source") val oddsSource: String? = null,
    @SerialName("odds_books") val oddsBooks: List<OddsBook>? = null,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("predicted_score") val predictedScore: String? = null,
    // Server-side captured crests (pipeline/images.js). The app reads these
    // first so every team paints instantly with no client-side lookup.
    @SerialName("home_logo") val homeLogo: String? = null,
    @SerialName("away_logo") val awayLogo: String? = null,
    @SerialName("field_odds") val fieldOdds: List<DriverOdds>? = null,
    @SerialName("tale_of_tape") val taleOfTape: TaleOfTape? = null,
    @SerialName("betting_props") val bettingProps: List<BettingProp>? = null,
    @SerialName("soccer_comparison") val soccerComparison: SoccerComparison? = null,
) {
    val isWin: Boolean get() = result == "win"
    val isLoss: Boolean get() = result == "loss"
    val isPending: Boolean get() = result == "pending"

    /** Decimal odds, falling back to the model's implied price. */
    val decimalOdds: Double
        get() = marketOdds ?: if (probability > 0) (100.0 / probability) else 1.9

    val potentialReturnPercent: Int
        get() = ((decimalOdds - 1.0) * 100).roundToInt()

    /** Market-implied win probability (%), when a real line exists. */
    val impliedProbability: Double?
        get() = marketOdds?.takeIf { it > 0 }?.let { 100.0 / it }

    /** Our edge over the market, in percentage points. */
    val valueEdge: Double?
        get() = impliedProbability?.let { probability - it }

    val isValuePlay: Boolean
        get() = (valueEdge ?: 0.0) >= 6.0

    /** Individual sports show a face, not a crest (see AthleteHeadshot on iOS). */
    val isIndividualSport: Boolean
        get() = sport in setOf("mma", "tennis", "golf", "f1", "motorsport")

    /** Golf/F1 style events: home = tournament, away = "Field". */
    val isFieldEvent: Boolean
        get() = awayTeam.equals("field", ignoreCase = true) || sport in setOf("golf", "f1")
}

@Serializable
data class MatchupFact(val label: String, val value: String)

@Serializable
data class OddsBook(
    val book: String,
    val odds: Double,
    val link: String? = null,
)

@Serializable
data class DriverOdds(
    val name: String,
    val win: Double? = null,
    val podium: Double? = null,
)

@Serializable
data class BettingProp(
    val label: String,
    val value: String,
    val hint: String? = null,
)

@Serializable
data class TaleOfTape(
    val home: ToTFighter? = null,
    val away: ToTFighter? = null,
)

@Serializable
data class ToTFighter(
    val name: String? = null,
    val height: String? = null,
    val reach: String? = null,
    val age: String? = null,
    val stance: String? = null,
    val country: String? = null,
    val record: String? = null,
)

@Serializable
data class SoccerComparison(
    val home: SoccerTeam? = null,
    val away: SoccerTeam? = null,
)

@Serializable
data class SoccerTeam(
    val name: String? = null,
    val position: Int? = null,
    val points: Int? = null,
    val played: Int? = null,
    val form: String? = null,
    @SerialName("goals_for") val goalsFor: Int? = null,
    @SerialName("goals_against") val goalsAgainst: Int? = null,
)
