import 'package:drift/drift.dart';

@TableIndex(name: 'idx_documents_last_opened', columns: {#lastOpenedAt})
@TableIndex(name: 'idx_documents_display_name', columns: {#displayName})
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
}
