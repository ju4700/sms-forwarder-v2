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
  static final List<RegExp> _patterns = <RegExp>[
    RegExp(
      r'You\s+have\s+received\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s+([^\.]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    ),
    RegExp(
      r'Received\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s+([^\.]+)\.?\s*Fee\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s+(?:Tk|BDT|৳)\s*([0-9]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
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

  static ParsedBkashTransaction? parse(String body) {
    Match? match;
    for (final RegExp pattern in _patterns) {
      final Match? candidate = pattern.firstMatch(body);
      if (candidate != null) {
        match = candidate;
        break;
      }
    }

    match ??= _primaryPattern.firstMatch(body);
    if (match == null) {
      return null;
    }

    final double? amount = _toAmount(match.group(1));
    final String sender = _normalizePhone(match.group(2) ?? '');
    final String reference = (match.groupCount >= 3 ? match.group(3) : '')?.trim() ?? '';
    final double? fee = _toAmount(match.groupCount >= 4 ? match.group(4) : '0');
    final double? balance = _toAmount(match.groupCount >= 5 ? match.group(5) : '0');
    final String trxId = (match.groupCount >= 6 ? match.group(6) : '')?.trim().toUpperCase() ?? '';
    final String dateText = (match.groupCount >= 7 ? match.group(7) : '')?.trim() ?? '';

    if (amount == null || fee == null || balance == null || sender.isEmpty) {
      return null;
    }

    final DateTime? parsed = dateText.isEmpty ? null : _parseDateTime(dateText);
    final DateTime local = parsed ?? DateTime.now();
    final DateTime utc = local.toUtc();

    final String resolvedTrxId = trxId.isEmpty ? _fallbackTrx(body) : trxId;
    if (resolvedTrxId.isEmpty) {
      return null;
    }

    return ParsedBkashTransaction(
      sender: sender,
      amount: amount,
      transactionId: resolvedTrxId,
      reference: reference,
      fee: fee,
      balance: balance,
      localIso: local.toIso8601String(),
      utcIso: utc.toIso8601String(),
      confidence: _confidenceFor(reference: reference),
      rawSms: body,
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

  static String _fallbackTrx(String body) {
    final RegExp trxPattern = RegExp(r'(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)', caseSensitive: false);
    final Match? match = trxPattern.firstMatch(body);
    if (match == null) {
      return '';
    }
    return (match.group(1) ?? '').trim().toUpperCase();
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
