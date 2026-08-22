import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pdf_providers.dart';
import 'mlkit_ocr_service.dart';
import 'ocr_service.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  return MlKitOcrService(ref.watch(pdfEngineProvider));
});
