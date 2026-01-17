import 'package:flutter/material.dart';

/// Represents a stroke/border value with color and width.
///
/// This is a pure data class that can represent any stroke configuration.
/// Works with numeric values only (no expressions/theme constants).
class StrokeValue {
  /// The stroke color (null means no stroke).
  final Color? color;

  /// The stroke width in pixels.
  final double width;

  const StrokeValue({
    this.color,
    this.width = 1.0,
  });

  /// Creates a StrokeValue with no stroke.
  const StrokeValue.none()
      : color = null,
        width = 0.0;

  /// Creates a StrokeValue with a color and width.
  const StrokeValue.solid({
    required Color color,
    double width = 1.0,
  })  : color = color,
        width = width;

  /// Whether this stroke is empty (no color or zero width).
  bool get isEmpty => color == null || width == 0;

  /// Creates a StrokeValue from a JSON map or dynamic value.
  factory StrokeValue.fromJson(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const StrokeValue.none();
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

    final width = (json['width'] as num?)?.toDouble() ?? 1.0;

    if (color == null || width == 0) {
      return const StrokeValue.none();
    }

    return StrokeValue.solid(color: color, width: width);
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
      'width': width,
      'position': 'inside', // Default to inside for now
    };
  }

  /// Creates a copy with the specified values changed.
  StrokeValue copyWith({
    Color? color,
    double? width,
  }) {
    return StrokeValue(
      color: color ?? this.color,
      width: width ?? this.width,
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
      other is StrokeValue && color == other.color && width == other.width;

  @override
  int get hashCode => Object.hash(color, width);
}
