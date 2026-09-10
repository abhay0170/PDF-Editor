import 'dart:io';

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/pdf.dart' as pdf_lib;
import 'package:path/path.dart' as p;

import '../../core/utils/image_recompress.dart';
import '../engine/pdf_engine.dart';
import 'ocr_service.dart';

/// Render scale used before handing a page to ML Kit and embedding it as the
/// output page's background — 2.0x native point size gives text recognition
/// enough resolution to work with while keeping output file size reasonable.
const double _ocrScale = 2.0;

/// JPEG quality used when re-encoding each rendered page before it's
/// embedded as the output page's background image.
const int _ocrJpegQuality = 90;

class MlKitOcrService implements OcrService {
  MlKitOcrService(this._engine);

  final PdfEngine _engine;

  @override
  Future<int> makeSearchable({required String sourcePath, required String outputPath}) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final document = pdf_lib.PdfDocument();
    final font = pdf_lib.PdfFont.helvetica(document);
    final tempDir = await Directory.systemTemp.createTemp('pdf_ocr_');
    final batch = await _engine.openForRendering(sourcePath);

    try {
      var recognizedChars = 0;
      const pointsPerPixel = 1 / _ocrScale;

      for (var pageNumber = 1; pageNumber <= batch.pageCount; pageNumber++) {
        final pngBytes = await batch.renderPage(pageNumber, scale: _ocrScale);
        final page = await compute(recompressPngPageForOcr, (pngBytes, _ocrJpegQuality));
        final jpegBytes = page.jpegBytes;
        final imagePath = p.join(tempDir.path, 'page_$pageNumber.jpg');
        await File(imagePath).writeAsBytes(jpegBytes);

        RecognizedText recognized;
        try {
          recognized = await recognizer.processImage(InputImage.fromFilePath(imagePath));
        } catch (e) {
          // A single unreadable page shouldn't fail the whole document — it
          // simply carries through with no text layer of its own.
          debugPrint('OCR: page $pageNumber could not be recognized: $e');
          recognized = RecognizedText(text: '', blocks: const []);
        }

        final pageWidth = page.width * pointsPerPixel;
        final pageHeight = page.height * pointsPerPixel;

        final pdfPage = pdf_lib.PdfPage(document, pageFormat: pdf_lib.PdfPageFormat(pageWidth, pageHeight));
        final graphics = pdfPage.getGraphics();
        final pdfImage = pdf_lib.PdfImage.jpeg(document, image: jpegBytes);
        graphics.drawImage(pdfImage, 0, 0, pageWidth, pageHeight);

        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            for (final element in line.elements) {
              final text = _sanitizeForLatin1(element.text);
              if (text.trim().isEmpty) continue;

              final box = element.boundingBox;
              try {
                final fontSize = (box.height * pointsPerPixel).clamp(1.0, 400.0);
                final naturalWidth = (font.stringMetrics(text) * fontSize).advanceWidth;
                final targetWidth = box.width * pointsPerPixel;
                final horizontalScale = naturalWidth > 0 ? (targetWidth / naturalWidth).clamp(0.05, 20.0) : 1.0;

                graphics.drawString(
                  font,
                  fontSize,
                  text,
                  box.left * pointsPerPixel,
                  pageHeight - (box.bottom * pointsPerPixel),
                  mode: pdf_lib.PdfTextRenderingMode.invisible,
                  scale: horizontalScale,
                );
                recognizedChars += text.length;
              } catch (e) {
                // Helvetica can only encode Latin-1; a stray glyph
                // _sanitizeForLatin1 didn't catch shouldn't sink the rest of
                // the document's text layer.
                debugPrint('OCR: dropped an unencodable text run on page $pageNumber: $e');
              }
            }
          }
        }
      }

      final bytes = await document.save();
      await File(outputPath).writeAsBytes(bytes);
      return recognizedChars;
    } finally {
      await recognizer.close();
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
      await batch.dispose();
    }
  }

  /// Helvetica (the built-in Type1 base font used here) can only encode
  /// Latin-1 — `PdfFont.stringMetrics`/`putText` call `latin1.encode`
  /// internally and throw on anything outside it. Recognized text routinely
  /// contains smart quotes, em dashes, bullets, or other punctuation outside
  /// that range, so common look-alikes are mapped to their ASCII
  /// equivalents and anything else still unencodable is dropped, rather
  /// than letting one bad character abort the rest of the document's text
  /// layer.
  static final RegExp _singleQuotes = RegExp('[‘’‚′]');
  static final RegExp _doubleQuotes = RegExp('[“”„″]');
  static final RegExp _dashes = RegExp('[–—]');
  static final RegExp _bullets = RegExp('[•●◦]');

  String _sanitizeForLatin1(String text) {
    final mapped = text
        .replaceAll(_singleQuotes, "'")
        .replaceAll(_doubleQuotes, '"')
        .replaceAll(_dashes, '-')
        .replaceAll('…', '...')
        .replaceAll(_bullets, '*')
        .replaceAll(' ', ' ');
    final buffer = StringBuffer();
    for (final rune in mapped.runes) {
      if (rune <= 0xFF) buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }
}
