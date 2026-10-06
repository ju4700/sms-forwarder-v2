package com.example.sms_forwarder_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import java.util.concurrent.Executors

class SmsReceiver : BroadcastReceiver() {
    companion object { private val executor = Executors.newSingleThreadExecutor() }
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return
        val sender = messages.first().originatingAddress.orEmpty()
        if (!PaymentProtocol.trustedSender(sender) || messages.any { it.originatingAddress != sender }) return
        val body = messages.joinToString("") { it.messageBody.orEmpty() }.trim()
        val timestamp = messages.first().timestampMillis
        if (PaymentProtocol.parse(sender, body, timestamp) == null) return
        val pending = goAsync()
        executor.execute {
            try {
                if (SmsQueueStore.enqueue(context, sender, body, timestamp)) {
                    NativeWorkScheduler.ensurePeriodic(context)
                    NativeWorkScheduler.triggerImmediate(context)
                }
            } catch (_: Exception) {
                Log.e("SmsReceiver", "Receipt capture failed; recover receipts from the payment inbox")
                PaymentAlerts.show(context, "Receipt capture failed. Open the app and recover recent receipts.")
            } finally { pending.finish() }
        }
    }
}
