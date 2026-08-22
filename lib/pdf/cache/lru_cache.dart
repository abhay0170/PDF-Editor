/// A generic bounded LRU cache: entries are evicted, oldest-access-first,
/// once either [maxEntries] or [maxBytes] is exceeded. [sizeOf] estimates
/// the in-memory footprint of a value (e.g. `width * height * 4` for a
/// decoded bitmap) so the byte budget reflects real memory, not just count.
class LruCache<K, V> {
  LruCache({required this.maxEntries, required this.maxBytes, required this.sizeOf})
    : assert(maxEntries > 0),
      assert(maxBytes > 0);

  final int maxEntries;
  final int maxBytes;
  final int Function(V value) sizeOf;

  final _entries = <K, V>{};
  final _sizes = <K, int>{};
  int _currentBytes = 0;

  int get currentBytes => _currentBytes;
  int get length => _entries.length;

  bool contains(K key) => _entries.containsKey(key);

  /// Returns the cached value for [key], marking it most-recently-used, or
  /// null if absent.
  V? get(K key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    // Re-insert to move this entry to the end (most-recently-used) of the
    // LinkedHashMap's iteration order.
    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    final previousSize = _sizes.remove(key);
    if (previousSize != null) {
      _currentBytes -= previousSize;
      _entries.remove(key);
    }

    final size = sizeOf(value);
    _entries[key] = value;
    _sizes[key] = size;
    _currentBytes += size;

    _evictIfNeeded();
  }

  bool remove(K key) {
    final value = _entries.remove(key);
    final size = _sizes.remove(key);
    if (size != null) _currentBytes -= size;
    return value != null;
  }

  void clear() {
    _entries.clear();
    _sizes.clear();
    _currentBytes = 0;
  }

  void _evictIfNeeded() {
    while (_entries.isNotEmpty && (_entries.length > maxEntries || _currentBytes > maxBytes)) {
      final oldestKey = _entries.keys.first;
      remove(oldestKey);
    }
  }
}
