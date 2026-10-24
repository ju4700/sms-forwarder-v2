package com.example.sms_forwarder_v2

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.min

class SmsForwardWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {

    companion object {
        private val workLock = Any()
    }

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
            val apiSecret = prefs?.getString("flutter.api_secret", "")?.trim().orEmpty()
            val maxAttempts = readMaxAttempts(prefs) ?: 12
            val rulesJson = prefs?.getString("flutter.capture_rules_json", "[]") ?: "[]"

            if (endpoint.isBlank()) {
                Log.w("SmsForwardWorker", "No delivery endpoint configured, skipping delivery")
                return Result.success()
            }

            val now = System.currentTimeMillis()
            var processedCount = 0
            var deliveredCount = 0

            queue.forEach { item ->
                val sender = item.optString("sender", "")
                val rawBody = item.optString("body", "")
                val timestamp = item.optLong("timestamp", 0L)
                val attempts = item.optInt("attemptCount", 0)

                try {
                    val status = item.optString("status", "pending")
                    if (status == "failed" || status == "dead_letter" || status == "delivered") {
                        return@forEach
                    }

                    val shouldForward = item.optBoolean("forward", false) ||
                        ruleMatches(rulesJson, sender, rawBody)
                    if (!shouldForward) {
                        SmsQueueStore.updateItem(
                            context = applicationContext,
                            sender = sender,
                            body = rawBody,
                            timestamp = timestamp,
                            status = "captured",
                            attemptCount = attempts,
                            nextRetryAt = 0L,
                            lastEvent = "Captured (rule mismatch)",
                        )
                        return@forEach
                    }

                    val nextRetryAt = item.optLong("nextRetryAt", 0L)
                    if (nextRetryAt > now) {
                        // In backoff delay, do NOT execute now and DO NOT spin-loop
                        return@forEach
                    }

                    // Parse transaction details (multi-provider + resilient fallback)
                    val parsed = parseTransaction(rawBody, sender)
                    val idempotencyKey = buildIdempotencyKey(parsed)

                    Log.d("SmsForwardWorker", "Sending ${parsed.provider} trx=${parsed.trxId} amt=${parsed.amount}")
                    SmsQueueStore.updateItem(
                        context = applicationContext,
                        sender = sender,
                        body = rawBody,
                        timestamp = timestamp,
                        status = "sending",
                        attemptCount = attempts,
                        nextRetryAt = nextRetryAt,
                        lastEvent = "Sending ${parsed.trxId}",
                    )

                    val sent = sendPayload(
                        endpoint = endpoint,
                        apiSecret = apiSecret,
                        idempotencyKey = idempotencyKey,
                        payload = parsed,
                    )

                    if (sent in 200..299) {
                        Log.i("SmsForwardWorker", "Delivered ${parsed.trxId} (HTTP $sent)")
                        SmsQueueStore.updateItem(
                            context = applicationContext,
                            sender = sender,
                            body = rawBody,
                            timestamp = timestamp,
                            status = "delivered",
                            attemptCount = attempts,
                            nextRetryAt = 0L,
                            lastEvent = "Delivered ${parsed.trxId} (HTTP $sent)",
                        )
                        deliveredCount++
                        return@forEach
                    }

                    val newAttempts = attempts + 1

                    if (sent in 400..499 && !isRetryableHttpStatus(sent)) {
                        Log.w("SmsForwardWorker", "Non-retryable HTTP $sent, dead-lettering")
                        SmsQueueStore.updateItem(
                            context = applicationContext,
                            sender = sender,
                            body = rawBody,
                            timestamp = timestamp,
                            status = "failed",
                            attemptCount = newAttempts,
                            nextRetryAt = 0L,
                            lastEvent = "Failed ${parsed.trxId} (HTTP $sent)",
                            lastError = "Non-retryable HTTP $sent",
                        )
                    } else if (newAttempts >= maxAttempts) {
                        Log.w("SmsForwardWorker", "Max attempts reached, dead-lettering")
                        SmsQueueStore.updateItem(
                            context = applicationContext,
                            sender = sender,
                            body = rawBody,
                            timestamp = timestamp,
                            status = "failed",
                            attemptCount = newAttempts,
                            nextRetryAt = 0L,
                            lastEvent = "Failed ${parsed.trxId} after $newAttempts attempts (HTTP $sent)",
                            lastError = "Max attempts reached (HTTP $sent)",
                        )
                    } else {
                        val retryAt = now + computeBackoffMs(newAttempts)
                        Log.d("SmsForwardWorker", "Scheduled retry $newAttempts/$maxAttempts at +${(retryAt - now)/1000}s")
                        SmsQueueStore.updateItem(
                            context = applicationContext,
                            sender = sender,
                            body = rawBody,
                            timestamp = timestamp,
                            status = "retry_scheduled",
                            attemptCount = newAttempts,
                            nextRetryAt = retryAt,
                            lastEvent = "Retry ${parsed.trxId} ($newAttempts/$maxAttempts) [HTTP $sent]",
                            lastError = "HTTP $sent",
                        )
                    }
                    processedCount++
                } catch (e: Exception) {
                    Log.e("SmsForwardWorker", "Error processing item: ${e.message}", e)
                    SmsQueueStore.updateItem(
                        context = applicationContext,
                        sender = sender,
                        body = rawBody,
                        timestamp = timestamp,
                        status = "failed",
                        attemptCount = attempts,
                        nextRetryAt = 0L,
                        lastEvent = "Processing error",
                        lastError = e.message.orEmpty(),
                    )
                }
            }

