import 'transaction_parser.dart';

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
  static bool looksLikeBkashReceivedSms(String body) {
    final String lower = body.toLowerCase();
    return (lower.contains('you have received') || lower.contains('received')) &&
        (lower.contains('trxid') || lower.contains('transaction id')) &&
        lower.contains('balance');
  }

  static ParsedBkashTransaction? parse(String body, {String? fallbackSender}) {
    final ParsedTransaction parsed = TransactionParser.parse(body, fallbackSender: fallbackSender);
    if (!parsed.isParsed && parsed.amount == 0.0) {
      return null;
    }
    return ParsedBkashTransaction(
      sender: parsed.sender,
      amount: parsed.amount,
      transactionId: parsed.transactionId,
      reference: parsed.reference,
      fee: parsed.fee,
      balance: parsed.balance,
      localIso: parsed.localIso,
      utcIso: parsed.utcIso,
      confidence: parsed.isParsed ? 1.0 : 0.5,
      rawSms: parsed.rawSms,
    );
  }
}
