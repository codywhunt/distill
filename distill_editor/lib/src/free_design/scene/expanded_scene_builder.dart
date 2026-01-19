import '../models/component_def.dart';
import '../models/editor_document.dart';
import '../models/node.dart';
import '../models/node_props.dart';
import '../models/node_type.dart';
import 'expanded_scene.dart';

/// Builds an [ExpandedScene] from an [EditorDocument].
///
/// The builder expands component instances into their full node trees,
/// applying ID namespacing and overrides. This creates a flat, fully-resolved
/// view suitable for rendering.
///
/// ## ID Namespacing
///
/// Nodes inside instances get namespaced IDs to prevent collisions:
/// - Regular node: `n_button`
/// - Inside instance `inst1`: `inst1::comp_button::btn_root`
/// - Nested instances: `inst1::inst2::comp_button::btn_root`
///
/// ## Patch Targeting
///
/// The builder tracks which document node should be patched when editing
/// an expanded node:
/// - Regular nodes: patch target = node ID
/// - Instance children (v1): patch target = null (not editable)
///
/// ## Cycle Detection
///
/// The builder detects component cycles (A → B → A) and creates error
/// placeholders instead of infinite loops. Same component used multiple times
/// in different paths is allowed.
class ExpandedSceneBuilder {
  const ExpandedSceneBuilder();

  /// Build an expanded scene for a frame.
  ///
  /// Returns null if the frame doesn't exist or has no valid root node.
  ExpandedScene? build(String frameId, EditorDocument doc) {
    final frame = doc.frames[frameId];
    if (frame == null) return null;

    final rootNode = doc.nodes[frame.rootNodeId];
    if (rootNode == null) return null;

    final nodes = <String, ExpandedNode>{};
    final patchTarget = <String, String?>{};
    final slotChildrenByInstance = <String, List<String>>{};

    _expandNode(
      node: rootNode,
      doc: doc,
      namespace: null,
      instancePatchTarget: null,
      nodes: nodes,
      patchTarget: patchTarget,
      slotChildrenByInstance: slotChildrenByInstance,
      ancestorComponentIds: const {},
      instancePath: const [],
    );

    return ExpandedScene(
      frameId: frameId,
      rootId: rootNode.id,
      nodes: nodes,
      patchTarget: patchTarget,
      slotChildrenByInstance: slotChildrenByInstance,
    );
  }

  /// Recursively expand a node and its children.
  ///
  /// Returns the expanded ID of this node (useful for parent to reference).
  String? _expandNode({
    required Node node,
    required EditorDocument doc,
    required String? namespace,
    required String? instancePatchTarget,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required Map<String, List<String>> slotChildrenByInstance,
    required Set<String> ancestorComponentIds,
    required List<String> instancePath,
  }) {
    final expandedId = _namespaceId(node.id, namespace);
    final targetId = instancePatchTarget ?? node.id;

    // Handle instance nodes - returns the expanded root ID of the component
    if (node.type == NodeType.instance) {
      return _expandInstance(
        instanceNode: node,
        doc: doc,
        namespace: namespace,
        nodes: nodes,
        patchTarget: patchTarget,
        slotChildrenByInstance: slotChildrenByInstance,
        ancestorComponentIds: ancestorComponentIds,
        instancePath: instancePath,
      );
    }

    // Expand children with proper namespacing
    final expandedChildIds = <String>[];
    for (final childId in node.childIds) {
      final childNode = doc.nodes[childId];
      if (childNode == null) continue;

      // Get the actual expanded ID from the child expansion
      // (instance children return their component root ID)
      final childExpandedId = _expandNode(
        node: childNode,
        doc: doc,
        namespace: namespace,
        instancePatchTarget: instancePatchTarget,
        nodes: nodes,
        patchTarget: patchTarget,
        slotChildrenByInstance: slotChildrenByInstance,
        ancestorComponentIds: ancestorComponentIds,
        instancePath: instancePath,
      );

      if (childExpandedId != null) {
        expandedChildIds.add(childExpandedId);
      }
    }

    // Determine origin kind
    final originKind =
        instancePath.isEmpty ? OriginKind.frameNode : OriginKind.componentChild;

    // Create expanded node with origin metadata
    final expandedNode = ExpandedNode.fromNode(
      node,
      expandedId: expandedId,
      patchTargetId: targetId,
      childIds: expandedChildIds,
      origin: ExpandedNodeOrigin(
        kind: originKind,
        instancePath: instancePath,
      ),
    );

    nodes[expandedId] = expandedNode;
    patchTarget[expandedId] = targetId;

    return expandedId;
  }

