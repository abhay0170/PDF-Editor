import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_providers.dart';
import '../features/library/domain/import_state.dart';
import '../features/library/presentation/home_screen.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/providers/import_controller.dart';
import '../features/library/presentation/widgets/document_actions_sheet.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'router.dart';
import 'theme/icons.dart';

class _BottomNavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

/// Which bottom-nav tab is active. Also used by [HomeScreen]'s "View all"
/// link to jump straight to the Documents tab.
final bottomNavIndexProvider = NotifierProvider<_BottomNavIndexNotifier, int>(
  _BottomNavIndexNotifier.new,
);

/// Hosts the bottom nav (Home / Documents / Profile) and the single
/// import-result listener shared by every tab — an import can be triggered
/// from more than one place (Documents tab's FAB, Merge's inline picker),
/// so this lives above all of them rather than being duplicated per tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(bottomNavIndexProvider);

    ref.listen<AsyncValue<ImportState>>(importControllerProvider, (previous, next) {
      // AppShell stays mounted beneath any pushed tool screen even when it
      // isn't the visible/active route, so this listener keeps firing in
      // the background. importControllerProvider is also used by
      // InlineDocumentPicker's/Merge's "Import a new PDF" (see
      // import_flow.dart) from inside other screens — without this guard,
      // this handling (including its acknowledge() call, which resets the
      // shared state) races that other flow's read of the same state and
      // wins, silently swallowing the import result there.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final importState = next.value;
      if (importState == null) return;
      _handleImportState(context, ref, importState);
    });

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const [HomeScreen(), LibraryScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(bottomNavIndexProvider.notifier).setIndex(i),
        destinations: [
          NavigationDestination(icon: Icon(AppIcons.home), label: 'Home'),
          NavigationDestination(icon: Icon(AppIcons.folder), label: 'Documents'),
          NavigationDestination(icon: Icon(AppIcons.profile), label: 'Profile'),
        ],
      ),
    );
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
