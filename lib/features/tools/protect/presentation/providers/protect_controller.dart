import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../core/constants/storage_constants.dart';
import '../../../../../core/errors/pdf_exceptions.dart';
import '../../../../../database/app_database.dart';
import '../../../../../pdf/protection/pdf_protection_providers.dart';
import '../../../domain/tool_run_state.dart';
import '../../../tool_result_inserter.dart';

typedef ProtectState = ToolRunState<int>;

class ProtectController extends AsyncNotifier<ProtectState> {
  @override
  FutureOr<ProtectState> build() => const ToolIdle();

  Future<void> addPassword(Document source, String password) async {
    if (password.isEmpty) {
      state = const AsyncData(ToolError('Enter a password.'));
      return;
    }
    await _run(
      source,
      suffix: 'protected',
      label: 'protected',
      run: (outputPath) => ref
          .read(pdfProtectionServiceProvider)
          .protect(sourcePath: source.path, outputPath: outputPath, password: password),
    );
  }

  Future<void> removePassword(Document source, String password) async {
    if (password.isEmpty) {
      state = const AsyncData(ToolError('Enter the document\'s password.'));
      return;
    }
    await _run(
      source,
      suffix: 'unlocked',
      label: 'unlocked',
      run: (outputPath) => ref
          .read(pdfProtectionServiceProvider)
          .removeProtection(sourcePath: source.path, outputPath: outputPath, password: password),
    );
  }

  Future<void> _run(
    Document source, {
    required String suffix,
    required String label,
    required Future<String> Function(String outputPath) run,
  }) async {
    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final baseName = p.basenameWithoutExtension(source.displayName);
      final displayName = '$baseName ($label).pdf';
      final outputPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_$suffix.pdf');

      final resultPath = await run(outputPath);

      final documentId = await insertToolResult(ref, path: resultPath, displayName: displayName);
      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not process this document.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final protectControllerProvider = AsyncNotifierProvider<ProtectController, ProtectState>(
  ProtectController.new,
);
