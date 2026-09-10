import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('get returns null for a key that was never set', () async {
    expect(await db.settingsDao.get('missing'), isNull);
  });

  test('set then get returns the stored value', () async {
    await db.settingsDao.set('scan_draft_pages', '["a.jpg","b.jpg"]');

    expect(await db.settingsDao.get('scan_draft_pages'), '["a.jpg","b.jpg"]');
  });

  test('set overwrites a previously stored value for the same key', () async {
    await db.settingsDao.set('scan_draft_pages', '["a.jpg"]');
    await db.settingsDao.set('scan_draft_pages', '["a.jpg","b.jpg"]');

    expect(await db.settingsDao.get('scan_draft_pages'), '["a.jpg","b.jpg"]');
  });

  test('remove clears a stored value', () async {
    await db.settingsDao.set('scan_draft_pages', '["a.jpg"]');
    await db.settingsDao.remove('scan_draft_pages');

    expect(await db.settingsDao.get('scan_draft_pages'), isNull);
  });

  test('remove on a key that was never set does not throw', () async {
    await db.settingsDao.remove('never_set');

    expect(await db.settingsDao.get('never_set'), isNull);
  });
}
