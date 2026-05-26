package com.example.geofence_reminder

import android.app.Service
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

class NativeLocationScanService : Service() {
    private val scanIntervalMillis = 15_000L
    private val fallbackScanIntervalMillis = 60_000L
    private val fastestIntervalMillis = 5_000L
    private val minDistanceMeters = 5f

    private val client by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private val handler = Handler(Looper.getMainLooper())
    private var hasBaselineScan = false
    private val periodicScan = object : Runnable {
        override fun run() {
            scanCurrentLocation()
            handler.postDelayed(this, fallbackScanIntervalMillis)
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(
            NativeNotificationHelper.LOCATION_SERVICE_NOTIFICATION_ID,
            NativeNotificationHelper.buildLocationServiceNotification(this)
        )
        scanCurrentLocation()
        handler.postDelayed(periodicScan, fallbackScanIntervalMillis)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (NativeReminderStore.load(this).none { it.isEnabled }) {
            stopSelf()
        } else {
            requestLocationUpdates()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(periodicScan)
        client.removeLocationUpdates(NativeLocationUpdatePendingIntent.create(this))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun requestLocationUpdates() {
        if (!hasBaselineScan) {
            scanCurrentLocation()
            return
        }
        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            scanIntervalMillis
        )
            .setMinUpdateDistanceMeters(minDistanceMeters)
            .setMinUpdateIntervalMillis(fastestIntervalMillis)
            .setMaxUpdateDelayMillis(scanIntervalMillis)
            .setWaitForAccurateLocation(true)
            .build()
        try {
            client.removeLocationUpdates(NativeLocationUpdatePendingIntent.create(this))
            client.requestLocationUpdates(request, NativeLocationUpdatePendingIntent.create(this))
        } catch (_: SecurityException) {
            stopSelf()
        }
    }

    private fun scanCurrentLocation() {
        try {
            val token = CancellationTokenSource()
            client.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, token.token)
                .addOnSuccessListener { location ->
                    if (location != null) {
                        val shouldTrigger = hasBaselineScan
                        NativeReminderTrigger.scanAt(
                            this,
                            location.latitude,
                            location.longitude,
                            triggerOnEntry = shouldTrigger
                        )
                        if (!shouldTrigger) {
                            hasBaselineScan = true
                            requestLocationUpdates()
                        }
                    } else {
                        scanLastKnownLocation()
                    }
                }
                .addOnFailureListener {
                    scanLastKnownLocation()
                }
        } catch (_: SecurityException) {
            stopSelf()
        }
    }

    private fun scanLastKnownLocation() {
        try {
            client.lastLocation.addOnSuccessListener { location ->
                if (location != null) {
                    val shouldTrigger = hasBaselineScan
                    NativeReminderTrigger.scanAt(
                        this,
                        location.latitude,
                        location.longitude,
                        triggerOnEntry = shouldTrigger
                    )
                    if (!shouldTrigger) {
                        hasBaselineScan = true
                        requestLocationUpdates()
                    }
                }
            }
        } catch (_: SecurityException) {
            stopSelf()
        }
    }
}
