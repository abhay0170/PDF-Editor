import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';

import '../../../app/theme/icons.dart';
import '../../../app/theme/radii.dart';
import '../../../app/theme/spacing.dart';
import '../../../core/errors/pdf_exceptions.dart';
import '../../../database/app_database.dart';
import '../../../database/database_providers.dart';
import '../../../pdf/renderer/pdf_viewer_config.dart';
import 'providers/bookmark_providers.dart';
import 'providers/viewer_controller.dart';
import 'widgets/download_size_sheet.dart';
import 'widgets/viewer_bottom_bar.dart';
import 'widgets/viewer_search_bar.dart';
import 'widgets/viewer_top_bar.dart';

class ViewerScreen extends HookConsumerWidget {
  const ViewerScreen({super.key, required this.documentId});

  final int documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = ref.watch(documentByIdProvider(documentId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: documentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _ViewerMessage(message: 'This document could no longer be found.'),
        data: (document) {
          if (document == null) {
            return const _ViewerMessage(message: 'This document could no longer be found.');
          }
          return _ViewerBody(document: document);
        },
      ),
    );
  }
}

/// Split into narrow `Consumer`/[ConsumerWidget] layers below rather than one
/// `ref.watch` of the whole [ViewerState] — a page turn or toolbar toggle
/// previously rebuilt this entire widget, including reconstructing
/// [PdfViewer.file]'s `params` (and its closures) from scratch on every
/// frame. Now only the top bar and bottom bar rebuild on their respective
/// state changes, and the PDF viewer itself keeps a stable `params` instance.
class _ViewerBody extends HookConsumerWidget {
  const _ViewerBody({required this.document});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = viewerControllerProvider(document.id);
    final controller = ref.watch(provider.select((s) => s.controller));
    final searcher = ref.watch(provider.select((s) => s.searcher));
    final viewerNotifier = ref.read(provider.notifier);

    final searchActive = useState(false);
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;

