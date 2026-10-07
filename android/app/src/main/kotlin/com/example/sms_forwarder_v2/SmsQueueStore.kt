package com.example.sms_forwarder_v2

import android.content.Context
import org.json.JSONObject

object SmsQueueStore {
    private var repository: ReceiptQueue? = null
    @Synchronized private fun store(context: Context): ReceiptQueue {
        repository?.let { return it }
        val app = context.applicationContext
        return ReceiptQueue({ SecureStorage.read(app, "receipt_queue") },
            { SecureStorage.write(app, "receipt_queue", it) }).also { repository = it }
    }
    fun readQueue(context: Context) = store(context).read()
    fun update(context: Context, id: String, change: (JSONObject) -> Unit) = store(context).update(id, change)
    fun enqueue(context: Context, sender: String, body: String, timestamp: Long): Boolean = synchronized(PaymentConfig) {
        val receipt = PaymentProtocol.parse(sender, body, timestamp) ?: return false
        val config = PaymentConfig.read(context) ?: return false
        val id = PaymentProtocol.sha256("bkash|${config.receivingAccount}|${receipt.transactionId}".toByteArray(Charsets.UTF_8))
        store(context).enqueue(JSONObject().apply {
            put("id", id); put("sender", sender); put("body", body); put("timestamp", timestamp)
            put("receivingAccount", config.receivingAccount); put("deviceId", config.deviceId)
            put("amountMinor", receipt.amountMinor); put("payerAccount", receipt.payer)
            put("transactionId", receipt.transactionId); put("reference", receipt.reference); put("paidAt", receipt.paidAt)
            put("attemptCount", 0); put("nextRetryAt", 0L); put("status", "pending"); put("forward", true)
        })
    }
    fun snapshot(context: Context): List<Map<String, Any>> = readQueue(context).map { item ->
        item.keys().asSequence().associateWith { key -> item.get(key) }
    }
    fun retryDeadLetters(context: Context): Int = store(context).retry()
    fun markHandled(context: Context, id: String) = store(context).markHandled(id)
    fun retrySingle(context: Context, body: String, timestamp: Long): Boolean = store(context).retry(body, timestamp) > 0
}
