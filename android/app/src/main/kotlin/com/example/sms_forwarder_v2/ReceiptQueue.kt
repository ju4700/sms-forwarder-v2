package com.example.sms_forwarder_v2

import org.json.JSONArray
import org.json.JSONObject

/** Storage-independent queue implementation, shared by the Android store and regression tests. */
class ReceiptQueue(private val readPayload: () -> String?, private val writePayload: (String) -> Unit,
    private val now: () -> Long = { System.currentTimeMillis() }) {
    @Synchronized fun read(): MutableList<JSONObject> {
        val array = JSONArray(readPayload() ?: "[]")
        val queue = MutableList(array.length()) { array.getJSONObject(it) }
        val retained = retain(queue)
        if (retained.size != queue.size) writePayload(JSONArray(retained).toString())
        return retained.toMutableList()
    }

    @Synchronized fun write(queue: List<JSONObject>) {
        writePayload(JSONArray(retain(queue)).toString())
    }

    private fun retain(queue: List<JSONObject>): List<JSONObject> {
        val completed = queue.filter { it.optString("status") in listOf("delivered", "handled_manually") }
            .filter { it.optLong("timestamp") >= now() - 7L * 24 * 60 * 60 * 1000 }.takeLast(100)
        val unresolved = queue.filter { it.optString("status") !in listOf("delivered", "handled_manually") }
        return unresolved + completed
    }

    @Synchronized fun enqueue(item: JSONObject): Boolean {
        val queue = read()
        if (queue.any { it.getString("id") == item.getString("id") }) return false
        check(queue.count { it.optString("status") !in listOf("delivered", "handled_manually") } < 1000) { "Payment queue full. Resolve deliveries and recover recent receipts." }
        queue.add(item)
        write(queue)
        return true
    }

    @Synchronized fun update(id: String, change: (JSONObject) -> Unit) {
        val queue = read()
        val item = queue.find { it.getString("id") == id } ?: return
        change(item)
        write(queue)
    }

    @Synchronized fun retry(body: String? = null, timestamp: Long? = null): Int {
        val queue = read()
        val matching = queue.filter {
            if (body == null) it.optString("status") in listOf("failed", "dead_letter")
            else it.optString("status") !in listOf("delivered", "handled_manually") && it.optString("body") == body && it.optLong("timestamp") == timestamp
        }
        matching.forEach {
            it.put("status", "pending"); it.put("attemptCount", 0); it.put("nextRetryAt", 0L); it.put("lastEvent", "Manual retry requested")
        }
        write(queue)
        return matching.size
    }

    @Synchronized fun markHandled(id: String) {
        update(id) {
            require(it.optString("status") in listOf("failed", "dead_letter")) { "Only failed receipts can be marked handled manually" }
            it.put("status", "handled_manually"); it.put("lastEvent", "Handled manually in the wallet/store")
        }
    }
}
