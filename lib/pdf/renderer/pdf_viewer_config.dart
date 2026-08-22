import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/constants/cache_constants.dart';

/// A tuned [PdfViewerParams] for the app's viewer screen. `pdfrx` already
/// virtualizes rendering (only visible pages + a prefetch window are kept
/// resident) and bounds page-image memory internally — this just makes the
/// budget explicit rather than relying on the library default.
PdfViewerParams buildPdfViewerParams({
  required Color backgroundColor,
  PdfViewerOverlaysBuilder? viewerOverlayBuilder,
  PdfViewerErrorBannerBuilder? errorBannerBuilder,
  PdfViewerReadyCallback? onViewerReady,
}) {
  return PdfViewerParams(
    backgroundColor: backgroundColor,
    maxImageBytesCachedOnMemory: CacheConstants.viewerMaxImageBytesCachedOnMemory,
    behaviorControlParams: const PdfViewerBehaviorControlParams(
      enableLowResolutionPagePreview: true,
    ),
    viewerOverlayBuilder: viewerOverlayBuilder,
    errorBannerBuilder: errorBannerBuilder,
    onViewerReady: onViewerReady,
  );
}
