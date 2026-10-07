package com.example.sms_forwarder_v2

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/** Optional visible monitoring; WorkManager and the SMS receiver provide capture/retry. */
class SmsMonitorService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel("payment_monitor", "Payment monitoring", NotificationManager.IMPORTANCE_LOW))
        }
        val notification = NotificationCompat.Builder(this, "payment_monitor").setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Payment forwarder active").setContentText("Monitoring incoming bKash receipts")
            .setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) startForeground(1001, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(1001, notification)
        NativeWorkScheduler.ensurePeriodic(this)
        NativeWorkScheduler.triggerImmediate(this)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_NOT_STICKY
    override fun onTimeout(startId: Int, fgsType: Int) { stopSelf() }
}
