/// ECS Components for Distill
///
/// Components are pure data - no methods, no behavior.
/// Each represents one aspect of an entity.

import 'dart:ui';

import '../core/component.dart';
import '../core/entity.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SPATIAL COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Local position relative to parent (or world if no parent)
class Position implements Component {
  double x;
  double y;

  Position(this.x, this.y);

  Offset toOffset() => Offset(x, y);

  Position copy() => Position(x, y);

  @override
  String toString() => 'Position($x, $y)';
}

/// Size of the entity
class Size implements Component {
  double width;
  double height;

  Size(this.width, this.height);

  Size copy() => Size(width, height);

  Rect toRect(Offset offset) => Rect.fromLTWH(offset.dx, offset.dy, width, height);

  @override
  String toString() => 'Size($width, $height)';
}

/// Computed world-space transform (output of TransformSystem)
class WorldTransform implements Component {
  /// Accumulated transform from root to this entity
  final Matrix4 matrix;

  WorldTransform(this.matrix);

  Offset get translation => Offset(matrix.entry(0, 3), matrix.entry(1, 3));

  /// Transform a local point to world space
  Offset localToWorld(Offset local) {
    return Offset(
      matrix.entry(0, 0) * local.dx + matrix.entry(0, 3),
      matrix.entry(1, 1) * local.dy + matrix.entry(1, 3),
    );
  }
}

/// Computed world-space bounds (output of BoundsSystem)
class WorldBounds implements Component {
  final Rect rect;

  WorldBounds(this.rect);

  bool contains(Offset point) => rect.contains(point);
  bool overlaps(Rect other) => rect.overlaps(other);
}

// ═══════════════════════════════════════════════════════════════════════════
// STYLE COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Fill (background)
class Fill implements Component {
  final FillType type;
  final Color? color;
  final Gradient? gradient;
  final String? imageUrl;

  const Fill._({
    required this.type,
    this.color,
    this.gradient,
    this.imageUrl,
  });

  factory Fill.solid(Color color) => Fill._(type: FillType.solid, color: color);
  factory Fill.gradient(Gradient gradient) =>
      Fill._(type: FillType.gradient, gradient: gradient);
  factory Fill.image(String url) => Fill._(type: FillType.image, imageUrl: url);
  factory Fill.none() => const Fill._(type: FillType.none);

  bool get isNone => type == FillType.none;
}

enum FillType { none, solid, gradient, image }

/// Gradient definition
class Gradient {
  final List<Color> colors;
  final List<double> stops;
  final GradientType type;
  final double angle; // For linear gradients

  const Gradient({
    required this.colors,
    required this.stops,
    this.type = GradientType.linear,
    this.angle = 0,
  });
}

enum GradientType { linear, radial }

/// Stroke (border)
class Stroke implements Component {
  final Color color;
  final double width;
  final StrokePosition position;

  const Stroke({
    required this.color,
    required this.width,
    this.position = StrokePosition.inside,
  });
}

enum StrokePosition { inside, center, outside }

/// Corner radius
class CornerRadius implements Component {
  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;

