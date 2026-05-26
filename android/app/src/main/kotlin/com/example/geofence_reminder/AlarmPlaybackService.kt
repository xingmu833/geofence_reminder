package com.example.geofence_reminder

import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.IBinder

class AlarmPlaybackService : Service() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(
            NativeNotificationHelper.ALARM_SERVICE_NOTIFICATION_ID,
            NativeNotificationHelper.buildAlarmServiceNotification(this)
        )
        startSound(
            source = intent?.getStringExtra("source") ?: "builtIn",
            id = intent?.getStringExtra("id") ?: "alarm_chime",
            uri = intent?.getStringExtra("uri")
        )
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopSound()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startSound(source: String, id: String, uri: String?) {
        stopSound()
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            isLooping = true
            if (source == "localFile" && !uri.isNullOrBlank()) {
                setDataSource(this@AlarmPlaybackService, Uri.parse(uri))
            } else {
                val resourceId = resources.getIdentifier(id, "raw", packageName)
                val fallbackId = resources.getIdentifier("alarm_chime", "raw", packageName)
                val afd = resources.openRawResourceFd(if (resourceId == 0) fallbackId else resourceId)
                afd.use {
                    setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
            }
            prepare()
            start()
        }
    }

    private fun stopSound() {
        mediaPlayer?.run {
            try {
                stop()
            } catch (_: Exception) {
            }
            release()
        }
        mediaPlayer = null
    }

    companion object {
        const val ACTION_STOP = "geofence_reminder.action.STOP_ALARM"
    }
}
