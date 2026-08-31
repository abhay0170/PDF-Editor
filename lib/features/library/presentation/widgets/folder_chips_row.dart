import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import '../../../../database/database_providers.dart';
import '../providers/library_providers.dart';

/// Horizontal "All" + per-folder filter chips shown above the document
/// list. Long-press a folder chip to rename or delete it; the trailing "+"
/// chip creates a new one.
class FolderChipsRow extends ConsumerWidget {
  const FolderChipsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final selected = ref.watch(selectedFolderProvider);
    final folders = foldersAsync.value ?? const [];

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => ref.read(selectedFolderProvider.notifier).select(null),
          ),
          for (final folder in folders) ...[
            const SizedBox(width: Spacing.xs),
            GestureDetector(
              onLongPress: () => _showFolderOptions(context, ref, folder),
              child: ChoiceChip(
                label: Text(folder.name),
                selected: selected == folder.id,
                onSelected: (_) => ref.read(selectedFolderProvider.notifier).select(folder.id),
              ),
            ),
          ],
          const SizedBox(width: Spacing.xs),
          ActionChip(
            avatar: Icon(AppIcons.add, size: 16),
            label: const Text('New folder'),
            onPressed: () => _createFolder(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context, title: 'New folder');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(folderDaoProvider).insertFolder(name.trim());
  }

  Future<void> _showFolderOptions(BuildContext context, WidgetRef ref, Folder folder) async {
    final action = await showModalBottomSheet<_FolderAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(AppIcons.pencil),
              title: const Text('Rename'),
              onTap: () => Navigator.of(sheetContext).pop(_FolderAction.rename),
            ),
            ListTile(
              leading: Icon(AppIcons.trash),
              title: const Text('Delete folder'),
              onTap: () => Navigator.of(sheetContext).pop(_FolderAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _FolderAction.rename:
        final name = await _promptForName(context, title: 'Rename folder', initial: folder.name);
        if (name == null || name.trim().isEmpty) return;
        await ref.read(folderDaoProvider).rename(folder.id, name.trim());
      case _FolderAction.delete:
        if (ref.read(selectedFolderProvider) == folder.id) {
          ref.read(selectedFolderProvider.notifier).select(null);
        }
        await ref.read(folderDaoProvider).deleteById(folder.id);
    }
  }

  Future<String?> _promptForName(BuildContext context, {required String title, String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

enum _FolderAction { rename, delete }
