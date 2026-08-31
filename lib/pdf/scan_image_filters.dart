import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Color treatments offered for a scanned page. [original] is a no-op kept
/// so callers can treat "revert to original" the same as applying any other
/// filter, rather than special-casing it.
enum ScanFilter { original, grayscale, blackAndWhite }

/// Applies [filter] to a scanned page photo, returning new PNG bytes. Safe
/// to call repeatedly on an already-filtered file — grayscale and
/// black-and-white are both idempotent, so switching between filters never
/// needs the original capture.
Future<Uint8List> applyScanFilter(Uint8List sourceBytes, ScanFilter filter) async {
  if (filter == ScanFilter.original) return sourceBytes;

  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const FormatException('Could not read this image.');
  }

  final img.Image filtered;
  switch (filter) {
    case ScanFilter.original:
      filtered = decoded;
    case ScanFilter.grayscale:
      filtered = img.grayscale(decoded);
    case ScanFilter.blackAndWhite:
      // Document-scanner style high-contrast black & white: grayscale first
      // so the luminance-based threshold reads shadows/paper tone evenly,
      // then push every pixel to pure black or white so text stays crisp
      // instead of muddy gray.
      filtered = img.grayscale(decoded);
      for (final pixel in filtered) {
        final value = pixel.luminance > 140 ? 255 : 0;
        pixel
          ..r = value
          ..g = value
          ..b = value;
      }
  }

  return Uint8List.fromList(img.encodePng(filtered));
}
