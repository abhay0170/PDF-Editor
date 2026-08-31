import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import '../../domain/tool_run_state.dart';
import '../../widgets/inline_document_picker.dart';
import 'providers/export_controller.dart';

class ExportScreen extends HookConsumerWidget {
  const ExportScreen({super.key, this.initialDocument});

  final Document? initialDocument;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDocument = useState<Document?>(initialDocument);
    final format = useState(ExportFormat.txt);
    final exportState = ref.watch(exportControllerProvider);
    final isProcessing = exportState.value is ToolProcessing;

    ref.listen<AsyncValue<ExportState>>(exportControllerProvider, (previous, next) {
      final value = next.value;
      switch (value) {
        case ToolSuccess(:final result):
          ref.read(exportControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result ? 'Saved to your chosen location.' : 'Export canceled.')),
          );
        case ToolError(:final message):
          ref.read(exportControllerProvider.notifier).reset();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case ToolIdle():
        case ToolProcessing():
        case null:
          break;
      }
    });

    final theme = Theme.of(context);
    final document = selectedDocument.value;
    final formatLabel = format.value == ExportFormat.txt ? 'TXT' : 'DOCX';

    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal, vertical: Spacing.lg),
        children: [
          Text('Document', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          InlineDocumentPicker(
            selected: document,
            onSelected: (doc) => selectedDocument.value = doc,
          ),
          const SizedBox(height: Spacing.xxl),
          Text('Format', style: theme.textTheme.titleLarge),
          const SizedBox(height: Spacing.md),
          SegmentedButton<ExportFormat>(
            segments: const [
              ButtonSegment(value: ExportFormat.txt, label: Text('TXT')),
              ButtonSegment(value: ExportFormat.docx, label: Text('DOCX')),
            ],
            selected: {format.value},
            onSelectionChanged: (selection) => format.value = selection.first,
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
                'Pulls the text already in this PDF and saves it as a plain-text or Word file '
                '(paragraphs only — no formatting, images, or layout carried over). Pages that are '
                'only images (no text layer) won\'t contribute anything — run "Make searchable" '
                '(OCR) on them first.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Spacing.fabClearance),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (document != null && !isProcessing)
            ? () => ref.read(exportControllerProvider.notifier).export(document, format.value)
            : null,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(AppIcons.export),
        label: Text(isProcessing ? 'Exporting…' : 'Export as $formatLabel'),
      ),
    );
  }
}
