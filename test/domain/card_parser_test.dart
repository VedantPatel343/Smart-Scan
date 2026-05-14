import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scanner/features/card/domain/parsers/card_parser.dart';

/// Technical assignment: Card parser — formats, spacing, expiry, noisy OCR.
void main() {
  final parser = CardParser();

  group('CardParser.parse', () {
    test('extracts grouped PAN, expiry MM/YY, and holder name', () {
      const raw = '''
HDFC BANK
JANE Q PUBLIC
4111  1111  1111  1111
VALID THRU 09/28
''';
      final d = parser.parse(raw);
      expect(d.cardNumber, isNotNull);
      expect(d.cardNumber!.replaceAll(' ', ''), '4111111111111111');
      expect(d.expiryDate, '09/28');
      expect(d.cardHolderName, isNotNull);
      expect(d.cardHolderName!.toLowerCase(), contains('jane'));
    });

    test('parses expiry with hyphen form', () {
      const raw = '5412 7512 3412 3456\n12-29';
      final d = parser.parse(raw);
      expect(d.expiryDate, '12/29');
    });

    test('handles double spaces between PAN groups', () {
      const raw = '4111  1111  1111  1111';
      final d = parser.parse(raw);
      expect(d.cardNumber, isNotNull);
      expect(d.cardNumber!.replaceAll(' ', ''), '4111111111111111');
    });

    test('returns null card number when no valid Luhn PAN present', () {
      const raw = 'Random receipt\nTotal 42.00\nRef 999888777';
      final d = parser.parse(raw);
      expect(d.cardNumber, isNull);
    });
  });
}
