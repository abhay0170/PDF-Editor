import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/icons.dart';
import '../../../../app/theme/radii.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../database/app_database.dart';
import '../../../../database/database_providers.dart';
import '../providers/library_providers.dart';

/// Shown right after a PDF is added to the library — a fast way to jump
/// into a tool with the new document already selected, instead of landing
/// straight in the viewer with no sense of what else is possible.
Future<void> showDocumentActionsSheet(BuildContext context, Document document) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Added to your library', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: Spacing.xs),
                Text(
                  document.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          _ActionTile(
            icon: AppIcons.file,
            title: 'Open',
            onTap: () {
              Navigator.of(sheetContext).pop();
              AppRoutes.openViewer(context, documentId: document.id);
            },
          ),
          _ActionTile(
            icon: AppIcons.folder,
            title: 'Move to folder',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _showMoveToFolderSheet(context, document);
            },
          ),
          _ActionTile(
            icon: AppIcons.rotate,
            title: 'Rotate',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openRotate),
          ),
          _ActionTile(
            icon: AppIcons.compress,
            title: 'Compress',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openCompress),
          ),
          _ActionTile(
            icon: AppIcons.sign,
            title: 'Sign',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openSign),
          ),
          _ActionTile(
            icon: AppIcons.watermark,
            title: 'Watermark',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openWatermark),
          ),
          _ActionTile(
            icon: AppIcons.split,
            title: 'Split',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openSplit),
          ),
          _ActionTile(
            icon: AppIcons.extract,
            title: 'Extract pages',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openExtract),
          ),
          _ActionTile(
            icon: AppIcons.merge,
            title: 'Merge with another PDF',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openMerge),
          ),
          _ActionTile(
            icon: AppIcons.ocr,
            title: 'Make searchable',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openOcr),
          ),
          _ActionTile(
            icon: AppIcons.export,
            title: 'Export as TXT / DOCX',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openExport),
          ),
          _ActionTile(
            icon: AppIcons.lock,
            title: 'Protect',
            onTap: () => _openTool(sheetContext, context, document, AppRoutes.openProtect),
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    ),
  );
}

Future<void> _showMoveToFolderSheet(BuildContext context, Document document) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
    builder: (sheetContext) => Consumer(
      builder: (consumerContext, ref, _) {
        final foldersAsync = ref.watch(foldersProvider);
        final folders = foldersAsync.value ?? const [];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
                child: Text('Move to folder', style: Theme.of(consumerContext).textTheme.titleLarge),
              ),
              ListTile(
                leading: Icon(AppIcons.close, color: Theme.of(consumerContext).colorScheme.primary),
                title: const Text('Unfiled'),
                selected: document.folderId == null,
                onTap: () {
                  ref.read(documentDaoProvider).setFolder(document.id, null);
                  Navigator.of(sheetContext).pop();
                },
              ),
              for (final folder in folders)
                ListTile(
                  leading: Icon(AppIcons.folder, color: Theme.of(consumerContext).colorScheme.primary),
                  title: Text(folder.name),
                  selected: document.folderId == folder.id,
                  onTap: () {
                    ref.read(documentDaoProvider).setFolder(document.id, folder.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: Spacing.sm),
            ],
          ),
        );
      },
    ),
  );
}

void _openTool(
  BuildContext sheetContext,
  BuildContext context,
  Document document,
  Future<void> Function(BuildContext, {Document? initialDocument}) open,
) {
  Navigator.of(sheetContext).pop();
  open(context, initialDocument: document);
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      onTap: onTap,
    );
  }
}
