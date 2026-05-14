class CardDetails {
  final String? cardNumber;
  final String? expiryDate;
  final String? cardHolderName;

  const CardDetails({this.cardNumber, this.expiryDate, this.cardHolderName});

  bool get hasAnyData =>
      cardNumber != null || expiryDate != null || cardHolderName != null;

  String get maskedCardNumber {
    if (cardNumber == null || cardNumber!.isEmpty) return 'XXXX XXXX XXXX XXXX';
    final digits = cardNumber!.replaceAll(RegExp(r'\s'), '');
    if (digits.length < 4) return 'XXXX XXXX XXXX ${digits.padLeft(4, 'X')}';
    return 'XXXX XXXX XXXX ${digits.substring(digits.length - 4)}';
  }

  CardDetails copyWith({String? cardNumber, String? expiryDate, String? cardHolderName}) =>
      CardDetails(
        cardNumber: cardNumber ?? this.cardNumber,
        expiryDate: expiryDate ?? this.expiryDate,
        cardHolderName: cardHolderName ?? this.cardHolderName,
      );
}
