import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/card_details.dart';

class CardDisplayWidget extends StatefulWidget {
  final CardDetails card;
  const CardDisplayWidget({super.key, required this.card});

  @override
  State<CardDisplayWidget> createState() => _CardDisplayWidgetState();
}

class _CardDisplayWidgetState extends State<CardDisplayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale, _fade;
  bool _showFull = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: _buildCard()),
    );
  }

  Widget _buildCard() {
    final card = widget.card;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A2C8C), Color(0xFF6C63FF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.45), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: Stack(children: [
        Positioned(right: -30, top: -30,
          child: Container(width: 160, height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.07)))),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [_chip()]),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _showFull = !_showFull),
              child: Text(
                _showFull ? (card.cardNumber ?? 'XXXX XXXX XXXX XXXX') : card.maskedCardNumber,
                style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w600, letterSpacing: 3),
              ),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _cardField('CARD HOLDER', card.cardHolderName ?? '—'),
              _cardFieldRight('VALID THRU', card.expiryDate ?? 'MM/YY'),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _chip() => Container(
    width: 44, height: 32,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const LinearGradient(colors: [Color(0xFFE8C97C), Color(0xFFC9A84C)]),
    ),
  );

  Widget _cardField(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ],
  );

  Widget _cardFieldRight(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(label, style: GoogleFonts.inter(color: Colors.white54, fontSize: 9, letterSpacing: 1.5)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ],
  );
}
