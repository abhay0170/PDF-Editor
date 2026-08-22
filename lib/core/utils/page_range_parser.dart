/// Parses page-range input like `"1-3, 5, 7-9"` into a sorted, deduplicated
/// list of 1-based page numbers, validated against [pageCount].
///
/// Throws [FormatException] with a user-presentable message on invalid
/// input (empty, non-numeric, reversed range, or out of bounds).
List<int> parsePageRanges(String input, {required int pageCount}) {
  final segments = input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) {
    throw const FormatException('Enter at least one page or range, e.g. "1-3, 5".');
  }

  final pages = <int>{};

  for (final segment in segments) {
    final rangeParts = segment.split('-').map((s) => s.trim()).toList();

    if (rangeParts.length == 1) {
      final page = int.tryParse(rangeParts[0]);
      if (page == null) {
        throw FormatException('"$segment" is not a valid page number.');
      }
      _validatePage(page, pageCount, segment);
      pages.add(page);
    } else if (rangeParts.length == 2) {
      final start = int.tryParse(rangeParts[0]);
      final end = int.tryParse(rangeParts[1]);
      if (start == null || end == null) {
        throw FormatException('"$segment" is not a valid page range.');
      }
      _validatePage(start, pageCount, segment);
      _validatePage(end, pageCount, segment);
      if (end < start) {
        throw FormatException('"$segment" is backwards — start must be ≤ end.');
      }
      for (var page = start; page <= end; page++) {
        pages.add(page);
      }
    } else {
      throw FormatException('"$segment" is not a valid page or range.');
    }
  }

  final sorted = pages.toList()..sort();
  return sorted;
}

void _validatePage(int page, int pageCount, String segment) {
  if (page < 1 || page > pageCount) {
    throw FormatException('"$segment" is out of range — this document has $pageCount pages.');
  }
}
