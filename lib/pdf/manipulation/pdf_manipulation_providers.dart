import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pdf_providers.dart';
import 'pdf_combiner_manipulation_service.dart';
import 'pdf_manipulation_service.dart';

final pdfManipulationServiceProvider = Provider<PdfManipulationService>((ref) {
  return PdfCombinerManipulationService(ref.watch(pdfEngineProvider));
});