  /// Expand a component instance.
  ///
  /// Returns the expanded ID of the component's root node (for parent to reference).
  String? _expandInstance({
    required Node instanceNode,
    required EditorDocument doc,
    required String? namespace,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required Map<String, List<String>> slotChildrenByInstance,
    required Set<String> ancestorComponentIds,
    required List<String> instancePath,
  }) {
    final props = instanceNode.props;
    if (props is! InstanceProps) return null;

    final componentId = props.componentId;

    // Cycle detection - check if we're re-entering a component in the current path
    if (ancestorComponentIds.contains(componentId)) {
      return _createCyclePlaceholder(
        instanceNode: instanceNode,
        namespace: namespace,
        nodes: nodes,
        patchTarget: patchTarget,
        instancePath: instancePath,
        cycleComponentId: componentId,
      );
    }

    final component = doc.components[componentId];
    if (component == null) {
      // Component not found - create placeholder
      return _createMissingPlaceholder(
        instanceNode: instanceNode,
        namespace: namespace,
        nodes: nodes,
        patchTarget: patchTarget,
        instancePath: instancePath,
        missingComponentId: componentId,
      );
    }

    final componentRoot = doc.nodes[component.rootNodeId];
    if (componentRoot == null) {
      return _createMissingPlaceholder(
        instanceNode: instanceNode,
        namespace: namespace,
        nodes: nodes,
        patchTarget: patchTarget,
        instancePath: instancePath,
        missingComponentId: componentId,
      );
    }

    // Create new namespace for instance children
    final instanceId = _namespaceId(instanceNode.id, namespace);
    final instanceNamespace = instanceId;

    // Update ancestor tracking for cycle detection
    final newAncestors = {...ancestorComponentIds, componentId};
    final newInstancePath = [...instancePath, instanceId];

    // Recursively expand component tree with instance namespace
    // All children inside instance patch back to the instance node
    _expandComponentTree(
      node: componentRoot,
      doc: doc,
      component: component,
      instanceId: instanceId,
      instanceNamespace: instanceNamespace,
      instanceProps: props,
      overrides: props.overrides,
      nodes: nodes,
      patchTarget: patchTarget,
      slotChildrenByInstance: slotChildrenByInstance,
      ancestorComponentIds: newAncestors,
      instancePath: newInstancePath,
    );

    // The component root's expanded ID becomes the instance's child
    final componentRootExpandedId = '$instanceNamespace::${component.rootNodeId}';

    // Create the instance node itself with OriginKind.instanceRoot
    // This makes the instance selectable in the layer tree
    final instanceExpandedNode = ExpandedNode.fromNode(
      instanceNode,
      expandedId: instanceId,
      patchTargetId: instanceNode.id, // Instance is editable (selectable)
      childIds: [componentRootExpandedId], // Component root is its child
      origin: ExpandedNodeOrigin(
        kind: OriginKind.instanceRoot,
        componentId: componentId,
        instancePath: instancePath, // Parent's instance path (before this instance)
      ),
    );

    nodes[instanceId] = instanceExpandedNode;
    patchTarget[instanceId] = instanceNode.id;

    // Return the instance's expanded ID (not the component root)
    // This is what parent nodes should reference as their child
    return instanceId;
  }

