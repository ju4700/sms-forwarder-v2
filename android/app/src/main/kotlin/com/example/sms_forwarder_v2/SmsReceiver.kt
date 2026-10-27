package com.example.sms_forwarder_v2

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "sms_forwarder_incoming_channel"
        private const val NOTIFICATION_CHANNEL_NAME = "Incoming SMS Notifications"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        val action = intent.action
        val isDefaultSmsApp = isDefaultSmsApp(context)
        val shouldProcess = when {
            isDefaultSmsApp -> action == Telephony.Sms.Intents.SMS_DELIVER_ACTION
            else -> action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION
        }

        if (!shouldProcess) {
            try { pendingResult.finish() } catch (_: Exception) {}
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

            // If we are the default SMS app, write to Android's system SMS inbox
            if (isDefaultSmsApp) {
                saveToSystemTelephonyProvider(context, sender, body, timestamp)
                postSmsNotification(context, sender, body)
            }

            if (SmsQueueStore.containsMessage(context, sender, body, timestamp)) {
                Log.i("SmsReceiver", "Duplicate SMS ignored from $sender at $timestamp")
                return
            }

            val shouldForward = ruleMatches(context, sender, body)
            Log.i("SmsReceiver", "Captured SMS from $sender (${body.length} chars), forward=$shouldForward")

            if (!shouldForward) {
                Log.d("SmsReceiver", "SMS from $sender does not match any forward rules, skipping queue")
                return
            }

            val enqueued = SmsQueueStore.enqueue(context, sender, body, timestamp, true)
            if (!enqueued) {
                return
            }

            NativeWorkScheduler.ensurePeriodic(context)
            NativeWorkScheduler.triggerImmediate(context)
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed in onReceive: ${e.message}", e)
        } finally {
            try {
                pendingResult.finish()
            } catch (_: Exception) {}
        }
    }

    private fun saveToSystemTelephonyProvider(context: Context, sender: String, body: String, timestamp: Long) {
        try {
            val values = ContentValues().apply {
                put(Telephony.Sms.ADDRESS, sender)
                put(Telephony.Sms.BODY, body)
                put(Telephony.Sms.DATE, timestamp)
                put(Telephony.Sms.READ, 0)
                put(Telephony.Sms.SEEN, 0)
                put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
            }
            context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)
            Log.d("SmsReceiver", "Successfully saved incoming SMS to system provider for $sender")
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed to save SMS to system provider: ${e.message}")
        }
    }

    private fun postSmsNotification(context: Context, sender: String, body: String) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    NOTIFICATION_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alerts for incoming SMS messages"
                    enableVibration(true)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val notificationId = sender.hashCode().and(0x7FFFFFFF)

            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("sender", sender)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                notificationId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // MessagingStyle Person (Google Messages style)
            val person = androidx.core.app.Person.Builder()
                .setName(sender)
                .build()

            val messagingStyle = NotificationCompat.MessagingStyle(person)
                .addMessage(body, System.currentTimeMillis(), person)

            val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.sym_action_chat)
                .setStyle(messagingStyle)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)

            // Direct Reply Action via RemoteInput
            val remoteInput = androidx.core.app.RemoteInput.Builder(NotificationActionReceiver.KEY_TEXT_REPLY)
                .setLabel("Reply")
                .build()

            val replyIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_REPLY
                putExtra(NotificationActionReceiver.EXTRA_SENDER, sender)
                putExtra(NotificationActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            }
            val replyPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId + 1,
                replyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            )

            val replyAction = NotificationCompat.Action.Builder(
                android.R.drawable.ic_menu_send,
                "Reply",
                replyPendingIntent
            ).addRemoteInput(remoteInput).build()
            builder.addAction(replyAction)

            // Mark as Read Action
            val markReadIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_MARK_READ
                putExtra(NotificationActionReceiver.EXTRA_SENDER, sender)
                putExtra(NotificationActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            }
            val markReadPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId + 2,
                markReadIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val markReadAction = NotificationCompat.Action.Builder(
                android.R.drawable.checkbox_on_background,
                "Mark Read",
                markReadPendingIntent
            ).build()
            builder.addAction(markReadAction)

            // 1-Tap Copy OTP Action if message is an OTP
            if (isSecurityOrOtp(body.lowercase())) {
                val otp = extractOtpCode(body)
                if (!otp.isNullOrBlank()) {
                    val copyOtpIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                        action = NotificationActionReceiver.ACTION_COPY_OTP
                        putExtra(NotificationActionReceiver.EXTRA_OTP, otp)
                        putExtra(NotificationActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
                    }
                    val copyOtpPendingIntent = PendingIntent.getBroadcast(
                        context,
                        notificationId + 3,
                        copyOtpIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val copyAction = NotificationCompat.Action.Builder(
                        android.R.drawable.ic_menu_save,
                        "Copy $otp",
                        copyOtpPendingIntent
                    ).build()
                    builder.addAction(copyAction)
                }
            }

            notificationManager.notify(notificationId, builder.build())
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed to post SMS notification: ${e.message}")
        }
    }

    private fun extractOtpCode(body: String): String? {
        val regex = Regex("""\b([0-9]{4,8})\b""")
        return regex.find(body)?.groupValues?.getOrNull(1)
    }


    private fun ruleMatches(context: Context, sender: String, body: String): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.capture_rules_json", "[]") ?: "[]"
        val json = runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
        val lowerBody = body.lowercase()
        val lowerSender = sender.lowercase()

        // Fallback: If capture rules have not yet synced from Flutter, do not discard SMS;
        // safely match standard financial transactions
        if (json.length() == 0) {
            if (isSecurityOrOtp(lowerBody)) return false
            if (isPromotionalOrSpam(lowerBody)) return false
            return templateMatches("all", lowerSender, lowerBody)
        }

        for (i in 0 until json.length()) {
            val rule = json.optJSONObject(i) ?: continue
            if (!rule.optBoolean("enabled", true)) {
                continue
            }

            val filterOtp = rule.optBoolean("filterOtp", true)
            if (filterOtp && isSecurityOrOtp(lowerBody)) {
                Log.d("SmsReceiver", "Blocked by security/OTP shield")
                continue
            }

            val filterSpam = rule.optBoolean("filterSpam", true)
            if (filterSpam && isPromotionalOrSpam(lowerBody)) {
                Log.d("SmsReceiver", "Blocked by promotional spam filter")
                continue
            }

            val direction = rule.optString("direction", "credit")
            if (direction != "all") {
                val detectedDirection = detectDirection(lowerBody)
                if (direction == "credit" && detectedDirection == "debit") {
                    Log.d("SmsReceiver", "Skipped debit transaction for credit-only rule")
                    continue
                }
                if (direction == "debit" && detectedDirection == "credit") {
                    Log.d("SmsReceiver", "Skipped credit transaction for debit-only rule")
                    continue
                }
            }

            val minAmount = rule.optDouble("minAmount", 0.0)
            if (minAmount > 0.0) {
                val amount = extractAmount(body)
                if (amount != null && amount < minAmount) {
                    Log.d("SmsReceiver", "Skipped: amount $amount below minAmount $minAmount")
                    continue
                }
            }

            val type = rule.optString("type", "")
            if (type == "custom_format") {
                val format = rule.optString("customFormat", "")
                if (format.isNotBlank() && CustomSmsFormatParser.matches(format, body)) {
                    val senderPattern = rule.optString("senderPattern", "")
                    if (senderPattern.isBlank() || Regex(senderPattern, RegexOption.IGNORE_CASE).containsMatchIn(sender)) {
                        return true
                    }
                }
                continue
            }

            if (type == "template") {
                val key = rule.optString("templateKey", "all")
                if (templateMatches(key, lowerSender, lowerBody)) {
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

    private fun isSecurityOrOtp(lowerBody: String): Boolean {
        val otpRegex = Regex("""\botp\b""", RegexOption.IGNORE_CASE)
        return lowerBody.contains("verification code") ||
            lowerBody.contains("security code") ||
            lowerBody.contains("login code") ||
            lowerBody.contains("one time password") ||
            lowerBody.contains("secret pin") ||
            lowerBody.contains("do not share") ||
            otpRegex.containsMatchIn(lowerBody)
    }

    private fun isPromotionalOrSpam(lowerBody: String): Boolean {
        // Legitimate transaction confirmations containing TrxID or TxnID are never promotional spam
        if (lowerBody.contains("trxid") || lowerBody.contains("txnid")) {
            return false
        }
        return lowerBody.contains("cashback") ||
            lowerBody.contains("offer") ||
            lowerBody.contains("bonus") ||
            lowerBody.contains("dial *247#") ||
            lowerBody.contains("dial *167#") ||
            lowerBody.contains("dial *322#") ||
            lowerBody.contains("download app") ||
            lowerBody.contains("promo") ||
            lowerBody.contains("discount") ||
            lowerBody.contains("recharge offer")
    }

    private fun detectDirection(lowerBody: String): String {
        if (lowerBody.contains("received") ||
            lowerBody.contains("cash in") ||
            lowerBody.contains("credited") ||
            lowerBody.contains("payment received") ||
            lowerBody.contains("deposit")) {
            return "credit"
        }
        if (lowerBody.contains("payment to") ||
            lowerBody.contains("payment successful") ||
            lowerBody.contains("cash out") ||
            lowerBody.contains("send money") ||
            lowerBody.contains("sent to") ||
            lowerBody.contains("debited") ||
            lowerBody.contains("bill successfully paid") ||
            lowerBody.contains("withdrawn")) {
            return "debit"
        }
        return "unknown"
    }

    private fun extractAmount(body: String): Double? {
        val regex = Regex("""(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)""", RegexOption.IGNORE_CASE)
        val match = regex.find(body) ?: return null
        val raw = match.groupValues.getOrNull(1)?.replace(",", "")?.trim() ?: return null
        return raw.toDoubleOrNull()
    }

    private fun templateMatches(key: String, lowerSender: String, lowerBody: String): Boolean {
        return when (key.lowercase()) {
            "all" -> (lowerSender.contains("bkash") || lowerSender.contains("nagad") || lowerSender.contains("rocket") ||
                lowerSender.contains("dbbl") || lowerSender.contains("bank") || lowerSender.contains("upay") ||
                lowerSender.contains("cellfin") || lowerSender.contains("mpesa") || lowerSender.contains("gcash") ||
                lowerSender.contains("upi") || lowerBody.contains("trxid") || lowerBody.contains("txnid") ||
                lowerBody.contains("credited") || lowerBody.contains("balance"))
            "bkash" -> lowerSender.contains("bkash") || lowerSender == "16247" || (lowerBody.contains("trxid") && lowerBody.contains("balance"))
            "nagad" -> lowerSender.contains("nagad") || lowerSender == "16167" || lowerBody.contains("nagad") || lowerBody.contains("txnid")
            "rocket" -> lowerSender.contains("rocket") || lowerSender == "16216" || lowerSender.contains("dbbl") || lowerBody.contains("rocket")
            "upay" -> lowerSender.contains("upay") || lowerBody.contains("upay")
            "cellfin" -> lowerSender.contains("cellfin") || lowerBody.contains("cellfin") || lowerBody.contains("ibbl")
            "mpesa" -> lowerSender.contains("mpesa") || lowerBody.contains("m-pesa") || lowerBody.contains("mpesa")
            "gcash" -> lowerSender.contains("gcash") || lowerBody.contains("gcash")
            "upi" -> lowerSender.contains("upi") || lowerBody.contains("upi") || lowerBody.contains("vpa")
            "bank" -> lowerSender.contains("bank") || lowerSender.contains("city") || lowerSender.contains("brac") ||
                lowerSender.contains("ebl") || lowerSender.contains("dbbl") || lowerSender.contains("scb") ||
                lowerSender.contains("ibbl") || lowerSender.contains("ific") || lowerSender.contains("ucb") ||
                lowerSender.contains("mtb") || lowerBody.contains("a/c") || lowerBody.contains("card ending")
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
