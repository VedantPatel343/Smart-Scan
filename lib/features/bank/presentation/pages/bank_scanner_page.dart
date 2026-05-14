import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/bank_details.dart';
import '../controllers/bank_scanner_controller.dart';
import '../widgets/bank_details_card.dart';
import '../widgets/scanner_overlay.dart';

class BankScannerPage extends StatefulWidget {
  final bool startWithGallery;
  const BankScannerPage({super.key, this.startWithGallery = false});

  @override
  State<BankScannerPage> createState() => _BankScannerPageState();
}

class _BankScannerPageState extends State<BankScannerPage> {
  late final BankScannerController _ctrl;
  bool _resultShown = false;
  String? _lastSnackError;

  @override
  void initState() {
    super.initState();
    _ctrl = BankScannerController();
    _ctrl.addListener(_onState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.startWithGallery) {
        _ctrl.pickFromGalleryForPreview();
      } else {
        _ctrl.initialize();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onState);
    _ctrl.dispose();
    super.dispose();
  }

  void _onState() {
    if (!mounted) return;
    if (_ctrl.state == ScannerState.scanning) {
      _lastSnackError = null;
    }
    final err = _ctrl.errorMessage;
    if (err != null &&
        err.isNotEmpty &&
        err != _lastSnackError &&
        _ctrl.state == ScannerState.ready) {
      _lastSnackError = err;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text(err, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: Colors.red.shade900,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }
    if (err == null) _lastSnackError = null;

    setState(() {});
    if (_ctrl.state == ScannerState.result && !_resultShown) {
      _resultShown = true;
      _showResult(_ctrl.bankDetails!);
    }
  }

  void _showResult(BankDetails details) {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BankResultSheet(
        details: details,
        onScanAgain: () {
          Navigator.pop(sheetContext);
          _resultShown = false;
          _ctrl.reset();
        },
        onDone: () {
          Navigator.pop(sheetContext);
          Navigator.pop(context, details);
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
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
        title: Text('Scan Passbook',
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
                  backgroundColor: AppTheme.accent,
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
    final camReady = cam != null && cam.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (camReady)
          CameraPreview(cam)
        else
          Container(color: Colors.black),
        if (camReady)
          BankScannerOverlay(
            isScanning: _ctrl.state == ScannerState.scanning && _ctrl.previewImagePath == null,
          ),
        Positioned(
          bottom: 140,
          left: 24,
          right: 24,
          child: Column(
            children: [
              Text(
                _ctrl.state == ScannerState.scanning
                    ? 'Capturing…'
                    : camReady
                        ? 'Hold phone upright — fit the passbook inside the large frame'
                        : 'Pick an image or open camera from home to scan',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFab() {
    final s = _ctrl.state;
    if (s == ScannerState.preview) return const SizedBox.shrink();
    if (s != ScannerState.ready && s != ScannerState.scanning) return const SizedBox.shrink();
    final isReady = s == ScannerState.ready;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _circleBtn(Icons.photo_library_rounded, isReady ? _ctrl.pickFromGalleryForPreview : null),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: isReady ? _ctrl.captureForPreview : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
            ),
            child: s == ScannerState.scanning
                ? const Padding(padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(width: 32),
        _circleBtn(isReady && _ctrl.torchOn ? Icons.flash_on : Icons.flash_off,
            isReady ? _ctrl.toggleTorch : null),
      ]),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    ),
  );

  Widget _loading(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(color: AppTheme.accent),
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
          icon: const Icon(Icons.settings), label: const Text('Open Settings'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent)),
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
      ElevatedButton(onPressed: _ctrl.initialize, child: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent)),
    ],
  )));
}

// ── Bank Result Bottom Sheet ─────────────────────────────────────────────────

class _BankResultSheet extends StatelessWidget {
  final BankDetails details;
  final VoidCallback onScanAgain;
  final VoidCallback onDone;
  const _BankResultSheet({required this.details, required this.onScanAgain, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              _badge(),
              const SizedBox(height: 20),
              BankDetailsCard(details: details),
              const SizedBox(height: 24),
              if (details.accountHolderName != null) _row(context, Icons.person, 'Account Holder', details.accountHolderName!),
              if (details.accountNumber != null)     _row(context, Icons.account_balance_wallet, 'Account Number', details.accountNumber!),
              if (details.ifscCode != null)          _row(context, Icons.code, 'IFSC Code', details.ifscCode!),
              if (details.bankName != null)          _row(context, Icons.account_balance, 'Bank Name', details.bankName!),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: onScanAgain, child: const Text('Scan Again'))),
                const SizedBox(width: 16),
                Expanded(child: ElevatedButton(onPressed: onDone, child: const Text('Done'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _badge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: AppTheme.secondary, size: 18),
      const SizedBox(width: 8),
      Text('Document Scanned Successfully',
          style: GoogleFonts.inter(color: AppTheme.secondary, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$label copied'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              backgroundColor: AppTheme.bgSurface,
            ));
          },
          icon: const Icon(Icons.copy_rounded, color: Colors.white24, size: 18),
        ),
      ]),
    );
  }
}
