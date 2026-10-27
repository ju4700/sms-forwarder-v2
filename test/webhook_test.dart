import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sms_forwarder_v2/core/services/transaction_parser.dart';

void main() {
  const String webhookUrl = 'https://apireceiver.vercel.app/api/hook/sms';

  group('Webhook Payload Contract Tests', () {
    test('transaction parser produces compliant schema 2.0 payload', () {
      const String sms =
          'You have received Tk 1,500.00 from 01711223344. Ref STORE. Fee Tk 0.00. Balance Tk 25,450.50. TrxID 9K20ABC123 at 24/10/2026 22:00';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'bKash');

      final Map<String, dynamic> json = parsed.toJson(idempotencyKey: 'test-key-123');

      expect(json['schemaVersion'], '2.0');
      expect(json['idempotencyKey'], 'test-key-123');
      expect(json['provider'], 'bkash');
      expect(json['direction'], 'credit');
      expect(json['amount'], 1500.0);
      expect(json['fee'], 0.0);
      expect(json['balance'], 25450.5);
      expect(json['transactionId'], '9K20ABC123');
      expect(json['sender'], '01711223344');
      expect(json['reference'], 'STORE');
      expect(json['rawSms'], sms);
      expect(json['isParsed'], true);
    });
  });

  group('Live Webhook Endpoint Tests', () {
    test('GET request to endpoint returns 200 with received=True', () async {
      final http.Response response = await http.get(Uri.parse(webhookUrl));
      expect(response.statusCode, 200);

      final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['received'], true);
      expect(body['method'], 'GET');
    });

    test('POST transaction payload to endpoint returns 200 with received=True', () async {
      final Map<String, dynamic> payload = <String, dynamic>{
        'schemaVersion': '2.0',
        'idempotencyKey': 'test-live-${DateTime.now().millisecondsSinceEpoch}',
        'provider': 'bkash',
        'direction': 'credit',
        'number': '01711223344',
        'sender': '01711223344',
        'amount': 750.0,
        'fee': 0.0,
        'balance': 5250.0,
        'transactionId': 'LIVE_TEST_${DateTime.now().millisecondsSinceEpoch % 100000}',
        'reference': 'ANTIGRAVITY_TEST',
        'datetimeLocal': DateTime.now().toIso8601String(),
        'datetimeUtc': DateTime.now().toUtc().toIso8601String(),
        'isParsed': true,
        'rawSms': 'You have received Tk 750.00 from 01711223344. Ref ANTIGRAVITY_TEST. Fee Tk 0.00. Balance Tk 5,250.00. TrxID TEST999 at 24/10/2026 22:30',
        'metadata': <String, dynamic>{
          'rawSms': 'You have received Tk 750.00 from 01711223344. Ref ANTIGRAVITY_TEST. Fee Tk 0.00. Balance Tk 5,250.00. TrxID TEST999 at 24/10/2026 22:30',
          'parserVersion': '2.0.0-multi',
        },
      };

      final http.Response response = await http.post(
        Uri.parse(webhookUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          'X-Idempotency-Key': payload['idempotencyKey'] as String,
        },
        body: jsonEncode(payload),
      );

      expect(response.statusCode, 200);
      final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['received'], true);
      expect(body['method'], 'POST');
    });
  });
}
