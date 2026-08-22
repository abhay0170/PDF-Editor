import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/app_database.dart';
import '../../../../database/daos/document_dao.dart';
import '../../../../database/database_providers.dart';

class LibrarySortNotifier extends Notifier<SortSpec> {
  @override
  SortSpec build() => const SortSpec(DocumentSortField.name);

  void setSort(SortSpec sort) => state = sort;
}

final librarySortProvider = NotifierProvider<LibrarySortNotifier, SortSpec>(
  LibrarySortNotifier.new,
);

final libraryDocumentsProvider = StreamProvider<List<Document>>((ref) {
  final sort = ref.watch(librarySortProvider);
  return ref.watch(documentDaoProvider).watchAll(sort: sort);
});

final recentDocumentsProvider = StreamProvider<List<Document>>((ref) {
  return ref.watch(documentDaoProvider).watchRecent();
});
