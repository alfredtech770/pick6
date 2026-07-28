package com.pick1.app.push

import com.google.firebase.messaging.FirebaseMessaging
import com.pick1.app.BuildConfig
import com.pick1.app.data.LanguageManager
import com.pick1.app.data.Supabase
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/**
 * Registers this device's FCM token in the SAME `device_tokens` table the
 * iOS app writes to — the table already carries a `platform` column, so
 * Android rows sit alongside the iOS APNs rows and the `send-push` Edge
 * Function fans out to both once it grows an FCM branch.
 *
 * Mirrors `PushManager.swift`: upsert on token, stamp environment /
 * platform / app_version / locale so pushes can be localized server-side.
 */
object PushManager {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    @Serializable
    private data class TokenRow(
        val token: String,
        val user_id: String,
        val environment: String,
        val platform: String,
        val app_version: String?,
        val locale: String,
    )

    /** Fetch the current FCM token and upload it (call after sign-in). */
    fun register() {
        FirebaseMessaging.getInstance().token.addOnSuccessListener(::upload)
    }

    fun upload(token: String) {
        val userId = Supabase.client.auth.currentUserOrNull()?.id ?: return
        scope.launch {
            // Best-effort — a failed token upload must never disrupt the app.
            runCatching {
                Supabase.client.from("device_tokens").upsert(
                    TokenRow(
                        token = token,
                        user_id = userId,
                        environment = if (BuildConfig.DEBUG) "sandbox" else "production",
                        platform = "android",
                        app_version = BuildConfig.VERSION_NAME,
                        locale = LanguageManager.current ?: "en",
                    )
                ) { onConflict = "token" }
            }
        }
    }
}
