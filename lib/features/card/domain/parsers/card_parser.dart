import 'dart:math' show max, min;

import '../entities/card_details.dart';

class CardParser {
  static bool _binValid(String d) {
    final f = int.tryParse(d.isEmpty ? '' : d[0]) ?? -1;
    return f >= 2 && f <= 6;
  }

  static bool _luhnValid(String n) {
    if (n.length < 13 || n.length > 19) return false;
    if (!RegExp(r'^\d+$').hasMatch(n)) return false;
    var sum = 0;
    var alt = false;
    for (var i = n.length - 1; i >= 0; i--) {
      var d = int.parse(n[i]);
      if (alt) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      alt = !alt;
    }
    return sum % 10 == 0;
  }

  /// Manual Luhn validation on a card PAN (digits only after stripping spaces).
  static bool isValidCard(String cardNumber) {
    final d = cardNumber.replaceAll(RegExp(r'\s'), '');
    if (!_binValid(d)) return false;
    return _luhnValid(d);
  }

  CardDetails parse(String rawText) {
    final lines = _splitLines(rawText);
    final cardNumber = _extractCardNumber(lines);
    final expiryDate = _extractExpiryDate(lines);
    final cardHolderName = _extractCardHolderName(lines, cardNumber, expiryDate);
    return CardDetails(cardNumber: cardNumber, expiryDate: expiryDate, cardHolderName: cardHolderName);
  }

  static CardDetails mergeCaptures(List<CardDetails> scans) {
    if (scans.isEmpty) return const CardDetails();

    String? expiry;
    String? name;
    for (final s in scans) {
      expiry ??= s.expiryDate;
      name ??= s.cardHolderName;
    }

    final pans = scans
        .map((e) => e.cardNumber?.replaceAll(RegExp(r'\s'), ''))
        .whereType<String>()
        .where((d) => d.length >= 13 && d.length <= 19 && RegExp(r'^\d+$').hasMatch(d))
        .toList();

    String? panFormatted;
    if (pans.isNotEmpty) {
      final merged = _mergePanDigitsWithMajority(pans);
      if (merged != null) {
        panFormatted = _formatPanDigits(merged);
      } else {
        for (final p in pans) {
          final r = _tryRepairLuhn(p);
          if (r != null) {
            panFormatted = _formatPanDigits(r);
            break;
          }
        }
      }
    }

    return CardDetails(cardNumber: panFormatted, expiryDate: expiry, cardHolderName: name);
  }

