import 'dart:ui';

import 'package:distill_editor/src/free_design/free_design.dart';

/// Test harness for integration tests of the drag/drop system (Layer B).
///
/// This harness uses real builders and compilers:
/// - ExpandedSceneBuilder to build scenes from EditorDocument
/// - RenderCompiler to compile RenderDocument
/// - FrameLookups.build() for ID mappings
///
/// Use this for integration tests that verify the full pipeline.
/// For isolated unit tests, use DragDropUnitHarness instead.
///
/// ## Usage
///
/// ```dart
/// final harness = MiniSceneHarness.verticalStack(childCount: 3);
/// final preview = harness.computePreview(
///   cursorWorld: Offset(50, 100),
///   draggedExpandedIds: ['child_0'],
///   draggedDocIds: ['child_0'],
///   originalParents: {'child_0': 'root'},
/// );
/// expect(preview.insertionIndex, equals(2));
/// ```
class MiniSceneHarness {
  /// Frame ID used in tests.
  final String frameId;

  /// Frame position in world coordinates.
  final Offset framePosition;

  /// The document used to build the scene.
  final EditorDocument document;

  /// The expanded scene (built from document).
  final ExpandedScene scene;

  /// The compiled render document.
  final RenderDocument renderDoc;

  /// Pre-computed ID lookups.
  final FrameLookups lookups;

  /// Bounds by expanded ID (set during layout simulation).
  final Map<String, Rect> _boundsByExpandedId;

  /// Configurable hit result override.
  ContainerHit? hitResultOverride;

  /// The builder instance (stateless, reusable).
  final DropPreviewBuilder _builder = const DropPreviewBuilder();

  MiniSceneHarness._({
    required this.frameId,
    required this.framePosition,
    required this.document,
    required this.scene,
    required this.renderDoc,
    required this.lookups,
    required Map<String, Rect> boundsByExpandedId,
  }) : _boundsByExpandedId = boundsByExpandedId;

  // ===========================================================================
  // Factory Constructors
  // ===========================================================================

  /// Creates a harness from an existing EditorDocument.
  ///
  /// [boundsProvider] is called for each node to get its bounds.
  /// This simulates layout without requiring actual Flutter layout.
  factory MiniSceneHarness.fromDocument({
    required EditorDocument document,
    required String frameId,
    Offset framePosition = Offset.zero,
    required Rect? Function(String expandedId, ExpandedNode node) boundsProvider,
  }) {
    // Build expanded scene
    const sceneBuilder = ExpandedSceneBuilder();
    final scene = sceneBuilder.build(frameId, document);
    if (scene == null) {
      throw ArgumentError('Failed to build scene for frame $frameId');
    }

    // Compile to render document
    final compiler = RenderCompiler(tokens: TokenResolver.empty());
    final renderDoc = compiler.compile(scene);

    // Build lookups
    final lookups = FrameLookups.build(
      scene: scene,
      renderDoc: renderDoc,
    );

    // Compute bounds for all nodes
    final boundsByExpandedId = <String, Rect>{};
    for (final entry in scene.nodes.entries) {
      final bounds = boundsProvider(entry.key, entry.value);
      if (bounds != null) {
        boundsByExpandedId[entry.key] = bounds;
      }
    }

    return MiniSceneHarness._(
      frameId: frameId,
      framePosition: framePosition,
      document: document,
      scene: scene,
      renderDoc: renderDoc,
      lookups: lookups,
      boundsByExpandedId: boundsByExpandedId,
    );
  }

