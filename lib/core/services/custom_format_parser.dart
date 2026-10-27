import 'transaction_parser.dart';

class CustomFormatPreset {
  const CustomFormatPreset({
    required this.id,
    required this.name,
    required this.provider,
    required this.format,
    required this.direction,
    required this.sampleSms,
  });

  final String id;
  final String name;
  final String provider;
  final String format;
  final String direction;
  final String sampleSms;
}

class CustomSmsFormatParser {
  static const List<CustomFormatPreset> presets = <CustomFormatPreset>[
    CustomFormatPreset(
      id: 'mpesa_ke',
      name: 'M-Pesa (Kenya / East Africa)',
      provider: 'mpesa',
      direction: 'credit',
      format: '{trxId} Confirmed. Ksh{amount} received from {sender} on {date}. New M-PESA balance is Ksh{balance}.',
      sampleSms:
          'QA12BC34DE Confirmed. Ksh1,500.00 received from John Doe 0712345678 on 26/10/26 at 3:45 PM. New M-PESA balance is Ksh14,250.00. Transaction cost, Ksh0.00.',
    ),
    CustomFormatPreset(
      id: 'mpesa_send',
      name: 'M-Pesa Send Money (Debit)',
      provider: 'mpesa',
      direction: 'debit',
      format: '{trxId} Confirmed. Ksh{amount} sent to {sender} on {date}. New M-PESA balance is Ksh{balance}. Transaction cost, Ksh{fee}.',
      sampleSms:
          'QA12BC34DE Confirmed. Ksh2,000.00 sent to Jane Doe 0798765432 on 26/10/26 at 2:30 PM. New M-PESA balance is Ksh12,250.00. Transaction cost, Ksh34.00.',
    ),
    CustomFormatPreset(
      id: 'gcash_ph',
      name: 'GCash (Philippines)',
      provider: 'gcash',
      direction: 'credit',
      format: 'You have received PHP {amount} from {sender} on {date}. Ref. No. {trxId}.',
      sampleSms:
          'You have received PHP 1,500.00 from Juan Cruz (09171234567) on 10/26/2026 15:30. Ref. No. 123456789012.',
    ),
    CustomFormatPreset(
      id: 'upi_in',
      name: 'UPI / Bank Credit (India)',
      provider: 'upi',
      direction: 'credit',
      format: 'A/C {account} credited by Rs {amount} on {date} by transfer from {sender}. Ref {trxId}. Avail Bal: Rs {balance}',
      sampleSms:
          'A/C *1234 credited by Rs 2,500.00 on 26-Oct-26 by transfer from UPI/rajesh@okaxis. Ref 429812345678. Avail Bal: Rs 18,450.00 - HDFC Bank',
    ),
    CustomFormatPreset(
      id: 'chase_us',
      name: 'Chase / US Bank Deposit',
      provider: 'chase',
      direction: 'credit',
      format: 'Chase: A deposit of \${amount} was made to your checking account ending in {account} on {date}.',
      sampleSms:
          'Chase: A deposit of \$1,250.00 was made to your checking account ending in 1234 on 10/26/2026.',
    ),
    CustomFormatPreset(
      id: 'zelle_us',
      name: 'Zelle Payment Received (US)',
      provider: 'zelle',
      direction: 'credit',
      format: 'You received a Zelle payment of \${amount} from {sender}. Confirmation: {trxId}.',
      sampleSms:
          'You received a Zelle payment of \$250.00 from Alex Smith. Confirmation: ZEL123456.',
    ),
    CustomFormatPreset(
      id: 'upay_bd',
      name: 'Upay (Bangladesh)',
      provider: 'upay',
      direction: 'credit',
      format: 'Cash In of Tk {amount} from {sender} successful. Fee Tk {fee}. Balance Tk {balance}. TrxID: {trxId}',
      sampleSms:
          'Cash In of Tk 1,000.00 from 01812345678 successful. Fee Tk 0.00. Balance Tk 3,500.00. TrxID: UP12345678 at 24/10/2026 15:00',
    ),
    CustomFormatPreset(
      id: 'cellfin_bd',
      name: 'CellFin / IBBL (Bangladesh)',
      provider: 'cellfin',
      direction: 'credit',
      format: 'CellFin: Your A/C has been credited with Tk {amount} via Fund Transfer. Avail Bal: Tk {balance}. TrxID: {trxId}',
      sampleSms:
          'CellFin: Your A/C has been credited with Tk 5,000.00 via Fund Transfer. Avail Bal: Tk 15,200.00. TrxID: CF123456',
    ),
  ];

