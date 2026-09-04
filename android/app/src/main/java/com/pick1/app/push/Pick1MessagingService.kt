package com.pick1.app.push

import android.app.NotificationManager
import com.pick1.app.MainActivity
import android.content.Intent
import android.app.PendingIntent
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

        // Anything carrying a dollar figure rings the cha-ching, which lives
        // on its own channel because an Android channel is IMMUTABLE once
        // created and pick1_alerts can never be given a new sound.
        val moneyKeys = setOf(
            "result_win", "recap", "hot_streak", "big_odds",
            "free_recap", "free_recap_b", "week_missed",
        )
        val channel = if (campaign in moneyKeys) "pick1_money" else "pick1_alerts"

        // Tapping it has to OPEN something. Without a content intent the
        // notification was inert: it appeared, it was tapped, and nothing
        // happened. The campaign rides along so the app can record the open.
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            campaign?.let { putExtra("campaign", it) }
            variant?.let { putExtra("variant", it) }
        }
        val pending = PendingIntent.getActivity(
            this,
            campaign?.hashCode() ?: 0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        getSystemService(NotificationManager::class.java)
            .notify(System.currentTimeMillis().toInt(), notification)
    }
}
