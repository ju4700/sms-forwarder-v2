package com.example.sms_forwarder_v2

import org.junit.Assert.*
import org.junit.Test
import javax.crypto.KeyGenerator

class SecureStorageTest {
    private fun key() = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    @Test fun authenticatedEncryptionPreservesUtf8AndRandomizesCiphertext() {
        val key = key()
        val first = SecureStorage.encrypt("receipt_queue", "Receipt ৳ 299", key)
        val second = SecureStorage.encrypt("receipt_queue", "Receipt ৳ 299", key)
        assertFalse(first.contentEquals(second))
        assertEquals("Receipt ৳ 299", SecureStorage.decrypt("receipt_queue", first, key))
    }
    @Test fun tamperedCiphertextWrongKeysAndStorageSubstitutionFailClosed() {
        val key = key()
        val encrypted = SecureStorage.encrypt("delivery_config", "secret", key)
        val tampered = encrypted.copyOf().apply { this[lastIndex] = (this[lastIndex].toInt() xor 1).toByte() }
        assertThrows(Exception::class.java) { SecureStorage.decrypt("delivery_config", tampered, key) }
        assertThrows(Exception::class.java) { SecureStorage.decrypt("delivery_config", encrypted, key()) }
        assertThrows(Exception::class.java) { SecureStorage.decrypt("receipt_queue", encrypted, key) }
    }
}
