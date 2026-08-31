import 'package:flutter/material.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/spacing.dart';

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key, required this.onAddPdf});

  final VoidCallback onAddPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxxl, vertical: Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.folder, size: 40, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: Spacing.lg),
            Text('No documents', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text(
              'Add a PDF to get started.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xxl),
            ElevatedButton(onPressed: onAddPdf, child: const Text('Add PDF')),
          ],
        ),
      ),
    );
  }
}
