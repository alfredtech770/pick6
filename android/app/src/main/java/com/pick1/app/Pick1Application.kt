package com.pick1.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
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

        createNotificationChannels()
    }

    /**
     * Android requires an explicit channel per notification sound, and a
     * channel is IMMUTABLE once created: its sound cannot be changed later,
     * on any device that already has it. That is why the cha-ching needs a
     * second channel rather than an edit to `pick1_alerts`.
     *
     * Ordering matters. `send-push` must not name `pick1_money` until a
     * release carrying this channel is actually on phones, or the push
     * arrives addressed to a channel the device does not have.
     */
    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java)

        // Everything that is not money: picks, live scores, billing.
        val alerts = NotificationChannel(
            "pick1_alerts",
            getString(R.string.settings_notifications),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.settings_notifications_sub)
            enableVibration(true)
        }

        // Anything carrying a dollar figure, so the sound alone says what it
        // is before the phone is even out of a pocket.
        val money = NotificationChannel(
            "pick1_money",
            getString(R.string.settings_notifications),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.settings_notifications_sub)
            enableVibration(true)
            setSound(
                Uri.parse("android.resource://" + packageName + "/" + R.raw.chaching),
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build(),
            )
        }

        manager.createNotificationChannel(alerts)
        manager.createNotificationChannel(money)
    }
}
