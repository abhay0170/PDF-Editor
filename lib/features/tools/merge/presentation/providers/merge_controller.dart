import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../core/constants/storage_constants.dart';
import '../../../../../core/errors/pdf_exceptions.dart';
import '../../../../../database/app_database.dart';
import '../../../../../pdf/manipulation/pdf_manipulation_providers.dart';
import '../../../domain/tool_run_state.dart';
import '../../../tool_result_inserter.dart';

typedef MergeState = ToolRunState<int>;

class MergeController extends AsyncNotifier<MergeState> {
  @override
  FutureOr<MergeState> build() => const ToolIdle();

  Future<void> merge(List<Document> orderedDocuments) async {
    if (orderedDocuments.length < 2) {
      state = const AsyncData(ToolError('Select at least two PDFs to merge.'));
      return;
    }

    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final displayName = 'Merged ${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outputPath = p.join(docsDir.path, displayName);

      final resultPath = await ref.read(pdfManipulationServiceProvider).mergePdfs(
        sourcePaths: orderedDocuments.map((d) => d.path).toList(),
        outputPath: outputPath,
      );

      final documentId = await insertToolResult(ref, path: resultPath, displayName: displayName);
      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not merge these documents.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final mergeControllerProvider = AsyncNotifierProvider<MergeController, MergeState>(MergeController.new);
