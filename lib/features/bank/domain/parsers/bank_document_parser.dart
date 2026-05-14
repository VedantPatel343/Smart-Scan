import '../entities/bank_details.dart';

class BankDocumentParser {

  BankDetails parse(String rawText) {
    final normalised = _normaliseOcrText(rawText);
    final lines = _splitLines(normalised);
    final joinedLines = _buildJoinedLines(lines);

    final ifscCode = _extractIfscCode(joinedLines);
    final accountNumber = _extractAccountNumber(joinedLines, ifscCode);
    final bankName = _extractBankName(joinedLines);
    final accountHolderName =
    _extractAccountHolderName(joinedLines, accountNumber, ifscCode, bankName);

    return BankDetails(
      accountHolderName: accountHolderName,
      accountNumber: accountNumber,
      ifscCode: ifscCode,
      bankName: bankName,
    );
  }

  BankDetails parsePassbook(String rawText) => parse(rawText);

  // OCR Normalisation
  String _normaliseOcrText(String text) {
    var result = text
        .replaceAll(RegExp(r'[\u00A0\u2000-\u200B\uFEFF]'), ' ')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"');
    result = result.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return result;
  }

  // Line splitting
  List<String> _splitLines(String text) {
    return text
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  // Label+value line joining
  List<String> _buildJoinedLines(List<String> lines) {
    final result = <String>[];
    for (int i = 0; i < lines.length; i++) {
      result.add(lines[i]);
      if (i + 1 < lines.length) {
        final t = lines[i].trim();
        final next = lines[i + 1].trim();
        // Label-only line: ends with ':', is short (< 40 chars), no digits.
        final endsWithColon = RegExp(r'[A-Za-z\.\)]\s*:\s*$').hasMatch(t);
        if (endsWithColon && t.length < 40 && !RegExp(r'\d').hasMatch(t)) {
          result.add('$t $next');
        } else if (_isBareNameLabelLine(t) &&
            !RegExp(r'\d').hasMatch(next) &&
            next.length >= 3 &&
            next.length < 60) {
          result.add('$t : $next');
        } else if (_isAccountLabelSeekingNextLine(t) &&
            RegExp(r'^\d').hasMatch(next)) {
          result.add('$t $next');
        }
      }
    }
    return result;
  }

  bool _isBareNameLabelLine(String t) {
    final u = t.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
    if (RegExp(r'\d').hasMatch(t) || u.length > 44 || u.contains(':')) {
      return false;
    }
    return u == 'NAME' ||
        u == 'NAME(S)' ||
        u == 'NAMES' ||
        u == 'CUSTOMER NAME' ||
        u == 'ACCOUNT HOLDER' ||
        u == 'A/C HOLDER' ||
        u == 'JOINT HOLDER' ||
        u == 'PRIMARY HOLDER';
  }

  bool _isAccountLabelSeekingNextLine(String t) {
    if (_isBareNameLabelLine(t)) return false;
    if (RegExp(r'\d').hasMatch(t)) return false;
    if (t.length > 52) return false;
    final u = t.toUpperCase();
    return u.contains('ACCOUNT') || u.contains('A/C') || u.contains('A.C');
  }

  // IFSC Code Extraction
  /// RBI IFSC: 4 letters, 0, then 6 alphanumeric. OCR often misreads 5th as O, I, L, |.
  String? _coerceIfscCandidate(String raw) {
    if (raw.length != 11) return null;
    final u = raw.toUpperCase();
    var fifth = u[4];
    if ('OoIlL1|'.contains(fifth)) fifth = '0';
    final s = '${u.substring(0, 4)}$fifth${u.substring(5)}'.toUpperCase();
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(s)) return null;
    return s;
  }

