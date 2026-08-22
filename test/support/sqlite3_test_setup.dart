/// As of `sqlite3` 3.5.x, the native library is built automatically via
/// Dart's native-assets hooks (see the package's `hook/` directory) — no
/// manual `DynamicLibrary` wiring is needed for `flutter test` anymore.
void ensureSqlite3LoadedForTests() {}
