import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/errors/pdf_exceptions.dart';
import 'pdf_protection_service.dart';

class SyncfusionPdfProtectionService implements PdfProtectionService {
  @override
  Future<String> protect({
    required String sourcePath,
    required String outputPath,
    required String password,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    try {
      final output = await compute(_encryptInBackground, (bytes, password));
      await File(outputPath).writeAsBytes(output);
      return outputPath;
    } catch (e) {
      debugPrint('PDF protect failed: $e');
      throw const PdfManipulationException('Could not add a password to this document.');
    }
  }

  @override
  Future<String> removeProtection({
    required String sourcePath,
    required String outputPath,
    required String password,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    try {
      final output = await compute(_decryptInBackground, (bytes, password));
      await File(outputPath).writeAsBytes(output);
      return outputPath;
    } on _IncorrectPasswordException {
      throw const PdfManipulationException('Incorrect password.');
    } catch (e) {
      debugPrint('PDF removeProtection failed: $e');
      throw const PdfManipulationException('Could not remove the password from this document.');
    }
  }
}

class _IncorrectPasswordException implements Exception {
  const _IncorrectPasswordException();
}

/// Runs the whole-document AES-256 encryption on a background isolate via
/// `compute()` — synchronous CPU work that would otherwise block the UI
/// thread for the entire save, especially on large documents.
Future<Uint8List> _encryptInBackground((Uint8List bytes, String password) args) async {
  final (bytes, password) = args;
  final document = PdfDocument(inputBytes: bytes);
  try {
    document.security.userPassword = password;
    document.security.ownerPassword = password;
    document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
    return Uint8List.fromList(await document.save());
  } finally {
    document.dispose();
  }
}

/// Background-isolate counterpart of [_encryptInBackground] for password
/// removal.
Future<Uint8List> _decryptInBackground((Uint8List bytes, String password) args) async {
  final (bytes, password) = args;
  final PdfDocument document;
  try {
    document = PdfDocument(inputBytes: bytes, password: password);
  } catch (_) {
    throw const _IncorrectPasswordException();
  }
  try {
    document.security.userPassword = '';
    document.security.ownerPassword = '';
    return Uint8List.fromList(await document.save());
  } finally {
    document.dispose();
  }
}
