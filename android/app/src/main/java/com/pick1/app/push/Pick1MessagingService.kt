package com.pick1.app.push

import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.pick1.app.R
import com.posthog.PostHog

/**
 * Receives pushes from the existing `send-push` Edge Function.
 *
 * That function already stamps `campaign` (pick_drop / result_win /
 * free_recap …) and `variant` (the A/B arm) into the payload's data block —
 * we read the same keys here so Android opens are attributed in PostHog
 * exactly like the iOS `notificationOpened` event.
 *
 * NOTE: the Edge Function currently speaks APNs only. Adding an FCM branch
 * (and storing the FCM token alongside the APNs one) is the server-side half
 * of Android push.
 */
class Pick1MessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // Persist alongside the iOS APNs rows in device_tokens so send-push
        // can fan out to Android once it grows an FCM branch.
        PushManager.upload(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val campaign = message.data["campaign"]
        val variant = message.data["variant"]
        PostHog.capture(
            "notification_received",
            properties = buildMap {
                campaign?.let { put("campaign", it) }
                variant?.let { put("variant", it) }
            },
        )

        val title = message.notification?.title ?: return
        val body = message.notification?.body.orEmpty()

        val notification = NotificationCompat.Builder(this, "pick1_alerts")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(System.currentTimeMillis().toInt(), notification)
    }
}
