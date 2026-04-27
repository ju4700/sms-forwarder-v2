package com.example.sms_forwarder_v2

import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "sms_forwarder_v2/foreground_service"
	private val smsBridgeChannelName = "sms_forwarder_v2/sms_bridge"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		NativeWorkScheduler.ensurePeriodic(this)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"start" -> {
						startMonitorService()
						result.success(true)
					}

					"stop" -> {
						stopService(Intent(this, SmsMonitorService::class.java))
						result.success(true)
					}

					else -> result.notImplemented()
				}
			}

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsBridgeChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"drainCapturedSms" -> {
						result.success(drainCapturedSms())
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun startMonitorService() {
		val intent = Intent(this, SmsMonitorService::class.java)
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			startForegroundService(intent)
		} else {
			startService(intent)
		}
	}

	private fun drainCapturedSms(): List<Map<String, Any>> {
		return SmsQueueStore.drainForFlutter(this)
	}
}
