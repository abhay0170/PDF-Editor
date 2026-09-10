import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import '../../domain/tool_run_state.dart';
import '../../widgets/inline_document_picker.dart';
import 'providers/watermark_controller.dart';

class WatermarkScreen extends HookConsumerWidget {
  const WatermarkScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final textController = useTextEditingController();
    final isProcessing = ref.watch(watermarkControllerProvider.select((s) => s.value is ToolProcessing));

    ref.listen<AsyncValue<WatermarkState>>(watermarkControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(watermarkControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(watermarkControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    Future<void> runWatermark() async {
      final document = selectedDocument.value;
      if (document == null) return;
      if (textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter watermark text.')));
        return;
      }
      await ref.read(watermarkControllerProvider.notifier).watermark(document, textController.text);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Watermark PDF')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal, vertical: Spacing.lg),
        children: [
          Text('Document', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          InlineDocumentPicker(
            selected: selectedDocument.value,
            onSelected: (doc) => selectedDocument.value = doc,
          ),
          if (selectedDocument.value != null) ...[
            const SizedBox(height: Spacing.sectionSpacing),
            Text('Watermark text', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: textController,
              decoration: const InputDecoration(hintText: 'e.g. CONFIDENTIAL, DRAFT'),
            ),
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: Radii.mediumRadius,
              ),
              child: Text(
                'The result is recreated as images — text won’t be selectable or searchable.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: textController,
        builder: (context, _) {
          final canRun =
              selectedDocument.value != null && textController.text.trim().isNotEmpty && !isProcessing;
          return FloatingActionButton.extended(
            onPressed: canRun ? runWatermark : null,
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(AppIcons.watermark),
            label: Text(isProcessing ? 'Applying…' : 'Apply watermark'),
          );
        },
      ),
    );
  }
}
