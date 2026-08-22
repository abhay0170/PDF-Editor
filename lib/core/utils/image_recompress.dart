import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../errors/pdf_exceptions.dart';

/// Decodes a PNG and re-encodes it as JPEG at [quality] — pure-Dart pixel
/// work (no `dart:ui`), so unlike the other page-image transforms in
/// lib/pdf/ it's safe to run via `compute()` off the UI isolate. Shared by
/// [PdfCombinerManipulationService.compressPdf] (the real run) and
/// `CompressEstimateController` (the live slider preview) so both pay the
/// same isolate-hop cost model.
Uint8List recompressPngAsJpeg((Uint8List pngBytes, int quality) args) {
  final (pngBytes, quality) = args;
  final decoded = img.decodePng(pngBytes);
  if (decoded == null) {
    throw const PdfManipulationException('Could not process a rendered page.');
  }
  return img.encodeJpg(decoded, quality: quality);
}

/// Same idea as [recompressPngAsJpeg] but for an already-captured photo of
/// arbitrary format (JPEG/PNG/etc, as produced by the document scanner)
/// rather than a freshly rendered PDF page. Used by `ScanEstimateController`
/// for the live "what would this scan compress to" preview.
Uint8List recompressImageAsJpeg((Uint8List imageBytes, int quality) args) {
  final (imageBytes, quality) = args;
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    throw const PdfManipulationException('Could not process a scanned page.');
  }
  return img.encodeJpg(decoded, quality: quality);
}