  /// Expand a component's node tree within an instance.
  void _expandComponentTree({
    required Node node,
    required EditorDocument doc,
    required ComponentDef component,
    required String instanceId,
    required String instanceNamespace,
    required InstanceProps instanceProps,
    required Map<String, dynamic> overrides,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required Map<String, List<String>> slotChildrenByInstance,
    required Set<String> ancestorComponentIds,
    required List<String> instancePath,
  }) {
    final expandedId = '$instanceNamespace::${node.id}';

    // Handle nested instances
    if (node.type == NodeType.instance) {
      _expandInstance(
        instanceNode: node,
        doc: doc,
        namespace: instanceNamespace,
        nodes: nodes,
        patchTarget: patchTarget,
        slotChildrenByInstance: slotChildrenByInstance,
        ancestorComponentIds: ancestorComponentIds,
        instancePath: instancePath,
      );
      return;
    }

    // Expand children
    final expandedChildIds = <String>[];
    for (final childId in node.childIds) {
      final childNode = doc.nodes[childId];
      if (childNode == null) continue;

      // Handle slot nodes - returns exactly ONE expanded ID (root, default, or placeholder)
      if (childNode.type == NodeType.slot) {
        final slotExpandedId = _expandSlot(
          slotNode: childNode,
          doc: doc,
          instanceId: instanceId,
          instanceNamespace: instanceNamespace,
          instanceProps: instanceProps,
          nodes: nodes,
          patchTarget: patchTarget,
          slotChildrenByInstance: slotChildrenByInstance,
          ancestorComponentIds: ancestorComponentIds,
          instancePath: instancePath,
        );
        if (slotExpandedId != null) {
          expandedChildIds.add(slotExpandedId);
        }
        continue;
      }

      // Check if child is a nested instance
      if (childNode.type == NodeType.instance) {
        final nestedExpandedId = _expandInstance(
          instanceNode: childNode,
          doc: doc,
          namespace: instanceNamespace,
          nodes: nodes,
          patchTarget: patchTarget,
          slotChildrenByInstance: slotChildrenByInstance,
          ancestorComponentIds: ancestorComponentIds,
          instancePath: instancePath,
        );
        if (nestedExpandedId != null) {
          expandedChildIds.add(nestedExpandedId);
        }
      } else {
        final expandedChildId = '$instanceNamespace::$childId';
        expandedChildIds.add(expandedChildId);

        _expandComponentTree(
          node: childNode,
          doc: doc,
          component: component,
          instanceId: instanceId,
          instanceNamespace: instanceNamespace,
          instanceProps: instanceProps,
          overrides: overrides,
          nodes: nodes,
          patchTarget: patchTarget,
          slotChildrenByInstance: slotChildrenByInstance,
          ancestorComponentIds: ancestorComponentIds,
          instancePath: instancePath,
        );
      }
    }

    // Apply overrides - support both local and namespaced keys for compatibility
    var resolvedNode = node;
    final localId = localIdFromNodeId(node.id);
    final nodeOverrides =
        overrides[node.id] ?? (localId != null ? overrides[localId] : null);
    final wasOverridden = nodeOverrides != null;

    if (nodeOverrides != null && nodeOverrides is Map<String, dynamic>) {
      resolvedNode = _applyOverrides(node, nodeOverrides);
    }

    // Create expanded node - instance children cannot be edited (v1)
    // Set editableTarget: false to ensure patchTargetId is null
    final expandedNode = ExpandedNode.fromNode(
      resolvedNode,
      expandedId: expandedId,
      editableTarget: false,
      childIds: expandedChildIds,
      origin: ExpandedNodeOrigin(
        kind: OriginKind.componentChild,
        componentId: component.id,
        componentTemplateUid: node.templateUid,
        instancePath: instancePath,
        isOverridden: wasOverridden,
      ),
    );

    nodes[expandedId] = expandedNode;
    patchTarget[expandedId] = null;
  }

