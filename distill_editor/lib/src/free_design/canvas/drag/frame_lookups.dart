import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../render/render_document.dart';
import '../../scene/expanded_scene.dart';

/// Pre-computed lookups for a frame's expanded scene.
///
/// Built once when [ExpandedScene] is created, not during drag operations.
/// This eliminates runtime scanning for ID mappings.
///
/// ## Usage
///
/// Store in [CanvasState] cache alongside the [ExpandedScene]:
/// ```dart
/// final scene = expandScene(frame);
/// final lookups = FrameLookups.build(scene: scene, renderDoc: renderDoc);
/// // Cache both together
/// ```
///
/// ## ID Domain Mappings
///
/// - **expandedToDoc**: What document node does this expanded ID represent?
/// - **docToExpanded**: What expanded IDs represent this document node? (multi-instance)
/// - **expandedParent**: What is the parent of this expanded node? (for climbing)
@immutable
class FrameLookups {
  /// Expanded ID → Doc ID.
  ///
  /// Copied from `scene.patchTarget`.
  /// Value is null if the expanded node is unpatchable (inside instance).
  final Map<String, String?> expandedToDoc;

  /// Doc ID → List of Expanded IDs (reverse map).
  ///
  /// One document node can appear multiple times via component instances.
  /// For example, `row_1` might have expanded IDs:
  /// - `row_1` (direct reference)
  /// - `inst_a::row_1` (inside instance A)
  /// - `inst_b::row_1` (inside instance B)
  ///
  /// This is critical for INV-1: when hit testing returns an expandedId,
  /// we know the exact instance, not just the doc node.
  final Map<String, List<String>> docToExpanded;

  /// Expanded ID → Parent Expanded ID.
  ///
  /// Built by traversing the render tree.
  /// Value is null for the root node.
  ///
  /// Used for climbing to auto-layout ancestors when the hit container
  /// is an absolute container (INV-4).
  final Map<String, String?> expandedParent;

  const FrameLookups({
    required this.expandedToDoc,
    required this.docToExpanded,
    required this.expandedParent,
  });

  /// Build lookups from an [ExpandedScene] and [RenderDocument].
  ///
  /// This should be called once when the scene is created/updated,
  /// not during drag operations.
  factory FrameLookups.build({
    required ExpandedScene scene,
    required RenderDocument renderDoc,
  }) {
    // Copy expandedToDoc from scene.patchTarget
    final expandedToDoc = Map<String, String?>.from(scene.patchTarget);

    // Build docToExpanded (reverse map)
    final docToExpanded = <String, List<String>>{};
    for (final entry in scene.patchTarget.entries) {
      final expandedId = entry.key;
      final docId = entry.value;
      if (docId != null) {
        docToExpanded.putIfAbsent(docId, () => []).add(expandedId);
      }
    }

    // Build expandedParent by traversing render tree
    final expandedParent = <String, String?>{};

    void visitNode(String expandedId, String? parentExpandedId) {
      expandedParent[expandedId] = parentExpandedId;
      final node = renderDoc.nodes[expandedId];
      if (node != null) {
        for (final childId in node.childIds) {
          visitNode(childId, expandedId);
        }
      }
    }

    // Start traversal from root
    if (renderDoc.rootId.isNotEmpty) {
      visitNode(renderDoc.rootId, null);
    }

    return FrameLookups(
      expandedToDoc: expandedToDoc,
      docToExpanded: docToExpanded,
      expandedParent: expandedParent,
    );
  }

  /// Get the document ID for an expanded ID.
  ///
  /// Returns null if:
  /// - The expanded ID is not in the scene
  /// - The expanded node is unpatchable (inside instance)
  String? getDocId(String expandedId) => expandedToDoc[expandedId];

  /// Get all expanded IDs for a document ID.
  ///
  /// Returns empty list if the document ID is not in the scene.
  List<String> getExpandedIds(String docId) => docToExpanded[docId] ?? const [];

  /// Get the parent expanded ID for an expanded ID.
  ///
  /// Returns null if:
  /// - The expanded ID is the root
  /// - The expanded ID is not in the scene
  String? getParent(String expandedId) => expandedParent[expandedId];

  /// Walk up the parent chain until a condition is met.
  ///
  /// [predicate] is called for each ancestor. If it returns true, that
  /// ancestor is returned. If no ancestor satisfies the predicate, returns null.
  ///
  /// Useful for climbing to find an auto-layout ancestor (INV-4).
  String? findAncestor(String expandedId, bool Function(String) predicate) {
    var current = expandedParent[expandedId];
    while (current != null) {
      if (predicate(current)) {
        return current;
      }
      current = expandedParent[current];
    }
    return null;
  }

  /// Validate that all reflow offset keys exist in the render document.
  ///
  /// Returns true if all keys are valid, false if any key is missing.
  /// This supports INV-3: reflow keys must exist in render tree.
  ///
  /// Usage:
  /// ```dart
  /// assert(lookups.validateReflowKeys(reflowOffsets, renderDoc),
  ///   'INV-3: Reflow keys must exist in renderDoc.nodes');
  /// ```
  bool validateReflowKeys(
    Map<String, Offset> reflowOffsets,
    RenderDocument renderDoc,
  ) {
    for (final key in reflowOffsets.keys) {
      if (!renderDoc.nodes.containsKey(key)) {
        return false;
      }
    }
    return true;
  }

  /// Get all ancestors of an expanded ID (from parent to root).
  ///
  /// Returns empty list if the expanded ID is the root or not found.
  List<String> getAncestors(String expandedId) {
    final ancestors = <String>[];
    var current = expandedParent[expandedId];
    while (current != null) {
      ancestors.add(current);
      current = expandedParent[current];
    }
    return ancestors;
  }

  @override
  String toString() => 'FrameLookups('
      'expandedToDoc: ${expandedToDoc.length}, '
      'docToExpanded: ${docToExpanded.length}, '
      'expandedParent: ${expandedParent.length})';
}
