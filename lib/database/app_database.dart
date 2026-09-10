import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/constants/storage_constants.dart';
import 'daos/bookmark_dao.dart';
import 'daos/document_dao.dart';
import 'daos/folder_dao.dart';
import 'daos/settings_dao.dart';
import 'tables/bookmarks_table.dart';
import 'tables/documents_table.dart';
import 'tables/folders_table.dart';
import 'tables/settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Documents, Bookmarks, SettingsEntries, Folders],
  daos: [DocumentDao, BookmarkDao, SettingsDao, FolderDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: StorageConstants.databaseFileName));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(documents, documents.content);
      }
      if (from < 3) {
        await m.createTable(folders);
        await m.addColumn(documents, documents.folderId);
        // idx_documents_last_opened/display_name and idx_bookmarks_document_id
        // have existed since the very first schema (v1) and so are already
        // present on any upgrading database via its original onCreate — only
        // this index is new, introduced alongside the folderId column above.
        await m.createIndex(idxDocumentsFolderId);
      }
    },
  );
}
