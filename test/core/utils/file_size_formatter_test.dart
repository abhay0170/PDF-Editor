import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/utils/file_size_formatter.dart';

void main() {
  group('formatFileSize', () {
    test('formats byte counts under 1KB as bytes', () {
      expect(formatFileSize(512), '512 B');
    });

    test('formats kilobyte-range sizes with one decimal', () {
      expect(formatFileSize(2048), '2.0 KB');
    });

    test('formats megabyte-range sizes with one decimal', () {
      expect(formatFileSize(5 * 1024 * 1024), '5.0 MB');
    });

    test('formats gigabyte-range sizes with one decimal', () {
      expect(formatFileSize(3 * 1024 * 1024 * 1024), '3.0 GB');
    });
  });
}
