package com.example.sms_forwarder_v2

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object SmsQueueStore {
    private const val prefsName = "sms_forwarder_native"
    private const val keyQueue = "captured_sms_queue"
    private const val maxQueueSize = 300

    fun enqueue(context: Context, sender: String, body: String, timestamp: Long, shouldForward: Boolean) {
        val queue = readQueue(context)
        val item = JSONObject().apply {
            put("sender", sender)
            put("body", body)
            put("timestamp", timestamp)
            put("attemptCount", 0)
            put("nextRetryAt", 0L)
            put("status", if (shouldForward) "pending" else "captured")
            put("forward", shouldForward)
        }
        queue.add(item)

        val trimmed = if (queue.size > maxQueueSize) {
            queue.takeLast(maxQueueSize).toMutableList()
        } else {
            queue
        }
        writeQueue(context, trimmed)
    }

    fun readQueue(context: Context): MutableList<JSONObject> {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        val raw = prefs.getString(keyQueue, "[]") ?: "[]"
        val json = runCatching { JSONArray(raw) }.getOrElse { JSONArray() }
        val out = mutableListOf<JSONObject>()
        for (i in 0 until json.length()) {
            val item = json.optJSONObject(i) ?: continue
            out.add(item)
        }
        return out
    }

    fun writeQueue(context: Context, items: List<JSONObject>) {
        val trimmed = if (items.size > maxQueueSize) {
            items.takeLast(maxQueueSize)
        } else {
            items
        }

        val json = JSONArray()
        trimmed.forEach { json.put(it) }
        try {
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            prefs.edit().putString(keyQueue, json.toString()).apply()
        } catch (e: Exception) {
            android.util.Log.e("SmsQueueStore", "Failed to write queue", e)
        }
    }

    fun snapshot(context: Context): List<Map<String, Any>> {
        val queue = readQueue(context)
        return queue.map { item ->
            mapOf(
                "sender" to item.optString("sender", ""),
                "body" to item.optString("body", ""),
                "timestamp" to item.optLong("timestamp", System.currentTimeMillis()),
                "status" to item.optString("status", "pending"),
                "attemptCount" to item.optInt("attemptCount", 0),
                "nextRetryAt" to item.optLong("nextRetryAt", 0L),
                "lastError" to item.optString("lastError", ""),
                "forward" to item.optBoolean("forward", false),
            )
        }
    }

    fun retryDeadLetters(context: Context): Int {
        val queue = readQueue(context)
        val now = System.currentTimeMillis()
        var retried = 0
        queue.forEach { item ->
            if (item.optString("status", "pending") == "dead_letter") {
                item.put("status", "retry_scheduled")
                item.put("nextRetryAt", now)
                item.put("lastError", "")
                item.put("forward", true)
                retried += 1
            }
        }
        writeQueue(context, queue)
        return retried
    }

    fun retrySingle(context: Context, sender: String, body: String, timestamp: Long): Boolean {
        val queue = readQueue(context)
        val now = System.currentTimeMillis()
        var updated = false
        queue.forEach { item ->
            if (updated) {
                return@forEach
            }
            val itemSender = item.optString("sender", "")
            val itemBody = item.optString("body", "")
            val itemTimestamp = item.optLong("timestamp", 0L)
            if (itemSender == sender && itemBody == body && itemTimestamp == timestamp) {
                item.put("status", "retry_scheduled")
                item.put("nextRetryAt", now)
                item.put("lastError", "")
                item.put("forward", true)
                updated = true
            }
        }

        if (updated) {
            writeQueue(context, queue)
        }
        return updated
    }

}
