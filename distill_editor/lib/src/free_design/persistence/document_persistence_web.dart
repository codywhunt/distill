import 'dart:typed_data';

/// Write bytes to a file (web stub - not used on web).
///
/// On web, file_picker handles downloads directly via the bytes parameter.
/// This stub exists to satisfy the conditional import.
Future<void> writeFile(String path, Uint8List bytes) async {
  // On web, this should never be called - file_picker handles downloads.
  throw UnsupportedError('Direct file writes not supported on web');
}
