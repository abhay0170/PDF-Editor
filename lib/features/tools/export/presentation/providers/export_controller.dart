import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../../database/app_database.dart';
import '../../../../../pdf/pdf_providers.dart';
import '../../../domain/tool_run_state.dart';

enum ExportFormat { txt, docx }

/// `true` if the user completed the system save dialog, `false` if they
/// canceled it.
typedef ExportState = ToolRunState<bool>;

class ExportController extends AsyncNotifier<ExportState> {
  @override
  FutureOr<ExportState> build() => const ToolIdle();

  /// Extracts [source]'s native text layer (the same extraction used for
  /// library search — not OCR) and saves it via the system save dialog, as
  /// either plain text or a minimal paragraphs-only .docx.
  Future<void> export(Document source, ExportFormat format) async {
    state = const AsyncData(ToolProcessing());
    try {
      final text = await ref.read(pdfEngineProvider).extractText(source.path);
      if (text.trim().isEmpty) {
        state = const AsyncData(
          ToolError('No text found in this document. Try "Make searchable" (OCR) first.'),
        );
        return;
      }

      final baseName = p.basenameWithoutExtension(source.displayName);
      final Uint8List bytes;
      final String fileName;
      final String mimeType;
      switch (format) {
        case ExportFormat.txt:
          bytes = Uint8List.fromList(utf8.encode(text));
          fileName = '$baseName.txt';
          mimeType = 'text/plain';
        case ExportFormat.docx:
          bytes = await _buildDocx(text);
          fileName = '$baseName.docx';
          mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      }

      final savedUri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
      state = AsyncData(ToolSuccess(savedUri != null));
    } catch (_) {
      state = const AsyncData(ToolError('Could not export this document.'));
    }
  }

  /// One paragraph per non-blank line — no rich formatting, matching the
  /// same plain-text fidelity as the .txt export.
  Future<Uint8List> _buildDocx(String text) {
    var builder = docx();
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) continue;
      builder = builder.p(line);
    }
    return DocxExporter().exportToBytes(builder.build());
  }

  void reset() => state = const AsyncData(ToolIdle());
}

final exportControllerProvider = AsyncNotifierProvider<ExportController, ExportState>(
  ExportController.new,
);
