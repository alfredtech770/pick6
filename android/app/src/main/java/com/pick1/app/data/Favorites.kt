package com.pick1.app.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * Starred picks — port of the iOS `FavoritesStore`.
 *
 * Tapping the star on a match detail adds the pick here, which is what
 * populates the Wins/Picks tab and the Live tab's FAVORITES filter. Held
 * locally (DataStore) like iOS holds it in @AppStorage.
 */
object Favorites {
    private val KEY = stringSetPreferencesKey("favoritePickIds")

    fun ids(ctx: Context): Flow<Set<String>> =
        ctx.prefsStore.data.map { it[KEY] ?: emptySet() }

    suspend fun toggle(ctx: Context, pickId: String) {
        ctx.prefsStore.edit { prefs ->
            val cur = prefs[KEY] ?: emptySet()
            prefs[KEY] = if (pickId in cur) cur - pickId else cur + pickId
        }
    }

    suspend fun clear(ctx: Context) {
        ctx.prefsStore.edit { it[KEY] = emptySet() }
    }
}
