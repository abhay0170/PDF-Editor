import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../database/app_database.dart';

/// Saves a copy of [document]'s PDF bytes to a location the user picks via
/// the system save dialog (e.g. Downloads) — the app's internal storage
/// isn't visible to other apps, so this is how a document gets out to
/// Files/email/etc. Shared by the library row and viewer actions.
Future<void> downloadDocument(BuildContext context, Document document) async {
  try {
    final bytes = await File(document.path).readAsBytes();
    final savedUri = await FilePicker.saveFile(
      fileName: document.displayName,
      bytes: bytes,
      mimeType: 'application/pdf',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(savedUri != null ? 'Saved to your chosen location.' : 'Download canceled.'),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not download this document.')),
    );
  }
}
