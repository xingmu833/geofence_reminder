package com.example.geofence_reminder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object NativeNotificationHelper {
    const val LOCATION_SERVICE_NOTIFICATION_ID = 9101
    const val ALARM_SERVICE_NOTIFICATION_ID = 9001

    private const val notificationChannelId = "native_geofence_notification_v2"
    private const val alarmChannelId = "native_geofence_alarm_v2"
    private const val locationServiceChannelId = "native_geofence_location_service_v2"

    fun showReminder(context: Context, reminder: NativeReminder) {
        ensureChannels(context)
        val isAlarm = reminder.alertMode == "alarm"
        val title = if (isAlarm) "\u5230\u8FBE\u63D0\u9192\u5730\u70B9" else "\u4F4D\u7F6E\u63D0\u9192"
        val builder = notificationBuilder(
            context,
            if (isAlarm) alarmChannelId else notificationChannelId
        )
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle(title)
            .setContentText(reminder.title)
            .setTicker("\u4F4D\u7F6E\u63D0\u9192")
            .setAutoCancel(!isAlarm)
            .setOngoing(isAlarm)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(
                if (isAlarm) strongReminderPendingIntent(context, reminder) else openAppPendingIntent(context, reminder.id)
            )

        if (isAlarm) {
            builder.setCategory(Notification.CATEGORY_ALARM)
                .setPriority(Notification.PRIORITY_MAX)
                .setFullScreenIntent(strongReminderPendingIntent(context, reminder), true)
            startAlarmService(context, reminder)
        } else {
            builder.setCategory(Notification.CATEGORY_REMINDER)
                .setPriority(Notification.PRIORITY_HIGH)
        }

        val manager = context.getSystemService(NotificationManager::class.java)
        manager.notify(notificationId(reminder.id), builder.build())
        if (readVibrationEnabled(context)) {
            vibrate(context, isAlarm)
        }
    }

    fun buildAlarmServiceNotification(context: Context, sourceIntent: Intent? = null): Notification {
        ensureChannels(context)
        val contentPendingIntent = if (sourceIntent?.hasExtra("reminderId") == true) {
            val reminderId = sourceIntent.getIntExtra("reminderId", 0)
            val title = sourceIntent.getStringExtra("title") ?: "\u5F3A\u63D0\u9192"
            val body = sourceIntent.getStringExtra("location") ?: ""
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("strongReminderId", reminderId)
                putExtra("strongReminderTitle", title)
                putExtra("strongReminderBody", body)
            }
            PendingIntent.getActivity(context, 2002, intent, PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag())
        } else {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            PendingIntent.getActivity(context, 2002, intent, PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag())
        }
        return notificationBuilder(context, alarmChannelId)
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle("\u5F3A\u63D0\u9192\u54CD\u94C3\u4E2D")
            .setContentText("\u70B9\u51FB\u6253\u5F00\u63D0\u9192\u9875\u9762")
            .setPriority(Notification.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setContentIntent(contentPendingIntent)
            .build()
    }

    fun buildLocationServiceNotification(context: Context): Notification {
        ensureChannels(context)
        return notificationBuilder(context, locationServiceChannelId)
            .setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle("\u4F4D\u7F6E\u63D0\u9192\u8FD0\u884C\u4E2D")
            .setContentText("\u6B63\u5728\u68C0\u6D4B\u76EE\u6807\u5730\u70B9")
            .setPriority(Notification.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setOngoing(true)
            .setContentIntent(openAppPendingIntent(context, 0))
            .build()
    }

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        val notificationChannel = NotificationChannel(
            notificationChannelId,
            "\u4F4D\u7F6E\u63D0\u9192",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "\u8FDB\u5165\u76EE\u6807\u5730\u70B9\u65F6\u663E\u793A\u7684\u63D0\u9192"
            enableVibration(true)
        }
        val alarmChannel = NotificationChannel(
            alarmChannelId,
            "\u5F3A\u63D0\u9192",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "\u8FDB\u5165\u76EE\u6807\u5730\u70B9\u65F6\u663E\u793A\u7684\u9AD8\u4F18\u5148\u7EA7\u63D0\u9192"
            enableVibration(true)
            lightColor = Color.BLUE
        }
        val locationServiceChannel = NotificationChannel(
            locationServiceChannelId,
            "\u4F4D\u7F6E\u63D0\u9192\u670D\u52A1",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "\u4FDD\u6301\u4F4D\u7F6E\u63D0\u9192\u5728\u540E\u53F0\u8FD0\u884C"
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(notificationChannel)
        manager.createNotificationChannel(alarmChannel)
        manager.createNotificationChannel(locationServiceChannel)
    }

    private fun notificationBuilder(context: Context, channelId: String): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
    }

    private fun openAppPendingIntent(context: Context, reminderId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("reminderId", reminderId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        return PendingIntent.getActivity(context, reminderId, intent, flags)
    }

    private fun alarmAlertPendingIntent(context: Context, reminder: NativeReminder): PendingIntent {
        val intent = Intent(context, AlarmAlertActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(AlarmAlertActivity.EXTRA_REMINDER_ID, reminder.id)
            putExtra(AlarmAlertActivity.EXTRA_TITLE, reminder.title)
            putExtra(AlarmAlertActivity.EXTRA_LOCATION, reminder.locationName)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        return PendingIntent.getActivity(context, 10_000 + reminder.id, intent, flags)
    }

    private fun strongReminderPendingIntent(context: Context, reminder: NativeReminder): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("strongReminderId", reminder.id)
            putExtra("strongReminderTitle", "\u5230\u8FBE\u63D0\u9192\u5730\u70B9")
            putExtra("strongReminderBody", reminder.title)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        return PendingIntent.getActivity(context, 20_000 + reminder.id, intent, flags)
    }

    private fun startAlarmService(context: Context, reminder: NativeReminder) {
        val intent = Intent(context, AlarmPlaybackService::class.java).apply {
            putExtra("source", readAlarmSoundSource(context))
            putExtra("id", readAlarmSoundId(context))
            putExtra("uri", readAlarmSoundUri(context))
            putExtra("reminderId", reminder.id)
            putExtra("title", "\u5F3A\u63D0\u9192")
            putExtra("location", reminder.title)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (_: Exception) {
        }
    }

    private fun readVibrationEnabled(context: Context): Boolean {
        return context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.settings.vibrationEnabled", true)
    }

    private fun readAlarmSoundSource(context: Context): String {
        return context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.settings.alarmSound.source", "builtIn") ?: "builtIn"
    }

    private fun readAlarmSoundId(context: Context): String {
        return context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.settings.alarmSound.id", "alarm_chime") ?: "alarm_chime"
    }

    private fun readAlarmSoundUri(context: Context): String? {
        return context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.settings.alarmSound.uri", null)
    }

    private fun vibrate(context: Context, isAlarm: Boolean) {
        val pattern = if (isAlarm) longArrayOf(0, 800, 350, 800) else longArrayOf(0, 250)
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern, -1)
        }
    }

    fun notificationId(id: Int): Int {
        val normalized = id % 0x7fffffff
        return if (normalized == 0) 1 else normalized
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }
}