  static String _formatPanDigits(String d) {
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(d[i]);
    }
    return b.toString();
  }

  static String? _mergePanDigitsWithMajority(List<String> pans) {
    final byLen = <int, List<String>>{};
    for (final p in pans) {
      byLen.putIfAbsent(p.length, () => []).add(p);
    }
    var bestLen = 0;
    var bestCount = 0;
    byLen.forEach((len, list) {
      final c = list.length;
      if (c > bestCount || (c == bestCount && len == 16 && bestLen != 16)) {
        bestCount = c;
        bestLen = len;
      }
    });
    final group = byLen[bestLen] ?? pans;
    if (group.length == 1) {
      final s = group.first;
      if (_binValid(s) && _luhnValid(s)) return s;
      return _tryRepairLuhn(s);
    }

    final buf = StringBuffer();
    for (var i = 0; i < bestLen; i++) {
      final counts = List.filled(10, 0);
      for (final p in group) {
        final d = int.tryParse(p[i]);
        if (d != null) counts[d]++;
      }
      final bestDigit = counts.indexOf(counts.reduce(max));
      buf.write(bestDigit);
    }
    final s = buf.toString();
    if (_binValid(s) && _luhnValid(s)) return s;
    return _tryRepairLuhn(s);
  }

  /// If [digits] fails Luhn (common with one OCR error), try every single-digit fix.
  static String? _tryRepairLuhn(String digits) {
    if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
    if (digits.length < 13 || digits.length > 19) return null;
    if (_binValid(digits) && _luhnValid(digits)) return digits;

    if (digits.length == 17) {
      for (var skip = 0; skip < 17; skip++) {
        final sub = digits.substring(0, skip) + digits.substring(skip + 1);
        final r = _repairFixedLength(sub);
        if (r != null) return r;
      }
    }

    return _repairFixedLength(digits);
  }

  static String? _repairFixedLength(String digits) {
    final len = digits.length;
    if (len < 13 || len > 19) return null;
    if (_binValid(digits) && _luhnValid(digits)) return digits;
    for (var i = 0; i < len; i++) {
      for (var d = 0; d <= 9; d++) {
        final c = '${digits.substring(0, i)}$d${digits.substring(i + 1)}';
        if (_binValid(c) && _luhnValid(c)) return c;
      }
    }
    return null;
  }

  List<String> _splitLines(String text) =>
      text.split(RegExp(r'[\n\r]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  String _ocrCorrectIfDigitLine(String line) {
    final ns = line.replaceAll(' ', '');
    if (ns.isEmpty) return line;
    final count = RegExp(r'[0-9OoIiLlSsBbGgZz]').allMatches(ns).length;
    if (count / ns.length < 0.4) return line;
    return line
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('I', '1')
        .replaceAll('i', '1')
        .replaceAll('L', '1')
        .replaceAll('l', '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('G', '6')
        .replaceAll('Z', '2')
        .replaceAll('z', '2');
  }

  String _normalizeCardLine(String raw) {
    var s = raw.replaceAll(RegExp(r'[\u00A0\u2000-\u200B\uFEFF]'), ' ');
    s = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  Iterable<String> _cardNumberHaystacks(List<String> lines) sync* {
    for (final raw in lines) {
      final n = _normalizeCardLine(raw);
      if (n.isNotEmpty) yield n;
    }
    for (var i = 0; i < lines.length - 1; i++) {
      final n = _normalizeCardLine('${lines[i]} ${lines[i + 1]}');
      if (n.isNotEmpty) yield n;
    }
    for (var i = 0; i < lines.length - 2; i++) {
      final n = _normalizeCardLine('${lines[i]} ${lines[i + 1]} ${lines[i + 2]}');
      if (n.isNotEmpty) yield n;
    }
  }

  String? _ocrConfusedCharToDigit(String ch) {
    switch (ch) {
      case '0':
      case 'O':
      case 'o':
        return '0';
      case '1':
      case 'I':
      case 'i':
      case 'l':
      case 'L':
      case '|':
        return '1';
      case '2':
      case 'Z':
      case 'z':
        return '2';
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
        return ch;
      case 'S':
      case 's':
        return '5';
      case 'B':
        return '8';
      case 'G':
      case 'g':
        return '6';
      default:
        return null;
    }
  }

  static final _ocrPanChunk = RegExp(
    r'([0-9OoIiLlSsBbGgZz|](?:[\s\-\._]*[0-9OoIiLlSsBbGgZz|]){12,18})',
    caseSensitive: false,
  );

  String? _panFromDigitRun(String corrected) {
    for (final m in _ocrPanChunk.allMatches(corrected)) {
      final chunk = m.group(1)!;
      final b = StringBuffer();
      var invalid = false;
      for (var i = 0; i < chunk.length; i++) {
        final ch = chunk[i];
        if (RegExp(r'[\s\-\._]').hasMatch(ch)) continue;
        final d = _ocrConfusedCharToDigit(ch);
        if (d == null) {
          invalid = true;
          break;
        }
        b.write(d);
      }
      if (invalid) continue;
      final mapped = b.toString();
      if (mapped.length < 13) continue;
      for (var len = min(19, mapped.length); len >= 13; len--) {
        for (var i = 0; i + len <= mapped.length; i++) {
          final c = mapped.substring(i, i + len);
          if (_binValid(c) && _luhnValid(c)) return c;
          if (len == 16 && _binValid(c)) {
            final repaired = CardParser._tryRepairLuhn(c);
            if (repaired != null) return repaired;
          }
        }
      }
    }

    final digits = corrected.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 13) return null;
    for (var len = 19; len >= 13; len--) {
      for (var i = 0; i + len <= digits.length; i++) {
        final c = digits.substring(i, i + len);
        if (_binValid(c) && _luhnValid(c)) return c;
        if (len == 16 && _binValid(c)) {
          final repaired = CardParser._tryRepairLuhn(c);
          if (repaired != null) return repaired;
        }
      }
    }
    return null;
  }

  String? _extractCardNumber(List<String> lines) {
    final grouped = RegExp(
      r'(?<!\d)(\d{4})[\s\-\._]+(\d{4})[\s\-\._]+(\d{4})[\s\-\._]+(\d{1,4})(?!\d)',
    );
    final plain = RegExp(r'(?<!\d)\d{13,19}(?!\d)');

    for (final hay in _cardNumberHaystacks(lines)) {
      final line = _ocrCorrectIfDigitLine(hay);

      final gm = grouped.firstMatch(line);
      if (gm != null) {
        final c = '${gm.group(1)}${gm.group(2)}${gm.group(3)}${gm.group(4)}';
        if (_binValid(c) && _luhnValid(c)) return _formatCardNumber(c);
        final r = CardParser._tryRepairLuhn(c);
        if (r != null) return _formatCardNumber(r);
      }

      for (final pm in plain.allMatches(line)) {
        final c = pm.group(0)!;
        if (_binValid(c) && _luhnValid(c)) return _formatCardNumber(c);
        final r = CardParser._tryRepairLuhn(c);
        if (r != null) return _formatCardNumber(r);
      }

      final fromRun = _panFromDigitRun(line);
      if (fromRun != null) return _formatCardNumber(fromRun);
    }
    return null;
  }

  String _formatCardNumber(String d) => CardParser._formatPanDigits(d);

  String? _extractExpiryDate(List<String> lines) {
    final patterns = [
      RegExp(r'(?<!\d)(0[1-9]|1[0-2])\/(2[0-9]|20[2-9][0-9])(?!\d)'),
      RegExp(r'(?<!\d)(0[1-9]|1[0-2])\-(2[0-9]|20[2-9][0-9])(?!\d)'),
    ];
    for (final line in lines) {
      for (final p in patterns) {
        final m = p.firstMatch(line);
        if (m != null) {
          final month = m.group(1)!;
          final raw = m.group(2)!;
          final year = raw.length == 4 ? raw.substring(2) : raw;
          if (_isExpiryPlausible(month, year)) return '$month/$year';
        }
      }
    }
    return null;
  }

  bool _isExpiryPlausible(String mm, String yy) {
    final now = DateTime.now();
    final month = int.tryParse(mm);
    final year = int.tryParse(yy);
    if (month == null || year == null) return false;
    final fy = year + 2000;
    if (fy < now.year) return false;
    if (fy == now.year && month < now.month) return false;
    return true;
  }

  String? _extractCardHolderName(List<String> lines, String? cardNumber, String? expiryDate) {
    const ignore = {
      'VISA', 'MASTERCARD', 'MASTER', 'AMEX', 'RUPAY', 'DISCOVER',
      'CREDIT', 'DEBIT', 'CARD', 'BANK', 'VALID', 'THRU', 'GOOD',
      'MEMBER', 'SINCE', 'EXPIRY', 'DATE', 'CVV', 'CVC', 'EXPIRES',
      'MONTH', 'YEAR', 'MONTHYEAR', 'HDFC', 'ICICI', 'AXIS', 'KOTAK',
      'SBI', 'PNB', 'BOI', 'BOB', 'UNION', 'FEDERAL', 'INDUSIND', 'YES',
      'CITI', 'CITIBANK', 'STATE', 'INDIA', 'PLATINUM', 'GOLD', 'CLASSIC',
      'SIGNATURE', 'INTERNATIONAL', 'WORLD', 'REWARDS',
    };
    final cardDigits = cardNumber?.replaceAll(' ', '') ?? '';
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (RegExp(r'\d').hasMatch(t)) continue;
      if (expiryDate != null && t.contains(expiryDate)) continue;
      if (cardDigits.isNotEmpty && t.replaceAll(' ', '').contains(cardDigits)) continue;
      if (!RegExp(r"^[A-Z][A-Z\s.\-']{3,35}$").hasMatch(t)) continue;
      final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final nameWords = words
          .where((w) => !ignore.contains(w))
          .where((w) => RegExp(r"^[A-Z][A-Z.\-']*$").hasMatch(w) && w.length >= 2)
          .toList();
      if (nameWords.isEmpty) continue;
      if (nameWords.length < 2 && nameWords[0].length < 5) continue;
      return nameWords.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
    }
    return null;
  }
}
