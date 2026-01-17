import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/default_theme.dart';
import '../models/numeric_value.dart';
import '../models/token_schema.dart';

/// Resolves design token references to concrete values.
///
/// Uses a [TokenSchema] to resolve dot-notation token paths like
/// `color.primary`, `spacing.md`, or `color.text.secondary`.
///
/// ## Token Format
///
/// Tokens follow a dot-notation path format:
/// - `color.primary` → Color
/// - `color.text.secondary` → Color (nested)
/// - `spacing.md` → double
/// - `radius.lg` → double
///
/// ## Usage
///
/// ```dart
/// final resolver = TokenResolver(defaultTokenSchema);
/// final color = resolver.resolveColor('color.primary');
/// final gap = resolver.resolveNumeric(TokenNumeric('spacing.md'));
/// ```
class TokenResolver {
  /// The token schema containing all token definitions.
  final TokenSchema schema;

  const TokenResolver(this.schema);

  /// Create resolver from a TokenSchema.
  factory TokenResolver.fromSchema(TokenSchema schema) => TokenResolver(schema);

  /// Create with default tokens from [defaultTokenSchema].
  factory TokenResolver.defaults() => TokenResolver(defaultTokenSchema);

  /// An empty resolver with no tokens registered.
  static const TokenResolver emptyResolver = TokenResolver(TokenSchema());

  /// Create an empty resolver (no tokens registered).
  factory TokenResolver.empty() => emptyResolver;

  /// Resolve a color token path to a Color.
  ///
  /// Path format: 'color.primary' or 'color.text.secondary'
  /// Returns null if the token is not found or value is not a hex color.
  Color? resolveColor(String tokenRef) {
    final value = schema.resolve(tokenRef);
    if (value is String && value.startsWith('#')) {
      return _parseHex(value);
    }
    return null;
  }

  /// Resolve a spacing token path to double.
  ///
  /// Returns null if the token is not found.
  double? resolveSpacing(String tokenRef) {
    final value = schema.resolve(tokenRef);
    return value is num ? value.toDouble() : null;
  }

  /// Resolve a radius token path to double.
  ///
  /// Returns null if the token is not found.
  double? resolveRadius(String tokenRef) {
    final value = schema.resolve(tokenRef);
    return value is num ? value.toDouble() : null;
  }

  /// Resolve NumericValue to concrete double.
  ///
  /// For [FixedNumeric], returns the value directly.
  /// For [TokenNumeric], resolves through the schema.
  /// Logs a warning and returns [fallback] for unresolved tokens.
  double resolveNumeric(NumericValue value, {double fallback = 0.0}) {
    return switch (value) {
      FixedNumeric(:final value) => value,
      TokenNumeric(:final tokenRef) => _resolveTokenOrWarn(tokenRef, fallback),
    };
  }

  double _resolveTokenOrWarn(String tokenRef, double fallback) {
    // Try spacing first, then radius (both are numeric)
    final resolved = resolveSpacing(tokenRef) ?? resolveRadius(tokenRef);
    if (resolved == null) {
      debugPrint(
          'TokenResolver: Unresolved token "$tokenRef", using fallback $fallback');
      return fallback;
    }
    return resolved;
  }

  /// Check if a string looks like a token reference.
  ///
  /// Token refs are strings that start with known category prefixes.
  static bool isTokenRef(String value) {
    return value.startsWith('color.') ||
        value.startsWith('spacing.') ||
        value.startsWith('radius.') ||
        value.startsWith('typography.');
  }

  Color? _parseHex(String hex) {
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
  String toString() => 'TokenResolver(schema: $schema)';
}
