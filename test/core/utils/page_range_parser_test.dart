import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/utils/page_range_parser.dart';

void main() {
  group('parsePageRanges valid input', () {
    test('parses a single page', () {
      expect(parsePageRanges('5', pageCount: 10), [5]);
    });

    test('parses a simple range', () {
      expect(parsePageRanges('1-3', pageCount: 10), [1, 2, 3]);
    });

    test('parses a mix of pages and ranges', () {
      expect(parsePageRanges('1-3, 5, 7-9', pageCount: 10), [1, 2, 3, 5, 7, 8, 9]);
    });

    test('dedupes and sorts overlapping input', () {
      expect(parsePageRanges('5, 3, 1-4', pageCount: 10), [1, 2, 3, 4, 5]);
    });

    test('tolerates extra whitespace', () {
      expect(parsePageRanges('  1 - 3 ,  5  ', pageCount: 10), [1, 2, 3, 5]);
    });

    test('a range of a single page is valid', () {
      expect(parsePageRanges('4-4', pageCount: 10), [4]);
    });
  });

  group('parsePageRanges invalid input', () {
    test('throws on empty input', () {
      expect(() => parsePageRanges('', pageCount: 10), throwsFormatException);
    });

    test('throws on whitespace-only input', () {
      expect(() => parsePageRanges('   ', pageCount: 10), throwsFormatException);
    });

    test('throws on non-numeric page', () {
      expect(() => parsePageRanges('abc', pageCount: 10), throwsFormatException);
    });

    test('throws on a reversed range', () {
      expect(() => parsePageRanges('5-3', pageCount: 10), throwsFormatException);
    });

    test('throws when a page is below 1', () {
      expect(() => parsePageRanges('0', pageCount: 10), throwsFormatException);
    });

    test('throws when a page exceeds the page count', () {
      expect(() => parsePageRanges('11', pageCount: 10), throwsFormatException);
    });

    test('throws when a range partially exceeds the page count', () {
      expect(() => parsePageRanges('8-11', pageCount: 10), throwsFormatException);
    });

    test('throws on a malformed range with too many parts', () {
      expect(() => parsePageRanges('1-2-3', pageCount: 10), throwsFormatException);
    });
  });
}
