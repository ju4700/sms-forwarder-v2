package com.example.sms_forwarder_v2

import java.math.BigDecimal
import java.net.URI
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/** Deliberately supports receiving-wallet bKash credit receipts only. */
object PaymentProtocol {
    const val MAX_SMS_BYTES = 4096
    const val MAX_RECEIPT_AGE_MS = 48L * 60 * 60 * 1000
    private val phone = Regex("^01[3-9]\\d{8}$")
    private val money = "([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\\.([0-9]{1,2}))?"
    private val receipt = Regex(
        "^(?:You\\s+have\\s+received|Received)\\s+(?:Tk|BDT|৳)\\s*${money}\\s+from\\s+([+0-9]+)\\.?\\s*" +
            "(?:(?:Ref|Reference)\\s+([A-Z0-9 _./-]{1,64}?)\\.?\\s*)?" +
            "Fee\\s+(?:Tk|BDT|৳)\\s*${money}\\.?\\s*Balance\\s+(?:Tk|BDT|৳)\\s*${money}\\.?\\s*" +
            "(?:TrxID|Transaction\\s*ID)\\s+([A-Z0-9]{8,12})\\s+at\\s+(\\d{1,2}/\\d{1,2}/\\d{4}\\s+\\d{1,2}:\\d{2})\\.?$",
        RegexOption.IGNORE_CASE,
    )

    data class Receipt(val payer: String, val amountMinor: Int, val transactionId: String, val reference: String, val paidAt: Long)

    fun trustedSender(sender: String): Boolean = sender.equals("bKash", ignoreCase = true) || sender == "16247"

    fun normalizePhone(raw: String): String? {
        val local = raw.trim().removePrefix("+").let { if (it.startsWith("880")) "0${it.substring(3)}" else it }
        return local.takeIf { phone.matches(it) }
    }

    fun parse(sender: String, body: String, receivedAt: Long, now: Long = System.currentTimeMillis()): Receipt? {
        if (!trustedSender(sender) || body.toByteArray(Charsets.UTF_8).size > MAX_SMS_BYTES) return null
        if (receivedAt <= 0 || receivedAt > now + 300_000 || receivedAt < now - MAX_RECEIPT_AGE_MS) return null
        val m = receipt.matchEntire(body.trim()) ?: return null
        val amount = minorUnits(m.groupValues[1], m.groupValues[2]) ?: return null
        if (amount <= 0 || amount > 100_000_000) return null
        if (minorUnits(m.groupValues[5], m.groupValues[6]) == null || minorUnits(m.groupValues[7], m.groupValues[8]) == null) return null
        val payer = normalizePhone(m.groupValues[3]) ?: return null
        val trxId = m.groupValues[9].uppercase(Locale.US)
        if (!trxId.any { it.isDigit() } || !trxId.any { it in 'A'..'Z' }) return null
        val paidAt = runCatching {
            SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("Asia/Dhaka")
                isLenient = false
            }.parse(m.groupValues[10])?.time
        }.getOrNull() ?: return null
        // Use the SMS reception time; retries must not reinterpret an old receipt as new.
        if (paidAt > receivedAt + 300_000 || paidAt < receivedAt - MAX_RECEIPT_AGE_MS) return null
        return Receipt(payer, amount, trxId, m.groupValues[4].trim().removeSuffix("."), paidAt)
    }

    private fun minorUnits(whole: String, decimal: String): Int? = runCatching {
        BigDecimal(whole.replace(",", "") + "." + decimal.ifEmpty { "0" }).movePointRight(2).intValueExact()
    }.getOrNull()

    fun validEndpoint(value: String): Boolean = runCatching {
        val uri = URI(value)
        uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.rawUserInfo == null && uri.rawQuery == null &&
            uri.rawFragment == null && !uri.rawPath.isNullOrBlank() && (uri.port == -1 || uri.port == 443)
    }.getOrDefault(false)

    fun sha256(value: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(value).joinToString("") { "%02x".format(it) }

    fun signature(secret: String, path: String, deviceId: String, timestamp: String, nonce: String, body: ByteArray): String {
        val canonical = "v1\nPOST\n$path\n$deviceId\n$timestamp\n$nonce\n${sha256(body)}"
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(canonical.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }
}
