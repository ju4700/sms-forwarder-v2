package com.example.sms_forwarder_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        // Android 15 prohibits launching dataSync foreground services from boot.
        NativeWorkScheduler.ensurePeriodic(context)
        NativeWorkScheduler.triggerImmediate(context)
    }
}
