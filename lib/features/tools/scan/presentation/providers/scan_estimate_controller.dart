import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/compression_params.dart';
import '../../../../../core/utils/image_recompress.dart';

/// Live "what would this scan compress to" preview shown while the user
/// drags the quality slider in the scan save sheet — same shape as
/// `CompressEstimateController`, but working from the raw scanned image
/// files (there's no PDF yet at that point) instead of an existing
/// [Document]. Only the first page is re-encoded and the result is
/// extrapolated by page count, so this is an estimate, not the exact final
/// size.
class ScanEstimateController extends AsyncNotifier<int?> {
  Timer? _debounce;
  int _requestId = 0;

  @override
  FutureOr<int?> build() {
    ref.onDispose(() => _debounce?.cancel());
    return null;
  }

  /// Pass `qualityPercent >= 100` to clear the estimate (the sheet falls
  /// back to showing the summed size of the raw scanned images).
  void refreshEstimate(List<String> imagePaths, double qualityPercent) {
    _debounce?.cancel();
    final requestId = ++_requestId;
    if (imagePaths.isEmpty || qualityPercent >= 100) {
      state = const AsyncData(null);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      state = const AsyncLoading<int?>();
      try {
        final params = compressionParamsForQuality(qualityPercent);
        final firstImageBytes = await File(imagePaths.first).readAsBytes();
        final jpegBytes = await compute(recompressImageAsJpeg, (firstImageBytes, params.quality));
        if (requestId == _requestId) {
          state = AsyncData(jpegBytes.length * imagePaths.length);
        }
      } catch (_) {
        if (requestId == _requestId) state = const AsyncData(null);
      }
    });
  }
}

final scanEstimateControllerProvider = AsyncNotifierProvider.autoDispose<ScanEstimateController, int?>(
  ScanEstimateController.new,
);
