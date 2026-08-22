import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_combiner/models/merge_input.dart';
import 'package:pdf_combiner/pdf_combiner.dart';

import '../../core/errors/pdf_exceptions.dart';
import '../../core/utils/image_recompress.dart';
import '../engine/pdf_engine.dart';
import '../rotate_image.dart';
import '../signature/signature_renderer.dart';
import '../watermark/watermark_renderer.dart';
import 'pdf_manipulation_service.dart';

/// Render scale used when rasterizing pages for Split/Rotate/Extract — 2.0x
/// native point size is roughly 144 DPI, a reasonable balance of on-screen
/// quality against output file size.
const double _exportScale = 2.0;

class PdfCombinerManipulationService implements PdfManipulationService {
  PdfCombinerManipulationService(this._engine);

  final PdfEngine _engine;

  @override
  Future<String> mergePdfs({required List<String> sourcePaths, required String outputPath}) async {
    if (sourcePaths.length < 2) {
      throw const PdfManipulationException('Select at least two PDFs to merge.');
    }
    try {
      return await PdfCombiner.mergeMultiplePDFs(
        inputs: sourcePaths.map(MergeInput.path).toList(),
        outputPath: outputPath,
      );
    } catch (_) {
      throw const PdfManipulationException('Could not merge these documents.');
    }
  }

  @override
  Future<List<String>> splitPdf({
    required String sourcePath,
    required List<List<int>> pageRanges,
    required String outputDir,
  }) async {
    if (pageRanges.isEmpty) {
      throw const PdfManipulationException('Choose at least one page range to split out.');
    }
    await Directory(outputDir).create(recursive: true);

    final batch = await _engine.openForRendering(sourcePath);
    try {
      final outputs = <String>[];
      for (var i = 0; i < pageRanges.length; i++) {
        final outputPath = p.join(outputDir, 'split_${i + 1}.pdf');
        await _assemblePagesFromBatch(batch, pageRanges[i], outputPath);
        outputs.add(outputPath);
      }
      return outputs;
    } finally {
      await batch.dispose();
    }
  }

  @override
  Future<String> extractPages({
    required String sourcePath,
    required List<int> pageNumbers,
    required String outputPath,
  }) async {
    if (pageNumbers.isEmpty) {
      throw const PdfManipulationException('Choose at least one page to extract.');
    }
    final batch = await _engine.openForRendering(sourcePath);
    try {
      return await _assemblePagesFromBatch(batch, pageNumbers, outputPath);
    } finally {
      await batch.dispose();
    }
  }

  @override
  Future<String> rotatePages({
    required String sourcePath,
    required Set<int> pageNumbers,
    required int degrees,
    required String outputPath,
  }) async {
    if (pageNumbers.isEmpty) {
      throw const PdfManipulationException('Choose at least one page to rotate.');
    }

    final batch = await _engine.openForRendering(sourcePath);
    try {
      final allPages = List.generate(batch.pageCount, (i) => i + 1);
      return await _assemblePagesFromBatch(
        batch,
        allPages,
        outputPath,
        rotationDegreesFor: (page) => pageNumbers.contains(page) ? degrees : 0,
      );
    } finally {
      await batch.dispose();
    }
  }

  @override
  Future<String> createPdfFromImages({required List<String> imagePaths, required String outputPath}) async {
    if (imagePaths.isEmpty) {
      throw const PdfManipulationException('No scanned pages to save.');
    }
    try {
      await PdfCombiner.createPDFFromMultipleImages(
        inputs: imagePaths.map(MergeInput.path).toList(),
        outputPath: outputPath,
      );
      return outputPath;
    } catch (_) {
      throw const PdfManipulationException('Could not assemble the scanned pages into a PDF.');
    }
  }

