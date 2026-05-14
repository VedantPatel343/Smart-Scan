import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/entities/bank_details.dart';
import '../../domain/parsers/bank_document_parser.dart';

class BankScannerService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  final BankDocumentParser _parser = BankDocumentParser();

  CameraController? _cameraController;
  bool _isProcessing = false;

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  Future<void> initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras found.');
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

  Future<void> dispose() async {
    await _cameraController?.dispose();
    await _recognizer.close();
    _cameraController = null;
  }

  String _sortedOcrText(RecognizedText text) {
    final items = <({double y, double x, String t})>[];
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final r = line.boundingBox;
        items.add((y: r.top, x: r.left, t: line.text));
      }
    }
    if (items.isEmpty) return text.text;
    const rowTol = 36.0;
    items.sort((a, b) {
      if ((a.y - b.y).abs() <= rowTol) return a.x.compareTo(b.x);
      return a.y.compareTo(b.y);
    });
    return items.map((e) => e.t).join('\n');
  }

  BankDetails _parseRecognized(RecognizedText recognized) {
    final raw = _sortedOcrText(recognized);
    if (raw.trim().isEmpty) return const BankDetails();
    return _parser.parse(raw);
  }

  Future<String?> takePictureOnly() async {
    if (!isInitialized) return null;
    final xFile = await _cameraController!.takePicture();
    return xFile.path;
  }

  Future<BankDetails?> scanImageFile(File file) async {
    if (_isProcessing) return null;
    _isProcessing = true;
    try {
      final img = InputImage.fromFilePath(file.path);
      final recognized = await _recognizer.processImage(img);
      final r = _parseRecognized(recognized);
      return r.hasAnyData ? r : null;
    } finally {
      _isProcessing = false;
    }
  }
}
