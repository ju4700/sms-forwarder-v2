package com.example.sms_forwarder_v2

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.security.MessageDigest
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.min

class SmsForwardWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {

    private val senderPattern = Regex("^01[3-9]\\d{8}$")
    private val referencePattern = Regex("^[A-Z0-9][A-Z0-9 _./-]{1,31}$")
    private val transactionPattern = Regex("^[A-Z0-9]{8,20}$")

    override fun doWork(): Result {
        val queue = SmsQueueStore.readQueue(applicationContext)
        if (queue.isEmpty()) {
            return Result.success()
        }

        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val endpoint = prefs.getString("flutter.api_endpoint", "")?.trim().orEmpty()
        val maxAttempts = prefs.getInt("flutter.max_attempts", 12)

        if (endpoint.isBlank()) {
            return Result.retry()
        }

        val now = System.currentTimeMillis()
        val updated = mutableListOf<JSONObject>()
        var shouldRetryWorker = false

        queue.forEach { item ->
            val status = item.optString("status", "pending")
            if (status == "dead_letter" || status == "delivered") {
                updated.add(item)
                return@forEach
            }

            val nextRetryAt = item.optLong("nextRetryAt", 0L)
            if (nextRetryAt > now) {
                updated.add(item)
                shouldRetryWorker = true
                return@forEach
            }

            val body = item.optString("body", "")
            val parsed = parseBkash(body)
            if (parsed == null) {
                item.put("status", "dead_letter")
                item.put("lastError", "Parser could not match bKash template")
                updated.add(item)
                return@forEach
            }

            val idempotencyKey = buildId(parsed)
            val sent = sendPayload(
                endpoint = endpoint,
                idempotencyKey = idempotencyKey,
                payload = parsed,
                rawSms = body,
            )

            if (sent in 200..299) {
                item.put("status", "delivered")
                item.put("nextRetryAt", 0L)
                item.put("lastError", "")
                updated.add(item)
                return@forEach
            }

            val attempts = item.optInt("attemptCount", 0) + 1
            if (sent in 400..499 && !isRetryableHttpStatus(sent)) {
                item.put("attemptCount", attempts)
                item.put("status", "dead_letter")
                item.put("lastError", "HTTP $sent")
                updated.add(item)
            } else if (attempts >= maxAttempts) {
                item.put("attemptCount", attempts)
                item.put("status", "dead_letter")
                item.put("lastError", if (sent == 0) "Max attempts reached" else "HTTP $sent")
                updated.add(item)
            } else {
                val retryAt = now + computeBackoffMs(attempts)
                item.put("attemptCount", attempts)
                item.put("status", "retry_scheduled")
                item.put("nextRetryAt", retryAt)
                item.put("lastError", if (sent == 0) "Delivery failed" else "HTTP $sent")
                updated.add(item)
                shouldRetryWorker = true
            }
        }

        SmsQueueStore.writeQueue(applicationContext, updated)

        if (shouldRetryWorker) {
            NativeWorkScheduler.triggerImmediate(applicationContext)
        }

        return Result.success()
    }

    private fun parseBkash(body: String): ParsedSms? {
        val pattern = Regex(
            pattern = """(?i)(?:You\s+have\s+received|Received)\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s+([^.]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})""",
        )

        val match = pattern.find(body) ?: return null
        val amount = match.groupValues[1].toDoubleOrNull() ?: return null
        val sender = normalizePhone(match.groupValues[2])
        val reference = cleanReference(match.groupValues[3])
        val fee = match.groupValues[4].toDoubleOrNull() ?: 0.0
        val balance = match.groupValues[5].toDoubleOrNull() ?: 0.0
        val trxId = match.groupValues[6].trim().uppercase()
        val dateText = match.groupValues[7].trim()

        if (!isValidAmount(amount) || !isValidAmount(fee) || !isValidAmount(balance)) {
            return null
        }

        if (!senderPattern.matches(sender)) {
            return null
        }

        if (reference.isBlank() || !referencePattern.matches(reference)) {
            return null
        }

        if (!transactionPattern.matches(trxId)) {
            return null
        }

        val parsedDate = parseDate(dateText) ?: return null
        if (!isSaneTimestamp(parsedDate)) {
            return null
        }

        val localIso = toLocalIso(dateText)
        val utcIso = toUtcIso(dateText)

        return ParsedSms(
            sender = sender,
            amount = amount,
            reference = reference,
            fee = fee,
            balance = balance,
            trxId = trxId,
            localIso = localIso,
            utcIso = utcIso,
        )
    }