  @override
  Future<String> watermarkPdf({
    required String sourcePath,
    required String text,
    required String outputPath,
  }) async {
    if (text.trim().isEmpty) {
      throw const PdfManipulationException('Enter watermark text.');
    }

    final batch = await _engine.openForRendering(sourcePath);
    final tempDir = await Directory.systemTemp.createTemp('pdf_watermark_');
    try {
      final allPages = List.generate(batch.pageCount, (i) => i + 1);
      final imagePaths = <String>[];
      for (final pageNumber in allPages) {
        final pngBytes = await batch.renderPage(pageNumber, scale: _exportScale);
        final watermarked = await applyTextWatermark(pngBytes, text: text.trim());

        final imagePath = p.join(tempDir.path, 'page_$pageNumber.png');
        await File(imagePath).writeAsBytes(watermarked);
        imagePaths.add(imagePath);
      }

      try {
        await PdfCombiner.createPDFFromMultipleImages(
          inputs: imagePaths.map(MergeInput.path).toList(),
          outputPath: outputPath,
        );
      } catch (_) {
        throw const PdfManipulationException('Could not assemble the watermarked PDF.');
      }
      return outputPath;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
      await batch.dispose();
    }
  }

  @override
  Future<String> compressPdf({
    required String sourcePath,
    required String outputPath,
    required double scale,
    required int quality,
  }) async {
    final batch = await _engine.openForRendering(sourcePath);
    final tempDir = await Directory.systemTemp.createTemp('pdf_compress_');
    try {
      final allPages = List.generate(batch.pageCount, (i) => i + 1);
      final imagePaths = <String>[];
      for (final pageNumber in allPages) {
        final pngBytes = await batch.renderPage(pageNumber, scale: scale);
        final jpegBytes = await compute(recompressPngAsJpeg, (pngBytes, quality));

        final imagePath = p.join(tempDir.path, 'page_$pageNumber.jpg');
        await File(imagePath).writeAsBytes(jpegBytes);
        imagePaths.add(imagePath);
      }

      try {
        await PdfCombiner.createPDFFromMultipleImages(
          inputs: imagePaths.map(MergeInput.path).toList(),
          outputPath: outputPath,
        );
      } catch (_) {
        throw const PdfManipulationException('Could not assemble the compressed PDF.');
      }
      return outputPath;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
      await batch.dispose();
    }
  }

  @override
  Future<String> signPdf({
    required String sourcePath,
    required String outputPath,
    required int pageNumber,
    required Uint8List signatureImageBytes,
    required double relativeX,
    required double relativeY,
    required double relativeWidth,
  }) async {
    final batch = await _engine.openForRendering(sourcePath);
    final tempDir = await Directory.systemTemp.createTemp('pdf_sign_');
    try {
      final allPages = List.generate(batch.pageCount, (i) => i + 1);
      final imagePaths = <String>[];
      for (final number in allPages) {
        final pngBytes = await batch.renderPage(number, scale: _exportScale);
        final finalBytes = number == pageNumber
            ? await compositeSignature(
                pngBytes,
                signaturePngBytes: signatureImageBytes,
                relativeX: relativeX,
                relativeY: relativeY,
                relativeWidth: relativeWidth,
              )
            : pngBytes;

        final imagePath = p.join(tempDir.path, 'page_$number.png');
        await File(imagePath).writeAsBytes(finalBytes);
        imagePaths.add(imagePath);
      }

      try {
        await PdfCombiner.createPDFFromMultipleImages(
          inputs: imagePaths.map(MergeInput.path).toList(),
          outputPath: outputPath,
        );
      } catch (_) {
        throw const PdfManipulationException('Could not assemble the signed PDF.');
      }
      return outputPath;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
      await batch.dispose();
    }
  }

  Future<String> _assemblePagesFromBatch(
    PdfPageBatch batch,
    List<int> pageNumbers,
    String outputPath, {
    int Function(int pageNumber)? rotationDegreesFor,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('pdf_manip_');
    try {
      final imagePaths = <String>[];
      for (final pageNumber in pageNumbers) {
        final pngBytes = await batch.renderPage(pageNumber, scale: _exportScale);
        final rotation = rotationDegreesFor?.call(pageNumber) ?? 0;
        final finalBytes = rotation == 0 ? pngBytes : await rotateImageBytes(pngBytes, rotation);

        final imagePath = p.join(tempDir.path, 'page_$pageNumber.png');
        await File(imagePath).writeAsBytes(finalBytes);
        imagePaths.add(imagePath);
      }

      try {
        await PdfCombiner.createPDFFromMultipleImages(
          inputs: imagePaths.map(MergeInput.path).toList(),
          outputPath: outputPath,
        );
      } catch (_) {
        throw const PdfManipulationException('Could not assemble the resulting PDF.');
      }
      return outputPath;
    } finally {
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    }
  }
}
