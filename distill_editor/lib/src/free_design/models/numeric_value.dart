/// A numeric value that can be either a fixed value or a token reference.
///
/// Mirrors the [ColorValue] pattern used for colors. This enables spacing,
/// padding, radius, and other numeric properties to reference design tokens.
///
/// Example usage:
/// ```dart
/// final gap = FixedNumeric(16.0);         // Raw value
/// final gap = TokenNumeric('spacing.md'); // Token reference
/// ```
sealed class NumericValue {
  const NumericValue();

  factory NumericValue.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('value')) {
      return FixedNumeric((json['value'] as num).toDouble());
    } else if (json.containsKey('tokenRef')) {
      return TokenNumeric(json['tokenRef'] as String);
    }
    throw ArgumentError('Unknown numeric format: $json');
  }

  Map<String, dynamic> toJson();

  /// Get the fixed value if this is a [FixedNumeric], otherwise return [fallback].
  ///
  /// Use this for UI calculations that need a concrete value before token resolution.
  /// For actual rendering, use [TokenResolver.resolveNumeric] instead.
  double toDouble({double fallback = 0.0}) {
    return switch (this) {
      FixedNumeric(:final value) => value,
      TokenNumeric() => fallback,
    };
  }
}

/// Fixed numeric value (concrete double).
class FixedNumeric extends NumericValue {
  final double value;

  const FixedNumeric(this.value);

  @override
  Map<String, dynamic> toJson() => {'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FixedNumeric && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FixedNumeric($value)';
}

/// Token reference numeric (resolved at compile time).
///
/// The [tokenRef] is a dot-notation path like 'spacing.md' or 'radius.lg'.
class TokenNumeric extends NumericValue {
  final String tokenRef;

  const TokenNumeric(this.tokenRef);

  @override
  Map<String, dynamic> toJson() => {'tokenRef': tokenRef};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenNumeric && tokenRef == other.tokenRef;

  @override
  int get hashCode => tokenRef.hashCode;

  @override
  String toString() => 'TokenNumeric($tokenRef)';
}
