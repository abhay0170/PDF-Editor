import 'package:flutter/material.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/spacing.dart';

/// A tappable "Import a new PDF" row — shared between MergeScreen's own
/// checklist and [InlineDocumentPicker], so the two document-selection UIs
/// look and behave identically.
class ImportPdfRow extends StatelessWidget {
  const ImportPdfRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            Icon(AppIcons.add, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: Spacing.md),
            Text(
              'Import a new PDF',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
