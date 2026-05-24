package com.example.geofence_reminder

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmAlertActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()

        val reminderId = intent.getIntExtra(EXTRA_REMINDER_ID, 0)
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
            .ifBlank { "\u5230\u8FBE\u63D0\u9192\u5730\u70B9" }
        val location = intent.getStringExtra(EXTRA_LOCATION).orEmpty()
            .ifBlank { "\u76EE\u6807\u5730\u70B9" }

        setContentView(buildContent(reminderId, title, location))
    }

    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )
    }

    private fun buildContent(reminderId: Int, title: String, location: String): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(32), dp(28), dp(32))
            setBackgroundColor(Color.rgb(15, 23, 42))
        }

        root.addView(TextView(this).apply {
            text = "\u5F3A\u63D0\u9192"
            setTextColor(Color.rgb(219, 234, 254))
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(dp(18), dp(8), dp(18), dp(8))
            background = roundedDrawable(Color.rgb(37, 99, 235), dp(24).toFloat())
        })

        root.addView(TextView(this).apply {
            text = "\u5DF2\u5230\u8FBE\u76EE\u6807\u5730\u70B9"
            setTextColor(Color.WHITE)
            textSize = 30f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(28), 0, 0)
        })

        root.addView(TextView(this).apply {
            text = title
            setTextColor(Color.rgb(226, 232, 240))
            textSize = 22f
            gravity = Gravity.CENTER
            setPadding(0, dp(18), 0, 0)
        })

        root.addView(TextView(this).apply {
            text = location
            setTextColor(Color.rgb(148, 163, 184))
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(0, dp(10), 0, dp(34))
        })

        root.addView(Button(this).apply {
            text = "\u505C\u6B62\u63D0\u9192"
            textSize = 18f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            background = roundedDrawable(Color.rgb(37, 99, 235), dp(16).toFloat())
            setPadding(dp(24), dp(14), dp(24), dp(14))
            setOnClickListener {
                stopAlarm(reminderId)
                finish()
            }
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        root.addView(Button(this).apply {
            text = "\u6253\u5F00\u5E94\u7528"
            textSize = 16f
            setTextColor(Color.rgb(219, 234, 254))
            background = roundedDrawable(Color.rgb(30, 41, 59), dp(16).toFloat())
            setPadding(dp(24), dp(12), dp(24), dp(12))
            setOnClickListener {
                stopAlarm(reminderId)
                startActivity(Intent(this@AlarmAlertActivity, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra("reminderId", reminderId)
                })
                finish()
            }
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = dp(12)
        })

        return root
    }

    private fun stopAlarm(reminderId: Int) {
        startService(Intent(this, AlarmPlaybackService::class.java).apply {
            action = AlarmPlaybackService.ACTION_STOP
        })
        val manager = getSystemService(NotificationManager::class.java)
        manager.cancel(NativeNotificationHelper.notificationId(reminderId))
        manager.cancel(NativeNotificationHelper.ALARM_SERVICE_NOTIFICATION_ID)
    }

    private fun roundedDrawable(color: Int, radius: Float): android.graphics.drawable.Drawable {
        return android.graphics.drawable.GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_REMINDER_ID = "reminderId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_LOCATION = "location"
    }
}
