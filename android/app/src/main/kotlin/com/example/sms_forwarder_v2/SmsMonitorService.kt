package com.example.sms_forwarder_v2

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.pm.ServiceInfo
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import android.content.Context

class SmsMonitorService : Service() {
    private var wakeLock: android.os.PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        
        val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
        wakeLock = powerManager.newWakeLock(
            android.os.PowerManager.PARTIAL_WAKE_LOCK,
            "SmsForwarder::MonitorWakeLock"
        )
        wakeLock?.acquire()
        
        createNotificationChannel()
        try {
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.d("SmsMonitorService", "Foreground service started")
            scheduleHeartbeat()
        } catch (e: Exception) {
            Log.e("SmsMonitorService", "Failed to start foreground service: ${e.message}", e)
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        scheduleHeartbeat()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean("flutter.foreground_mode", false)
        if (!enabled) {
            return
        }

        val restartIntent = Intent(applicationContext, SmsMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }
        cancelHeartbeat()
    }

    private fun scheduleHeartbeat() {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
            val intent = Intent(this, HeartbeatReceiver::class.java)
            val pendingIntent = android.app.PendingIntent.getBroadcast(
                this,
                0,
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            val triggerTime = System.currentTimeMillis() + 15 * 60 * 1000 // 15 minutes
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    android.app.AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }
        } catch (e: SecurityException) {
            Log.e("SmsMonitorService", "Cannot schedule exact alarm: ${e.message}. Falling back to inexact alarm.")
            try {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                val intent = Intent(this, HeartbeatReceiver::class.java)
                val pendingIntent = android.app.PendingIntent.getBroadcast(
                    this,
                    0,
                    intent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                val triggerTime = System.currentTimeMillis() + 15 * 60 * 1000
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        android.app.AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        android.app.AlarmManager.RTC_WAKEUP,
                        triggerTime,
                        pendingIntent
                    )
                }
            } catch (fallbackEx: Exception) {
                Log.e("SmsMonitorService", "Fallback inexact alarm also failed: ${fallbackEx.message}")
            }
        } catch (e: Exception) {
            Log.e("SmsMonitorService", "Failed to schedule heartbeat: ${e.message}")
        }
    }

    private fun cancelHeartbeat() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = Intent(this, HeartbeatReceiver::class.java)
        val pendingIntent = android.app.PendingIntent.getBroadcast(
            this,
            0,
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SMS Monitor",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Keeps SMS monitoring active for reliability"
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SMS Forwarder Active")
            .setContentText("Monitoring transaction SMS in reliability mode")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "sms_forwarder_monitor"
        private const val NOTIFICATION_ID = 1001
    }
}
