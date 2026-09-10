import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/settings_table.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [SettingsEntries])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(
      settingsEntries,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) {
    return into(settingsEntries).insertOnConflictUpdate(
      SettingsEntriesCompanion.insert(key: key, value: value),
    );
  }

  Stream<String?> watch(String key) {
    final query = select(settingsEntries)..where((t) => t.key.equals(key));
    return query.watchSingleOrNull().map((row) => row?.value);
  }

  Future<void> remove(String key) {
    return (delete(settingsEntries)..where((t) => t.key.equals(key))).go();
  }
}
