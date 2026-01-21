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
/// - Unsaved changes protection
class DocumentController {
  final EditorDocumentStore store;
  final DocumentPersistenceService persistence;
  final VoidCallback? onDocumentChanged;

  /// Callback to confirm discarding unsaved changes.
  ///
  /// Return `true` to proceed with the operation, `false` to cancel.
  /// If not provided, operations will proceed without confirmation.
  final Future<bool> Function()? confirmDiscardChanges;

  DocumentController({
    required this.store,
    required this.persistence,
    this.onDocumentChanged,
    this.confirmDiscardChanges,
  });

  /// Create a new empty document.
  ///
  /// If there are unsaved changes and [confirmDiscardChanges] is provided,
  /// the user will be prompted to confirm before proceeding.
  ///
  /// Clears the current document, resets undo history, and clears the save target.
  Future<void> newDocument() async {
    if (store.hasUnsavedChanges) {
      final confirmed = await confirmDiscardChanges?.call() ?? true;
      if (!confirmed) return;
    }
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
    final success = await persistence.save(store.document, saveAs: saveAs);
    if (success) {
      store.markSaved();
    }
    return success;
  }

  /// Load a document from file.
  ///
  /// If there are unsaved changes and [confirmDiscardChanges] is provided,
  /// the user will be prompted to confirm before proceeding.
  ///
  /// Shows the file picker and loads the selected document.
  /// Returns true if load was successful, false if user cancelled.
  /// Throws [DocumentLoadException] on invalid file.
  Future<bool> loadDocument() async {
    if (store.hasUnsavedChanges) {
      final confirmed = await confirmDiscardChanges?.call() ?? true;
      if (!confirmed) return false;
    }
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
