import 'dart:ui';

import '../utils/collection_equality.dart';

/// The type of a render node.
///
/// Render types are more granular than editor node types, specifically
/// distinguishing between layout containers (box, row, column).
enum RenderNodeType {
  /// A container with stack/absolute positioning.
  box,

  /// A horizontal flex container (Row).
  row,

  /// A vertical flex container (Column).
  column,

  /// Text content.
  text,

  /// Image content.
  image,

  /// Icon content.
  icon,

  /// Flexible/fixed spacer.
  spacer,
}

/// A document ready for rendering to Flutter widgets.
///
/// The render document contains fully-resolved nodes where:
/// - All tokens have been resolved to concrete values
/// - Container nodes have been mapped to specific render types
/// - Layout properties are ready for widget construction
class RenderDocument {
  /// The root node ID.
  final String rootId;

  /// All render nodes, keyed by ID.
  final Map<String, RenderNode> nodes;

  const RenderDocument({
    required this.rootId,
    required this.nodes,
  });

  /// Get a node by ID.
  RenderNode? getNode(String id) => nodes[id];

  /// Whether this document is empty.
  bool get isEmpty => nodes.isEmpty;

  /// Whether this document is not empty.
  bool get isNotEmpty => nodes.isNotEmpty;

  @override
  String toString() => 'RenderDocument(root: $rootId, nodes: ${nodes.length})';
}

/// A node ready for rendering to Flutter widgets.
///
/// Contains all resolved values needed to construct the widget:
/// - Concrete colors (no token references)
/// - Resolved dimensions
/// - Layout parameters
class RenderNode {
  /// The node ID (matches expanded scene ID).
  final String id;

  /// The render type (determines which widget to create).
  final RenderNodeType type;

  /// Resolved properties for widget construction.
  ///
  /// Contents depend on [type]:
  /// - box/row/column: width, height, padding, gap, fill, stroke, etc.
  /// - text: text, fontSize, fontWeight, color, etc.
  /// - image: src, fit, etc.
  /// - icon: icon, size, color
  /// - spacer: width, height, flex
  final Map<String, dynamic> props;

  /// Child node IDs.
  final List<String> childIds;

  /// Computed bounds after layout (null until layout pass).
  /// Set by BoundsTracker post-frame callback for measured bounds.
  Rect? computedBounds;

  /// Pre-computed bounds from compilation (frame-local).
  ///
  /// Non-null for absolute-positioned nodes with fixed size.
  /// Null for auto-layout nodes that need post-frame measurement.
  /// These bounds are known at compile time and don't require measurement.
  ///
  /// Coordinates are frame-local (relative to parent's origin, or frame origin for root).
  final Rect? compiledBounds;

  RenderNode({
    required this.id,
    required this.type,
    required this.props,
    required this.childIds,
    this.computedBounds,
    this.compiledBounds,
  });

  /// Get a property value.
  T? prop<T>(String key) {
    final value = props[key];
    if (value is T) return value;
    return null;
  }

  /// Get a property value with default.
  T propOr<T>(String key, T defaultValue) {
    return prop<T>(key) ?? defaultValue;
  }

  /// Create a copy with updated properties.
  RenderNode copyWith({
    String? id,
    RenderNodeType? type,
    Map<String, dynamic>? props,
    List<String>? childIds,
    Rect? computedBounds,
    Rect? compiledBounds,
  }) {
    return RenderNode(
      id: id ?? this.id,
      type: type ?? this.type,
      props: props ?? this.props,
      childIds: childIds ?? this.childIds,
      computedBounds: computedBounds ?? this.computedBounds,
      compiledBounds: compiledBounds ?? this.compiledBounds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenderNode &&
          id == other.id &&
          type == other.type &&
          mapEquals(props, other.props) &&
          listEquals(childIds, other.childIds);

  @override
  int get hashCode => Object.hash(
        id,
        type,
        Object.hashAll(props.entries),
        Object.hashAll(childIds),
      );

  @override
  String toString() =>
      'RenderNode($id, type: $type, children: ${childIds.length})';
}
