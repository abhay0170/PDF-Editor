import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../database/database_providers.dart';
import '../../pdf/models/pdf_document_info.dart';
import '../../pdf/pdf_providers.dart';

/// Inserts a tool-generated PDF (merge/split/rotate/extract output) into the
/// library — same probe-then-insert shape [ImportController] uses for
/// picked files, so results show up in the Library exactly like an import.
Future<int> insertToolResult(Ref ref, {required String path, required String displayName}) async {
  final engine = ref.read(pdfEngineProvider);
  final probeResult = await engine.probe(path);
  final pageCount = switch (probeResult) {
    PdfProbeOk(:final info) => info.pageCount,
    _ => 0,
  };
  final fileSize = await File(path).length();
  final now = DateTime.now();

  final id = await ref.read(documentDaoProvider).insertDocument(
    DocumentsCompanion.insert(
      path: path,
      displayName: displayName,
      pageCount: Value(pageCount),
      fileSize: fileSize,
      createdAt: now,
      modifiedAt: now,
    ),
  );

  unawaited(indexDocumentContent(ref, documentId: id, path: path));
  return id;
}

/// Extracts and stores [Document.content] for library-wide search — best
/// effort, same fire-and-forget shape as thumbnail generation, since it must
/// never delay a document showing up after import/scan/a tool run.
Future<void> indexDocumentContent(Ref ref, {required int documentId, required String path}) async {
  try {
    final text = await ref.read(pdfEngineProvider).extractText(path);
    if (text.isNotEmpty) {
      await ref.read(documentDaoProvider).updateContent(documentId, text);
    }
  } catch (_) {
    // Best-effort; the document just won't be content-searchable.
  }
}
