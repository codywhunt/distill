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

  /// Child node IDs (order matters for rendering).
  final List<String> childIds;

  const Node({
    required this.id,
    this.name = '',
    required this.type,
    required this.props,
    this.layout = const NodeLayout(),
    this.style = const NodeStyle(),
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
    List<String>? childIds,
  }) {
    return Node(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      props: props ?? this.props,
      layout: layout ?? this.layout,
      style: style ?? this.style,
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
          listEquals(childIds, other.childIds);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        props,
        layout,
        style,
        Object.hashAll(childIds),
      );

  @override
  String toString() => 'Node(id: $id, name: $name, type: $type)';
}
