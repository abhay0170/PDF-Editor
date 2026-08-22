import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../app/router.dart';
import '../../../app/theme/icons.dart';
import '../../../app/theme/spacing.dart';
import 'providers/library_providers.dart';
import 'widgets/document_list_row.dart';
import 'widgets/quick_tools_row.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// The Home tab — a greeting header, the tools grid, and a short preview of
/// recently opened documents (full list lives on the Documents tab, reached
/// via "View all" or the bottom nav).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentDocumentsProvider).value ?? const [];
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppRoutes.openScan(context),
        tooltip: 'Scan',
        shape: const CircleBorder(),
        child: Icon(AppIcons.scan, size: 26),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.screenHorizontal,
            Spacing.lg,
            Spacing.screenHorizontal,
            Spacing.fabClearance,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_greeting()} 👋', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          style: theme.textTheme.headlineSmall,
                          children: [
                            const TextSpan(text: 'PDF '),
                            TextSpan(text: 'Reader', style: TextStyle(color: theme.colorScheme.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Scan, edit, and organize your PDFs.', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.md),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: theme.colorScheme.secondary),
                  onPressed: () => ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Pro features coming soon'))),
                  icon: Icon(AppIcons.crown, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xxl),
            const QuickToolsRow(padding: EdgeInsets.zero),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: Spacing.sectionSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent', style: theme.textTheme.titleLarge),
                  TextButton(
                    onPressed: () => ref.read(bottomNavIndexProvider.notifier).setIndex(1),
                    child: const Text('View all'),
                  ),
                ],
              ),
              for (final doc in recent.take(4))
                DocumentListRow(document: doc, onTap: () => AppRoutes.openViewer(context, documentId: doc.id)),
            ],
          ],
        ),
      ),
    );
  }
}
