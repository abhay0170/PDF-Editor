import 'package:drift/drift.dart';

import 'folders_table.dart';

@TableIndex(name: 'idx_documents_last_opened', columns: {#lastOpenedAt})
@TableIndex(name: 'idx_documents_display_name', columns: {#displayName})
@TableIndex(name: 'idx_documents_folder_id', columns: {#folderId})
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get displayName => text()();
  IntColumn get pageCount => integer().withDefault(const Constant(0))();
  IntColumn get fileSize => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  IntColumn get lastPage => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get thumbnailPath => text().nullable()();

  /// Concatenated text extracted from every page (best-effort, populated
  /// asynchronously after insert — see `indexDocumentContent` in
  /// `tool_result_inserter.dart`). Null until indexing completes or if the
  /// document has no extractable text (e.g. an un-OCR'd scan).
  TextColumn get content => text().nullable()();

  /// Null means unfiled (shown in "All" but no folder chip). Deleting a
  /// folder clears this rather than deleting the documents in it.
  IntColumn get folderId =>
      integer().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();
}
