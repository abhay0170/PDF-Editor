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

typedef SplitState = ToolRunState<List<int>>;

class SplitController extends AsyncNotifier<SplitState> {
  @override
  FutureOr<SplitState> build() => const ToolIdle();

  Future<void> split(Document source, List<List<int>> pageRanges) async {
    if (pageRanges.isEmpty) {
      state = const AsyncData(ToolError('Add at least one part to split out.'));
      return;
    }

    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final baseName = p.basenameWithoutExtension(source.displayName);
      final outputDir = Directory(
        p.join(appDir.path, StorageConstants.documentsSubdir, 'split_${DateTime.now().millisecondsSinceEpoch}'),
      );

      final outputPaths = await ref.read(pdfManipulationServiceProvider).splitPdf(
        sourcePath: source.path,
        pageRanges: pageRanges,
        outputDir: outputDir.path,
      );

      final documentIds = <int>[];
      for (var i = 0; i < outputPaths.length; i++) {
        final displayName = '$baseName (part ${i + 1}).pdf';
        documentIds.add(
          await insertToolResult(ref, path: outputPaths[i], displayName: displayName),
        );
      }

      state = AsyncData(ToolSuccess(documentIds));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not split this document.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final splitControllerProvider = AsyncNotifierProvider<SplitController, SplitState>(SplitController.new);
