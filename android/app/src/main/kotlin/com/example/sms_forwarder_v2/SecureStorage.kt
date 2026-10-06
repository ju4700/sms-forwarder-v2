package com.example.sms_forwarder_v2

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Keystore-backed authenticated encryption. Errors propagate; there is no plaintext fallback. */
object SecureStorage {
    private const val alias = "qabasic-payment-storage-v1"

    @Synchronized private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
        }.generateKey()
    }

    fun read(context: Context, name: String): String? {
        val stored = context.getSharedPreferences("payment_secure", Context.MODE_PRIVATE).getString(name, null) ?: return null
        return decrypt(name, Base64.decode(stored, Base64.NO_WRAP), key())
    }

    internal fun decrypt(name: String, packed: ByteArray, key: SecretKey): String {
        require(packed.size >= 28) { "Invalid encrypted storage" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, packed.copyOfRange(0, 12)))
        cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
        return String(cipher.doFinal(packed.copyOfRange(12, packed.size)), Charsets.UTF_8)
    }

    fun write(context: Context, name: String, value: String) {
        val packed = encrypt(name, value, key())
        check(context.getSharedPreferences("payment_secure", Context.MODE_PRIVATE).edit()
            .putString(name, Base64.encodeToString(packed, Base64.NO_WRAP)).commit()) { "Encrypted storage write failed" }
    }

    internal fun encrypt(name: String, value: String, key: SecretKey): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        cipher.updateAAD(name.toByteArray(Charsets.UTF_8))
        return cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
    }
}
