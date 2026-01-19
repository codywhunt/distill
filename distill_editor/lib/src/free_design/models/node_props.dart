import '../utils/collection_equality.dart';
import 'node_type.dart';

/// Type-specific properties for nodes.
///
/// Each [NodeType] has a corresponding props class.
sealed class NodeProps {
  const NodeProps();

  factory NodeProps.fromJson(NodeType type, Map<String, dynamic> json) {
    return switch (type) {
      NodeType.container => ContainerProps.fromJson(json),
      NodeType.text => TextProps.fromJson(json),
      NodeType.image => ImageProps.fromJson(json),
      NodeType.icon => IconProps.fromJson(json),
      NodeType.spacer => SpacerProps.fromJson(json),
      NodeType.instance => InstanceProps.fromJson(json),
      NodeType.slot => SlotProps.fromJson(json),
    };
  }

  Map<String, dynamic> toJson();

  /// Remap any node ID references in these props.
  ///
  /// Default implementation returns self (no ID references).
  /// Override in subclasses that contain node ID references.
  NodeProps remapIds(Map<String, String> idMap) => this;
}

// =============================================================================
// ContainerProps
// =============================================================================

/// Properties for container nodes.
class ContainerProps extends NodeProps {
  /// Whether this container clips its children.
  final bool clipContent;

  /// Scroll direction if this container is scrollable.
  ///
  /// - `null`: Not scrollable (default)
  /// - `'vertical'`: Scrolls vertically
  /// - `'horizontal'`: Scrolls horizontally
  final String? scrollDirection;

  const ContainerProps({
    this.clipContent = false,
    this.scrollDirection,
  });

  ContainerProps copyWith({
    bool? clipContent,
    String? scrollDirection,
  }) {
    return ContainerProps(
      clipContent: clipContent ?? this.clipContent,
      scrollDirection: scrollDirection ?? this.scrollDirection,
    );
  }

