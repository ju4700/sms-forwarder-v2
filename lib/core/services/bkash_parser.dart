import 'package:intl/intl.dart';

class ParsedBkashTransaction {
  ParsedBkashTransaction({
    required this.sender,
    required this.amount,
    required this.transactionId,
    required this.reference,
    required this.fee,
    required this.balance,
    required this.localIso,
    required this.utcIso,
    required this.confidence,
    required this.rawSms,
  });

  final String sender;
  final double amount;
  final String transactionId;
  final String reference;
  final double fee;
  final double balance;
  final String localIso;
  final String utcIso;
  final double confidence;
  final String rawSms;
}

class BkashParser {
  static final RegExp _senderPattern = RegExp(r'^01[3-9]\d{8}$');
  static final RegExp _referencePattern = RegExp(r'^[A-Z0-9][A-Z0-9 _./-]{1,31}$');
  static final RegExp _transactionPattern = RegExp(r'^[A-Z0-9]{8,20}$');

  static final List<RegExp> _patterns = <RegExp>[
    RegExp(
      r'You\s+have\s+received\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s+([^\.]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    ),
    RegExp(
      r'You\s+have\s+received\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    ),
    RegExp(
      r'Received\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s+([^\.]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    ),
    RegExp(
      r'Payment\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+to\s+([^\.]+)\.?\s+is\s+successful\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    ),
    RegExp(
      r'Bill\s+successfully\s+paid\.?\s*Biller:\s*([^\n]+)\s*Amount:\s*(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s*Fee:\s*(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    ),
  ];

  static final RegExp _primaryPattern = RegExp(
    r'You\s+have\s+received\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)',
    caseSensitive: false,
  );

  static bool looksLikeBkashReceivedSms(String body) {
    final String lower = body.toLowerCase();
    return (lower.contains('you have received') || lower.contains('received')) &&
        (lower.contains('trxid') || lower.contains('transaction id')) &&
        lower.contains('balance');
  }

  static ParsedBkashTransaction? parse(String body, {String? fallbackSender}) {
    Match? match;
    int patternIndex = -1;
    for (final RegExp pattern in _patterns) {
      final Match? candidate = pattern.firstMatch(body);
      if (candidate != null) {
        match = candidate;
        patternIndex = _patterns.indexOf(pattern);
        break;
      }
    }

    match ??= _primaryPattern.firstMatch(body);
    if (match == null) {
      return null;
    }

    final ParsedFields fields = _extractFields(match, patternIndex, fallbackSender: fallbackSender);
    final double? amount = fields.amount;
    final String sender = fields.sender;
    final String reference = fields.reference;
    final double? fee = fields.fee;
    final double? balance = fields.balance;
    final String trxId = fields.trxId;
    final String dateText = fields.dateText;

    if (amount == null || fee == null || balance == null || sender.isEmpty) {
      return null;
    }

    if (!_isValidAmount(amount) || !_isValidAmount(fee) || !_isValidAmount(balance)) {
      return null;
    }

    if (_isDigitsOnly(sender) && !_senderPattern.hasMatch(sender)) {
      return null;
    }

    final String safeReference = reference.isEmpty || !_referencePattern.hasMatch(reference)
        ? fields.fallbackReference
        : reference;

    if (!_transactionPattern.hasMatch(trxId)) {
      return null;
    }

    final DateTime? parsed = dateText.isEmpty ? null : _parseDateTime(dateText);
    if (parsed == null || !_isSaneTimestamp(parsed)) {
      return null;
    }

    final DateTime local = parsed;
    final DateTime utc = local.toUtc();

    return ParsedBkashTransaction(
      sender: sender,
      amount: amount,
      transactionId: trxId,
      reference: safeReference,
      fee: fee,
      balance: balance,
      localIso: local.toIso8601String(),
      utcIso: utc.toIso8601String(),
      confidence: _confidenceFor(reference: safeReference),
      rawSms: body,
    );
  }

  static ParsedFields _extractFields(
    Match match,
    int patternIndex, {
    String? fallbackSender,
  }) {
    if (patternIndex == 1) {
      return ParsedFields(
        amount: _toAmount(match.group(1)),
        sender: _normalizePhone(match.group(2) ?? fallbackSender ?? ''),
        reference: '',
        fee: _toAmount(match.group(3)) ?? 0,
        balance: _toAmount(match.group(4)) ?? 0,
        trxId: (match.group(5) ?? '').trim().toUpperCase(),
        dateText: (match.group(6) ?? '').trim(),
        fallbackReference: 'RECEIVED',
      );
    }

    if (patternIndex == 3) {
      return ParsedFields(
        amount: _toAmount(match.group(1)),
        sender: _normalizePhone(fallbackSender ?? ''),
        reference: _cleanReference(match.group(2) ?? ''),
        fee: 0,
        balance: _toAmount(match.group(3)),
        trxId: (match.group(4) ?? '').trim().toUpperCase(),
        dateText: (match.group(5) ?? '').trim(),
        fallbackReference: 'PAYMENT',
      );
    }

    if (patternIndex == 4) {
      return ParsedFields(
        amount: _toAmount(match.group(2)),
        sender: _normalizePhone(fallbackSender ?? ''),
        reference: _cleanReference(match.group(1) ?? ''),
        fee: _toAmount(match.group(3)) ?? 0,
        balance: 0,
        trxId: (match.group(4) ?? '').trim().toUpperCase(),
        dateText: (match.group(5) ?? '').trim(),
        fallbackReference: 'BILL',
      );
    }

    return ParsedFields(
      amount: _toAmount(match.group(1)),
      sender: _normalizePhone(match.group(2) ?? fallbackSender ?? ''),
      reference: _cleanReference((match.groupCount >= 3 ? match.group(3) : '') ?? ''),
      fee: _toAmount(match.groupCount >= 4 ? match.group(4) : '0'),
      balance: _toAmount(match.groupCount >= 5 ? match.group(5) : '0'),
      trxId: (match.groupCount >= 6 ? match.group(6) : '')?.trim().toUpperCase() ?? '',
      dateText: (match.groupCount >= 7 ? match.group(7) : '')?.trim() ?? '',
      fallbackReference: 'RECEIVED',
    );
  }

  static double? _toAmount(String? raw) {
    if (raw == null) {
      return null;
    }
    final String normalized = raw.replaceAll(',', '').trim();
    return double.tryParse(normalized);
  }

  static DateTime? _parseDateTime(String text) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').parseStrict(text);
    } catch (_) {
      return null;
    }
  }

  static String _normalizePhone(String raw) {
    final String digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('880') && digitsOnly.length >= 13) {
      return '0${digitsOnly.substring(3)}';
    }
    if (digitsOnly.startsWith('88') && digitsOnly.length > 11) {
      return digitsOnly.substring(2);
    }
    return digitsOnly;
  }

  static String _cleanReference(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
  }

  static bool _isDigitsOnly(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  static bool _isValidAmount(double value) {
    return value >= 0 && value <= 1000000;
  }

  static bool _isSaneTimestamp(DateTime value) {
    final DateTime now = DateTime.now();
    final DateTime lowerBound = now.subtract(const Duration(days: 365 * 3));
    final DateTime upperBound = now.add(const Duration(minutes: 5));
    return value.isAfter(lowerBound) && value.isBefore(upperBound);
  }

  static double _confidenceFor({required String reference}) {
    if (reference.isEmpty) {
      return 0.85;
    }
    if (reference.length >= 3) {
      return 0.98;
    }
    return 0.9;
  }
}

class ParsedFields {
  ParsedFields({
    required this.amount,
    required this.sender,
    required this.reference,
    required this.fee,
    required this.balance,
    required this.trxId,
    required this.dateText,
    required this.fallbackReference,
  });

  final double? amount;
  final String sender;
  final String reference;
  final double? fee;
  final double? balance;
  final String trxId;
  final String dateText;
  final String fallbackReference;
}
