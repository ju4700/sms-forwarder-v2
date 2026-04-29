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
}
