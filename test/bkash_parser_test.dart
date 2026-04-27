import 'package:flutter_test/flutter_test.dart';
import 'package:sms_forwarder_v2/core/services/bkash_parser.dart';

void main() {
  test('parses standard bKash received SMS', () {
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
    expect(parsed.localIso.startsWith('2026-03-18T21:29'), isTrue);
    expect(parsed.utcIso, isNotEmpty);
  });

  test('parses compact variant with BDT token and Reference keyword', () {
    const String sms =
        'Received BDT 350 from +8801815946458. Reference SHOPPAY. Fee BDT 0.00. Balance BDT 1000.00. Transaction ID X7Y8Z9ABCD at 18/03/2026 09:05';

    final ParsedBkashTransaction? parsed = BkashParser.parse(sms);

    expect(parsed, isNotNull);
    expect(parsed!.sender, '01815946458');
    expect(parsed.amount, 350);
    expect(parsed.transactionId, 'X7Y8Z9ABCD');
    expect(parsed.reference, 'SHOPPAY');
    expect(parsed.fee, 0);
    expect(parsed.balance, 1000);
  });
}
