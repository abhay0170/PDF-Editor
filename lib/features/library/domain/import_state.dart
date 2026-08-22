sealed class ImportState {
  const ImportState();
}

class ImportIdle extends ImportState {
  const ImportIdle();
}

class ImportPicking extends ImportState {
  const ImportPicking();
}

class ImportCopying extends ImportState {
  const ImportCopying();
}

/// [path] is the app-managed copy already on disk; retry via
/// [ImportController.retryWithPassword].
class ImportPasswordRequired extends ImportState {
  const ImportPasswordRequired(this.path, {this.wrongPassword = false});

  final String path;
  final bool wrongPassword;
}

class ImportDuplicate extends ImportState {
  const ImportDuplicate(this.existingDocumentId);

  final int existingDocumentId;
}

class ImportCorrupted extends ImportState {
  const ImportCorrupted(this.message);

  final String message;
}

class ImportSuccess extends ImportState {
  const ImportSuccess(this.documentId);

  final int documentId;
}
