import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/documents_table.dart';

part 'document_dao.g.dart';

enum DocumentSortField { name, lastOpened, dateAdded, pageCount }

class SortSpec {
  const SortSpec(this.field, {this.descending = false});

  final DocumentSortField field;
  final bool descending;
}

@DriftAccessor(tables: [Documents])
class DocumentDao extends DatabaseAccessor<AppDatabase> with _$DocumentDaoMixin {
  DocumentDao(super.db);

  Stream<List<Document>> watchAll({required SortSpec sort}) {
    final query = select(documents);
    switch (sort.field) {
      case DocumentSortField.name:
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.displayName,
            mode: sort.descending ? OrderingMode.desc : OrderingMode.asc,
          ),
        ]);
      case DocumentSortField.lastOpened:
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.lastOpenedAt,
            mode: sort.descending ? OrderingMode.desc : OrderingMode.asc,
          ),
        ]);
      case DocumentSortField.dateAdded:
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.createdAt,
            mode: sort.descending ? OrderingMode.desc : OrderingMode.asc,
          ),
        ]);
      case DocumentSortField.pageCount:
        query.orderBy([
          (t) => OrderingTerm(
            expression: t.pageCount,
            mode: sort.descending ? OrderingMode.desc : OrderingMode.asc,
          ),
        ]);
    }
    return query.watch();
  }

  Stream<List<Document>> watchRecent({int limit = 10}) {
    final query = select(documents)
      ..where((t) => t.lastOpenedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.lastOpenedAt)])
      ..limit(limit);
    return query.watch();
  }

  Future<Document?> findByPath(String path) {
    return (select(documents)..where((t) => t.path.equals(path))).getSingleOrNull();
  }

  Future<Document?> findById(int id) {
    return (select(documents)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Heuristic dedupe check for import: same display name and byte size.
  /// Not content-hash based, but cheap and good enough to catch the common
  /// "picked the same file twice" case without reading the whole file.
  Future<Document?> findDuplicate({required String displayName, required int fileSize}) {
    return (select(documents)..where(
          (t) => t.displayName.equals(displayName) & t.fileSize.equals(fileSize),
        ))
        .getSingleOrNull();
  }

  Future<int> insertDocument(DocumentsCompanion entry) {
    return into(documents).insert(entry);
  }

  Future<void> updateThumbnailPath(int id, String thumbnailPath) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(thumbnailPath: Value(thumbnailPath)),
    );
  }

  Future<void> updateContent(int id, String content) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(content: Value(content)),
    );
  }

  Stream<List<Document>> watchByFolder(int folderId) {
    return (select(documents)..where((t) => t.folderId.equals(folderId))).watch();
  }

  /// Pass `null` to unfile the document.
  Future<void> setFolder(int id, int? folderId) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(folderId: Value(folderId)),
    );
  }

  Future<void> markOpened(int id, {required int lastPage}) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(
        lastOpenedAt: Value(DateTime.now()),
        lastPage: Value(lastPage),
      ),
    );
  }

  /// Bumps [Document.lastOpenedAt] (for the Recent row) without touching
  /// [Document.lastPage] — call [updateLastPage] separately as the user
  /// actually navigates.
  Future<void> touchOpened(int id) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(lastOpenedAt: Value(DateTime.now())),
    );
  }

  Future<void> updateLastPage(int id, int lastPage) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(lastPage: Value(lastPage)),
    );
  }

  Future<void> setFavorite(int id, bool isFavorite) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(isFavorite: Value(isFavorite)),
    );
  }

  Future<void> rename(int id, String displayName) {
    return (update(documents)..where((t) => t.id.equals(id))).write(
      DocumentsCompanion(displayName: Value(displayName)),
    );
  }

  Future<int> deleteById(int id) {
    return (delete(documents)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deleteByIds(List<int> ids) {
    return (delete(documents)..where((t) => t.id.isIn(ids))).go();
  }

  /// Clears [Document.lastOpenedAt] for every document, emptying the Recent
  /// row without touching the documents themselves.
  Future<int> clearRecent() {
    return (update(documents)..where((t) => t.lastOpenedAt.isNotNull())).write(
      const DocumentsCompanion(lastOpenedAt: Value(null)),
    );
  }
}
