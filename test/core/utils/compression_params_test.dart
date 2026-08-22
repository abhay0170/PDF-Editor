import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/utils/compression_params.dart';

void main() {
  group('compressionParamsForQuality', () {
    test('maps the minimum slider value to the lowest scale and quality', () {
      final params = compressionParamsForQuality(10);
      expect(params.quality, 10);
      expect(params.scale, 1.0);
    });

    test('maps the maximum slider value to the highest scale and quality', () {
      final params = compressionParamsForQuality(100);
      expect(params.quality, 100);
      expect(params.scale, 2.0);
    });

    test('interpolates scale linearly between the endpoints', () {
      final params = compressionParamsForQuality(55);
      expect(params.quality, 55);
      expect(params.scale, closeTo(1.5, 0.01));
    });

    test('clamps values outside the 10-100 range', () {
      expect(compressionParamsForQuality(0).quality, 10);
      expect(compressionParamsForQuality(500).quality, 100);
    });
  });
}
