/// Node types for the Free Design Editor IR.
///
/// Each type corresponds to a specific kind of UI element that can be
/// placed on the canvas.
enum NodeType {
  /// Box container with optional children and auto-layout.
  container,

  /// Text content with styling.
  text,

  /// Image asset reference.
  image,

  /// Icon from an icon set.
  icon,

  /// Flexible space (Expanded/Spacer in Flutter).
  spacer,

  /// Component instance - references a ComponentDef.
  instance,

  /// Slot placeholder within a component definition.
  slot;

  /// Parse from JSON string value.
  static NodeType fromJson(String value) {
    return NodeType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown NodeType: $value'),
    );
  }

  /// Serialize to JSON string value.
  String toJson() => name;
}
