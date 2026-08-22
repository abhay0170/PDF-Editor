/// Domain-level errors for PDF operations. The UI must catch these and show
/// calm, user-facing messages instead of raw stack traces.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PdfOpenException extends AppException {
  const PdfOpenException([super.message = 'This document could not be opened.']);
}

class PdfPasswordRequiredException extends AppException {
  const PdfPasswordRequiredException([super.message = 'This document is password protected.']);
}

class PdfCorruptedException extends AppException {
  const PdfCorruptedException([super.message = 'This document appears to be damaged or corrupted.']);
}

class PdfRenderException extends AppException {
  const PdfRenderException([super.message = 'This page could not be rendered.']);
}

class PdfSearchException extends AppException {
  const PdfSearchException([super.message = 'Search could not be completed.']);
}

class PdfManipulationException extends AppException {
  const PdfManipulationException([super.message = 'This operation could not be completed.']);
}

class DocumentNotFoundException extends AppException {
  const DocumentNotFoundException([super.message = 'This document could no longer be found.']);
}

class DuplicateDocumentException extends AppException {
  const DuplicateDocumentException([super.message = 'This document is already in your library.']);
}
