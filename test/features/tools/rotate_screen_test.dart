import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/features/library/presentation/providers/library_providers.dart';
import 'package:pdf_reader/features/tools/rotate/presentation/rotate_screen.dart';

void main() {
  testWidgets('shows the document picker before any document is chosen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryDocumentsProvider.overrideWith((ref) => Stream.value(const []))],
        child: const MaterialApp(home: RotateScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Import a new PDF'), findsOneWidget);
    expect(find.text('No documents in your library yet.'), findsOneWidget);
    // Rotation options only appear once a document is selected.
    expect(find.text('Rotation'), findsNothing);
  });
}