  // ===========================================================================
  // Slot Expansion
  // ===========================================================================

  /// Generate a safe expanded ID for slot content.
  ///
  /// Uses safe encoding to prevent parsing ambiguity when contentNodeId
  /// contains '::' (e.g., if someone injects a component-owned node).
  String _slotContentExpandedId(
    String instanceNamespace,
    String slotName,
    String contentNodeId,
  ) {
    final safeContentId = contentNodeId.replaceAll('::', '__');
    return '$instanceNamespace::slot($slotName)::$safeContentId';
  }

  /// Expand a slot node. Returns the expanded ID of:
  /// - Injected content root (if SlotAssignment has content)
  /// - Default content root (if slot has defaultContentId, NOT editable)
  /// - Slot placeholder (if empty, for visual indication)
  String? _expandSlot({
    required Node slotNode,
    required EditorDocument doc,
    required String instanceId,
    required String instanceNamespace,
    required InstanceProps instanceProps,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required Map<String, List<String>> slotChildrenByInstance,
    required Set<String> ancestorComponentIds,
    required List<String> instancePath,
  }) {
    final slotProps = slotNode.props as SlotProps;
    final slotName = slotProps.slotName;
    final assignment = instanceProps.slots[slotName];

    // Case 1: Slot has injected content
    if (assignment?.hasContent == true) {
      final contentRootId = assignment!.rootNodeId!;
      final contentRoot = doc.nodes[contentRootId];
      if (contentRoot == null) return null;

      final rootExpandedId = _expandSlotContentTree(
        node: contentRoot,
        slotName: slotName,
        instanceId: instanceId,
        instanceNamespace: instanceNamespace,
        doc: doc,
        nodes: nodes,
        patchTarget: patchTarget,
        slotChildrenByInstance: slotChildrenByInstance,
        ancestorComponentIds: ancestorComponentIds,
        instancePath: instancePath,
      );

      // Register in index for layer tree (O(1) lookup)
      slotChildrenByInstance.putIfAbsent(instanceId, () => []).add(rootExpandedId);

      return rootExpandedId;
    }

    // Case 2: Slot has default content (component-owned, NOT editable)
    if (slotProps.defaultContentId != null) {
      final defaultRoot = doc.nodes[slotProps.defaultContentId];
      if (defaultRoot != null) {
        return _expandDefaultContent(
          node: defaultRoot,
          slotName: slotName,
          instanceNamespace: instanceNamespace,
          doc: doc,
          nodes: nodes,
          patchTarget: patchTarget,
          instancePath: instancePath,
        );
      }
    }

    // Case 3: Empty slot - render placeholder
    return _expandSlotPlaceholder(
      slotNode: slotNode,
      instanceNamespace: instanceNamespace,
      nodes: nodes,
      patchTarget: patchTarget,
      instancePath: instancePath,
    );
  }

