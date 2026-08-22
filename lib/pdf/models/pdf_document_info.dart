class PdfDocumentInfo {
  const PdfDocumentInfo({required this.pageCount, required this.isEncrypted});

  final int pageCount;
  final bool isEncrypted;
}

/// Result of a headless probe of a candidate PDF file during import.
sealed class PdfProbeResult {
  const PdfProbeResult();
}

class PdfProbeOk extends PdfProbeResult {
  const PdfProbeOk(this.info);

  final PdfDocumentInfo info;
}

class PdfProbePasswordRequired extends PdfProbeResult {
  const PdfProbePasswordRequired();
}

class PdfProbeCorrupted extends PdfProbeResult {
  const PdfProbeCorrupted(this.message);

  final String message;
}

class PdfProbeMissingFile extends PdfProbeResult {
  const PdfProbeMissingFile();
}
