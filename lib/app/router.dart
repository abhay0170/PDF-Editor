import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tools/compress/presentation/compress_screen.dart';
import '../features/tools/extract/presentation/extract_screen.dart';
import '../features/tools/merge/presentation/merge_screen.dart';
import '../features/tools/ocr/presentation/ocr_screen.dart';
import '../features/tools/rotate/presentation/rotate_screen.dart';
import '../features/tools/scan/presentation/scan_screen.dart';
import '../features/tools/sign/presentation/sign_screen.dart';
import '../features/tools/split/presentation/split_screen.dart';
import '../features/tools/watermark/presentation/watermark_screen.dart';
import '../features/viewer/presentation/viewer_screen.dart';

/// Typed navigation helpers. With this many screens still fitting in a flat
/// list, a full declarative router is unnecessary overhead — plain
/// [Navigator.push] keeps document-id arguments type-safe without string
/// route parsing.
class AppRoutes {
  const AppRoutes._();

  static Future<void> openViewer(BuildContext context, {required int documentId}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ViewerScreen(documentId: documentId)));
  }

  static Future<void> openSettings(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  static Future<void> openMerge(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MergeScreen(initialDocument: initialDocument)));
  }

  static Future<void> openSplit(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SplitScreen(initialDocument: initialDocument)));
  }

  static Future<void> openRotate(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RotateScreen(initialDocument: initialDocument)));
  }

  static Future<void> openExtract(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ExtractScreen(initialDocument: initialDocument)));
  }

  static Future<void> openScan(BuildContext context) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  static Future<void> openWatermark(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WatermarkScreen(initialDocument: initialDocument)));
  }

  static Future<void> openCompress(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CompressScreen(initialDocument: initialDocument)));
  }

  static Future<void> openSign(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SignScreen(initialDocument: initialDocument)));
  }

  static Future<void> openOcr(BuildContext context, {Document? initialDocument}) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => OcrScreen(initialDocument: initialDocument)));
  }
}
