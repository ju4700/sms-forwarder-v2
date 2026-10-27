package com.example.sms_forwarder_v2

import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.provider.Telephony
import android.telephony.SmsManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "sms_forwarder_v2/foreground_service"
	private val smsBridgeChannelName = "sms_forwarder_v2/sms_bridge"
	private val roleRequestCode = 9341

	private var pendingSendIntent: Map<String, String>? = null
	private var smsMethodChannel: MethodChannel? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		handleSendIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		handleSendIntent(intent)
	}

	override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
		super.cleanUpFlutterEngine(flutterEngine)
		smsMethodChannel = null
	}

	private fun handleSendIntent(intent: Intent?) {
		val parsed = parseSendToIntent(intent) ?: return
		pendingSendIntent = parsed
		smsMethodChannel?.invokeMethod("onSendToIntent", parsed)
	}

	private fun parseSendToIntent(intent: Intent?): Map<String, String>? {
		if (intent == null) return null
		val action = intent.action
		if (action != Intent.ACTION_SENDTO && action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) {
			return null
		}

		var address = ""
		var body = ""

		val uri = intent.data
		if (uri != null) {
			val scheme = uri.scheme?.lowercase()
			if (scheme == "sms" || scheme == "smsto" || scheme == "mms" || scheme == "mmsto") {
				val ssp = uri.schemeSpecificPart ?: ""
				if (ssp.contains("?")) {
					val parts = ssp.split("?", limit = 2)
					address = Uri.decode(parts[0])
					val query = parts[1]
					for (param in query.split("&")) {
						val kv = param.split("=", limit = 2)
						if (kv.isNotEmpty() && kv[0].equals("body", ignoreCase = true)) {
							body = if (kv.size > 1) Uri.decode(kv[1]) else ""
						}
					}
				} else {
					address = Uri.decode(ssp)
				}
			}
		}

		if (body.isBlank()) {
			body = intent.getStringExtra("sms_body")
				?: intent.getStringExtra(Intent.EXTRA_TEXT)
				?: ""
		}

		if (address.isBlank()) {
			address = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER) ?: ""
		}

		if (address.isNotBlank() || body.isNotBlank()) {
			return mapOf("address" to address, "body" to body)
		}
		return null
	}

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

		val bridgeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, smsBridgeChannelName)
		smsMethodChannel = bridgeChannel
		bridgeChannel.setMethodCallHandler { call, result ->
				when (call.method) {
					"getInitialSendIntent" -> {
						try {
							val data = pendingSendIntent
							pendingSendIntent = null
							result.success(data)
						} catch (e: Exception) {
							result.error("INTENT_ERROR", e.message, null)
						}
					}

					"isDefaultSmsApp" -> {
						try {
							result.success(isDefaultSmsApp())
						} catch (e: Exception) {
							result.error("ROLE_STATUS_ERROR", e.message, null)
						}
					}

					"requestDefaultSmsRole" -> {
						try {
							val launched = requestDefaultSmsRole()
							result.success(launched)
						} catch (e: Exception) {
							result.error("ROLE_REQUEST_ERROR", e.message, null)
						}
					}

					"getQueueSnapshot" -> {
						try {
							result.success(SmsQueueStore.snapshot(this))
						} catch (e: Exception) {
							result.error("SNAPSHOT_ERROR", e.message, null)
						}
					}

					"retryDeadLetters" -> {
						try {
							val count = SmsQueueStore.retryDeadLetters(this)
							NativeWorkScheduler.triggerImmediate(this)
							result.success(count)
						} catch (e: Exception) {
							result.error("RETRY_ERROR", e.message, null)
						}
					}

					"retrySingle" -> {
						try {
							val sender = call.argument<String>("sender")?.trim().orEmpty()
							val body = call.argument<String>("body")?.trim().orEmpty()
							val timestamp = call.argument<Long>("timestamp") ?: 0L
							if (sender.isBlank() || body.isBlank() || timestamp <= 0L) {
								result.success(false)
								return@setMethodCallHandler
							}
							val ok = SmsQueueStore.retrySingle(this, sender, body, timestamp)
							if (ok) {
								NativeWorkScheduler.triggerImmediate(this)
							}
							result.success(ok)
						} catch (e: Exception) {
							result.error("RETRY_ONE_ERROR", e.message, null)
						}
					}

					"triggerNativeSync" -> {
						try {
							NativeWorkScheduler.triggerImmediate(this)
							result.success(true)
						} catch (e: Exception) {
							result.error("SYNC_ERROR", e.message, null)
						}
					}

					"sendSms" -> {
						try {
							val address = call.argument<String>("address")?.trim().orEmpty()
							val body = call.argument<String>("body")?.trim().orEmpty()
							if (address.isBlank() || body.isBlank()) {
								result.success(false)
								return@setMethodCallHandler
							}
							sendSms(address, body)
							result.success(true)
						} catch (e: Exception) {
							result.error("SEND_SMS_ERROR", e.message, null)
						}
					}

					"importSmsInbox" -> {
						try {
							val limit = call.argument<Int>("limit") ?: 500
							result.success(importInbox(limit))
						} catch (e: Exception) {
							result.error("IMPORT_SMS_ERROR", e.message, null)
						}
					}

					"setCaptureRules" -> {
						try {
							val json = call.argument<String>("json") ?: "[]"
							val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
							prefs.edit().putString("flutter.capture_rules_json", json).apply()
							result.success(true)
						} catch (e: Exception) {
							result.error("SET_RULES_ERROR", e.message, null)
						}
					}

					"isIgnoringBatteryOptimizations" -> {
						try {
							result.success(isIgnoringBatteryOptimizations())
						} catch (e: Exception) {
							result.error("BATTERY_STATUS_ERROR", e.message, null)
						}
					}

					"requestIgnoreBatteryOptimizations" -> {
						try {
							result.success(requestIgnoreBatteryOptimizations())
						} catch (e: Exception) {
							result.error("BATTERY_REQUEST_ERROR", e.message, null)
						}
					}

					"markThreadRead" -> {
						try {
							val address = call.argument<String>("address")?.trim().orEmpty()
							if (address.isNotBlank()) {
								val values = ContentValues().apply {
									put(Telephony.Sms.READ, 1)
									put(Telephony.Sms.SEEN, 1)
								}
								contentResolver.update(
									Telephony.Sms.CONTENT_URI,
									values,
									"${Telephony.Sms.ADDRESS} = ? AND ${Telephony.Sms.READ} = 0",
									arrayOf(address)
								)
								val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
								notificationManager?.cancel(address.hashCode().and(0x7FFFFFFF))
							}
							result.success(true)
						} catch (e: Exception) {
							result.error("MARK_READ_ERROR", e.message, null)
						}
					}

					"deleteThread" -> {
						try {
							val address = call.argument<String>("address")?.trim().orEmpty()
							if (address.isNotBlank()) {
								contentResolver.delete(
									Telephony.Sms.CONTENT_URI,
									"${Telephony.Sms.ADDRESS} = ?",
									arrayOf(address)
								)
							}
							result.success(true)
						} catch (e: Exception) {
							result.error("DELETE_THREAD_ERROR", e.message, null)
						}
					}

					"enqueueTestSms" -> {
						try {
							val sender = call.argument<String>("sender")?.trim().orEmpty().ifEmpty { "bKash" }
							val body = call.argument<String>("body")?.trim().orEmpty()
							val timestamp = System.currentTimeMillis()
							if (body.isBlank()) {
								result.success(false)
								return@setMethodCallHandler
							}
							val enqueued = SmsQueueStore.enqueue(this, sender, body, timestamp, true)
							if (enqueued) {
								NativeWorkScheduler.triggerImmediate(this)
							}
							result.success(enqueued)
						} catch (e: Exception) {
							result.error("TEST_ENQUEUE_ERROR", e.message, null)
						}
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun sendSms(address: String, body: String) {
		val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			applicationContext.getSystemService(SmsManager::class.java)
		} else {
			SmsManager.getDefault()
		}
		val parts = manager.divideMessage(body)
		if (parts.size > 1) {
			manager.sendMultipartTextMessage(address, null, parts, null, null)
		} else {
			manager.sendTextMessage(address, null, body, null, null)
		}
		saveSentSmsToSystem(address, body)
	}

	private fun saveSentSmsToSystem(address: String, body: String) {
		try {
			val values = ContentValues().apply {
				put(Telephony.Sms.ADDRESS, address)
				put(Telephony.Sms.BODY, body)
				put(Telephony.Sms.DATE, System.currentTimeMillis())
				put(Telephony.Sms.READ, 1)
				put(Telephony.Sms.SEEN, 1)
				put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
			}
			contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
		} catch (e: Exception) {
			Log.e("MainActivity", "Failed to save sent SMS to system: ${e.message}")
		}
	}

	private fun importInbox(limit: Int): List<Map<String, Any>> {
		val result = mutableListOf<Map<String, Any>>()
		val uri = Telephony.Sms.CONTENT_URI
		val projection = arrayOf(
			Telephony.Sms.ADDRESS,
			Telephony.Sms.BODY,
			Telephony.Sms.DATE,
			Telephony.Sms.TYPE,
		)
		val sort = "${Telephony.Sms.DATE} DESC"
		val cursor = contentResolver.query(uri, projection, null, null, sort) ?: return result
		cursor.use {
			var count = 0
			val idxAddress = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
			val idxBody = cursor.getColumnIndex(Telephony.Sms.BODY)
			val idxDate = cursor.getColumnIndex(Telephony.Sms.DATE)
			val idxType = cursor.getColumnIndex(Telephony.Sms.TYPE)

			while (cursor.moveToNext() && count < limit) {
				val address = if (idxAddress >= 0) cursor.getString(idxAddress) else ""
				val body = if (idxBody >= 0) cursor.getString(idxBody) else ""
				val date = if (idxDate >= 0) cursor.getLong(idxDate) else 0L
				val type = if (idxType >= 0) cursor.getInt(idxType) else Telephony.Sms.MESSAGE_TYPE_INBOX
				val incoming = type == Telephony.Sms.MESSAGE_TYPE_INBOX

				result.add(
					mapOf(
						"address" to (address ?: ""),
						"body" to (body ?: ""),
						"timestamp" to date,
						"isIncoming" to incoming,
					),
				)
				count += 1
			}
		}
		return result
	}

	private fun startMonitorService() {
		val intent = Intent(this, SmsMonitorService::class.java)
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			startForegroundService(intent)
		} else {
			startService(intent)
		}
	}

	private fun isDefaultSmsApp(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
			roleManager.isRoleHeld(RoleManager.ROLE_SMS)
		} else {
			val defaultSms = Telephony.Sms.getDefaultSmsPackage(this)
			defaultSms == packageName
		}
	}

	private fun requestDefaultSmsRole(): Boolean {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val roleManager = getSystemService(Context.ROLE_SERVICE) as RoleManager
			val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
			startActivityForResult(intent, roleRequestCode)
			return true
		}

		val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
		intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
		startActivity(intent)
		return true
	}

	private fun isIgnoringBatteryOptimizations(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
			manager.isIgnoringBatteryOptimizations(packageName)
		} else {
			true
		}
	}

	private fun requestIgnoreBatteryOptimizations(): Boolean {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			return true
		}
		if (isIgnoringBatteryOptimizations()) {
			return true
		}
		val intent = Intent(
			Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
			Uri.parse("package:$packageName"),
		)
		startActivity(intent)
		return true
	}
}