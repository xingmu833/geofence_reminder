package com.example.geofence_reminder

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

object NativeGeofenceManager {
    private const val requestPrefix = "reminder-"
    private const val geofenceResponsivenessMillis = 10_000

    fun sync(context: Context, reminderMaps: List<Map<String, Any?>>) {
        val previousById = NativeReminderStore.load(context).associateBy { it.id }
        val reminders = reminderMaps.map { map ->
            val next = NativeReminderStore.fromMap(map)
            mergeRuntimeState(previousById[next.id], next)
        }
        NativeReminderStore.saveSnapshot(context, reminders)
        val client = LocationServices.getGeofencingClient(context)
        if (reminders.isEmpty()) {
            client.removeGeofences(geofencePendingIntent(context))
            stopLocationScan(context)
            return
        }

        val geofences = reminders
            .filter { it.isEnabled }
            .map {
                Geofence.Builder()
                    .setRequestId(requestPrefix + it.id)
                    .setCircularRegion(
                        it.latitude,
                        it.longitude,
                        it.radiusMeters.toFloat()
                    )
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                    .setNotificationResponsiveness(geofenceResponsivenessMillis)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .build()
            }
        if (geofences.isEmpty()) {
            stopLocationScan(context)
            return
        }

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(0)
            .addGeofences(geofences)
            .build()
        try {
            markCurrentLocationAsBaseline(context)
            val pendingIntent = geofencePendingIntent(context)
            client.removeGeofences(pendingIntent).addOnCompleteListener {
                try {
                    client.addGeofences(request, pendingIntent)
                    startLocationScan(context)
                } catch (_: SecurityException) {
                    startLocationScan(context)
                }
            }
        } catch (_: SecurityException) {
            startLocationScan(context)
        }
    }

    fun restoreFromPrefs(context: Context) {
        val reminders = NativeReminderStore.load(context)
            .filter { it.isEnabled }
            .map { reminder ->
                mapOf<String, Any?>(
                    "id" to reminder.id,
                    "title" to reminder.title,
                    "locationName" to reminder.locationName,
                    "latitude" to reminder.latitude,
                    "longitude" to reminder.longitude,
                    "radiusMeters" to reminder.radiusMeters,
                    "isEnabled" to reminder.isEnabled,
                    "triggerLimit" to reminder.triggerLimit,
                    "dailyTriggerLimit" to reminder.dailyTriggerLimit,
                    "scheduleLabel" to reminder.scheduleLabel,
                    "alertMode" to reminder.alertMode,
                    "lastTriggeredAt" to nullableString(reminder, "lastTriggeredAt"),
                    "lastTriggeredLabel" to nullableString(reminder, "lastTriggeredLabel"),
                    "dailyTriggeredCount" to reminder.dailyTriggeredCount,
                    "dailyTriggerDate" to nullableString(reminder, "dailyTriggerDate"),
                    "isInsideGeofence" to reminder.isInsideGeofence
                )
            }
        sync(context, reminders)
    }

    private fun nullableString(reminder: NativeReminder, key: String): String? {
        return if (reminder.json.has(key) && !reminder.json.isNull(key)) {
            reminder.json.optString(key)
        } else {
            null
        }
    }

    private fun mergeRuntimeState(previous: NativeReminder?, next: NativeReminder): NativeReminder {
        if (previous == null || !isSameFence(previous, next)) {
            next.json.put("entryArmed", false)
            return NativeReminderStore.fromJson(next.json)
        }

        val merged = next.json
        merged.put("entryArmed", previous.entryArmed)
        if (previous.triggerLimit == "once" && previous.lastTriggeredAt != null) {
            merged.put("isEnabled", false)
        }
        if (previous.isInsideGeofence) {
            merged.put("isInsideGeofence", true)
        }
        copyRuntimeStringIfNewer(previous, next, "lastTriggeredAt")
        copyRuntimeString(previous, next, "lastTriggeredLabel")
        copyRuntimeStringIfNewer(previous, next, "dailyTriggerDate")
        if (previous.dailyTriggeredCount > next.dailyTriggeredCount) {
            merged.put("dailyTriggeredCount", previous.dailyTriggeredCount)
        }
        return NativeReminderStore.fromJson(merged)
    }

    private fun isSameFence(a: NativeReminder, b: NativeReminder): Boolean {
        return a.latitude == b.latitude &&
            a.longitude == b.longitude &&
            a.radiusMeters == b.radiusMeters
    }

    private fun copyRuntimeString(previous: NativeReminder, next: NativeReminder, key: String) {
        if (!previous.json.has(key) || previous.json.isNull(key)) {
            return
        }
        if (!next.json.has(key) || next.json.isNull(key) || next.json.optString(key).isBlank()) {
            next.json.put(key, previous.json.optString(key))
        }
    }

    private fun copyRuntimeStringIfNewer(previous: NativeReminder, next: NativeReminder, key: String) {
        if (!previous.json.has(key) || previous.json.isNull(key)) {
            return
        }
        val previousValue = previous.json.optString(key)
        val nextValue = if (next.json.has(key) && !next.json.isNull(key)) {
            next.json.optString(key)
        } else {
            ""
        }
        if (nextValue.isBlank() || previousValue > nextValue) {
            next.json.put(key, previousValue)
        }
    }

    fun remove(context: Context, reminderId: Int) {
        LocationServices.getGeofencingClient(context)
            .removeGeofences(listOf(requestPrefix + reminderId))
        if (NativeReminderStore.load(context).none { it.isEnabled }) {
            stopLocationScan(context)
        }
    }

    private fun startLocationScan(context: Context) {
        val intent = Intent(context, NativeLocationScanService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        } catch (_: Exception) {
        }
    }

    private fun stopLocationScan(context: Context) {
        context.stopService(Intent(context, NativeLocationScanService::class.java))
    }

    private fun markCurrentLocationAsBaseline(context: Context) {
        try {
            LocationServices.getFusedLocationProviderClient(context)
                .lastLocation
                .addOnSuccessListener { location ->
                    if (location != null) {
                        NativeReminderTrigger.scanAt(
                            context,
                            location.latitude,
                            location.longitude,
                            triggerOnEntry = false
                        )
                    }
                }
        } catch (_: SecurityException) {
        }
    }

    private fun geofencePendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, NativeGeofenceReceiver::class.java)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        return PendingIntent.getBroadcast(context, 1001, intent, flags)
    }
}
