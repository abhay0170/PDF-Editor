import 'dart:async';

import 'support/sqlite3_test_setup.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ensureSqlite3LoadedForTests();
  await testMain();
}
