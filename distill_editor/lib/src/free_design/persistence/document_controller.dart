import 'dart:ui';

import '../models/editor_document.dart';
import '../store/editor_document_store.dart';
import 'document_persistence_service.dart';

/// Orchestrates document lifecycle operations.
///
/// Handles:
/// - New document creation
/// - Save/load operations
/// - Error handling
/// - State reset coordination
class DocumentController {
  final EditorDocumentStore store;
  final DocumentPersistenceService persistence;
  final VoidCallback? onDocumentChanged;

  DocumentController({
    required this.store,
    required this.persistence,
    this.onDocumentChanged,
  });

  /// Create a new empty document.
  ///
  /// Clears the current document, resets undo history, and clears the save target.
  Future<void> newDocument() async {
    // TODO: Check unsaved changes first (future enhancement)
    store.replaceDocument(EditorDocument.empty(), clearUndo: true);
    persistence.clearSaveTarget();
    onDocumentChanged?.call();
  }

  /// Save the current document.
  ///
  /// If [saveAs] is true, always shows the file picker.
  /// Otherwise, saves to the last path if available.
  ///
  /// Returns true if save was successful, false if user cancelled.
  Future<bool> saveDocument({bool saveAs = false}) async {
    return persistence.save(store.document, saveAs: saveAs);
  }

  /// Load a document from file.
  ///
  /// Shows the file picker and loads the selected document.
  /// Returns true if load was successful, false if user cancelled.
  /// Throws [DocumentLoadException] on invalid file.
  Future<bool> loadDocument() async {
    // TODO: Check unsaved changes first (future enhancement)
    final doc = await persistence.load();
    if (doc == null) return false; // User cancelled
    store.replaceDocument(doc, clearUndo: true);
    onDocumentChanged?.call();
    return true;
  }

  /// Get the display name for the current document (for title bar, etc.).
  String? get documentName => persistence.lastFileName;

  /// Whether there is a save target (can "Save" without showing picker).
  bool get hasSaveTarget => persistence.hasSaveTarget;
}
