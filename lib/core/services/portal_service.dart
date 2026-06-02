import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'portal_config.dart';

class PortalPairingResult {
  PortalPairingResult({
    required this.deviceId,
    required this.deviceSecret,
    required this.pin,
  });

  final String deviceId;
  final String deviceSecret;
  final String pin;
}

class PortalMessage {
  PortalMessage({
    required this.address,
    required this.body,
    required this.timestamp,
    required this.direction,
  });

  final String address;
  final String body;
  final int timestamp;
  final String direction;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'address': address,
      'body': body,
      'timestamp': timestamp,
      'direction': direction,
    };
  }
}

class PortalService {
  PortalService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const int _bulkChunkSize = 100;

  Uri _resolve(String path) {
    final String base = PortalConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Future<PortalPairingResult> claimPairing(
    String pairingId, {
    String? deviceId,
    String? deviceSecret,
  }) async {
    final Uri url = _resolve('/api/pairing/claim');
    final Map<String, dynamic> payload = <String, dynamic>{
      'pairingId': pairingId,
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      payload['deviceId'] = deviceId;
    }
    if (deviceSecret != null && deviceSecret.isNotEmpty) {
      payload['deviceSecret'] = deviceSecret;
    }
    final http.Response response = await _client.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Pairing failed (${response.statusCode})');
    }

    final Map<String, dynamic> responsePayload =
        jsonDecode(response.body) as Map<String, dynamic>;
    return PortalPairingResult(
      deviceId: responsePayload['deviceId']?.toString() ?? '',
      deviceSecret: responsePayload['deviceSecret']?.toString() ?? '',
      pin: responsePayload['pin']?.toString() ?? '',
    );
  }

  Future<void> uploadMessagesBulk({
    required String deviceId,
    required String deviceSecret,
    required List<PortalMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return;
    }

    final Uri url = _resolve('/api/messages/bulk');
    for (int start = 0; start < messages.length; start += _bulkChunkSize) {
      final int end = (start + _bulkChunkSize < messages.length)
          ? start + _bulkChunkSize
          : messages.length;
      final List<PortalMessage> chunk = messages.sublist(start, end);

      late final http.Response response;
      try {
        response = await _client
            .post(
              url,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'x-device-id': deviceId,
                'x-device-secret': deviceSecret,
              },
              body: jsonEncode(<String, dynamic>{
                'messages': chunk
                    .map((PortalMessage message) => message.toJson())
                    .toList(),
              }),
            )
            .timeout(_requestTimeout);
      } on TimeoutException {
        throw Exception(
          'Portal request timed out while uploading messages. Check internet and retry.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Bulk upload failed (${response.statusCode})');
      }
    }
  }
}
