import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/constants/storage_constants.dart';
import 'daos/bookmark_dao.dart';
import 'daos/document_dao.dart';
import 'daos/settings_dao.dart';
import 'tables/bookmarks_table.dart';
import 'tables/documents_table.dart';
import 'tables/settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Documents, Bookmarks, SettingsEntries],
  daos: [DocumentDao, BookmarkDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: StorageConstants.databaseFileName));

  @override
  int get schemaVersion => 1;
}
