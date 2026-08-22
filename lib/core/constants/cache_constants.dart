/// Tunable cache/prefetch budgets. Kept in one place so they can be adjusted
/// after benchmarking without hunting through the codebase.
class CacheConstants {
  const CacheConstants._();

  /// In-memory thumbnail cache budget (encoded PNG bytes, not decoded bitmaps).
  static const int thumbnailCacheMaxBytes = 32 * 1024 * 1024;
  static const int thumbnailCacheMaxEntries = 200;

  /// Thumbnail render target size (logical pixels, upscaled for device pixel ratio by the caller).
  static const double thumbnailWidth = 160;
  static const double thumbnailHeight = 220;

  /// pdfrx's own bounded page-image cache (see PdfViewerParams.maxImageBytesCachedOnMemory).
  static const int viewerMaxImageBytesCachedOnMemory = 100 * 1024 * 1024;
}
