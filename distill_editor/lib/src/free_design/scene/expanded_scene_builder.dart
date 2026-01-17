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
/// - Inside instance `inst1`: `inst1::n_button`
/// - Nested instances: `inst1::inst2::n_button`
///
/// ## Patch Targeting
///
/// The builder tracks which document node should be patched when editing
/// an expanded node:
/// - Regular nodes: patch target = node ID
/// - Instance children (v1): patch target = instance node ID
///   (editing children edits the instance, not the source component)
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

    _expandNode(
      node: rootNode,
      doc: doc,
      namespace: null,
      instancePatchTarget: null,
      nodes: nodes,
      patchTarget: patchTarget,
    );

    return ExpandedScene(
      frameId: frameId,
      rootId: rootNode.id,
      nodes: nodes,
      patchTarget: patchTarget,
    );
  }

  /// Recursively expand a node and its children.
  void _expandNode({
    required Node node,
    required EditorDocument doc,
    required String? namespace,
    required String? instancePatchTarget,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
  }) {
    final expandedId = _namespaceId(node.id, namespace);
    final targetId = instancePatchTarget ?? node.id;

    // Handle instance nodes
    if (node.type == NodeType.instance) {
      _expandInstance(
        instanceNode: node,
        doc: doc,
        namespace: namespace,
        nodes: nodes,
        patchTarget: patchTarget,
      );
      return;
    }

    // Expand children with proper namespacing
    final expandedChildIds = <String>[];
    for (final childId in node.childIds) {
      final childNode = doc.nodes[childId];
      if (childNode == null) continue;

      final expandedChildId = _namespaceId(childId, namespace);
      expandedChildIds.add(expandedChildId);

      _expandNode(
        node: childNode,
        doc: doc,
        namespace: namespace,
        instancePatchTarget: instancePatchTarget,
        nodes: nodes,
        patchTarget: patchTarget,
      );
    }

    // Create expanded node
    final expandedNode = ExpandedNode.fromNode(
      node,
      expandedId: expandedId,
      patchTargetId: targetId,
      childIds: expandedChildIds,
    );

    nodes[expandedId] = expandedNode;
    patchTarget[expandedId] = targetId;
  }

  /// Expand a component instance.
  void _expandInstance({
    required Node instanceNode,
    required EditorDocument doc,
    required String? namespace,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
  }) {
    final props = instanceNode.props;
    if (props is! InstanceProps) return;

    final componentId = props.componentId;
    final component = doc.components[componentId];
    if (component == null) {
      // Component not found - create placeholder
      _createPlaceholder(
        instanceNode: instanceNode,
        namespace: namespace,
        nodes: nodes,
        patchTarget: patchTarget,
      );
      return;
    }

    final componentRoot = doc.nodes[component.rootNodeId];
    if (componentRoot == null) {
      _createPlaceholder(
        instanceNode: instanceNode,
        namespace: namespace,
        nodes: nodes,
        patchTarget: patchTarget,
      );
      return;
    }

    // Create new namespace for instance children
    final instanceId = _namespaceId(instanceNode.id, namespace);
    final instanceNamespace = instanceId;

    // The instance node itself maps to the instance in the document
    patchTarget[instanceId] = instanceNode.id;

    // Recursively expand component tree with instance namespace
    // All children inside instance patch back to the instance node
    _expandComponentTree(
      node: componentRoot,
      doc: doc,
      component: component,
      instanceId: instanceId,
      instanceNamespace: instanceNamespace,
      overrides: props.overrides,
      nodes: nodes,
      patchTarget: patchTarget,
    );
  }

  /// Expand a component's node tree within an instance.
  void _expandComponentTree({
    required Node node,
    required EditorDocument doc,
    required ComponentDef component,
    required String instanceId,
    required String instanceNamespace,
    required Map<String, dynamic> overrides,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
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
      );
      return;
    }

    // Expand children
    final expandedChildIds = <String>[];
    for (final childId in node.childIds) {
      final childNode = doc.nodes[childId];
      if (childNode == null) continue;

      final expandedChildId = '$instanceNamespace::$childId';
      expandedChildIds.add(expandedChildId);

      _expandComponentTree(
        node: childNode,
        doc: doc,
        component: component,
        instanceId: instanceId,
        instanceNamespace: instanceNamespace,
        overrides: overrides,
        nodes: nodes,
        patchTarget: patchTarget,
      );
    }

    // Apply overrides if any exist for this node
    var resolvedNode = node;
    final nodeOverrides = overrides[node.id];
    if (nodeOverrides != null && nodeOverrides is Map<String, dynamic>) {
      resolvedNode = _applyOverrides(node, nodeOverrides);
    }

    // Create expanded node - instance children cannot be edited (v1)
    // Set patchTargetId to null to prevent editing
    final expandedNode = ExpandedNode.fromNode(
      resolvedNode,
      expandedId: expandedId,
      patchTargetId: null,
      childIds: expandedChildIds,
    );

    nodes[expandedId] = expandedNode;
    patchTarget[expandedId] = null;
  }

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

  /// Create a placeholder node for missing component.
  void _createPlaceholder({
    required Node instanceNode,
    required String? namespace,
    required Map<String, ExpandedNode> nodes,
    required Map<String, String?> patchTarget,
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
    );

    nodes[expandedId] = placeholderNode;
    patchTarget[expandedId] = instanceNode.id;
  }

  /// Apply namespace prefix to an ID.
  String _namespaceId(String id, String? namespace) {
    if (namespace == null) return id;
    return '$namespace::$id';
  }
}
