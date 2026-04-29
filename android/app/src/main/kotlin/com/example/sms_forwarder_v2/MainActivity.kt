package com.example.sms_forwarder_v2

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "sms_forwarder_v2/foreground_service"
	private val smsBridgeChannelName = "sms_forwarder_v2/sms_bridge"
	private val roleRequestCode = 9341

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
		manager.sendTextMessage(address, null, body, null, null)
	}

	private fun importInbox(limit: Int): List<Map<String, Any>> {
		val result = mutableListOf<Map<String, Any>>()
		val uri = Telephony.Sms.Inbox.CONTENT_URI
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
}
