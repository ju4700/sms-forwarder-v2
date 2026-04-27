import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/queued_sms.dart';
import 'database_service.dart';
import 'settings_service.dart';

class DeliveryService {
  DeliveryService({
    required this.databaseService,
    required this.settingsService,
  });

  final DatabaseService databaseService;
  final SettingsService settingsService;

  Future<bool> enqueueFromParsed({
    required String sender,
    required String messageBody,
    required double amount,
    required String transactionId,
    required String reference,
    required double fee,
    required double balance,
    required String localIso,
    required String utcIso,
  }) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final String uniqueSeed = '$transactionId|$amount|$sender|$localIso';
    final String id = 'txn-${uniqueSeed.hashCode.abs()}';
    final QueuedSms sms = QueuedSms(
      id: id,
      sender: sender,
      messageBody: messageBody,
      amount: amount,
      transactionId: transactionId,
      reference: reference,
      fee: fee,
      balance: balance,
      transactionLocalTime: localIso,
      transactionUtcTime: utcIso,
      status: 'pending',
      attemptCount: 0,
      nextRetryAt: null,
      lastError: null,
      createdAt: now,
      updatedAt: now,
    );

    await databaseService.insert(sms);
    return true;
  }

  Future<void> drainQueue() async {
    final AppSettings settings = await settingsService.load();
    if (settings.apiEndpoint.isEmpty) {
      return;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<QueuedSms> pending = await databaseService.fetchPending(now);

    for (final QueuedSms item in pending) {
      await _deliverOne(item, settings);
    }
  }

  Future<void> _deliverOne(QueuedSms item, AppSettings settings) async {
    final Uri uri;
    try {
      uri = Uri.parse(settings.apiEndpoint);
    } catch (_) {
      await databaseService.update(
        item.copyWith(
          status: 'dead_letter',
          lastError: 'Invalid API endpoint URL',
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return;
    }

    final Map<String, Object?> payload = <String, Object?>{
      'idempotencyKey': item.id,
      'number': item.sender,
      'amount': item.amount,
      'transactionId': item.transactionId,
      'reference': item.reference,
      'datetimeLocal': item.transactionLocalTime,
      'datetimeUtc': item.transactionUtcTime,
      'metadata': <String, Object?>{
        'fee': item.fee,
        'balance': item.balance,
        'rawSms': item.messageBody,
        'parserVersion': '1.0.0',
      },
    };

    try {
      final http.Response response = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'X-Idempotency-Key': item.id,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await databaseService.update(
          item.copyWith(
            status: 'delivered',
            lastError: null,
            nextRetryAt: null,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return;
      }

      await _scheduleRetry(item, settings.maxAttempts, 'HTTP ${response.statusCode}');
    } catch (e) {
      await _scheduleRetry(item, settings.maxAttempts, e.toString());
    }
  }

  Future<void> _scheduleRetry(QueuedSms item, int maxAttempts, String error) async {
    final int attempts = item.attemptCount + 1;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (attempts >= maxAttempts) {
      await databaseService.update(
        item.copyWith(
          attemptCount: attempts,
          status: 'dead_letter',
          lastError: error,
          nextRetryAt: null,
          updatedAt: now,
        ),
      );
      return;
    }

    final int retryAt = now + _computeBackoffWithJitterMs(attempts);
    await databaseService.update(
      item.copyWith(
        attemptCount: attempts,
        status: 'retry_scheduled',
        lastError: error,
        nextRetryAt: retryAt,
        updatedAt: now,
      ),
    );
  }

  int _computeBackoffWithJitterMs(int attempts) {
    const int initialMs = 1000;
    const int capMs = 60 * 60 * 1000;
    final int expDelay = min(capMs, initialMs * (1 << attempts));
    final int jitter = (expDelay * 0.1 * (Random().nextDouble() * 2 - 1)).round();
    return max(1000, expDelay + jitter);
  }
}
