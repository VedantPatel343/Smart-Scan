
class BankDetails {
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;

  const BankDetails({
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
  });

  bool get hasAnyData =>
      accountHolderName != null || accountNumber != null || ifscCode != null;

  bool get isValidPassbookExtract {
    final ac = accountNumber?.replaceAll(RegExp(r'\s'), '') ?? '';
    if (!RegExp(r'^\d{9,20}$').hasMatch(ac)) return false;

    final ifsc = ifscCode?.replaceAll(RegExp(r'\s'), '').toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) return false;

    final name = accountHolderName?.trim() ?? '';
    if (name.length < 3) return false;
    if (RegExp(r'^\d+$').hasMatch(name)) return false;
    return true;
  }

  factory BankDetails.mergeCaptures(Iterable<BankDetails> scans) {
    final list = scans.toList();
    if (list.isEmpty) return const BankDetails();

    int score(BankDetails b) {
      var s = 0;
      if (b.ifscCode != null && b.ifscCode!.replaceAll(RegExp(r'\s'), '').length == 11) {
        s += 4;
      }
      final ac = b.accountNumber?.replaceAll(RegExp(r'\s'), '') ?? '';
      if (RegExp(r'^\d{9,20}$').hasMatch(ac)) s += 4;
      if (b.accountHolderName != null && b.accountHolderName!.trim().length >= 3) {
        s += 2;
      }
      if (b.bankName != null) s += 1;
      return s;
    }

    BankDetails? bestWhere(bool Function(BankDetails) has) {
      BankDetails? pick;
      var bestS = -1;
      for (final b in list) {
        if (!has(b)) continue;
        final sc = score(b);
        if (sc > bestS) {
          bestS = sc;
          pick = b;
        }
      }
      return pick;
    }

    String? modeIfAgreed(List<String> values, int minVotes) {
      if (values.isEmpty) return null;
      final counts = <String, int>{};
      for (final s in values) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
      String? pick;
      var bestV = 0;
      counts.forEach((k, v) {
        if (v >= minVotes && v > bestV) {
          bestV = v;
          pick = k;
        }
      });
      return pick;
    }

    final ifscs = list
        .map((e) => e.ifscCode?.replaceAll(RegExp(r'\s'), '').toUpperCase())
        .whereType<String>()
        .where((s) => s.length == 11)
        .toList();

    final accounts = list
        .map((e) => e.accountNumber?.replaceAll(RegExp(r'\s'), ''))
        .whereType<String>()
        .where((s) => RegExp(r'^\d+$').hasMatch(s) && s.length >= 9 && s.length <= 20)
        .toList();

    final names = list
        .map((e) => e.accountHolderName?.trim().replaceAll(RegExp(r'\s+'), ' '))
        .whereType<String>()
        .where((s) => s.length >= 3)
        .toList();

    final banks = list.map((e) => e.bankName).whereType<String>().toList();

    final mergedIfsc = modeIfAgreed(ifscs, 2) ??
        bestWhere((b) {
          final c = b.ifscCode?.replaceAll(RegExp(r'\s'), '').toUpperCase() ?? '';
          return c.length == 11;
        })?.ifscCode?.replaceAll(RegExp(r'\s'), '').toUpperCase();

    final mergedAccount = modeIfAgreed(accounts, 2) ??
        bestWhere((b) {
          final a = b.accountNumber?.replaceAll(RegExp(r'\s'), '') ?? '';
          return RegExp(r'^\d{9,20}$').hasMatch(a);
        })?.accountNumber?.replaceAll(RegExp(r'\s'), '');

    final mergedName = modeIfAgreed(names, 2) ??
        bestWhere((b) => (b.accountHolderName?.trim().length ?? 0) >= 3)?.accountHolderName?.trim();

    final mergedBank = modeIfAgreed(banks, 2) ?? bestWhere((b) => b.bankName != null)?.bankName;

    return BankDetails(
      ifscCode: mergedIfsc != null && mergedIfsc.length == 11 ? mergedIfsc : null,
      accountNumber: mergedAccount,
      accountHolderName: mergedName,
      bankName: mergedBank,
    );
  }

  String get maskedAccountNumber {
    if (accountNumber == null) return '••••••••••••';
    final digits = accountNumber!.replaceAll(RegExp(r'\s'), '');
    if (digits.length <= 4) return digits;
    final visible = digits.substring(digits.length - 4);
    final masked = '•' * (digits.length - 4);
    return '$masked$visible';
  }

  BankDetails copyWith({
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
  }) {
    return BankDetails(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      bankName: bankName ?? this.bankName,
    );
  }

  @override
  String toString() =>
      'BankDetails(holder: $accountHolderName, account: $maskedAccountNumber, '
      'ifsc: $ifscCode, bank: $bankName)';
}
