package com.example.sms_forwarder_v2

import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ReceiptQueueTest {
    private val now = 1791266400000L
    private fun item(id: String, status: String = "pending") = JSONObject().apply {
        put("id", id); put("status", status); put("timestamp", now); put("body", id)
    }
    private fun queue(): ReceiptQueue {
        var payload: String? = null
        return ReceiptQueue({ payload }, { payload = it }, { now })
    }
    @Test fun deliveredHistoryCannotStopNewCaptures() {
        val queue = queue()
        repeat(350) { queue.enqueue(item("$it", "delivered")) }
        assertEquals(100, queue.read().size)
        assertTrue(queue.enqueue(item("new-payment")))
        assertEquals(101, queue.read().size)
    }
    @Test fun snapshotsCannotOverwriteNewlyReceivedPayments() {
        val queue = queue()
        queue.enqueue(item("a"))
        val staleWorkerSnapshot = queue.read()
        queue.enqueue(item("b"))
        queue.update(staleWorkerSnapshot.first().getString("id")) { it.put("status", "delivered") }
        assertEquals(setOf("a", "b"), queue.read().map { it.getString("id") }.toSet())
    }
    @Test fun simultaneousCapturesAreNotLost() {
        val queue = queue()
        val executor = Executors.newFixedThreadPool(4)
        repeat(80) { i -> executor.submit { queue.enqueue(item("$i")) } }
        executor.shutdown()
        assertTrue(executor.awaitTermination(15, TimeUnit.SECONDS))
        assertEquals(80, queue.read().size)
    }
    @Test fun retriesResetAttemptLimitAndNeverResendDeliveredHistory() {
        val queue = queue()
        queue.enqueue(item("failed", "failed").put("attemptCount", 12))
        queue.enqueue(item("done", "delivered"))
        assertEquals(1, queue.retry())
        assertEquals(0, queue.read().first { it.getString("id") == "failed" }.getInt("attemptCount"))
        assertEquals(0, queue.retry("done", now))
    }
    @Test fun overflowDoesNotEvictUnresolvedPayments() {
        val queue = queue()
        queue.write((0 until 1000).map { item("$it") })
        assertThrows(IllegalStateException::class.java) { queue.enqueue(item("overflow")) }
        assertEquals(1000, queue.read().size)
        assertFalse(queue.enqueue(item("0")))
    }
    @Test fun corruptStorageFailsInsteadOfResettingHistory() {
        val queue = ReceiptQueue({ "corrupted" }, { fail("Must not overwrite corrupt storage") })
        assertThrows(Exception::class.java) { queue.enqueue(item("new")) }
    }
    @Test fun readPrunesExpiredDeliveredHistoryWhileKeepingUndeliveredReceipts() {
        var clock = now
        var payload: String? = null
        val queue = ReceiptQueue({ payload }, { payload = it }, { clock })
        queue.enqueue(item("done", "delivered")); queue.enqueue(item("pending"))
        clock += 8L * 24 * 60 * 60 * 1000
        assertEquals(listOf("pending"), queue.read().map { it.getString("id") })
        assertFalse(payload!!.contains("done"))
    }
    @Test fun manualResolutionCannotDiscardPendingReceiptsOrResendHandledOnes() {
        val queue = queue()
        queue.enqueue(item("pending")); queue.enqueue(item("failed", "failed"))
        assertThrows(IllegalArgumentException::class.java) { queue.markHandled("pending") }
        queue.markHandled("failed")
        assertEquals(0, queue.retry("failed", now))
        assertEquals("pending", queue.read().first { it.getString("id") == "pending" }.getString("status"))
    }
}