  /// Creates a vertical stack with N children.
  ///
  /// Structure:
  /// ```
  /// root (vertical auto-layout)
  ///   ├── child_0
  ///   ├── child_1
  ///   └── child_2
  /// ```
  factory MiniSceneHarness.verticalStack({
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
    final doc = _buildVerticalDocument(
      childCount: childCount,
      gap: gap,
      paddingTop: paddingTop,
      paddingRight: paddingRight,
      paddingBottom: paddingBottom,
      paddingLeft: paddingLeft,
    );

    // Calculate bounds based on layout
    final parentWidth = paddingLeft + childWidth + paddingRight;
    final parentHeight = paddingTop +
        (childHeight * childCount) +
        (gap * (childCount - 1).clamp(0, childCount)) +
        paddingBottom;

    return MiniSceneHarness.fromDocument(
      document: doc,
      frameId: 'f_test',
      framePosition: framePosition,
      boundsProvider: (expandedId, node) {
        if (expandedId == 'root') {
          return Rect.fromLTWH(0, 0, parentWidth, parentHeight);
        }
        // Child nodes
        final match = RegExp(r'child_(\d+)').firstMatch(expandedId);
        if (match != null) {
          final index = int.parse(match.group(1)!);
          final y = paddingTop + index * (childHeight + gap);
          return Rect.fromLTWH(paddingLeft, y, childWidth, childHeight);
        }
        return null;
      },
    );
  }

  /// Creates a horizontal row with N children.
  factory MiniSceneHarness.horizontalRow({
    int childCount = 3,
    double childWidth = 80,
    double childHeight = 50,
    double gap = 10,
    Offset framePosition = Offset.zero,
  }) {
    final doc = _buildHorizontalDocument(
      childCount: childCount,
      gap: gap,
    );

    final parentWidth =
        (childWidth * childCount) + (gap * (childCount - 1).clamp(0, childCount));

    return MiniSceneHarness.fromDocument(
      document: doc,
      frameId: 'f_test',
      framePosition: framePosition,
      boundsProvider: (expandedId, node) {
        if (expandedId == 'root') {
          return Rect.fromLTWH(0, 0, parentWidth, childHeight);
        }
        final match = RegExp(r'child_(\d+)').firstMatch(expandedId);
        if (match != null) {
          final index = int.parse(match.group(1)!);
          final x = index * (childWidth + gap);
          return Rect.fromLTWH(x, 0, childWidth, childHeight);
        }
        return null;
      },
    );
  }

  /// Creates a structure with component instances.
  ///
  /// Structure:
  /// ```
  /// root (vertical auto-layout)
  ///   ├── inst_a (instance of comp_row)
  ///   │     └── inst_a::row_content
  ///   └── inst_b (instance of comp_row)
  ///         └── inst_b::row_content
  /// ```
  factory MiniSceneHarness.withInstances({
    Offset framePosition = Offset.zero,
  }) {
    final doc = _buildInstanceDocument();

    return MiniSceneHarness.fromDocument(
      document: doc,
      frameId: 'f_test',
      framePosition: framePosition,
      boundsProvider: (expandedId, node) {
        // Root
        if (expandedId == 'root') {
          return const Rect.fromLTWH(0, 0, 300, 200);
        }
        // Instance A and its children
        if (expandedId == 'inst_a' || expandedId == 'inst_a::row_root') {
          return const Rect.fromLTWH(10, 10, 280, 50);
        }
        if (expandedId == 'inst_a::row_content') {
          return const Rect.fromLTWH(20, 20, 100, 30);
        }
        // Instance B and its children
        if (expandedId == 'inst_b' || expandedId == 'inst_b::row_root') {
          return const Rect.fromLTWH(10, 70, 280, 50);
        }
        if (expandedId == 'inst_b::row_content') {
          return const Rect.fromLTWH(20, 80, 100, 30);
        }
        return null;
      },
    );
  }

  /// Creates a deeply nested structure.
  ///
  /// Structure:
  /// ```
  /// root (vertical)
  ///   └── level1 (vertical)
  ///         └── level2 (horizontal)
  ///               ├── leaf_a
  ///               └── leaf_b
  /// ```
  factory MiniSceneHarness.deeplyNested({
    Offset framePosition = Offset.zero,
  }) {
    final doc = _buildNestedDocument();

    return MiniSceneHarness.fromDocument(
      document: doc,
      frameId: 'f_test',
      framePosition: framePosition,
      boundsProvider: (expandedId, node) {
        return switch (expandedId) {
          'root' => const Rect.fromLTWH(0, 0, 400, 300),
          'level1' => const Rect.fromLTWH(10, 10, 380, 280),
          'level2' => const Rect.fromLTWH(20, 20, 360, 100),
          'leaf_a' => const Rect.fromLTWH(30, 30, 80, 60),
          'leaf_b' => const Rect.fromLTWH(120, 30, 80, 60),
          _ => null,
        };
      },
    );
  }

  // ===========================================================================
  // Document Builders (Private)
  // ===========================================================================

  static EditorDocument _buildVerticalDocument({
    required int childCount,
    required double gap,
    required double paddingTop,
    required double paddingRight,
    required double paddingBottom,
    required double paddingLeft,
  }) {
    final childIds = <String>[];
    var doc = EditorDocument.empty(documentId: 'test_doc');

    // Create child nodes
    for (var i = 0; i < childCount; i++) {
      final id = 'child_$i';
      childIds.add(id);
      doc = doc.withNode(Node(
        id: id,
        name: 'Child $i',
        type: NodeType.container,
        props: const ContainerProps(),
      ));
    }

    // Create root with auto-layout
    doc = doc.withNode(Node(
      id: 'root',
      name: 'Root',
      type: NodeType.container,
      props: const ContainerProps(),
      childIds: childIds,
      layout: NodeLayout(
        autoLayout: AutoLayout(
          direction: LayoutDirection.vertical,
          gap: FixedNumeric(gap),
          padding: TokenEdgePadding(
            top: FixedNumeric(paddingTop),
            right: FixedNumeric(paddingRight),
            bottom: FixedNumeric(paddingBottom),
            left: FixedNumeric(paddingLeft),
          ),
        ),
      ),
    ));

    // Create frame
    final now = DateTime.now();
    doc = doc.withFrame(Frame(
      id: 'f_test',
      name: 'Test Frame',
      rootNodeId: 'root',
      canvas: const CanvasPlacement(
        position: Offset.zero,
        size: Size(200, 400),
      ),
      createdAt: now,
      updatedAt: now,
    ));

    return doc;
  }

  static EditorDocument _buildHorizontalDocument({
    required int childCount,
    required double gap,
  }) {
    final childIds = <String>[];
    var doc = EditorDocument.empty(documentId: 'test_doc');

    for (var i = 0; i < childCount; i++) {
      final id = 'child_$i';
      childIds.add(id);
      doc = doc.withNode(Node(
        id: id,
        name: 'Child $i',
        type: NodeType.container,
        props: const ContainerProps(),
      ));
    }

    doc = doc.withNode(Node(
      id: 'root',
      name: 'Root',
      type: NodeType.container,
      props: const ContainerProps(),
      childIds: childIds,
      layout: NodeLayout(
        autoLayout: AutoLayout(
          direction: LayoutDirection.horizontal,
          gap: FixedNumeric(gap),
        ),
      ),
    ));

    final now = DateTime.now();
    doc = doc.withFrame(Frame(
      id: 'f_test',
      name: 'Test Frame',
      rootNodeId: 'root',
      canvas: const CanvasPlacement(
        position: Offset.zero,
        size: Size(400, 100),
      ),
      createdAt: now,
      updatedAt: now,
    ));

    return doc;
  }

  static EditorDocument _buildInstanceDocument() {
    var doc = EditorDocument.empty(documentId: 'test_doc');

    // Component definition: a simple row
    doc = doc.withNode(const Node(
      id: 'row_root',
      name: 'Row Root',
      type: NodeType.container,
      props: ContainerProps(),
      childIds: ['row_content'],
      layout: NodeLayout(
        autoLayout: AutoLayout(direction: LayoutDirection.horizontal),
      ),
    ));

    doc = doc.withNode(const Node(
      id: 'row_content',
      name: 'Row Content',
      type: NodeType.container,
      props: ContainerProps(),
    ));

    final now = DateTime.now();
    doc = doc.withComponent(ComponentDef(
      id: 'comp_row',
      name: 'Row Component',
      rootNodeId: 'row_root',
      createdAt: now,
      updatedAt: now,
    ));

    // Two instances of the component
    doc = doc.withNode(const Node(
      id: 'inst_a',
      name: 'Instance A',
      type: NodeType.instance,
      props: InstanceProps(componentId: 'comp_row'),
    ));

    doc = doc.withNode(const Node(
      id: 'inst_b',
      name: 'Instance B',
      type: NodeType.instance,
      props: InstanceProps(componentId: 'comp_row'),
    ));

    // Root containing both instances
    doc = doc.withNode(const Node(
      id: 'root',
      name: 'Root',
      type: NodeType.container,
      props: ContainerProps(),
      childIds: ['inst_a', 'inst_b'],
      layout: NodeLayout(
        autoLayout: AutoLayout(
          direction: LayoutDirection.vertical,
          gap: FixedNumeric(10),
        ),
      ),
    ));

    doc = doc.withFrame(Frame(
      id: 'f_test',
      name: 'Test Frame',
      rootNodeId: 'root',
      canvas: const CanvasPlacement(
        position: Offset.zero,
        size: Size(300, 200),
      ),
      createdAt: now,
      updatedAt: now,
    ));

    return doc;
  }

  static EditorDocument _buildNestedDocument() {
    var doc = EditorDocument.empty(documentId: 'test_doc');

    // Leaf nodes
    doc = doc.withNode(const Node(
      id: 'leaf_a',
      name: 'Leaf A',
      type: NodeType.container,
      props: ContainerProps(),
    ));

    doc = doc.withNode(const Node(
      id: 'leaf_b',
      name: 'Leaf B',
      type: NodeType.container,
      props: ContainerProps(),
    ));

    // Level 2 (horizontal)
    doc = doc.withNode(const Node(
      id: 'level2',
      name: 'Level 2',
      type: NodeType.container,
      props: ContainerProps(),
      childIds: ['leaf_a', 'leaf_b'],
      layout: NodeLayout(
        autoLayout: AutoLayout(
          direction: LayoutDirection.horizontal,
          gap: FixedNumeric(10),
        ),
      ),
    ));

    // Level 1 (vertical)
    doc = doc.withNode(const Node(
      id: 'level1',
      name: 'Level 1',
      type: NodeType.container,
      props: ContainerProps(),
      childIds: ['level2'],
      layout: NodeLayout(
        autoLayout: AutoLayout(direction: LayoutDirection.vertical),
      ),
    ));

    // Root (vertical)
    doc = doc.withNode(const Node(
      id: 'root',
      name: 'Root',
      type: NodeType.container,
      props: ContainerProps(),
      childIds: ['level1'],
      layout: NodeLayout(
        autoLayout: AutoLayout(direction: LayoutDirection.vertical),
      ),
    ));

    final now = DateTime.now();
    doc = doc.withFrame(Frame(
      id: 'f_test',
      name: 'Test Frame',
      rootNodeId: 'root',
      canvas: const CanvasPlacement(
        position: Offset.zero,
        size: Size(400, 300),
      ),
      createdAt: now,
      updatedAt: now,
    ));

    return doc;
  }

  // ===========================================================================
  // Callback Implementations
  // ===========================================================================

  /// Get bounds for an expanded ID (frame-local coordinates).
  Rect? getBounds(String frameId, String expandedId) {
    if (frameId != this.frameId) return null;
    return _boundsByExpandedId[expandedId];
  }

  /// Get frame position in world coordinates.
  Offset getFramePos(String frameId) {
    if (frameId != this.frameId) return Offset.zero;
    return framePosition;
  }

  /// Hit test for a container at world position.
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

    // Get paint order from render doc (we traverse in reverse)
    final paintOrder = _computePaintOrder();

    // Hit test back to front
    for (var i = paintOrder.length - 1; i >= 0; i--) {
      final expandedId = paintOrder[i];
      if (excludeExpandedIds.contains(expandedId)) continue;

      final bounds = _boundsByExpandedId[expandedId];
      if (bounds != null && bounds.contains(frameLocal)) {
        return ContainerHit(
          expandedId: expandedId,
          docId: scene.patchTarget[expandedId],
        );
      }
    }

    return null;
  }

