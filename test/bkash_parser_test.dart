import 'package:flutter_test/flutter_test.dart';
import 'package:sms_forwarder_v2/core/services/bkash_parser.dart';
import 'package:sms_forwarder_v2/core/services/transaction_parser.dart';

void main() {
  group('bKash Parsing', () {
    test('parses standard bKash received SMS without comma', () {
      const String sms =
          'You have received Tk 200.00 from 01815946458. Ref FEROJ. Fee Tk 0.00. Balance Tk 458.97. TrxID DCI99TCKLX at 18/03/2026 21:29';

      final ParsedBkashTransaction? parsed = BkashParser.parse(sms);

      expect(parsed, isNotNull);
      expect(parsed!.sender, '01815946458');
      expect(parsed.amount, 200.00);
      expect(parsed.transactionId, 'DCI99TCKLX');
      expect(parsed.reference, 'FEROJ');
      expect(parsed.fee, 0.00);
      expect(parsed.balance, 458.97);
    });

    test('parses bKash received SMS WITH COMMA in thousands amount', () {
      const String sms =
          'You have received Tk 1,500.00 from 01711223344. Ref STORE. Fee Tk 0.00. Balance Tk 25,450.50. TrxID 9K20ABC123 at 21/10/2026 14:30';

      final ParsedTransaction parsed = TransactionParser.parse(sms);

      expect(parsed.provider, 'bkash');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 1500.00);
      expect(parsed.balance, 25450.50);
      expect(parsed.transactionId, '9K20ABC123');
      expect(parsed.sender, '01711223344');
    });

    test('parses bKash with Bengali numerals', () {
      const String sms =
          'You have received Tk ১,৫০০.০০ from ০১৭xxxxxxxx. Ref FEROJ. Fee Tk ০.০০. Balance Tk ১০,৪৫৮.৯৭. TrxID 9K20ABC123 at ১৮/০৩/২০২৬ ২১:২৯';

      final ParsedTransaction parsed = TransactionParser.parse(sms);
      expect(parsed.amount, 1500.00);
      expect(parsed.balance, 10458.97);
      expect(parsed.transactionId, '9K20ABC123');
    });

    test('parses bKash Merchant Payment received SMS', () {
      const String sms =
          'Payment received Tk 850.00 from 01912345678. Ref INVOICE12. Fee Tk 0.00. Balance Tk 12,850.00. TrxID PMT987654 at 26/10/2026 15:30';

      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'bKash');
      expect(parsed.provider, 'bkash');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 850.00);
      expect(parsed.reference, 'INVOICE12');
      expect(parsed.transactionId, 'PMT987654');
      expect(parsed.sender, '01912345678');
      expect(parsed.balance, 12850.00);
    });
  });

  group('Nagad Parsing', () {
    test('parses Nagad Cash In message', () {
      const String sms =
          'Cash In Tk 2,000.00 from 01712345678 successful. Fee: Tk 0.00. Balance: Tk 4,500.00. TrxID: 71ABCDEF at 21/10/2026 15:20';

      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'NAGAD');

      expect(parsed.provider, 'nagad');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 2000.00);
      expect(parsed.balance, 4500.00);
      expect(parsed.transactionId, '71ABCDEF');
      expect(parsed.sender, '01712345678');
    });
  });

  group('Rocket Parsing', () {
    test('parses Rocket Cash In message with 12-digit account', () {
      const String sms =
          'Cash In of Tk. 5,000.00 from 01712345678-9 successful. Fee Tk. 0.00, Balance Tk. 12,345.67. TxnId: 2456789012 on 21-OCT-26 14:15:30';

      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: '16216');

      expect(parsed.provider, 'rocket');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 5000.00);
      expect(parsed.balance, 12345.67);
      expect(parsed.transactionId, '2456789012');
      expect(parsed.sender, '01712345678-9');
    });
  });

  group('Commercial Bank Parsing', () {
    test('parses Bank A/C credit alert', () {
      const String sms =
          'Dear Customer, your A/C ending 1234 has been credited by BDT 25,000.00 on 21-OCT-2026 by NPSB/Fund Transfer. Avail Bal: BDT 80,450.00. Ref: Salary';

      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'CityBank');

      expect(parsed.provider, 'bank');
      expect(parsed.direction, 'credit');
      expect(parsed.amount, 25000.00);
      expect(parsed.balance, 80450.00);
      expect(parsed.accountNumber, '1234');
    });

    test('parses Bank A/C debit alert', () {
      const String sms =
          'A/C ending with 9876 has been debited for BDT 3,500.00 on 22/10/2026 via ATM. Avail Bal: BDT 45,000.00';

      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'DBBL');

      expect(parsed.provider, 'bank');
      expect(parsed.direction, 'debit');
      expect(parsed.amount, 3500.00);
      expect(parsed.balance, 45000.00);
      expect(parsed.accountNumber, '9876');
    });

    test('parses Bank Card POS / purchase alert', () {
      const String sms =
          'Your Card ending 4321 was used for BDT 1,250.00 at UNIMART on 22-OCT-2026. Avail Bal BDT 32,100.00';

      final ParsedTransaction parsed = TransactionParser.parse(sms, fallbackSender: 'EBL');

      expect(parsed.provider, 'bank');
      expect(parsed.direction, 'debit');
      expect(parsed.amount, 1250.00);
      expect(parsed.balance, 32100.00);
      expect(parsed.accountNumber, 'CARD_4321');
    });
  });

  group('Security & Spam Filters', () {
    test('identifies OTP and security verification codes without false positives on words containing otp', () {
      const String otp1 = 'Your bKash verification code is 482910. Do not share this code.';
      const String otp2 = 'Use OTP 129482 to approve transaction of BDT 500 at Merchant.';
      const String normal = 'You have received Tk 500.00 from 01700000000.';
      const String footpath = 'Payment to Footpath Cafe of Tk 250.00 successful. Ref Hotpot.';

      expect(TransactionParser.isSecurityOrOtp(otp1), isTrue);
      expect(TransactionParser.isSecurityOrOtp(otp2), isTrue);
      expect(TransactionParser.isSecurityOrOtp(normal), isFalse);
      expect(TransactionParser.isSecurityOrOtp(footpath), isFalse);
    });

    test('identifies promotional spam and marketing alerts without blocking transactions with cashback', () {
      const String promo = 'Recharge 50 Tk to get 10 Tk cashback! Offer valid today only. Dial *247#';
      const String normal = 'You have received Tk 500.00 from 01700000000.';
      const String trxWithCashback =
          'You have received Tk 200.00 from 01815946458. Ref FEROJ. Fee Tk 0.00. Balance Tk 458.97. TrxID DCI99TCKLX at 18/03/2026 21:29. Enjoy exciting cashback offers!';

      expect(TransactionParser.isPromotionalOrSpam(promo), isTrue);
      expect(TransactionParser.isPromotionalOrSpam(normal), isFalse);
      expect(TransactionParser.isPromotionalOrSpam(trxWithCashback), isFalse);
    });

    test('accurately classifies Send Money as debit', () {
      const String sendMoney =
          'Send Money Tk 500.00 to 01711223344 successful. Fee Tk 5.00. Balance Tk 1,200.00. TrxID 9K20ABC at 21/10/2026 14:30';
      expect(TransactionParser.detectDirection(sendMoney), 'debit');
    });
  });
}
