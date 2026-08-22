import 'dart:io';

import 'package:flutter/foundation.dart';

/// Dev-only helper for inspecting process memory during manual profiling.
/// Not wired into any UI; call from a debugger/print statement when needed.
class MemoryMonitor {
  const MemoryMonitor();

  /// Current resident set size in bytes, or null if unavailable on this platform.
  int? currentRssBytes() {
    if (kIsWeb) return null;
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return null;
    }
  }
}
