package com.pick1.app.data

import com.pick1.app.BuildConfig
import com.pick1.app.data.model.Pick
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.realtime.Realtime
import io.ktor.client.engine.okhttp.OkHttp
import kotlinx.serialization.json.Json

/**
 * The single Supabase client — points at the SAME project the iOS app uses
 * (`SupabaseManager.swift`), so Android reads the identical picks, respects
 * the same RLS policies, and shares the auth user table.
 *
 * The anon key is a publishable client credential; row access is enforced
 * server-side by RLS, exactly as on iOS.
 */
object Supabase {
    val client = createSupabaseClient(
        supabaseUrl = BuildConfig.SUPABASE_URL,
        supabaseKey = BuildConfig.SUPABASE_ANON_KEY,
    ) {
        install(Postgrest)
        install(Auth)
        install(Realtime)
        httpEngine = OkHttp.create()
        defaultSerializer = io.github.jan.supabase.serializer.KotlinXSerializer(
            Json { ignoreUnknownKeys = true; coerceInputValues = true }
        )
    }
}

/**
 * Reads for the picks board. Mirrors what `PicksViewModel.swift` fetches so
 * both platforms show the same slate.
 */
class PicksRepository {

    /** Today's slate (plus anything still pending), newest first. */
    suspend fun todayPicks(): List<Pick> =
        Supabase.client.from("picks")
            .select {
                filter { eq("game_date", today()) }
            }
            .decodeList<Pick>()

    /** Recently graded winners — powers the free-tier "Latest Wins" rail. */
    suspend fun latestWins(limit: Int = 10): List<Pick> =
        Supabase.client.from("picks")
            .select {
                filter { eq("result", "win") }
                order("game_date", io.github.jan.supabase.postgrest.query.Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList<Pick>()

    /** Everything in a date window — used by the sport hubs and tracker. */
    suspend fun picksBetween(fromDate: String, toDate: String): List<Pick> =
        Supabase.client.from("picks")
            .select {
                filter {
                    gte("game_date", fromDate)
                    lte("game_date", toDate)
                }
            }
            .decodeList<Pick>()

    /** Live scores for today's games — powers the LIVE NOW tab. */
    suspend fun liveScores(): List<com.pick1.app.data.model.LiveScore> =
        Supabase.client.from("live_scores").select().decodeList()

    private fun today(): String {
        val fmt = java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd")
        return java.time.LocalDate.now().format(fmt)
    }
}
