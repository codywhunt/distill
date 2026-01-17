import 'package:flutter/material.dart';

/// Represents a shadow value with color, offsets, blur, and spread.
///
/// This is a pure data class that can represent any shadow configuration.
/// Works with numeric values only (no expressions/theme constants).
class ShadowValue {
  /// The shadow color (null means no shadow).
  final Color? color;

  /// The horizontal offset in pixels.
  final double offsetX;

  /// The vertical offset in pixels.
  final double offsetY;

  /// The blur radius in pixels.
  final double blur;

  /// The spread radius in pixels.
  final double spread;

  const ShadowValue({
    this.color,
    this.offsetX = 0.0,
    this.offsetY = 4.0,
    this.blur = 8.0,
    this.spread = 0.0,
  });

  /// Creates a ShadowValue with no shadow.
  const ShadowValue.none()
      : color = null,
        offsetX = 0.0,
        offsetY = 0.0,
        blur = 0.0,
        spread = 0.0;

  /// Creates a ShadowValue with a color and offsets.
  const ShadowValue.dropShadow({
    required Color color,
    double offsetX = 0.0,
    double offsetY = 4.0,
    double blur = 8.0,
    double spread = 0.0,
  })  : color = color,
        offsetX = offsetX,
        offsetY = offsetY,
        blur = blur,
        spread = spread;

  /// Whether this shadow is empty (no color or zero blur).
  bool get isEmpty => color == null || (blur == 0 && spread == 0);

  /// Creates a ShadowValue from a JSON map or dynamic value.
  factory ShadowValue.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const ShadowValue.none();
    }

    // Parse color from nested color object
    Color? color;
    if (json['color'] != null) {
      final colorMap = json['color'] as Map<String, dynamic>;
      if (colorMap.containsKey('hex')) {
        final hex = colorMap['hex'] as String;
        color = _parseColor(hex);
      }
    }

    final offsetX = (json['offsetX'] as num?)?.toDouble() ?? 0.0;
    final offsetY = (json['offsetY'] as num?)?.toDouble() ?? 4.0;
    final blur = (json['blur'] as num?)?.toDouble() ?? 8.0;
    final spread = (json['spread'] as num?)?.toDouble() ?? 0.0;

    if (color == null) {
      return const ShadowValue.none();
    }

    return ShadowValue.dropShadow(
      color: color,
      offsetX: offsetX,
      offsetY: offsetY,
      blur: blur,
      spread: spread,
    );
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    if (isEmpty) {
      return {};
    }

    return {
      'color': {
        'hex': _colorToHex(color!),
      },
      'offsetX': offsetX,
      'offsetY': offsetY,
      'blur': blur,
      'spread': spread,
    };
  }

  /// Creates a copy with the specified values changed.
  ShadowValue copyWith({
    Color? color,
    double? offsetX,
    double? offsetY,
    double? blur,
    double? spread,
  }) {
    return ShadowValue(
      color: color ?? this.color,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      blur: blur ?? this.blur,
      spread: spread ?? this.spread,
    );
  }

  static Color? _parseColor(String? colorString) {
    if (colorString == null) return null;
    try {
      final hex = colorString.replaceFirst('#', '');
      final value = int.parse(hex, radix: 16);
      if (hex.length == 6) {
        return Color(0xFF000000 | value);
      } else if (hex.length == 8) {
        return Color(value);
      }
    } catch (_) {}
    return null;
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShadowValue &&
          color == other.color &&
          offsetX == other.offsetX &&
          offsetY == other.offsetY &&
          blur == other.blur &&
          spread == other.spread;

  @override
  int get hashCode => Object.hash(color, offsetX, offsetY, blur, spread);
}
