import 'dart:ui';

import 'numeric_value.dart';

/// Layout properties for a node.
///
/// Controls positioning, sizing, and auto-layout behavior.
class NodeLayout {
  /// How this node is positioned within its parent.
  final PositionMode position;

  /// How this node's size is determined.
  final SizeMode size;

  /// Auto-layout configuration (null if not an auto-layout container).
  final AutoLayout? autoLayout;

  /// Constraints on the node's size.
  final LayoutConstraints? constraints;

  const NodeLayout({
    this.position = const PositionModeAuto(),
    this.size = const SizeMode.hug(),
    this.autoLayout,
    this.constraints,
  });

  NodeLayout copyWith({
    PositionMode? position,
    SizeMode? size,
    AutoLayout? autoLayout,
    LayoutConstraints? constraints,
  }) {
    return NodeLayout(
      position: position ?? this.position,
      size: size ?? this.size,
      autoLayout: autoLayout ?? this.autoLayout,
      constraints: constraints ?? this.constraints,
    );
  }

  factory NodeLayout.fromJson(Map<String, dynamic> json) {
    return NodeLayout(
      position: json['position'] != null
          ? PositionMode.fromJson(json['position'] as Map<String, dynamic>)
          : const PositionModeAuto(),
      size: json['size'] != null
          ? SizeMode.fromJson(json['size'] as Map<String, dynamic>)
          : const SizeMode.hug(),
      autoLayout: json['autoLayout'] != null
          ? AutoLayout.fromJson(json['autoLayout'] as Map<String, dynamic>)
          : null,
      constraints: json['constraints'] != null
          ? LayoutConstraints.fromJson(
              json['constraints'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'position': position.toJson(),
      'size': size.toJson(),
      if (autoLayout != null) 'autoLayout': autoLayout!.toJson(),
      if (constraints != null) 'constraints': constraints!.toJson(),
    };
  }

  /// Convenience getter for x position (null if auto-positioned).
  double? get x => switch (position) {
        PositionModeAbsolute(:final x) => x,
        _ => null,
      };

  /// Convenience getter for y position (null if auto-positioned).
  double? get y => switch (position) {
        PositionModeAbsolute(:final y) => y,
        _ => null,
      };

  /// Whether this node uses absolute/positioned layout (vs auto-layout).
  bool get isPositioned => position is PositionModeAbsolute;

  /// Remap any node ID references in this layout.
  ///
  /// Currently a no-op, but provides a hook for future fields that
  /// may contain node ID references (e.g., constraint anchors).
  NodeLayout remapIds(Map<String, String> idMap) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeLayout &&
          position == other.position &&
          size == other.size &&
          autoLayout == other.autoLayout &&
          constraints == other.constraints;

  @override
  int get hashCode =>
      Object.hash(position, size, autoLayout, constraints);
}

// =============================================================================
// PositionMode
// =============================================================================

/// How a node is positioned within its parent.
///
/// Serializes as:
/// - Auto: `{ "mode": "auto" }`
/// - Absolute: `{ "mode": "absolute", "x": 100, "y": 200 }`
///
/// This allows patching via paths like `/layout/position/x`.
sealed class PositionMode {
  const PositionMode();

  factory PositionMode.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'] as String;
    return switch (mode) {
      'auto' => const PositionModeAuto(),
      'absolute' => PositionModeAbsolute(
          // Accept both x/y and left/top for robustness with LLM output
          x: ((json['x'] ?? json['left']) as num?)?.toDouble() ?? 0,
          y: ((json['y'] ?? json['top']) as num?)?.toDouble() ?? 0,
        ),
      _ => throw ArgumentError('Unknown position mode: $mode'),
    };
  }

  Map<String, dynamic> toJson();
}

/// Position determined by auto-layout.
class PositionModeAuto extends PositionMode {
  const PositionModeAuto();

  @override
  Map<String, dynamic> toJson() => {'mode': 'auto'};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PositionModeAuto;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Absolute position relative to parent's top-left.
class PositionModeAbsolute extends PositionMode {
  final double x;
  final double y;

  const PositionModeAbsolute({required this.x, required this.y});

  Offset get offset => Offset(x, y);

  @override
  Map<String, dynamic> toJson() => {'mode': 'absolute', 'x': x, 'y': y};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionModeAbsolute && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

// =============================================================================
// AxisSize
// =============================================================================

/// Size mode for a single axis (width or height).
sealed class AxisSize {
  const AxisSize();

