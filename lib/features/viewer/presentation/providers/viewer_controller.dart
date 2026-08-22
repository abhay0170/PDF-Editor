import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../database/database_providers.dart';

class ViewerState {
  const ViewerState({
    required this.controller,
    required this.currentPage,
    required this.toolbarVisible,
    this.searcher,
  });

  final PdfViewerController controller;
  final int currentPage;
  final bool toolbarVisible;

  /// Null until `pdfrx` reports the viewer is ready (`onViewerReady`) — its
  /// constructor null-checks `controller.isReady` internally, so it cannot
  /// be created any earlier than that without crashing.
  final PdfTextSearcher? searcher;

  ViewerState copyWith({int? currentPage, bool? toolbarVisible, PdfTextSearcher? searcher}) =>
      ViewerState(
        controller: controller,
        currentPage: currentPage ?? this.currentPage,
        toolbarVisible: toolbarVisible ?? this.toolbarVisible,
        searcher: searcher ?? this.searcher,
      );
}

/// Scoped per open document (`autoDispose.family`) so native `pdfrx`
/// resources and the search/page state are torn down as soon as the viewer
/// closes, and never leak into the next document opened.
class ViewerController extends Notifier<ViewerState> {
  ViewerController(this.documentId);

  final int documentId;
  late final PdfViewerController _pdfController;

  @override
  ViewerState build() {
    _pdfController = PdfViewerController();
    _pdfController.addListener(_onTransformChanged);
    ref.read(documentDaoProvider).touchOpened(documentId);

    ref.onDispose(() {
      _pdfController.removeListener(_onTransformChanged);
      state.searcher?.dispose();
    });

    return ViewerState(controller: _pdfController, currentPage: 1, toolbarVisible: true);
  }

  void _onTransformChanged() {
    final page = _pdfController.pageNumber;
    if (page != null && page != state.currentPage) {
      state = state.copyWith(currentPage: page);
      ref.read(documentDaoProvider).updateLastPage(documentId, page);
    }
  }

  /// Called from `PdfViewerParams.onViewerReady` once `pdfrx` has finished
  /// attaching the controller to a loaded document.
  void attachSearcherIfNeeded() {
    if (state.searcher != null) return;
    state = state.copyWith(searcher: PdfTextSearcher(_pdfController));
  }

  void toggleToolbar() => state = state.copyWith(toolbarVisible: !state.toolbarVisible);

  void setToolbarVisible(bool visible) {
    if (visible != state.toolbarVisible) {
      state = state.copyWith(toolbarVisible: visible);
    }
  }
}

final viewerControllerProvider = NotifierProvider.autoDispose
    .family<ViewerController, ViewerState, int>(ViewerController.new);
