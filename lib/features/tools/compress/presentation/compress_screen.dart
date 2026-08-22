import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../database/app_database.dart';
import '../../domain/tool_run_state.dart';
import '../../widgets/inline_document_picker.dart';
import 'providers/compress_controller.dart';
import 'providers/compress_estimate_controller.dart';

class CompressScreen extends HookConsumerWidget {
  const CompressScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final quality = useState(70.0);
    final originalSize = useState<int?>(null);
    final compressState = ref.watch(compressControllerProvider);
    final estimateState = ref.watch(compressEstimateControllerProvider);
    final isProcessing = compressState.value is ToolProcessing;

    useEffect(() {
      final document = selectedDocument.value;
      if (document == null) {
        originalSize.value = null;
        return null;
      }
      originalSize.value = null;
      File(document.path).length().then((size) {
        originalSize.value = size;
      });
      return null;
    }, [selectedDocument.value]);

    ref.listen<AsyncValue<CompressState>>(compressControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(compressControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(compressControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    void onQualityChanged(double value) {
      quality.value = value;
      final document = selectedDocument.value;
      if (document != null) {
        ref.read(compressEstimateControllerProvider.notifier).refreshEstimate(document, value);
      }
    }

    final theme = Theme.of(context);
    final showingOriginal = quality.value >= 100;
    final estimatedBytes = estimateState.value;
    final isEstimating = estimateState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal, vertical: Spacing.lg),
        children: [
          Text('Document', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          InlineDocumentPicker(
            selected: selectedDocument.value,
            onSelected: (doc) {
              selectedDocument.value = doc;
              ref.read(compressEstimateControllerProvider.notifier).refreshEstimate(doc, quality.value);
            },
          ),
          if (selectedDocument.value != null) ...[
            const SizedBox(height: Spacing.sectionSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quality', style: theme.textTheme.titleLarge),
                Text('${quality.value.round()}%', style: theme.textTheme.titleLarge),
              ],
            ),
            Slider(
              value: quality.value,
              min: 10,
              max: 100,
              onChanged: onQualityChanged,
            ),
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
                      Text(
                        showingOriginal ? 'Original size' : 'Estimated size',
                        style: theme.textTheme.bodySmall,
                      ),
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
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
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
                    Text(
                      'was ${formatFileSize(originalSize.value!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: Radii.mediumRadius,
              ),
              child: Text(
                'The result is recreated as images — text won’t be selectable or searchable. '
                'The estimate above is based on page 1; the actual result may differ slightly.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (selectedDocument.value != null && !isProcessing)
            ? () => ref.read(compressControllerProvider.notifier).compress(selectedDocument.value!, quality.value)
            : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.compress),
        label: Text(isProcessing ? 'Compressing…' : 'Compress'),
      ),
    );
  }
}
