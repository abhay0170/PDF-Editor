import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../database/database_providers.dart';

const _scanDraftSettingKey = 'scan_draft_pages';

/// Persists the in-progress scan (captured page image paths) across app
/// restarts. If the user scans one or more pages and then closes the app
/// entirely — not just backgrounds it, which already keeps this in memory —
/// reopening the Scan tool resumes exactly where they left off instead of
/// starting a fresh scan.
class ScanDraftController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final stored = await ref.read(settingsDaoProvider).get(_scanDraftSettingKey);
    if (stored == null || stored.isEmpty) return const [];

    final paths = (jsonDecode(stored) as List).cast<String>();
    // The scanner/picker write into a cache directory the OS is free to
    // clear between app runs — drop any page that's no longer actually
    // there rather than resuming with a broken thumbnail.
    final existing = <String>[];
    for (final path in paths) {
      if (await File(path).exists()) existing.add(path);
    }
    if (existing.length != paths.length) {
      await _persist(existing);
    }
    return existing;
  }

  /// Called after every change to the scanned-pages list (capture, retake,
  /// reorder, remove) so the draft on disk always matches what's on screen.
  Future<void> save(List<String> pages) async {
    state = AsyncData(pages);
    await _persist(pages);
  }

  /// Called once the scan is saved as a PDF (or discarded entirely) — the
  /// draft has served its purpose and shouldn't be offered for resuming.
  Future<void> clear() async {
    state = const AsyncData([]);
    await ref.read(settingsDaoProvider).remove(_scanDraftSettingKey);
  }

  Future<void> _persist(List<String> pages) async {
    if (pages.isEmpty) {
      await ref.read(settingsDaoProvider).remove(_scanDraftSettingKey);
    } else {
      await ref.read(settingsDaoProvider).set(_scanDraftSettingKey, jsonEncode(pages));
    }
  }
}

final scanDraftControllerProvider = AsyncNotifierProvider<ScanDraftController, List<String>>(
  ScanDraftController.new,
);
