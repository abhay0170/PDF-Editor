import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/database/app_database.dart';
import 'package:pdf_reader/features/library/presentation/library_screen.dart';
import 'package:pdf_reader/features/library/presentation/providers/library_providers.dart';

/// Both tests below render [LibraryScreen], which includes `FolderChipsRow`
/// once the document list is non-empty — without this override that widget
/// watches `foldersProvider` down to a real `appDatabaseProvider`, opening an
/// actual native sqlite connection whose setup timer outlives a single
/// `tester.pump()` and trips the framework's "no pending timers" invariant.
final _noFoldersOverride = foldersProvider.overrideWith((ref) => Stream.value(const []));

Document _document({required int id, required String name}) {
  final now = DateTime(2026, 1, 1);
  return Document(
    id: id,
    path: '/docs/$name.pdf',
    displayName: name,
    pageCount: 12,
    fileSize: 2048,
    createdAt: now,
    modifiedAt: now,
    lastPage: 0,
    sortOrder: 0,
    isFavorite: false,
  );
}

void main() {
  testWidgets('shows the empty state when there are no documents', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryDocumentsProvider.overrideWith((ref) => Stream.value(const [])),
          recentDocumentsProvider.overrideWith((ref) => Stream.value(const [])),
          _noFoldersOverride,
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No documents'), findsOneWidget);
    expect(find.text('Add a PDF to get started.'), findsOneWidget);
  });

  testWidgets('lists documents by display name once loaded', (tester) async {
    final documents = [
      _document(id: 1, name: 'Annual Report'),
      _document(id: 2, name: 'Project Proposal'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryDocumentsProvider.overrideWith((ref) => Stream.value(documents)),
          recentDocumentsProvider.overrideWith((ref) => Stream.value(const [])),
          _noFoldersOverride,
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Annual Report'), findsOneWidget);
    expect(find.text('Project Proposal'), findsOneWidget);
    expect(find.text('2 documents'), findsOneWidget);
  });
}
