import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../core/constants/storage_constants.dart';
import '../../../../../core/errors/pdf_exceptions.dart';
import '../../../../../database/app_database.dart';
import '../../../../../pdf/ocr/ocr_providers.dart';
import '../../../domain/tool_run_state.dart';
import '../../../tool_result_inserter.dart';

typedef OcrState = ToolRunState<int>;

class OcrController extends AsyncNotifier<OcrState> {
  @override
  FutureOr<OcrState> build() => const ToolIdle();

  Future<void> makeSearchable(Document source) async {
    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final baseName = p.basenameWithoutExtension(source.displayName);
      final displayName = '$baseName (searchable).pdf';
      final outputPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_ocr.pdf');

      final recognizedChars = await ref
          .read(ocrServiceProvider)
          .makeSearchable(sourcePath: source.path, outputPath: outputPath);

      if (recognizedChars == 0) {
        await File(outputPath).delete().catchError((_) => File(outputPath));
        state = const AsyncData(ToolError('No text was found in this document.'));
        return;
      }

      final documentId = await insertToolResult(ref, path: outputPath, displayName: displayName);
      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not recognize text in this document.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final ocrControllerProvider = AsyncNotifierProvider<OcrController, OcrState>(OcrController.new);
