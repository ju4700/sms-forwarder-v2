package com.example.sms_forwarder_v2

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object SmsQueueStore {
    private const val prefsName = "sms_forwarder_native"
    private const val keyQueue = "captured_sms_queue"
    private const val maxQueueSize = 300

    fun enqueue(context: Context, sender: String, body: String, timestamp: Long, shouldForward: Boolean): Boolean {
        val queue = readQueue(context)
        if (containsMessage(queue, sender, body, timestamp)) {
            android.util.Log.i("SmsQueueStore", "Duplicate SMS ignored for sender=$sender timestamp=$timestamp")
            return false
        }

        val item = JSONObject().apply {
            put("sender", sender)
            put("body", body)
            put("timestamp", timestamp)
            put("attemptCount", 0)
            put("nextRetryAt", 0L)
            put("status", if (shouldForward) "pending" else "captured")
            put("forward", shouldForward)
            put("portalStatus", "pending")
            put("portalAttemptCount", 0)
            put("portalNextRetryAt", 0L)
            put("portalLastEvent", "")
        }
        queue.add(item)

        val trimmed = if (queue.size > maxQueueSize) {
            queue.takeLast(maxQueueSize).toMutableList()
        } else {
            queue
        }
        writeQueue(context, trimmed)
        return true
    }

    fun containsMessage(queue: List<JSONObject>, sender: String, body: String, timestamp: Long): Boolean {
        return queue.any { item ->
            item.optString("sender", "") == sender &&
                item.optString("body", "") == body &&
                item.optLong("timestamp", 0L) == timestamp
        }
    }

    fun containsMessage(context: Context, sender: String, body: String, timestamp: Long): Boolean {
        return containsMessage(readQueue(context), sender, body, timestamp)
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
                "lastEvent" to item.optString("lastEvent", ""),
                "forward" to item.optBoolean("forward", false),
                "portalStatus" to item.optString("portalStatus", "pending"),
                "portalAttemptCount" to item.optInt("portalAttemptCount", 0),
                "portalNextRetryAt" to item.optLong("portalNextRetryAt", 0L),
                "portalLastEvent" to item.optString("portalLastEvent", ""),
            )
        }
    }

    fun retryDeadLetters(context: Context): Int {
        val queue = readQueue(context)
        val now = System.currentTimeMillis()
        var retried = 0
        queue.forEach { item ->
            val status = item.optString("status", "pending")
            if (status == "dead_letter" || status == "failed") {
                item.put("status", "retry_scheduled")
                item.put("nextRetryAt", now)
                item.put("lastError", "")
                item.put("lastEvent", "Manual retry")
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
                item.put("lastEvent", "Manual retry")
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
