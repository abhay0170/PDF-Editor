import 'dart:typed_data';

/// PDF-editing operations, separate from [PdfEngine] (rendering/reading).
///
/// [mergePdfs] preserves the original vector content. [splitPdf],
/// [extractPages], and [rotatePages] are **not** supported directly by the
/// underlying `pdf_combiner` library, so the implementation rasterizes the
/// needed pages through [PdfEngine] and reassembles them — the output pages
/// are images, not vector PDF content. Callers must disclose this to users.
abstract class PdfManipulationService {
  Future<String> mergePdfs({required List<String> sourcePaths, required String outputPath});

  /// One output PDF per entry in [pageRanges], written into [outputDir].
  Future<List<String>> splitPdf({
    required String sourcePath,
    required List<List<int>> pageRanges,
    required String outputDir,
  });

  Future<String> extractPages({
    required String sourcePath,
    required List<int> pageNumbers,
    required String outputPath,
  });

  /// Rotates only [pageNumbers] by [degrees] (90/180/270); all other pages
  /// are carried through unrotated. The whole document is rasterized either
  /// way since `pdf_combiner` has no page-level PDF write API.
  Future<String> rotatePages({
    required String sourcePath,
    required Set<int> pageNumbers,
    required int degrees,
    required String outputPath,
  });

  /// Assembles scanned page images (already cropped/enhanced by the device's
  /// document scanner) into a single PDF, one image per page, in order.
  Future<String> createPdfFromImages({required List<String> imagePaths, required String outputPath});

  /// Stamps [text] onto every page as a semi-transparent, tiled, rotated
  /// watermark. Rasterizes the whole document — same tradeoff as
  /// split/rotate/extract.
  Future<String> watermarkPdf({
    required String sourcePath,
    required String text,
    required String outputPath,
  });

  /// Re-renders every page at [scale] and re-encodes it as a JPEG at
  /// [quality] (1-100), then reassembles — the same rasterization tradeoff
  /// as split/rotate/extract/watermark, but chosen deliberately here to
  /// shrink file size rather than as a side effect. Callers typically derive
  /// both from a single slider value via `compressionParamsForQuality`.
  Future<String> compressPdf({
    required String sourcePath,
    required String outputPath,
    required double scale,
    required int quality,
  });

  /// Composites [signatureImageBytes] (a transparent-background signature
  /// image) onto [pageNumber] only, at [relativeX]/[relativeY] (top-left
  /// corner, as fractions of the page) and [relativeWidth] (as a fraction of
  /// the page width — height follows the signature's own aspect ratio).
  /// Every page — signed or not — is rasterized to reassemble the document,
  /// same tradeoff as the other manipulation tools.
  Future<String> signPdf({
    required String sourcePath,
    required String outputPath,
    required int pageNumber,
    required Uint8List signatureImageBytes,
    required double relativeX,
    required double relativeY,
    required double relativeWidth,
  });
}
