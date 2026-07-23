package com.pick1.app.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.decodeFromJsonElement
import kotlin.math.roundToInt

/** Tolerant parser for the AI-written detail blobs. */
internal val LenientJson = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    isLenient = true
}

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
    @SerialName("betting_props") val bettingProps: List<BettingProp>? = null,

    // ── AI-written detail blobs ──────────────────────────────────────
    // These come out of the Claude pipeline and their value TYPES vary from
    // row to row (reachNum has been seen as both 71 and 66.5; soccer
    // position is the string "1st"). Decoding them eagerly into typed
    // classes made the entire picks query fail on a single odd row and
    // blanked the whole board. They're held as raw JSON here — the board
    // never breaks — and parsed leniently only where a detail screen needs
    // them, via taleOfTape() / soccerComparison() below.
    @SerialName("tale_of_tape") val taleOfTapeRaw: JsonElement? = null,
    @SerialName("soccer_comparison") val soccerComparisonRaw: JsonElement? = null,
) {
    /** Lenient decode; returns null rather than throwing on an odd shape. */
    fun taleOfTape(): TaleOfTape? = taleOfTapeRaw?.let {
        runCatching { LenientJson.decodeFromJsonElement<TaleOfTape>(it) }.getOrNull()
    }

    fun soccerComparison(): SoccerComparison? = soccerComparisonRaw?.let {
        runCatching { LenientJson.decodeFromJsonElement<SoccerComparison>(it) }.getOrNull()
    }

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

    /**
     * Fallback decimal odds when no market quote exists — derived from the
     * model's own probability. Used only for payout math, and labelled as
     * such in the UI (mirrors the iOS `Pick.impliedOddsForPayout` extension).
     */
    val impliedOddsForPayout: Double?
        get() = if (probability > 0) 100.0 / probability else null

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

/**
 * Combat tale-of-the-tape (`tale_of_tape` jsonb, written by pipeline/combat.js).
 *
 * NOTE the fighters are keyed "a"/"b" — NOT home/away — and every career stat
 * arrives as a *string* (or null). Verified against live rows; getting this
 * wrong makes the whole picks query fail to decode.
 */
@Serializable
data class TaleOfTape(
    val a: ToTFighter? = null,
    val b: ToTFighter? = null,
    val edges: Map<String, ToTEdge>? = null,
    val weightClass: String? = null,
)

@Serializable
data class ToTFighter(
    val id: String? = null,
    val name: String? = null,
    val age: Double? = null,
    val height: String? = null,
    val reach: String? = null,
    val reachNum: Double? = null,
    val stance: String? = null,
    val country: String? = null,
    val nickname: String? = null,
    val record: String? = null,
    val weightClass: String? = null,
    val career: ToTCareer? = null,
)

@Serializable
data class ToTCareer(
    val strLPM: String? = null,
    val strAcc: String? = null,
    val tdAvg: String? = null,
    val tdAcc: String? = null,
    val subAvg: String? = null,
)

@Serializable
data class ToTEdge(
    val fighter: String? = null,
    val value: String? = null,
)

/**
 * Soccer form panel (`soccer_comparison` jsonb, from pipeline/soccer.js).
 *
 * Every numeric-looking field is stored as a STRING ("3", "1st", "5") — do
 * not model these as Int or decoding blows up on `position: "1st"`.
 */
@Serializable
data class SoccerComparison(
    val home: SoccerTeam? = null,
    val away: SoccerTeam? = null,
    val competition: String? = null,
)

@Serializable
data class SoccerTeam(
    val name: String? = null,
    val found: Boolean? = null,
    val group: String? = null,
    val position: String? = null,
    val points: String? = null,
    val played: String? = null,
    val record: String? = null,
    val form: String? = null,
    val goalsFor: String? = null,
    val goalsAgainst: String? = null,
)

/**
 * A live game's running score — mirrors `LiveScore` in Models/Pick.swift and
 * the `live_scores` table the pipeline updates. Joined to a Pick by game_id.
 */
@Serializable
data class LiveScore(
    val id: String,
    @SerialName("game_id") val gameId: String,
    val sport: String,
    @SerialName("home_team") val homeTeam: String,
    @SerialName("away_team") val awayTeam: String,
    @SerialName("home_score") val homeScore: Int? = null,
    @SerialName("away_score") val awayScore: Int? = null,
    val status: String? = null,
    val quarter: String? = null,
    @SerialName("start_time") val startTime: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
) {
    /** In-progress right now (not scheduled, not final). */
    val isLive: Boolean
        get() = status?.lowercase()?.let {
            it.contains("in") || it.contains("live") || it.contains("progress")
        } ?: false
}
