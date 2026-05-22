package com.example.geofence_reminder

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "geofence_reminder/device_settings"
    private val alarmAudioChannelName = "geofence_reminder/alarm_audio"
    private val pickAlarmAudioRequestCode = 9181
    private var alarmMediaPlayer: MediaPlayer? = null
    private var pendingPickAlarmAudioResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "brand" to Build.BRAND,
                            "model" to Build.MODEL
                        )
                    )
                    "openVendorPowerSettings" -> result.success(openVendorPowerSettings())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmAudioChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarmSound" -> {
                        val source = call.argument<String>("source") ?: "builtIn"
                        val id = call.argument<String>("id") ?: "alarm_chime"
                        val uri = call.argument<String>("uri")
                        try {
                            startAlarmSound(source, id, uri)
                        } catch (_: Exception) {
                            startAlarmSound("builtIn", "alarm_chime", null)
                        }
                        result.success(null)
                    }
                    "stopAlarmSound" -> {
                        stopAlarmSound()
                        result.success(null)
                    }
                    "pickAlarmAudio" -> pickAlarmAudio(result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stopAlarmSound()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickAlarmAudioRequestCode) {
            return
        }

        val result = pendingPickAlarmAudioResult ?: return
        pendingPickAlarmAudioResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: Exception) {
        }

        result.success(
            mapOf(
                "name" to resolveDisplayName(uri),
                "uri" to uri.toString()
            )
        )
    }

    private fun startAlarmSound(source: String, id: String, uri: String?) {
        stopAlarmSound()
        alarmMediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            isLooping = true
            if (source == "localFile" && !uri.isNullOrBlank()) {
                setDataSource(this@MainActivity, Uri.parse(uri))
            } else {
                val resourceId = resources.getIdentifier(id, "raw", packageName)
                val afd = resources.openRawResourceFd(
                    if (resourceId == 0) {
                        resources.getIdentifier("alarm_chime", "raw", packageName)
                    } else {
                        resourceId
                    }
                )
                afd.use {
                    setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
            }
            prepare()
            start()
        }
    }

    private fun stopAlarmSound() {
        alarmMediaPlayer?.run {
            try {
                stop()
            } catch (_: Exception) {
            }
            release()
        }
        alarmMediaPlayer = null
    }

    private fun pickAlarmAudio(result: MethodChannel.Result) {
        if (pendingPickAlarmAudioResult != null) {
            result.error("pick_in_progress", "已有音频选择正在进行", null)
            return
        }

        pendingPickAlarmAudioResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, pickAlarmAudioRequestCode)
        } catch (error: Exception) {
            pendingPickAlarmAudioResult = null
            result.error("pick_failed", error.message, null)
        }
    }

    private fun resolveDisplayName(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex("_display_name")
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                return cursor.getString(nameIndex)
            }
        }
        return uri.lastPathSegment ?: "本地音频"
    }

    private fun openVendorPowerSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val deviceName = "$manufacturer $brand"
        val candidates = mutableListOf<Intent>()

        if (deviceName.contains("xiaomi") || deviceName.contains("redmi") || deviceName.contains("poco")) {
            candidates.add(componentIntent("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"))
            candidates.add(componentIntent("com.miui.securitycenter", "com.miui.powercenter.PowerSettings"))
        }
        if (deviceName.contains("vivo") || deviceName.contains("iqoo")) {
            candidates.add(componentIntent("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"))
            candidates.add(componentIntent("com.iqoo.secure", "com.iqoo.secure.safeguard.PurviewTabActivity"))
        }
        if (deviceName.contains("oppo") || deviceName.contains("realme") || deviceName.contains("oneplus")) {
            candidates.add(componentIntent("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"))
            candidates.add(componentIntent("com.oplus.safecenter", "com.oplus.athena.powersave.PowerSaveActivity"))
        }
        if (deviceName.contains("huawei") || deviceName.contains("honor")) {
            candidates.add(componentIntent("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"))
        }

        candidates.add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        })
        candidates.add(Intent(Settings.ACTION_SETTINGS))

        return candidates.any { startSafely(it) }
    }

    private fun componentIntent(packageName: String, className: String): Intent {
        return Intent().apply {
            component = ComponentName(packageName, className)
        }
    }

    private fun startSafely(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}
