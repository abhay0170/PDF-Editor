import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/database/app_database.dart';
import 'package:pdf_reader/features/library/presentation/providers/library_providers.dart';
import 'package:pdf_reader/features/tools/merge/presentation/merge_screen.dart';

Document _document({required int id, required String name}) {
  final now = DateTime(2026, 1, 1);
  return Document(
    id: id,
    path: '/docs/$name.pdf',
    displayName: name,
    pageCount: 5,
    fileSize: 1024,
    createdAt: now,
    modifiedAt: now,
    lastPage: 0,
    sortOrder: 0,
    isFavorite: false,
  );
}

void main() {
  testWidgets('prompts to import more PDFs when fewer than two exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryDocumentsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: MergeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Import at least two PDFs to merge them.'), findsOneWidget);
  });

  testWidgets('lists documents to select once two or more exist', (tester) async {
    final documents = [_document(id: 1, name: 'Alpha'), _document(id: 2, name: 'Beta')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryDocumentsProvider.overrideWith((ref) => Stream.value(documents)),
        ],
        child: const MaterialApp(home: MergeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });
}
