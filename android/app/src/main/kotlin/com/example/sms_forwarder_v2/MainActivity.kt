package com.example.sms_forwarder_v2

import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.provider.Telephony
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeWorkScheduler.ensurePeriodic(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sms_forwarder_v2/foreground_service").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this, SmsMonitorService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                        result.success(true)
                    }
                    "stop" -> { stopService(Intent(this, SmsMonitorService::class.java)); result.success(true) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("SERVICE_ERROR", "Could not change foreground service", null) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sms_forwarder_v2/sms_bridge").setMethodCallHandler { call, result ->
            // Encryption, inbox access, and queue writes must not block the UI thread.
            executor.execute {
                try {
                    val value: Any? = when (call.method) {
                        "loadSettings" -> {
                            val c = PaymentConfig.read(this)
                            mapOf("apiEndpoint" to (c?.endpoint ?: ""), "deviceId" to (c?.deviceId ?: ""),
                                "receivingAccount" to (c?.receivingAccount ?: ""), "secretConfigured" to (c != null),
                                "foregroundReliabilityMode" to getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).getBoolean("flutter.foreground_mode", false))
                        }
                        "saveSettings" -> {
                            PaymentConfig.save(this, call.argument<String>("apiEndpoint").orEmpty().trim(),
                                call.argument<String>("deviceId").orEmpty().trim(), call.argument<String>("secret").orEmpty().trim(),
                                call.argument<String>("receivingAccount").orEmpty().trim())
                            NativeWorkScheduler.triggerImmediate(this)
                            true
                        }
                        "setForegroundMode" -> {
                            check(getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE).edit()
                                .putBoolean("flutter.foreground_mode", call.argument<Boolean>("enabled") == true).commit())
                            true
                        }
                        "getQueueSnapshot" -> SmsQueueStore.snapshot(this)
                        "markHandled" -> { SmsQueueStore.markHandled(this, call.argument<String>("id").orEmpty()); true }
                        "retryDeadLetters" -> SmsQueueStore.retryDeadLetters(this).also { NativeWorkScheduler.triggerImmediate(this) }
                        "retrySingle" -> SmsQueueStore.retrySingle(this, call.argument<String>("body").orEmpty(),
                            (call.argument<Number>("timestamp") ?: 0).toLong()).also { if (it) NativeWorkScheduler.triggerImmediate(this) }
                        "triggerNativeSync" -> { NativeWorkScheduler.triggerImmediate(this); true }
                        "recoverReceipts" -> recoverReceipts()
                        "isIgnoringBatteryOptimizations" -> getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(packageName)
                        "requestIgnoreBatteryOptimizations" -> {
                            runOnUiThread { startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))) }
                            true
                        }
                        else -> { runOnUiThread { result.notImplemented() }; return@execute }
                    }
                    runOnUiThread { result.success(value) }
                } catch (e: IllegalArgumentException) {
                    runOnUiThread { result.error("INVALID_SETTINGS", e.message, null) }
                } catch (e: IllegalStateException) {
                    runOnUiThread { result.error("PAYMENT_ERROR", e.message, null) }
                } catch (_: Exception) {
                    runOnUiThread { result.error("STORAGE_ERROR", "Payment storage unavailable. Check device storage and permissions.", null) }
                }
            }
        }
    }

    private fun recoverReceipts(): Int {
        if (PaymentConfig.read(this) == null) return 0
        val earliest = System.currentTimeMillis() - PaymentProtocol.MAX_RECEIPT_AGE_MS
        val projection = arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE)
        var captured = 0
        contentResolver.query(Telephony.Sms.Inbox.CONTENT_URI, projection, "${Telephony.Sms.DATE} >= ?",
            arrayOf(earliest.toString()), "${Telephony.Sms.DATE} ASC")?.use { cursor ->
            while (cursor.moveToNext()) {
                val sender = cursor.getString(0).orEmpty()
                if (!PaymentProtocol.trustedSender(sender)) continue
                val body = cursor.getString(1).orEmpty()
                val timestamp = cursor.getLong(2)
                if (SmsQueueStore.enqueue(this, sender, body, timestamp)) captured++
            }
        }
        NativeWorkScheduler.triggerImmediate(this)
        return captured
    }
}
