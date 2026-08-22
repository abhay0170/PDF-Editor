import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf_reader/pdf/signature/signature_renderer.dart';

void main() {
  testWidgets('composites a signature onto a page without changing page dimensions', (tester) async {
    final page = img.Image(width: 400, height: 600);
    img.fill(page, color: img.ColorRgb8(255, 255, 255));
    final pageBytes = img.encodePng(page);

    final signature = img.Image(width: 200, height: 80, numChannels: 4);
    img.fill(signature, color: img.ColorRgba8(0, 0, 0, 0));
    img.drawLine(signature, x1: 10, y1: 40, x2: 190, y2: 40, color: img.ColorRgba8(0, 0, 0, 255));
    final signatureBytes = img.encodePng(signature);

    // signature_renderer awaits real dart:ui codec/rasterization callbacks,
    // which never fire inside testWidgets' FakeAsync zone without runAsync.
    final resultBytes = await tester.runAsync(
      () => compositeSignature(
        pageBytes,
        signaturePngBytes: signatureBytes,
        relativeX: 0.5,
        relativeY: 0.8,
        relativeWidth: 0.3,
      ),
    );

    final decoded = img.decodePng(resultBytes!);
    expect(decoded, isNotNull);
    expect(decoded!.width, 400);
    expect(decoded.height, 600);
    // The signature must have actually drawn something onto the page.
    expect(resultBytes, isNot(equals(pageBytes)));
  });
}
