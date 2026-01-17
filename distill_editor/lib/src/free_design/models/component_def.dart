import '../utils/collection_equality.dart';

/// A reusable component definition.
///
/// Components define a reusable tree structure that can be instantiated
/// multiple times via [InstanceProps].
class ComponentDef {
  /// Unique identifier for this component.
  final String id;

  /// Human-readable name for the component.
  final String name;

  /// Optional description of the component.
  final String? description;

  /// Root node ID for this component's tree.
  /// The node and its children should exist in the document's nodes map.
  final String rootNodeId;

  /// Properties that can be overridden on instances.
  /// Maps property name to default value.
  final Map<String, dynamic> exposedProps;

  /// When this component was created.
  final DateTime createdAt;

  /// When this component was last modified.
  final DateTime updatedAt;

  const ComponentDef({
    required this.id,
    required this.name,
    this.description,
    required this.rootNodeId,
    this.exposedProps = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy with modified fields.
  ComponentDef copyWith({
    String? id,
    String? name,
    String? description,
    String? rootNodeId,
    Map<String, dynamic>? exposedProps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComponentDef(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rootNodeId: rootNodeId ?? this.rootNodeId,
      exposedProps: exposedProps ?? this.exposedProps,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create a ComponentDef from JSON.
  factory ComponentDef.fromJson(Map<String, dynamic> json) {
    return ComponentDef(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      rootNodeId: json['rootNodeId'] as String,
      exposedProps:
          (json['exposedProps'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'rootNodeId': rootNodeId,
        if (exposedProps.isNotEmpty) 'exposedProps': exposedProps,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComponentDef &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          rootNodeId == other.rootNodeId &&
          mapEquals(exposedProps, other.exposedProps) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        rootNodeId,
        Object.hashAll(exposedProps.entries),
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'ComponentDef(id: $id, name: $name)';
}