  /// Recursively expand slot content (injected, editable).
  ///
  /// Returns the expanded ID of the root node.
  /// All descendants get OriginKind.slotContent and non-null patchTargetId.
  String _expandSlotContentTree({
    required Node node,
    required String slotName,
    required String instanceId,
    required String instanceNamespace,
    required EditorDocument doc,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required Map<String, List<String>> slotChildrenByInstance,
    required Set<String> ancestorComponentIds,
    required List<String> instancePath,
  }) {
    final expandedId = _slotContentExpandedId(instanceNamespace, slotName, node.id);

    // Handle nested instances within slot content
    if (node.type == NodeType.instance) {
      final nestedId = _expandInstance(
        instanceNode: node,
        doc: doc,
        namespace: '$instanceNamespace::slot($slotName)',
        nodes: nodes,
        patchTarget: patchTarget,
        slotChildrenByInstance: slotChildrenByInstance,
        ancestorComponentIds: ancestorComponentIds,
        instancePath: instancePath,
      );
      return nestedId ?? expandedId;
    }

    // Expand children recursively - ALL get slotContent origin
    final expandedChildIds = <String>[];
    for (final childId in node.childIds) {
      final childNode = doc.nodes[childId];
      if (childNode == null) continue;

      final childExpandedId = _expandSlotContentTree(
        node: childNode,
        slotName: slotName,
        instanceId: instanceId,
        instanceNamespace: instanceNamespace,
        doc: doc,
        nodes: nodes,
        patchTarget: patchTarget,
        slotChildrenByInstance: slotChildrenByInstance,
        ancestorComponentIds: ancestorComponentIds,
        instancePath: instancePath,
      );
      expandedChildIds.add(childExpandedId);
    }

    // Create expanded node - EDITABLE (patchTargetId = doc node id)
    final expandedNode = ExpandedNode.fromNode(
      node,
      expandedId: expandedId,
      patchTargetId: node.id, // Makes it editable
      childIds: expandedChildIds,
      origin: ExpandedNodeOrigin(
        kind: OriginKind.slotContent,
        instancePath: instancePath,
        slotOrigin: SlotOrigin(
          slotName: slotName,
          instanceId: instanceId,
        ),
      ),
    );

    nodes[expandedId] = expandedNode;
    patchTarget[expandedId] = node.id;

    return expandedId;
  }

  /// Expand default slot content (component-owned, NOT editable).
  String _expandDefaultContent({
    required Node node,
    required String slotName,
    required String instanceNamespace,
    required EditorDocument doc,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required List<String> instancePath,
  }) {
    final safeId = node.id.replaceAll('::', '__');
    final expandedId = '$instanceNamespace::$slotName::default::$safeId';

    // Expand children (also not editable)
    final expandedChildIds = <String>[];
    for (final childId in node.childIds) {
      final childNode = doc.nodes[childId];
      if (childNode == null) continue;

      final childExpandedId = _expandDefaultContent(
        node: childNode,
        slotName: slotName,
        instanceNamespace: instanceNamespace,
        doc: doc,
        nodes: nodes,
        patchTarget: patchTarget,
        instancePath: instancePath,
      );
      expandedChildIds.add(childExpandedId);
    }

    // Create expanded node directly (NOT editable - patchTargetId must be null)
    final expandedNode = ExpandedNode(
      id: expandedId,
      patchTargetId: null, // NOT editable - component-owned
      type: node.type,
      childIds: expandedChildIds,
      layout: node.layout,
      style: node.style,
      props: node.props,
      origin: ExpandedNodeOrigin(
        kind: OriginKind.componentChild, // Default content is component-owned
        instancePath: instancePath,
      ),
    );

    nodes[expandedId] = expandedNode;
    patchTarget[expandedId] = null;

    return expandedId;
  }

  /// Expand an empty slot as a placeholder.
  String _expandSlotPlaceholder({
    required Node slotNode,
    required String instanceNamespace,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required List<String> instancePath,
  }) {
    final expandedId = '$instanceNamespace::${slotNode.id}';

    // Create expanded node directly (NOT editable - patchTargetId must be null)
    final expandedNode = ExpandedNode(
      id: expandedId,
      patchTargetId: null,
      type: slotNode.type,
      childIds: const [],
      layout: slotNode.layout,
      style: slotNode.style,
      props: slotNode.props,
      origin: ExpandedNodeOrigin(
        kind: OriginKind.componentChild,
        instancePath: instancePath,
      ),
    );

    nodes[expandedId] = expandedNode;
    patchTarget[expandedId] = null;

    return expandedId;
  }

  // ===========================================================================
  // Overrides
  // ===========================================================================

