import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scanner/features/bank/domain/entities/bank_details.dart';
import 'package:smart_scanner/features/bank/domain/parsers/bank_document_parser.dart';

/// Technical assignment: Passbook parser — IFSC, account among many numbers, name.
void main() {
  final parser = BankDocumentParser();

  group('BankDocumentParser.parsePassbook', () {
    test('extracts IFSC, account number, and holder from typical OCR block', () {
      const raw = '''
STATE BANK OF INDIA
Account Holder Name : RAMESH KUMAR SHARMA
Account Number : 30245678912
IFSC Code : SBIN0001234
Branch : MAIN BRANCH
''';
      final d = parser.parsePassbook(raw);
      expect(d.ifscCode, 'SBIN0001234');
      expect(d.accountNumber, '30245678912');
      expect(d.accountHolderName, isNotNull);
      expect(d.accountHolderName!.toLowerCase(), contains('ramesh'));
    });

    test('picks labelled account among multiple numeric lines', () {
      const raw = '''
Phone 9876543210
IFSC HDFC0000999
Account Number : 50100123456789
Txn ID 1209384756
Balance 1000.00
''';
      final d = parser.parsePassbook(raw);
      expect(d.accountNumber, '50100123456789');
      expect(d.ifscCode, 'HDFC0000999');
    });

    test('parsePassbook alias matches parse', () {
      const raw = 'IFSC : ICIC0000101\nA/c No 1234567890\nName : AMIT PATEL';
      expect(
        parser.parsePassbook(raw).accountNumber,
        parser.parse(raw).accountNumber,
      );
    });
  });

  group('BankDetails.isValidPassbookExtract', () {
    test('true when all three core fields are well-formed', () {
      const d = BankDetails(
        accountNumber: '30245678912',
        ifscCode: 'SBIN0001234',
        accountHolderName: 'Ramesh Kumar',
      );
      expect(d.isValidPassbookExtract, isTrue);
    });

    test('false when fifth IFSC character is not 0 (RBI layout)', () {
      const d = BankDetails(
        accountNumber: '30245678912',
        ifscCode: 'SBIN1001234',
        accountHolderName: 'Ramesh Kumar',
      );
      expect(d.isValidPassbookExtract, isFalse);
    });

    test('false when account number too short', () {
      const d = BankDetails(
        accountNumber: '12345678',
        ifscCode: 'SBIN0001234',
        accountHolderName: 'Ramesh Kumar',
      );
      expect(d.isValidPassbookExtract, isFalse);
    });

    test('false when name is digits only', () {
      const d = BankDetails(
        accountNumber: '30245678912',
        ifscCode: 'SBIN0001234',
        accountHolderName: '12345',
      );
      expect(d.isValidPassbookExtract, isFalse);
    });
  });
}
