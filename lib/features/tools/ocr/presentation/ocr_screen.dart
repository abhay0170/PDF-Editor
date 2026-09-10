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
import 'providers/ocr_controller.dart';

class OcrScreen extends HookConsumerWidget {
  const OcrScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final isProcessing = ref.watch(ocrControllerProvider.select((s) => s.value is ToolProcessing));

    ref.listen<AsyncValue<OcrState>>(ocrControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(ocrControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(ocrControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    final theme = Theme.of(context);
    final document = selectedDocument.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Make Searchable')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal, vertical: Spacing.lg),
        children: [
          Text('Document', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          InlineDocumentPicker(
            selected: document,
            onSelected: (doc) => selectedDocument.value = doc,
          ),
          if (document != null) ...[
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: Radii.mediumRadius,
              ),
              child: Text(
                'Recognizes text on each page and adds an invisible layer underneath, so scanned or photographed '
                'pages become searchable and selectable. Recognition happens entirely on your device and works '
                'best on clear, well-lit pages — accuracy varies with image quality.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (document != null && !isProcessing)
            ? () => ref.read(ocrControllerProvider.notifier).makeSearchable(document)
            : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.ocr),
        label: Text(isProcessing ? 'Recognizing text…' : 'Make Searchable'),
      ),
    );
  }
}
