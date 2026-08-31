import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/folders_table.dart';

part 'folder_dao.g.dart';

@DriftAccessor(tables: [Folders])
class FolderDao extends DatabaseAccessor<AppDatabase> with _$FolderDaoMixin {
  FolderDao(super.db);

  Stream<List<Folder>> watchAll() {
    final query = select(folders)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }

  Future<int> insertFolder(String name) {
    return into(folders).insert(FoldersCompanion.insert(name: name, createdAt: DateTime.now()));
  }

  Future<void> rename(int id, String name) {
    return (update(folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(name: Value(name)),
    );
  }

  /// Deletes the folder; documents inside it become unfiled via the
  /// `Documents.folderId` foreign key's `setNull` action.
  Future<int> deleteById(int id) {
    return (delete(folders)..where((t) => t.id.equals(id))).go();
  }
}
