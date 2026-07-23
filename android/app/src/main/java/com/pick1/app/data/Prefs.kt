package com.pick1.app.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

internal val Context.prefsStore by preferencesDataStore(name = "pick1_prefs")

/**
 * Local preferences — the Android counterpart of the iOS `@AppStorage` keys.
 *
 * `hasFinishedOnboarding` mirrors iOS so the 20-screen funnel runs once, and
 * `userGoal` persists the Goals answer that the paywall echoes back.
 */
object Prefs {
    private val ONBOARDED = booleanPreferencesKey("hasFinishedOnboarding")
    private val GOAL = intPreferencesKey("userGoal")

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
}
