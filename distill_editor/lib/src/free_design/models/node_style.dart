import 'dart:ui';

import '../utils/collection_equality.dart';
import 'numeric_value.dart';

/// Visual styling properties for a node.
class NodeStyle {
  /// Background fill.
  final Fill? fill;

  /// Border stroke.
  final Stroke? stroke;

  /// Corner radius.
  final CornerRadius? cornerRadius;

  /// Drop shadow.
  final Shadow? shadow;

  /// Opacity (0.0 - 1.0).
  final double opacity;

  /// Whether the node is visible.
  final bool visible;

  const NodeStyle({
    this.fill,
    this.stroke,
    this.cornerRadius,
    this.shadow,
    this.opacity = 1.0,
    this.visible = true,
  });

  NodeStyle copyWith({
    Fill? fill,
    Stroke? stroke,
    CornerRadius? cornerRadius,
    Shadow? shadow,
    double? opacity,
    bool? visible,
  }) {
    return NodeStyle(
      fill: fill ?? this.fill,
      stroke: stroke ?? this.stroke,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      shadow: shadow ?? this.shadow,
      opacity: opacity ?? this.opacity,
      visible: visible ?? this.visible,
    );
  }

  factory NodeStyle.fromJson(Map<String, dynamic> json) {
    return NodeStyle(
      fill: json['fill'] != null
          ? Fill.fromJson(json['fill'] as Map<String, dynamic>)
          : null,
      stroke: json['stroke'] != null
          ? Stroke.fromJson(json['stroke'] as Map<String, dynamic>)
          : null,
      cornerRadius: json['cornerRadius'] != null
          ? CornerRadius.fromJson(json['cornerRadius'] as Map<String, dynamic>)
          : null,
      shadow: json['shadow'] != null
          ? Shadow.fromJson(json['shadow'] as Map<String, dynamic>)
          : null,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      visible: json['visible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (fill != null) 'fill': fill!.toJson(),
        if (stroke != null) 'stroke': stroke!.toJson(),
        if (cornerRadius != null) 'cornerRadius': cornerRadius!.toJson(),
        if (shadow != null) 'shadow': shadow!.toJson(),
        'opacity': opacity,
        'visible': visible,
      };

  /// Remap any node ID references in this style.
  ///
  /// Currently a no-op, but provides a hook for future fields that
  /// may contain node ID references.
  NodeStyle remapIds(Map<String, String> idMap) => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeStyle &&
          fill == other.fill &&
          stroke == other.stroke &&
          cornerRadius == other.cornerRadius &&
          shadow == other.shadow &&
          opacity == other.opacity &&
          visible == other.visible;

  @override
  int get hashCode =>
      Object.hash(fill, stroke, cornerRadius, shadow, opacity, visible);
}

// =============================================================================
// Fill
// =============================================================================

/// Background fill for a node.
sealed class Fill {
  const Fill();

  factory Fill.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'solid' => SolidFill.fromJson(json),
      'gradient' => GradientFill.fromJson(json),
      'token' => TokenFill.fromJson(json),
      _ => throw ArgumentError('Unknown fill type: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

/// Solid color fill.
class SolidFill extends Fill {
  final ColorValue color;

  const SolidFill(this.color);

  factory SolidFill.fromJson(Map<String, dynamic> json) {
    return SolidFill(ColorValue.fromJson(json['color'] as Map<String, dynamic>));
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'solid',
        'color': color.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SolidFill && color == other.color;

  @override
  int get hashCode => color.hashCode;
}

/// Gradient fill.
class GradientFill extends Fill {
  final GradientType gradientType;
  final List<GradientStop> stops;
  final double angle; // For linear gradients, in degrees

  const GradientFill({
    required this.gradientType,
    required this.stops,
    this.angle = 0,
  });

  factory GradientFill.fromJson(Map<String, dynamic> json) {
    return GradientFill(
      gradientType: GradientType.fromJson(json['gradientType'] as String),
      stops: (json['stops'] as List)
          .map((s) => GradientStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      angle: (json['angle'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'gradient',
        'gradientType': gradientType.toJson(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'angle': angle,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradientFill &&
          gradientType == other.gradientType &&
          listEquals(stops, other.stops) &&
          angle == other.angle;

  @override
  int get hashCode => Object.hash(gradientType, Object.hashAll(stops), angle);
}

/// Token reference fill (resolved at compile time).
class TokenFill extends Fill {
  final String tokenRef;

  const TokenFill(this.tokenRef);

  factory TokenFill.fromJson(Map<String, dynamic> json) {
    return TokenFill(json['tokenRef'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'token',
        'tokenRef': tokenRef,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TokenFill && tokenRef == other.tokenRef;

  @override
  int get hashCode => tokenRef.hashCode;
}

enum GradientType {
  linear,
  radial;

  static GradientType fromJson(String value) {
    return GradientType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GradientType.linear,
    );
  }

  String toJson() => name;
}

class GradientStop {
  final double position; // 0.0 - 1.0
  final ColorValue color;

  const GradientStop({required this.position, required this.color});

  factory GradientStop.fromJson(Map<String, dynamic> json) {
    return GradientStop(
      position: (json['position'] as num).toDouble(),
      color: ColorValue.fromJson(json['color'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        'color': color.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradientStop &&
          position == other.position &&
          color == other.color;

  @override
  int get hashCode => Object.hash(position, color);
}

// =============================================================================
// Stroke
// =============================================================================

/// Border stroke for a node.
class Stroke {
  final ColorValue color;
  final double width;
  final StrokePosition position;

  const Stroke({
    required this.color,
    this.width = 1.0,
    this.position = StrokePosition.inside,
  });

  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      color: ColorValue.fromJson(json['color'] as Map<String, dynamic>),
      width: (json['width'] as num?)?.toDouble() ?? 1.0,
      position: StrokePosition.fromJson(json['position'] as String? ?? 'inside'),
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color.toJson(),
        'width': width,
        'position': position.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stroke &&
          color == other.color &&
          width == other.width &&
          position == other.position;

  @override
  int get hashCode => Object.hash(color, width, position);
}

enum StrokePosition {
  inside,
  center,
  outside;

  static StrokePosition fromJson(String value) {
    return StrokePosition.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StrokePosition.inside,
    );
  }

  String toJson() => name;
}

// =============================================================================
// CornerRadius
// =============================================================================

/// Corner radius for a node with token support.
///
/// Each corner can be either a fixed value or a token reference.
///
/// Example:
/// ```dart
/// // Uniform fixed radius
/// CornerRadius.circular(8)
///
/// // Uniform token radius
/// CornerRadius.allToken('radius.md')
///
/// // Per-corner with mixed values
/// CornerRadius(
///   topLeft: FixedNumeric(8),
///   topRight: TokenNumeric('radius.lg'),
///   bottomRight: TokenNumeric('radius.lg'),
///   bottomLeft: FixedNumeric(8),
/// )
/// ```
class CornerRadius {
  final NumericValue topLeft;
  final NumericValue topRight;
  final NumericValue bottomRight;
  final NumericValue bottomLeft;

  const CornerRadius({
    this.topLeft = const FixedNumeric(0),
    this.topRight = const FixedNumeric(0),
    this.bottomRight = const FixedNumeric(0),
    this.bottomLeft = const FixedNumeric(0),
  });

  const CornerRadius.all(NumericValue radius)
      : topLeft = radius,
        topRight = radius,
        bottomRight = radius,
        bottomLeft = radius;

  /// Convenience for uniform fixed radius (common case).
  CornerRadius.circular(double radius)
      : topLeft = FixedNumeric(radius),
        topRight = FixedNumeric(radius),
        bottomRight = FixedNumeric(radius),
        bottomLeft = FixedNumeric(radius);

  /// Convenience for uniform token radius.
  CornerRadius.allToken(String tokenRef)
      : topLeft = TokenNumeric(tokenRef),
        topRight = TokenNumeric(tokenRef),
        bottomRight = TokenNumeric(tokenRef),
        bottomLeft = TokenNumeric(tokenRef);

  /// Parse from JSON with legacy format support.
  ///
  /// Handles legacy format where values are raw numbers and
  /// new format where values are NumericValue JSON.
  factory CornerRadius.fromJson(Map<String, dynamic> json) {
    // Handle uniform shorthand: { "all": 8 } or { "all": { "tokenRef": "..." } }
    if (json.containsKey('all')) {
      final allValue = json['all'];
      if (allValue is num) {
        // Legacy: { "all": 8 }
        return CornerRadius.circular(allValue.toDouble());
      } else if (allValue is Map<String, dynamic>) {
        // New: { "all": { "tokenRef": "radius.md" } }
        return CornerRadius.all(NumericValue.fromJson(allValue));
      }
    }

    // Per-corner format
    return CornerRadius(
      topLeft: _parseCornerValue(json['topLeft']),
      topRight: _parseCornerValue(json['topRight']),
      bottomRight: _parseCornerValue(json['bottomRight']),
      bottomLeft: _parseCornerValue(json['bottomLeft']),
    );
  }

  static NumericValue _parseCornerValue(dynamic value) {
    if (value == null) return const FixedNumeric(0);
    if (value is num) {
      // Legacy: { "topLeft": 8 }
      return FixedNumeric(value.toDouble());
    }
    if (value is Map<String, dynamic>) {
      // New: { "topLeft": { "value": 8 } }
      return NumericValue.fromJson(value);
    }
    return const FixedNumeric(0);
  }

  Map<String, dynamic> toJson() {
    // Optimize for uniform radius
    if (topLeft == topRight &&
        topRight == bottomRight &&
        bottomRight == bottomLeft) {
      return {'all': topLeft.toJson()};
    }
    return {
      'topLeft': topLeft.toJson(),
      'topRight': topRight.toJson(),
      'bottomRight': bottomRight.toJson(),
      'bottomLeft': bottomLeft.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CornerRadius &&
          topLeft == other.topLeft &&
          topRight == other.topRight &&
          bottomRight == other.bottomRight &&
          bottomLeft == other.bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() => 'CornerRadius(topLeft: $topLeft, topRight: $topRight, '
      'bottomRight: $bottomRight, bottomLeft: $bottomLeft)';
}

// =============================================================================
// Shadow
// =============================================================================

/// Drop shadow for a node.
class Shadow {
  final ColorValue color;
  final double offsetX;
  final double offsetY;
  final double blur;
  final double spread;

  const Shadow({
    required this.color,
    this.offsetX = 0,
    this.offsetY = 4,
    this.blur = 8,
    this.spread = 0,
  });

  factory Shadow.fromJson(Map<String, dynamic> json) {
    return Shadow(
      color: ColorValue.fromJson(json['color'] as Map<String, dynamic>),
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 4,
      blur: (json['blur'] as num?)?.toDouble() ?? 8,
      spread: (json['spread'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color.toJson(),
        'offsetX': offsetX,
        'offsetY': offsetY,
        'blur': blur,
        'spread': spread,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Shadow &&
          color == other.color &&
          offsetX == other.offsetX &&
          offsetY == other.offsetY &&
          blur == other.blur &&
          spread == other.spread;

  @override
  int get hashCode => Object.hash(color, offsetX, offsetY, blur, spread);
}

// =============================================================================
// ColorValue
// =============================================================================

/// A color value (hex or token reference).
sealed class ColorValue {
  const ColorValue();

  factory ColorValue.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('hex')) {
      return HexColor(json['hex'] as String);
    } else if (json.containsKey('tokenRef')) {
      return TokenColor(json['tokenRef'] as String);
    }
    throw ArgumentError('Unknown color format: $json');
  }

  Map<String, dynamic> toJson();

  /// Convert to Flutter Color (only works for HexColor).
  Color? toColor();
}

/// Hex color value.
class HexColor extends ColorValue {
  final String hex;

  const HexColor(this.hex);

  @override
  Map<String, dynamic> toJson() => {'hex': hex};

  @override
  Color? toColor() {
    final cleanHex = hex.replaceFirst('#', '');
    final value = int.tryParse(cleanHex, radix: 16);
    if (value == null) return null;

    if (cleanHex.length == 6) {
      return Color(0xFF000000 | value);
    } else if (cleanHex.length == 8) {
      return Color(value);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HexColor && hex == other.hex;

  @override
  int get hashCode => hex.hashCode;
}

/// Token reference color (resolved at compile time).
class TokenColor extends ColorValue {
  final String tokenRef;

  const TokenColor(this.tokenRef);

  @override
  Map<String, dynamic> toJson() => {'tokenRef': tokenRef};

  @override
  Color? toColor() => null; // Must be resolved by TokenResolver

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenColor && tokenRef == other.tokenRef;

  @override
  int get hashCode => tokenRef.hashCode;
}
