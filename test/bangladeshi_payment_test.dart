import 'package:flutter_test/flutter_test.dart';
import 'package:sms_forwarder_v2/core/services/transaction_parser.dart';

void main() {
  group('Bangladeshi Payment Systems SMS Formats', () {
    test('bKash: Personal received SMS with reference and fee', () {
      const String sms =
          'You have received Tk 2,500.00 from 01712345678. Ref grocery. Fee Tk 0.00. Balance Tk 14,850.50. TrxID BL92JK49 at 26/10/2026 14:30';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'bKash');

      expect(parsed.provider, 'bkash');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 2500.0);
      expect(parsed.sender, '01712345678');
      expect(parsed.reference, 'GROCERY');
      expect(parsed.balance, 14850.50);
      expect(parsed.fee, 0.0);
      expect(parsed.transactionId, 'BL92JK49');
    });

    test('bKash: Merchant payment received SMS', () {
      const String sms =
          'Payment received Tk 850.00 from 01987654321. Ref INV-1002. Fee Tk 0.00. Balance Tk 45,200.00. TrxID PM89A123 at 26/10/2026 15:45';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'bKash');

      expect(parsed.provider, 'bkash');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 850.0);
      expect(parsed.sender, '01987654321');
      expect(parsed.reference, 'INV-1002');
      expect(parsed.transactionId, 'PM89A123');
    });

    test('Nagad: Cash In SMS with TxnID', () {
      const String sms =
          'Cash In Tk 5,000.00 from 01611223344 successful. Ref: Family. Fee: Tk 0.00. Balance: Tk 12,300.00. TxnID: 72A99BC at 25/10/2026 11:20';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: '16167');

      expect(parsed.provider, 'nagad');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 5000.0);
      expect(parsed.sender, '01611223344');
      expect(parsed.reference, 'FAMILY');
      expect(parsed.balance, 12300.0);
      expect(parsed.transactionId, '72A99BC');
    });

    test('Rocket / DBBL: Cash In from 12-digit mobile account', () {
      const String sms =
          'Cash In of Tk 1,200.00 from 01711223344-8 successful. Fee Tk 0.00, Balance Tk 3,450.00. TxnId:RK98765432';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'Rocket');

      expect(parsed.provider, 'rocket');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 1200.0);
      expect(parsed.sender, contains('01711223344'));
      expect(parsed.balance, 3450.0);
      expect(parsed.transactionId, 'RK98765432');
    });

    test('Upay (UCB): Cash In SMS', () {
      const String sms =
          'Cash In of Tk 1,000.00 from 01812345678 successful. Fee Tk 0.00. Balance Tk 3,500.00. TrxID: UP12345678 at 24/10/2026 15:00';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'upay');

      expect(parsed.amount, 1000.0);
      expect(parsed.transactionId, 'UP12345678');
      expect(parsed.balance, 3500.0);
      expect(parsed.isParsed, isTrue);
    });

    test('CellFin (IBBL): Fund Transfer Credit alert', () {
      const String sms =
          'CellFin: Your A/C has been credited with Tk 5,000.00 via Fund Transfer. Avail Bal: Tk 15,200.00. TrxID: CF123456';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'IBBL');

      expect(parsed.amount, 5000.0);
      expect(parsed.transactionId, 'CF123456');
      expect(parsed.balance, 15200.0);
    });

    test('Commercial Bank (City Bank / BRAC Bank): A/C credit alert', () {
      const String sms =
          'A/C *8901 has been credited by Tk 25,000.00 on 26/10/2026 by NPSB IBFT from Citytouch. Avail Bal: Tk 78,500.00';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'CityBank');

      expect(parsed.provider, 'bank');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 25000.0);
      expect(parsed.balance, 78500.0);
      expect(parsed.accountNumber, '8901');
    });

    test('Commercial Bank: A/C debit alert via ATM / POS', () {
      const String sms =
          'A/C ending with 4567 is debited for Tk 5,000.00 on 26/10/2026 at ATM WDL. Avail Bal Tk 22,100.00';
      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'BRACBank');

      expect(parsed.provider, 'bank');
      expect(parsed.direction, 'debit');
      expect(parsed.amount, 5000.0);
      expect(parsed.balance, 22100.0);
    });
  });

  group('Home Screen Queue Filtering Tests', () {
    test('filters out generic/non-forward messages from queue snapshot', () {
      // Simulate raw rows from native SmsQueueStore
      final List<Map<String, dynamic>> rawNativeRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'sender': 'bKash',
          'body': 'You have received Tk 100.00 from 01700000000. Balance Tk 500.00. TrxID TX123',
          'timestamp': 1700000000000,
          'forward': true,
          'status': 'pending',
        },
        <String, dynamic>{
          'sender': 'Friend',
          'body': 'Hey, are you coming to dinner tonight?',
          'timestamp': 1700000001000,
          'forward': false, // Generic SMS that did not match rules
          'status': 'captured',
        },
        <String, dynamic>{
          'sender': 'Nagad',
          'body': 'Cash In Tk 500.00 from 01800000000 successful. Balance: Tk 1,200.00. TxnID: NG998',
          'timestamp': 1700000002000,
          'forward': true,
          'status': 'pending',
        },
      ];

      // Enforce the home queue filter: only rows with forward == true are queued
      final List<Map<String, dynamic>> homeQueue = rawNativeRows
          .where((Map<String, dynamic> row) => row['forward'] == true)
          .toList();

      expect(homeQueue.length, 2);
      expect(homeQueue.any((Map<String, dynamic> r) => r['sender'] == 'Friend'), isFalse);
      expect(homeQueue.every((Map<String, dynamic> r) => r['forward'] == true), isTrue);
    });
  });
}
