package com.example.geofence_reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
class NativeGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            return
        }
        val transition = event.geofenceTransition
        val ids = event.triggeringGeofences
            ?.mapNotNull { it.requestId.removePrefix("reminder-").toIntOrNull() }
            ?: return

        ids.forEach { id ->
            if (transition == Geofence.GEOFENCE_TRANSITION_ENTER) {
                NativeReminderTrigger.triggerById(context, id)
            }
        }
    }
}
