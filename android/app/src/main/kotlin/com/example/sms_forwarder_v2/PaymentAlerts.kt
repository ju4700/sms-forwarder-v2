package com.example.sms_forwarder_v2

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

object PaymentAlerts {
    fun show(context: Context, message: String) {
        runCatching {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(NotificationChannel("payment_errors", "Payment delivery errors", NotificationManager.IMPORTANCE_HIGH))
            }
            val intent = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            manager.notify(1002, NotificationCompat.Builder(context, "payment_errors")
                .setSmallIcon(R.mipmap.ic_launcher).setContentTitle("Payment forwarding needs attention")
                .setContentText(message).setContentIntent(intent).setAutoCancel(true).build())
        }
    }
}
