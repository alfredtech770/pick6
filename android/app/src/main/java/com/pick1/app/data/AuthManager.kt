package com.pick1.app.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.OTP
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.status.SessionStatus

/**
 * Auth — port of the iOS `AuthManager`.
 *
 * Passwordless by default, against the SAME Supabase project as iOS, so an
 * account created on either platform is the same user with the same picks,
 * bets and entitlement.
 *
 * Sign in with Apple is replaced by Google Sign-In here (SIWA on Android is
 * a clunky web flow); Supabase supports both providers on one project, and
 * a user who signed up with email OTP on iOS can sign in with the same
 * email OTP on Android.
 */
object AuthManager {

    var isAuthenticated by mutableStateOf(false)
        private set
    var error by mutableStateOf<String?>(null)
        private set
    var busy by mutableStateOf(false)
        private set

    val userId: String? get() = Supabase.client.auth.currentUserOrNull()?.id

    /** Reflects an existing session on cold start. */
    suspend fun refreshSession() {
        runCatching {
            Supabase.client.auth.awaitInitialization()
            isAuthenticated = Supabase.client.auth.currentSessionOrNull() != null
        }
    }

    /** Step 1 — email a 6-digit code. */
    suspend fun sendOtp(email: String): Boolean {
        busy = true; error = null
        val ok = runCatching {
            Supabase.client.auth.signInWith(OTP) { this.email = email }
        }.onFailure { error = friendly(it) }.isSuccess
        busy = false
        return ok
    }

    /** Step 2 — verify the code; success flips [isAuthenticated]. */
    suspend fun verifyOtp(email: String, token: String): Boolean {
        busy = true; error = null
        val ok = runCatching {
            Supabase.client.auth.verifyEmailOtp(
                type = io.github.jan.supabase.auth.OtpType.Email.EMAIL,
                email = email,
                token = token,
            )
        }.onFailure { error = friendly(it) }.isSuccess
        if (ok) isAuthenticated = Supabase.client.auth.currentSessionOrNull() != null
        busy = false
        return ok
    }

    /** Google Sign-In — the Android counterpart of Sign in with Apple. */
    suspend fun signInWithGoogle(idToken: String, rawNonce: String?): Boolean {
        busy = true; error = null
        val ok = runCatching {
            Supabase.client.auth.signInWith(IDToken) {
                provider = Google
                this.idToken = idToken
                this.nonce = rawNonce
            }
        }.onFailure { error = friendly(it) }.isSuccess
        if (ok) isAuthenticated = Supabase.client.auth.currentSessionOrNull() != null
        busy = false
        return ok
    }

    suspend fun signOut() {
        runCatching { Supabase.client.auth.signOut() }
        isAuthenticated = false
    }

    fun clearError() { error = null }

    /** Matches the iOS friendlyError mapping. */
    private fun friendly(t: Throwable): String {
        val m = t.message.orEmpty()
        return when {
            m.contains("network", true) || m.contains("host", true) ->
                "Couldn't reach the Pick1 server. Check your connection and try again."
            m.contains("expired", true) || m.contains("invalid", true) ->
                "That code didn't work. Check it and try again."
            else -> m.ifBlank { "Something went wrong. Try again." }
        }
    }
}
