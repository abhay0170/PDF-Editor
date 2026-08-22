import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../../app/theme/icons.dart';
import '../../../../../app/theme/radii.dart';
import '../../../../../app/theme/spacing.dart';
import '../../../../../core/utils/file_size_formatter.dart';
import '../../../../../features/settings/presentation/default_storage_provider.dart';
import '../providers/scan_controller.dart';
import '../providers/scan_estimate_controller.dart';

/// Bottom sheet opened when the user taps "Save as PDF" in Scan to PDF —
/// lets them pick a file name, a quality/size (reusing the Compress tool's
/// slider-and-estimate approach), and a storage folder (defaulting to the
/// "Default storage" folder set in Settings) before the PDF is assembled,
/// added to the library, and offered for export via the system save dialog.
Future<void> showScanSaveSheet(BuildContext context, List<String> pages) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
    builder: (sheetContext) => _ScanSaveSheet(pages: pages),
  );
}

class _ScanSaveSheet extends HookConsumerWidget {
  const _ScanSaveSheet({required this.pages});

  final List<String> pages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultStorage = ref.watch(defaultStorageProvider);
    final nameController = useTextEditingController(text: 'Scan ${DateTime.now().millisecondsSinceEpoch}');
    final quality = useState(100.0);
    final rawSize = useState<int?>(null);
    final folder = useState<String?>(defaultStorage);
    final estimateState = ref.watch(scanEstimateControllerProvider);

    useEffect(() {
      var total = 0;
      Future<void> sum() async {
        for (final path in pages) {
          total += await File(path).length();
        }
        rawSize.value = total;
      }

      sum();
      return null;
    }, const []);

    void onQualityChanged(double value) {
      quality.value = value;
      ref.read(scanEstimateControllerProvider.notifier).refreshEstimate(pages, value);
    }

    Future<void> pickFolder() async {
      final path = await FilePicker.getDirectoryPath(dialogTitle: 'Choose storage folder');
      if (path != null) folder.value = path;
    }

    void save() {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      Navigator.of(context).pop();
      ref
          .read(scanControllerProvider.notifier)
          .save(pages, fileName: name, qualityPercent: quality.value, exportFolder: folder.value);
    }

    final theme = Theme.of(context);
    final showingRaw = quality.value >= 100;
    final estimatedBytes = estimateState.value;
    final isEstimating = estimateState.isLoading;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Spacing.xl,
          Spacing.lg,
          Spacing.xl,
          Spacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save as PDF', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xl),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'File name', suffixText: '.pdf'),
            ),
            const SizedBox(height: Spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quality', style: theme.textTheme.titleMedium),
                Text('${quality.value.round()}%', style: theme.textTheme.titleMedium),
              ],
            ),
            Slider(value: quality.value, min: 10, max: 100, onChanged: onQualityChanged),
            const SizedBox(height: Spacing.sm),
            Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: Radii.mediumRadius,
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated size', style: theme.textTheme.bodySmall),
                      const SizedBox(height: Spacing.xs),
                      if (showingRaw)
                        Text(
                          rawSize.value == null ? '—' : formatFileSize(rawSize.value!),
                          style: theme.textTheme.headlineSmall,
                        )
                      else if (isEstimating || estimatedBytes == null)
                        SizedBox(
                          height: 28,
                          child: Row(
                            children: [
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: Spacing.sm),
                              Text('Estimating…', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        )
                      else
                        Text(formatFileSize(estimatedBytes), style: theme.textTheme.headlineSmall),
                    ],
                  ),
                  if (!showingRaw && rawSize.value != null)
                    Text('was ${formatFileSize(rawSize.value!)}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
            InkWell(
              onTap: pickFolder,
              borderRadius: Radii.mediumRadius,
              child: Container(
                padding: const EdgeInsets.all(Spacing.lg),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: Radii.mediumRadius,
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.folder, size: 20, color: theme.textTheme.bodyMedium?.color),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Save to', style: theme.textTheme.bodySmall),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            folder.value == null ? 'Choose when saving' : p.basename(folder.value!),
                            style: theme.textTheme.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevronRight, size: 18, color: theme.textTheme.bodySmall?.color),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: save,
                icon: Icon(AppIcons.download),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
