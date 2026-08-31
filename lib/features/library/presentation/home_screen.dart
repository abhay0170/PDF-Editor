import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/app_shell.dart';
import '../../../app/router.dart';
import '../../../app/theme/icons.dart';
import '../../../app/theme/radii.dart';
import '../../../app/theme/spacing.dart';
import '../../../app/theme/tool_colors.dart';
import 'providers/import_controller.dart';
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
        onPressed: () => _showAddOptionsSheet(context, ref),
        tooltip: 'Add',
        shape: const CircleBorder(),
        child: Icon(AppIcons.add, size: 26),
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

  void _showAddOptionsSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xl, Spacing.xl, Spacing.xl, Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AddOptionButton(
                icon: AppIcons.camera,
                label: 'Camera',
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  AppRoutes.openScan(context);
                },
              ),
              const SizedBox(height: Spacing.md),
              _AddOptionButton(
                icon: AppIcons.image,
                label: 'Photos',
                backgroundColor: ToolColors.scan,
                foregroundColor: Colors.white,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  AppRoutes.openScan(context, autoPickFromGallery: true);
                },
              ),
              const SizedBox(height: Spacing.md),
              _AddOptionButton(
                icon: AppIcons.file,
                label: 'Import Files',
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface,
                border: Border.all(color: theme.dividerColor),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(importControllerProvider.notifier).pickAndImportPdf();
                },
              ),
              const SizedBox(height: Spacing.xl),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: theme.cardColor),
                onPressed: () => Navigator.of(sheetContext).pop(),
                icon: Icon(AppIcons.close, color: theme.textTheme.bodyLarge?.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width, tall action button for the "add" sheet — closer in
/// prominence to the reference design's stacked Camera/Photos/Import
/// buttons than a standard [FilledButton].
class _AddOptionButton extends StatelessWidget {
  const _AddOptionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.border,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final BoxBorder? border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: backgroundColor,
        borderRadius: Radii.largeRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.largeRadius,
          child: Container(
            decoration: BoxDecoration(borderRadius: Radii.largeRadius, border: border),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: foregroundColor),
                const SizedBox(width: Spacing.sm),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: foregroundColor, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
