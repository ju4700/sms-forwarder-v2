package com.example.sms_forwarder_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.role.RoleManager
import android.os.Build
import android.provider.Telephony
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val isDefaultSmsApp = isDefaultSmsApp(context)
        val shouldProcess = when {
            isDefaultSmsApp -> action == Telephony.Sms.Intents.SMS_DELIVER_ACTION
            else -> action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION
        }

        if (!shouldProcess) {
            return
        }

        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isEmpty()) {
                Log.v("SmsReceiver", "No messages in intent")
                return
            }

            val body = buildString {
                messages.forEach { append(it.messageBody ?: "") }
            }.trim()

            if (body.isEmpty()) {
                Log.v("SmsReceiver", "Empty message body")
                return
            }

            val sender = messages.firstOrNull()?.originatingAddress.orEmpty()
            val timestamp = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()

            if (sender.isBlank()) {
                Log.w("SmsReceiver", "Missing sender address")
                return
            }

            if (SmsQueueStore.containsMessage(context, sender, body, timestamp)) {
                Log.i("SmsReceiver", "Duplicate SMS ignored from $sender at $timestamp")
                return
            }

            // Check queue size to prevent OOM on message floods
            val queue = runCatching { SmsQueueStore.readQueue(context) }.getOrNull() ?: emptyList()
            if (queue.size >= 290) {
                Log.w("SmsReceiver", "Queue near capacity (${queue.size}/300), dropping SMS")
                return
            }

            val shouldForward = ruleMatches(context, sender, body)
            Log.i("SmsReceiver", "Captured SMS from $sender (${body.length} chars), forward=$shouldForward")

            val enqueued = SmsQueueStore.enqueue(context, sender, body, timestamp, shouldForward)
            if (!enqueued) {
                return
            }
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val portalDeviceId = prefs.getString("flutter.portal_device_id", "")?.trim().orEmpty()
            val portalSecret = prefs.getString("flutter.portal_device_secret", "")?.trim().orEmpty()
            val portalEnabled = portalDeviceId.isNotBlank() && portalSecret.isNotBlank()

            if (shouldForward || portalEnabled) {
                NativeWorkScheduler.ensurePeriodic(context)
                NativeWorkScheduler.triggerImmediate(context)
            }
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed in onReceive: ${e.message}", e)
        }
    }

    private fun ruleMatches(context: Context, sender: String, body: String): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.capture_rules_json", "[]") ?: "[]"
        val json = runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
        if (json.length() == 0) {
            return false
        }

        val lowerBody = body.lowercase()
        for (i in 0 until json.length()) {
            val rule = json.optJSONObject(i) ?: continue
            if (!rule.optBoolean("enabled", true)) {
                continue
            }

            val type = rule.optString("type", "")
            if (type == "template") {
                val key = rule.optString("templateKey", "")
                if (templateMatches(key, lowerBody)) {
                    return true
                }
                continue
            }

            if (type == "regex") {
                val senderPattern = rule.optString("senderPattern", "")
                val bodyPattern = rule.optString("bodyPattern", "")

                val senderOk = if (senderPattern.isNotBlank()) {
                    Regex(senderPattern, RegexOption.IGNORE_CASE).containsMatchIn(sender)
                } else {
                    true
                }

                val bodyOk = if (bodyPattern.isNotBlank()) {
                    Regex(bodyPattern, RegexOption.IGNORE_CASE).containsMatchIn(body)
                } else {
                    true
                }

                if (senderOk && bodyOk) {
                    return true
                }
            }
        }

        return false
    }

    private fun templateMatches(key: String, lowerBody: String): Boolean {
        return when (key.lowercase()) {
            "bkash" -> lowerBody.contains("trxid") && lowerBody.contains("balance")
            "rocket" -> lowerBody.contains("rocket") || lowerBody.contains("cash in")
            "dbbl" -> lowerBody.contains("dbbl") || lowerBody.contains("transaction")
            else -> false
        }
    }

    private fun isDefaultSmsApp(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = context.getSystemService(Context.ROLE_SERVICE) as RoleManager
                roleManager.isRoleHeld(RoleManager.ROLE_SMS)
            } else {
                Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
            }
        } catch (_: Exception) {
            false
        }
    }
}
