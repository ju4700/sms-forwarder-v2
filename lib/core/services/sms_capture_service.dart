import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsCaptureService {
  SmsCaptureService();

  static const MethodChannel _channel = MethodChannel('sms_forwarder_v2/sms_bridge');

  Future<bool> requestPermissions() async {
    final PermissionStatus smsStatus = await Permission.sms.request();
    return smsStatus.isGranted;
  }

  Future<void> startListening() async {}

  Future<bool> isDefaultSmsApp() async {
    try {
      return await _channel.invokeMethod<bool>('isDefaultSmsApp') ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: isDefaultSmsApp failed: $e');
      return false;
    }
  }

  Future<bool> requestDefaultSmsRole() async {
    try {
      return await _channel.invokeMethod<bool>('requestDefaultSmsRole') ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: requestDefaultSmsRole failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchQueueSnapshot() async {
    try {
      final List<dynamic> rows =
          await _channel.invokeMethod<List<dynamic>>('getQueueSnapshot') ?? <dynamic>[];

      return rows.whereType<Map<dynamic, dynamic>>().map((Map<dynamic, dynamic> row) {
        return row.map((dynamic key, dynamic value) {
          return MapEntry(key.toString(), value);
        });
      }).toList(growable: false);
    } catch (e) {
      // If platform channel fails, return empty snapshot rather than throwing
      // and log the error to console for diagnostics.
      // Caller should handle empty list gracefully.
      // ignore: avoid_print
      print('sms_capture_service: fetchQueueSnapshot failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> retryDeadLetters() async {
    try {
      await _channel.invokeMethod<int>('retryDeadLetters');
    } catch (e) {
      // ignore errors from native layer
      // ignore: avoid_print
      print('sms_capture_service: retryDeadLetters failed: $e');
    }
  }

  Future<bool> retrySingle({
    required String sender,
    required String body,
    required int timestamp,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('retrySingle', <String, dynamic>{
            'sender': sender,
            'body': body,
            'timestamp': timestamp,
          }) ??
          false;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: retrySingle failed: $e');
      return false;
    }
  }

  Future<void> triggerNativeSync() async {
    try {
      await _channel.invokeMethod<bool>('triggerNativeSync');
    } catch (e) {
      // ignore errors from native layer
      // ignore: avoid_print
      print('sms_capture_service: triggerNativeSync failed: $e');
    }
  }

  Future<bool> sendSms({
    required String address,
    required String body,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('sendSms', <String, dynamic>{
            'address': address,
            'body': body,
          }) ??
          false;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: sendSms failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> importSmsInbox({int limit = 500}) async {
    try {
      final List<dynamic> rows =
          await _channel.invokeMethod<List<dynamic>>('importSmsInbox', <String, dynamic>{
                'limit': limit,
              }) ??
              <dynamic>[];

      return rows.whereType<Map<dynamic, dynamic>>().map((Map<dynamic, dynamic> row) {
        return row.map((dynamic key, dynamic value) {
          return MapEntry(key.toString(), value);
        });
      }).toList(growable: false);
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: importSmsInbox failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> setCaptureRules(String json) async {
    try {
      await _channel.invokeMethod<bool>('setCaptureRules', <String, dynamic>{
        'json': json,
      });
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: setCaptureRules failed: $e');
    }
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: battery status failed: $e');
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: request battery ignore failed: $e');
    }
  }

  Future<bool> markThreadRead(String address) async {
    try {
      return await _channel.invokeMethod<bool>('markThreadRead', <String, dynamic>{
            'address': address,
          }) ??
          false;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: markThreadRead failed: $e');
      return false;
    }
  }

  Future<bool> deleteThread(String address) async {
    try {
      return await _channel.invokeMethod<bool>('deleteThread', <String, dynamic>{
            'address': address,
          }) ??
          false;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: deleteThread failed: $e');
      return false;
    }
  }

  Future<Map<String, String>?> getInitialSendIntent() async {
    try {
      final dynamic res = await _channel.invokeMethod<dynamic>('getInitialSendIntent');
      if (res is Map) {
        return res.map((dynamic k, dynamic v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('sms_capture_service: getInitialSendIntent failed: $e');
      return null;
    }
  }

  void registerSendIntentHandler(void Function(Map<String, String> data) handler) {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onSendToIntent') {
        if (call.arguments is Map) {
          final Map<dynamic, dynamic> args = call.arguments as Map<dynamic, dynamic>;
          final Map<String, String> map = args.map(
            (dynamic k, dynamic v) => MapEntry(k.toString(), v?.toString() ?? ''),
          );
          handler(map);
        }
      }
    });
  }
}
