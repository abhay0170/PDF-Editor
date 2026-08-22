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

  return ref.read(documentDaoProvider).insertDocument(
    DocumentsCompanion.insert(
      path: path,
      displayName: displayName,
      pageCount: Value(pageCount),
      fileSize: fileSize,
      createdAt: now,
      modifiedAt: now,
    ),
  );
}
