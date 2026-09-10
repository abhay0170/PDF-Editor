import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../core/utils/page_range_parser.dart';
import '../../../../database/app_database.dart';
import '../../domain/tool_run_state.dart';
import '../../widgets/inline_document_picker.dart';
import 'providers/split_controller.dart';

class SplitScreen extends HookConsumerWidget {
  const SplitScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final partControllers = useState<List<TextEditingController>>([
      TextEditingController(),
      TextEditingController(),
    ]);
    final isProcessing = ref.watch(splitControllerProvider.select((s) => s.value is ToolProcessing));

    // partControllers is a dynamic list (parts can be added/removed), so it
    // can't use the auto-disposing useTextEditingController hook — dispose
    // whatever's left in it ourselves when the screen unmounts.
    useEffect(() {
      return () {
        for (final controller in partControllers.value) {
          controller.dispose();
        }
      };
    }, const []);

    ref.listen<AsyncValue<SplitState>>(splitControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(splitControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created ${result.length} PDFs in your library.')),
          );
        case ToolError(:final message):
          ref.read(splitControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    void addPart() {
      partControllers.value = [...partControllers.value, TextEditingController()];
    }

    void removePart(int index) {
      final updated = [...partControllers.value];
      updated.removeAt(index).dispose();
      partControllers.value = updated;
    }

    Future<void> runSplit() async {
      final document = selectedDocument.value;
      if (document == null) return;

      final ranges = <List<int>>[];
      try {
        for (final controller in partControllers.value) {
          final text = controller.text.trim();
          if (text.isEmpty) continue;
          ranges.add(parsePageRanges(text, pageCount: document.pageCount));
        }
      } on FormatException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }

      if (ranges.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Add at least one part to split out.')));
        return;
      }

      await ref.read(splitControllerProvider.notifier).split(document, ranges);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Split PDF')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal, vertical: Spacing.lg),
        children: [
          Text('Document', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          InlineDocumentPicker(
            selected: selectedDocument.value,
            onSelected: (doc) => selectedDocument.value = doc,
          ),
          const SizedBox(height: Spacing.sectionSpacing),
          if (selectedDocument.value != null) ...[
            Text('Parts', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text(
              'One PDF per part, e.g. "1-3" or "5, 7-9" (${selectedDocument.value!.pageCount} pages total).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.md),
            for (var i = 0; i < partControllers.value.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: partControllers.value[i],
                        decoration: InputDecoration(hintText: 'Part ${i + 1}, e.g. 1-3'),
                      ),
                    ),
                    if (partControllers.value.length > 1)
                      IconButton(
                        icon: Icon(AppIcons.close, size: 18),
                        tooltip: 'Remove part',
                        onPressed: () => removePart(i),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: addPart,
              icon: Icon(AppIcons.add, size: 18),
              label: const Text('Add another part'),
            ),
            const SizedBox(height: Spacing.xxl),
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                borderRadius: Radii.mediumRadius,
              ),
              child: Text(
                'Split pages are recreated as images — text in the result won’t be selectable or searchable.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (selectedDocument.value != null && !isProcessing) ? runSplit : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.split),
        label: Text(isProcessing ? 'Splitting…' : 'Split'),
      ),
    );
  }
}
