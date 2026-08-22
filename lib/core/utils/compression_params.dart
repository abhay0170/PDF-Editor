/// Render scale and JPEG quality to use when compressing a page, derived
/// from a single 10-100 "quality" slider value.
typedef CompressionParams = ({double scale, int quality});

/// Maps a quality slider value (10 = smallest/most compressed, 100 = largest/
/// least compressed) to the render scale and JPEG quality
/// [PdfManipulationService.compressPdf] should use. Shared between the live
/// size estimate and the actual compression run so the preview matches what
/// running Compress will actually produce.
CompressionParams compressionParamsForQuality(double qualityPercent) {
  final clamped = qualityPercent.clamp(10, 100);
  final quality = clamped.round();
  final scale = 1.0 + (clamped - 10) / 90 * 1.0;
  return (scale: scale, quality: quality);
}