  const CornerRadius({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  factory CornerRadius.all(double radius) => CornerRadius(
        topLeft: radius,
        topRight: radius,
        bottomRight: radius,
        bottomLeft: radius,
      );

  factory CornerRadius.zero() => const CornerRadius(
        topLeft: 0,
        topRight: 0,
        bottomRight: 0,
        bottomLeft: 0,
      );

  BorderRadius toBorderRadius() => BorderRadius.only(
        topLeft: Radius.circular(topLeft),
        topRight: Radius.circular(topRight),
        bottomRight: Radius.circular(bottomRight),
        bottomLeft: Radius.circular(bottomLeft),
      );
}

/// Opacity (0.0 - 1.0)
class Opacity implements Component {
  final double value;

  const Opacity(this.value);
}

/// Visibility
class Visibility implements Component {
  final bool isVisible;

  const Visibility(this.isVisible);
}

/// Shadow effects
class Shadows implements Component {
  final List<Shadow> shadows;

  const Shadows(this.shadows);
}

class Shadow {
  final Color color;
  final double offsetX;
  final double offsetY;
  final double blur;
  final double spread;
  final bool inner;

  const Shadow({
    required this.color,
    this.offsetX = 0,
    this.offsetY = 4,
    this.blur = 8,
    this.spread = 0,
    this.inner = false,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// TEXT COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Text content and styling
class TextContent implements Component {
  String text;
  final TextStyle? style;
  final TextAlign align;
  final TextOverflow overflow;

  TextContent({
    required this.text,
    this.style,
    this.align = TextAlign.left,
    this.overflow = TextOverflow.clip,
  });
}

enum TextAlign { left, center, right, justify }
enum TextOverflow { clip, ellipsis, visible }

// Re-export TextStyle from world.dart
export '../core/world.dart' show TextStyle, FontWeight;

// ═══════════════════════════════════════════════════════════════════════════
// HIERARCHY COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Parent-child relationship
class Hierarchy implements Component {
  Entity? parent;
  int childIndex;

  Hierarchy({this.parent, this.childIndex = 0});

  Hierarchy copy() => Hierarchy(parent: parent, childIndex: childIndex);
}

/// Metadata: name/label
class Name implements Component {
  String value;

  Name(this.value);
}

// ═══════════════════════════════════════════════════════════════════════════
// LAYOUT COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Auto-layout settings (like CSS flexbox)
class AutoLayout implements Component {
  final LayoutDirection direction;
  final double gap;
  final EdgePadding padding;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final bool wrap;

  const AutoLayout({
    required this.direction,
    this.gap = 0,
    this.padding = EdgePadding.zero,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.wrap = false,
  });
}

enum LayoutDirection { horizontal, vertical }

enum MainAxisAlignment { start, center, end, spaceBetween, spaceAround, spaceEvenly }

enum CrossAxisAlignment { start, center, end, stretch }

class EdgePadding {
  final double top;
  final double right;
  final double bottom;
  final double left;

  const EdgePadding({
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    this.left = 0,
  });

  factory EdgePadding.all(double value) =>
      EdgePadding(top: value, right: value, bottom: value, left: value);

  factory EdgePadding.symmetric({double horizontal = 0, double vertical = 0}) =>
      EdgePadding(top: vertical, right: horizontal, bottom: vertical, left: horizontal);

  static const EdgePadding zero = EdgePadding();

  double get horizontal => left + right;
  double get vertical => top + bottom;
}

// ═══════════════════════════════════════════════════════════════════════════
// FRAME COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Marks an entity as a frame/artboard (top-level design surface)
class FrameMarker implements Component {
  /// Position on the infinite canvas
  double canvasX;
  double canvasY;

  FrameMarker({
    required this.canvasX,
    required this.canvasY,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPONENT SYSTEM
// ═══════════════════════════════════════════════════════════════════════════

/// Marks an entity as a component definition (reusable template)
class ComponentDef implements Component {
  final String name;
  /// Root entity of this component's tree
  final Entity rootEntity;
  /// Exposed properties that can be overridden
  final Set<String> exposedProps;

  ComponentDef({
    required this.name,
    required this.rootEntity,
    this.exposedProps = const {},
  });
}

/// References a component definition with overrides
class Instance implements Component {
  /// The component definition entity
  final Entity componentId;

  /// Overrides: path -> value
  /// Path format: "entityId.property" or "entityId.property.subprop"
  final Map<String, dynamic> overrides;

  Instance({
    required this.componentId,
    this.overrides = const {},
  });

  /// Get override for a property path
  T? getOverride<T>(String path) => overrides[path] as T?;

  /// Create copy with additional override
  Instance withOverride(String path, dynamic value) {
    return Instance(
      componentId: componentId,
      overrides: {...overrides, path: value},
    );
  }
}