    final params = useMemoized(
      () => buildPdfViewerParams(
        backgroundColor: backgroundColor,
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          PdfOverlayInteractionRegion(
            onTap: (_) {
              viewerNotifier.toggleToolbar();
              return true;
            },
            child: SizedBox(width: size.width, height: size.height),
          ),
        ],
        errorBannerBuilder: (context, error, stackTrace, documentRef) =>
            _ViewerMessage(message: _messageForError(error)),
        onViewerReady: (document, controller) => viewerNotifier.attachSearcherIfNeeded(),
      ),
      [document.id, backgroundColor],
    );

    // SizedBox.expand forces tight constraints onto the Stack regardless of
    // what the Scaffold body passes down. Without it, a Stack with a
    // non-Positioned child (the top bar below) can shrink-wrap to that
    // child's small intrinsic height instead of filling the screen, which
    // squeezes the PdfViewer into a sliver and makes the page look blank.
    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: PdfViewer.file(
              document.path,
              controller: controller,
              initialPageNumber: document.lastPage > 0 ? document.lastPage : 1,
              params: params,
            ),
          ),
          if (searchActive.value && searcher != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ViewerSearchBar(
                searcher: searcher,
                onClose: () => searchActive.value = false,
              ),
            )
          else
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ViewerTopBarLayer(
                documentId: document.id,
                title: document.displayName,
                onBack: () => Navigator.of(context).pop(),
                onMore: () => _showMoreSheet(context, document),
              ),
            ),
          if (!searchActive.value)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ViewerBottomBarLayer(
                document: document,
                controller: controller,
                canSearch: searcher != null,
                onSearch: () => searchActive.value = true,
              ),
            ),
        ],
      ),
    );
  }

  static String _messageForError(Object error) {
    return switch (error) {
      PdfPasswordException() => const PdfPasswordRequiredException().message,
      PdfException() => const PdfCorruptedException().message,
      _ => const PdfOpenException().message,
    };
  }

  static void _showMoreSheet(BuildContext context, Document document) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(AppIcons.info),
              title: const Text('Document info'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showInfoSheet(context, document, const [], null);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDownloadSizeSheet(context, document);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.print),
              title: const Text('Print'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _printDocument(context, document);
              },
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }

  static Future<void> _printDocument(BuildContext context, Document document) async {
    try {
      final bytes = await File(document.path).readAsBytes();
      await Printing.layoutPdf(name: document.displayName, onLayout: (_) async => bytes);
    } catch (e) {
      debugPrint('Print document failed: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not print this document.')));
    }
  }

  static void _showInfoSheet(
    BuildContext context,
    Document document,
    List<Bookmark> bookmarks,
    PdfViewerController? controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: Radii.bottomSheetTop),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.displayName, style: theme.textTheme.titleLarge),
                const SizedBox(height: Spacing.md),
                Text('${document.pageCount} pages', style: theme.textTheme.bodyMedium),
                Text(
                  '${(document.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: theme.textTheme.bodyMedium,
                ),
                if (bookmarks.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xl),
                  Text('Bookmarks', style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.sm),
                  for (final bookmark in bookmarks)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(AppIcons.bookmark, size: 18, color: theme.colorScheme.primary),
                      title: Text('Page ${bookmark.page}'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        controller?.goToPage(pageNumber: bookmark.page);
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Watches only [ViewerState.toolbarVisible] — a page turn (which changes
/// `currentPage`) no longer rebuilds the top bar.
class _ViewerTopBarLayer extends ConsumerWidget {
  const _ViewerTopBarLayer({
    required this.documentId,
    required this.title,
    required this.onBack,
    required this.onMore,
  });

  final int documentId;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolbarVisible = ref.watch(
      viewerControllerProvider(documentId).select((s) => s.toolbarVisible),
    );
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: toolbarVisible ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: toolbarVisible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !toolbarVisible,
          child: ViewerTopBar(title: title, onBack: onBack, onMore: onMore),
        ),
      ),
    );
  }
}

/// Watches [ViewerState.toolbarVisible] and [ViewerState.currentPage] plus
/// the document's bookmarks — isolated from the top bar and the PDF viewer
/// itself so neither rebuilds when only the current page changes.
class _ViewerBottomBarLayer extends ConsumerWidget {
  const _ViewerBottomBarLayer({
    required this.document,
    required this.controller,
    required this.canSearch,
    required this.onSearch,
  });

  final Document document;
  final PdfViewerController controller;
  final bool canSearch;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = viewerControllerProvider(document.id);
    final toolbarVisible = ref.watch(provider.select((s) => s.toolbarVisible));
    final currentPage = ref.watch(provider.select((s) => s.currentPage));
    final bookmarksAsync = ref.watch(bookmarksForDocumentProvider(document.id));
    final bookmarks = bookmarksAsync.value ?? const <Bookmark>[];
    final currentBookmark = bookmarks.where((b) => b.page == currentPage).firstOrNull;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: toolbarVisible ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: toolbarVisible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !toolbarVisible,
          child: ViewerBottomBar(
            isBookmarked: currentBookmark != null,
            onSearch: canSearch ? onSearch : null,
            onToggleBookmark: () => _toggleBookmark(ref, document, currentPage, currentBookmark),
            onInfo: () => _ViewerBody._showInfoSheet(context, document, bookmarks, controller),
          ),
        ),
      ),
    );
  }

  static Future<void> _toggleBookmark(
    WidgetRef ref,
    Document document,
    int page,
    Bookmark? existing,
  ) async {
    final dao = ref.read(bookmarkDaoProvider);
    if (existing != null) {
      await dao.deleteById(existing.id);
    } else {
      await dao.insertBookmark(
        BookmarksCompanion.insert(documentId: document.id, page: page, createdAt: DateTime.now()),
      );
    }
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
