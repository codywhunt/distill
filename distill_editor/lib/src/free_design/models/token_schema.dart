/// Token schema defining available design tokens.
///
/// Supports nested paths via dot notation: `color.text.secondary`
/// Values are stored as primitives (String for colors, num for sizes).
///
/// ## Path Resolution
///
/// ```dart
/// final schema = TokenSchema(
///   color: {
///     'primary': '#007AFF',
///     'text': {'primary': '#000', 'secondary': '#666'},
///   },
///   spacing: {'md': 16},
/// );
///
/// schema.resolve('color.primary');        // '#007AFF'
/// schema.resolve('color.text.secondary'); // '#666'
/// schema.resolve('spacing.md');           // 16
/// ```
class TokenSchema {
  /// Color tokens. Keys can be flat ('primary') or nested via maps.
  final Map<String, dynamic> color;

  /// Spacing tokens (padding, gap, margin). Values in logical pixels.
  final Map<String, num> spacing;

  /// Border radius tokens.
  final Map<String, num> radius;

  /// Typography presets (composite tokens).
  final Map<String, TypographyToken> typography;

  const TokenSchema({
    this.color = const {},
    this.spacing = const {},
    this.radius = const {},
    this.typography = const {},
  });

  /// Resolve a dot-notation path to its value.
  ///
  /// Returns null if path not found.
  ///
  /// Example: `resolve('color.text.secondary')` → `'#666666'`
  dynamic resolve(String path) {
    final parts = path.split('.');
    if (parts.isEmpty) return null;

    // Get the category map
    dynamic current = switch (parts[0]) {
      'color' => color,
      'spacing' => spacing,
      'radius' => radius,
      'typography' => typography,
      _ => null,
    };
    if (current == null) return null;

    // Walk the remaining path
    for (var i = 1; i < parts.length; i++) {
      if (current is Map) {
        current = current[parts[i]];
      } else {
        return null;
      }
    }
    return current;
  }

  factory TokenSchema.fromJson(Map<String, dynamic> json) {
    return TokenSchema(
      color: (json['color'] as Map<String, dynamic>?) ?? const {},
      spacing: (json['spacing'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num)),
          ) ??
          const {},
      radius: (json['radius'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num)),
          ) ??
          const {},
      typography: (json['typography'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, TypographyToken.fromJson(v as Map<String, dynamic>)),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'color': color,
        'spacing': spacing,
        'radius': radius,
        'typography': typography.map((k, v) => MapEntry(k, v.toJson())),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenSchema &&
          _deepEquals(color, other.color) &&
          _deepEquals(spacing, other.spacing) &&
          _deepEquals(radius, other.radius) &&
          _deepEquals(typography, other.typography);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(color.entries),
        Object.hashAll(spacing.entries),
        Object.hashAll(radius.entries),
        Object.hashAll(typography.entries),
      );

  bool _deepEquals(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    return a == b;
  }
}

/// Typography token with font properties.
///
/// Represents a reusable typography style that can be referenced by name.
class TypographyToken {
  final double size;
  final int weight;
  final double? lineHeight;
  final double? letterSpacing;

  const TypographyToken({
    required this.size,
    required this.weight,
    this.lineHeight,
    this.letterSpacing,
  });

  factory TypographyToken.fromJson(Map<String, dynamic> json) {
    return TypographyToken(
      size: (json['size'] as num).toDouble(),
      weight: (json['weight'] as num).toInt(),
      lineHeight: (json['lineHeight'] as num?)?.toDouble(),
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'weight': weight,
        if (lineHeight != null) 'lineHeight': lineHeight,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypographyToken &&
          size == other.size &&
          weight == other.weight &&
          lineHeight == other.lineHeight &&
          letterSpacing == other.letterSpacing;

  @override
  int get hashCode => Object.hash(size, weight, lineHeight, letterSpacing);
}
