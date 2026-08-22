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

typedef RotateState = ToolRunState<int>;

class RotateController extends AsyncNotifier<RotateState> {
  @override
  FutureOr<RotateState> build() => const ToolIdle();

  Future<void> rotate(Document source, Set<int> pageNumbers, int degrees) async {
    if (pageNumbers.isEmpty) {
      state = const AsyncData(ToolError('Choose at least one page to rotate.'));
      return;
    }

    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final baseName = p.basenameWithoutExtension(source.displayName);
      final displayName = '$baseName (rotated).pdf';
      final outputPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_rotated.pdf');

      final resultPath = await ref.read(pdfManipulationServiceProvider).rotatePages(
        sourcePath: source.path,
        pageNumbers: pageNumbers,
        degrees: degrees,
        outputPath: outputPath,
      );

      final documentId = await insertToolResult(ref, path: resultPath, displayName: displayName);
      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not rotate this document.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final rotateControllerProvider = AsyncNotifierProvider<RotateController, RotateState>(
  RotateController.new,
);
