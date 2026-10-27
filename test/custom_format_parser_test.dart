import 'package:flutter_test/flutter_test.dart';
import 'package:sms_forwarder_v2/core/services/custom_format_parser.dart';
import 'package:sms_forwarder_v2/core/services/transaction_parser.dart';

void main() {
  group('CustomSmsFormatParser Preset Tests', () {
    test('parses M-Pesa Kenya received SMS correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'mpesa_ke');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'mpesa');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 1500.0);
      expect(parsed.transactionId, 'QA12BC34DE');
      expect(parsed.sender, contains('John Doe'));
      expect(parsed.balance, 14250.0);
      expect(parsed.fee, 0.0);
      expect(parsed.isParsed, isTrue);
    });

    test('parses M-Pesa Kenya Send Money (debit) SMS correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'mpesa_send');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'mpesa');
      expect(parsed.direction, 'debit');
      expect(parsed.amount, 2000.0);
      expect(parsed.transactionId, 'QA12BC34DE');
      expect(parsed.sender, contains('Jane Doe'));
      expect(parsed.balance, 12250.0);
      expect(parsed.fee, 34.0);
    });

    test('parses GCash Philippines received SMS correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'gcash_ph');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'gcash');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 1500.0);
      expect(parsed.transactionId, '123456789012');
      expect(parsed.sender, contains('Juan Cruz'));
    });

    test('parses Indian UPI / Bank credit SMS correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'upi_in');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'upi');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 2500.0);
      expect(parsed.accountNumber, '*1234');
      expect(parsed.transactionId, '429812345678');
      expect(parsed.balance, 18450.0);
    });

    test('parses Chase US Bank deposit alert correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'chase_us');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'chase');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 1250.0);
      expect(parsed.accountNumber, '1234');
    });

    test('parses Zelle US payment received correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'zelle_us');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'zelle');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 250.0);
      expect(parsed.transactionId, 'ZEL123456');
      expect(parsed.sender, contains('Alex Smith'));
    });

    test('parses Upay Bangladesh Cash In correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'upay_bd');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'upay');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 1000.0);
      expect(parsed.fee, 0.0);
      expect(parsed.balance, 3500.0);
      expect(parsed.transactionId, 'UP12345678');
    });

    test('parses CellFin Bangladesh credit transfer correctly', () {
      final CustomFormatPreset preset =
          CustomSmsFormatParser.presets.firstWhere((CustomFormatPreset p) => p.id == 'cellfin_bd');

      final ParsedTransaction? parsed = CustomSmsFormatParser.parse(
        template: preset.format,
        body: preset.sampleSms,
        providerName: preset.provider,
        direction: preset.direction,
      );

      expect(parsed, isNotNull);
      expect(parsed!.provider, 'cellfin');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 5000.0);
      expect(parsed.balance, 15200.0);
      expect(parsed.transactionId, 'CF123456');
    });
  });

  group('Custom Format Interactive Template Tester', () {
    test('testTemplate returns success and map of extracted values', () {
      const String template =
          'Payment of \${amount} made to {sender}. Trx: {trxId}. Balance: \${balance}';
      const String sample =
          'Payment of \$49.99 made to DigitalOcean. Trx: DO1029384. Balance: \$1,234.50';

      final Map<String, dynamic> result = CustomSmsFormatParser.testTemplate(template, sample);
      expect(result['success'], isTrue);
      final Map<String, dynamic> extracted = result['extracted'] as Map<String, dynamic>;
      expect(extracted['amount'], '49.99');
      expect(extracted['sender'], 'DigitalOcean');
      expect(extracted['trxId'], 'DO1029384');
      expect(extracted['balance'], '1,234.50');
    });

    test('testTemplate returns failure with helpful error when template does not match', () {
      const String template = 'Received \${amount} from {sender}';
      const String sample = 'Sent \$50 to Alice';

      final Map<String, dynamic> result = CustomSmsFormatParser.testTemplate(template, sample);
      expect(result['success'], isFalse);
      expect(result['error'], contains('did not match'));
    });
  });
}
