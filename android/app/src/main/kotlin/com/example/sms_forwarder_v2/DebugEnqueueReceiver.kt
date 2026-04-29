package com.example.sms_forwarder_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Debug-only receiver to enqueue a test SMS via adb broadcast.
 * Usage:
 * adb shell am broadcast -a com.example.sms_forwarder_v2.DEBUG_ENQUEUE --es sender "+8801..." --es body "..." --ei timestamp 123456789
 */
class DebugEnqueueReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action != "com.example.sms_forwarder_v2.DEBUG_ENQUEUE") return

            val sender = intent.getStringExtra("sender") ?: "+000000000"
            val body = intent.getStringExtra("body") ?: "DEBUG SMS"
            val timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis())

            Log.i("DebugEnqueueReceiver", "Debug enqueue from $sender: ${body.take(120)}")

            SmsQueueStore.enqueue(context, sender, body, timestamp, true)
            NativeWorkScheduler.triggerImmediate(context)

            Log.i("DebugEnqueueReceiver", "Enqueued debug SMS and triggered work")
        } catch (e: Exception) {
            Log.e("DebugEnqueueReceiver", "Failed to enqueue debug SMS: ${e.message}", e)
        }
    }
}
