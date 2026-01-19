import 'dart:ui';

/// Distinguishes design frames from component editing frames.
enum FrameKind {
  /// A regular design surface (screen, page, modal).
  design,

  /// A frame for editing a component's internal structure.
  component,
}

/// A frame is a top-level design surface (screen, page, modal).
///
/// Frames exist on the infinite canvas and contain a tree of nodes.
/// A frame can be either a design frame (for regular design work) or
/// a component frame (for editing a component's internal structure).
class Frame {
  /// Unique identifier for this frame.
  final String id;

  /// Human-readable name for the frame.
  final String name;

  /// Root node ID for this frame's content tree.
  final String rootNodeId;

  /// Canvas placement (position and size on the infinite canvas).
  final CanvasPlacement canvas;

  /// The kind of frame (design surface or component editor).
  final FrameKind kind;

  /// For component frames: the ComponentDef this frame edits.
  /// Null for design frames.
  final String? componentId;

  /// When this frame was created.
  final DateTime createdAt;

  /// When this frame was last modified.
  final DateTime updatedAt;

  const Frame({
    required this.id,
    required this.name,
    required this.rootNodeId,
    required this.canvas,
    this.kind = FrameKind.design,
    this.componentId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy with modified fields.
  Frame copyWith({
    String? id,
    String? name,
    String? rootNodeId,
    CanvasPlacement? canvas,
    FrameKind? kind,
    String? componentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Frame(
      id: id ?? this.id,
      name: name ?? this.name,
      rootNodeId: rootNodeId ?? this.rootNodeId,
      canvas: canvas ?? this.canvas,
      kind: kind ?? this.kind,
      componentId: componentId ?? this.componentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a Frame from JSON.
  ///
  /// Backwards compatible: `kind` defaults to `design` if not present.
  factory Frame.fromJson(Map<String, dynamic> json) {
    return Frame(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      rootNodeId: json['rootNodeId'] as String,
      canvas: CanvasPlacement.fromJson(
        json['canvas'] as Map<String, dynamic>,
      ),
      kind: json['kind'] != null
          ? FrameKind.values.byName(json['kind'] as String)
          : FrameKind.design,
      componentId: json['componentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rootNodeId': rootNodeId,
        'canvas': canvas.toJson(),
        'kind': kind.name,
        if (componentId != null) 'componentId': componentId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Frame &&
          id == other.id &&
          name == other.name &&
          rootNodeId == other.rootNodeId &&
          canvas == other.canvas &&
          kind == other.kind &&
          componentId == other.componentId &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        rootNodeId,
        canvas,
        kind,
        componentId,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'Frame(id: $id, name: $name)';
}

/// Canvas placement for a frame (position and size on the infinite canvas).
class CanvasPlacement {
  /// Position on the infinite canvas (top-left corner).
  final Offset position;

  /// Size of the frame.
  final Size size;

  const CanvasPlacement({
    required this.position,
    required this.size,
  });

  /// Create a copy with modified fields.
  CanvasPlacement copyWith({
    Offset? position,
    Size? size,
  }) {
    return CanvasPlacement(
      position: position ?? this.position,
      size: size ?? this.size,
    );
  }

  /// Create a CanvasPlacement from JSON.
  factory CanvasPlacement.fromJson(Map<String, dynamic> json) {
    final position = json['position'] as Map<String, dynamic>;
    final size = json['size'] as Map<String, dynamic>;
    return CanvasPlacement(
      position: Offset(
        (position['x'] as num).toDouble(),
        (position['y'] as num).toDouble(),
      ),
      size: Size(
        (size['width'] as num).toDouble(),
        (size['height'] as num).toDouble(),
      ),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'position': {
          'x': position.dx,
          'y': position.dy,
        },
        'size': {
          'width': size.width,
          'height': size.height,
        },
      };

  /// Get the bounding rectangle.
  Rect get bounds => Rect.fromLTWH(
        position.dx,
        position.dy,
        size.width,
        size.height,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasPlacement &&
          position == other.position &&
          size == other.size;

  @override
  int get hashCode => Object.hash(position, size);

  @override
  String toString() =>
      'CanvasPlacement(position: $position, size: $size)';
}
