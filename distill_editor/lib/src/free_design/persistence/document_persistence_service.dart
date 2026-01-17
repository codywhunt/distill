import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/editor_document.dart';

// Conditional import for dart:io (only available on non-web platforms)
import 'document_persistence_io.dart'
    if (dart.library.html) 'document_persistence_web.dart' as platform;

/// Service for saving and loading documents.
///
/// Handles platform differences:
/// - Desktop: writes to file paths, remembers last save path
/// - Web: triggers downloads, remembers filename for display
class DocumentPersistenceService {
  static const _fileType = 'distill_editor_document';
  static const _currentVersion = '1.0';
  static const _fileExtension = 'distill';

  // Desktop: full path. Web: just filename for display.
  String? _lastSavePath;
  String? _lastFileName;

  /// Save document to file.
  ///
  /// - Desktop: writes to path (or shows picker if saveAs or no path)
  /// - Web: triggers download with filename
  ///
  /// Returns true if save was successful, false if user cancelled.
  Future<bool> save(EditorDocument doc, {bool saveAs = false}) async {
    final bytes = _encodeDocument(doc);
    final suggestedName = _lastFileName ?? 'untitled.$_fileExtension';

    if (kIsWeb) {
      // Web: always download
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Document',
        fileName: suggestedName,
        bytes: bytes,
        allowedExtensions: [_fileExtension],
        type: FileType.custom,
      );
      if (result != null) {
        _lastFileName = result.split('/').last;
        return true;
      }
      return false;
    } else {
      // Desktop: write to file
      if (!saveAs && _lastSavePath != null) {
        await platform.writeFile(_lastSavePath!, bytes);
        return true;
      }
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Document',
        fileName: suggestedName,
        allowedExtensions: [_fileExtension],
        type: FileType.custom,
      );
      if (result != null) {
        await platform.writeFile(result, bytes);
        _lastSavePath = result;
        _lastFileName = result.split('/').last;
        return true;
      }
      return false;
    }
  }

  /// Load document from file picker.
  ///
  /// Returns null if user cancelled.
  /// Throws [DocumentLoadException] on invalid file.
  Future<EditorDocument?> load() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [_fileExtension],
      withData: true, // Required for web
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      throw DocumentLoadException('Failed to read file data');
    }

    final doc = _decodeDocument(bytes);
    _lastFileName = file.name;
    if (!kIsWeb && file.path != null) {
      _lastSavePath = file.path;
    }
    return doc;
  }

  /// Get the filename of the last saved/loaded document (for UI display).
  String? get lastFileName => _lastFileName;

  /// Whether we have a save target (can "Save" without showing picker).
  bool get hasSaveTarget =>
      kIsWeb ? _lastFileName != null : _lastSavePath != null;

  /// Clear save target (for "New Document").
  void clearSaveTarget() {
    _lastSavePath = null;
    _lastFileName = null;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Uint8List _encodeDocument(EditorDocument doc) {
    final wrapper = {
      'type': _fileType,
      'version': _currentVersion,
      'document': doc.toJson(),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(wrapper)));
  }

  EditorDocument _decodeDocument(Uint8List bytes) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (e) {
      throw DocumentLoadException('Invalid file format: not valid JSON');
    }

    // Validate wrapper
    if (json['type'] != _fileType) {
      throw DocumentLoadException('Not a valid Distill document');
    }
    final version = json['version'] as String?;
    if (version != _currentVersion) {
      throw DocumentLoadException(
        'Unsupported document version: $version (expected $_currentVersion)',
      );
    }

    final docJson = json['document'];
    if (docJson is! Map<String, dynamic>) {
      throw DocumentLoadException('Invalid document structure');
    }

    try {
      return EditorDocument.fromJson(docJson);
    } catch (e) {
      throw DocumentLoadException('Failed to parse document: $e');
    }
  }
}

/// Exception thrown when loading a document fails.
class DocumentLoadException implements Exception {
  final String message;
  DocumentLoadException(this.message);

  @override
  String toString() => message;
}