            Log.i("SmsForwardWorker", "Finished: processed=$processedCount, delivered=$deliveredCount")
            Result.success()
        } catch (e: Exception) {
            Log.e("SmsForwardWorker", "Unhandled error in doWork: ${e.message}", e)
            Result.retry()
        }
    }

    private fun sendPayload(
        endpoint: String,
        apiSecret: String,
        idempotencyKey: String,
        payload: ParsedResult,
    ): Int {
        val jsonBody = JSONObject().apply {
            put("schemaVersion", "2.0")
            put("idempotencyKey", idempotencyKey)
            put("provider", payload.provider)
            put("direction", payload.direction)
            put("number", payload.sender)
            put("amount", payload.amount)
            put("fee", payload.fee)
            put("balance", payload.balance)
            put("transactionId", payload.trxId)
            put("reference", payload.reference)
            put("datetimeLocal", payload.localIso)
            put("datetimeUtc", payload.utcIso)
            put("isParsed", payload.isParsed)
            if (payload.accountNumber.isNotBlank()) {
                put("accountNumber", payload.accountNumber)
            }
            put("metadata", JSONObject().apply {
                put("rawSms", payload.rawSms)
                put("parserVersion", "2.0.0-multi")
            })
        }

        val jsonString = jsonBody.toString()
        val url = runCatching { URL(endpoint) }.getOrNull() ?: return 0
        val connection = (url.openConnection() as? HttpURLConnection) ?: return 0

        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15000
            connection.readTimeout = 20000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("X-Idempotency-Key", idempotencyKey)

            if (apiSecret.isNotBlank()) {
                connection.setRequestProperty("Authorization", "Bearer $apiSecret")
                val signature = computeHmacSha256(jsonString, apiSecret)
                if (signature.isNotBlank()) {
                    connection.setRequestProperty("X-Signature", signature)
                }
            }

            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(jsonString)
                writer.flush()
            }

            connection.responseCode
        } catch (_: Exception) {
            0
        } finally {
            connection.disconnect()
        }
    }

    private fun computeHmacSha256(data: String, key: String): String {
        return try {
            val mac = Mac.getInstance("HmacSHA256")
            val secretKey = SecretKeySpec(key.toByteArray(Charsets.UTF_8), "HmacSHA256")
            mac.init(secretKey)
            val bytes = mac.doFinal(data.toByteArray(Charsets.UTF_8))
            bytes.joinToString("") { "%02x".format(it) }
        } catch (_: Exception) {
            ""
        }
    }

    private fun buildIdempotencyKey(parsed: ParsedResult): String {
        val seed = "${parsed.trxId}|${parsed.amount}|${parsed.sender}|${parsed.localIso}|${parsed.rawSms.hashCode()}"
        val digest = MessageDigest.getInstance("SHA-256").digest(seed.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun isRetryableHttpStatus(code: Int): Boolean {
        return code == 408 || code == 425 || code == 429 || (code in 500..599)
    }

    private fun computeBackoffMs(attempts: Int): Long {
        val cappedShift = min(attempts, 12)
        val exp = 1000L shl cappedShift
        val jitter = (Math.random() * 2000).toLong()
        return min(exp + jitter, 30L * 60L * 1000L)
    }

    private fun readMaxAttempts(prefs: SharedPreferences?): Int? {
        if (prefs == null) return null
        val raw = prefs.all["flutter.max_attempts"]
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is Float -> raw.toInt()
            is String -> raw.toIntOrNull()
            else -> null
        }
    }

    private fun ruleMatches(raw: String, sender: String, body: String): Boolean {
        val json = runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
        if (json.length() == 0) return false

        val lowerBody = body.lowercase()
        val lowerSender = sender.lowercase()

        for (i in 0 until json.length()) {
            val rule = json.optJSONObject(i) ?: continue
            if (!rule.optBoolean("enabled", true)) continue

            val filterOtp = rule.optBoolean("filterOtp", true)
            if (filterOtp && isSecurityOrOtp(lowerBody)) continue

            val filterSpam = rule.optBoolean("filterSpam", true)
            if (filterSpam && isPromotionalOrSpam(lowerBody)) continue

            val direction = rule.optString("direction", "credit")
            if (direction != "all") {
                val detectedDirection = detectDirection(lowerBody)
                if (direction == "credit" && detectedDirection == "debit") continue
                if (direction == "debit" && detectedDirection == "credit") continue
            }

            val minAmount = rule.optDouble("minAmount", 0.0)
            if (minAmount > 0.0) {
                val amount = extractAmount(body)
                if (amount != null && amount < minAmount) continue
            }

            val type = rule.optString("type", "")
            if (type == "template") {
                val key = rule.optString("templateKey", "all")
                if (templateMatches(key, lowerSender, lowerBody)) return true
                continue
            }

            if (type == "regex") {
                val senderPattern = rule.optString("senderPattern", "")
                val bodyPattern = rule.optString("bodyPattern", "")

                val senderOk = if (senderPattern.isNotBlank()) {
                    Regex(senderPattern, RegexOption.IGNORE_CASE).containsMatchIn(sender)
                } else true

                val bodyOk = if (bodyPattern.isNotBlank()) {
                    Regex(bodyPattern, RegexOption.IGNORE_CASE).containsMatchIn(body)
                } else true

                if (senderOk && bodyOk) return true
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
            "all" -> (lowerSender.contains("bkash") || lowerSender.contains("nagad") || lowerSender.contains("rocket") || lowerSender.contains("dbbl") || lowerSender.contains("bank") || lowerBody.contains("trxid") || lowerBody.contains("txnid") || lowerBody.contains("credited") || lowerBody.contains("balance"))
            "bkash" -> lowerSender.contains("bkash") || lowerSender == "16247" || (lowerBody.contains("trxid") && lowerBody.contains("balance"))
            "nagad" -> lowerSender.contains("nagad") || lowerSender == "16167" || lowerBody.contains("nagad") || lowerBody.contains("txnid")
            "rocket" -> lowerSender.contains("rocket") || lowerSender == "16216" || lowerSender.contains("dbbl") || lowerBody.contains("rocket")
            "bank" -> lowerSender.contains("bank") || lowerSender.contains("city") || lowerSender.contains("brac") || lowerSender.contains("ebl") || lowerSender.contains("dbbl") || lowerBody.contains("a/c") || lowerBody.contains("card ending")
            else -> false
        }
    }

    // ==========================================
    // Multi-Provider Parsing Engine in Kotlin
    // ==========================================

    data class ParsedResult(
        val provider: String,
        val direction: String,
        val amount: Double,
        val fee: Double,
        val balance: Double,
        val trxId: String,
        val reference: String,
        val sender: String,
        val accountNumber: String,
        val localIso: String,
        val utcIso: String,
        val rawSms: String,
        val isParsed: Boolean,
    )

    private fun parseTransaction(rawBody: String, sender: String): ParsedResult {
        val normalized = normalizeBengaliDigits(rawBody).trim()
        val now = Date()
        val defaultLocal = toLocalIso(now)
        val defaultUtc = toUtcIso(now)

        // 1. Try bKash parsing
        val bkash = tryParseBkash(normalized, sender, defaultLocal, defaultUtc)
        if (bkash != null) return bkash

        // 2. Try Nagad parsing
        val nagad = tryParseNagad(normalized, sender, defaultLocal, defaultUtc)
        if (nagad != null) return nagad

        // 3. Try Rocket parsing
        val rocket = tryParseRocket(normalized, sender, defaultLocal, defaultUtc)
        if (rocket != null) return rocket

        // 4. Try Commercial Bank parsing
        val bank = tryParseBank(normalized, sender, defaultLocal, defaultUtc)
        if (bank != null) return bank

        // 5. Resilient Generic Fallback (NEVER drops matching SMS)
        return parseGenericFallback(normalized, sender, defaultLocal, defaultUtc)
    }

    private fun tryParseBkash(body: String, sender: String, defaultLocal: String, defaultUtc: String): ParsedResult? {
        val p1 = Regex(
            """(?i)(?:You\s+have\s+received|Received)\s+(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s*([^.]+)\.?\s*Fee\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})"""
        )
        val m1 = p1.find(body)
        if (m1 != null) {
            val amt = cleanAmount(m1.groupValues[1]) ?: return null
            val dateText = m1.groupValues[7].trim()
            return ParsedResult(
                provider = "bkash",
                direction = "credit",
                amount = amt,
                sender = normalizePhone(m1.groupValues[2]),
                reference = cleanReference(m1.groupValues[3]),
                fee = cleanAmount(m1.groupValues[4]) ?: 0.0,
                balance = cleanAmount(m1.groupValues[5]) ?: 0.0,
                trxId = m1.groupValues[6].trim().uppercase(),
                accountNumber = "",
                localIso = parseDateToLocal(dateText) ?: defaultLocal,
                utcIso = parseDateToUtc(dateText) ?: defaultUtc,
                rawSms = body,
                isParsed = true,
            )
        }

        val p2 = Regex(
            """(?i)(?:You\s+have\s+received|Received)\s+(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*Fee\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})"""
        )
        val m2 = p2.find(body)
        if (m2 != null) {
            val amt = cleanAmount(m2.groupValues[1]) ?: return null
            val dateText = m2.groupValues[6].trim()
            return ParsedResult(
                provider = "bkash",
                direction = "credit",
                amount = amt,
                sender = normalizePhone(m2.groupValues[2]),
                reference = "RECEIVED",
                fee = cleanAmount(m2.groupValues[3]) ?: 0.0,
                balance = cleanAmount(m2.groupValues[4]) ?: 0.0,
                trxId = m2.groupValues[5].trim().uppercase(),
                accountNumber = "",
                localIso = parseDateToLocal(dateText) ?: defaultLocal,
                utcIso = parseDateToUtc(dateText) ?: defaultUtc,
                rawSms = body,
                isParsed = true,
            )
        }
        return null
    }

    private fun tryParseNagad(body: String, sender: String, defaultLocal: String, defaultUtc: String): ParsedResult? {
        val p = Regex(
            """(?i)(?:Cash\s+In|Received|You\s+have\s+received)\s+(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)(?:\s+successful)?\.?\s*(?:Ref:?\s*([^.]+)\.?)?\s*Fee:?\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*Balance:?\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|TxnID):?\s*([A-Z0-9]+)\s+(?:at|on)\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})"""
        )
        val m = p.find(body)
        if (m != null) {
            val amt = cleanAmount(m.groupValues[1]) ?: return null
            val dateText = m.groupValues[7].trim()
            return ParsedResult(
                provider = "nagad",
                direction = "credit",
                amount = amt,
                sender = normalizePhone(m.groupValues[2]),
                reference = cleanReference(m.groupValues[3].ifEmpty { "NAGAD" }),
                fee = cleanAmount(m.groupValues[4]) ?: 0.0,
                balance = cleanAmount(m.groupValues[5]) ?: 0.0,
                trxId = m.groupValues[6].trim().uppercase(),
                accountNumber = "",
                localIso = parseDateToLocal(dateText) ?: defaultLocal,
                utcIso = parseDateToUtc(dateText) ?: defaultUtc,
                rawSms = body,
                isParsed = true,
            )
        }
        return null
    }

    private fun tryParseRocket(body: String, sender: String, defaultLocal: String, defaultUtc: String): ParsedResult? {
        val p = Regex(
            """(?i)Cash\s+In\s+of\s+(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+-]+)\s+successful\.?\s*Fee\s*(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?),?\s*Balance\s*(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TxnId|TrxID):?\s*([A-Z0-9]+)"""
        )
        val m = p.find(body)
        if (m != null) {
            val amt = cleanAmount(m.groupValues[1]) ?: return null
            return ParsedResult(
                provider = "rocket",
                direction = "credit",
                amount = amt,
                sender = normalizePhone(m.groupValues[2]),
                reference = "CASH_IN",
                fee = cleanAmount(m.groupValues[3]) ?: 0.0,
                balance = cleanAmount(m.groupValues[4]) ?: 0.0,
                trxId = m.groupValues[5].trim().uppercase(),
                accountNumber = "",
                localIso = defaultLocal,
                utcIso = defaultUtc,
                rawSms = body,
                isParsed = true,
            )
        }
        return null
    }

    private fun tryParseBank(body: String, sender: String, defaultLocal: String, defaultUtc: String): ParsedResult? {
        val acRegex = Regex(
            """(?i)A/C\s*(?:ending\s+with\s*|\*|ending\s+)?([0-9A-Z]+)\s+(?:has\s+been|is)?\s*(credited|debited)\s*(?:by|for|with)?\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:on|at)\s*([0-9]{1,2}(?:/|-)[0-9A-Za-z]{2,3}(?:/|-)[0-9]{2,4}[^.]*?)\s*(?:by|via|Ref:?)\s*([^.]+)?\.?\s*(?:Avail(?:able)?\s*Bal(?:ance)?:?|Total\s*Bal:?)\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)"""
        )
        val acMatch = acRegex.find(body)
        if (acMatch != null) {
            val amt = cleanAmount(acMatch.groupValues[3]) ?: return null
            val action = acMatch.groupValues[2].lowercase()
            val direction = if (action == "debited") "debit" else "credit"
            return ParsedResult(
                provider = "bank",
                direction = direction,
                amount = amt,
                sender = sender.ifEmpty { "BANK" },
                reference = cleanReference(acMatch.groupValues[5].ifEmpty { "BANK_TRANSFER" }),
                accountNumber = acMatch.groupValues[1].trim(),
                fee = 0.0,
                balance = cleanAmount(acMatch.groupValues[6]) ?: 0.0,
                trxId = "BANK_${System.currentTimeMillis()}",
                localIso = defaultLocal,
                utcIso = defaultUtc,
                rawSms = body,
                isParsed = true,
            )
        }

        val cardRegex = Regex(
            """(?i)(?:Your\s+)?Card\s*(?:ending\s+with\s*|\*|ending\s+)?([0-9A-Z]+)\s+(?:was\s+used\s+for|debited\s+for)\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:at|to|for)?\s*([^.]+)?\s*(?:on|at)\s*([0-9]{1,2}(?:/|-)[0-9A-Za-z]{2,3}(?:/|-)[0-9]{2,4}[^.]*?)\.?\s*(?:Avail(?:able)?\s*Bal(?:ance)?:?|Total\s*Bal:?)\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)"""
        )
        val cardMatch = cardRegex.find(body)
        if (cardMatch != null) {
            val amt = cleanAmount(cardMatch.groupValues[2]) ?: return null
            return ParsedResult(
                provider = "bank",
                direction = "debit",
                amount = amt,
                sender = sender.ifEmpty { "BANK" },
                reference = cleanReference(cardMatch.groupValues[3].ifEmpty { "CARD_TXN" }),
                accountNumber = "CARD_${cardMatch.groupValues[1].trim()}",
                fee = 0.0,
                balance = cleanAmount(cardMatch.groupValues[5]) ?: 0.0,
                trxId = "BANK_${System.currentTimeMillis()}",
                localIso = defaultLocal,
                utcIso = defaultUtc,
                rawSms = body,
                isParsed = true,
            )
        }

        return null
    }

    private fun parseGenericFallback(body: String, sender: String, defaultLocal: String, defaultUtc: String): ParsedResult {
        val amtRegex = Regex("""(?i)(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)""")
        val trxRegex = Regex("""(?i)(?:TrxID|TxnID|Txn\s*ID|Transaction\s*ID|Ref\s*ID)[\s:]*([A-Z0-9]+)""")
        val balRegex = Regex("""(?i)(?:Bal|Balance|Avail(?:able)?\s*Bal(?:ance)?|Total\s*Bal)[\s:]*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)""")
        val feeRegex = Regex("""(?i)Fee[\s:]*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)""")

        val amtMatch = amtRegex.find(body)
        val trxMatch = trxRegex.find(body)
        val balMatch = balRegex.find(body)
        val feeMatch = feeRegex.find(body)

        val amount = cleanAmount(amtMatch?.groupValues?.getOrNull(1)) ?: 0.0
        val trxId = trxMatch?.groupValues?.getOrNull(1)?.trim()?.uppercase() ?: "GEN_${System.currentTimeMillis()}"
        val balance = cleanAmount(balMatch?.groupValues?.getOrNull(1)) ?: 0.0
        val fee = cleanAmount(feeMatch?.groupValues?.getOrNull(1)) ?: 0.0

        return ParsedResult(
            provider = "generic",
            direction = detectDirection(body.lowercase()),
            amount = amount,
            trxId = trxId,
            reference = "SMS_FORWARD",
            sender = sender.ifEmpty { "UNKNOWN" },
            fee = fee,
            balance = balance,
            accountNumber = "",
            localIso = defaultLocal,
            utcIso = defaultUtc,
            rawSms = body,
            isParsed = amtMatch != null,
        )
    }

    private fun cleanAmount(raw: String?): Double? {
        if (raw.isNullOrBlank()) return null
        return runCatching { raw.replace(",", "").trim().toDouble() }.getOrNull()
    }

    private fun cleanReference(raw: String): String {
        return raw.replace(Regex("""\s+"""), " ").trim().uppercase()
    }

    private fun normalizePhone(raw: String): String {
        val digits = raw.replace(Regex("""[^0-9]"""), "")
        return when {
            digits.startsWith("880") && digits.length >= 13 -> "0${digits.substring(3)}"
            digits.startsWith("88") && digits.length > 11 -> digits.substring(2)
            else -> digits
        }
    }

    private fun normalizeBengaliDigits(input: String): String {
        val bengali = arrayOf('০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯')
        val english = arrayOf('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
        var output = input
        for (i in 0 until 10) {
            output = output.replace(bengali[i], english[i])
        }
        return output
    }

    private fun parseDateToLocal(text: String): String? {
        val parser = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
            isLenient = false
        }
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
        }
        val parsed = runCatching { parser.parse(text) }.getOrNull() ?: return null
        return formatter.format(parsed)
    }

    private fun parseDateToUtc(text: String): String? {
        val parser = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
            isLenient = false
        }
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val parsed = runCatching { parser.parse(text) }.getOrNull() ?: return null
        return formatter.format(parsed)
    }

    private fun toLocalIso(date: Date): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Asia/Dhaka")
        }
        return formatter.format(date)
    }

    private fun toUtcIso(date: Date): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        return formatter.format(date)
    }
}
