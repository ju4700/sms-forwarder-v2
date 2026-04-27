import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bkash_parser.dart';
import 'delivery_service.dart';

class SmsCaptureService {
  SmsCaptureService({
    required this.deliveryService,
  });

  static const MethodChannel _channel = MethodChannel('sms_forwarder_v2/sms_bridge');

  final DeliveryService deliveryService;

  Future<bool> requestPermissions() async {
    final PermissionStatus smsStatus = await Permission.sms.request();
    return smsStatus.isGranted;
  }

  Future<void> startListening() async {}

  Future<int> drainCapturedFromNative() async {
    final List<dynamic> rows =
        await _channel.invokeMethod<List<dynamic>>('drainCapturedSms') ?? <dynamic>[];

    int ingested = 0;
    for (final dynamic row in rows) {
      if (row is! Map<dynamic, dynamic>) {
        continue;
      }

      final String body = (row['body'] as String?)?.trim() ?? '';
      if (body.isEmpty || !BkashParser.looksLikeBkashReceivedSms(body)) {
        continue;
      }

      final ParsedBkashTransaction? parsed = BkashParser.parse(body);
      if (parsed == null) {
        continue;
      }

      await deliveryService.enqueueFromParsed(
        sender: parsed.sender,
        messageBody: body,
        amount: parsed.amount,
        transactionId: parsed.transactionId,
        reference: parsed.reference,
        fee: parsed.fee,
        balance: parsed.balance,
        localIso: parsed.localIso,
        utcIso: parsed.utcIso,
      );
      ingested++;
    }

    if (ingested > 0) {
      await deliveryService.drainQueue();
    }

    return ingested;
  }
}
