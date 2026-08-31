import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../database/app_database.dart';
import '../../../../database/database_providers.dart';
import '../../../../pdf/models/pdf_document_info.dart';
import '../../../../pdf/pdf_providers.dart';
import '../../../tools/tool_result_inserter.dart';
import '../../domain/import_state.dart';

class ImportController extends AsyncNotifier<ImportState> {
  @override
  FutureOr<ImportState> build() => const ImportIdle();

  Future<void> pickAndImportPdf() async {
    state = const AsyncData(ImportPicking());

    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final pickedPath = result?.path;
    if (pickedPath == null) {
      state = const AsyncData(ImportIdle());
      return;
    }

    await _importFromPickedFile(pickedPath);
  }

  Future<void> retryWithPassword(String copiedPath, String password) async {
    await _finishImport(copiedPath, passwordProvider: () => password);
  }

  Future<void> cancelPendingImport(String copiedPath) async {
    try {
      await File(copiedPath).delete();
    } catch (_) {
      // Best-effort cleanup.
    }
    state = const AsyncData(ImportIdle());
  }

  void acknowledge() {
    state = const AsyncData(ImportIdle());
  }

  Future<void> _importFromPickedFile(String pickedPath) async {
    state = const AsyncData(ImportCopying());

    final sourceFile = File(pickedPath);
    if (!sourceFile.existsSync()) {
      state = const AsyncData(ImportCorrupted('The selected file could no longer be found.'));
      return;
    }

    final displayName = p.basename(pickedPath);
    final fileSize = await sourceFile.length();

    final duplicate = await ref
        .read(documentDaoProvider)
        .findDuplicate(displayName: displayName, fileSize: fileSize);
    if (duplicate != null) {
      state = AsyncData(ImportDuplicate(duplicate.id));
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(p.join(appDir.path, StorageConstants.documentsSubdir));
    await docsDir.create(recursive: true);
    final destPath = await _uniqueDestinationPath(docsDir.path, displayName);

    await sourceFile.copy(destPath);

    await _finishImport(destPath);
  }

  Future<void> _finishImport(String copiedPath, {PdfPasswordProvider? passwordProvider}) async {
    final engine = ref.read(pdfEngineProvider);
    final probeResult = await engine.probe(copiedPath, passwordProvider: passwordProvider);

    switch (probeResult) {
      case PdfProbeOk(:final info):
        await _insertAndFinish(copiedPath, info);
      case PdfProbePasswordRequired():
        state = AsyncData(
          ImportPasswordRequired(copiedPath, wrongPassword: passwordProvider != null),
        );
      case PdfProbeCorrupted(:final message):
        try {
          await File(copiedPath).delete();
        } catch (_) {
          // Best-effort cleanup; leaving an orphaned file is harmless.
        }
        state = AsyncData(ImportCorrupted(message));
      case PdfProbeMissingFile():
        state = const AsyncData(ImportCorrupted('The imported file could no longer be found.'));
    }
  }

  Future<void> _insertAndFinish(String path, PdfDocumentInfo info) async {
    final now = DateTime.now();
    final fileSize = await File(path).length();
    final documentDao = ref.read(documentDaoProvider);

    final id = await documentDao.insertDocument(
      DocumentsCompanion.insert(
        path: path,
        displayName: p.basename(path),
        pageCount: Value(info.pageCount),
        fileSize: fileSize,
        createdAt: now,
        modifiedAt: now,
      ),
    );

    state = AsyncData(ImportSuccess(id));

    unawaited(_generateThumbnail(id, path));
    unawaited(indexDocumentContent(ref, documentId: id, path: path));
  }

  Future<void> _generateThumbnail(int documentId, String path) async {
    try {
      final engine = ref.read(pdfEngineProvider);
      final pngBytes = await engine.renderPagePng(
        path,
        pageNumber: 1,
        width: CacheConstants.thumbnailWidth.round(),
        height: CacheConstants.thumbnailHeight.round(),
      );

      final appDir = await getApplicationDocumentsDirectory();
      final thumbsDir = Directory(p.join(appDir.path, StorageConstants.thumbnailsSubdir));
      await thumbsDir.create(recursive: true);
      final thumbPath = p.join(thumbsDir.path, '$documentId.png');
      await File(thumbPath).writeAsBytes(pngBytes);

      ref.read(thumbnailCacheProvider).put(documentId, pngBytes);
      await ref.read(documentDaoProvider).updateThumbnailPath(documentId, thumbPath);
    } catch (_) {
      // Thumbnail generation is best-effort; the library falls back to a
      // placeholder icon if this never completes.
    }
  }

  Future<String> _uniqueDestinationPath(String dirPath, String fileName) async {
    var candidate = p.join(dirPath, fileName);
    if (!File(candidate).existsSync()) return candidate;

    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    var counter = 1;
    do {
      candidate = p.join(dirPath, '$base ($counter)$ext');
      counter++;
    } while (File(candidate).existsSync());
    return candidate;
  }
}

final importControllerProvider = AsyncNotifierProvider<ImportController, ImportState>(
  ImportController.new,
);
