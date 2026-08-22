import 'dart:io';
import 'dart:typed_data';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../pdf/rotate_image.dart';
import '../../domain/tool_run_state.dart';
import 'crop_page_screen.dart';
import 'providers/scan_controller.dart';
import 'widgets/scan_save_sheet.dart';

class ScanScreen extends HookConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pages = useState<List<String>>(const []);
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
                      label: const Text('Scan one page'),
                    ),
                    const SizedBox(height: Spacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => scanMore(noOfPages: 100),
                      icon: Icon(AppIcons.scan),
                      label: const Text('Scan multiple pages'),
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
  });

  final String imagePath;
  final int pageNumber;
  final VoidCallback onRemove;
  final VoidCallback onRotate;
  final VoidCallback onCrop;

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
          IconButton(icon: Icon(AppIcons.crop, size: 18), tooltip: 'Crop', onPressed: onCrop),
          IconButton(icon: Icon(AppIcons.rotate, size: 18), tooltip: 'Rotate', onPressed: onRotate),
          IconButton(icon: Icon(AppIcons.close, size: 18), tooltip: 'Remove', onPressed: onRemove),
        ],
      ),
    );
  }
}
