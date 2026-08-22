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

typedef ExtractState = ToolRunState<int>;

class ExtractController extends AsyncNotifier<ExtractState> {
  @override
  FutureOr<ExtractState> build() => const ToolIdle();

  Future<void> extract(Document source, List<int> pageNumbers) async {
    if (pageNumbers.isEmpty) {
      state = const AsyncData(ToolError('Choose at least one page to extract.'));
      return;
    }

    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final baseName = p.basenameWithoutExtension(source.displayName);
      final displayName = '$baseName (extracted).pdf';
      final outputPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_extracted.pdf');

      final resultPath = await ref.read(pdfManipulationServiceProvider).extractPages(
        sourcePath: source.path,
        pageNumbers: pageNumbers,
        outputPath: outputPath,
      );

      final documentId = await insertToolResult(ref, path: resultPath, displayName: displayName);
      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not extract these pages.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final extractControllerProvider = AsyncNotifierProvider<ExtractController, ExtractState>(
  ExtractController.new,
);
