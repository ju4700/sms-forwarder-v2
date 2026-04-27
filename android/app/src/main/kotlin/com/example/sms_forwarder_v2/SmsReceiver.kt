package com.example.sms_forwarder_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) {
            return
        }

        val body = buildString {
            messages.forEach { append(it.messageBody ?: "") }
        }.trim()

        if (body.isEmpty()) {
            return
        }

        val lower = body.lowercase()
        if (!(lower.contains("received") && lower.contains("trxid") && lower.contains("balance"))) {
            return
        }

        val sender = messages.firstOrNull()?.originatingAddress.orEmpty()
        val timestamp = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()
        SmsQueueStore.enqueue(context, sender, body, timestamp)
        NativeWorkScheduler.ensurePeriodic(context)
        NativeWorkScheduler.triggerImmediate(context)
    }
}
