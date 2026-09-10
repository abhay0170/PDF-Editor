import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../core/utils/page_range_parser.dart';
import '../../../../database/app_database.dart';
import '../../domain/tool_run_state.dart';
import '../../widgets/inline_document_picker.dart';
import 'providers/extract_controller.dart';

class ExtractScreen extends HookConsumerWidget {
  const ExtractScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final pagesController = useTextEditingController();
    final isProcessing = ref.watch(extractControllerProvider.select((s) => s.value is ToolProcessing));

    ref.listen<AsyncValue<ExtractState>>(extractControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(extractControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(extractControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    Future<void> runExtract() async {
      final document = selectedDocument.value;
      if (document == null) return;

      List<int> pages;
      try {
        pages = parsePageRanges(pagesController.text, pageCount: document.pageCount);
      } on FormatException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }

      await ref.read(extractControllerProvider.notifier).extract(document, pages);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Extract Pages')),
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
            Text('Pages to extract', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text(
              'e.g. "1-3, 5" (${selectedDocument.value!.pageCount} pages total)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: pagesController,
              decoration: const InputDecoration(hintText: '1-3, 5'),
            ),
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: Radii.mediumRadius,
              ),
              child: Text(
                'Extracted pages are recreated as images — text won’t be selectable or searchable.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (selectedDocument.value != null && !isProcessing) ? runExtract : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.extract),
        label: Text(isProcessing ? 'Extracting…' : 'Extract'),
      ),
    );
  }
}
