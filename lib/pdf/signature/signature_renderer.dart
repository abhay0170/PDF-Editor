import 'dart:typed_data';
import 'dart:ui' as ui;

/// Draws [signaturePngBytes] (a transparent-background signature, as
/// exported by the signature pad) onto a rendered page ([pagePngBytes], as
/// produced by [PdfEngine.renderPageAtScale]) at a position and width given
/// as fractions of the page — so the same coordinates apply regardless of
/// what resolution the page was rendered at. Height is derived from the
/// signature's own aspect ratio. Returns new PNG bytes.
Future<Uint8List> compositeSignature(
  Uint8List pagePngBytes, {
  required Uint8List signaturePngBytes,
  required double relativeX,
  required double relativeY,
  required double relativeWidth,
}) async {
  final page = await _decodePng(pagePngBytes);
  final signature = await _decodePng(signaturePngBytes);

  try {
    final pageWidth = page.width.toDouble();
    final pageHeight = page.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, pageWidth, pageHeight));
    canvas.drawImage(page, ui.Offset.zero, ui.Paint());

    final drawWidth = relativeWidth * pageWidth;
    final drawHeight = drawWidth * (signature.height / signature.width);
    final dstRect = ui.Rect.fromLTWH(relativeX * pageWidth, relativeY * pageHeight, drawWidth, drawHeight);
    final srcRect = ui.Rect.fromLTWH(0, 0, signature.width.toDouble(), signature.height.toDouble());
    canvas.drawImageRect(signature, srcRect, dstRect, ui.Paint());

    final picture = recorder.endRecording();
    try {
      final composited = await picture.toImage(page.width, page.height);
      try {
        final byteData = await composited.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Failed to encode signed page as PNG');
        }
        return byteData.buffer.asUint8List();
      } finally {
        composited.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    page.dispose();
    signature.dispose();
  }
}

Future<ui.Image> _decodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
