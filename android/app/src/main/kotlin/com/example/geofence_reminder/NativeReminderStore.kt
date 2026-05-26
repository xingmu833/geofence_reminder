package com.example.geofence_reminder

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.util.Date

data class NativeReminder(
    val json: JSONObject,
    val id: Int,
    val title: String,
    val locationName: String,
    val latitude: Double,
    val longitude: Double,
    val radiusMeters: Int,
    val isEnabled: Boolean,
    val triggerLimit: String,
    val dailyTriggerLimit: Int,
    val scheduleLabel: String,
    val alertMode: String,
    val lastTriggeredAt: Date?,
    val dailyTriggerDate: Date?,
    val dailyTriggeredCount: Int,
    val isInsideGeofence: Boolean,
    val entryArmed: Boolean
)

object NativeReminderStore {
    private const val nativePrefsName = "NativeReminderStore"
    private const val nativeRemindersKey = "reminders.v1"
    private const val flutterPrefsName = "FlutterSharedPreferences"
    private const val flutterRemindersKey = "flutter.reminders.v1"

    fun load(context: Context): MutableList<NativeReminder> {
        val raw = readRaw(context) ?: return mutableListOf()
        return try {
            val array = JSONArray(raw)
            MutableList(array.length()) { index ->
                fromJson(array.getJSONObject(index))
            }
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    fun save(context: Context, reminders: List<NativeReminder>) {
        val array = JSONArray()
        reminders.forEach { array.put(it.json) }
        saveRaw(context, array.toString())
    }

    fun saveSnapshot(context: Context, reminders: List<NativeReminder>) {
        save(context, reminders)
    }

    private fun readRaw(context: Context): String? {
        val nativeRaw = context.getSharedPreferences(nativePrefsName, Context.MODE_PRIVATE)
            .getString(nativeRemindersKey, null)
        if (!nativeRaw.isNullOrBlank()) {
            return nativeRaw
        }
        return context.getSharedPreferences(flutterPrefsName, Context.MODE_PRIVATE)
            .getString(flutterRemindersKey, null)
    }

    private fun saveRaw(context: Context, raw: String) {
        context.getSharedPreferences(nativePrefsName, Context.MODE_PRIVATE)
            .edit()
            .putString(nativeRemindersKey, raw)
            .apply()
        context.getSharedPreferences(flutterPrefsName, Context.MODE_PRIVATE)
            .edit()
            .putString(flutterRemindersKey, raw)
            .apply()
    }

    fun fromMap(map: Map<String, Any?>): NativeReminder {
        val json = JSONObject()
        map.forEach { (key, value) ->
            if (value != null) {
                json.put(key, value)
            }
        }
        return fromJson(json)
    }

    fun fromJson(json: JSONObject): NativeReminder {
        val lastTriggeredAt = parseDate(json.optString("lastTriggeredAt"))
        val dailyTriggerDate = parseDate(json.optString("dailyTriggerDate"))
        return NativeReminder(
            json = json,
            id = json.optInt("id"),
            title = json.optString("title"),
            locationName = json.optString("locationName"),
            latitude = json.optDouble("latitude"),
            longitude = json.optDouble("longitude"),
            radiusMeters = json.optInt("radiusMeters", 200),
            isEnabled = json.optBoolean("isEnabled", true),
            triggerLimit = json.optString("triggerLimit", "always"),
            dailyTriggerLimit = json.optInt("dailyTriggerLimit", 1).coerceIn(1, 24),
            scheduleLabel = json.optString("scheduleLabel"),
            alertMode = json.optString("alertMode", "notification"),
            lastTriggeredAt = lastTriggeredAt,
            dailyTriggerDate = dailyTriggerDate ?: if (json.optString("triggerLimit") == "daily") lastTriggeredAt else null,
            dailyTriggeredCount = json.optInt("dailyTriggeredCount", if (dailyTriggerDate == null) 0 else 1),
            isInsideGeofence = json.optBoolean("isInsideGeofence", false),
            entryArmed = json.optBoolean("entryArmed", false)
        )
    }

    fun markInside(reminder: NativeReminder, inside: Boolean): NativeReminder {
        reminder.json.put("isInsideGeofence", inside)
        return fromJson(reminder.json)
    }

    fun markEntryArmed(reminder: NativeReminder, inside: Boolean): NativeReminder {
        reminder.json.put("isInsideGeofence", inside)
        reminder.json.put("entryArmed", true)
        return fromJson(reminder.json)
    }

    fun markTriggered(reminder: NativeReminder, now: Date): NativeReminder {
        val nowIso = toIsoString(now)
        val nextDailyCount =
            if (reminder.dailyTriggerDate != null && isSameDay(reminder.dailyTriggerDate, now)) {
                reminder.dailyTriggeredCount + 1
            } else {
                1
            }
        reminder.json.put("isEnabled", if (reminder.triggerLimit == "once") false else reminder.isEnabled)
        reminder.json.put("lastTriggeredAt", nowIso)
        reminder.json.put("lastTriggeredLabel", formatTriggerTime(now))
        reminder.json.put("dailyTriggeredCount", nextDailyCount)
        reminder.json.put("dailyTriggerDate", nowIso)
        reminder.json.put("isInsideGeofence", true)
        return fromJson(reminder.json)
    }

    fun canTriggerAt(reminder: NativeReminder, now: Date): Boolean {
        if (!reminder.isEnabled || !isScheduleActiveAt(reminder, now)) {
            return false
        }
        if (reminder.triggerLimit == "once" && reminder.lastTriggeredAt != null) {
            return false
        }
        if (
            reminder.triggerLimit == "daily" &&
            reminder.dailyTriggerDate != null &&
            isSameDay(reminder.dailyTriggerDate, now) &&
            reminder.dailyTriggeredCount >= reminder.dailyTriggerLimit
        ) {
            return false
        }
        return true
    }

    private fun isScheduleActiveAt(reminder: NativeReminder, now: Date): Boolean {
        val range = Regex("""(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})""")
            .find(reminder.scheduleLabel) ?: return true
        val startHour = range.groupValues[1].toIntOrNull() ?: return true
        val startMinute = range.groupValues[2].toIntOrNull() ?: return true
        val endHour = range.groupValues[3].toIntOrNull() ?: return true
        val endMinute = range.groupValues[4].toIntOrNull() ?: return true
        val local = now.toInstant().atZone(ZoneId.systemDefault()).toLocalTime()
        val currentMinutes = local.hour * 60 + local.minute
        val startMinutes = startHour * 60 + startMinute
        val endMinutes = endHour * 60 + endMinute
        if (startMinutes == endMinutes) {
            return true
        }
        return if (startMinutes < endMinutes) {
            currentMinutes in startMinutes..endMinutes
        } else {
            currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }

    private fun parseDate(value: String?): Date? {
        if (value.isNullOrBlank()) {
            return null
        }
        return try {
            Date.from(java.time.Instant.parse(value))
        } catch (_: Exception) {
            try {
                val local = LocalDateTime.parse(value)
                Date.from(local.atZone(ZoneId.systemDefault()).toInstant())
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun toIsoString(date: Date): String {
        return date.toInstant().toString()
    }

    private fun isSameDay(a: Date, b: Date): Boolean {
        val zone = ZoneId.systemDefault()
        val dayA: LocalDate = a.toInstant().atZone(zone).toLocalDate()
        val dayB: LocalDate = b.toInstant().atZone(zone).toLocalDate()
        return dayA == dayB
    }

    private fun formatTriggerTime(time: Date): String {
        val zone = ZoneId.systemDefault()
        val local = time.toInstant().atZone(zone).toLocalDateTime()
        val now = LocalDateTime.now()
        val timeText = "%02d:%02d".format(local.hour, local.minute)
        return when (local.toLocalDate()) {
            now.toLocalDate() -> "Today $timeText"
            now.minusDays(1).toLocalDate() -> "Yesterday $timeText"
            else -> "${local.monthValue}/${local.dayOfMonth} $timeText"
        }
    }
}
