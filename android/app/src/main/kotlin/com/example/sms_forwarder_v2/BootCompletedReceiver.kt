package com.example.sms_forwarder_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
            return
        }

        Log.d("BootCompletedReceiver", "Boot completed received")

        try {
            Log.d("BootCompletedReceiver", "Scheduling work after boot")
            NativeWorkScheduler.ensurePeriodic(context)
            NativeWorkScheduler.triggerImmediate(context)
        } catch (e: Exception) {
            Log.e("BootCompletedReceiver", "Failed to schedule work: ${e.message}", e)
        }

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.foreground_mode", false)
            if (!enabled) {
                Log.d("BootCompletedReceiver", "Foreground mode disabled, skipping service start")
                return
            }

            Log.i("BootCompletedReceiver", "Starting foreground service after boot")
            val serviceIntent = Intent(context, SmsMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: Exception) {
            Log.e("BootCompletedReceiver", "Failed to start foreground service: ${e.message}", e)
        }
    }
}