  /// Compute paint order by traversing the scene tree (pre-order).
  List<String> _computePaintOrder() {
    final order = <String>[];
    void traverse(String nodeId) {
      order.add(nodeId);
      final node = renderDoc.nodes[nodeId];
      if (node != null) {
        for (final childId in node.childIds) {
          traverse(childId);
        }
      }
    }
    traverse(renderDoc.rootId);
    return order;
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Get cursor position at a slot boundary.
  Offset cursorAtSlot(String parentExpandedId, int slotIndex) {
    final children = renderDoc.nodes[parentExpandedId]?.childIds ?? [];
    final docId = lookups.getDocId(parentExpandedId);
    final autoLayout = docId != null
        ? document.nodes[docId]?.layout.autoLayout
        : null;
    final direction = autoLayout?.direction ?? LayoutDirection.vertical;
    final parentBounds = _boundsByExpandedId[parentExpandedId];

    if (parentBounds == null) return framePosition;

    double mainAxisPos;

    if (children.isEmpty || slotIndex == 0) {
      mainAxisPos = direction == LayoutDirection.horizontal
          ? parentBounds.left + 5
          : parentBounds.top + 5;
    } else if (slotIndex >= children.length) {
      final lastChild = children.last;
      final lastBounds = _boundsByExpandedId[lastChild];
      mainAxisPos = direction == LayoutDirection.horizontal
          ? (lastBounds?.right ?? parentBounds.right) + 5
          : (lastBounds?.bottom ?? parentBounds.bottom) + 5;
    } else {
      final prevChild = children[slotIndex - 1];
      final currChild = children[slotIndex];
      final prevBounds = _boundsByExpandedId[prevChild];
      final currBounds = _boundsByExpandedId[currChild];

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

    return direction == LayoutDirection.horizontal
        ? Offset(mainAxisPos + framePosition.dx, parentBounds.center.dy + framePosition.dy)
        : Offset(parentBounds.center.dx + framePosition.dx, mainAxisPos + framePosition.dy);
  }

  /// Get all expanded IDs for a given doc ID.
  List<String> expandedIdsFor(String docId) {
    return lookups.getExpandedIds(docId);
  }

  /// Check if an expanded ID is inside an instance.
  bool isInsideInstance(String expandedId) {
    return scene.isInsideInstance(expandedId);
  }

  /// Get the owning instance ID for an expanded ID.
  String? getOwningInstance(String expandedId) {
    return scene.getOwningInstance(expandedId);
  }

  // ===========================================================================
  // Main API: Compute Drop Preview
  // ===========================================================================

  /// Compute a drop preview with the given parameters.
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
