import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Rotates a raster image (PNG/JPEG bytes) by [degrees] (90/180/270) using a
/// `dart:ui` Canvas rather than a pure-Dart pixel-by-pixel loop — Canvas
/// rotation is backed by Skia and is orders of magnitude faster, which
/// matters both for rotating every page of a large PDF and for instant
/// single-tap rotation of a scanned photo. Returns new PNG bytes.
Future<Uint8List> rotateImageBytes(Uint8List imageBytes, int degrees) async {
  final codec = await ui.instantiateImageCodec(imageBytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final srcWidth = image.width.toDouble();
    final srcHeight = image.height.toDouble();
    final swapDimensions = degrees == 90 || degrees == 270;
    final dstWidth = swapDimensions ? srcHeight : srcWidth;
    final dstHeight = swapDimensions ? srcWidth : srcHeight;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, dstWidth, dstHeight));
    canvas.translate(dstWidth / 2, dstHeight / 2);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-srcWidth / 2, -srcHeight / 2);
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());

    final picture = recorder.endRecording();
    try {
      final rotated = await picture.toImage(dstWidth.round(), dstHeight.round());
      try {
        final byteData = await rotated.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Failed to encode rotated image as PNG');
        }
        return byteData.buffer.asUint8List();
      } finally {
        rotated.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    image.dispose();
  }
}
