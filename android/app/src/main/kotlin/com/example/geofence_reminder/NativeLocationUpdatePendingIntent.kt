package com.example.geofence_reminder

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object NativeLocationUpdatePendingIntent {
    fun create(context: Context): PendingIntent {
        val intent = Intent(context, NativeLocationReceiver::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        return PendingIntent.getBroadcast(context, 2001, intent, flags)
    }
}
