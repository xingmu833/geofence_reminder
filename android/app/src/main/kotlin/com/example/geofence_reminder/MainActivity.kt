package com.example.geofence_reminder

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "geofence_reminder/device_settings"

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
