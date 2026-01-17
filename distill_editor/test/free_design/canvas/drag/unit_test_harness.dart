import 'dart:ui';

import 'package:distill_editor/src/free_design/free_design.dart';

/// Test harness for pure unit tests of the drag/drop system (Layer A).
///
/// This harness provides all data directly - no compilers or builders.
/// Tests are fast, stable, and targeted at specific logic.
///
/// ## Usage
///
/// ```dart
/// final harness = DragDropUnitHarness.verticalColumn(childCount: 3);
/// final preview = harness.computePreview(
///   cursorWorld: Offset(50, 100),
///   draggedExpandedIds: ['child_0'],
///   draggedDocIds: ['child_0'],
///   originalParents: {'child_0': 'parent'},
/// );
/// expect(preview.insertionIndex, equals(2));
/// ```
class DragDropUnitHarness {
  /// Frame ID used in tests.
  final String frameId;

  /// Frame position in world coordinates.
  final Offset framePosition;

  /// Bounds by expanded ID (frame-local coordinates).
  final Map<String, Rect> boundsByExpandedId;

  /// Children by expanded ID (from renderDoc.nodes[id].childIds).
  final Map<String, List<String>> renderChildrenByExpandedId;

  /// Expanded ID → Doc ID mapping.
  final Map<String, String?> expandedToDoc;

  /// Doc ID to List of Expanded IDs mapping.
  final Map<String, List<String>> docToExpanded;

  /// Expanded ID → Parent Expanded ID mapping.
  final Map<String, String?> expandedParent;

  /// Paint order (back to front) for hit testing.
  final List<String> paintOrder;

  /// Which doc nodes have auto-layout.
  final Map<String, AutoLayout?> autoLayoutByDocId;

  /// Configurable hit result (overrides automatic hit testing).
  ContainerHit? hitResultOverride;

  /// The builder instance (stateless, reusable).
  final DropPreviewBuilder _builder = const DropPreviewBuilder();

  DragDropUnitHarness({
    this.frameId = 'frame_1',
    this.framePosition = Offset.zero,
    required this.boundsByExpandedId,
    required this.renderChildrenByExpandedId,
    required this.expandedToDoc,
    required this.expandedParent,
    required this.paintOrder,
    required this.autoLayoutByDocId,
    Map<String, List<String>>? docToExpanded,
  }) : docToExpanded = docToExpanded ?? _buildDocToExpanded(expandedToDoc);

  /// Build the reverse map from expandedToDoc.
  static Map<String, List<String>> _buildDocToExpanded(
    Map<String, String?> expandedToDoc,
  ) {
    final result = <String, List<String>>{};
    for (final entry in expandedToDoc.entries) {
      final docId = entry.value;
      if (docId != null) {
        result.putIfAbsent(docId, () => []).add(entry.key);
      }
    }
    return result;
  }

  // ===========================================================================
  // Factory Constructors for Common Scenarios
  // ===========================================================================

  /// Creates a vertical column with N children.
  ///
  /// Structure:
  /// ```
  /// parent (vertical auto-layout)
  ///   ├── child_0
  ///   ├── child_1
  ///   └── child_2
  /// ```
  factory DragDropUnitHarness.verticalColumn({
    int childCount = 3,
    double childWidth = 100,
    double childHeight = 50,
    double gap = 10,
    double paddingTop = 0,
    double paddingRight = 0,
    double paddingBottom = 0,
    double paddingLeft = 0,
    Offset framePosition = Offset.zero,
  }) {
    final bounds = <String, Rect>{};
    final children = <String>[];
    final expandedToDoc = <String, String?>{};
    final expandedParent = <String, String?>{};
    final paintOrder = <String>[];

    // Parent bounds (accommodate all children)
    final parentWidth = paddingLeft + childWidth + paddingRight;
    final parentHeight =
        paddingTop + (childHeight * childCount) + (gap * (childCount - 1).clamp(0, childCount)) + paddingBottom;
    bounds['parent'] = Rect.fromLTWH(0, 0, parentWidth, parentHeight);
    expandedToDoc['parent'] = 'parent';
    expandedParent['parent'] = null;
    paintOrder.add('parent');

    // Children
    var y = paddingTop;
    for (var i = 0; i < childCount; i++) {
      final id = 'child_$i';
      bounds[id] = Rect.fromLTWH(paddingLeft, y, childWidth, childHeight);
      children.add(id);
      expandedToDoc[id] = id;
      expandedParent[id] = 'parent';
      paintOrder.add(id);
      y += childHeight + gap;
    }

    return DragDropUnitHarness(
      framePosition: framePosition,
      boundsByExpandedId: bounds,
      renderChildrenByExpandedId: {'parent': children},
      expandedToDoc: expandedToDoc,
      expandedParent: expandedParent,
      paintOrder: paintOrder,
      autoLayoutByDocId: {
        'parent': AutoLayout(
          direction: LayoutDirection.vertical,
          gap: FixedNumeric(gap),
          padding: TokenEdgePadding(
            top: FixedNumeric(paddingTop),
            right: FixedNumeric(paddingRight),
            bottom: FixedNumeric(paddingBottom),
            left: FixedNumeric(paddingLeft),
          ),
        ),
      },
    );
  }

