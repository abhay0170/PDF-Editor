import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/bookmarks_table.dart';

part 'bookmark_dao.g.dart';

@DriftAccessor(tables: [Bookmarks])
class BookmarkDao extends DatabaseAccessor<AppDatabase> with _$BookmarkDaoMixin {
  BookmarkDao(super.db);

  Stream<List<Bookmark>> watchForDocument(int documentId) {
    final query = select(bookmarks)
      ..where((t) => t.documentId.equals(documentId))
      ..orderBy([(t) => OrderingTerm.asc(t.page)]);
    return query.watch();
  }

  Future<int> insertBookmark(BookmarksCompanion entry) {
    return into(bookmarks).insert(entry);
  }

  Future<int> deleteById(int id) {
    return (delete(bookmarks)..where((t) => t.id.equals(id))).go();
  }
}
