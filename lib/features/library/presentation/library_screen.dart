import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/icons.dart';
import '../../../app/theme/spacing.dart';
import '../../../database/daos/document_dao.dart';
import 'providers/import_controller.dart';
import 'providers/library_providers.dart';
import 'widgets/document_list_row.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(importControllerProvider.notifier).pickAndImportPdf(),
        tooltip: 'Add PDF',
        child: Icon(AppIcons.add),
      ),
      body: documentsAsync.when(
        loading: () => const _LibrarySkeleton(),
        error: (error, _) => Center(
          child: Text('Something went wrong loading your library.', style: Theme.of(context).textTheme.bodyMedium),
        ),
        data: (documents) {
          final filtered = searchQuery.value.isEmpty
              ? documents
              : documents
                    .where((d) => d.displayName.toLowerCase().contains(searchQuery.value.toLowerCase()))
                    .toList();

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
                      const SizedBox(height: Spacing.xs),
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
                          hintText: 'Search documents',
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
                    onTap: () => AppRoutes.openViewer(context, documentId: doc.id),
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
