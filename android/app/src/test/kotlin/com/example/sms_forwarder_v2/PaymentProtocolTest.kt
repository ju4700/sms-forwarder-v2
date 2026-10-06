package com.example.sms_forwarder_v2

import org.junit.Assert.*
import org.junit.Test
import java.time.Instant

class PaymentProtocolTest {
    private val now = Instant.parse("2026-10-06T06:01:00Z").toEpochMilli()
    private val sms = "You have received Tk 299.00 from 01712345678. Ref QB123. Fee Tk 0.00. Balance Tk 458.97. TrxID DCI99TCKLX at 06/10/2026 12:00"
    @Test fun parsesCreditAndUsesDhakaTimezone() {
        val receipt = PaymentProtocol.parse("bKash", sms, now, now)!!
        assertEquals(29900, receipt.amountMinor)
        assertEquals("01712345678", receipt.payer)
        assertEquals("QB123", receipt.reference)
        assertEquals(Instant.parse("2026-10-06T06:00:00Z").toEpochMilli(), receipt.paidAt)
    }
    @Test fun rejectsUntrustedSendersEvenWithPerfectReceiptText() {
        for (sender in listOf("01711111111", "bKash-fake", " bKash", "bkash-pay", "016247")) {
            assertNull(PaymentProtocol.parse(sender, sms, now, now))
        }
        assertNotNull(PaymentProtocol.parse("16247", sms, now, now))
    }
    @Test fun rejectsOutgoingPaymentsAndEmbeddedCreditText() {
        assertNull(PaymentProtocol.parse("bKash", "Payment Tk 299.00 to SHOP is successful. Balance Tk 458.97. TrxID DCI99TCKLX at 06/10/2026 12:00", now, now))
        assertNull(PaymentProtocol.parse("bKash", "Fake notification: $sms", now, now))
        assertNull(PaymentProtocol.parse("bKash", "$sms\nOTP 123456", now, now))
    }
    @Test fun rejectsInvalidDatesZeroAmountsAndStaleReceipts() {
        assertNull(PaymentProtocol.parse("bKash", sms.replace("06/10/2026", "31/02/2026"), now, now))
        assertNull(PaymentProtocol.parse("bKash", sms.replace("Tk 299.00", "Tk 0.00"), now, now))
        assertNull(PaymentProtocol.parse("bKash", sms.replace("299.00", "299.001"), now, now))
        assertNull(PaymentProtocol.parse("bKash", sms, now, now + PaymentProtocol.MAX_RECEIPT_AGE_MS + 1))
    }
    @Test fun supportsCommasAndReceiptWithoutReference() {
        assertEquals(129950, PaymentProtocol.parse("bKash", sms.replace("299.00", "1,299.50"), now, now)!!.amountMinor)
        assertEquals("", PaymentProtocol.parse("bKash", sms.replace("Ref QB123. ", ""), now, now)!!.reference)
    }
    @Test fun restrictsDeliveryEndpoints() {
        assertTrue(PaymentProtocol.validEndpoint("https://qabasic.example/api/payments/sms"))
        for (url in listOf("http://qabasic.example/api", "https://user:secret@qabasic.example/api", "https://qabasic.example/api?key=secret", "https://qabasic.example/api#test", "https://qabasic.example:8443/api")) {
            assertFalse(PaymentProtocol.validEndpoint(url))
        }
    }
    @Test fun matchesNodeHmacTestVectorAndBindsEveryField() {
        val body = "{\"schemaVersion\":\"2.0\"}".toByteArray()
        val nonce = "00000000-0000-4000-8000-000000000001"
        val signature = PaymentProtocol.signature("f".repeat(64), "/api/payments/sms", "payment-phone-1", "1791270000", nonce, body)
        assertEquals("4faa084f567210dce106ac226c686b3f6d5ac54857a1b094f90d93c908736a1d", signature)
        assertNotEquals(signature, PaymentProtocol.signature("f".repeat(64), "/api/other", "payment-phone-1", "1791270000", nonce, body))
    }
}