  /// Creates a horizontal row with N children.
  factory DragDropUnitHarness.horizontalRow({
    int childCount = 3,
    double childWidth = 80,
    double childHeight = 50,
    double gap = 10,
    Offset framePosition = Offset.zero,
  }) {
    final bounds = <String, Rect>{};
    final children = <String>[];
    final expandedToDoc = <String, String?>{};
    final expandedParent = <String, String?>{};
    final paintOrder = <String>[];

    // Parent bounds
    final parentWidth =
        (childWidth * childCount) + (gap * (childCount - 1).clamp(0, childCount));
    bounds['parent'] = Rect.fromLTWH(0, 0, parentWidth, childHeight);
    expandedToDoc['parent'] = 'parent';
    expandedParent['parent'] = null;
    paintOrder.add('parent');

    // Children
    var x = 0.0;
    for (var i = 0; i < childCount; i++) {
      final id = 'child_$i';
      bounds[id] = Rect.fromLTWH(x, 0, childWidth, childHeight);
      children.add(id);
      expandedToDoc[id] = id;
      expandedParent[id] = 'parent';
      paintOrder.add(id);
      x += childWidth + gap;
    }

    return DragDropUnitHarness(
      framePosition: framePosition,
      boundsByExpandedId: bounds,
      renderChildrenByExpandedId: {'parent': children},
      expandedToDoc: expandedToDoc,
      expandedParent: expandedParent,
      paintOrder: paintOrder,
      autoLayoutByDocId: {
        'parent': AutoLayout(
          direction: LayoutDirection.horizontal,
          gap: FixedNumeric(gap),
        ),
      },
    );
  }

  /// Creates a nested structure with absolute child inside auto-layout.
  ///
  /// Structure:
  /// ```
  /// grandparent (vertical auto-layout)
  ///   └── parent (absolute position, no auto-layout)
  ///         └── child (absolute position)
  /// ```
  factory DragDropUnitHarness.nestedAbsolute({
    Offset framePosition = Offset.zero,
  }) {
    return DragDropUnitHarness(
      framePosition: framePosition,
      boundsByExpandedId: {
        'grandparent': const Rect.fromLTWH(0, 0, 400, 300),
        'parent': const Rect.fromLTWH(20, 20, 200, 150),
        'child': const Rect.fromLTWH(40, 40, 100, 80),
      },
      renderChildrenByExpandedId: {
        'grandparent': ['parent'],
        'parent': ['child'],
        'child': [],
      },
      expandedToDoc: {
        'grandparent': 'grandparent',
        'parent': 'parent',
        'child': 'child',
      },
      expandedParent: {
        'grandparent': null,
        'parent': 'grandparent',
        'child': 'parent',
      },
      paintOrder: ['grandparent', 'parent', 'child'],
      autoLayoutByDocId: {
        'grandparent': const AutoLayout(direction: LayoutDirection.vertical),
        'parent': null, // Absolute container, no auto-layout
        'child': null,
      },
    );
  }

  /// Creates a multi-instance scenario where one doc node appears multiple times.
  ///
  /// Structure:
  /// ```
  /// root (vertical auto-layout)
  ///   ├── inst_a::row  → row (docId)
  ///   └── inst_b::row  → row (docId)
  /// ```
  factory DragDropUnitHarness.multiInstance({
    Offset framePosition = Offset.zero,
  }) {
    return DragDropUnitHarness(
      framePosition: framePosition,
      boundsByExpandedId: {
        'root': const Rect.fromLTWH(0, 0, 300, 200),
        'inst_a::row': const Rect.fromLTWH(10, 10, 280, 50),
        'inst_b::row': const Rect.fromLTWH(10, 70, 280, 50),
      },
      renderChildrenByExpandedId: {
        'root': ['inst_a::row', 'inst_b::row'],
        'inst_a::row': [],
        'inst_b::row': [],
      },
      expandedToDoc: {
        'root': 'root',
        'inst_a::row': 'row', // Both map to same docId
        'inst_b::row': 'row',
      },
      docToExpanded: {
        'root': ['root'],
        'row': ['inst_a::row', 'inst_b::row'], // One docId → multiple expandedIds
      },
      expandedParent: {
        'root': null,
        'inst_a::row': 'root',
        'inst_b::row': 'root',
      },
      paintOrder: ['root', 'inst_a::row', 'inst_b::row'],
      autoLayoutByDocId: {
        'root': const AutoLayout(direction: LayoutDirection.vertical, gap: FixedNumeric(10)),
        'row': const AutoLayout(direction: LayoutDirection.horizontal),
      },
    );
  }

