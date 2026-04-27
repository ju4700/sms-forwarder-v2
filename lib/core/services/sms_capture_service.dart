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

  Future<List<Map<String, dynamic>>> fetchQueueSnapshot() async {
    final List<dynamic> rows =
        await _channel.invokeMethod<List<dynamic>>('getQueueSnapshot') ?? <dynamic>[];

    return rows.whereType<Map<dynamic, dynamic>>().map((Map<dynamic, dynamic> row) {
      return row.map((dynamic key, dynamic value) {
        return MapEntry(key.toString(), value);
      });
    }).toList(growable: false);
  }

  Future<void> retryDeadLetters() async {
    await _channel.invokeMethod<int>('retryDeadLetters');
  }

  Future<void> triggerNativeSync() async {
    await _channel.invokeMethod<bool>('triggerNativeSync');
  }
}