  String? _firstIfscInText(String lineUpper) {
    final mStrict = RegExp(r'\b([A-Z]{4}[O0][A-Z0-9]{6})\b').firstMatch(lineUpper);
    if (mStrict != null) return _coerceIfscCandidate(mStrict.group(1)!);
    final compact = lineUpper.replaceAll(RegExp(r'[\s\-_/|,\.]'), '');
    final loose = RegExp(r'([A-Z]{4}[O0IlL1|][A-Z0-9]{6})');
    for (final m in loose.allMatches(compact)) {
      final c = _coerceIfscCandidate(m.group(1)!);
      if (c != null) return c;
    }
    return null;
  }

  String? _extractIfscCode(List<String> lines) {
    // Pass 1: lines that mention IFSC / branch code (label context).
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('IFSC') ||
          upper.contains('IFS CODE') ||
          upper.contains('IFS:') ||
          upper.contains('IFS ') ||
          upper.contains('BRANCH CODE')) {
        final hit = _firstIfscInText(upper);
        if (hit != null) return hit;
      }
    }
    // Pass 2: compact header blob only when IFSC-related wording exists in the
    // first lines (join catches label on one line + code on the next).
    final headLines = lines.take(36).toList();
    final headText = headLines.join(' ').toUpperCase();
    if (!(headText.contains('IFSC') ||
        headText.contains('IFS ') ||
        headText.contains('IFS:') ||
        headText.contains('IFS CODE') ||
        headText.contains('BRANCH CODE'))) {
      return null;
    }
    final head = headText.replaceAll(RegExp(r'[\s\-_/|,\.]+'), '');
    final loose = RegExp(r'([A-Z]{4}[O0IlL1|][A-Z0-9]{6})');
    for (final m in loose.allMatches(head)) {
      final c = _coerceIfscCandidate(m.group(1)!);
      if (c != null) return c;
    }
    return null;
  }

  // Account Number Extraction
  String? _extractAccountNumber(List<String> lines, String? ifscCode) {
    final inline = RegExp(
      r'(?:a/c|account)\s*(?:no\.?|number|num|#)?\s*[:\.\-]?\s*(\d[\d\s\-\._]{6,26}\d|\d{9,20})',
      caseSensitive: false,
    );

    // Pass 0: label and number on same OCR line.
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (ifscCode != null && upper.contains(ifscCode)) continue;
      final m = inline.firstMatch(line);
      if (m != null) {
        final digits = m.group(1)!.replaceAll(RegExp(r'[\s\-\._]'), '');
        if (RegExp(r'^\d{9,20}$').hasMatch(digits)) return digits;
      }
    }

    // Pass 1: explicit account-number label.
    for (final line in lines) {
      if (_isAccountNumberLabel(line.toUpperCase())) {
        final c = _digitsFromLine(line, min: 9, max: 20);
        if (c != null) return c;
      }
    }

    // Pass 2: line contains 'ACCOUNT' or 'A/C' anywhere.
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('ACCOUNT') || upper.contains('A/C')) {
        if (ifscCode != null && upper.contains(ifscCode)) continue;
        final c = _digitsFromLine(line, min: 9, max: 20);
        if (c != null) return c;
      }
    }

    // Pass 3: strict unlabeled scan (11–20 digits avoids phone/MICR/PIN).
    for (final line in lines) {
      if (ifscCode != null && line.toUpperCase().contains(ifscCode)) continue;
      if (_isPhoneOnlyLine(line)) continue;
      if (_looksLikeTransactionNoise(line)) continue;
      final c = _digitsFromLine(line, min: 11, max: 20);
      if (c != null) return c;
    }
    return null;
  }

  /// Skip passbook transaction rows (date + currency-like amount).
  bool _looksLikeTransactionNoise(String line) {
    final hasDate = RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(line);
    final hasMoney = RegExp(r'(?:Rs\.?|INR|MRP|₹)\s*[\d,.]+', caseSensitive: false).hasMatch(line) ||
        (RegExp(r'\b\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\b').hasMatch(line) &&
            RegExp(r'[.,]\d{2}\b').hasMatch(line));
    return hasDate && hasMoney;
  }

  bool _isAccountNumberLabel(String upper) {
    return RegExp(
      r'\b(ACCOUNT\s*(NO\.?|NUMBER|NUM)\b|ACC\.?\s*NO\.?|A\/C\.?\s*(NO\.?|NUMBER))',
    ).hasMatch(upper);
  }

  bool _isPhoneOnlyLine(String line) {
    final d = line.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(d)) return true;
    if (RegExp(r'^91[6-9]\d{9}$').hasMatch(d)) return true;
    return false;
  }

  String? _digitsFromLine(String line, {required int min, required int max}) {
    final pattern = RegExp(r'\d[\d\s\-\._]{0,26}\d|\d{9,20}');
    final candidates = <String>[];
    for (final m in pattern.allMatches(line)) {
      final raw = m.group(0)!;
      final digits = raw.replaceAll(RegExp(r'[\s\-\._]'), '');
      if (!RegExp(r'^\d+$').hasMatch(digits)) continue;
      if (digits.length < min || digits.length > max) continue;
      if (digits.length == 8 && _isDateLike(digits)) continue;
      if (digits.length == 10 && RegExp(r'^[6-9]').hasMatch(digits)) continue;
      candidates.add(digits);
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.length.compareTo(a.length));
    return candidates.first;
  }

  bool _isDateLike(String d) {
    final day = int.tryParse(d.substring(0, 2)) ?? 0;
    final mon = int.tryParse(d.substring(2, 4)) ?? 0;
    final yr = int.tryParse(d.substring(4)) ?? 0;
    return day >= 1 && day <= 31 && mon >= 1 && mon <= 12 &&
        yr >= 1900 && yr <= 2100;
  }

  // Bank Name Extraction
  static const _bankKeywords = <String, String>{
    'STATE BANK': 'State Bank of India (SBI)',
    'SBI': 'State Bank of India (SBI)',
    'HDFC': 'HDFC Bank',
    'ICICI': 'ICICI Bank',
    'AXIS': 'Axis Bank',
    'KOTAK': 'Kotak Mahindra Bank',
    'PUNJAB NATIONAL': 'Punjab National Bank (PNB)',
    'PNB': 'Punjab National Bank (PNB)',
    'BANK OF BARODA': 'Bank of Baroda (BOB)',
    'BOB': 'Bank of Baroda (BOB)',
    'BANK OF INDIA': 'Bank of India (BOI)',
    'BOI': 'Bank of India (BOI)',
    'CANARA': 'Canara Bank',
    'UNION BANK': 'Union Bank of India',
    'IDBI': 'IDBI Bank',
    'INDUSIND': 'IndusInd Bank',
    'YES BANK': 'Yes Bank',
    'FEDERAL': 'Federal Bank',
    'INDIAN BANK': 'Indian Bank',
    'UCO': 'UCO Bank',
    'CENTRAL BANK': 'Central Bank of India',
    'SYNDICATE': 'Syndicate Bank',
    'VIJAYA': 'Vijaya Bank',
    'DENA': 'Dena Bank',
    'ALLAHABAD': 'Allahabad Bank',
    'ANDHRA': 'Andhra Bank',
    'CORPORATION': 'Corporation Bank',
    'INDIAN OVERSEAS': 'Indian Overseas Bank',
    'IOB': 'Indian Overseas Bank',
    'RBL': 'RBL Bank',
    'DCB': 'DCB Bank',
    'SOUTH INDIAN': 'South Indian Bank',
    'KARNATAKA': 'Karnataka Bank',
    'LAKSHMI VILAS': 'Lakshmi Vilas Bank',
    'NAINITAL': 'Nainital Bank',
    'PAYTM': 'Paytm Payments Bank',
    'FINO': 'Fino Payments Bank',
    'AIRTEL': 'Airtel Payments Bank',
    'JANA': 'Jana Small Finance Bank',
    'AU SMALL': 'AU Small Finance Bank',
    'AU BANK': 'AU Small Finance Bank',
    'EQUITAS': 'Equitas Small Finance Bank',
    'UJJIVAN': 'Ujjivan Small Finance Bank',
    'SURYODAY': 'Suryoday Small Finance Bank',
    'SARASWAT': 'Saraswat Bank',
  };

  String? _extractBankName(List<String> lines) {
    for (final line in lines) {
      final upper = line.toUpperCase();
      for (final entry in _bankKeywords.entries) {
        if (upper.contains(entry.key)) return entry.value;
      }
    }
    return null;
  }

  // Account Holder Name Extraction
  static const _ignoreKeywords = <String>{
    'STATE', 'BANK', 'HDFC', 'ICICI', 'AXIS', 'KOTAK', 'CANARA', 'UNION',
    'PUNJAB', 'NATIONAL', 'FEDERAL', 'INDIAN', 'OVERSEAS', 'SYNDICATE',
    'ALLAHABAD', 'ANDHRA', 'CORPORATION', 'CENTRAL', 'VIJAYA', 'DENA',
    'INDUSIND', 'IDBI', 'PAYTM', 'AIRTEL', 'FINO', 'SBI', 'BOB', 'BOI',
    'PNB', 'IOB', 'RBL', 'DCB', 'UCO', 'YES', 'AU', 'EQUITAS', 'UJJIVAN',
    'MAHINDRA', 'SARASWAT',
    'ACCOUNT', 'NUMBER', 'PASSBOOK', 'SAVINGS', 'CURRENT', 'FIXED',
    'DEPOSIT', 'RECURRING', 'CREDIT', 'DEBIT', 'BRANCH', 'CODE', 'IFSC',
    'MICR', 'DATE', 'BALANCE', 'AMOUNT', 'TRANSACTION', 'PARTICULARS',
    'WITHDRAWAL', 'OPENING', 'CLOSING', 'STATEMENT', 'SLIP', 'CHEQUE',
    'DEMAND', 'DRAFT', 'REFERENCE', 'DESCRIPTION', 'NARRATION', 'MODE',
    'TYPE', 'LIMIT', 'NOMINEE', 'JOINT', 'HOLDER', 'CUSTOMER', 'CIF',
    'PHONE', 'MOBILE', 'EMAIL', 'ADDRESS', 'CITY', 'PIN', 'PINCODE',
    'INDIA', 'SIGNATURE', 'MANAGER', 'AUTHORIZED', 'RESERVE', 'SCHEDULED',
    'COMMERCIAL', 'COOPERATIVE', 'LIMITED', 'LTD', 'INTEREST', 'RATE',
    'PERIOD', 'FROM', 'SERVICE', 'CHARGES', 'PRINT', 'GENERATED',
    'REPORT', 'PAGE', 'MINI', 'UPDATED', 'LAST', 'NEXT', 'PREVIOUS',
    'TOTAL', 'DETAILS', 'INFORMATION', 'SUMMARY', 'LEDGER', 'PREFERRED',
    'CONTACT', 'NOMINATION', 'REGISTERED', 'OPERATIONAL', 'SCHEME',
    'SELF', 'GENERAL', 'OPEN', 'RECO',
  };

  String? _extractAccountHolderName(
      List<String> lines,
      String? accountNumber,
      String? ifscCode,
      String? bankName,
      ) {
    for (final line in lines) {
      if (_isNameLabel(line.toUpperCase())) {
        final name = _extractNameAfterLabel(line);
        if (name != null) return name;
      }
    }

    final honorific = RegExp(
      r'^(?:Mr\.?|Mrs\.?|Ms\.?|Dr\.?|Sri\.?|Smt\.?|Shri\.?|Ku\.?|Prof\.?)\s+(.+)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = honorific.firstMatch(line.trim());
      if (m != null) {
        final name = _cleanName(m.group(1)!);
        if (name != null) return name;
      }
    }

    for (final line in lines) {
      if (accountNumber != null && line.contains(accountNumber)) continue;
      if (ifscCode != null && line.toUpperCase().contains(ifscCode)) continue;
      if (bankName != null &&
          line.toUpperCase().contains(bankName.toUpperCase())) continue;
      if (_looksLikeAddress(line)) continue;
      final name = _tryExtractName(line);
      if (name != null) return name;
    }
    return null;
  }

  /// Matches any name-field label across major Indian bank passbook formats.
  bool _isNameLabel(String upper) {
    return RegExp(
      r'(?:'
      r'NAME\s*\(S\)\s*:'       // Kotak: "Name(s):"
      r'|NAME\s*:'              // BOI: "Name :" / generic "Name:"
      r'|ACCOUNT\s*HOLDER'      // "Account Holder" / "Account Holder Name"
      r'|A\/C\s*HOLDER'         // "A/C Holder"
      r'|ACCOUNT\s*NAME'        // "Account Name"
      r'|CUSTOMER\s*NAME'       // HDFC: "Customer Name"
      r'|DEPOSITOR\s*NAME'
      r'|NAME\s*OF\s*(?:ACCOUNT|DEPOSITOR)'
      r'|PRIMARY\s*HOLDER'
      r'|JOINT\s*HOLDER'
      r')',
    ).hasMatch(upper);
  }

  String? _extractNameAfterLabel(String line) {
    final colonIdx = line.indexOf(':');
    if (colonIdx != -1) {
      final after = _stripNameNoise(line.substring(colonIdx + 1).trim());
      if (after.isNotEmpty) {
        final name = _cleanName(after);
        if (name != null && name.length >= 3) return name;
      }
    }
    // Regex fallback.
    final re = RegExp(
      r'(?:Name\s*\(S\)|Customer\s*Name|Account\s*Holder(?:\s*Name)?|'
      r'A\/C\s*Holder(?:\s*Name)?|Account\s*Name|Depositor(?:\s*Name)?|Name)\s*[:\-]\s*(.+)',
      caseSensitive: false,
    );
    final m = re.firstMatch(line);
    if (m != null) return _cleanName(_stripNameNoise(m.group(1)!));
    return null;
  }

  String _stripNameNoise(String raw) {
    var s = raw.replaceAll(RegExp(r'[*#_|]{1,}'), ' ').trim();
    s = s.replaceAll(RegExp(r'\s+\d{1,4}$'), '');
    s = s.replaceAll(RegExp(r'^\d{1,4}\s+'), '');
    return s.trim();
  }

  bool _looksLikeAddress(String line) {
    if (RegExp(r'\d').hasMatch(line)) return true;
    if (line.contains(',')) return true;
    final upper = line.toUpperCase();
    const addrWords = [
      'ROAD', 'STREET', 'NAGAR', 'COLONY', 'SECTOR', 'PLOT', 'FLAT',
      'FLOOR', 'NEAR', 'BEHIND', 'OPPOSITE', 'DIST', 'DISTRICT', 'TALUK',
      'VILLAGE', 'BLOCK', 'WARD', 'POST', 'OFFICE', 'LANE', 'MARKET',
      'CHOWK', 'MARG', 'VIHAR', 'PRADESH', 'MADHYA',
    ];
    return addrWords.any((w) => upper.contains(w));
  }

  String? _tryExtractName(String line) {
    if (line.length < 4 || line.length > 68) return null;
    if (!RegExp(r"^[A-Za-z][A-Za-z\s\.'’\-]{2,65}$").hasMatch(line)) return null;

    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < 2 || words.length > 6) return null;

    final upperWords =
    words.map((w) => w.toUpperCase().replaceAll('.', '')).toList();

    // Reject if ANY word is an ignore keyword.
    if (upperWords.any((w) => w.length >= 2 && _ignoreKeywords.contains(w))) {
      return null;
    }
    // At least one word must be >= 4 chars.
    if (upperWords.every((w) => w.length < 4)) return null;

    return _cleanName(words.join(' '));
  }

  String? _cleanName(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r"[^\w\s\.'’\-]"), '')
        .trim();
    if (cleaned.length < 3) return null;
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}