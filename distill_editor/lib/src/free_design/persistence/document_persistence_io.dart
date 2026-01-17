import 'dart:io';
import 'dart:typed_data';

/// Write bytes to a file (desktop platforms only).
Future<void> writeFile(String path, Uint8List bytes) async {
  final file = File(path);
  await file.writeAsBytes(bytes);
}