  factory ContainerProps.fromJson(Map<String, dynamic> json) {
    return ContainerProps(
      clipContent: json['clipContent'] as bool? ?? false,
      scrollDirection: json['scrollDirection'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'clipContent': clipContent,
        if (scrollDirection != null) 'scrollDirection': scrollDirection,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContainerProps &&
          clipContent == other.clipContent &&
          scrollDirection == other.scrollDirection;

  @override
  int get hashCode => Object.hash(clipContent, scrollDirection);
}

// =============================================================================
// TextProps
// =============================================================================

/// Properties for text nodes.
class TextProps extends NodeProps {
  /// The text content.
  final String text;

  /// Font family name.
  final String? fontFamily;

  /// Font size in logical pixels.
  final double fontSize;

  /// Font weight (100-900).
  final int fontWeight;

  /// Text color (hex or token).
  final String? color;

  /// Text alignment.
  final TextAlign textAlign;

  /// Line height multiplier.
  final double? lineHeight;

  /// Letter spacing.
  final double? letterSpacing;

  /// Text decoration.
  final TextDecoration decoration;

  const TextProps({
    required this.text,
    this.fontFamily,
    this.fontSize = 14,
    this.fontWeight = 400,
    this.color,
    this.textAlign = TextAlign.left,
    this.lineHeight,
    this.letterSpacing,
    this.decoration = TextDecoration.none,
  });

  TextProps copyWith({
    String? text,
    String? fontFamily,
    double? fontSize,
    int? fontWeight,
    String? color,
    TextAlign? textAlign,
    double? lineHeight,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return TextProps(
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      textAlign: textAlign ?? this.textAlign,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      decoration: decoration ?? this.decoration,
    );
  }

  factory TextProps.fromJson(Map<String, dynamic> json) {
    return TextProps(
      text: json['text'] as String? ?? '',
      fontFamily: json['fontFamily'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14,
      fontWeight: json['fontWeight'] as int? ?? 400,
      color: json['color'] as String?,
      textAlign: TextAlign.fromJson(json['textAlign'] as String? ?? 'left'),
      lineHeight: (json['lineHeight'] as num?)?.toDouble(),
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble(),
      decoration:
          TextDecoration.fromJson(json['decoration'] as String? ?? 'none'),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'text': text,
        if (fontFamily != null) 'fontFamily': fontFamily,
        'fontSize': fontSize,
        'fontWeight': fontWeight,
        if (color != null) 'color': color,
        'textAlign': textAlign.toJson(),
        if (lineHeight != null) 'lineHeight': lineHeight,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
        'decoration': decoration.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextProps &&
          text == other.text &&
          fontFamily == other.fontFamily &&
          fontSize == other.fontSize &&
          fontWeight == other.fontWeight &&
          color == other.color &&
          textAlign == other.textAlign &&
          lineHeight == other.lineHeight &&
          letterSpacing == other.letterSpacing &&
          decoration == other.decoration;

  @override
  int get hashCode => Object.hash(
        text,
        fontFamily,
        fontSize,
        fontWeight,
        color,
        textAlign,
        lineHeight,
        letterSpacing,
        decoration,
      );
}

enum TextAlign {
  left,
  center,
  right,
  justify;

  static TextAlign fromJson(String value) {
    return TextAlign.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextAlign.left,
    );
  }

  String toJson() => name;
}

enum TextDecoration {
  none,
  underline,
  lineThrough;

  static TextDecoration fromJson(String value) {
    return TextDecoration.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextDecoration.none,
    );
  }

  String toJson() => name;
}

// =============================================================================
// ImageProps
// =============================================================================

/// Properties for image nodes.
class ImageProps extends NodeProps {
  /// Asset path or URL.
  final String src;

  /// How the image should be scaled.
  final ImageFit fit;

  /// Alt text for accessibility.
  final String? alt;

  const ImageProps({
    required this.src,
    this.fit = ImageFit.cover,
    this.alt,
  });

  ImageProps copyWith({
    String? src,
    ImageFit? fit,
    String? alt,
  }) {
    return ImageProps(
      src: src ?? this.src,
      fit: fit ?? this.fit,
      alt: alt ?? this.alt,
    );
  }

  factory ImageProps.fromJson(Map<String, dynamic> json) {
    return ImageProps(
      src: json['src'] as String? ?? '',
      fit: ImageFit.fromJson(json['fit'] as String? ?? 'cover'),
      alt: json['alt'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'src': src,
        'fit': fit.toJson(),
        if (alt != null) 'alt': alt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageProps &&
          src == other.src &&
          fit == other.fit &&
          alt == other.alt;

  @override
  int get hashCode => Object.hash(src, fit, alt);
}

enum ImageFit {
  contain,
  cover,
  fill,
  fitWidth,
  fitHeight,
  none,
  scaleDown;

  static ImageFit fromJson(String value) {
    return ImageFit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ImageFit.cover,
    );
  }

  String toJson() => name;
}

// =============================================================================
// IconProps
// =============================================================================

/// Properties for icon nodes.
class IconProps extends NodeProps {
  /// Icon name (e.g., 'arrow_forward', 'home').
  final String icon;

  /// Icon set/family (e.g., 'material', 'lucide').
  final String iconSet;

  /// Icon size in logical pixels.
  final double size;

  /// Icon color (hex or token).
  final String? color;

  const IconProps({
    required this.icon,
    this.iconSet = 'material',
    this.size = 24,
    this.color,
  });

  IconProps copyWith({
    String? icon,
    String? iconSet,
    double? size,
    String? color,
  }) {
    return IconProps(
      icon: icon ?? this.icon,
      iconSet: iconSet ?? this.iconSet,
      size: size ?? this.size,
      color: color ?? this.color,
    );
  }

  factory IconProps.fromJson(Map<String, dynamic> json) {
    return IconProps(
      icon: json['icon'] as String? ?? '',
      iconSet: json['iconSet'] as String? ?? 'material',
      size: (json['size'] as num?)?.toDouble() ?? 24,
      color: json['color'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'icon': icon,
        'iconSet': iconSet,
        'size': size,
        if (color != null) 'color': color,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IconProps &&
          icon == other.icon &&
          iconSet == other.iconSet &&
          size == other.size &&
          color == other.color;

  @override
  int get hashCode => Object.hash(icon, iconSet, size, color);
}

// =============================================================================
// SpacerProps
// =============================================================================

/// Properties for spacer nodes (flexible space).
class SpacerProps extends NodeProps {
  /// Flex factor for the spacer.
  final int flex;

  const SpacerProps({
    this.flex = 1,
  });

  SpacerProps copyWith({int? flex}) {
    return SpacerProps(flex: flex ?? this.flex);
  }

  factory SpacerProps.fromJson(Map<String, dynamic> json) {
    return SpacerProps(
      flex: json['flex'] as int? ?? 1,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'flex': flex,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SpacerProps && flex == other.flex;

  @override
  int get hashCode => flex.hashCode;
}

// =============================================================================
// InstanceProps
// =============================================================================

/// Properties for component instance nodes.
class InstanceProps extends NodeProps {
  /// Reference to the component definition.
  final String componentId;

  /// Parameter overrides keyed by parameter key (v2).
  ///
  /// Values must match the corresponding [ComponentParamDef.type].
  /// Parameters not in this map use their default values.
  final Map<String, dynamic> paramOverrides;

  /// Legacy property overrides keyed by node ID (deprecated).
  @Deprecated('Use paramOverrides instead for typed parameter overrides')
  final Map<String, dynamic> overrides;

  /// Slot assignments for this instance.
  ///
  /// Keyed by slot name. Slots not present in the map use default content
  /// (if the slot has `defaultContentId`) or remain empty.
  final Map<String, SlotAssignment> slots;

  const InstanceProps({
    required this.componentId,
    this.paramOverrides = const {},
    // ignore: deprecated_member_use_from_same_package
    this.overrides = const {},
    this.slots = const {},
  });

  InstanceProps copyWith({
    String? componentId,
    Map<String, dynamic>? paramOverrides,
    @Deprecated('Use paramOverrides instead') Map<String, dynamic>? overrides,
    Map<String, SlotAssignment>? slots,
  }) {
    return InstanceProps(
      componentId: componentId ?? this.componentId,
      paramOverrides: paramOverrides ?? this.paramOverrides,
      // ignore: deprecated_member_use_from_same_package
      overrides: overrides ?? this.overrides,
      slots: slots ?? this.slots,
    );
  }

  factory InstanceProps.fromJson(Map<String, dynamic> json) {
    return InstanceProps(
      componentId: json['componentId'] as String? ?? '',
      paramOverrides:
          (json['paramOverrides'] as Map<String, dynamic>?) ?? const {},
      // ignore: deprecated_member_use_from_same_package
      overrides: (json['overrides'] as Map<String, dynamic>?) ?? const {},
      slots: (json['slots'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, SlotAssignment.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'componentId': componentId,
        if (paramOverrides.isNotEmpty) 'paramOverrides': paramOverrides,
        // ignore: deprecated_member_use_from_same_package
        if (overrides.isNotEmpty) 'overrides': overrides,
        if (slots.isNotEmpty)
          'slots': slots.map((k, v) => MapEntry(k, v.toJson())),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstanceProps &&
          componentId == other.componentId &&
          mapEquals(paramOverrides, other.paramOverrides) &&
          // ignore: deprecated_member_use_from_same_package
          mapEquals(overrides, other.overrides) &&
          mapEquals(slots, other.slots);

  @override
  int get hashCode => Object.hash(
        componentId,
        Object.hashAll(paramOverrides.entries),
        // ignore: deprecated_member_use_from_same_package
        Object.hashAll(overrides.entries),
        Object.hashAll(slots.entries),
      );
}

// =============================================================================
// SlotProps
// =============================================================================

/// Properties for slot placeholder nodes in component definitions.
class SlotProps extends NodeProps {
  /// Name of the slot for identification.
  final String slotName;

  /// Default content node ID (optional).
  final String? defaultContentId;

  const SlotProps({
    required this.slotName,
    this.defaultContentId,
  });

  SlotProps copyWith({
    String? slotName,
    String? defaultContentId,
  }) {
    return SlotProps(
      slotName: slotName ?? this.slotName,
      defaultContentId: defaultContentId ?? this.defaultContentId,
    );
  }

  factory SlotProps.fromJson(Map<String, dynamic> json) {
    return SlotProps(
      slotName: json['slotName'] as String? ?? '',
      defaultContentId: json['defaultContentId'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'slotName': slotName,
        if (defaultContentId != null) 'defaultContentId': defaultContentId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotProps &&
          slotName == other.slotName &&
          defaultContentId == other.defaultContentId;

  @override
  int get hashCode => Object.hash(slotName, defaultContentId);
}

// =============================================================================
// SlotAssignment
// =============================================================================

/// Assignment of content to a slot in a component instance.
///
/// In v1, each slot accepts exactly one root node. If you need multiple
/// elements, wrap them in a container first.
class SlotAssignment {
  /// The root node ID of the injected content.
  ///
  /// This node must exist in `doc.nodes` with `ownerInstanceId` pointing
  /// to the owning instance. Null means use default content or empty.
  final String? rootNodeId;

  const SlotAssignment({this.rootNodeId});

  /// Whether this slot has content assigned.
  bool get hasContent => rootNodeId != null;

  SlotAssignment copyWith({String? rootNodeId}) {
    return SlotAssignment(rootNodeId: rootNodeId ?? this.rootNodeId);
  }

  factory SlotAssignment.fromJson(Map<String, dynamic> json) {
    return SlotAssignment(
      rootNodeId: json['rootNodeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (rootNodeId != null) 'rootNodeId': rootNodeId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotAssignment && rootNodeId == other.rootNodeId;

  @override
  int get hashCode => rootNodeId.hashCode;
}
