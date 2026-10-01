import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_medreminder/features/medications/medication_screen.dart';

class PrescriptionScannerScreen extends StatefulWidget {
  const PrescriptionScannerScreen({super.key});

  @override
  State<PrescriptionScannerScreen> createState() =>
      _PrescriptionScannerScreenState();
}

class _PrescriptionScannerScreenState extends State<PrescriptionScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _processing = false;
  String? _error;

  Future<void> _capturePrescription() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
    } catch (error, stackTrace) {
      _logFailure('camera capture', error, stackTrace);
      _showError('Could not capture the image.');
      return;
    }

    if (image == null) {
      if (mounted) setState(() => _processing = false);
      return;
    }

    final imageFile = File(image.path);
    try {
      if (image.path.trim().isEmpty || !await imageFile.exists()) {
        throw const FileSystemException('Captured image path is missing.');
      }
      await imageFile.openRead(0, 1).first;
    } catch (error, stackTrace) {
      _logFailure('captured image file', error, stackTrace);
      _showError('Could not read the captured image.');
      return;
    }

    late final InputImage inputImage;
    try {
      inputImage = InputImage.fromFilePath(image.path);
    } catch (error, stackTrace) {
      _logFailure('InputImage conversion', error, stackTrace);
      _showError('Could not prepare the captured image.');
      return;
    }

    late final TextRecognizer recognizer;
    try {
      recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    } catch (error, stackTrace) {
      _logFailure('text recognizer initialization', error, stackTrace);
      _showError('Could not start text recognition.');
      return;
    }

    late final RecognizedText result;
    try {
      result = await recognizer.processImage(inputImage);
    } catch (error, stackTrace) {
      _logFailure('OCR processImage', error, stackTrace);
      await recognizer.close();
      _showError('Text recognition failed. Please try again.');
      return;
    }

    try {
      await recognizer.close();
    } catch (error, stackTrace) {
      _logFailure('text recognizer close', error, stackTrace);
    }

    if (!mounted) return;
    if (result.text.trim().isEmpty) {
      _showError('No readable text was found. Try a clearer image.');
      return;
    }

    try {
      final parsed = _PrescriptionParse.fromText(result.text);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddMedicationScreen.fromPrescription(
            detectedText: result.text,
            initialName: parsed.name,
            initialDosage: parsed.dosage,
            initialFrequency: parsed.frequency,
            initialReminderTime: parsed.reminderTime,
          ),
        ),
      );
      if (mounted) setState(() => _processing = false);
    } catch (error, stackTrace) {
      _logFailure('OCR result extraction/review', error, stackTrace);
      _showError('Could not read the medication details. Please try again.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _processing = false;
      _error = message;
    });
  }

  void _logFailure(String stage, Object error, StackTrace stackTrace) {
    debugPrint('Prescription scanner $stage failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Prescription')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.document_scanner_outlined, size: 76),
              const SizedBox(height: 20),
              Text(
                'Scan Prescription',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Capture a clear prescription photo. Text recognition runs only on this device.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              if (_processing) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 14),
                const Text('Reading prescription...', textAlign: TextAlign.center),
              ] else
                FilledButton.icon(
                  onPressed: _capturePrescription,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Open Camera'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionParse {
  const _PrescriptionParse({
    this.name = '',
    this.dosage = '',
    this.frequency,
    this.reminderTime,
  });

  final String name;
  final String dosage;
  final String? frequency;
  final String? reminderTime;

  factory _PrescriptionParse.fromText(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final dosageMatch = RegExp(
      r'\b\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|%)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final timeMatch = RegExp(r'\b([01]?\d|2[0-3]):[0-5]\d\b').firstMatch(text);
    final lower = text.toLowerCase();

    String? frequency;
    if (lower.contains('three times') || lower.contains('three-time')) {
      frequency = 'Three times a day';
    } else if (lower.contains('twice') || lower.contains('two times')) {
      frequency = 'Twice a day';
    } else if (lower.contains('weekly') || lower.contains('once a week')) {
      frequency = 'Weekly';
    } else if (lower.contains('once daily') ||
        lower.contains('once a day') ||
        lower.contains('every day') ||
        lower.contains('daily')) {
      frequency = 'Every day';
    }

    final name = lines.firstWhere(
      (line) => dosageMatch == null || line != dosageMatch.group(0),
      orElse: () => '',
    );

    return _PrescriptionParse(
      name: name,
      dosage: dosageMatch?.group(0) ?? '',
      frequency: frequency,
      reminderTime: timeMatch?.group(0),
    );
  }
}
