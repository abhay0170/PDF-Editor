import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest side an uploaded signature photo is downscaled to before
/// processing — keeps the resulting transparent PNG (and therefore the
/// final signed PDF) a reasonable size regardless of how large the source
/// photo was.
const int _maxDimension = 1200;

/// Pixels at or above this luminance (0-255) are treated as background
/// paper and made fully transparent.
const double _backgroundLuminance = 200;

/// Pixels at or below this luminance are treated as fully-opaque ink.
/// Between [_inkLuminance] and [_backgroundLuminance], alpha ramps linearly
/// so stroke edges stay anti-aliased instead of showing a hard cutout.
const double _inkLuminance = 110;

/// Converts a photographed signature — dark ink strokes on a light, roughly
/// uniform background (paper) — into a transparent-background image with
/// the same shape of output the hand-drawn signature pad produces, so it
/// can go through the same [compositeSignature] path.
///
/// This is a luminance threshold, not true segmentation: it assumes a light
/// background and dark strokes, which covers the overwhelmingly common case
/// (a signature signed in pen on white/light paper, photographed with a
/// phone) without pulling in an ML dependency. Heavy shadows, colored or
/// patterned paper, or very light ink can produce a rougher cutout.
Uint8List removeSignatureBackground(Uint8List imageBytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(imageBytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw const FormatException('Could not read this image.');
  }

  final source = decoded.width > _maxDimension || decoded.height > _maxDimension
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? _maxDimension : null,
          height: decoded.height > decoded.width ? _maxDimension : null,
        )
      : decoded;

  final result = img.Image(width: source.width, height: source.height, numChannels: 4);
  for (final pixel in source) {
    final luminance = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
    final alpha = ((_backgroundLuminance - luminance) / (_backgroundLuminance - _inkLuminance) * 255)
        .clamp(0, 255)
        .round();
    result.setPixelRgba(pixel.x, pixel.y, pixel.r, pixel.g, pixel.b, alpha);
  }

  return Uint8List.fromList(img.encodePng(result));
}
