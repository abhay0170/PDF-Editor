import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../domain/tool_run_state.dart';
import 'providers/scan_controller.dart';
import 'providers/scan_draft_controller.dart';
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
    final draftAsync = ref.watch(scanDraftControllerProvider);
    final scanState = ref.watch(scanControllerProvider);
    final isProcessing = scanState.value is ToolProcessing;

    void setPages(List<String> next) {
      pages.value = next;
      ref.read(scanDraftControllerProvider.notifier).save(next);
    }

    ref.listen<AsyncValue<ScanState>>(scanControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(scanControllerProvider.notifier).reset();
          ref.read(scanDraftControllerProvider.notifier).clear();
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
          setPages([...pages.value, ...captured]);
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

    // Deliberately not cunning_document_scanner's gallery source: that opens
    // a generic ACTION_GET_CONTENT intent, which on many Android devices
    // resolves to a chooser listing "Camera" alongside the gallery apps.
    // image_picker's gallery picker opens the photo grid directly.
    Future<void> pickFromGallery() async {
      try {
        final picked = await ImagePicker().pickMultiImage();
        if (picked.isNotEmpty) {
          setPages([...pages.value, ...picked.map((file) => file.path)]);
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open photos.')));
        }
      }
    }

    // Skips this screen's own "choose a scan type" landing entirely: the
    // camera (or gallery picker) opens the instant this screen is pushed —
    // unless a draft from a previous, unfinished scan is waiting on disk
    // (the user scanned at least one page last time and then closed the
    // app rather than saving or discarding), in which case those pages are
    // restored instead so nothing is lost. Document vs. ID card vs. passport
    // mode is selected inside the native scanner's own UI, not by a
    // separate button here. If the user cancels a fresh scan without
    // capturing anything, there's nothing left to show, so this just backs
    // out instead of stranding them on a blank screen.
    useEffect(() {
      if (draftAsync.isLoading) return null;

      Future<void> autoStart() async {
        final draft = draftAsync.value ?? const [];
        if (draft.isNotEmpty) {
          pages.value = draft;
          return;
        }

        if (autoPickFromGallery) {
          await pickFromGallery();
        } else {
          await scanMore(noOfPages: 100);
        }
        if (pages.value.isEmpty && context.mounted) {
          Navigator.of(context).pop();
        }
      }

      autoStart();
      return null;
    }, [draftAsync.isLoading]);

    Future<void> retakePage(int index) async {
      try {
        final captured = await CunningDocumentScanner.getPictures(
          scannerSource: ScannerSource.camera,
          noOfPages: 1,
        );
        if (captured == null || captured.isEmpty) return;
        final list = [...pages.value];
        list[index] = captured.first;
        setPages(list);
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

    void viewPage(String imagePath) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _PagePreviewScreen(imagePath: imagePath)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan to PDF')),
      body: pages.value.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.screenHorizontal,
                vertical: Spacing.lg,
              ),
              onReorderItem: (oldIndex, newIndex) {
                final list = [...pages.value];
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                setPages(list);
              },
              itemCount: pages.value.length + 1,
              itemBuilder: (context, index) {
                if (index == pages.value.length) {
                  return Padding(
                    key: const ValueKey('scan-more'),
                    padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.fabClearance),
                    child: OutlinedButton.icon(
                      onPressed: () => scanMore(noOfPages: 100),
                      icon: Icon(AppIcons.camera, size: 18),
                      label: const Text('Add more'),
                    ),
                  );
                }

                final imagePath = pages.value[index];
                return _ScannedPageRow(
                  key: ValueKey(imagePath),
                  imagePath: imagePath,
                  pageNumber: index + 1,
                  onView: () => viewPage(imagePath),
                  onRemove: () {
                    final list = [...pages.value]..removeAt(index);
                    setPages(list);
                    // Nothing left to show or resume — back out rather than
                    // stranding the user on a permanent loading spinner.
                    if (list.isEmpty && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  onRetake: () => retakePage(index),
                );
              },
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
    required this.onView,
    required this.onRemove,
    required this.onRetake,
  });

  final String imagePath;
  final int pageNumber;
  final VoidCallback onView;
  final VoidCallback onRemove;
  final VoidCallback onRetake;

  static const double _thumbnailHeight = 52;

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
          InkWell(
            onTap: onView,
            borderRadius: Radii.smallRadius,
            child: ClipRRect(
              borderRadius: Radii.smallRadius,
              child: Image.file(File(imagePath), width: 40, height: _thumbnailHeight, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: SizedBox(
              height: _thumbnailHeight,
              child: Align(
                alignment: Alignment.topLeft,
                child: Text('Page $pageNumber', style: theme.textTheme.bodyLarge),
              ),
            ),
          ),
          IconButton(icon: Icon(AppIcons.retake, size: 18), tooltip: 'Retake', onPressed: onRetake),
          IconButton(icon: Icon(AppIcons.close, size: 18), tooltip: 'Remove', onPressed: onRemove),
        ],
      ),
    );
  }
}

class _PagePreviewScreen extends StatelessWidget {
  const _PagePreviewScreen({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(child: Image.file(File(imagePath))),
      ),
    );
  }
}
