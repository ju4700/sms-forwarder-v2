import 'package:intl/intl.dart';

class ParsedTransaction {
  ParsedTransaction({
    required this.provider,
    required this.direction,
    required this.amount,
    required this.transactionId,
    required this.reference,
    required this.sender,
    required this.fee,
    required this.balance,
    required this.localIso,
    required this.utcIso,
    required this.rawSms,
    this.accountNumber,
    this.isParsed = true,
  });

  final String provider; // 'bkash', 'nagad', 'rocket', 'dbbl', 'bank', 'generic'
  final String direction; // 'credit', 'debit', 'unknown'
  final double amount;
  final String transactionId;
  final String reference;
  final String sender;
  final double fee;
  final double balance;
  final String localIso;
  final String utcIso;
  final String rawSms;
  final String? accountNumber;
  final bool isParsed;

  Map<String, dynamic> toJson({String idempotencyKey = ''}) {
    return <String, dynamic>{
      'schemaVersion': '2.0',
      if (idempotencyKey.isNotEmpty) 'idempotencyKey': idempotencyKey,
      'provider': provider,
      'direction': direction,
      'amount': amount,
      'fee': fee,
      'balance': balance,
      'transactionId': transactionId,
      'reference': reference,
      'sender': sender,
      'accountNumber': accountNumber,
      'datetimeLocal': localIso,
      'datetimeUtc': utcIso,
      'rawSms': rawSms,
      'isParsed': isParsed,
    };
  }
}

class TransactionParser {
  static final RegExp _amountRegex = RegExp(
    r'(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _trxIdRegex = RegExp(
    r'(?:TrxID|TxnID|Txn\s*ID|Transaction\s*ID|Ref\s*ID)[\s:]*([A-Z0-9]+)',
    caseSensitive: false,
  );

