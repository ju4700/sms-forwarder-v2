package com.example.sms_forwarder_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receiver for android.provider.Telephony.SMS_RECEIVED broadcast.
 * Does not require BROADCAST_SMS permission so normal SMS broadcasts are received.
 */
class SmsReceivedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        SmsReceiver().onReceive(context, intent)
    }
}
