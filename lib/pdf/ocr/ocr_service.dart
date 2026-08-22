/// Runs on-device text recognition and produces a searchable PDF.
///
/// Unlike the rasterize-and-reassemble tools in `pdf/manipulation/` (which
/// only ever handle images), this one needs to draw real, selectable text
/// onto a page — something `pdf_combiner` cannot do — so it builds the
/// output PDF directly with the `pdf` package instead.
abstract class OcrService {
  /// Recognizes text on every page of [sourcePath] and writes a new PDF at
  /// [outputPath] — each page is the original page rendered as an image
  /// with an invisible text layer positioned over the recognized words, so
  /// the page looks identical but becomes searchable and selectable.
  /// Returns the number of characters recognized across the whole document
  /// (0 means nothing was found).
  Future<int> makeSearchable({required String sourcePath, required String outputPath});
}
