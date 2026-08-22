import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/app_database.dart';
import '../../../../database/database_providers.dart';
import '../../domain/import_state.dart';
import 'import_controller.dart';

/// Runs the shared "pick a PDF and import it" flow — handles password
/// prompts, duplicate detection, and corrupted-file errors the same way
/// everywhere it's invoked (currently: every tool's document picker).
/// Returns the resulting [Document] once it's actually in the library (a
/// fresh import or the existing duplicate), or null if the user canceled or
/// the import failed.
Future<Document?> runImportFlow(BuildContext context, WidgetRef ref) async {
  await ref.read(importControllerProvider.notifier).pickAndImportPdf();
  if (!context.mounted) return null;
  return _resolveImportOutcome(context, ref);
}

Future<Document?> _resolveImportOutcome(BuildContext context, WidgetRef ref) async {
  final state = ref.read(importControllerProvider).value;
  switch (state) {
    case ImportSuccess(:final documentId):
      ref.read(importControllerProvider.notifier).acknowledge();
      return ref.read(documentDaoProvider).findById(documentId);
    case ImportPasswordRequired(:final path, :final wrongPassword):
      return _promptForPassword(context, ref, path, wrongPassword: wrongPassword);
    case ImportDuplicate(:final existingDocumentId):
      ref.read(importControllerProvider.notifier).acknowledge();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This document is already in your library.')),
        );
      }
      return ref.read(documentDaoProvider).findById(existingDocumentId);
    case ImportCorrupted(:final message):
      ref.read(importControllerProvider.notifier).acknowledge();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return null;
    case ImportIdle():
    case ImportPicking():
    case ImportCopying():
    case null:
      return null;
  }
}

Future<Document?> _promptForPassword(
  BuildContext context,
  WidgetRef ref,
  String path, {
  required bool wrongPassword,
}) async {
  if (!context.mounted) return null;
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
    return null;
  }
  await ref.read(importControllerProvider.notifier).retryWithPassword(path, password);
  if (!context.mounted) return null;
  return _resolveImportOutcome(context, ref);
}
