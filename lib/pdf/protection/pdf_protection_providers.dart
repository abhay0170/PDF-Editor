import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pdf_protection_service.dart';
import 'syncfusion_pdf_protection_service.dart';

final pdfProtectionServiceProvider = Provider<PdfProtectionService>((ref) {
  return SyncfusionPdfProtectionService();
});
