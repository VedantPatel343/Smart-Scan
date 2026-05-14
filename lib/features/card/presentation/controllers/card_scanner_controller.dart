import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/card_scanner_service.dart';
import '../../domain/entities/card_details.dart';

enum ScannerState { idle, requestingPermission, permissionDenied, initializing, ready, preview, scanning, result, error }

class CardScannerController extends ChangeNotifier {
  final CardScannerService _service = CardScannerService();

  ScannerState _state = ScannerState.idle;
  CardDetails?  _cardDetails;
  String?       _errorMessage;
  bool          _torchOn = false;
  String?       _previewImagePath;

  ScannerState  get state        => _state;
  CardDetails?  get cardDetails  => _cardDetails;
  String?       get errorMessage => _errorMessage;
  bool          get torchOn      => _torchOn;
  String?       get previewImagePath => _previewImagePath;
  CardScannerService get service => _service;

  Future<void> initialize() async {
    _setState(ScannerState.requestingPermission);
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _errorMessage = status.isPermanentlyDenied
          ? 'Camera permission permanently denied. Enable it in Settings.'
          : 'Camera permission is required to scan cards.';
      _setState(ScannerState.permissionDenied); return;
    }
    _setState(ScannerState.initializing);
    try {
      await _service.initCamera();
      _setState(ScannerState.ready);
    } catch (e) {
      _errorMessage = 'Failed to initialize camera: $e';
      _setState(ScannerState.error);
    }
  }

  @override
  Future<void> dispose() async {
    await _service.dispose();
    super.dispose();
  }

  /// Capture one frame for preview; OCR runs after [processPreviewImage].
  Future<void> captureForPreview() async {
    if (_state != ScannerState.ready) return;
    _errorMessage = null;
    _previewImagePath = null;
    _setState(ScannerState.scanning);
    try {
      final path = await _service.takePictureOnly();
      if (path == null) {
        _errorMessage = 'Could not capture image. Try again.';
        _setState(ScannerState.ready);
        return;
      }
      _previewImagePath = path;
      _setState(ScannerState.preview);
    } catch (e) {
      _errorMessage = 'Capture failed: $e';
      _setState(ScannerState.ready);
    }
  }

  void discardPreview() {
    _previewImagePath = null;
    _errorMessage = null;
    _setState(ScannerState.ready);
  }

  Future<void> processPreviewImage() async {
    if (_state != ScannerState.preview || _previewImagePath == null) return;
    _errorMessage = null;
    _setState(ScannerState.scanning);
    try {
      final details = await _service.processImagePath(_previewImagePath!);
      if (details == null || !details.hasAnyData) {
        _errorMessage = 'Could not detect card. Try a clearer photo.';
        _previewImagePath = null;
        _setState(ScannerState.ready);
        return;
      }
      _cardDetails = details;
      _previewImagePath = null;
      _setState(ScannerState.result);
    } catch (e) {
      _errorMessage = 'Scan failed: $e';
      _previewImagePath = null;
      _setState(ScannerState.ready);
    }
  }

  void reset() {
    _cardDetails = null;
    _errorMessage = null;
    _previewImagePath = null;
    _setState(ScannerState.ready);
  }

  Future<void> toggleTorch() async {
    if (_service.cameraController == null) return;
    _torchOn = !_torchOn;
    await _service.cameraController!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    notifyListeners();
  }

  void _setState(ScannerState s) { _state = s; notifyListeners(); }
}
