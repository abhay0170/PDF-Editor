import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/app_database.dart';
import '../../../../database/database_providers.dart';

final bookmarksForDocumentProvider = StreamProvider.autoDispose.family<List<Bookmark>, int>((
  ref,
  documentId,
) {
  return ref.watch(bookmarkDaoProvider).watchForDocument(documentId);
});
