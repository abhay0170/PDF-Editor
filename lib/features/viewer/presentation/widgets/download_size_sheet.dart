import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../database/app_database.dart';
import '../../../tools/compress/presentation/providers/compress_estimate_controller.dart';
import '../../../tools/domain/tool_run_state.dart';
import '../providers/download_controller.dart';

/// Bottom sheet opened from the viewer's "Download" action — lets the user
/// pick a quality/size (reusing the Compress tool's slider and live
/// estimate) before saving a copy via the system save dialog.
Future<void> showDownloadSizeSheet(BuildContext context, Document document) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
    builder: (sheetContext) => _DownloadSizeSheet(document: document),
  );
}

class _DownloadSizeSheet extends HookConsumerWidget {
  const _DownloadSizeSheet({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = useState(100.0);
    final originalSize = useState<int?>(null);
    final downloadState = ref.watch(downloadControllerProvider);
    final estimateState = ref.watch(compressEstimateControllerProvider);
    final isProcessing = downloadState.value is ToolProcessing;

    useEffect(() {
      File(document.path).length().then((size) => originalSize.value = size);
      return null;
    }, const []);

    ref.listen<AsyncValue<DownloadState>>(downloadControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(downloadControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result ? 'Saved to your chosen location.' : 'Download canceled.')),
          );
        case ToolError(:final message):
          ref.read(downloadControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    void onQualityChanged(double value) {
      quality.value = value;
      ref.read(compressEstimateControllerProvider.notifier).refreshEstimate(document, value);
    }

    final theme = Theme.of(context);
    final showingOriginal = quality.value >= 100;
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
            Text('Download', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text(document.displayName, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: Spacing.xl),
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
                      Text(showingOriginal ? 'Original size' : 'Estimated size', style: theme.textTheme.bodySmall),
                      const SizedBox(height: Spacing.xs),
                      if (showingOriginal)
                        Text(
                          originalSize.value == null ? '—' : formatFileSize(originalSize.value!),
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
                  if (!showingOriginal && originalSize.value != null)
                    Text('was ${formatFileSize(originalSize.value!)}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => ref.read(downloadControllerProvider.notifier).download(document, quality.value),
                icon: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(AppIcons.download),
                label: Text(isProcessing ? 'Downloading…' : 'Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