  const factory AxisSize.hug() = AxisSizeHug;
  const factory AxisSize.fill() = AxisSizeFill;
  const factory AxisSize.fixed(double value) = AxisSizeFixed;

  factory AxisSize.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'] as String;
    return switch (mode) {
      'hug' => const AxisSizeHug(),
      'fill' => const AxisSizeFill(),
      'fixed' => AxisSizeFixed((json['value'] as num).toDouble()),
      _ => throw ArgumentError('Unknown axis size mode: $mode'),
    };
  }

  Map<String, dynamic> toJson();
}

class AxisSizeHug extends AxisSize {
  const AxisSizeHug();

  @override
  Map<String, dynamic> toJson() => {'mode': 'hug'};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AxisSizeHug;

  @override
  int get hashCode => 'hug'.hashCode;
}

class AxisSizeFill extends AxisSize {
  const AxisSizeFill();

  @override
  Map<String, dynamic> toJson() => {'mode': 'fill'};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AxisSizeFill;

  @override
  int get hashCode => 'fill'.hashCode;
}

class AxisSizeFixed extends AxisSize {
  final double value;

  const AxisSizeFixed(this.value);

  @override
  Map<String, dynamic> toJson() => {'mode': 'fixed', 'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AxisSizeFixed && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

// =============================================================================
// SizeMode
// =============================================================================

/// How a node's size is determined for both axes.
class SizeMode {
  final AxisSize width;
  final AxisSize height;

  const SizeMode({
    required this.width,
    required this.height,
  });

  /// Convenience constructor: both axes hug content.
  const SizeMode.hug()
      : width = const AxisSizeHug(),
        height = const AxisSizeHug();

  /// Convenience constructor: both axes fill available space.
  const SizeMode.fill()
      : width = const AxisSizeFill(),
        height = const AxisSizeFill();

  /// Convenience factory: both axes fixed to specific sizes.
  factory SizeMode.fixed(double width, double height) {
    return SizeMode(
      width: AxisSizeFixed(width),
      height: AxisSizeFixed(height),
    );
  }

  SizeMode copyWith({AxisSize? width, AxisSize? height}) {
    return SizeMode(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  factory SizeMode.fromJson(Map<String, dynamic> json) {
    return SizeMode(
      width: json['width'] != null
          ? AxisSize.fromJson(json['width'] as Map<String, dynamic>)
          : const AxisSizeHug(),
      height: json['height'] != null
          ? AxisSize.fromJson(json['height'] as Map<String, dynamic>)
          : const AxisSizeHug(),
    );
  }

  /// Legacy format migration helper.
  ///
  /// Handles old format: `{'mode': 'fixed', 'width': 100, 'height': 50}`
  /// New format: `{'width': {'mode': 'fixed', 'value': 100}, 'height': {'mode': 'hug'}}`
  static SizeMode fromLegacyJson(Map<String, dynamic> json) {
    // Check if this is old format (has 'mode' key at root level)
    if (json.containsKey('mode')) {
      final mode = json['mode'] as String;
      switch (mode) {
        case 'hug':
          return const SizeMode.hug();
        case 'fill':
          return const SizeMode.fill();
        case 'fixed':
          final width = (json['width'] as num).toDouble();
          final height = (json['height'] as num).toDouble();
          return SizeMode.fixed(width, height);
        default:
          throw ArgumentError('Unknown legacy size mode: $mode');
      }
    }
    // Use new format
    return SizeMode.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
        'width': width.toJson(),
        'height': height.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeMode && width == other.width && height == other.height;

  @override
  int get hashCode => Object.hash(width, height);
}

// =============================================================================
// AutoLayout
// =============================================================================

/// Auto-layout configuration for container nodes.
class AutoLayout {
  final LayoutDirection direction;
  final MainAxisAlignment mainAlign;
  final CrossAxisAlignment crossAlign;

  /// Gap between children. Can be a fixed value or token reference.
  /// Null means no gap (0).
  final NumericValue? gap;

  /// Padding around children. Supports token references per edge.
  final TokenEdgePadding padding;

  const AutoLayout({
    this.direction = LayoutDirection.vertical,
    this.mainAlign = MainAxisAlignment.start,
    this.crossAlign = CrossAxisAlignment.start,
    this.gap,
    this.padding = TokenEdgePadding.zero,
  });

  AutoLayout copyWith({
    LayoutDirection? direction,
    MainAxisAlignment? mainAlign,
    CrossAxisAlignment? crossAlign,
    NumericValue? gap,
    TokenEdgePadding? padding,
  }) {
    return AutoLayout(
      direction: direction ?? this.direction,
      mainAlign: mainAlign ?? this.mainAlign,
      crossAlign: crossAlign ?? this.crossAlign,
      gap: gap ?? this.gap,
      padding: padding ?? this.padding,
    );
  }

  /// Parse from JSON with legacy format support.
  ///
  /// Handles legacy format where gap is a raw number and padding uses
  /// raw numbers per edge.
  factory AutoLayout.fromJson(Map<String, dynamic> json) {
    // Handle gap: legacy (raw number) or new (NumericValue JSON)
    final gapValue = json['gap'];
    NumericValue? gap;
    if (gapValue is num) {
      // Legacy: { "gap": 16 }
      gap = gapValue > 0 ? FixedNumeric(gapValue.toDouble()) : null;
    } else if (gapValue is Map<String, dynamic>) {
      // New: { "gap": { "value": 16 } } or { "gap": { "tokenRef": "spacing.md" } }
      gap = NumericValue.fromJson(gapValue);
    }

    // Handle padding: legacy (raw EdgePadding) or new (TokenEdgePadding)
    final padJson = json['padding'];
    TokenEdgePadding padding;
    if (padJson is Map<String, dynamic>) {
      // TokenEdgePadding.fromJson handles both legacy and new formats
      padding = TokenEdgePadding.fromJson(padJson);
    } else {
      padding = TokenEdgePadding.zero;
    }

    return AutoLayout(
      direction:
          LayoutDirection.fromJson(json['direction'] as String? ?? 'vertical'),
      mainAlign:
          MainAxisAlignment.fromJson(json['mainAlign'] as String? ?? 'start'),
      crossAlign:
          CrossAxisAlignment.fromJson(json['crossAlign'] as String? ?? 'start'),
      gap: gap,
      padding: padding,
    );
  }

  Map<String, dynamic> toJson() => {
        'direction': direction.toJson(),
        'mainAlign': mainAlign.toJson(),
        'crossAlign': crossAlign.toJson(),
        if (gap != null) 'gap': gap!.toJson(),
        'padding': padding.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoLayout &&
          direction == other.direction &&
          mainAlign == other.mainAlign &&
          crossAlign == other.crossAlign &&
          gap == other.gap &&
          padding == other.padding;

  @override
  int get hashCode =>
      Object.hash(direction, mainAlign, crossAlign, gap, padding);
}

/// Layout direction for auto-layout containers.
enum LayoutDirection {
  horizontal,
  vertical;

  static LayoutDirection fromJson(String value) {
    return LayoutDirection.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LayoutDirection.vertical,
    );
  }

  String toJson() => name;
}

/// Main axis alignment.
enum MainAxisAlignment {
  start,
  center,
  end,
  spaceBetween,
  spaceAround,
  spaceEvenly;

  static MainAxisAlignment fromJson(String value) {
    return MainAxisAlignment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MainAxisAlignment.start,
    );
  }

  String toJson() => name;
}

/// Cross axis alignment.
enum CrossAxisAlignment {
  start,
  center,
  end,
  stretch;

  static CrossAxisAlignment fromJson(String value) {
    return CrossAxisAlignment.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CrossAxisAlignment.start,
    );
  }

  String toJson() => name;
}

/// Edge padding (like EdgeInsets but serializable).
///
/// This is the legacy padding class with raw double values.
/// See [TokenEdgePadding] for token-enabled padding.
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

  const EdgePadding.all(double value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  const EdgePadding.symmetric({double horizontal = 0, double vertical = 0})
      : top = vertical,
        right = horizontal,
        bottom = vertical,
        left = horizontal;

  static const EdgePadding zero = EdgePadding();

  factory EdgePadding.fromJson(Map<String, dynamic> json) {
    return EdgePadding(
      top: (json['top'] as num?)?.toDouble() ?? 0,
      right: (json['right'] as num?)?.toDouble() ?? 0,
      bottom: (json['bottom'] as num?)?.toDouble() ?? 0,
      left: (json['left'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'top': top,
        'right': right,
        'bottom': bottom,
        'left': left,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgePadding &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom &&
          left == other.left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// Edge padding with token support.
///
/// Each edge can be either a fixed value or a token reference.
/// Used by [AutoLayout] for token-aware padding.
///
/// Example:
/// ```dart
/// // All edges use same token
/// TokenEdgePadding.all(TokenNumeric('spacing.md'))
///
/// // Mixed fixed and token values
/// TokenEdgePadding(
///   top: FixedNumeric(16),
///   right: TokenNumeric('spacing.sm'),
///   bottom: FixedNumeric(16),
///   left: TokenNumeric('spacing.sm'),
/// )
/// ```
class TokenEdgePadding {
  final NumericValue top;
  final NumericValue right;
  final NumericValue bottom;
  final NumericValue left;

  const TokenEdgePadding({
    this.top = const FixedNumeric(0),
    this.right = const FixedNumeric(0),
    this.bottom = const FixedNumeric(0),
    this.left = const FixedNumeric(0),
  });

  const TokenEdgePadding.all(NumericValue value)
      : top = value,
        right = value,
        bottom = value,
        left = value;

  /// Convenience constructor for uniform fixed padding.
  TokenEdgePadding.allFixed(double value)
      : top = FixedNumeric(value),
        right = FixedNumeric(value),
        bottom = FixedNumeric(value),
        left = FixedNumeric(value);

  /// Convenience constructor for symmetric fixed padding.
  TokenEdgePadding.symmetric({double horizontal = 0, double vertical = 0})
      : top = FixedNumeric(vertical),
        right = FixedNumeric(horizontal),
        bottom = FixedNumeric(vertical),
        left = FixedNumeric(horizontal);

  static const TokenEdgePadding zero = TokenEdgePadding();

  /// Convert from legacy [EdgePadding].
  factory TokenEdgePadding.fromEdgePadding(EdgePadding old) => TokenEdgePadding(
        top: FixedNumeric(old.top),
        right: FixedNumeric(old.right),
        bottom: FixedNumeric(old.bottom),
        left: FixedNumeric(old.left),
      );

  /// Parse from JSON with legacy format support.
  ///
  /// Handles both legacy format `{ "top": 8, ... }` and
  /// new format `{ "top": { "value": 8 }, ... }`.
  factory TokenEdgePadding.fromJson(Map<String, dynamic> json) {
    return TokenEdgePadding(
      top: _parseEdgeValue(json['top']),
      right: _parseEdgeValue(json['right']),
      bottom: _parseEdgeValue(json['bottom']),
      left: _parseEdgeValue(json['left']),
    );
  }

  static NumericValue _parseEdgeValue(dynamic value) {
    if (value == null) return const FixedNumeric(0);
    if (value is num) {
      // Legacy format: raw number
      return FixedNumeric(value.toDouble());
    }
    if (value is Map<String, dynamic>) {
      // New format: NumericValue JSON
      return NumericValue.fromJson(value);
    }
    return const FixedNumeric(0);
  }

  Map<String, dynamic> toJson() => {
        'top': top.toJson(),
        'right': right.toJson(),
        'bottom': bottom.toJson(),
        'left': left.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenEdgePadding &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom &&
          left == other.left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);

  @override
  String toString() => 'TokenEdgePadding(top: $top, right: $right, '
      'bottom: $bottom, left: $left)';
}

// =============================================================================
// LayoutConstraints
// =============================================================================

/// Constraints on a node's size.
class LayoutConstraints {
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  const LayoutConstraints({
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  factory LayoutConstraints.fromJson(Map<String, dynamic> json) {
    return LayoutConstraints(
      minWidth: (json['minWidth'] as num?)?.toDouble(),
      maxWidth: (json['maxWidth'] as num?)?.toDouble(),
      minHeight: (json['minHeight'] as num?)?.toDouble(),
      maxHeight: (json['maxHeight'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (minWidth != null) 'minWidth': minWidth,
        if (maxWidth != null) 'maxWidth': maxWidth,
        if (minHeight != null) 'minHeight': minHeight,
        if (maxHeight != null) 'maxHeight': maxHeight,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutConstraints &&
          minWidth == other.minWidth &&
          maxWidth == other.maxWidth &&
          minHeight == other.minHeight &&
          maxHeight == other.maxHeight;

  @override
  int get hashCode =>
      Object.hash(minWidth, maxWidth, minHeight, maxHeight);
}
