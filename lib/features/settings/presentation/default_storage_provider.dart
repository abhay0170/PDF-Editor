import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_providers.dart';

const _defaultStorageSettingKey = 'default_storage_folder';

/// Persisted folder path used as the starting location for the system save
/// dialog (`FilePicker.saveFile`'s `initialDirectory`) whenever the app
/// offers a "download"/export action — e.g. Scan to PDF. `null` means the
/// user hasn't set one, so the OS picker opens at its own default location.
class DefaultStorageNotifier extends Notifier<String?> {
  @override
  String? build() {
    _loadPersisted();
    return null;
  }

  Future<void> _loadPersisted() async {
    final stored = await ref.read(settingsDaoProvider).get(_defaultStorageSettingKey);
    final value = (stored == null || stored.isEmpty) ? null : stored;
    if (value != state) state = value;
  }

  Future<void> setFolder(String? path) async {
    state = path;
    await ref.read(settingsDaoProvider).set(_defaultStorageSettingKey, path ?? '');
  }
}

final defaultStorageProvider = NotifierProvider<DefaultStorageNotifier, String?>(
  DefaultStorageNotifier.new,
);
