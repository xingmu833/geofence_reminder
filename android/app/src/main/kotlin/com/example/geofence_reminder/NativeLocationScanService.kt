package com.example.geofence_reminder

import android.app.Service
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

class NativeLocationScanService : Service() {
    private val scanIntervalMillis = 15_000L
    private val fastestIntervalMillis = 5_000L
    private val minDistanceMeters = 5f

    private val client by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private val handler = Handler(Looper.getMainLooper())
    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val location = result.lastLocation ?: return
            NativeReminderTrigger.scanAt(
                this@NativeLocationScanService,
                location.latitude,
                location.longitude
            )
        }
    }
    private val periodicScan = object : Runnable {
        override fun run() {
            scanCurrentLocation()
            handler.postDelayed(this, scanIntervalMillis)
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(
            NativeNotificationHelper.LOCATION_SERVICE_NOTIFICATION_ID,
            NativeNotificationHelper.buildLocationServiceNotification(this)
        )
        requestLocationUpdates()
        handler.post(periodicScan)
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
        client.removeLocationUpdates(locationCallback)
        client.removeLocationUpdates(NativeLocationUpdatePendingIntent.create(this))
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun requestLocationUpdates() {
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
            client.removeLocationUpdates(locationCallback)
            client.removeLocationUpdates(NativeLocationUpdatePendingIntent.create(this))
            client.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
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
                        NativeReminderTrigger.scanAt(this, location.latitude, location.longitude)
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
                    NativeReminderTrigger.scanAt(this, location.latitude, location.longitude)
                }
            }
        } catch (_: SecurityException) {
            stopSelf()
        }
    }
}
