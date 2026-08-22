import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'daos/bookmark_dao.dart';
import 'daos/document_dao.dart';
import 'daos/settings_dao.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final documentDaoProvider = Provider<DocumentDao>((ref) {
  return ref.watch(appDatabaseProvider).documentDao;
});

final bookmarkDaoProvider = Provider<BookmarkDao>((ref) {
  return ref.watch(appDatabaseProvider).bookmarkDao;
});

final settingsDaoProvider = Provider<SettingsDao>((ref) {
  return ref.watch(appDatabaseProvider).settingsDao;
});

final documentByIdProvider = FutureProvider.autoDispose.family<Document?, int>((ref, id) {
  return ref.watch(documentDaoProvider).findById(id);
});
