package com.example.sms_forwarder_v2

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object SmsQueueStore {
    private const val prefsName = "sms_forwarder_native"
    private const val keyQueue = "captured_sms_queue"
    private const val maxQueueSize = 300

    fun enqueue(context: Context, sender: String, body: String, timestamp: Long) {
        val queue = readQueue(context)
        val item = JSONObject().apply {
            put("sender", sender)
            put("body", body)
            put("timestamp", timestamp)
            put("attemptCount", 0)
            put("nextRetryAt", 0L)
            put("status", "pending")
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
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit().putString(keyQueue, json.toString()).apply()
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
                retried += 1
            }
        }
        writeQueue(context, queue)
        return retried
    }

}
