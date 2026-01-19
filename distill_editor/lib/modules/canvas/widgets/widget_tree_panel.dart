import 'package:flutter/material.dart' hide DragTarget;
import 'dart:ui' as ui show TextAlign;
import 'package:provider/provider.dart';

import '../../../src/free_design/canvas/drag_target.dart';
import '../../../src/free_design/models/editor_document.dart';
import '../../../src/free_design/models/node_props.dart';
import '../../../src/free_design/scene/expanded_scene.dart';
import '../../../src/free_design/store/editor_document_store.dart';
import '../canvas_state.dart';
import 'node_tree_item.dart';
import 'widget_tree_state.dart';

/// Main widget tree panel that displays the layers of the in-focus frame.
///
/// Shows a hierarchical tree of nodes with:
/// - Expand/collapse functionality
/// - Selection sync with canvas
/// - Hover sync with canvas
/// - Auto-scroll to selected nodes
/// - Instance handling (shown as collapsed, non-editable nodes)
class WidgetTreePanel extends StatefulWidget {
  const WidgetTreePanel({
    required this.treeState,
    super.key,
  });

  final WidgetTreeState treeState;

  @override
  State<WidgetTreePanel> createState() => _WidgetTreePanelState();
}

class _WidgetTreePanelState extends State<WidgetTreePanel> {
  String? _lastFocusFrameId;

