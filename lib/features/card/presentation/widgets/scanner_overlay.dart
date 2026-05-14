import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CardScannerOverlay extends StatefulWidget {
  final bool isScanning;
  const CardScannerOverlay({super.key, required this.isScanning});

  @override
  State<CardScannerOverlay> createState() => _CardScannerOverlayState();
}

class _CardScannerOverlayState extends State<CardScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scan;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _scan = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scan,
      builder: (_, __) => CustomPaint(
        painter: _CardOverlayPainter(scanValue: _scan.value, isScanning: widget.isScanning),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CardOverlayPainter extends CustomPainter {
  final double scanValue;
  final bool isScanning;
  const _CardOverlayPainter({required this.scanValue, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final cardW = size.width * 0.85;
    final cardH = cardW * (53.98 / 85.6);
    final left  = (size.width - cardW) / 2;
    final top   = (size.height - cardH) / 2;
    final rect  = Rect.fromLTWH(left, top, cardW, cardH);
    final rr    = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(rr)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withOpacity(0.65),
    );

    final corner = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 3 ..strokeCap = StrokeCap.round ..style = PaintingStyle.stroke;
    const l = 24.0;
    // TL
    canvas.drawLine(Offset(left, top + l), Offset(left, top), corner);
    canvas.drawLine(Offset(left, top), Offset(left + l, top), corner);
    // TR
    canvas.drawLine(Offset(rect.right - l, top), Offset(rect.right, top), corner);
    canvas.drawLine(Offset(rect.right, top), Offset(rect.right, top + l), corner);
    // BL
    canvas.drawLine(Offset(left, rect.bottom - l), Offset(left, rect.bottom), corner);
    canvas.drawLine(Offset(left, rect.bottom), Offset(left + l, rect.bottom), corner);
    // BR
    canvas.drawLine(Offset(rect.right - l, rect.bottom), Offset(rect.right, rect.bottom), corner);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - l), corner);

    if (isScanning) {
      final y = top + cardH * scanValue;
      canvas.drawLine(
        Offset(left, y), Offset(left + cardW, y),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.transparent, AppTheme.primary.withOpacity(0.9),
            AppTheme.secondary, AppTheme.primary.withOpacity(0.9), Colors.transparent,
          ]).createShader(Rect.fromLTWH(left, y, cardW, 2))
          ..strokeWidth = 2 ..style = PaintingStyle.stroke,
      );
      canvas.drawRect(
        Rect.fromLTWH(left, y, cardW, 20),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.primary.withOpacity(0.15), Colors.transparent],
        ).createShader(Rect.fromLTWH(left, y, cardW, 20)),
      );
    }
  }

  @override
  bool shouldRepaint(_CardOverlayPainter o) =>
      o.scanValue != scanValue || o.isScanning != isScanning;
}
