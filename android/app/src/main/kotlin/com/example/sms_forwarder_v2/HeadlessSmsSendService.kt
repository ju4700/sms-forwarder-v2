package com.example.sms_forwarder_v2

import android.app.Service
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log

class HeadlessSmsSendService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null && intent.action == "android.intent.action.RESPOND_VIA_MESSAGE") {
            val uri = intent.data
            var recipient = ""
            if (uri != null) {
                val ssp = uri.schemeSpecificPart ?: ""
                recipient = if (ssp.contains("?")) ssp.substringBefore("?") else ssp
                recipient = Uri.decode(recipient)
            }
            if (recipient.isBlank()) {
                recipient = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER) ?: ""
            }
            val text = intent.getStringExtra(Intent.EXTRA_TEXT).orEmpty()

            if (recipient.isNotBlank() && text.isNotBlank()) {
                sendAndSave(recipient, text)
            }
        }
        stopSelf(startId)
        return START_NOT_STICKY
    }

    private fun sendAndSave(recipient: String, text: String) {
        try {
            val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                applicationContext.getSystemService(SmsManager::class.java)
            } else {
                SmsManager.getDefault()
            }
            val parts = manager.divideMessage(text)
            if (parts.size > 1) {
                manager.sendMultipartTextMessage(recipient, null, parts, null, null)
            } else {
                manager.sendTextMessage(recipient, null, text, null, null)
            }

            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, recipient)
                put(Telephony.Sms.BODY, text)
                put(Telephony.Sms.DATE, System.currentTimeMillis())
                put(Telephony.Sms.READ, 1)
                put(Telephony.Sms.SEEN, 1)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
            }
            contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
            Log.i("HeadlessSmsSendService", "Successfully sent and saved quick-reply to $recipient")
        } catch (e: Exception) {
            Log.e("HeadlessSmsSendService", "Failed to send quick response: ${e.message}", e)
        }
    }
}