    private fun sendPayload(
        endpoint: String,
        idempotencyKey: String,
        payload: ParsedSms,
        rawSms: String,
    ): Int {
        val body = JSONObject().apply {
            put("schemaVersion", "1.0")
            put("idempotencyKey", idempotencyKey)
            put("number", payload.sender)
            put("amount", payload.amount)
            put("transactionId", payload.trxId)
            put("reference", payload.reference)
            put("datetimeLocal", payload.localIso)
            put("datetimeUtc", payload.utcIso)
            put("metadata", JSONObject().apply {
                put("fee", payload.fee)
                put("balance", payload.balance)
                put("rawSms", rawSms)
                put("parserVersion", "1.0.0-native")
            })
        }

        val url = runCatching { URL(endpoint) }.getOrNull() ?: return 0
        val connection = (url.openConnection() as? HttpURLConnection) ?: return 0

        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15000
            connection.readTimeout = 20000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("X-Idempotency-Key", idempotencyKey)

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(body.toString())
                writer.flush()
            }

            connection.responseCode
        } catch (_: Exception) {
            0
        } finally {
            connection.disconnect()
        }
    }

    private fun buildId(parsed: ParsedSms): String {
        val seed = "${parsed.trxId}|${parsed.amount}|${parsed.sender}|${parsed.localIso}"
        val digest = MessageDigest.getInstance("SHA-256").digest(seed.toByteArray())
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    private fun isRetryableHttpStatus(code: Int): Boolean {
        return code == 408 || code == 425 || code == 429 || (code >= 500 && code < 600)
    }

    private fun normalizePhone(raw: String): String {
        val digits = raw.replace(Regex("[^0-9]"), "")
        return when {
            digits.startsWith("880") && digits.length >= 13 -> "0${digits.substring(3)}"
            digits.startsWith("88") && digits.length > 11 -> digits.substring(2)
            else -> digits
        }
    }

    private fun cleanReference(raw: String): String {
        return raw.replace(Regex("\\s+"), " ").trim().uppercase()
    }

    private fun isValidAmount(value: Double): Boolean {
        return value >= 0.0 && value <= 1000000.0
    }

    private fun parseDate(text: String): Date? {
        val parser = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
            isLenient = false
        }
        return runCatching { parser.parse(text) }.getOrNull()
    }

    private fun isSaneTimestamp(value: Date): Boolean {
        val now = Date()
        val lower = Date(now.time - (365L * 3L * 24L * 60L * 60L * 1000L))
        val upper = Date(now.time + (5L * 60L * 1000L))
        return value.after(lower) && value.before(upper)
    }

    private fun toLocalIso(text: String): String {
        val parser = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
            isLenient = false
        }
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
        }
        val parsed = runCatching { parser.parse(text) }.getOrNull() ?: Date()
        return formatter.format(parsed)
    }

    private fun toUtcIso(text: String): String {
        val parser = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
            isLenient = false
        }
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val parsed = runCatching { parser.parse(text) }.getOrNull() ?: Date()
        return formatter.format(parsed)
    }

    private fun computeBackoffMs(attempts: Int): Long {
        val cappedShift = min(attempts, 20)
        val exp = 1000L shl cappedShift
        return min(exp, 60L * 60L * 1000L)
    }

    data class ParsedSms(
        val sender: String,
        val amount: Double,
        val reference: String,
        val fee: Double,
        val balance: Double,
        val trxId: String,
        val localIso: String,
        val utcIso: String,
    )
}
