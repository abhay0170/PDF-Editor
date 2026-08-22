import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/compression_params.dart';
import '../../../../../core/utils/image_recompress.dart';
import '../../../../../database/app_database.dart';
import '../../../../../pdf/pdf_providers.dart';

/// Live "what would this compress to" preview shown while the user drags the
/// quality slider. Re-rendering every page on every drag tick would be far
/// too slow, so this only renders and JPEG-encodes page 1, then extrapolates
/// `compressedPage1Bytes * pageCount` — an estimate, not the exact final
/// size (the real size is computed after [CompressController.compress]
/// actually runs on every page).
class CompressEstimateController extends AsyncNotifier<int?> {
  Timer? _debounce;

  /// Bumped on every call to [refreshEstimate]; a render's result is only
  /// applied if it's still the most recent request when it completes. Without
  /// this, a slower-finishing render for an earlier slider position could
  /// overwrite a faster, more recent one and show a stale estimate.
  int _requestId = 0;

  @override
  FutureOr<int?> build() {
    ref.onDispose(() => _debounce?.cancel());
    return null;
  }

  /// Schedules a debounced re-estimate. Pass `qualityPercent >= 100` to
  /// clear the estimate (the screen falls back to showing the real original
  /// file size at that end of the slider).
  void refreshEstimate(Document source, double qualityPercent) {
    _debounce?.cancel();
    final requestId = ++_requestId;
    if (qualityPercent >= 100) {
      state = const AsyncData(null);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      state = const AsyncLoading<int?>();
      try {
        final params = compressionParamsForQuality(qualityPercent);
        final engine = ref.read(pdfEngineProvider);
        final pngBytes = await engine.renderPageAtScale(source.path, pageNumber: 1, scale: params.scale);
        final jpegBytes = await compute(recompressPngAsJpeg, (pngBytes, params.quality));
        if (requestId == _requestId) {
          state = AsyncData(jpegBytes.length * source.pageCount);
        }
      } catch (_) {
        if (requestId == _requestId) state = const AsyncData(null);
      }
    });
  }
}

final compressEstimateControllerProvider = AsyncNotifierProvider.autoDispose<CompressEstimateController, int?>(
  CompressEstimateController.new,
);
