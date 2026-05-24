package com.example.geofence_reminder

import android.content.Context
import android.location.Location
import java.util.Date

object NativeReminderTrigger {
    private const val scanTriggerCooldownMillis = 30 * 1000L

    fun triggerById(context: Context, reminderId: Int) {
        val reminders = NativeReminderStore.load(context)
        val index = reminders.indexOfFirst { it.id == reminderId }
        if (index == -1) {
            return
        }
        if (reminders[index].isInsideGeofence) {
            return
        }
        triggerIndex(context, reminders, index)
    }

    fun markOutside(context: Context, reminderId: Int) {
        val reminders = NativeReminderStore.load(context)
        val index = reminders.indexOfFirst { it.id == reminderId }
        if (index == -1 || !reminders[index].isInsideGeofence) {
            return
        }
        reminders[index] = NativeReminderStore.markInside(reminders[index], false)
        NativeReminderStore.save(context, reminders)
    }

    fun scanAt(
        context: Context,
        latitude: Double,
        longitude: Double,
        triggerOnEntry: Boolean = true
    ) {
        val reminders = NativeReminderStore.load(context)
        if (reminders.isEmpty()) {
            return
        }

        var changed = false
        for (index in reminders.indices) {
            val reminder = reminders[index]
            val distance = distanceMeters(
                latitude,
                longitude,
                reminder.latitude,
                reminder.longitude
            )
            val isInside = distance <= reminder.radiusMeters
            if (!isInside) {
                if (reminder.isInsideGeofence) {
                    reminders[index] = NativeReminderStore.markInside(reminder, false)
                    changed = true
                }
                continue
            }

            if (reminder.isInsideGeofence) {
                continue
            }

            if (!triggerOnEntry) {
                reminders[index] = NativeReminderStore.markInside(reminder, true)
                changed = true
                continue
            }

            changed = triggerIndex(context, reminders, index) || changed
        }

        if (changed) {
            NativeReminderStore.save(context, reminders)
        }
    }

    private fun triggerIndex(
        context: Context,
        reminders: MutableList<NativeReminder>,
        index: Int
    ): Boolean {
        val reminder = reminders[index]
        if (reminder.isInsideGeofence) {
            return false
        }

        val now = Date()
        if (!NativeReminderStore.canTriggerAt(reminder, now) || isInCooldown(reminder, now)) {
            reminders[index] = NativeReminderStore.markInside(reminder, true)
            NativeReminderStore.save(context, reminders)
            return true
        }

        NativeNotificationHelper.showReminder(context, reminder)
        reminders[index] = NativeReminderStore.markTriggered(reminder, now)
        NativeReminderStore.save(context, reminders)

        if (!reminders[index].isEnabled) {
            NativeGeofenceManager.remove(context, reminder.id)
        }
        return true
    }

    private fun isInCooldown(reminder: NativeReminder, now: Date): Boolean {
        val last = reminder.lastTriggeredAt ?: return false
        return now.time - last.time < scanTriggerCooldownMillis
    }

    private fun distanceMeters(
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double
    ): Float {
        val result = FloatArray(1)
        Location.distanceBetween(
            startLatitude,
            startLongitude,
            endLatitude,
            endLongitude,
            result
        )
        return result[0]
    }
}
