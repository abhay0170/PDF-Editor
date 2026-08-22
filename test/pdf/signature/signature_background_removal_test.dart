import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_reader/pdf/signature/signature_background_removal.dart';

void main() {
  test('makes light background transparent and keeps dark ink opaque', () {
    final photo = img.Image(width: 100, height: 100);
    img.fill(photo, color: img.ColorRgb8(250, 250, 250));
    img.drawLine(photo, x1: 10, y1: 50, x2: 90, y2: 50, color: img.ColorRgb8(20, 20, 20), thickness: 4);
    final photoBytes = img.encodePng(photo);

    final resultBytes = removeSignatureBackground(photoBytes);
    final result = img.decodePng(resultBytes);

    expect(result, isNotNull);
    expect(result!.width, 100);
    expect(result.height, 100);
    expect(result.numChannels, 4);

    final backgroundPixel = result.getPixel(5, 5);
    expect(backgroundPixel.a, lessThan(10));

    final inkPixel = result.getPixel(50, 50);
    expect(inkPixel.a, greaterThan(200));
    expect(inkPixel.r, lessThan(60));
  });

  test('throws for unreadable image bytes', () {
    expect(() => removeSignatureBackground(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
}
