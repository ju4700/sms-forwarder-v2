import 'package:flutter/services.dart';

class ForegroundServiceController {
  ForegroundServiceController._();

  static final ForegroundServiceController instance = ForegroundServiceController._();

  static const MethodChannel _channel = MethodChannel(
    'sms_forwarder_v2/foreground_service',
  );

  Future<void> apply(bool enabled) async {
    if (enabled) {
      await start();
      return;
    }
    await stop();
  }

  Future<void> start() async {
    try {
      await _channel.invokeMethod<bool>('start');
    } catch (e) {
      // ignore native errors
      // ignore: avoid_print
      print('foreground_service: start failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (e) {
      // ignore native errors
      // ignore: avoid_print
      print('foreground_service: stop failed: $e');
    }
  }
}
