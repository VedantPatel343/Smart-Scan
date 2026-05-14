import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scanner/features/card/domain/parsers/card_parser.dart';

/// Technical assignment: Luhn algorithm — at least one test; here we cover
/// valid PAN, bad check digit, bad BIN, and spacing edge cases.
void main() {
  group('CardParser.isValidCard (manual Luhn + BIN)', () {
    test('accepts standard test Visa number with valid Luhn', () {
      expect(CardParser.isValidCard('4111111111111111'), isTrue);
    });

    test('rejects same length with wrong Luhn check digit', () {
      expect(CardParser.isValidCard('4111111111111112'), isFalse);
    });

    test('rejects PAN whose first digit is outside 2–6', () {
      expect(CardParser.isValidCard('1111111111111111'), isFalse);
    });

    test('accepts grouped format with spaces', () {
      expect(CardParser.isValidCard('4111 1111 1111 1111'), isTrue);
    });

    test('rejects too-short digit string', () {
      expect(CardParser.isValidCard('411111111111'), isFalse);
    });
  });
}
