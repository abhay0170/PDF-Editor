import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../core/constants/storage_constants.dart';
import '../../../../../core/errors/pdf_exceptions.dart';
import '../../../../../database/app_database.dart';
import '../../../../../pdf/manipulation/pdf_manipulation_providers.dart';
import '../../../domain/tool_run_state.dart';
import '../../../tool_result_inserter.dart';

typedef SignState = ToolRunState<int>;

class SignController extends AsyncNotifier<SignState> {
  @override
  FutureOr<SignState> build() => const ToolIdle();

  Future<void> sign(
    Document source, {
    required int pageNumber,
    required Uint8List signatureImageBytes,
    required double relativeX,
    required double relativeY,
    required double relativeWidth,
  }) async {
    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final baseName = p.basenameWithoutExtension(source.displayName);
      final displayName = '$baseName (signed).pdf';
      final outputPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_signed.pdf');

      final resultPath = await ref.read(pdfManipulationServiceProvider).signPdf(
        sourcePath: source.path,
        outputPath: outputPath,
        pageNumber: pageNumber,
        signatureImageBytes: signatureImageBytes,
        relativeX: relativeX,
        relativeY: relativeY,
        relativeWidth: relativeWidth,
      );

      final documentId = await insertToolResult(ref, path: resultPath, displayName: displayName);
      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not sign this document.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final signControllerProvider = AsyncNotifierProvider<SignController, SignState>(SignController.new);
