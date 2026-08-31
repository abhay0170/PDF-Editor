import 'dart:io';

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
    final document = PdfDocument(inputBytes: bytes);
    try {
      document.security.userPassword = password;
      document.security.ownerPassword = password;
      document.security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;
      final output = await document.save();
      await File(outputPath).writeAsBytes(output);
      return outputPath;
    } catch (_) {
      throw const PdfManipulationException('Could not add a password to this document.');
    } finally {
      document.dispose();
    }
  }

  @override
  Future<String> removeProtection({
    required String sourcePath,
    required String outputPath,
    required String password,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final PdfDocument document;
    try {
      document = PdfDocument(inputBytes: bytes, password: password);
    } catch (_) {
      throw const PdfManipulationException('Incorrect password.');
    }
    try {
      document.security.userPassword = '';
      document.security.ownerPassword = '';
      final output = await document.save();
      await File(outputPath).writeAsBytes(output);
      return outputPath;
    } catch (_) {
      throw const PdfManipulationException('Could not remove the password from this document.');
    } finally {
      document.dispose();
    }
  }
}
