import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/database/app_database.dart';
import 'package:pdf_reader/database/daos/document_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DocumentsCompanion sampleDocument({
    required String path,
    String displayName = 'Sample.pdf',
    DateTime? lastOpenedAt,
  }) {
    final now = DateTime(2026, 1, 1);
    return DocumentsCompanion.insert(
      path: path,
      displayName: displayName,
      fileSize: 1024,
      createdAt: now,
      modifiedAt: now,
      lastOpenedAt: Value(lastOpenedAt),
    );
  }

  test('insertDocument then findByPath returns the same document', () async {
    final id = await db.documentDao.insertDocument(
      sampleDocument(path: '/docs/a.pdf'),
    );

    final found = await db.documentDao.findByPath('/docs/a.pdf');

    expect(found, isNotNull);
    expect(found!.id, id);
    expect(found.displayName, 'Sample.pdf');
  });

  test('findByPath returns null for an unknown path', () async {
    final found = await db.documentDao.findByPath('/does/not/exist.pdf');
    expect(found, isNull);
  });

  test('watchAll emits documents ordered by display name', () async {
    await db.documentDao.insertDocument(
      sampleDocument(path: '/docs/b.pdf', displayName: 'Bravo.pdf'),
    );
    await db.documentDao.insertDocument(
      sampleDocument(path: '/docs/a.pdf', displayName: 'Alpha.pdf'),
    );

    final docs = await db.documentDao
        .watchAll(sort: const SortSpec(DocumentSortField.name))
        .first;

    expect(docs.map((d) => d.displayName), ['Alpha.pdf', 'Bravo.pdf']);
  });

  test('watchRecent only includes documents with lastOpenedAt set', () async {
    await db.documentDao.insertDocument(sampleDocument(path: '/docs/never.pdf'));
    await db.documentDao.insertDocument(
      sampleDocument(path: '/docs/opened.pdf', lastOpenedAt: DateTime(2026, 5, 1)),
    );

    final recent = await db.documentDao.watchRecent().first;

    expect(recent, hasLength(1));
    expect(recent.single.path, '/docs/opened.pdf');
  });

  test('markOpened updates lastOpenedAt and lastPage', () async {
    final id = await db.documentDao.insertDocument(
      sampleDocument(path: '/docs/a.pdf'),
    );

    await db.documentDao.markOpened(id, lastPage: 7);
    final updated = await db.documentDao.findById(id);

    expect(updated!.lastPage, 7);
    expect(updated.lastOpenedAt, isNotNull);
  });

  test('deleteById removes the document', () async {
    final id = await db.documentDao.insertDocument(
      sampleDocument(path: '/docs/a.pdf'),
    );

    final deletedCount = await db.documentDao.deleteById(id);
    final found = await db.documentDao.findById(id);

    expect(deletedCount, 1);
    expect(found, isNull);
  });
}
