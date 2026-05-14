package com.example.sms_forwarder_v2

import android.content.Context
import android.util.Log
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

    companion object {
        private val workLock = Any()
    }

    private val senderPattern = Regex("^01[3-9]\\d{8}$")
    private val referencePattern = Regex("^[A-Z0-9][A-Z0-9 _./-]{1,31}$")
    private val transactionPattern = Regex("^[A-Z0-9]{8,20}$")

    override fun doWork(): Result = synchronized(workLock) {
        try {
            Log.d("SmsForwardWorker", "doWork started, attempt ${runAttemptCount + 1}")
            
            val queue = runCatching { SmsQueueStore.readQueue(applicationContext) }.getOrElse { 
                Log.w("SmsForwardWorker", "Failed to read queue, returning empty")
                emptyList()
            }
            if (queue.isEmpty()) {
                Log.d("SmsForwardWorker", "Queue is empty, finishing")
                return Result.success()
            }

            val prefs = runCatching {
                applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            }.getOrNull()
            
            val endpoint = prefs?.getString("flutter.api_endpoint", "")?.trim().orEmpty()
            val maxAttempts = readMaxAttempts(prefs) ?: 12

            val rulesJson = prefs?.getString("flutter.capture_rules_json", "[]") ?: "[]"

            if (endpoint.isBlank()) {
                Log.w("SmsForwardWorker", "No endpoint configured, skipping delivery")
                return Result.success()
            }
            Log.d("SmsForwardWorker", "Processing ${queue.size} items, max retries=$maxAttempts")

            val now = System.currentTimeMillis()
            val updated = mutableListOf<JSONObject>()
            var shouldRetryWorker = false
            var processedCount = 0
            var deliveredCount = 0

            queue.forEach { item ->
                try {
                    val status = item.optString("status", "pending")
                    if (status == "failed" || status == "dead_letter" || status == "delivered") {
                        updated.add(item)
                        return@forEach
                    }

                    val shouldForward = item.optBoolean("forward", false) ||
                        ruleMatches(rulesJson, item.optString("sender", ""), item.optString("body", ""))
                    if (!shouldForward) {
                        item.put("status", "captured")
                        item.put("lastEvent", "Captured (rule mismatch)")
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
                    val parsed = parseBkash(body, item.optString("sender", ""))
                    if (parsed == null) {
                        Log.w("SmsForwardWorker", "Failed to parse bKash from SMS")
                        item.put("status", "captured")
                        item.put("forward", false)
                        item.put("nextRetryAt", 0L)
                        item.put("lastEvent", "Captured (parser mismatch)")
                        updated.add(item)
                        return@forEach
                    }

                    val idempotencyKey = buildId(parsed)
                    Log.d("SmsForwardWorker", "Sending trx ${parsed.trxId}")
                    item.put("lastEvent", "Sending ${parsed.trxId}")
                    val sent = sendPayload(
                        endpoint = endpoint,
                        idempotencyKey = idempotencyKey,
                        payload = parsed,
                        rawSms = body,
                    )

                    if (sent in 200..299) {
                        Log.i("SmsForwardWorker", "Delivered ${parsed.trxId}")
                        item.put("status", "delivered")
                        item.put("nextRetryAt", 0L)
                        item.put("lastEvent", "Delivered ${parsed.trxId} (HTTP $sent)")
                        updated.add(item)
                        deliveredCount++
                        return@forEach
                    }

                    val attempts = item.optInt("attemptCount", 0) + 1
                    if (sent in 400..499 && !isRetryableHttpStatus(sent)) {
                        Log.w("SmsForwardWorker", "Non-retryable HTTP $sent, dead-lettering")
                        item.put("attemptCount", attempts)
                        item.put("status", "failed")
                        item.put("lastEvent", "Failed ${parsed.trxId} (HTTP $sent)")
                        updated.add(item)
                    } else if (attempts >= maxAttempts) {
                        Log.w("SmsForwardWorker", "Max attempts reached, dead-lettering")
                        item.put("attemptCount", attempts)
                        item.put("status", "failed")
                        item.put(
                            "lastEvent",
                            if (sent == 0)
                                "Failed ${parsed.trxId} after $attempts attempts"
                            else
                                "Failed ${parsed.trxId} (HTTP $sent)",
                        )
                        updated.add(item)
                    } else {
                        val retryAt = now + computeBackoffMs(attempts)
                        Log.d("SmsForwardWorker", "Scheduled retry $attempts/$maxAttempts")
                        item.put("attemptCount", attempts)
                        item.put("status", "retry_scheduled")
                        item.put("nextRetryAt", retryAt)
                        item.put(
                            "lastEvent",
                            if (sent == 0)
                                "Retry ${parsed.trxId} ($attempts/$maxAttempts)"
                            else
                                "Retry ${parsed.trxId} (HTTP $sent)",
                        )
                        updated.add(item)
                        shouldRetryWorker = true
                    }
                    processedCount++
                } catch (e: Exception) {
                    Log.e("SmsForwardWorker", "Error processing item: ${e.message}", e)
                    // Mark bad item as dead_letter to prevent infinite loop
                    try {
                        item.put("status", "dead_letter")
                        item.put("lastError", "Processing error: ${e.message}")
                    } catch (_: Exception) {}
                    updated.add(item)
                }
            }

            runCatching { SmsQueueStore.writeQueue(applicationContext, updated) }
                .onFailure { e -> Log.e("SmsForwardWorker", "Failed to write queue: ${e.message}", e) }

            if (shouldRetryWorker) {
                Log.d("SmsForwardWorker", "Scheduling immediate retry")
                runCatching { NativeWorkScheduler.triggerImmediate(applicationContext) }
                    .onFailure { e -> Log.e("SmsForwardWorker", "Failed to trigger: ${e.message}", e) }
            }

            Log.i("SmsForwardWorker", "Finished: processed=$processedCount, delivered=$deliveredCount")
            Result.success()
        } catch (e: Exception) {
            Log.e("SmsForwardWorker", "Unhandled error in doWork: ${e.message}", e)
            Result.retry()
        }
    }

    private fun ruleMatches(raw: String, sender: String, body: String): Boolean {
        val json = runCatching { org.json.JSONArray(raw) }.getOrElse { org.json.JSONArray() }
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

    private fun readMaxAttempts(prefs: android.content.SharedPreferences?): Int? {
        if (prefs == null) {
            return null
        }
        val raw = prefs.all["flutter.max_attempts"]
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is Float -> raw.toInt()
            is String -> raw.toIntOrNull()
            else -> null
        }
    }

    private fun templateMatches(key: String, lowerBody: String): Boolean {
        return when (key.lowercase()) {
            "bkash" -> lowerBody.contains("trxid") && lowerBody.contains("balance")
            "rocket" -> lowerBody.contains("rocket") || lowerBody.contains("cash in")
            "dbbl" -> lowerBody.contains("dbbl") || lowerBody.contains("transaction")
            else -> false
        }
    }

    private fun parseBkash(body: String, fallbackSender: String): ParsedSms? {
        val patterns = listOf(
            Regex(
                pattern = """(?i)(?:You\s+have\s+received|Received)\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s+([^.]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})""",
            ),
            Regex(
                pattern = """(?i)(?:You\s+have\s+received|Received)\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})""",
            ),
            Regex(
                pattern = """(?i)Payment\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+to\s+([^.]+)\.?\s+is\s+successful\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})""",
            ),
            Regex(
                pattern = """(?i)Bill\s+successfully\s+paid\.?\s*Biller:\s*([^\n]+)\s*Amount:\s*(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s*Fee:\s*(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})""",
            ),
        )

        var match: MatchResult? = null
        var patternIndex = -1
        patterns.forEachIndexed { index, pattern ->
            if (match == null) {
                val candidate = pattern.find(body)
                if (candidate != null) {
                    match = candidate
                    patternIndex = index
                }
            }
        }

        val found = match ?: return null
        val fields = extractFields(found, patternIndex, fallbackSender)

        val amount = fields.amount ?: return null
        val sender = fields.sender
        val reference = fields.reference
        val fee = fields.fee
        val balance = fields.balance
        val trxId = fields.trxId
        val dateText = fields.dateText

        if (!isValidAmount(amount) || !isValidAmount(fee) || !isValidAmount(balance)) {
            return null
        }

        if (sender.all { it.isDigit() } && !senderPattern.matches(sender)) {
            return null
        }

        val safeReference = if (reference.isBlank() || !referencePattern.matches(reference)) {
            fields.fallbackReference
        } else {
            reference
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
            reference = safeReference,
            fee = fee,
            balance = balance,
            trxId = trxId,
            localIso = localIso,
            utcIso = utcIso,
        )
    }

    private fun extractFields(match: MatchResult, patternIndex: Int, fallbackSender: String): ParsedFields {
        if (patternIndex == 1) {
            return ParsedFields(
                amount = match.groupValues[1].toDoubleOrNull(),
                sender = normalizePhone(match.groupValues[2]),
                reference = "",
                fee = match.groupValues[3].toDoubleOrNull() ?: 0.0,
                balance = match.groupValues[4].toDoubleOrNull() ?: 0.0,
                trxId = match.groupValues[5].trim().uppercase(),
                dateText = match.groupValues[6].trim(),
                fallbackReference = "RECEIVED",
            )
        }

        if (patternIndex == 2) {
            return ParsedFields(
                amount = match.groupValues[1].toDoubleOrNull(),
                sender = normalizePhone(fallbackSender),
                reference = cleanReference(match.groupValues[2]),
                fee = 0.0,
                balance = match.groupValues[3].toDoubleOrNull() ?: 0.0,
                trxId = match.groupValues[4].trim().uppercase(),
                dateText = match.groupValues[5].trim(),
                fallbackReference = "PAYMENT",
            )
        }

        if (patternIndex == 3) {
            return ParsedFields(
                amount = match.groupValues[2].toDoubleOrNull(),
                sender = normalizePhone(fallbackSender),
                reference = cleanReference(match.groupValues[1]),
                fee = match.groupValues[3].toDoubleOrNull() ?: 0.0,
                balance = 0.0,
                trxId = match.groupValues[4].trim().uppercase(),
                dateText = match.groupValues[5].trim(),
                fallbackReference = "BILL",
            )
        }

        return ParsedFields(
            amount = match.groupValues[1].toDoubleOrNull(),
            sender = normalizePhone(match.groupValues[2]),
            reference = cleanReference(match.groupValues[3]),
            fee = match.groupValues[4].toDoubleOrNull() ?: 0.0,
            balance = match.groupValues[5].toDoubleOrNull() ?: 0.0,
            trxId = match.groupValues[6].trim().uppercase(),
            dateText = match.groupValues[7].trim(),
            fallbackReference = "RECEIVED",
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

    private data class ParsedFields(
        val amount: Double?,
        val sender: String,
        val reference: String,
        val fee: Double,
        val balance: Double,
        val trxId: String,
        val dateText: String,
        val fallbackReference: String,
    )
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
