import 'package:collection/collection.dart';

/// Type of a component parameter value.
enum ParamType {
  string,
  number,
  boolean,
  color,
  enumValue;

  static ParamType fromJson(String value) {
    return ParamType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ParamType.string,
    );
  }

  String toJson() => name;
}

/// Which bucket a parameter binding targets.
enum OverrideBucket {
  props,
  style,
  layout;

  static OverrideBucket fromJson(String value) {
    return OverrideBucket.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OverrideBucket.props,
    );
  }

  String toJson() => name;
}

/// Which field within a bucket the parameter affects.
enum ParamField {
  // Props fields
  text,
  icon,
  imageSrc,

  // Style fields
  fillColor,
  strokeColor,
  opacity,
  cornerRadius,

  // Layout fields
  width,
  height,
  paddingAll,
  paddingHorizontal,
  paddingVertical,
  gap;

  static ParamField fromJson(String value) {
    return ParamField.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ParamField.text,
    );
  }

  String toJson() => name;
}

/// Target tuple for keying resolved values by bucket and field.
typedef ParamTarget = ({OverrideBucket bucket, ParamField field});

/// Links a parameter to a specific node field.
class ParamBinding {
  /// References [Node.templateUid] to identify the target node.
  final String targetTemplateUid;

  /// Which bucket the field belongs to (props, style, layout).
  final OverrideBucket bucket;

  /// Which specific field within the bucket.
  final ParamField field;

  const ParamBinding({
    required this.targetTemplateUid,
    required this.bucket,
    required this.field,
  });

  factory ParamBinding.fromJson(Map<String, dynamic> json) {
    return ParamBinding(
      targetTemplateUid: json['targetTemplateUid'] as String,
      bucket: OverrideBucket.fromJson(json['bucket'] as String),
      field: ParamField.fromJson(json['field'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'targetTemplateUid': targetTemplateUid,
        'bucket': bucket.toJson(),
        'field': field.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParamBinding &&
          targetTemplateUid == other.targetTemplateUid &&
          bucket == other.bucket &&
          field == other.field;

  @override
  int get hashCode => Object.hash(targetTemplateUid, bucket, field);

  @override
  String toString() =>
      'ParamBinding(targetTemplateUid: $targetTemplateUid, bucket: $bucket, field: $field)';
}

/// Definition of a component parameter.
///
/// Parameters provide typed property controls for component instances,
/// allowing users to customize specific aspects of the component.
class ComponentParamDef {
  /// Unique key for this parameter (e.g., "label", "iconName").
  final String key;

  /// The data type of this parameter's value.
  final ParamType type;

  /// Default value used when no override is provided.
  final dynamic defaultValue;

  /// Optional group for organizing parameters in the UI (e.g., "Content", "Style").
  final String? group;

  /// Binding that links this parameter to a node field.
  final ParamBinding binding;

  /// Options for [ParamType.enumValue] parameters.
  final List<String>? enumOptions;

  const ComponentParamDef({
    required this.key,
    required this.type,
    required this.defaultValue,
    this.group,
    required this.binding,
    this.enumOptions,
  });

  ComponentParamDef copyWith({
    String? key,
    ParamType? type,
    dynamic defaultValue,
    String? group,
    ParamBinding? binding,
    List<String>? enumOptions,
  }) {
    return ComponentParamDef(
      key: key ?? this.key,
      type: type ?? this.type,
      defaultValue: defaultValue ?? this.defaultValue,
      group: group ?? this.group,
      binding: binding ?? this.binding,
      enumOptions: enumOptions ?? this.enumOptions,
    );
  }

  factory ComponentParamDef.fromJson(Map<String, dynamic> json) {
    return ComponentParamDef(
      key: json['key'] as String,
      type: ParamType.fromJson(json['type'] as String),
      defaultValue: json['defaultValue'],
      group: json['group'] as String?,
      binding: ParamBinding.fromJson(json['binding'] as Map<String, dynamic>),
      enumOptions: (json['enumOptions'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'type': type.toJson(),
        'defaultValue': defaultValue,
        if (group != null) 'group': group,
        'binding': binding.toJson(),
        if (enumOptions != null) 'enumOptions': enumOptions,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComponentParamDef &&
          key == other.key &&
          type == other.type &&
          defaultValue == other.defaultValue &&
          group == other.group &&
          binding == other.binding &&
          const ListEquality<String>().equals(enumOptions, other.enumOptions);

  @override
  int get hashCode => Object.hash(
        key,
        type,
        defaultValue,
        group,
        binding,
        enumOptions == null ? null : Object.hashAll(enumOptions!),
      );

  @override
  String toString() =>
      'ComponentParamDef(key: $key, type: $type, defaultValue: $defaultValue, group: $group)';
}
