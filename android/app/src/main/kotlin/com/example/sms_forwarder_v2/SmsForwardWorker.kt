package com.example.sms_forwarder_v2

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.URL
import java.net.URI
import java.util.UUID
import javax.net.ssl.HttpsURLConnection

class SmsForwardWorker(appContext: Context, params: WorkerParameters) : Worker(appContext, params) {
    companion object { private val workLock = Any() }

    override fun doWork(): Result = synchronized(workLock) {
        try {
            val config = PaymentConfig.read(applicationContext) ?: return Result.success()
            if (!PaymentProtocol.validEndpoint(config.endpoint)) return Result.failure()
            var retry = false
            for (item in SmsQueueStore.readQueue(applicationContext)) {
                if (isStopped) return Result.retry()
                if (item.optString("status") !in listOf("pending", "retry_scheduled")) continue
                if (item.optLong("nextRetryAt") > System.currentTimeMillis()) { retry = true; continue }
                val id = item.getString("id")
                val receivedAt = item.getLong("timestamp")
                val receipt = PaymentProtocol.parse(item.getString("sender"), item.getString("body"), receivedAt, receivedAt)
                if (receipt == null || item.getString("receivingAccount") != config.receivingAccount || item.getString("deviceId") != config.deviceId) {
                    SmsQueueStore.update(applicationContext, id) { it.put("status", "dead_letter"); it.put("lastEvent", "Receipt validation failed") }
                    continue
                }
                val body = JSONObject().apply {
                    put("schemaVersion", "2.0"); put("provider", "bkash"); put("currency", "BDT")
                    put("idempotencyKey", id); put("transactionId", receipt.transactionId)
                    put("payerAccount", receipt.payer); put("amountMinor", receipt.amountMinor)
                    put("receivingAccount", config.receivingAccount); put("smsSender", item.getString("sender"))
                    put("receivedAt", receivedAt); put("paidAt", receipt.paidAt); put("reference", receipt.reference)
                    put("rawSms", item.getString("body"))
                }.toString().toByteArray(Charsets.UTF_8)
                val code = send(config, body, id)
                val attempts = item.optInt("attemptCount") + 1
                val retryable = code == 0 || code in listOf(408, 425, 429) || code in 500..599
                if (code in 200..299) {
                    SmsQueueStore.update(applicationContext, id) {
                        it.put("status", "delivered"); it.put("nextRetryAt", 0L)
                        it.put("lastEvent", "Receipt accepted by server (HTTP $code)")
                    }
                } else if (!retryable || attempts >= 12) {
                    SmsQueueStore.update(applicationContext, id) {
                        it.put("status", "failed"); it.put("attemptCount", attempts)
                        it.put("lastEvent", "Delivery requires attention (HTTP $code)")
                    }
                    PaymentAlerts.show(applicationContext, "A receipt could not be delivered. Check delivery settings and retry.")
                } else {
                    retry = true
                    val delay = (10_000L * (1L shl (attempts - 1).coerceAtMost(10))).coerceAtMost(3_600_000L)
                    SmsQueueStore.update(applicationContext, id) {
                        it.put("status", "retry_scheduled"); it.put("attemptCount", attempts)
                        it.put("nextRetryAt", System.currentTimeMillis() + delay); it.put("lastEvent", "Retry scheduled (HTTP $code)")
                    }
                }
            }
            if (retry) Result.retry() else Result.success()
        } catch (_: Exception) {
            PaymentAlerts.show(applicationContext, "Payment storage or delivery failed. Open the app to check the queue.")
            Result.retry()
        }
    }

    private fun send(config: PaymentConfig, body: ByteArray, id: String): Int {
        val timestamp = (System.currentTimeMillis() / 1000).toString()
        val nonce = UUID.randomUUID().toString()
        val signature = PaymentProtocol.signature(config.secret, URI(config.endpoint).rawPath, config.deviceId, timestamp, nonce, body)
        val connection = URL(config.endpoint).openConnection() as HttpsURLConnection
        return try {
            connection.instanceFollowRedirects = false
            connection.requestMethod = "POST"
            connection.connectTimeout = 15_000; connection.readTimeout = 20_000
            connection.doOutput = true
            connection.setFixedLengthStreamingMode(body.size)
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("X-Device-Id", config.deviceId)
            connection.setRequestProperty("X-Timestamp", timestamp)
            connection.setRequestProperty("X-Nonce", nonce)
            connection.setRequestProperty("X-Signature", "v1=$signature")
            connection.setRequestProperty("X-Idempotency-Key", id)
            connection.outputStream.use { it.write(body) }
            connection.responseCode
        } catch (_: Exception) { 0 } finally { connection.disconnect() }
    }
}