  @override
  Widget build(BuildContext context) {
    final canvasState = context.watch<CanvasState>();
    final store = canvasState.store;

    // Determine focus frame
    final focusFrameId = _getFocusFrameId(canvasState, store.document);

    // Clear keys if focus frame changed
    if (focusFrameId != _lastFocusFrameId) {
      widget.treeState.clearKeys();
      _lastFocusFrameId = focusFrameId;
    }

    // No focus frame - show empty state
    if (focusFrameId == null) {
      return _buildEmptyState('Select a frame to view layers');
    }

    // Get expanded scene for the focus frame
    final scene = canvasState.getExpandedScene(focusFrameId);
    if (scene == null) {
      return _buildEmptyState('Frame not found');
    }

    // Expand root node by default on first load
    if (!widget.treeState.isExpanded(scene.rootId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.treeState.expandPath([scene.rootId]);
        }
      });
    }

    // Auto-expand and scroll to selection
    _handleSelectionChange(canvasState, scene);

    return ListenableBuilder(
      listenable: widget.treeState,
      builder: (context, _) {
        return SingleChildScrollView(
          controller: widget.treeState.scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              // Build tree starting from root
              _buildNodeTree(
                scene,
                scene.rootId,
                0,
                canvasState.selection,
                canvasState.hovered,
                store,
                focusFrameId,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build a node and its children recursively.
  Widget _buildNodeTree(
    ExpandedScene scene,
    String expandedId,
    int depth,
    Set<DragTarget> selection,
    DragTarget? hovered,
    EditorDocumentStore store,
    String focusFrameId,
  ) {
    final expandedNode = scene.nodes[expandedId];
    if (expandedNode == null) return const SizedBox.shrink();

    // Determine children to display:
    // - For instance roots: show slot children from index (O(1) lookup)
    // - For regular editable nodes: show their actual children
    // - For non-editable nodes: no children (leaves)
    final List<String> displayChildren;
    if (expandedNode.origin?.kind == OriginKind.instanceRoot) {
      // Instance roots show slot content as virtual children
      displayChildren = scene.slotChildrenByInstance[expandedId] ?? const [];
    } else if (expandedNode.patchTargetId != null) {
      // Regular editable nodes show their actual children
      displayChildren = expandedNode.childIds;
    } else {
      // Non-editable nodes (component children) are leaves
      displayChildren = const [];
    }

    final canExpand = displayChildren.isNotEmpty;
    final isExpanded = canExpand && widget.treeState.isExpanded(expandedId);

    // Check selection/hover by matching expandedId
    final isSelected = selection.any(
      (t) => t is NodeTarget && t.expandedId == expandedId,
    );
    final isHovered = hovered is NodeTarget && hovered.expandedId == expandedId;

    // Get node name from document (ExpandedNode doesn't have name)
    final nodeName = _getNodeName(store, expandedNode);

    // Get componentId for instance nodes (for "go to component" action)
    final componentId = expandedNode.props is InstanceProps
        ? (expandedNode.props as InstanceProps).componentId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NodeTreeItem(
          key: widget.treeState.getOrCreateKey(expandedId),
          expandedId: expandedId,
          expandedNode: expandedNode,
          nodeName: nodeName,
          depth: depth,
          isExpanded: canExpand ? isExpanded : null,
          isSelected: isSelected,
          isHovered: isHovered,
          onTap: () => _handleTap(expandedId, expandedNode, focusFrameId),
          onHoverEnter:
              () => _handleHoverEnter(expandedId, expandedNode, focusFrameId),
          onHoverExit: () => _handleHoverExit(expandedId),
          onToggleExpand:
              canExpand
                  ? () => widget.treeState.toggleExpanded(expandedId)
                  : null,
          onGoToComponent:
              componentId != null
                  ? () => _navigateToComponent(context, componentId)
                  : null,
        ),
        if (canExpand && isExpanded)
          ...displayChildren.map(
            (childId) => _buildNodeTree(
              scene,
              childId,
              depth + 1,
              selection,
              hovered,
              store,
              focusFrameId,
            ),
          ),
      ],
    );
  }

  /// Get node name from document store.
  ///
  /// Falls back to the node type if name is not available.
  String _getNodeName(EditorDocumentStore store, ExpandedNode expandedNode) {
    // Try to get name from patch target
    if (expandedNode.patchTargetId != null) {
      final node = store.document.nodes[expandedNode.patchTargetId];
      if (node != null && node.name.isNotEmpty) {
        return node.name;
      }
    }

    // Fall back to type name
    return expandedNode.type.name;
  }

  /// Handle selection changes from canvas - auto-expand and scroll.
  void _handleSelectionChange(CanvasState canvasState, ExpandedScene scene) {
    final selection = canvasState.selection;
    if (selection.length == 1 && selection.first is NodeTarget) {
      final target = selection.first as NodeTarget;

      // Build ancestor path using expanded IDs
      final ancestorPath = _getExpandedAncestorPath(scene, target.expandedId);

      // Expand all ancestors
      if (ancestorPath.isNotEmpty) {
        widget.treeState.expandPath(ancestorPath);
      }

      // Auto-scroll after rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.treeState.scrollToNode(target.expandedId);
        }
      });
    }
  }

  /// Get ancestor path from root to node (exclusive of node itself).
  List<String> _getExpandedAncestorPath(
    ExpandedScene scene,
    String expandedId,
  ) {
    final ancestors = <String>[];
    String? current = expandedId;

    // Build parent index from scene.nodes
    final parentIndex = <String, String>{};
    for (final node in scene.nodes.values) {
      for (final childId in node.childIds) {
        parentIndex[childId] = node.id;
      }
    }

    // Walk up to root
    while (current != null && current != scene.rootId) {
      current = parentIndex[current];
      if (current != null && current != scene.rootId) {
        ancestors.add(current);
      }
    }

    return ancestors;
  }

  /// Handle tree item tap - select on canvas.
  void _handleTap(
    String expandedId,
    ExpandedNode expandedNode,
    String focusFrameId,
  ) {
    // Determine what to select:
    // - Regular editable nodes and instance roots: patchTargetId is the doc node ID
    // - Component children (null patchTargetId): not selectable
    final patchTarget = expandedNode.patchTargetId;

    if (patchTarget == null) {
      // Component children can't be selected
      return;
    }

    final canvasState = context.read<CanvasState>();

    // Use canvasState.select() with NodeTarget containing expandedId
    canvasState.select(
      NodeTarget(
        frameId: focusFrameId,
        expandedId: expandedId,
        patchTarget: patchTarget,
      ),
      addToSelection: false, // Replace selection
    );
  }

  /// Handle hover enter - set hovered on canvas.
  void _handleHoverEnter(
    String expandedId,
    ExpandedNode expandedNode,
    String focusFrameId,
  ) {
    // Component children (null patchTargetId) can't be hovered
    final patchTarget = expandedNode.patchTargetId;

    if (patchTarget == null) {
      return;
    }

    final canvasState = context.read<CanvasState>();

    canvasState.setHovered(
      NodeTarget(
        frameId: focusFrameId,
        expandedId: expandedId,
        patchTarget: patchTarget,
      ),
    );
  }

  /// Handle hover exit - clear hovered on canvas if still relevant.
  void _handleHoverExit(String expandedId) {
    final canvasState = context.read<CanvasState>();

    // Only clear if this is still the hovered target
    final hovered = canvasState.hovered;
    if (hovered is NodeTarget && hovered.expandedId == expandedId) {
      canvasState.setHovered(null);
    }
  }

  /// Navigate to a component's editing frame.
  void _navigateToComponent(BuildContext context, String componentId) {
    final canvasState = context.read<CanvasState>();
    canvasState.navigateToComponent(componentId);
  }

  /// Determine which frame should be shown in the tree.
  ///
  /// Priority:
  /// 1. Frame containing selected node
  /// 2. Selected frame
  /// 3. Frame containing hovered node
  /// 4. Hovered frame
  /// 5. First frame in document
  String? _getFocusFrameId(CanvasState state, EditorDocument doc) {
    // 1. If a node is selected, use its frame
    final nodeTarget = state.selection.whereType<NodeTarget>().firstOrNull;
    if (nodeTarget != null) return nodeTarget.frameId;

    // 2. If a frame is selected, use that frame
    final frameTarget = state.selection.whereType<FrameTarget>().firstOrNull;
    if (frameTarget != null) return frameTarget.frameId;

    // 3. If something is hovered, use its frame
    final hovered = state.hovered;
    if (hovered is NodeTarget) return hovered.frameId;
    if (hovered is FrameTarget) return hovered.frameId;

    // 4. Fall back to first frame
    return doc.frames.keys.firstOrNull;
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey,
          ),
          textAlign: ui.TextAlign.center,
        ),
      ),
    );
  }
}
