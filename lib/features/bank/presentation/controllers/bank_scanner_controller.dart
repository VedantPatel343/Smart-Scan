import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/bank_scanner_service.dart';
import '../../domain/entities/bank_details.dart';

enum ScannerState {
  idle,
  requestingPermission,
  permissionDenied,
  initializing,
  ready,
  preview,
  scanning,
  result,
  error,
}

class BankScannerController extends ChangeNotifier {
  final BankScannerService _service = BankScannerService();
  final ImagePicker _picker = ImagePicker();
  static const String _invalidPassbookMessage = 'image is invalid';

  ScannerState _state = ScannerState.idle;
  BankDetails? _bankDetails;
  String? _errorMessage;
  bool _torchOn = false;
  String? _previewImagePath;

  ScannerState get state => _state;
  BankDetails? get bankDetails => _bankDetails;
  String? get errorMessage => _errorMessage;
  bool get torchOn => _torchOn;
  String? get previewImagePath => _previewImagePath;
  BankScannerService get service => _service;

  Future<void> initialize() async {
    _setState(ScannerState.requestingPermission);
    _errorMessage = null;
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _errorMessage = status.isPermanentlyDenied
          ? 'Camera permission permanently denied. Enable it in Settings.'
          : 'Camera access is required to scan documents.';
      _setState(ScannerState.permissionDenied);
      return;
    }
    _setState(ScannerState.initializing);
    try {
      await _service.initCamera();
      _setState(ScannerState.ready);
    } catch (e) {
      _errorMessage = 'Failed to start camera: $e';
      _setState(ScannerState.error);
    }
  }

  @override
  Future<void> dispose() async {
    await _service.dispose();
    super.dispose();
  }

  /// Camera: one frame for preview; OCR runs in [processPreviewImage].
  Future<void> captureForPreview() async {
    if (_state != ScannerState.ready) return;
    if (!_service.isInitialized) {
      _errorMessage = 'Camera is not ready.';
      notifyListeners();
      return;
    }
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

  /// Run OCR + passbook parser on the preview image, then validate.
  Future<void> processPreviewImage() async {
    if (_state != ScannerState.preview || _previewImagePath == null) return;
    _errorMessage = null;
    _setState(ScannerState.scanning);
    try {
      final details = await _service.scanImageFile(File(_previewImagePath!));
      if (details == null || !details.hasAnyData) {
        _errorMessage = 'Could not extract banking details from this image.';
        _previewImagePath = null;
        _setState(ScannerState.ready);
        return;
      }
      if (!details.isValidPassbookExtract) {
        _errorMessage = BankScannerController._invalidPassbookMessage;
        _previewImagePath = null;
        _setState(ScannerState.ready);
        return;
      }
      _bankDetails = details;
      _previewImagePath = null;
      _setState(ScannerState.result);
    } catch (e) {
      _errorMessage = 'Failed to process image: $e';
      _previewImagePath = null;
      _setState(ScannerState.ready);
    }
  }

  Future<void> pickFromGalleryForPreview() async {
    if (_state == ScannerState.scanning) return;
    if (_state == ScannerState.idle) {
      _setState(ScannerState.ready);
    }
    _errorMessage = null;

    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      _errorMessage = 'Photo library access is required to pick an image.';
      _setState(ScannerState.ready);
      return;
    }
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (xFile == null) {
        _setState(ScannerState.ready);
        return;
      }
      _previewImagePath = xFile.path;
      _setState(ScannerState.preview);
    } catch (e) {
      _errorMessage = 'Failed to pick image: $e';
      _setState(ScannerState.ready);
    }
  }

  Future<void> toggleTorch() async {
    if (_service.cameraController == null) return;
    _torchOn = !_torchOn;
    await _service.cameraController!.setFlashMode(_torchOn ? FlashMode.torch : FlashMode.off);
    notifyListeners();
  }

  void reset() {
    _bankDetails = null;
    _errorMessage = null;
    _previewImagePath = null;
    _setState(ScannerState.ready);
  }

  void _setState(ScannerState s) {
    _state = s;
    notifyListeners();
  }
}
