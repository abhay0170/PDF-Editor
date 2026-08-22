import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../core/utils/document_download.dart';
import '../../../../database/app_database.dart';
import '../../../../database/database_providers.dart';
import 'document_thumbnail.dart';

class DocumentListRow extends ConsumerWidget {
  const DocumentListRow({super.key, required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metadata = document.pageCount > 0
        ? '${document.pageCount} pages · ${formatShortDate(document.modifiedAt)}'
        : formatShortDate(document.modifiedAt);

    return Semantics(
      button: true,
      label: '${document.displayName}, $metadata',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenHorizontal,
            vertical: Spacing.sm,
          ),
          child: SizedBox(
            height: Spacing.listRowHeight,
            child: Row(
              children: [
                DocumentThumbnail(document: document, width: 44, height: 58),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(metadata, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.more, size: 20),
                  tooltip: 'More options',
                  onPressed: () => _showActionsSheet(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(AppIcons.pencil),
                title: const Text('Rename'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRenameDialog(context, ref);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.download),
                title: const Text('Download'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  downloadDocument(context, document);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.trash),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(context, ref);
                },
              ),
              const SizedBox(height: Spacing.sm),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: document.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newName != null && newName.isNotEmpty && newName != document.displayName) {
      await ref.read(documentDaoProvider).rename(document.id, newName);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('"${document.displayName}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(documentDaoProvider).deleteById(document.id);
      final file = File(document.path);
      if (file.existsSync()) await file.delete();
      final thumbPath = document.thumbnailPath;
      if (thumbPath != null && File(thumbPath).existsSync()) {
        await File(thumbPath).delete();
      }
    }
  }
}
