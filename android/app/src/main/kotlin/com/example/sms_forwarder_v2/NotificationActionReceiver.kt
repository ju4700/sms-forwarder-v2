package com.example.sms_forwarder_v2

import android.app.NotificationManager
import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import android.widget.Toast

class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_REPLY = "com.example.sms_forwarder_v2.ACTION_NOTIFICATION_REPLY"
        const val ACTION_MARK_READ = "com.example.sms_forwarder_v2.ACTION_NOTIFICATION_MARK_READ"
        const val ACTION_COPY_OTP = "com.example.sms_forwarder_v2.ACTION_COPY_OTP"

        const val KEY_TEXT_REPLY = "key_text_reply"
        const val EXTRA_SENDER = "extra_sender"
        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        const val EXTRA_OTP = "extra_otp"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val sender = intent.getStringExtra(EXTRA_SENDER).orEmpty()
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        when (action) {
            ACTION_REPLY -> {
                val remoteInput = RemoteInput.getResultsFromIntent(intent)
                val replyText = remoteInput?.getCharSequence(KEY_TEXT_REPLY)?.toString()?.trim().orEmpty()
                if (sender.isNotBlank() && replyText.isNotBlank()) {
                    sendAndSaveSms(context, sender, replyText)
                    notificationManager?.cancel(notificationId)
                }
            }

            ACTION_MARK_READ -> {
                if (sender.isNotBlank()) {
                    markSmsReadInSystem(context, sender)
                }
                notificationManager?.cancel(notificationId)
            }

            ACTION_COPY_OTP -> {
                val otp = intent.getStringExtra(EXTRA_OTP).orEmpty()
                if (otp.isNotBlank()) {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                    val clip = ClipData.newPlainText("OTP Code", otp)
                    clipboard?.setPrimaryClip(clip)
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        Toast.makeText(context, "Copied code: $otp", Toast.LENGTH_SHORT).show()
                    }
                }
                notificationManager?.cancel(notificationId)
            }
        }
    }

    private fun sendAndSaveSms(context: Context, address: String, body: String) {
        try {
            val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }

            val parts = manager.divideMessage(body)
            if (parts.size > 1) {
                manager.sendMultipartTextMessage(address, null, parts, null, null)
            } else {
                manager.sendTextMessage(address, null, body, null, null)
            }

            // Save sent SMS to Telephony.Sms.Sent provider
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, address)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.SEEN, 1)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            }
            context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
            Log.i("NotificationAction", "Sent and saved direct reply to $address")
        } catch (e: Exception) {
            Log.e("NotificationAction", "Failed to send direct reply: ${e.message}", e)
        }
    }

    private fun markSmsReadInSystem(context: Context, address: String) {
        try {
            val values = ContentValues().apply {
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.SEEN, 1)
            }
            context.contentResolver.update(
                Telephony.Sms.CONTENT_URI,
                values,
                "${Telephony.Sms.ADDRESS} = ? AND ${Telephony.Sms.READ} = 0",
                arrayOf(address)
            )
            Log.i("NotificationAction", "Marked messages read for $address in system provider")
        } catch (e: Exception) {
            Log.e("NotificationAction", "Failed to mark read in system: ${e.message}", e)
        }
    }
}
