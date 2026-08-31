import 'dart:io';
import 'dart:typed_data';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../pdf/rotate_image.dart';
import '../../../../pdf/scan_image_filters.dart';
import '../../domain/tool_run_state.dart';
import 'crop_page_screen.dart';
import 'providers/scan_controller.dart';
import 'widgets/scan_save_sheet.dart';

class ScanScreen extends HookConsumerWidget {
  const ScanScreen({super.key, this.autoPickFromGallery = false});

  /// When true, immediately opens the gallery picker on first frame instead
  /// of waiting for the user to tap a button — used by the home screen's
  /// "Photos" quick-add option.
  final bool autoPickFromGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = useState<List<String>>(const []);
    // Maps a page's current file path back to the pre-filter capture it was
    // derived from, so switching Grayscale -> Black & white -> Original
    // always starts from the same source instead of compounding filters (or
    // "original" being unable to undo one). Rotate/crop write a brand-new
    // path with no entry here, which is correct — filters apply on top of
    // whatever crop/rotation is currently in effect.
    final filterBaseline = useState<Map<String, String>>({});
    final scanState = ref.watch(scanControllerProvider);
    final isProcessing = scanState.value is ToolProcessing;

    ref.listen<AsyncValue<ScanState>>(scanControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(scanControllerProvider.notifier).reset();
          CunningDocumentScanner.cleanCache().catchError((_) {});
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(scanControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    Future<void> scanMore({required int noOfPages}) async {
      try {
        final captured = await CunningDocumentScanner.getPictures(
          scannerSource: ScannerSource.camera,
          noOfPages: noOfPages,
        );
        if (captured != null && captured.isNotEmpty) {
          pages.value = [...pages.value, ...captured];
        }
      } on CunningDocumentScannerException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open the scanner.')));
        }
      }
    }

    // ID cards are typically scanned front and back, so this defaults to two
    // captures instead of the single-page default used for documents.
    Future<void> scanIdCard() => scanMore(noOfPages: 2);

    // Deliberately not cunning_document_scanner's gallery source: that opens
    // a generic ACTION_GET_CONTENT intent, which on many Android devices
    // resolves to a chooser listing "Camera" alongside the gallery apps.
    // image_picker's gallery picker opens the photo grid directly.
    Future<void> pickFromGallery() async {
      try {
        final picked = await ImagePicker().pickMultiImage();
        if (picked.isNotEmpty) {
          pages.value = [...pages.value, ...picked.map((file) => file.path)];
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open photos.')));
        }
      }
    }

    useEffect(() {
      if (autoPickFromGallery) {
        pickFromGallery();
      }
      return null;
    }, const []);

    Future<void> rotatePage(int index) async {
      final path = pages.value[index];
      final bytes = await File(path).readAsBytes();
      final rotated = await rotateImageBytes(bytes, 90);
      final newPath = p.join(p.dirname(path), '${DateTime.now().microsecondsSinceEpoch}_rotated.png');
      await File(newPath).writeAsBytes(rotated);
      final list = [...pages.value];
      list[index] = newPath;
      pages.value = list;
    }

    Future<void> cropPage(int index) async {
      final path = pages.value[index];
      final bytes = await File(path).readAsBytes();
      if (!context.mounted) return;
      final cropped = await Navigator.of(
        context,
      ).push<Uint8List>(MaterialPageRoute(builder: (_) => CropPageScreen(imageBytes: bytes)));
      if (cropped == null) return;
      final newPath = p.join(p.dirname(path), '${DateTime.now().microsecondsSinceEpoch}_cropped.png');
      await File(newPath).writeAsBytes(cropped);
      final list = [...pages.value];
      list[index] = newPath;
      pages.value = list;
    }

