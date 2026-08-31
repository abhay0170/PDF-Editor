import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/icons.dart';
import '../../../app/theme/spacing.dart';
import '../../../database/app_database.dart';
import '../../../database/daos/document_dao.dart';
import '../../../database/database_providers.dart';
import 'providers/import_controller.dart';
import 'providers/library_providers.dart';
import 'widgets/document_list_row.dart';
import 'widgets/folder_chips_row.dart';
import 'widgets/library_empty_state.dart';

/// The Documents tab — search, sort, and the full document list. The
/// greeting header, tools grid, and recent-documents preview live on the
/// Home tab instead; see `home_screen.dart`.
class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final searchDebounce = useRef<Timer?>(null);
    useEffect(() => () => searchDebounce.value?.cancel(), const []);
    final documentsAsync = ref.watch(libraryDocumentsProvider);
    final selectedFolder = ref.watch(selectedFolderProvider);
    final selectedIds = useState<Set<int>>(const {});
    final selectionMode = selectedIds.value.isNotEmpty;

    final documents = documentsAsync.value ?? const <Document>[];
    final query = searchQuery.value.toLowerCase();
    final filtered = documents.where((d) {
      if (selectedFolder != null && d.folderId != selectedFolder) return false;
      if (query.isEmpty) return true;
      return d.displayName.toLowerCase().contains(query) ||
          (d.content?.toLowerCase().contains(query) ?? false);
    }).toList();

    void clearSelection() => selectedIds.value = const {};

    void toggleSelected(int id) {
      final next = {...selectedIds.value};
      if (!next.remove(id)) next.add(id);
      selectedIds.value = next;
    }

    Future<void> deleteSelected() async {
      final ids = selectedIds.value;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Delete ${ids.length} ${ids.length == 1 ? 'document' : 'documents'}?'),
          content: const Text('They will be permanently removed.'),
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
      if (confirmed != true) return;

      final toDelete = documents.where((d) => ids.contains(d.id)).toList();
      await ref.read(documentDaoProvider).deleteByIds(ids.toList());
      for (final doc in toDelete) {
        final file = File(doc.path);
        if (file.existsSync()) await file.delete();
        final thumbPath = doc.thumbnailPath;
        if (thumbPath != null && File(thumbPath).existsSync()) {
          await File(thumbPath).delete();
        }
      }
      clearSelection();
    }

    return Scaffold(
      appBar: selectionMode
          ? AppBar(
              leading: IconButton(
                icon: Icon(AppIcons.close),
                tooltip: 'Cancel selection',
                onPressed: clearSelection,
              ),
              title: Text('${selectedIds.value.length} selected'),
              actions: [
                IconButton(
                  icon: Icon(AppIcons.check),
                  tooltip: 'Select all',
                  onPressed: () => selectedIds.value = filtered.map((d) => d.id).toSet(),
                ),
                IconButton(
                  icon: Icon(AppIcons.trash),
                  tooltip: 'Delete selected',
                  onPressed: deleteSelected,
                ),
              ],
            )
          : AppBar(title: const Text('Documents')),
      floatingActionButton: selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => ref.read(importControllerProvider.notifier).pickAndImportPdf(),
              tooltip: 'Add PDF',
              child: Icon(AppIcons.add),
            ),
      body: documentsAsync.when(
        loading: () => const _LibrarySkeleton(),
        error: (error, _) => Center(
          child: Text('Something went wrong loading your library.', style: Theme.of(context).textTheme.bodyMedium),
        ),
        data: (_) {
          if (documents.isEmpty) {
            return LibraryEmptyState(
              onAddPdf: () => ref.read(importControllerProvider.notifier).pickAndImportPdf(),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.screenHorizontal,
                  Spacing.sectionSpacing,
                  Spacing.screenHorizontal,
                  Spacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('All Documents', style: Theme.of(context).textTheme.titleLarge),
                          _SortMenuButton(ref: ref),
                        ],
                      ),
                      const SizedBox(height: Spacing.sm),
                      const FolderChipsRow(),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        '${documents.length} ${documents.length == 1 ? 'document' : 'documents'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: Spacing.md),
                      TextField(
                        onChanged: (value) {
                          searchDebounce.value?.cancel();
                          searchDebounce.value = Timer(
                            const Duration(milliseconds: 250),
                            () => searchQuery.value = value,
                          );
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name or text inside documents',
                          prefixIcon: Icon(AppIcons.search, size: 20),
                        ),
                      ),
                      const SizedBox(height: Spacing.sm),
                    ],
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: Spacing.screenHorizontal + 56,
                  color: Theme.of(context).dividerColor,
                ),
                itemBuilder: (_, index) {
                  final doc = filtered[index];
                  return DocumentListRow(
                    document: doc,
                    onTap: selectionMode
                        ? () => toggleSelected(doc.id)
                        : () => AppRoutes.openViewer(context, documentId: doc.id),
                    onLongPress: () => toggleSelected(doc.id),
                    selectionMode: selectionMode,
                    selected: selectedIds.value.contains(doc.id),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: Spacing.fabClearance)),
            ],
          );
        },
      ),
    );
  }

}

class _SortMenuButton extends StatelessWidget {
  const _SortMenuButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DocumentSortField>(
      icon: Icon(AppIcons.sortAndFilter, size: 20),
      tooltip: 'Sort',
      onSelected: (field) =>
          ref.read(librarySortProvider.notifier).setSort(SortSpec(field)),
      itemBuilder: (_) => const [
        PopupMenuItem(value: DocumentSortField.name, child: Text('Name')),
        PopupMenuItem(value: DocumentSortField.lastOpened, child: Text('Last opened')),
        PopupMenuItem(value: DocumentSortField.dateAdded, child: Text('Date added')),
        PopupMenuItem(value: DocumentSortField.pageCount, child: Text('Page count')),
      ],
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).dividerColor.withValues(alpha: 0.6);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.screenHorizontal,
        vertical: Spacing.lg,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        child: Row(
          children: [
            Container(width: 44, height: 58, color: placeholderColor),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 160, color: placeholderColor),
                  const SizedBox(height: Spacing.sm),
                  Container(height: 12, width: 100, color: placeholderColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