  // ===========================================================================
  // Callback Implementations
  // ===========================================================================

  /// Get bounds for an expanded ID (frame-local coordinates).
  Rect? getBounds(String frameId, String expandedId) {
    if (frameId != this.frameId) return null;
    return boundsByExpandedId[expandedId];
  }

  /// Get frame position in world coordinates.
  Offset getFramePos(String frameId) {
    if (frameId != this.frameId) return Offset.zero;
    return framePosition;
  }

  /// Hit test for a container at world position.
  ///
  /// If [hitResultOverride] is set, returns that.
  /// Otherwise, performs hit testing using bounds and paint order.
  ContainerHit? hitTestContainer(
    String frameId,
    Offset worldPos,
    Set<String> excludeExpandedIds,
  ) {
    if (hitResultOverride != null) {
      return hitResultOverride;
    }

    if (frameId != this.frameId) return null;

    // Convert to frame-local
    final frameLocal = worldPos - framePosition;

    // Hit test back to front (last in paint order = topmost)
    for (var i = paintOrder.length - 1; i >= 0; i--) {
      final expandedId = paintOrder[i];
      if (excludeExpandedIds.contains(expandedId)) continue;

      final bounds = boundsByExpandedId[expandedId];
      if (bounds != null && bounds.contains(frameLocal)) {
        return ContainerHit(
          expandedId: expandedId,
          docId: expandedToDoc[expandedId],
        );
      }
    }

    return null;
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Get cursor position at a slot boundary.
  ///
  /// [slotIndex] 0 = before first child, 1 = after first child, etc.
  Offset cursorAtSlot(String parentExpandedId, int slotIndex) {
    final children = renderChildrenByExpandedId[parentExpandedId] ?? [];
    final autoLayout = autoLayoutByDocId[expandedToDoc[parentExpandedId]];
    final direction = autoLayout?.direction ?? LayoutDirection.vertical;
    final parentBounds = boundsByExpandedId[parentExpandedId];

    if (parentBounds == null) return framePosition;

    double mainAxisPos;

    if (children.isEmpty || slotIndex == 0) {
      // Before first child
      mainAxisPos = direction == LayoutDirection.horizontal
          ? parentBounds.left + 5
          : parentBounds.top + 5;
    } else if (slotIndex >= children.length) {
      // After last child
      final lastChild = children.last;
      final lastBounds = boundsByExpandedId[lastChild];
      mainAxisPos = direction == LayoutDirection.horizontal
          ? (lastBounds?.right ?? parentBounds.right) + 5
          : (lastBounds?.bottom ?? parentBounds.bottom) + 5;
    } else {
      // Between children: midpoint between prev and current
      final prevChild = children[slotIndex - 1];
      final currChild = children[slotIndex];
      final prevBounds = boundsByExpandedId[prevChild];
      final currBounds = boundsByExpandedId[currChild];

      if (prevBounds != null && currBounds != null) {
        mainAxisPos = direction == LayoutDirection.horizontal
            ? (prevBounds.right + currBounds.left) / 2
            : (prevBounds.bottom + currBounds.top) / 2;
      } else {
        mainAxisPos = direction == LayoutDirection.horizontal
            ? parentBounds.left + 5
            : parentBounds.top + 5;
      }
    }

    // Return world position
    return direction == LayoutDirection.horizontal
        ? Offset(mainAxisPos + framePosition.dx, parentBounds.center.dy + framePosition.dy)
        : Offset(parentBounds.center.dx + framePosition.dx, mainAxisPos + framePosition.dy);
  }

  /// Build a minimal EditorDocument for the harness.
  ///
  /// This creates nodes based on the harness configuration.
  EditorDocument buildDocument() {
    var doc = EditorDocument.empty(documentId: 'test_doc');

    for (final entry in expandedToDoc.entries) {
      final expandedId = entry.key;
      final docId = entry.value;
      if (docId == null) continue;

      // Skip if we already added this docId
      if (doc.nodes.containsKey(docId)) continue;

      final childIds = renderChildrenByExpandedId[expandedId] ?? [];
      final childDocIds = childIds
          .map((c) => expandedToDoc[c])
          .whereType<String>()
          .toList();

      doc = doc.withNode(Node(
        id: docId,
        name: docId,
        type: NodeType.container,
        props: const ContainerProps(),
        childIds: childDocIds,
        layout: NodeLayout(
          autoLayout: autoLayoutByDocId[docId],
        ),
      ));
    }

    return doc;
  }

  /// Build FrameLookups from harness data.
  FrameLookups buildLookups() {
    return FrameLookups(
      expandedToDoc: Map.from(expandedToDoc),
      docToExpanded: Map.from(docToExpanded),
      expandedParent: Map.from(expandedParent),
    );
  }

  /// Build a minimal RenderDocument from harness data.
  RenderDocument buildRenderDocument() {
    final nodes = <String, RenderNode>{};

    for (final expandedId in boundsByExpandedId.keys) {
      final childIds = renderChildrenByExpandedId[expandedId] ?? [];
      final docId = expandedToDoc[expandedId];
      final autoLayout = docId != null ? autoLayoutByDocId[docId] : null;

      RenderNodeType type;
      if (autoLayout != null) {
        type = autoLayout.direction == LayoutDirection.horizontal
            ? RenderNodeType.row
            : RenderNodeType.column;
      } else {
        type = RenderNodeType.box;
      }

      nodes[expandedId] = RenderNode(
        id: expandedId,
        type: type,
        props: const {},
        childIds: childIds,
        compiledBounds: boundsByExpandedId[expandedId],
      );
    }

    // Find root (node with no parent)
    final rootId = expandedParent.entries
        .firstWhere((e) => e.value == null, orElse: () => const MapEntry('', null))
        .key;

    return RenderDocument(rootId: rootId, nodes: nodes);
  }

  // ===========================================================================
  // Main API: Compute Drop Preview
  // ===========================================================================

  /// Compute a drop preview with the given parameters.
  ///
  /// This is the main entry point for testing DropPreviewBuilder logic.
  DropPreview computePreview({
    required Offset cursorWorld,
    required List<String> draggedExpandedIds,
    required List<String> draggedDocIds,
    required Map<String, String> originalParents,
    int? lastInsertionIndex,
    Offset? lastInsertionCursor,
    double zoom = 1.0,
    String? originParentExpandedId,
    Rect? originParentContentWorldRect,
  }) {
    final document = buildDocument();
    final lookups = buildLookups();
    final renderDoc = buildRenderDocument();

    // Create a minimal expanded scene (we only use patchTarget from it)
    final scene = ExpandedScene(
      frameId: frameId,
      rootId: renderDoc.rootId,
      nodes: const {},
      patchTarget: Map.from(expandedToDoc),
    );

    return _builder.compute(
      lockedFrameId: frameId,
      cursorWorld: cursorWorld,
      draggedDocIdsOrdered: draggedDocIds,
      draggedExpandedIdsOrdered: draggedExpandedIds,
      originalParents: originalParents,
      lastInsertionIndex: lastInsertionIndex,
      lastInsertionCursor: lastInsertionCursor,
      zoom: zoom,
      document: document,
      scene: scene,
      renderDoc: renderDoc,
      lookups: lookups,
      getBounds: getBounds,
      getFramePos: getFramePos,
      hitTestContainer: hitTestContainer,
      originParentExpandedId: originParentExpandedId,
      originParentContentWorldRect: originParentContentWorldRect,
    );
  }
}

/// Helper to apply patches to a simple tree for testing patch outcomes.
///
/// Takes an initial tree (parentId → childIds) and applies DetachChild/AttachChild
/// patches, returning the resulting child list for a given parent.
class PatchTreeTester {
  final Map<String, List<String>> _tree;

  PatchTreeTester(Map<String, List<String>> initialTree)
      : _tree = {
          for (final entry in initialTree.entries)
            entry.key: List.from(entry.value),
        };

  /// Apply patches and return the resulting tree.
  void applyPatches(List<PatchOp> patches) {
    for (final patch in patches) {
      if (patch is DetachChild) {
        final children = _tree[patch.parentId];
        if (children != null) {
          children.remove(patch.childId);
        }
      } else if (patch is AttachChild) {
        final children = _tree.putIfAbsent(patch.parentId, () => []);
        final index = patch.index.clamp(0, children.length);
        children.insert(index, patch.childId);
      }
    }
  }

  /// Get the children of a parent after patches are applied.
  List<String> childrenOf(String parentId) {
    return List.unmodifiable(_tree[parentId] ?? []);
  }
}
