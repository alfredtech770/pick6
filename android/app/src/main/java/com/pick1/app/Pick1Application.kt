package com.pick1.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import com.pick1.app.billing.Billing
import com.posthog.android.PostHogAndroid
import com.posthog.android.PostHogAndroidConfig

class Pick1Application : Application() {
    override fun onCreate() {
        super.onCreate()

        // Same PostHog project as iOS, so funnel events land in one place.
        PostHogAndroid.setup(
            this,
            PostHogAndroidConfig(
                apiKey = BuildConfig.POSTHOG_KEY,
                host = BuildConfig.POSTHOG_HOST,
            ).apply { captureScreenViews = true },
        )

        // Play Billing — connect early so the catalogue + entitlement are warm
        // before the paywall is ever shown.
        Billing.init(this)

        createNotificationChannel()
    }

    /**
     * Android requires an explicit channel for notifications. `pick1_alerts`
     * matches the manifest default so FCM pushes from the existing send-push
     * Edge Function land here, with the custom win sound.
     */
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "pick1_alerts",
            getString(R.string.settings_notifications),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.settings_notifications_sub)
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
