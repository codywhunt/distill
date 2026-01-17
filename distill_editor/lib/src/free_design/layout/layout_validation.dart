import 'package:flutter/rendering.dart' hide CrossAxisAlignment;

import '../models/models.dart';
import '../store/editor_document_store.dart';

/// Shared validation utilities for layout sizing modes.
///
/// Used by property panel to determine when Fill mode is valid.
/// The render compiler has its own internal `_isParentBounded` for runtime
/// validation, but this class is the single source of truth for UI validation.
class LayoutValidation {
  /// Check if a node can use Fill sizing on the given axis.
  ///
  /// Fill is allowed when:
  /// 1. Node is root (frame provides bounds)
  /// 2. Parent has Fixed size on that axis
  /// 3. Parent has Fill and grandparent is bounded (recursive)
  /// 4. Cross-axis Fill when parent has crossAlign: stretch (recursive)
  ///
  /// Returns true if Fill is valid, false otherwise.
  static bool canUseFill({
    required String nodeId,
    required Axis axis,
    required EditorDocumentStore store,
  }) {
    return _isParentBounded(
      nodeId: nodeId,
      axis: axis,
      store: store,
    );
  }

  /// Returns human-readable reason why Fill is disabled, or null if allowed.
  ///
  /// Use this to provide helpful tooltips in the UI when Fill is unavailable.
  static String? getFillDisabledReason({
    required String nodeId,
    required Axis axis,
    required EditorDocumentStore store,
  }) {
    if (canUseFill(nodeId: nodeId, axis: axis, store: store)) {
      return null;
    }

    final parentId = store.parentIndex[nodeId];
    if (parentId == null) return 'No parent container';

    final parent = store.document.nodes[parentId];
    if (parent == null) return 'Parent not found';

    final parentSize = parent.layout.size;
    final parentAxisSize =
        axis == Axis.horizontal ? parentSize.width : parentSize.height;
    final axisName = axis == Axis.horizontal ? 'width' : 'height';

    if (parentAxisSize is AxisSizeHug) {
      final autoLayout = parent.layout.autoLayout;
      if (autoLayout != null) {
        final isCrossAxis = (autoLayout.direction == LayoutDirection.vertical &&
                axis == Axis.horizontal) ||
            (autoLayout.direction == LayoutDirection.horizontal &&
                axis == Axis.vertical);
        if (isCrossAxis) {
          return 'Set parent alignment to "Stretch"';
        }
      }
      return 'Parent $axisName is "Hug" (unbounded)';
    }

    return 'Parent is unbounded on this axis';
  }

  /// Recursive check if the parent chain provides bounded constraints.
  static bool _isParentBounded({
    required String nodeId,
    required Axis axis,
    required EditorDocumentStore store,
  }) {
    final doc = store.document;
    final parentId = store.parentIndex[nodeId];

    // Root node - frame always provides bounds
    if (parentId == null) {
      final frameId = store.getFrameForNode(nodeId);
      return frameId != null && doc.frames[frameId] != null;
    }

    final parent = doc.nodes[parentId];
    if (parent == null) return false;

    final parentSize = parent.layout.size;
    final parentAxisSize =
        axis == Axis.horizontal ? parentSize.width : parentSize.height;

    // Case 1: Parent has Fixed size - definitely bounded
    if (parentAxisSize is AxisSizeFixed) {
      return true;
    }

    // Case 2: Cross-axis Fill with crossAlign: stretch
    final autoLayout = parent.layout.autoLayout;
    if (autoLayout != null) {
      final isCrossAxis = (autoLayout.direction == LayoutDirection.vertical &&
              axis == Axis.horizontal) ||
          (autoLayout.direction == LayoutDirection.horizontal &&
              axis == Axis.vertical);

      if (isCrossAxis && autoLayout.crossAlign == CrossAxisAlignment.stretch) {
        // Cross-axis stretch: the child will be stretched to match siblings
        // So we need to check if the PARENT is bounded on this axis (recursively)
        return _isParentBounded(nodeId: parentId, axis: axis, store: store);
      }
    }

    // Case 3: Parent has Fill - check grandparent
    if (parentAxisSize is AxisSizeFill) {
      return _isParentBounded(nodeId: parentId, axis: axis, store: store);
    }

    // Case 4: Parent has Hug - not bounded
    return false;
  }
}
