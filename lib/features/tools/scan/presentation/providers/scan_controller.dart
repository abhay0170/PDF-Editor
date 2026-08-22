import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../../core/constants/storage_constants.dart';
import '../../../../../core/errors/pdf_exceptions.dart';
import '../../../../../core/utils/compression_params.dart';
import '../../../../../pdf/manipulation/pdf_manipulation_providers.dart';
import '../../../domain/tool_run_state.dart';
import '../../../tool_result_inserter.dart';

typedef ScanState = ToolRunState<int>;

class ScanController extends AsyncNotifier<ScanState> {
  @override
  FutureOr<ScanState> build() => const ToolIdle();

  /// Assembles the scanned pages into a PDF (compressed to [qualityPercent]
  /// if below 100), adds it to the library the same way every other tool
  /// does, then offers a copy to [exportFolder] (or wherever the user picks)
  /// via the system save dialog — mirrors [DownloadController.download].
  Future<void> save(
    List<String> scannedImagePaths, {
    required String fileName,
    required double qualityPercent,
    String? exportFolder,
  }) async {
    if (scannedImagePaths.isEmpty) {
      state = const AsyncData(ToolError('Scan at least one page first.'));
      return;
    }

    state = const AsyncData(ToolProcessing());
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
      await docsDir.create(recursive: true);
      final displayName = fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf';
      final rawOutputPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_$displayName');

      final pdfService = ref.read(pdfManipulationServiceProvider);
      var resultPath = await pdfService.createPdfFromImages(
        imagePaths: scannedImagePaths,
        outputPath: rawOutputPath,
      );

      if (qualityPercent < 100) {
        final params = compressionParamsForQuality(qualityPercent);
        final compressedPath = p.join(docsDir.path, '${DateTime.now().millisecondsSinceEpoch}_$displayName');
        resultPath = await pdfService.compressPdf(
          sourcePath: resultPath,
          outputPath: compressedPath,
          scale: params.scale,
          quality: params.quality,
        );
        try {
          await File(rawOutputPath).delete();
        } catch (_) {
          // Scratch file cleanup is best-effort.
        }
      }

      final documentId = await insertToolResult(ref, path: resultPath, displayName: displayName);

      try {
        final bytes = await File(resultPath).readAsBytes();
        await FilePicker.saveFile(
          fileName: displayName,
          bytes: bytes,
          mimeType: 'application/pdf',
          initialDirectory: exportFolder,
        );
      } catch (_) {
        // The document is already saved to the library; a failed/canceled
        // export copy shouldn't surface as an error.
      }

      state = AsyncData(ToolSuccess(documentId));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not save the scanned pages as a PDF.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final scanControllerProvider = AsyncNotifierProvider<ScanController, ScanState>(ScanController.new);
