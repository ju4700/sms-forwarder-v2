package com.example.sms_forwarder_v2

import android.content.Context
import org.json.JSONObject

data class PaymentConfig(val endpoint: String, val deviceId: String, val secret: String, val receivingAccount: String) {
    companion object {
        @Synchronized fun read(context: Context): PaymentConfig? {
            val json = SecureStorage.read(context, "delivery_config")?.let { JSONObject(it) } ?: return null
            return PaymentConfig(json.getString("endpoint"), json.getString("deviceId"), json.getString("secret"), json.getString("receivingAccount"))
        }

        @Synchronized fun save(context: Context, endpoint: String, deviceId: String, secret: String, account: String) {
            require(PaymentProtocol.validEndpoint(endpoint)) { "Use an HTTPS endpoint without credentials, query or fragment" }
            require(Regex("^[A-Za-z0-9_-]{1,64}$").matches(deviceId)) { "Device ID must contain 1–64 letters, digits, underscores or hyphens" }
            val previous = read(context)
            val nextSecret = secret.ifBlank { previous?.secret.orEmpty() }
            require(Regex("^[a-fA-F0-9]{64}$").matches(nextSecret)) { "Enter a 64-character hexadecimal device secret" }
            val receiver = PaymentProtocol.normalizePhone(account) ?: error("Enter the receiving wallet's 11-digit number")
            // Receipts remain bound to the wallet/device configured when captured.
            if (previous != null && (previous.receivingAccount != receiver || previous.deviceId != deviceId)) {
                require(SmsQueueStore.readQueue(context).none { it.optString("status") !in listOf("delivered", "handled_manually") }) {
                    "Resolve queued receipts before changing the device or receiving wallet"
                }
            }
            SecureStorage.write(context, "delivery_config", JSONObject().apply {
                put("endpoint", endpoint); put("deviceId", deviceId); put("secret", nextSecret); put("receivingAccount", receiver)
            }.toString())
        }
    }
}
