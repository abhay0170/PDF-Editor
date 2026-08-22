import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Stamps [text] onto a rendered page ([pngBytes], as produced by
/// [PdfEngine.renderPageAtScale]) as a light, rotated, tiled watermark —
/// drawn with `dart:ui` directly rather than a bitmap font, so it stays
/// crisp and anti-aliased at any render scale. Returns new PNG bytes; the
/// caller disposes nothing, everything native here is cleaned up internally.
Future<Uint8List> applyTextWatermark(Uint8List pngBytes, {required String text}) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  try {
    final width = image.width.toDouble();
    final height = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.drawImage(image, Offset.zero, Paint());

    final fontSize = width * 0.045;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0x2E000000),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.rotate(-math.pi / 4);

    final stepX = textPainter.width + fontSize * 2;
    final stepY = textPainter.height + fontSize * 2;
    final diagonal = math.sqrt(width * width + height * height);
    final cols = (diagonal / stepX).ceil() + 1;
    final rows = (diagonal / stepY).ceil() + 1;

    for (var row = -rows; row <= rows; row++) {
      for (var col = -cols; col <= cols; col++) {
        final dx = col * stepX - textPainter.width / 2;
        final dy = row * stepY - textPainter.height / 2;
        textPainter.paint(canvas, Offset(dx, dy));
      }
    }
    canvas.restore();

    final picture = recorder.endRecording();
    try {
      final watermarked = await picture.toImage(image.width, image.height);
      try {
        final byteData = await watermarked.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Failed to encode watermarked page as PNG');
        }
        return byteData.buffer.asUint8List();
      } finally {
        watermarked.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    image.dispose();
  }
}