  static final RegExp _balanceRegex = RegExp(
    r'(?:Bal|Balance|Avail(?:able)?\s*Bal(?:ance)?|Total\s*Bal)[\s:]*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final RegExp _feeRegex = RegExp(
    r'Fee[\s:]*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  /// Converts Bengali numerals (০-৯) to Western Arabic (0-9)
  static String normalizeBengaliDigits(String input) {
    const List<String> bengali = <String>['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const List<String> english = <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String output = input;
    for (int i = 0; i < 10; i++) {
      output = output.replaceAll(bengali[i], english[i]);
    }
    return output;
  }

  static double? cleanAmount(String? raw) {
    if (raw == null) return null;
    final String clean = raw.replaceAll(',', '').trim();
    return double.tryParse(clean);
  }

  static String cleanReference(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }

  static String normalizePhone(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('880') && digits.length >= 13) {
      return '0${digits.substring(3)}';
    }
    if (digits.startsWith('88') && digits.length > 11) {
      return digits.substring(2);
    }
    return digits;
  }

  /// Returns true if this message is an OTP, verification code, or PIN alert.
  static bool isSecurityOrOtp(String body) {
    final String lower = body.toLowerCase();
    final RegExp otpWordRegex = RegExp(r'\botp\b', caseSensitive: false);
    return lower.contains('verification code') ||
        lower.contains('security code') ||
        lower.contains('login code') ||
        lower.contains('one time password') ||
        lower.contains('secret pin') ||
        lower.contains('do not share') ||
        otpWordRegex.hasMatch(body);
  }

  /// Returns true if this message is promotional or marketing spam.
  static bool isPromotionalOrSpam(String body) {
    final String lower = body.toLowerCase();
    // Legitimate transaction confirmations containing TrxID or TxnID are never promotional spam
    if (lower.contains('trxid') || lower.contains('txnid')) {
      return false;
    }
    return lower.contains('cashback') ||
        lower.contains('offer') ||
        lower.contains('bonus') ||
        lower.contains('dial *247#') ||
        lower.contains('dial *167#') ||
        lower.contains('dial *322#') ||
        lower.contains('download app') ||
        lower.contains('promo') ||
        lower.contains('discount') ||
        lower.contains('recharge offer');
  }

  /// Detects whether the transaction is credit (money received/deposit), debit (money sent/spent), or unknown.
  static String detectDirection(String body) {
    final String lower = body.toLowerCase();
    if (lower.contains('received') ||
        lower.contains('cash in') ||
        lower.contains('credited') ||
        lower.contains('payment received') ||
        lower.contains('deposit')) {
      return 'credit';
    }
    if (lower.contains('payment to') ||
        lower.contains('payment successful') ||
        lower.contains('cash out') ||
        lower.contains('send money') ||
        lower.contains('sent to') ||
        lower.contains('debited') ||
        lower.contains('bill successfully paid') ||
        lower.contains('was used for') ||
        lower.contains('withdrawn')) {
      return 'debit';
    }
    return 'unknown';
  }

  /// Detects the provider (bkash, nagad, rocket, bank, generic) based on sender or body keywords.
  static String detectProvider(String sender, String body) {
    final String s = sender.toLowerCase();
    final String b = body.toLowerCase();

    if (s.contains('bkash') || s == '16247' || b.contains('bkash')) {
      return 'bkash';
    }
    if (s.contains('nagad') || s == '16167' || b.contains('nagad')) {
      return 'nagad';
    }
    if (s.contains('rocket') || s == '16216' || b.contains('rocket') || s == 'dbbl') {
      return 'rocket';
    }
    if (s.contains('bank') ||
        s.contains('city') ||
        s.contains('brac') ||
        s.contains('ebl') ||
        s.contains('scb') ||
        s.contains('ibbl') ||
        b.contains('a/c') ||
        b.contains('card ending')) {
      return 'bank';
    }
    return 'generic';
  }

  /// Main parse method that attempts all provider patterns, falling back to a generic parser.
  static ParsedTransaction parse(String rawBody, {String? fallbackSender}) {
    final String normalized = normalizeBengaliDigits(rawBody).trim();
    final String sender = fallbackSender?.trim() ?? '';
    final String provider = detectProvider(sender, normalized);
    final String direction = detectDirection(normalized);

    final DateTime now = DateTime.now();
    final String localIso = DateFormat("yyyy-MM-dd'T'HH:mm:ssXXX").format(now);
    final String utcIso = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(now.toUtc());

    // 1. Try bKash parsing
    if (provider == 'bkash' || normalized.toLowerCase().contains('bkash') || normalized.toLowerCase().contains('trxid')) {
      final ParsedTransaction? bkash = _parseBkash(normalized, sender, localIso, utcIso);
      if (bkash != null) return bkash;
    }

    // 2. Try Nagad parsing
    if (provider == 'nagad' || normalized.toLowerCase().contains('nagad')) {
      final ParsedTransaction? nagad = _parseNagad(normalized, sender, localIso, utcIso);
      if (nagad != null) return nagad;
    }

    // 3. Try Rocket parsing
    if (provider == 'rocket' || normalized.toLowerCase().contains('rocket')) {
      final ParsedTransaction? rocket = _parseRocket(normalized, sender, localIso, utcIso);
      if (rocket != null) return rocket;
    }

    // 4. Try Commercial Bank parsing
    final ParsedTransaction? bank = _parseBank(normalized, sender, localIso, utcIso);
    if (bank != null) return bank;

    // 5. Fallback generic parser (extracts whatever is present)
    return _parseGeneric(normalized, sender, provider, direction, localIso, utcIso);
  }

  static ParsedTransaction? _parseBkash(String body, String sender, String fallbackLocal, String fallbackUtc) {
    // Credit with Ref
    final RegExp p1 = RegExp(
      r'(?:You\s+have\s+received|Received)\s+(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*(?:Ref|Reference)\s*([^\.]+)\.?\s*Fee\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    );
    final Match? m1 = p1.firstMatch(body);
    if (m1 != null) {
      final double? amt = cleanAmount(m1.group(1));
      if (amt != null) {
        final (String local, String utc) = _parseDateString(m1.group(7) ?? '', fallbackLocal, fallbackUtc);
        return ParsedTransaction(
          provider: 'bkash',
          direction: 'credit',
          amount: amt,
          sender: normalizePhone(m1.group(2) ?? ''),
          reference: cleanReference(m1.group(3) ?? ''),
          fee: cleanAmount(m1.group(4)) ?? 0.0,
          balance: cleanAmount(m1.group(5)) ?? 0.0,
          transactionId: m1.group(6)?.trim().toUpperCase() ?? '',
          localIso: local,
          utcIso: utc,
          rawSms: body,
        );
      }
    }

    // Credit without Ref
    final RegExp p2 = RegExp(
      r'(?:You\s+have\s+received|Received)\s+(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)\.?\s*Fee\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    );
    final Match? m2 = p2.firstMatch(body);
    if (m2 != null) {
      final double? amt = cleanAmount(m2.group(1));
      if (amt != null) {
        final (String local, String utc) = _parseDateString(m2.group(6) ?? '', fallbackLocal, fallbackUtc);
        return ParsedTransaction(
          provider: 'bkash',
          direction: 'credit',
          amount: amt,
          sender: normalizePhone(m2.group(2) ?? ''),
          reference: 'RECEIVED',
          fee: cleanAmount(m2.group(3)) ?? 0.0,
          balance: cleanAmount(m2.group(4)) ?? 0.0,
          transactionId: m2.group(5)?.trim().toUpperCase() ?? '',
          localIso: local,
          utcIso: utc,
          rawSms: body,
        );
      }
    }

    // Payment to merchant
    final RegExp p3 = RegExp(
      r'Payment\s+(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+to\s+([^\.]+)\.?\s+is\s+successful\.?\s*Balance\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    );
    final Match? m3 = p3.firstMatch(body);
    if (m3 != null) {
      final double? amt = cleanAmount(m3.group(1));
      if (amt != null) {
        final (String local, String utc) = _parseDateString(m3.group(5) ?? '', fallbackLocal, fallbackUtc);
        return ParsedTransaction(
          provider: 'bkash',
          direction: 'debit',
          amount: amt,
          sender: normalizePhone(sender),
          reference: cleanReference(m3.group(2) ?? ''),
          fee: 0.0,
          balance: cleanAmount(m3.group(3)) ?? 0.0,
          transactionId: m3.group(4)?.trim().toUpperCase() ?? '',
          localIso: local,
          utcIso: utc,
          rawSms: body,
        );
      }
    }

    // Cash Out
    final RegExp p4 = RegExp(
      r'Cash\s+Out\s+(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+to\s+([0-9+]+)\.?\s*Fee\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*Balance\s*(?:Tk|BDT|৳)\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|Transaction\s*ID)\s+([A-Z0-9]+)\s+at\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    );
    final Match? m4 = p4.firstMatch(body);
    if (m4 != null) {
      final double? amt = cleanAmount(m4.group(1));
      if (amt != null) {
        final (String local, String utc) = _parseDateString(m4.group(6) ?? '', fallbackLocal, fallbackUtc);
        return ParsedTransaction(
          provider: 'bkash',
          direction: 'debit',
          amount: amt,
          sender: normalizePhone(m4.group(2) ?? ''),
          reference: 'CASHOUT',
          fee: cleanAmount(m4.group(3)) ?? 0.0,
          balance: cleanAmount(m4.group(4)) ?? 0.0,
          transactionId: m4.group(5)?.trim().toUpperCase() ?? '',
          localIso: local,
          utcIso: utc,
          rawSms: body,
        );
      }
    }

    return null;
  }

  static ParsedTransaction? _parseNagad(String body, String sender, String fallbackLocal, String fallbackUtc) {
    // Cash In or Received
    final RegExp p = RegExp(
      r'(?:Cash\s+In|Received|You\s+have\s+received)\s+(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+]+)(?:\s+successful)?\.?\s*(?:Ref:?\s*([^\.]+)\.?)?\s*Fee:?\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*Balance:?\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TrxID|TxnID):?\s*([A-Z0-9]+)\s+(?:at|on)\s+([0-9]{1,2}/[0-9]{1,2}/[0-9]{4}\s+[0-9]{1,2}:[0-9]{2})',
      caseSensitive: false,
    );
    final Match? m = p.firstMatch(body);
    if (m != null) {
      final double? amt = cleanAmount(m.group(1));
      if (amt != null) {
        final (String local, String utc) = _parseDateString(m.group(7) ?? '', fallbackLocal, fallbackUtc);
        return ParsedTransaction(
          provider: 'nagad',
          direction: 'credit',
          amount: amt,
          sender: normalizePhone(m.group(2) ?? ''),
          reference: cleanReference(m.group(3) ?? 'NAGAD'),
          fee: cleanAmount(m.group(4)) ?? 0.0,
          balance: cleanAmount(m.group(5)) ?? 0.0,
          transactionId: m.group(6)?.trim().toUpperCase() ?? '',
          localIso: local,
          utcIso: utc,
          rawSms: body,
        );
      }
    }
    return null;
  }

  static ParsedTransaction? _parseRocket(String body, String sender, String fallbackLocal, String fallbackUtc) {
    // Rocket Cash In
    final RegExp p = RegExp(
      r'Cash\s+In\s+of\s+(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s+from\s+([0-9+-]+)\s+successful\.?\s*Fee\s*(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?),?\s*Balance\s*(?:Tk|BDT|৳)\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\.?\s*(?:TxnId|TrxID):?\s*([A-Z0-9]+)',
      caseSensitive: false,
    );
    final Match? m = p.firstMatch(body);
    if (m != null) {
      final double? amt = cleanAmount(m.group(1));
      if (amt != null) {
        return ParsedTransaction(
          provider: 'rocket',
          direction: 'credit',
          amount: amt,
          sender: m.group(2)?.trim() ?? '',
          reference: 'ROCKET',
          fee: cleanAmount(m.group(3)) ?? 0.0,
          balance: cleanAmount(m.group(4)) ?? 0.0,
          transactionId: m.group(5)?.trim().toUpperCase() ?? '',
          localIso: fallbackLocal,
          utcIso: fallbackUtc,
          rawSms: body,
        );
      }
    }
    return null;
  }

  static ParsedTransaction? _parseBank(String body, String sender, String fallbackLocal, String fallbackUtc) {
    // 1. Bank A/C Credit or Debit
    final RegExp acRegex = RegExp(
      r'A/C\s*(?:ending\s+with\s*|\*|ending\s+)?([0-9A-Z]+)\s+(?:has\s+been|is)?\s*(credited|debited)\s*(?:by|for|with)?\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:on|at)\s*([0-9]{1,2}(?:/|-)[0-9A-Za-z]{2,3}(?:/|-)[0-9]{2,4}[^.]*?)\s*(?:by|via|Ref:?)\s*([^\.]+)?\.?\s*(?:Avail(?:able)?\s*Bal(?:ance)?:?|Total\s*Bal:?)\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final Match? acMatch = acRegex.firstMatch(body);
    if (acMatch != null) {
      final double? amt = cleanAmount(acMatch.group(3));
      if (amt != null) {
        final String action = acMatch.group(2)?.toLowerCase() ?? 'credited';
        final String direction = action == 'debited' ? 'debit' : 'credit';
        return ParsedTransaction(
          provider: 'bank',
          direction: direction,
          amount: amt,
          sender: sender.isNotEmpty ? sender : 'BANK',
          reference: cleanReference(acMatch.group(5) ?? 'BANK_TRANSFER'),
          accountNumber: acMatch.group(1)?.trim(),
          fee: 0.0,
          balance: cleanAmount(acMatch.group(6)) ?? 0.0,
          transactionId: 'BANK_${DateTime.now().millisecondsSinceEpoch}',
          localIso: fallbackLocal,
          utcIso: fallbackUtc,
          rawSms: body,
        );
      }
    }

    // 2. Card Debit / POS / E-Commerce
    final RegExp cardRegex = RegExp(
      r'(?:Your\s+)?Card\s*(?:ending\s+with\s*|\*|ending\s+)?([0-9A-Z]+)\s+(?:was\s+used\s+for|debited\s+for)\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:at|to|for)?\s*([^\.]+)?\s*(?:on|at)\s*([0-9]{1,2}(?:/|-)[0-9A-Za-z]{2,3}(?:/|-)[0-9]{2,4}[^.]*?)\.?\s*(?:Avail(?:able)?\s*Bal(?:ance)?:?|Total\s*Bal:?)\s*(?:Tk|BDT|৳)?\.?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final Match? cardMatch = cardRegex.firstMatch(body);
    if (cardMatch != null) {
      final double? amt = cleanAmount(cardMatch.group(2));
      if (amt != null) {
        return ParsedTransaction(
          provider: 'bank',
          direction: 'debit',
          amount: amt,
          sender: sender.isNotEmpty ? sender : 'BANK',
          reference: cleanReference(cardMatch.group(3) ?? 'CARD_TXN'),
          accountNumber: 'CARD_${cardMatch.group(1)?.trim()}',
          fee: 0.0,
          balance: cleanAmount(cardMatch.group(5)) ?? 0.0,
          transactionId: 'BANK_${DateTime.now().millisecondsSinceEpoch}',
          localIso: fallbackLocal,
          utcIso: fallbackUtc,
          rawSms: body,
        );
      }
    }

    return null;
  }

  static ParsedTransaction _parseGeneric(
    String body,
    String sender,
    String provider,
    String direction,
    String localIso,
    String utcIso,
  ) {
    final Match? amtMatch = _amountRegex.firstMatch(body);
    final Match? trxMatch = _trxIdRegex.firstMatch(body);
    final Match? balMatch = _balanceRegex.firstMatch(body);
    final Match? feeMatch = _feeRegex.firstMatch(body);

    final double amount = cleanAmount(amtMatch?.group(1)) ?? 0.0;
    final String trxId = trxMatch?.group(1)?.trim().toUpperCase() ?? 'GEN_${DateTime.now().millisecondsSinceEpoch}';
    final double balance = cleanAmount(balMatch?.group(1)) ?? 0.0;
    final double fee = cleanAmount(feeMatch?.group(1)) ?? 0.0;

    return ParsedTransaction(
      provider: provider,
      direction: direction,
      amount: amount,
      transactionId: trxId,
      reference: 'SMS_FORWARD',
      sender: sender.isNotEmpty ? sender : 'UNKNOWN',
      fee: fee,
      balance: balance,
      localIso: localIso,
      utcIso: utcIso,
      rawSms: body,
      isParsed: amtMatch != null,
    );
  }

  static (String, String) _parseDateString(String text, String fallbackLocal, String fallbackUtc) {
    try {
      final DateFormat parser = DateFormat('dd/MM/yyyy HH:mm');
      final DateTime parsed = parser.parse(text.trim());
      // Apply Asia/Dhaka (+06:00)
      final DateTime dhakaTime = DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour - 6,
        parsed.minute,
      );
      final String local = DateFormat("yyyy-MM-dd'T'HH:mm:ss+06:00").format(parsed);
      final String utc = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(dhakaTime);
      return (local, utc);
    } catch (_) {
      return (fallbackLocal, fallbackUtc);
    }
  }
}
