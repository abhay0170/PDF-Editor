import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import '../../../library/presentation/providers/import_flow.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../library/presentation/widgets/document_thumbnail.dart';
import '../../../library/presentation/widgets/import_row.dart';
import '../../domain/tool_run_state.dart';
import 'providers/merge_controller.dart';

class MergeScreen extends HookConsumerWidget {
  const MergeScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(libraryDocumentsProvider);
    final initial = initialDocument;
    final selected = useState<List<Document>>(initial == null ? const [] : [initial]);
    final isProcessing = ref.watch(mergeControllerProvider.select((s) => s.value is ToolProcessing));

    ref.listen<AsyncValue<MergeState>>(mergeControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(mergeControllerProvider.notifier).reset();
          Navigator.of(context).pop();
          AppRoutes.openViewer(context, documentId: result);
        case ToolError(:final message):
          ref.read(mergeControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    void toggle(Document document) {
      final current = selected.value;
      final alreadySelected = current.any((d) => d.id == document.id);
      selected.value = alreadySelected
          ? current.where((d) => d.id != document.id).toList()
          : [...current, document];
    }

    Future<void> importNew() async {
      final imported = await runImportFlow(context, ref);
      if (imported != null && !selected.value.any((d) => d.id == imported.id)) {
        selected.value = [...selected.value, imported];
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDFs')),
      body: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text('Could not load your library.', style: Theme.of(context).textTheme.bodyMedium),
        ),
        data: (documents) {
          if (documents.length < 2) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Import at least two PDFs to merge them.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Spacing.xl),
                    FilledButton.icon(
                      onPressed: importNew,
                      icon: Icon(AppIcons.add),
                      label: const Text('Import a PDF'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.screenHorizontal,
              vertical: Spacing.lg,
            ),
            children: [
              if (selected.value.isNotEmpty) ...[
                Text('Merge order', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Drag to reorder — files are combined top to bottom.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Spacing.md),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorderItem: (oldIndex, newIndex) {
                    final list = [...selected.value];
                    final item = list.removeAt(oldIndex);
                    list.insert(newIndex, item);
                    selected.value = list;
                  },
                  itemCount: selected.value.length,
                  itemBuilder: (context, index) {
                    final document = selected.value[index];
                    return _SelectedRow(
                      key: ValueKey(document.id),
                      document: document,
                      onRemove: () => toggle(document),
                    );
                  },
                ),
                const SizedBox(height: Spacing.sectionSpacing),
              ],
              Text('All Documents', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Spacing.md),
              ImportPdfRow(onTap: importNew),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  return _CheckableRow(
                    key: ValueKey(document.id),
                    document: document,
                    checked: selected.value.any((d) => d.id == document.id),
                    onChanged: () => toggle(document),
                  );
                },
              ),
              const SizedBox(height: Spacing.fabClearance),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (selected.value.length >= 2 && !isProcessing)
            ? () => ref.read(mergeControllerProvider.notifier).merge(selected.value)
            : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.merge),
        label: Text(isProcessing ? 'Merging…' : 'Merge'),
      ),
    );
  }
}

class _CheckableRow extends StatelessWidget {
  const _CheckableRow({super.key, required this.document, required this.checked, required this.onChanged});

  final Document document;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            Checkbox(value: checked, onChanged: (_) => onChanged()),
            const SizedBox(width: Spacing.sm),
            DocumentThumbnail(document: document, width: 40, height: 52),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text(
                document.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedRow extends StatelessWidget {
  const _SelectedRow({super.key, required this.document, required this.onRemove});

  final Document document;
  final VoidCallback onRemove;

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
          Expanded(
            child: Text(
              document.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          IconButton(
            icon: Icon(AppIcons.close, size: 18),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