  /// Compiles a user-friendly template with `{amount}`, `{trxId}`, `{sender}`, etc. into a RegExp.
  static (RegExp regex, Map<String, int> groupMap)? compileTemplate(String template) {
    final String clean = template.trim();
    if (clean.isEmpty) return null;

    final Map<String, int> groupMap = <String, int>{};
    int groupIndex = 1;

    // Tokenize {placeholder}
    final RegExp placeholderRegex = RegExp(r'\{([A-Za-z0-9_]+|\.\.\.)\}');
    final StringBuffer patternBuffer = StringBuffer();
    int lastEnd = 0;

    for (final Match match in placeholderRegex.allMatches(clean)) {
      final String literalBefore = clean.substring(lastEnd, match.start);
      if (literalBefore.isNotEmpty) {
        patternBuffer.write(RegExp.escape(literalBefore).replaceAll(RegExp(r'\s+'), r'\s+'));
      }

      final String tag = match.group(1)?.toLowerCase() ?? '';
      switch (tag) {
        case 'amount':
        case 'amt':
          patternBuffer.write(r'([0-9,]+(?:\.[0-9]{1,2})?)');
          groupMap['amount'] = groupIndex++;
          break;
        case 'trxid':
        case 'txnid':
        case 'ref':
        case 'reference':
          patternBuffer.write(r'([A-Za-z0-9_-]+)');
          groupMap['trxId'] = groupIndex++;
          break;
        case 'sender':
        case 'from':
        case 'recipient':
        case 'counterparty':
          patternBuffer.write(r'([^\n,.]+)');
          groupMap['sender'] = groupIndex++;
          break;
        case 'balance':
        case 'bal':
          patternBuffer.write(r'([0-9,]+(?:\.[0-9]{1,2})?)');
          groupMap['balance'] = groupIndex++;
          break;
        case 'fee':
        case 'charge':
          patternBuffer.write(r'([0-9,]+(?:\.[0-9]{1,2})?)');
          groupMap['fee'] = groupIndex++;
          break;
        case 'account':
        case 'ac':
        case 'card':
          patternBuffer.write(r'([A-Za-z0-9*_-]+)');
          groupMap['account'] = groupIndex++;
          break;
        case 'currency':
          patternBuffer.write(r'([A-Za-z$€£৳₹]+)');
          groupMap['currency'] = groupIndex++;
          break;
        case 'date':
        case 'datetime':
        case 'time':
          patternBuffer.write(r'([0-9A-Za-z/:\s,-]+)');
          groupMap['date'] = groupIndex++;
          break;
        case 'any':
        case '...':
        default:
          patternBuffer.write(r'(?:.*?)');
          break;
      }

      lastEnd = match.end;
    }

    if (lastEnd < clean.length) {
      final String literalAfter = clean.substring(lastEnd);
      patternBuffer.write(RegExp.escape(literalAfter).replaceAll(RegExp(r'\s+'), r'\s+'));
    }

    try {
      final RegExp compiled = RegExp(patternBuffer.toString(), caseSensitive: false);
      return (compiled, groupMap);
    } catch (_) {
      return null;
    }
  }

  /// Parses an SMS against a custom format template string.
  static ParsedTransaction? parse({
    required String template,
    required String body,
    String? fallbackSender,
    String providerName = 'custom',
    String direction = 'credit',
  }) {
    final (RegExp regex, Map<String, int> groupMap)? compiled = compileTemplate(template);
    if (compiled == null) return null;

    final Match? match = compiled.$1.firstMatch(body);
    if (match == null) return null;

    final double? amount = compiled.$2.containsKey('amount')
        ? TransactionParser.cleanAmount(match.group(compiled.$2['amount']!))
        : null;

    final String trxId = compiled.$2.containsKey('trxId')
        ? (match.group(compiled.$2['trxId']!)?.trim().toUpperCase() ?? '')
        : 'CUST_${DateTime.now().millisecondsSinceEpoch}';

    final String sender = compiled.$2.containsKey('sender')
        ? (match.group(compiled.$2['sender']!)?.trim() ?? (fallbackSender ?? 'CUSTOM'))
        : (fallbackSender ?? 'CUSTOM');

    final double balance = compiled.$2.containsKey('balance')
        ? (TransactionParser.cleanAmount(match.group(compiled.$2['balance']!)) ?? 0.0)
        : 0.0;

    final double fee = compiled.$2.containsKey('fee')
        ? (TransactionParser.cleanAmount(match.group(compiled.$2['fee']!)) ?? 0.0)
        : 0.0;

    final String? account = compiled.$2.containsKey('account')
        ? match.group(compiled.$2['account']!)?.trim()
        : null;

    final DateTime now = DateTime.now();
    return ParsedTransaction(
      provider: providerName.isNotEmpty ? providerName : 'custom',
      direction: direction,
      amount: amount ?? 0.0,
      transactionId: trxId,
      reference: 'CUSTOM_SMS',
      sender: sender,
      fee: fee,
      balance: balance,
      accountNumber: account,
      localIso: now.toIso8601String(),
      utcIso: now.toUtc().toIso8601String(),
      rawSms: body,
      isParsed: amount != null && amount > 0,
    );
  }

  /// Tests a template against a sample SMS body and returns extracted values or error.
  static Map<String, dynamic> testTemplate(String template, String sampleSms) {
    final (RegExp regex, Map<String, int> groupMap)? compiled = compileTemplate(template);
    if (compiled == null) {
      return <String, dynamic>{
        'success': false,
        'error': 'Invalid template pattern. Please check your placeholder format.',
      };
    }

    final Match? match = compiled.$1.firstMatch(sampleSms.trim());
    if (match == null) {
      return <String, dynamic>{
        'success': false,
        'error': 'Template did not match the sample SMS. Ensure text outside placeholders matches exactly.',
      };
    }

    final Map<String, dynamic> extracted = <String, dynamic>{};
    for (final MapEntry<String, int> entry in compiled.$2.entries) {
      extracted[entry.key] = match.group(entry.value)?.trim() ?? '';
    }

    return <String, dynamic>{
      'success': true,
      'extracted': extracted,
    };
  }
}
