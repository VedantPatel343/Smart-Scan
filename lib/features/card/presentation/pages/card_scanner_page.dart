import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/card_details.dart';
import '../controllers/card_scanner_controller.dart';
import '../widgets/card_display_widget.dart';
import '../widgets/scanner_overlay.dart';

class CardScannerPage extends StatefulWidget {
  const CardScannerPage({super.key});

  @override
  State<CardScannerPage> createState() => _CardScannerPageState();
}

class _CardScannerPageState extends State<CardScannerPage> {
  late final CardScannerController _ctrl;
  bool _resultPopped = false;

  @override
  void initState() {
    super.initState();
    _ctrl = CardScannerController();
    _ctrl.addListener(_onState);
    _ctrl.initialize();
  }

  @override
  void dispose() { _ctrl.removeListener(_onState); _ctrl.dispose(); super.dispose(); }

  void _onState() {
    if (!mounted) return;
    setState(() {});
    if (_ctrl.state == ScannerState.result && !_resultPopped) {
      _resultPopped = true;
      _showResult(_ctrl.cardDetails!);
    }
  }

  void _showResult(CardDetails card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardResultSheet(
        card: card,
        onScanAgain: () { Navigator.pop(context); _resultPopped = false; _ctrl.reset(); },
        onDone: () { Navigator.pop(context); Navigator.pop(context, card); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Scan Card',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          if (_ctrl.state == ScannerState.ready ||
              (_ctrl.state == ScannerState.scanning && _ctrl.previewImagePath == null))
            IconButton(
              icon: Icon(_ctrl.torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
              onPressed: _ctrl.toggleTorch,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    switch (_ctrl.state) {
      case ScannerState.idle:
      case ScannerState.requestingPermission:
      case ScannerState.initializing:
        return _loading('Initializing camera…');
      case ScannerState.permissionDenied:
        return _permissionDenied();
      case ScannerState.error:
        return _error(_ctrl.errorMessage ?? 'Unknown error');
      case ScannerState.ready:
      case ScannerState.result:
        return _cameraView();
      case ScannerState.preview:
        return _previewPanel(isProcessing: false);
      case ScannerState.scanning:
        if (_ctrl.previewImagePath != null) {
          return _previewPanel(isProcessing: true);
        }
        return _cameraView();
    }
  }

  Widget _previewPanel({required bool isProcessing}) {
    final path = _ctrl.previewImagePath;
    if (path == null) return _cameraView();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isProcessing ? null : _ctrl.processPreviewImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text('Show Result', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: isProcessing ? null : _ctrl.discardPreview,
              child: Text('Retake', style: GoogleFonts.inter(color: Colors.white70, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraView() {
    final cam = _ctrl.service.cameraController;
    if (cam == null || !cam.value.isInitialized) return _loading('Starting camera…');
    return Stack(fit: StackFit.expand, children: [
      CameraPreview(cam),
      CardScannerOverlay(
        isScanning: _ctrl.state == ScannerState.scanning && _ctrl.previewImagePath == null,
      ),
      Positioned(
        bottom: 130, left: 24, right: 24,
        child: Column(children: [
          if (_ctrl.errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_ctrl.errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13)),
            ),
          Text(
            _ctrl.state == ScannerState.scanning
                ? 'Capturing…'
                : 'Align card in the frame and tap Scan',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildFab() {
    final s = _ctrl.state;
    if (s == ScannerState.preview) return const SizedBox.shrink();
    if (s != ScannerState.ready && s != ScannerState.scanning) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: s == ScannerState.ready ? _ctrl.captureForPreview : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.brandGradient,
            boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
          ),
          child: s == ScannerState.scanning
              ? const Padding(padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _loading(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(color: AppTheme.primary),
    const SizedBox(height: 20),
    Text(msg, style: GoogleFonts.inter(color: Colors.white60, fontSize: 14)),
  ]));

  Widget _permissionDenied() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.camera_alt_outlined, color: Colors.white30, size: 80),
      const SizedBox(height: 24),
      Text('Camera Permission Required', textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Text(_ctrl.errorMessage ?? '', textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 14)),
      const SizedBox(height: 28),
      ElevatedButton.icon(onPressed: _ctrl.initialize,
          icon: const Icon(Icons.settings), label: const Text('Open Settings')),
    ],
  )));

  Widget _error(String msg) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.error_outline, color: Colors.redAccent, size: 72),
      const SizedBox(height: 20),
      Text('Something went wrong', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Text(msg, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 24),
      ElevatedButton(onPressed: _ctrl.initialize, child: const Text('Retry')),
    ],
  )));
}

// ── Card Result Bottom Sheet ─────────────────────────────────────────────────

class _CardResultSheet extends StatelessWidget {
  final CardDetails card;
  final VoidCallback onScanAgain;
  final VoidCallback onDone;
  const _CardResultSheet({required this.card, required this.onScanAgain, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        _successBadge(),
        const SizedBox(height: 20),
        CardDisplayWidget(card: card),
        const SizedBox(height: 24),
        _infoTile(context, Icons.credit_card, 'Card Number', card.maskedCardNumber),
        if (card.expiryDate != null)
          _infoTile(context, Icons.date_range, 'Expiry Date', card.expiryDate!),
        if (card.cardHolderName != null)
          _infoTile(context, Icons.person, 'Card Holder', card.cardHolderName!),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: onScanAgain, child: const Text('Scan Again'))),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: onDone, child: const Text('Done'))),
        ]),
      ]),
    );
  }

  Widget _successBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.secondary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: AppTheme.secondary, size: 18),
      const SizedBox(width: 8),
      Text('Card Scanned Successfully',
          style: GoogleFonts.inter(color: AppTheme.secondary, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _infoTile(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white70, size: 18)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}
