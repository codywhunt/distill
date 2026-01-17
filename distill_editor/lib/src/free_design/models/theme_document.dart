import 'token_schema.dart';

/// A design theme containing token definitions.
///
/// Stored alongside EditorDocument. For MVP, embedded directly in the document.
///
/// ## Usage
///
/// ```dart
/// final theme = ThemeDocument(
///   id: 'brand-v1',
///   name: 'Brand Theme',
///   tokens: TokenSchema(
///     color: {'primary': '#007AFF'},
///     spacing: {'md': 16},
///   ),
/// );
/// ```
class ThemeDocument {
  /// Unique identifier for this theme.
  final String id;

  /// Human-readable theme name.
  final String name;

  /// Token definitions for this theme.
  final TokenSchema tokens;

  const ThemeDocument({
    required this.id,
    required this.name,
    required this.tokens,
  });

  factory ThemeDocument.fromJson(Map<String, dynamic> json) {
    return ThemeDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      tokens: TokenSchema.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tokens': tokens.toJson(),
      };

  ThemeDocument copyWith({
    String? id,
    String? name,
    TokenSchema? tokens,
  }) {
    return ThemeDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      tokens: tokens ?? this.tokens,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeDocument &&
          id == other.id &&
          name == other.name &&
          tokens == other.tokens;

  @override
  int get hashCode => Object.hash(id, name, tokens);

  @override
  String toString() => 'ThemeDocument(id: $id, name: $name)';
}
