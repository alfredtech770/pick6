package com.pick1.app.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

internal val Context.prefsStore by preferencesDataStore(name = "pick1_prefs")

/** Current instant as an ISO-8601 UTC string — for timestamptz comparisons. */
fun nowIso(): String = java.time.Instant.now().toString()

/**
 * Local preferences — the Android counterpart of the iOS `@AppStorage` keys.
 *
 * `hasFinishedOnboarding` mirrors iOS so the 20-screen funnel runs once, and
 * `userGoal` persists the Goals answer that the paywall echoes back.
 */
object Prefs {
    private val ONBOARDED = booleanPreferencesKey("hasFinishedOnboarding")
    private val GOAL = intPreferencesKey("userGoal")
    // Day Pass: the epoch-millis the last 24h pass was bought (0 = never).
    private val DAY_PASS_AT = longPreferencesKey("dayPassPurchasedAt")
    private const val DAY_PASS_MS = 24L * 60 * 60 * 1000

    fun onboarded(ctx: Context): Flow<Boolean> =
        ctx.prefsStore.data.map { it[ONBOARDED] ?: false }

    suspend fun setOnboarded(ctx: Context, value: Boolean) {
        ctx.prefsStore.edit { it[ONBOARDED] = value }
    }

    fun goal(ctx: Context): Flow<Int?> =
        ctx.prefsStore.data.map { it[GOAL] }

    suspend fun setGoal(ctx: Context, value: Int) {
        ctx.prefsStore.edit { it[GOAL] = value }
    }

    /** Record a Day Pass purchase at [purchaseTimeMs]; grants 24h of access. */
    suspend fun setDayPassPurchased(ctx: Context, purchaseTimeMs: Long) {
        ctx.prefsStore.edit { it[DAY_PASS_AT] = purchaseTimeMs }
    }

    /** Epoch-millis the current Day Pass expires (0 if none / expired-long-ago). */
    suspend fun dayPassUntil(ctx: Context): Long {
        val at = ctx.prefsStore.data.map { it[DAY_PASS_AT] ?: 0L }.first()
        return if (at <= 0L) 0L else at + DAY_PASS_MS
    }
}
