import 'package:collection/collection.dart';

import '../utils/collection_equality.dart';
import 'component_param.dart';

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

  /// Typed parameters exposed by this component (v2).
  ///
  /// Each parameter has a key, type, default value, and binding to a node field.
  /// Instances can override parameter values via [InstanceProps.paramOverrides].
  final List<ComponentParamDef> params;

  /// Legacy property overrides (deprecated, use [params] instead).
  /// Maps property name to default value.
  @Deprecated('Use params instead for typed parameter definitions')
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
    this.params = const [],
    // ignore: deprecated_member_use_from_same_package
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
    List<ComponentParamDef>? params,
    @Deprecated('Use params instead') Map<String, dynamic>? exposedProps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComponentDef(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rootNodeId: rootNodeId ?? this.rootNodeId,
      params: params ?? this.params,
      // ignore: deprecated_member_use_from_same_package
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
      params: (json['params'] as List<dynamic>?)
              ?.map((e) => ComponentParamDef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      // ignore: deprecated_member_use_from_same_package
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
        if (params.isNotEmpty) 'params': params.map((p) => p.toJson()).toList(),
        // ignore: deprecated_member_use_from_same_package
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
          const ListEquality<ComponentParamDef>().equals(params, other.params) &&
          // ignore: deprecated_member_use_from_same_package
          mapEquals(exposedProps, other.exposedProps) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        rootNodeId,
        Object.hashAll(params),
        // ignore: deprecated_member_use_from_same_package
        Object.hashAll(exposedProps.entries),
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'ComponentDef(id: $id, name: $name)';
}
