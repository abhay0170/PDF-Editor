import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/pdf_exceptions.dart';
import '../../../../core/utils/compression_params.dart';
import '../../../../database/app_database.dart';
import '../../../../pdf/manipulation/pdf_manipulation_providers.dart';
import '../../../tools/domain/tool_run_state.dart';

/// Result of a download: `true` if the user completed the system save
/// dialog, `false` if they canceled it.
typedef DownloadState = ToolRunState<bool>;

/// Saves a copy of a document at a chosen quality — at `qualityPercent >=
/// 100` this saves the original bytes untouched; below that it compresses
/// to a scratch file first (same approach as [CompressController]) and
/// saves the compressed result, discarding the scratch file afterward.
class DownloadController extends AsyncNotifier<DownloadState> {
  @override
  FutureOr<DownloadState> build() => const ToolIdle();

  Future<void> download(Document source, double qualityPercent) async {
    state = const AsyncData(ToolProcessing());
    try {
      final atOriginalQuality = qualityPercent >= 100;
      var pathToSave = source.path;

      if (!atOriginalQuality) {
        final params = compressionParamsForQuality(qualityPercent);
        final tempDir = await getTemporaryDirectory();
        final outputPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_download.pdf');
        pathToSave = await ref
            .read(pdfManipulationServiceProvider)
            .compressPdf(sourcePath: source.path, outputPath: outputPath, scale: params.scale, quality: params.quality);
      }

      final bytes = await File(pathToSave).readAsBytes();
      final savedUri = await FilePicker.saveFile(
        fileName: source.displayName,
        bytes: bytes,
        mimeType: 'application/pdf',
      );

      if (!atOriginalQuality) {
        try {
          await File(pathToSave).delete();
        } catch (_) {
          // Scratch file cleanup is best-effort.
        }
      }

      state = AsyncData(ToolSuccess(savedUri != null));
    } on PdfManipulationException catch (e) {
      state = AsyncData(ToolError(e.message));
    } catch (_) {
      state = const AsyncData(ToolError('Could not download this document.'));
    }
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final downloadControllerProvider = AsyncNotifierProvider<DownloadController, DownloadState>(
  DownloadController.new,
);
