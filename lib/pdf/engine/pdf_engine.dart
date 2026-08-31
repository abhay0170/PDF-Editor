import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import '../models/pdf_document_info.dart';

/// Headless PDF operations used during import/thumbnailing. The interactive
/// viewer talks to `pdfrx`'s [PdfViewer] widget directly, not through this
/// interface — this is only for operations that need a document without
/// showing it on screen.
abstract class PdfEngine {
  Future<PdfProbeResult> probe(String path, {PdfPasswordProvider? passwordProvider});

  Future<Uint8List> renderPagePng(
    String path, {
    required int pageNumber,
    required int width,
    required int height,
    PdfPasswordProvider? passwordProvider,
  });

  /// Renders [pageNumber] at [scale] × its native point size (72 points/inch,
  /// so `scale: 2.0` is roughly 144 DPI) — used for manipulation tools that
  /// need print-quality output rather than a small thumbnail.
  Future<Uint8List> renderPageAtScale(
    String path, {
    required int pageNumber,
    required double scale,
    PdfPasswordProvider? passwordProvider,
  });

  /// Opens [path] once for rendering several pages in sequence — every tool
  /// that walks a whole document (Split/Rotate/Extract/Watermark/Compress/
  /// Sign/OCR) should use this instead of repeated [renderPageAtScale] calls,
  /// each of which reopens and reparses the file from scratch.
  Future<PdfPageBatch> openForRendering(String path, {PdfPasswordProvider? passwordProvider});

  /// Concatenates every page's extracted text (native text layer — same as
  /// what the in-viewer search uses, not OCR), joined with blank lines.
  /// Returns an empty string for image-only pages with no extractable text.
  Future<String> extractText(String path, {PdfPasswordProvider? passwordProvider});
}

/// A single open document handle used to render multiple pages without
/// reopening the file each time. Callers must call [dispose] when done
/// (typically in a `finally` block).
abstract class PdfPageBatch {
  int get pageCount;

  Future<Uint8List> renderPage(int pageNumber, {required double scale});

  Future<void> dispose();
}

class PdfrxEngine implements PdfEngine {
  @override
  Future<PdfProbeResult> probe(String path, {PdfPasswordProvider? passwordProvider}) async {
    if (!File(path).existsSync()) {
      return const PdfProbeMissingFile();
    }

    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(path, passwordProvider: passwordProvider);
      return PdfProbeOk(
        PdfDocumentInfo(pageCount: document.pages.length, isEncrypted: false),
      );
    } on PdfPasswordException {
      return const PdfProbePasswordRequired();
    } on PdfException catch (e) {
      return PdfProbeCorrupted(e.message);
    } on FileSystemException {
      return const PdfProbeMissingFile();
    } finally {
      await document?.dispose();
    }
  }

  @override
  Future<Uint8List> renderPagePng(
    String path, {
    required int pageNumber,
    required int width,
    required int height,
    PdfPasswordProvider? passwordProvider,
  }) {
    return _withPage(
      path,
      pageNumber: pageNumber,
      passwordProvider: passwordProvider,
      render: (page) => page.render(fullWidth: width.toDouble(), fullHeight: height.toDouble()),
    );
  }

  @override
  Future<Uint8List> renderPageAtScale(
    String path, {
    required int pageNumber,
    required double scale,
    PdfPasswordProvider? passwordProvider,
  }) {
    return _withPage(
      path,
      pageNumber: pageNumber,
      passwordProvider: passwordProvider,
      render: (page) => page.render(fullWidth: page.width * scale, fullHeight: page.height * scale),
    );
  }

  @override
  Future<PdfPageBatch> openForRendering(String path, {PdfPasswordProvider? passwordProvider}) async {
    final document = await PdfDocument.openFile(path, passwordProvider: passwordProvider);
    return _PdfrxPageBatch(document);
  }

  @override
  Future<String> extractText(String path, {PdfPasswordProvider? passwordProvider}) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(path, passwordProvider: passwordProvider);
      final pageTexts = <String>[];
      for (final page in document.pages) {
        final text = await page.loadStructuredText();
        if (text.fullText.trim().isNotEmpty) {
          pageTexts.add(text.fullText);
        }
      }
      return pageTexts.join('\n\n');
    } on PdfException {
      return '';
    } finally {
      await document?.dispose();
    }
  }

  Future<Uint8List> _withPage(
    String path, {
    required int pageNumber,
    required PdfPasswordProvider? passwordProvider,
    required Future<PdfImage?> Function(PdfPage page) render,
  }) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(path, passwordProvider: passwordProvider);
      if (pageNumber < 1 || pageNumber > document.pages.length) {
        throw ArgumentError.value(pageNumber, 'pageNumber', 'Out of range');
      }

      final page = document.pages[pageNumber - 1];
      final pdfImage = await render(page);
      if (pdfImage == null) {
        throw StateError('pdfrx returned no image for page $pageNumber of $path');
      }
      try {
        return await _encodePng(pdfImage);
      } finally {
        pdfImage.dispose();
      }
    } finally {
      await document?.dispose();
    }
  }
}

Future<Uint8List> _encodePng(PdfImage pdfImage) async {
  final uiImage = await _decodeBgra(pdfImage.pixels, pdfImage.width, pdfImage.height);
  final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
  uiImage.dispose();
  if (byteData == null) {
    throw StateError('Failed to encode rendered page as PNG');
  }
  return byteData.buffer.asUint8List();
}

Future<ui.Image> _decodeBgra(Uint8List bgraPixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bgraPixels,
    width,
    height,
    ui.PixelFormat.bgra8888,
    completer.complete,
  );
  return completer.future;
}

class _PdfrxPageBatch implements PdfPageBatch {
  _PdfrxPageBatch(this._document);

  final PdfDocument _document;

  @override
  int get pageCount => _document.pages.length;

  @override
  Future<Uint8List> renderPage(int pageNumber, {required double scale}) async {
    if (pageNumber < 1 || pageNumber > _document.pages.length) {
      throw ArgumentError.value(pageNumber, 'pageNumber', 'Out of range');
    }

    final page = _document.pages[pageNumber - 1];
    final pdfImage = await page.render(fullWidth: page.width * scale, fullHeight: page.height * scale);
    if (pdfImage == null) {
      throw StateError('pdfrx returned no image for page $pageNumber');
    }
    try {
      return await _encodePng(pdfImage);
    } finally {
      pdfImage.dispose();
    }
  }

  @override
  Future<void> dispose() => _document.dispose();
}
