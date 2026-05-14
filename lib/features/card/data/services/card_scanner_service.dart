import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/card_details.dart';
import '../../domain/parsers/card_parser.dart';

/// Encapsulates all OCR + camera logic and exposes simple async methods.
class CardScannerService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final CardParser _parser = CardParser();

  CameraController? _cameraController;
  bool _isProcessing = false;

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  // ---------------------------------------------------------------------------
  // Camera lifecycle
  // ---------------------------------------------------------------------------

  /// Initialise the rear camera for scanning.
  Future<void> initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    // Pick rear camera
    final rear = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      rear,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();
  }

  /// Dispose camera and OCR resources.
  Future<void> dispose() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController?.dispose();
    }
    await _recognizer.close();
    _cameraController = null;
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Single photo for preview (no OCR).
  Future<String?> takePictureOnly() async {
    if (!isInitialized) return null;
    final xFile = await _cameraController!.takePicture();
    return xFile.path;
  }

  /// Run OCR + parse on an existing image file (after user confirms preview).
  Future<CardDetails?> processImagePath(String path) async {
    return processInputImage(InputImage.fromFilePath(path));
  }

  /// Capture a few frames, run OCR, and parse card details. Multiple shots are
  /// merged with per-digit majority voting on the PAN so intermittent OCR
  /// errors are less likely to drop the card number.
  Future<CardDetails?> scanFrame() async {
    if (_isProcessing) return null;
    if (!isInitialized) return null;

    _isProcessing = true;
    try {
      const shots = 3;
      const pause = Duration(milliseconds: 140);
      final runs = <CardDetails>[];

      for (var i = 0; i < shots; i++) {
        final xFile = await _cameraController!.takePicture();
        final inputImage = InputImage.fromFilePath(xFile.path);
        final recognizedText = await _recognizer.processImage(inputImage);
        final rawText = _sortedOcrText(recognizedText);
        if (rawText.trim().isNotEmpty) {
          runs.add(_parser.parse(rawText));
        }
        if (i < shots - 1) await Future<void>.delayed(pause);
      }

      if (runs.isEmpty) return null;
      final merged = CardParser.mergeCaptures(runs);
      if (!merged.hasAnyData) return null;
      return merged;
    } finally {
      _isProcessing = false;
    }
  }

  /// Reading-order text: sort every [TextLine] top-to-then-left so embossed PAN
  /// order matches physical layout better than [RecognizedText.text] alone.
  String _sortedOcrText(RecognizedText text) {
    final items = <({double y, double x, String t})>[];
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final r = line.boundingBox;
        items.add((y: r.top, x: r.left, t: line.text));
      }
    }
    if (items.isEmpty) return text.text;
    const rowTol = 32.0;
    items.sort((a, b) {
      if ((a.y - b.y).abs() <= rowTol) return a.x.compareTo(b.x);
      return a.y.compareTo(b.y);
    });
    return items.map((e) => e.t).join('\n');
  }

  /// Process an [InputImage] directly (used by image stream mode).
  Future<CardDetails?> processInputImage(InputImage image) async {
    if (_isProcessing) return null;
    _isProcessing = true;
    try {
      final recognizedText = await _recognizer.processImage(image);
      final rawText = _sortedOcrText(recognizedText);
      if (rawText.trim().isEmpty) return null;
      return _parser.parse(rawText);
    } finally {
      _isProcessing = false;
    }
  }
}
