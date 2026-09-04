package com.pick1.app

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.pick1.app.ui.RootScaffold
import kotlinx.serialization.json.put
import kotlinx.serialization.json.buildJsonObject
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.launch
import com.pick1.app.ui.theme.Pick1Theme

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // DEBUG ONLY: `adb shell am start ... --ez skipOnboarding true` jumps
        // straight to the board, mirroring the iOS -hasFinishedOnboarding
        // launch arg. Never reachable in a release build.
        val skipOnboarding = BuildConfig.DEBUG &&
            intent?.getBooleanExtra("skipOnboarding", false) == true
        // DEBUG ONLY: open a specific screen for review, mirroring the iOS
        // -PreviewStep launch arg. e.g. `--es screen summerFootball`.
        val debugScreen = if (BuildConfig.DEBUG) intent?.getStringExtra("screen") else null

        reportNotificationOpen(intent?.getStringExtra("campaign"), intent?.getStringExtra("variant"))

        setContent {
            Pick1Theme {
                RootScaffold(
                    forceSkipOnboarding = skipOnboarding,
                    debugScreen = debugScreen,
                )
            }
        }
    }

    /** A notification tap arriving while the activity is already alive. */
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        reportNotificationOpen(intent.getStringExtra("campaign"), intent.getStringExtra("variant"))
    }

    /**
     * Record that a push was OPENED.
     *
     * push_log recorded that a notification left and nothing about whether it
     * landed, on both platforms. iOS closed that on 2026-09-02; Android never
     * had it. `mark_push_opened` matches the most recent unopened send of this
     * campaign to this user within a day and runs as the caller's own session,
     * so nobody can mark someone else's.
     *
     * Fire and forget. A failed analytics write must never surface to someone
     * who just tapped a notification.
     */
    private fun reportNotificationOpen(campaign: String?, variant: String?) {
        if (campaign.isNullOrEmpty()) return
        com.posthog.PostHog.capture(
            "notification_opened",
            properties = buildMap {
                put("campaign", campaign)
                variant?.let { put("variant", it) }
            },
        )
        kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.IO).launch {
            runCatching {
                com.pick1.app.data.Supabase.client
                    .postgrest
                    .rpc("mark_push_opened", buildJsonObject { put("p_key", campaign) })
            }
        }
    }
}
