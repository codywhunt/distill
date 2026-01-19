import '../utils/collection_equality.dart';
import 'node_layout.dart';
import 'node_props.dart';
import 'node_style.dart';
import 'node_type.dart';

/// A node in the Editor IR scene graph.
///
/// Nodes are immutable. Use [copyWith] to create modified copies.
class Node {
  /// Unique identifier for this node.
  final String id;

  /// Human-readable name for the node.
  final String name;

  /// The type of this node.
  final NodeType type;

  /// Type-specific properties.
  final NodeProps props;

  /// Layout properties (position, size, auto-layout).
  final NodeLayout layout;

  /// Visual style properties.
  final NodeStyle style;

  /// Stable template identity for param bindings (component nodes only).
  ///
  /// Must be unique within the component (not globally). Used to survive
  /// internal component restructuring when bindings need to reconnect.
  final String? templateUid;

  /// Which component owns this node (null for frame nodes).
  ///
  /// For component nodes, this tracks ownership. If set, the node's [id]
  /// must start with `"$sourceComponentId::"`.
  final String? sourceComponentId;

  /// For slot content nodes only - points to owning instance.
  ///
  /// Null for regular nodes and component template nodes. Used for:
  /// - Querying "what slot content does this instance own?"
  /// - Garbage collection when instance is deleted
  final String? ownerInstanceId;

  /// Child node IDs (order matters for rendering).
  final List<String> childIds;

  const Node({
    required this.id,
    this.name = '',
    required this.type,
    required this.props,
    this.layout = const NodeLayout(),
    this.style = const NodeStyle(),
    this.templateUid,
    this.sourceComponentId,
    this.ownerInstanceId,
    this.childIds = const [],
  });

  /// Create a copy with modified fields.
  Node copyWith({
    String? id,
    String? name,
    NodeType? type,
    NodeProps? props,
    NodeLayout? layout,
    NodeStyle? style,
    String? templateUid,
    String? sourceComponentId,
    String? ownerInstanceId,
    List<String>? childIds,
  }) {
    return Node(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      props: props ?? this.props,
      layout: layout ?? this.layout,
      style: style ?? this.style,
      templateUid: templateUid ?? this.templateUid,
      sourceComponentId: sourceComponentId ?? this.sourceComponentId,
      ownerInstanceId: ownerInstanceId ?? this.ownerInstanceId,
      childIds: childIds ?? this.childIds,
    );
  }

  /// Create a Node from JSON.
  factory Node.fromJson(Map<String, dynamic> json) {
    final type = NodeType.fromJson(json['type'] as String);
    return Node(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      type: type,
      props: NodeProps.fromJson(
        type,
        json['props'] as Map<String, dynamic>? ?? {},
      ),
      layout: json['layout'] != null
          ? NodeLayout.fromJson(json['layout'] as Map<String, dynamic>)
          : const NodeLayout(),
      style: json['style'] != null
          ? NodeStyle.fromJson(json['style'] as Map<String, dynamic>)
          : const NodeStyle(),
      templateUid: json['templateUid'] as String?,
      sourceComponentId: json['sourceComponentId'] as String?,
      ownerInstanceId: json['ownerInstanceId'] as String?,
      childIds: (json['childIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (name.isNotEmpty) 'name': name,
        'type': type.toJson(),
        'props': props.toJson(),
        'layout': layout.toJson(),
        'style': style.toJson(),
        if (templateUid != null) 'templateUid': templateUid,
        if (sourceComponentId != null) 'sourceComponentId': sourceComponentId,
        if (ownerInstanceId != null) 'ownerInstanceId': ownerInstanceId,
        if (childIds.isNotEmpty) 'childIds': childIds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          props == other.props &&
          layout == other.layout &&
          style == other.style &&
          templateUid == other.templateUid &&
          sourceComponentId == other.sourceComponentId &&
          ownerInstanceId == other.ownerInstanceId &&
          listEquals(childIds, other.childIds);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        props,
        layout,
        style,
        templateUid,
        sourceComponentId,
        ownerInstanceId,
        Object.hashAll(childIds),
      );

  @override
  String toString() => 'Node(id: $id, name: $name, type: $type)';
}

// =============================================================================
// Component Node ID Helpers
// =============================================================================

/// Generate a namespaced ID for a component node.
///
/// The [localId] is the node's identity within the component (e.g., 'btn_root').
/// Returns `'$componentId::$localId'`.
///
/// Example:
/// ```dart
/// componentNodeId('comp_button', 'btn_root') // => 'comp_button::btn_root'
/// ```
String componentNodeId(String componentId, String localId) {
  return '$componentId::$localId';
}

/// Extract the local ID from a namespaced component node ID.
///
/// For `'comp_button::btn_root'`, returns `'btn_root'`.
/// Returns null if the ID is not namespaced (doesn't contain `'::'`).
///
/// Example:
/// ```dart
/// localIdFromNodeId('comp_button::btn_root') // => 'btn_root'
/// localIdFromNodeId('not_namespaced')        // => null
/// ```
String? localIdFromNodeId(String id) {
  final idx = id.indexOf('::');
  return idx >= 0 ? id.substring(idx + 2) : null;
}

/// Extract the component ID from a namespaced component node ID.
///
/// For `'comp_button::btn_root'`, returns `'comp_button'`.
/// Returns null if the ID is not namespaced (doesn't contain `'::'`).
///
/// Example:
/// ```dart
/// componentIdFromNodeId('comp_button::btn_root') // => 'comp_button'
/// componentIdFromNodeId('not_namespaced')        // => null
/// ```
String? componentIdFromNodeId(String id) {
  final idx = id.indexOf('::');
  return idx >= 0 ? id.substring(0, idx) : null;
}
