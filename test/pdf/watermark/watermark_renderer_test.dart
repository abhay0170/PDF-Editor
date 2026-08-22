import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_reader/pdf/watermark/watermark_renderer.dart';

void main() {
  testWidgets('stamps a watermark onto a page image without changing its dimensions', (tester) async {
    final source = img.Image(width: 200, height: 300);
    img.fill(source, color: img.ColorRgb8(255, 255, 255));
    final sourceBytes = img.encodePng(source);

    // applyTextWatermark awaits real dart:ui codec/rasterization callbacks,
    // which never fire inside testWidgets' FakeAsync zone — runAsync escapes
    // it so the native completions can actually land.
    final watermarkedBytes = await tester.runAsync(
      () => applyTextWatermark(sourceBytes, text: 'CONFIDENTIAL'),
    );

    final decoded = img.decodePng(watermarkedBytes!);
    expect(decoded, isNotNull);
    expect(decoded!.width, 200);
    expect(decoded.height, 300);
    // The watermark must have actually drawn something — the output can't be
    // byte-identical to a blank white page.
    expect(watermarkedBytes, isNot(equals(sourceBytes)));
  });
}
