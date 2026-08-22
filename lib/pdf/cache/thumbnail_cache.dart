import 'dart:typed_data';

import '../../core/constants/cache_constants.dart';
import 'lru_cache.dart';

/// In-memory cache of encoded (PNG) thumbnail bytes, keyed by document id.
/// The on-disk copy (see [Document.thumbnailPath]) survives cold starts;
/// this cache only avoids re-reading/re-decoding the file on every rebuild.
class ThumbnailCache {
  ThumbnailCache()
    : _cache = LruCache<int, Uint8List>(
        maxEntries: CacheConstants.thumbnailCacheMaxEntries,
        maxBytes: CacheConstants.thumbnailCacheMaxBytes,
        sizeOf: (bytes) => bytes.lengthInBytes,
      );

  final LruCache<int, Uint8List> _cache;

  Uint8List? get(int documentId) => _cache.get(documentId);

  void put(int documentId, Uint8List pngBytes) => _cache.put(documentId, pngBytes);

  bool remove(int documentId) => _cache.remove(documentId);

  void clear() => _cache.clear();
}