  /// Apply overrides to a node.
  Node _applyOverrides(Node node, Map<String, dynamic> overrides) {
    var result = node;

    // Apply props overrides
    if (overrides.containsKey('props')) {
      final propsOverrides = overrides['props'];
      if (propsOverrides is Map<String, dynamic>) {
        result = _applyPropsOverrides(result, propsOverrides);
      }
    }

    // Apply style overrides
    if (overrides.containsKey('style')) {
      final styleOverrides = overrides['style'];
      if (styleOverrides is Map<String, dynamic>) {
        result = _applyStyleOverrides(result, styleOverrides);
      }
    }

    // Apply layout overrides
    if (overrides.containsKey('layout')) {
      final layoutOverrides = overrides['layout'];
      if (layoutOverrides is Map<String, dynamic>) {
        result = _applyLayoutOverrides(result, layoutOverrides);
      }
    }

    return result;
  }

  /// Apply props overrides based on node type.
  Node _applyPropsOverrides(Node node, Map<String, dynamic> overrides) {
    final props = node.props;

    final newProps = switch (props) {
      TextProps() => props.copyWith(
          text: overrides['text'] as String? ?? props.text,
        ),
      ImageProps() => props.copyWith(
          src: overrides['src'] as String? ?? props.src,
        ),
      IconProps() => props.copyWith(
          icon: overrides['icon'] as String? ?? props.icon,
        ),
      _ => props,
    };

    return node.copyWith(props: newProps);
  }

  /// Apply style overrides.
  Node _applyStyleOverrides(Node node, Map<String, dynamic> overrides) {
    var style = node.style;

    if (overrides.containsKey('opacity')) {
      final opacity = overrides['opacity'];
      if (opacity is num) {
        style = style.copyWith(opacity: opacity.toDouble());
      }
    }

    // Add more style override handling as needed

    return node.copyWith(style: style);
  }

  /// Apply layout overrides.
  Node _applyLayoutOverrides(Node node, Map<String, dynamic> overrides) {
    // Layout overrides can be complex - add as needed
    return node;
  }

  /// Create a placeholder node for cycle detection.
  ///
  /// Returns the expanded ID of the placeholder.
  String _createCyclePlaceholder({
    required Node instanceNode,
    required String? namespace,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required List<String> instancePath,
    required String cycleComponentId,
  }) {
    final expandedId = _namespaceId(instanceNode.id, namespace);

    // Create a container placeholder with cycle debugging info
    final placeholderNode = ExpandedNode(
      id: expandedId,
      patchTargetId: instanceNode.id,
      type: NodeType.container,
      childIds: const [],
      layout: instanceNode.layout,
      style: instanceNode.style,
      props: const ContainerProps(),
      origin: ExpandedNodeOrigin(
        kind: OriginKind.errorPlaceholder,
        componentId: cycleComponentId,
        instancePath: instancePath,
      ),
    );

    nodes[expandedId] = placeholderNode;
    patchTarget[expandedId] = instanceNode.id;

    return expandedId;
  }

  /// Create a placeholder node for missing component.
  ///
  /// Returns the expanded ID of the placeholder.
  String _createMissingPlaceholder({
    required Node instanceNode,
    required String? namespace,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
    required List<String> instancePath,
    required String missingComponentId,
  }) {
    final expandedId = _namespaceId(instanceNode.id, namespace);

    // Create a container placeholder
    final placeholderNode = ExpandedNode(
      id: expandedId,
      patchTargetId: instanceNode.id,
      type: NodeType.container,
      childIds: const [],
      layout: instanceNode.layout,
      style: instanceNode.style,
      props: const ContainerProps(),
      origin: ExpandedNodeOrigin(
        kind: OriginKind.errorPlaceholder,
        componentId: missingComponentId,
        instancePath: instancePath,
      ),
    );

    nodes[expandedId] = placeholderNode;
    patchTarget[expandedId] = instanceNode.id;

    return expandedId;
  }

  /// Apply namespace prefix to an ID.
  String _namespaceId(String id, String? namespace) {
    if (namespace == null) return id;
    return '$namespace::$id';
  }
}
