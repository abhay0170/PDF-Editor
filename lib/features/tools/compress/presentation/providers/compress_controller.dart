import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../core/constants/storage_constants.dart';
import '../../../../../core/errors/pdf_exceptions.dart';
import '../../../../../core/utils/compression_params.dart';
import '../../../../../database/app_database.dart';
import '../../../../../pdf/manipulation/pdf_manipulation_providers.dart';
import '../../../domain/tool_run_state.dart';
import '../../../tool_result_inserter.dart';

typedef CompressState = ToolRunState<int>;

class CompressController extends AsyncNotifier<CompressState> {
  @override
  FutureOr<CompressState> build() => const ToolIdle();

  Future<void> compress(Document source, double qualityPercent) async {
    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final baseName = p.basenameWithoutExtension(source.displayName);
      final outputPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.pdf');

      final params = compressionParamsForQuality(qualityPercent);
      final resultPath = await ref
          .read(pdfManipulationServiceProvider)
          .compressPdf(sourcePath: source.path, outputPath: outputPath, scale: params.scale, quality: params.quality);

      final originalSize = await File(source.path).length();
      final newSize = await File(resultPath).length();
      final reduction = originalSize > 0 ? (100 - (newSize * 100 / originalSize)).round() : 0;
      final displayName = reduction > 0
          ? '$baseName (compressed, $reduction% smaller).pdf'
          : '$baseName (compressed).pdf';

      final documentId = await insertToolResult(ref, path: resultPath, displayName: displayName);
      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not compress this document.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final compressControllerProvider = AsyncNotifierProvider<CompressController, CompressState>(
  CompressController.new,
);
