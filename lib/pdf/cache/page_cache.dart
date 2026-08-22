import 'dart:ui' as ui;

/// Interface seam for a future tile-aware page cache. `pdfrx`'s own
/// `PdfViewerParams.maxImageBytesCachedOnMemory` already bounds page-image
/// memory for the interactive viewer, so this has no real implementation in
/// Phase 1 — it exists so high-zoom tile rendering can be added later
/// without reshaping call sites.
class PageCacheKey {
  const PageCacheKey({required this.documentId, required this.pageNumber, required this.zoom});

  final int documentId;
  final int pageNumber;
  final double zoom;

  @override
  bool operator ==(Object other) =>
      other is PageCacheKey &&
      other.documentId == documentId &&
      other.pageNumber == pageNumber &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(documentId, pageNumber, zoom);
}

abstract class PageCache {
  ui.Image? get(PageCacheKey key);
  void put(PageCacheKey key, ui.Image image);
  bool remove(PageCacheKey key);
  void clear();
}