    Future<void> retakePage(int index) async {
      try {
        final captured = await CunningDocumentScanner.getPictures(
          scannerSource: ScannerSource.camera,
          noOfPages: 1,
        );
        if (captured == null || captured.isEmpty) return;
        final list = [...pages.value];
        list[index] = captured.first;
        pages.value = list;
      } on CunningDocumentScannerException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not retake this page.')));
        }
      }
    }

    Future<void> applyFilter(int index, ScanFilter filter) async {
      final path = pages.value[index];
      final baselinePath = filterBaseline.value[path] ?? path;
      if (filter == ScanFilter.original) {
        final list = [...pages.value];
        list[index] = baselinePath;
        pages.value = list;
        return;
      }
      try {
        final bytes = await File(baselinePath).readAsBytes();
        final filtered = await applyScanFilter(bytes, filter);
        final newPath = p.join(
          p.dirname(path),
          '${DateTime.now().microsecondsSinceEpoch}_filtered.png',
        );
        await File(newPath).writeAsBytes(filtered);
        final list = [...pages.value];
        list[index] = newPath;
        pages.value = list;
        filterBaseline.value = {...filterBaseline.value, newPath: baselinePath};
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not apply that filter.')));
        }
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan to PDF')),
      body: pages.value.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.scan, size: 48, color: theme.textTheme.bodySmall?.color),
                    const SizedBox(height: Spacing.lg),
                    Text(
                      'Scan a document with your camera — edges and lighting are corrected automatically.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Spacing.xxl),
                    FilledButton.icon(
                      onPressed: () => scanMore(noOfPages: 1),
                      icon: Icon(AppIcons.camera),
                      label: const Text('Scan a document'),
                    ),
                    const SizedBox(height: Spacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => scanMore(noOfPages: 100),
                      icon: Icon(AppIcons.scan),
                      label: const Text('Scan multiple pages'),
                    ),
                    const SizedBox(height: Spacing.sm),
                    OutlinedButton.icon(
                      onPressed: scanIdCard,
                      icon: Icon(AppIcons.idCard),
                      label: const Text('Scan an ID card'),
                    ),
                  ],
                ),
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.screenHorizontal,
                vertical: Spacing.lg,
              ),
              onReorder: (oldIndex, newIndex) {
                final list = [...pages.value];
                if (newIndex > oldIndex) newIndex -= 1;
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                pages.value = list;
              },
              children: [
                for (var i = 0; i < pages.value.length; i++)
                  _ScannedPageRow(
                    key: ValueKey(pages.value[i]),
                    imagePath: pages.value[i],
                    pageNumber: i + 1,
                    onRemove: () {
                      final list = [...pages.value]..removeAt(i);
                      pages.value = list;
                    },
                    onRotate: () => rotatePage(i),
                    onCrop: () => cropPage(i),
                    onRetake: () => retakePage(i),
                    onFilter: (filter) => applyFilter(i, filter),
                  ),
                Padding(
                  key: const ValueKey('scan-more'),
                  padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.fabClearance),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => scanMore(noOfPages: 1),
                          icon: Icon(AppIcons.camera, size: 18),
                          label: const Text('Add one'),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => scanMore(noOfPages: 100),
                          icon: Icon(AppIcons.scan, size: 18),
                          label: const Text('Add multiple'),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: scanIdCard,
                          icon: Icon(AppIcons.idCard, size: 18),
                          label: const Text('Add ID card'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: pages.value.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: !isProcessing ? () => showScanSaveSheet(context, pages.value) : null,
              icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(AppIcons.file),
              label: Text(isProcessing ? 'Saving…' : 'Save as PDF'),
            ),
    );
  }
}

class _ScannedPageRow extends StatelessWidget {
  const _ScannedPageRow({
    super.key,
    required this.imagePath,
    required this.pageNumber,
    required this.onRemove,
    required this.onRotate,
    required this.onCrop,
    required this.onRetake,
    required this.onFilter,
  });

  final String imagePath;
  final int pageNumber;
  final VoidCallback onRemove;
  final VoidCallback onRotate;
  final VoidCallback onCrop;
  final VoidCallback onRetake;
  final ValueChanged<ScanFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: Radii.mediumRadius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(AppIcons.reorder, size: 18, color: theme.textTheme.bodySmall?.color),
          const SizedBox(width: Spacing.sm),
          ClipRRect(
            borderRadius: Radii.smallRadius,
            child: Image.file(File(imagePath), width: 40, height: 52, fit: BoxFit.cover),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text('Page $pageNumber', style: theme.textTheme.bodyLarge),
          ),
          PopupMenuButton<ScanFilter>(
            icon: Icon(AppIcons.filter, size: 18),
            tooltip: 'Filter',
            onSelected: onFilter,
            itemBuilder: (context) => const [
              PopupMenuItem(value: ScanFilter.original, child: Text('Original')),
              PopupMenuItem(value: ScanFilter.grayscale, child: Text('Grayscale')),
              PopupMenuItem(value: ScanFilter.blackAndWhite, child: Text('Black & white')),
            ],
          ),
          IconButton(icon: Icon(AppIcons.retake, size: 18), tooltip: 'Retake', onPressed: onRetake),
          IconButton(icon: Icon(AppIcons.crop, size: 18), tooltip: 'Crop', onPressed: onCrop),
          IconButton(icon: Icon(AppIcons.rotate, size: 18), tooltip: 'Rotate', onPressed: onRotate),
          IconButton(icon: Icon(AppIcons.close, size: 18), tooltip: 'Remove', onPressed: onRemove),
        ],
      ),
    );
  }
}
