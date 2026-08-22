import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/icons.dart';
import '../../../app/theme/spacing.dart';
import '../../../database/app_database.dart';
import '../../../database/daos/document_dao.dart';
import '../../../database/database_providers.dart';
import '../domain/import_state.dart';
import 'providers/import_controller.dart';
import 'providers/library_providers.dart';
import 'widgets/document_actions_sheet.dart';
import 'widgets/document_list_row.dart';
import 'widgets/library_empty_state.dart';
import 'widgets/quick_tools_row.dart';
import 'widgets/recent_document_card.dart';

class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = useState('');
    final searchDebounce = useRef<Timer?>(null);
    useEffect(() => () => searchDebounce.value?.cancel(), const []);
    final documentsAsync = ref.watch(libraryDocumentsProvider);
    final recentAsync = ref.watch(recentDocumentsProvider);

    ref.listen<AsyncValue<ImportState>>(importControllerProvider, (previous, next) {
      // LibraryScreen stays mounted beneath any pushed tool screen even when
      // it isn't the visible/active route, so this listener keeps firing in
      // the background. importControllerProvider is also used by
      // InlineDocumentPicker's/Merge's "Import a new PDF" (see
      // import_flow.dart) from inside other screens — without this guard,
      // LibraryScreen's own handling (including its acknowledge() call,
      // which resets the shared state) races that other flow's read of the
      // same state and wins, silently swallowing the import result there.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final importState = next.value;
      if (importState == null) return;
      _handleImportState(context, ref, importState);
    });

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(AppIcons.settings),
            tooltip: 'Settings',
            onPressed: () => AppRoutes.openSettings(context),
          ),
        ],
      ),
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

          final recent = recentAsync.value ?? const <Document>[];

          return CustomScrollView(
            slivers: [
              if (searchQuery.value.isEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.screenHorizontal,
                    Spacing.lg,
                    Spacing.screenHorizontal,
                    Spacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text('Quick tools', style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                const SliverToBoxAdapter(child: QuickToolsRow()),
              ],
              if (recent.isNotEmpty && searchQuery.value.isEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.screenHorizontal,
                    Spacing.sectionSpacing,
                    Spacing.screenHorizontal,
                    Spacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent', style: Theme.of(context).textTheme.titleLarge),
                        TextButton(
                          onPressed: () => _confirmClearRecent(context, ref),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.screenHorizontal),
                      itemCount: recent.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Spacing.md),
                      itemBuilder: (_, index) {
                        final doc = recent[index];
                        return RecentDocumentCard(
                          document: doc,
                          onTap: () => AppRoutes.openViewer(context, documentId: doc.id),
                        );
                      },
                    ),
                  ),
                ),
              ],
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

  Future<void> _confirmClearRecent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear recent history?'),
        content: const Text('This removes documents from the Recent row. Your documents themselves are not deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(documentDaoProvider).clearRecent();
    }
  }

  void _handleImportState(BuildContext context, WidgetRef ref, ImportState importState) {
    switch (importState) {
      case ImportSuccess(:final documentId):
        ref.read(importControllerProvider.notifier).acknowledge();
        _showActionsForNewDocument(context, ref, documentId);
      case ImportPasswordRequired(:final path, :final wrongPassword):
        _promptForPassword(context, ref, path, wrongPassword: wrongPassword);
      case ImportDuplicate(:final existingDocumentId):
        ref.read(importControllerProvider.notifier).acknowledge();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This document is already in your library.'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => AppRoutes.openViewer(context, documentId: existingDocumentId),
            ),
          ),
        );
      case ImportCorrupted(:final message):
        ref.read(importControllerProvider.notifier).acknowledge();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      case ImportIdle():
      case ImportPicking():
      case ImportCopying():
        break;
    }
  }

  Future<void> _showActionsForNewDocument(BuildContext context, WidgetRef ref, int documentId) async {
    final document = await ref.read(documentDaoProvider).findById(documentId);
    if (!context.mounted) return;
    if (document == null) {
      AppRoutes.openViewer(context, documentId: documentId);
      return;
    }
    await showDocumentActionsSheet(context, document);
  }

  Future<void> _promptForPassword(
    BuildContext context,
    WidgetRef ref,
    String path, {
    required bool wrongPassword,
  }) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password required'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter password',
            errorText: wrongPassword ? 'Incorrect password' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (password == null) {
      await ref.read(importControllerProvider.notifier).cancelPendingImport(path);
    } else {
      await ref.read(importControllerProvider.notifier).retryWithPassword(path, password);
    }
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
