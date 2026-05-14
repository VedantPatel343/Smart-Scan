import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class BankScannerOverlay extends StatefulWidget {
  final bool isScanning;
  const BankScannerOverlay({super.key, required this.isScanning});

  @override
  State<BankScannerOverlay> createState() => _BankScannerOverlayState();
}

class _BankScannerOverlayState extends State<BankScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => CustomPaint(
        painter: _BankOverlayPainter(
            progress: widget.isScanning ? _anim.value : null),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BankOverlayPainter extends CustomPainter {
  final double? progress;
  const _BankOverlayPainter({this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Tall frame in portrait: most of the screen height so name / IFSC / account
    // blocks on a vertical passbook page stay inside the guide.
    final hPad = size.width * 0.035;
    final bandH = size.height * 0.62;
    final top = size.height * 0.10;
    final rect = Rect.fromLTWH(hPad, top, size.width - 2 * hPad, bandH);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(rr)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withOpacity(0.56),
    );

    final corner = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 3.5 ..strokeCap = StrokeCap.round ..style = PaintingStyle.stroke;
    const l = 28.0;
    canvas.drawLine(Offset(rect.left, rect.top + l), Offset(rect.left, rect.top), corner);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + l, rect.top), corner);
    canvas.drawLine(Offset(rect.right - l, rect.top), Offset(rect.right, rect.top), corner);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + l), corner);
    canvas.drawLine(Offset(rect.left, rect.bottom - l), Offset(rect.left, rect.bottom), corner);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + l, rect.bottom), corner);
    canvas.drawLine(Offset(rect.right - l, rect.bottom), Offset(rect.right, rect.bottom), corner);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - l), corner);

    if (progress != null) {
      final y = rect.top + rect.height * progress!;
      canvas.drawLine(
        Offset(rect.left + 8, y), Offset(rect.right - 8, y),
        Paint()
          ..shader = LinearGradient(colors: [
            Colors.transparent, AppTheme.accent.withOpacity(0.9), Colors.transparent,
          ]).createShader(Rect.fromLTRB(rect.left, y, rect.right, y + 2))
          ..strokeWidth = 2,
      );
      canvas.drawRect(
        Rect.fromLTRB(rect.left + 8, y, rect.right - 8, math.min(y + 40, rect.bottom)),
        Paint()..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.accent.withOpacity(0.15), Colors.transparent],
        ).createShader(Rect.fromLTRB(rect.left, y, rect.right, y + 40)),
      );
    }
  }

  @override
  bool shouldRepaint(_BankOverlayPainter o) => o.progress != progress;
}
