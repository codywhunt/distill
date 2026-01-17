import 'dart:math';
import 'dart:ui';

import '../canvas/drag_target.dart';
import '../models/frame.dart';
import '../models/node.dart';

/// Extract copyable node IDs from selection, filtering to top-level roots only.
///
/// A "root" is a node whose parent is NOT also selected. This prevents
/// duplicating descendants when both parent and child are selected.
///
/// Returns roots sorted deterministically by position (minY, then minX, then id).
List<String> getTopLevelRoots({
  required Set<DragTarget> selection,
  required Map<String, String> parentIndex,
  required Map<String, Frame> frames,
  required Map<String, Node> nodes,
}) {
  // Step 1: Collect all selected node IDs (ignore null patchTargets)
  final selectedNodeIds = <String>{};

  for (final target in selection) {
    switch (target) {
      case NodeTarget(:final patchTarget):
        if (patchTarget != null) {
          selectedNodeIds.add(patchTarget);
        }
      case FrameTarget(:final frameId):
        final frame = frames[frameId];
        if (frame != null) {
          selectedNodeIds.add(frame.rootNodeId);
        }
    }
  }

  // Step 2: Filter to roots (parent not in selection)
  final roots = <String>[];
  for (final nodeId in selectedNodeIds) {
    final parentId = parentIndex[nodeId];
    if (parentId == null || !selectedNodeIds.contains(parentId)) {
      roots.add(nodeId);
    }
  }

  // Step 3: Sort deterministically by position (minY, minX), then id
  roots.sort((a, b) {
    final nodeA = nodes[a];
    final nodeB = nodes[b];
    if (nodeA == null || nodeB == null) return a.compareTo(b);

    final yA = nodeA.layout.y ?? 0;
    final yB = nodeB.layout.y ?? 0;
    if (yA != yB) return yA.compareTo(yB);

    final xA = nodeA.layout.x ?? 0;
    final xB = nodeB.layout.x ?? 0;
    if (xA != xB) return xA.compareTo(xB);

    return a.compareTo(b); // Fallback to id
  });

  return roots;
}

/// Compute anchor as bounding box top-left of selected roots.
///
/// The anchor is the minimum x and y coordinates among all root nodes.
/// Used for positioning pasted nodes relative to cursor.
Offset computeAnchor(List<String> rootIds, Map<String, Node> nodes) {
  double minX = double.infinity;
  double minY = double.infinity;

  for (final rootId in rootIds) {
    final node = nodes[rootId];
    if (node != null) {
      final x = node.layout.x ?? 0;
      final y = node.layout.y ?? 0;
      minX = min(minX, x);
      minY = min(minY, y);
    }
  }

  return Offset(
    minX == double.infinity ? 0 : minX,
    minY == double.infinity ? 0 : minY,
  );
}

/// Collect all nodes in subtrees rooted at the given IDs.
///
/// Returns nodes in parent-first order (roots first, then their descendants).
/// This is the order needed for InsertNode patches.
List<Node> collectSubtree(List<String> rootIds, Map<String, Node> nodes) {
  final result = <Node>[];
  final visited = <String>{};

  void visit(String nodeId) {
    if (visited.contains(nodeId)) return;
    visited.add(nodeId);

    final node = nodes[nodeId];
    if (node == null) return;

    result.add(node);
    for (final childId in node.childIds) {
      visit(childId);
    }
  }

  for (final rootId in rootIds) {
    visit(rootId);
  }

  return result;
}

/// Check if selection contains any copyable nodes.
///
/// A node is copyable if it has a valid patchTarget (not inside an instance).
/// Frames are always copyable (their root node is copied).
bool canCopy(Set<DragTarget> selection) {
  return selection.any((target) => switch (target) {
        NodeTarget(:final patchTarget) => patchTarget != null,
        FrameTarget() => true,
      });
}

/// Determine the target frame for paste operations.
///
/// Priority:
/// 1. If exactly one node selected → that node's frame
/// 2. If exactly one frame selected → that frame
/// 3. Otherwise → focusedFrameId
String? determineTargetFrame({
  required Set<DragTarget> selection,
  required String? focusedFrameId,
}) {
  // Priority 1: If exactly one node selected, use its frame
  final nodeTargets = selection.whereType<NodeTarget>().toList();
  if (nodeTargets.length == 1) {
    return nodeTargets.first.frameId;
  }

  // Priority 2: If exactly one frame selected, use it
  final frameTargets = selection.whereType<FrameTarget>().toList();
  if (frameTargets.length == 1) {
    return frameTargets.first.frameId;
  }

  // Priority 3: Use focused/current frame
  return focusedFrameId;
}

/// Determine the target parent node for paste operations.
///
/// Priority:
/// 1. If exactly one node with valid patchTarget selected → paste INTO that node
/// 2. Otherwise → paste into frame's root node
String? determineTargetParent({
  required Set<DragTarget> selection,
  required String? targetFrameId,
  required Map<String, Frame> frames,
}) {
  if (targetFrameId == null) return null;

  // If exactly one node with valid patchTarget → paste INTO that node
  final nodeTargets = selection
      .whereType<NodeTarget>()
      .where((t) => t.patchTarget != null && t.frameId == targetFrameId)
      .toList();

  if (nodeTargets.length == 1) {
    return nodeTargets.first.patchTarget;
  }

  // Otherwise → paste into frame's root node
  return frames[targetFrameId]?.rootNodeId;
}
