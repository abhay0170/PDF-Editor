import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/icons.dart';
import '../../../app/theme/radii.dart';
import '../../../app/theme/spacing.dart';
import '../../../database/app_database.dart';
import '../../library/presentation/providers/import_flow.dart';
import '../../library/presentation/providers/library_providers.dart';
import '../../library/presentation/widgets/document_thumbnail.dart';
import '../../library/presentation/widgets/import_row.dart';

/// Shows every library document directly in the screen — no tap-to-open
/// picker sheet — so choosing a document is one tap instead of two.
/// Mirrors the pattern MergeScreen's own inline checklist already used.
class InlineDocumentPicker extends ConsumerWidget {
  const InlineDocumentPicker({super.key, required this.selected, required this.onSelected});

  final Document? selected;
  final ValueChanged<Document> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(libraryDocumentsProvider);
    final theme = Theme.of(context);

    return documentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
        child: Text('Could not load your library.', style: theme.textTheme.bodyMedium),
      ),
      data: (documents) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImportPdfRow(
              onTap: () async {
                final imported = await runImportFlow(context, ref);
                if (imported != null) onSelected(imported);
              },
            ),
            if (documents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
                child: Text('No documents in your library yet.', style: theme.textTheme.bodyMedium),
              )
            else ...[
              Divider(height: 1, color: theme.dividerColor),
              for (final doc in documents)
                _DocumentRow(
                  document: doc,
                  selected: selected?.id == doc.id,
                  onTap: () => onSelected(doc),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document, required this.selected, required this.onTap});

  final Document document;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.mediumRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
        decoration: BoxDecoration(
          borderRadius: Radii.mediumRadius,
          color: selected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            DocumentThumbnail(document: document, width: 40, height: 52),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text('${document.pageCount} pages', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (selected) Icon(AppIcons.check, color: theme.colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
