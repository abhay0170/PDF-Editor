import 'package:drift/drift.dart';

import 'documents_table.dart';

@TableIndex(name: 'idx_bookmarks_document_id', columns: {#documentId})
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get page => integer()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}
