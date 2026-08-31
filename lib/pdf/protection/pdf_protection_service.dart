/// Adds or removes real, standards-compliant PDF password encryption —
/// unlike the rasterize-and-reassemble tools in `pdf/manipulation/`, this
/// preserves the document's original vector content, since encryption is a
/// container-level property, not something rasterizing pages could produce.
abstract class PdfProtectionService {
  /// Encrypts [sourcePath] with [password] as both the open (user) and
  /// permissions (owner) password, writing the result to [outputPath].
  Future<String> protect({
    required String sourcePath,
    required String outputPath,
    required String password,
  });

  /// Opens [sourcePath] with [password] and re-saves it to [outputPath]
  /// with encryption cleared. Throws [PdfManipulationException] if
  /// [password] is wrong.
  Future<String> removeProtection({
    required String sourcePath,
    required String outputPath,
    required String password,
  });
}
