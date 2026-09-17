package com.pick1.app.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringSetPreferencesKey
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Starred picks — port of the iOS `FavoritesStore`.
 *
 * Tapping the star on a match detail adds the pick here, which is what
 * populates the Wins/Picks tab and the Live tab's FAVORITES filter. The set
 * of pick ids is held locally (DataStore) like iOS holds it in @AppStorage.
 *
 * It ALSO mirrors the pick's `game_id` into the Supabase `user_favorites`
 * table, which is the only thing the pipeline can see. Until 2026-09-16 this
 * half did not exist on Android: favourites lived purely in DataStore, so
 * every favourite-driven notification (`fav_start`, `goal_fav`, `result_win`)
 * had an empty audience on Android and nothing was ever sent. iOS has synced
 * since the goal-push work; this brings Android to the same contract, row for
 * row: upsert on `user_id,game_id`, delete on un-favourite.
 *
 * The sync is best-effort. A failed write never blocks the star, because the
 * local set is what the UI reads; the cost of a dropped write is one missed
 * notification, and the cost of a blocked star is a broken button.
 */
object Favorites {
    private val KEY = stringSetPreferencesKey("favoritePickIds")

    @Serializable
    private data class FavRow(
        @SerialName("user_id") val userId: String,
        @SerialName("game_id") val gameId: String,
    )

    fun ids(ctx: Context): Flow<Set<String>> =
        ctx.prefsStore.data.map { it[KEY] ?: emptySet() }

    /**
     * Flip the star for [pickId] and mirror [gameId] to `user_favorites`.
     *
     * [gameId] is nullable because a pick row can arrive without one; in that
     * case the star still works locally and only the push targeting is lost.
     */
    suspend fun toggle(ctx: Context, pickId: String, gameId: String? = null) {
        var nowFav = false
        ctx.prefsStore.edit { prefs ->
            val cur = prefs[KEY] ?: emptySet()
            nowFav = pickId !in cur
            prefs[KEY] = if (nowFav) cur + pickId else cur - pickId
        }
        syncToDb(gameId, nowFav)
    }

    suspend fun clear(ctx: Context) {
        // Read the ids before wiping them so the server rows can go too,
        // otherwise "Clear all" would leave the user subscribed to alerts for
        // games whose star they can no longer see.
        ctx.prefsStore.edit { it[KEY] = emptySet() }
        val uid = userId() ?: return
        runCatching {
            Supabase.client.postgrest.from("user_favorites")
                .delete { filter { eq("user_id", uid) } }
        }
    }

    private fun userId(): String? =
        runCatching { Supabase.client.auth.currentUserOrNull()?.id }.getOrNull()

    private suspend fun syncToDb(gameId: String?, on: Boolean) {
        if (gameId.isNullOrEmpty()) return
        val uid = userId() ?: return
        runCatching {
            if (on) {
                Supabase.client.postgrest.from("user_favorites")
                    .upsert(FavRow(uid, gameId)) { onConflict = "user_id,game_id" }
            } else {
                Supabase.client.postgrest.from("user_favorites")
                    .delete {
                        filter {
                            eq("user_id", uid)
                            eq("game_id", gameId)
                        }
                    }
            }
        }
    }
}
