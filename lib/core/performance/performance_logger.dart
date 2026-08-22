import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Lightweight timing instrumentation. No-op cost in release builds beyond a
/// single `kReleaseMode` branch — never blocks or allocates in release.
class PerformanceLogger {
  const PerformanceLogger();

  Stopwatch startSpan(String label) {
    if (!kReleaseMode) {
      developer.Timeline.startSync(label);
    }
    return Stopwatch()..start();
  }

  void endSpan(String label, Stopwatch stopwatch) {
    stopwatch.stop();
    if (!kReleaseMode) {
      developer.Timeline.finishSync();
      debugPrint('[perf] $label: ${stopwatch.elapsedMilliseconds}ms');
    }
  }

  Future<T> measure<T>(String label, Future<T> Function() action) async {
    final stopwatch = startSpan(label);
    try {
      return await action();
    } finally {
      endSpan(label, stopwatch);
    }
  }
}
