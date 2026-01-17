import 'package:flutter/foundation.dart';

/// Result of hitting a container during drag operations.
///
/// This represents a container that the cursor is hovering over during a drag.
///
/// ## ID Domain Rules (INV-1: Expanded-First Hit Testing)
///
/// CRITICAL: [expandedId] is the PRIMARY result from hit testing.
/// [docId] is DERIVED via `scene.patchTarget[expandedId]`.
///
/// This ordering matters because:
/// - One docId can map to multiple expandedIds (e.g., same component in multiple instances)
/// - We need the specific expandedId under the cursor for correct bounds lookup
/// - Indicator positioning and reflow calculations use expanded bounds
///
/// Example: If component "row_1" appears in two instances:
/// - `inst_a::row_1` (expandedId) → `row_1` (docId)
/// - `inst_b::row_1` (expandedId) → `row_1` (docId)
///
/// When hovering over instance A, we need `inst_a::row_1` as the target,
/// not a random choice between the two expanded IDs.
@immutable
class ContainerHit {
  /// The specific expanded instance under cursor (PRIMARY).
  ///
  /// This is the authoritative result from hit testing.
  /// Use this for bounds lookup and indicator positioning.
  final String expandedId;

  /// The document node ID for patching (DERIVED).
  ///
  /// May be null if the container is unpatchable (e.g., inside a component instance).
  /// When non-null, use this for generating patches (MoveNode, etc.).
  final String? docId;

  const ContainerHit({
    required this.expandedId,
    required this.docId,
  });

  /// Whether this container can be patched directly.
  ///
  /// Returns false for containers inside component instances,
  /// which require override handling instead of direct patches.
  bool get canPatch => docId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContainerHit &&
          runtimeType == other.runtimeType &&
          expandedId == other.expandedId &&
          docId == other.docId;

  @override
  int get hashCode => Object.hash(expandedId, docId);

  @override
  String toString() => 'ContainerHit(expanded: $expandedId, doc: $docId)';
}
