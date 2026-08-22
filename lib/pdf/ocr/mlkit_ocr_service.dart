import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pdf_lib;

import '../../core/errors/pdf_exceptions.dart';
import '../engine/pdf_engine.dart';
import 'ocr_service.dart';

/// Render scale used before handing a page to ML Kit and embedding it as the
/// output page's background — 2.0x native point size gives text recognition
/// enough resolution to work with while keeping output file size reasonable.
const double _ocrScale = 2.0;

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
        final decoded = img.decodePng(pngBytes);
        if (decoded == null) {
          throw const PdfManipulationException('Could not process a rendered page.');
        }
        final jpegBytes = img.encodeJpg(decoded, quality: 90);
        final imagePath = p.join(tempDir.path, 'page_$pageNumber.jpg');
        await File(imagePath).writeAsBytes(jpegBytes);

        RecognizedText recognized;
        try {
          recognized = await recognizer.processImage(InputImage.fromFilePath(imagePath));
        } catch (_) {
          // A single unreadable page shouldn't fail the whole document — it
          // simply carries through with no text layer of its own.
          recognized = RecognizedText(text: '', blocks: const []);
        }

        final pageWidth = decoded.width * pointsPerPixel;
        final pageHeight = decoded.height * pointsPerPixel;

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
              } catch (_) {
                // Helvetica can only encode Latin-1; a stray glyph
                // _sanitizeForLatin1 didn't catch shouldn't sink the rest of
                // the document's text layer.
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
  String _sanitizeForLatin1(String text) {
    final mapped = text
        .replaceAll(RegExp('[‘’‚′]'), "'")
        .replaceAll(RegExp('[“”„″]'), '"')
        .replaceAll(RegExp('[–—]'), '-')
        .replaceAll('…', '...')
        .replaceAll(RegExp('[•●◦]'), '*')
        .replaceAll(' ', ' ');
    final buffer = StringBuffer();
    for (final rune in mapped.runes) {
      if (rune <= 0xFF) buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }
}
