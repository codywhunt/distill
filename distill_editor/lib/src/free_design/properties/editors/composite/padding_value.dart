/// The mode for the padding editor.
enum PaddingMode {
  /// Single value applied to all sides.
  all,

  /// Separate values for horizontal and vertical.
  symmetric,

  /// Separate values for each side (left, top, right, bottom).
  only,
}

/// Represents a padding value with mode and individual numeric values.
///
/// This is a pure data class that can represent any padding configuration.
/// Works with numeric values only (no expressions/theme constants).
class PaddingValue {
  /// The current mode of the padding.
  final PaddingMode mode;

  /// Value for all sides (used in `all` mode).
  final double? all;

  /// Value for horizontal (used in `symmetric` mode).
  final double? horizontal;

  /// Value for vertical (used in `symmetric` mode).
  final double? vertical;

  /// Value for left (used in `only` mode).
  final double? left;

  /// Value for top (used in `only` mode).
  final double? top;

  /// Value for right (used in `only` mode).
  final double? right;

  /// Value for bottom (used in `only` mode).
  final double? bottom;

  const PaddingValue({
    this.mode = PaddingMode.all,
    this.all,
    this.horizontal,
    this.vertical,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  /// Creates a PaddingValue with all sides set to the same value.
  const PaddingValue.all(double value)
      : mode = PaddingMode.all,
        all = value,
        horizontal = null,
        vertical = null,
        left = null,
        top = null,
        right = null,
        bottom = null;

  /// Creates a PaddingValue with symmetric horizontal and vertical values.
  const PaddingValue.symmetric({double? horizontal, double? vertical})
      : mode = PaddingMode.symmetric,
        all = null,
        horizontal = horizontal,
        vertical = vertical,
        left = null,
        top = null,
        right = null,
        bottom = null;

  /// Creates a PaddingValue with individual values for each side.
  const PaddingValue.only({
    double? left,
    double? top,
    double? right,
    double? bottom,
  })  : mode = PaddingMode.only,
        all = null,
        horizontal = null,
        vertical = null,
        left = left,
        top = top,
        right = right,
        bottom = bottom;

  /// Creates a PaddingValue from a JSON map or dynamic value.
  ///
  /// Intelligently detects the mode based on which values are present:
  /// - If all sides equal -> 'all' mode
  /// - If left==right and top==bottom -> 'symmetric' mode
  /// - Otherwise -> 'only' mode
  factory PaddingValue.fromJson(dynamic json) {
    // Handle case where json might be a primitive value instead of a map
    if (json == null || json is! Map<String, dynamic>) {
      return const PaddingValue.all(0);
    }

    final l = (json['left'] as num?)?.toDouble() ?? 0.0;
    final t = (json['top'] as num?)?.toDouble() ?? 0.0;
    final r = (json['right'] as num?)?.toDouble() ?? 0.0;
    final b = (json['bottom'] as num?)?.toDouble() ?? 0.0;

    // Check if all sides are equal
    if (l == t && t == r && r == b) {
      return PaddingValue.all(l);
    }

    // Check if symmetric (left==right and top==bottom)
    if (l == r && t == b) {
      return PaddingValue.symmetric(
        horizontal: l,
        vertical: t,
      );
    }

    // Individual values
    return PaddingValue.only(
      left: l,
      top: t,
      right: r,
      bottom: b,
    );
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    switch (mode) {
      case PaddingMode.all:
        final value = all ?? 0.0;
        return {
          'left': value,
          'top': value,
          'right': value,
          'bottom': value,
        };
      case PaddingMode.symmetric:
        return {
          'left': horizontal ?? 0.0,
          'top': vertical ?? 0.0,
          'right': horizontal ?? 0.0,
          'bottom': vertical ?? 0.0,
        };
      case PaddingMode.only:
        return {
          'left': left ?? 0.0,
          'top': top ?? 0.0,
          'right': right ?? 0.0,
          'bottom': bottom ?? 0.0,
        };
    }
  }

  /// Creates a copy with the specified values changed.
  PaddingValue copyWith({
    PaddingMode? mode,
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    return PaddingValue(
      mode: mode ?? this.mode,
      all: all ?? this.all,
      horizontal: horizontal ?? this.horizontal,
      vertical: vertical ?? this.vertical,
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaddingValue &&
          mode == other.mode &&
          all == other.all &&
          horizontal == other.horizontal &&
          vertical == other.vertical &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom;

  @override
  int get hashCode => Object.hash(
        mode,
        all,
        horizontal,
        vertical,
        left,
        top,
        right,
        bottom,
      );
}
