import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/pdf/cache/lru_cache.dart';

void main() {
  group('LruCache entry-count eviction', () {
    test('evicts the least-recently-used entry once maxEntries is exceeded', () {
      final cache = LruCache<int, String>(
        maxEntries: 2,
        maxBytes: 1000,
        sizeOf: (_) => 1,
      );

      cache.put(1, 'a');
      cache.put(2, 'b');
      cache.put(3, 'c'); // evicts key 1

      expect(cache.contains(1), isFalse);
      expect(cache.contains(2), isTrue);
      expect(cache.contains(3), isTrue);
      expect(cache.length, 2);
    });

    test('get() refreshes recency so it is not the next eviction victim', () {
      final cache = LruCache<int, String>(
        maxEntries: 2,
        maxBytes: 1000,
        sizeOf: (_) => 1,
      );

      cache.put(1, 'a');
      cache.put(2, 'b');
      cache.get(1); // 1 is now most-recently-used; 2 is now the LRU entry
      cache.put(3, 'c'); // evicts key 2, not key 1

      expect(cache.contains(1), isTrue);
      expect(cache.contains(2), isFalse);
      expect(cache.contains(3), isTrue);
    });
  });

  group('LruCache byte-budget eviction', () {
    test('evicts oldest entries once maxBytes is exceeded', () {
      final cache = LruCache<int, String>(
        maxEntries: 100,
        maxBytes: 10,
        sizeOf: (v) => v.length,
      );

      cache.put(1, 'aaaa'); // 4 bytes
      cache.put(2, 'bbbb'); // 4 bytes, total 8
      cache.put(3, 'cccc'); // 4 bytes, total 12 > 10 -> evict key 1 (total 8)

      expect(cache.contains(1), isFalse);
      expect(cache.contains(2), isTrue);
      expect(cache.contains(3), isTrue);
      expect(cache.currentBytes, 8);
    });

    test('a single oversized entry evicts everything else to make room', () {
      final cache = LruCache<int, String>(
        maxEntries: 100,
        maxBytes: 10,
        sizeOf: (v) => v.length,
      );

      cache.put(1, 'aa'); // 2 bytes
      cache.put(2, 'bbbbbbbbbb'); // 10 bytes -> evicts key 1

      expect(cache.contains(1), isFalse);
      expect(cache.contains(2), isTrue);
      expect(cache.currentBytes, 10);
    });
  });

  group('LruCache accounting correctness', () {
    test('put() on an existing key replaces its size rather than double-counting', () {
      final cache = LruCache<int, String>(
        maxEntries: 100,
        maxBytes: 1000,
        sizeOf: (v) => v.length,
      );

      cache.put(1, 'aa'); // 2 bytes
      cache.put(1, 'aaaaaa'); // replace with 6 bytes

      expect(cache.currentBytes, 6);
      expect(cache.length, 1);
    });

    test('remove() decrements currentBytes and returns whether the key existed', () {
      final cache = LruCache<int, String>(
        maxEntries: 100,
        maxBytes: 1000,
        sizeOf: (v) => v.length,
      );

      cache.put(1, 'aaaa');
      final removed = cache.remove(1);
      final removedAgain = cache.remove(1);

      expect(removed, isTrue);
      expect(removedAgain, isFalse);
      expect(cache.currentBytes, 0);
      expect(cache.contains(1), isFalse);
    });

    test('clear() resets entries and byte accounting', () {
      final cache = LruCache<int, String>(
        maxEntries: 100,
        maxBytes: 1000,
        sizeOf: (v) => v.length,
      );

      cache.put(1, 'aaaa');
      cache.put(2, 'bbbb');
      cache.clear();

      expect(cache.length, 0);
      expect(cache.currentBytes, 0);
      expect(cache.contains(1), isFalse);
    });

    test('get() on a missing key returns null without side effects', () {
      final cache = LruCache<int, String>(
        maxEntries: 100,
        maxBytes: 1000,
        sizeOf: (v) => v.length,
      );

      expect(cache.get(42), isNull);
      expect(cache.length, 0);
    });
  });
}
