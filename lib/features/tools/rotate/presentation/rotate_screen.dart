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
import 'providers/rotate_controller.dart';

class RotateScreen extends HookConsumerWidget {
  const RotateScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final rotateAllPages = useState(true);
    final pagesController = useTextEditingController();
    final degrees = useState(90);
    final isProcessing = ref.watch(rotateControllerProvider.select((s) => s.value is ToolProcessing));

    ref.listen<AsyncValue<RotateState>>(rotateControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(rotateControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(rotateControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    Future<void> runRotate() async {
      final document = selectedDocument.value;
      if (document == null) return;

      Set<int> pages;
      if (rotateAllPages.value) {
        pages = {for (var i = 1; i <= document.pageCount; i++) i};
      } else {
        try {
          pages = parsePageRanges(pagesController.text, pageCount: document.pageCount).toSet();
        } on FormatException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          return;
        }
      }

      await ref.read(rotateControllerProvider.notifier).rotate(document, pages, degrees.value);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Rotate PDF')),
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
            Text('Pages', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('All pages')),
                ButtonSegment(value: false, label: Text('Specific pages')),
              ],
              selected: {rotateAllPages.value},
              onSelectionChanged: (selection) => rotateAllPages.value = selection.first,
            ),
            if (!rotateAllPages.value) ...[
              const SizedBox(height: Spacing.md),
              TextField(
                controller: pagesController,
                decoration: InputDecoration(
                  hintText: 'e.g. 1-3, 5 (${selectedDocument.value!.pageCount} pages total)',
                ),
              ),
            ],
            const SizedBox(height: Spacing.sectionSpacing),
            Text('Rotation', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 90, label: Text('90°')),
                ButtonSegment(value: 180, label: Text('180°')),
                ButtonSegment(value: 270, label: Text('270°')),
              ],
              selected: {degrees.value},
              onSelectionChanged: (selection) => degrees.value = selection.first,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (selectedDocument.value != null && !isProcessing) ? runRotate : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.rotate),
        label: Text(isProcessing ? 'Rotating…' : 'Rotate'),
      ),
    );
  }
}
