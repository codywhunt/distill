/// The mode for the border radius editor.
enum BorderRadiusMode {
  /// Single value applied to all corners.
  all,

  /// Separate values for each corner (topLeft, topRight, bottomLeft, bottomRight).
  only,
}

/// Represents a border radius value with mode and individual numeric values.
///
/// This is a pure data class that can represent any border radius configuration.
/// Works with numeric values only (no expressions/theme constants).
class BorderRadiusValue {
  /// The current mode of the border radius.
  final BorderRadiusMode mode;

  /// Value for all corners (used in `all` mode).
  final double? all;

  /// Value for top left corner (used in `only` mode).
  final double? topLeft;

  /// Value for top right corner (used in `only` mode).
  final double? topRight;

  /// Value for bottom left corner (used in `only` mode).
  final double? bottomLeft;

  /// Value for bottom right corner (used in `only` mode).
  final double? bottomRight;

  const BorderRadiusValue({
    this.mode = BorderRadiusMode.all,
    this.all,
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
  });

  /// Creates a BorderRadiusValue with all corners set to the same value.
  const BorderRadiusValue.all(double value)
      : mode = BorderRadiusMode.all,
        all = value,
        topLeft = null,
        topRight = null,
        bottomLeft = null,
        bottomRight = null;

  /// Creates a BorderRadiusValue with individual values for each corner.
  const BorderRadiusValue.only({
    double? topLeft,
    double? topRight,
    double? bottomLeft,
    double? bottomRight,
  })  : mode = BorderRadiusMode.only,
        all = null,
        topLeft = topLeft,
        topRight = topRight,
        bottomLeft = bottomLeft,
        bottomRight = bottomRight;

  /// Creates a BorderRadiusValue from a JSON map or dynamic value.
  ///
  /// Intelligently detects the mode based on which values are present:
  /// - If 'all' key present -> 'all' mode
  /// - If all corners equal -> 'all' mode
  /// - Otherwise -> 'only' mode
  factory BorderRadiusValue.fromJson(dynamic json) {
    // Handle case where json might be a primitive value instead of a map
    if (json == null || json is! Map<String, dynamic>) {
      return const BorderRadiusValue.all(0);
    }

    // Handle 'all' key format from CornerRadius.toJson()
    if (json.containsKey('all')) {
      return BorderRadiusValue.all((json['all'] as num).toDouble());
    }

    final tl = (json['topLeft'] as num?)?.toDouble();
    final tr = (json['topRight'] as num?)?.toDouble();
    final bl = (json['bottomLeft'] as num?)?.toDouble();
    final br = (json['bottomRight'] as num?)?.toDouble();

    // Check if all corners are equal
    if (tl != null &&
        tl == tr &&
        tr == bl &&
        bl == br) {
      return BorderRadiusValue.all(tl);
    }

    // Individual values
    return BorderRadiusValue.only(
      topLeft: tl,
      topRight: tr,
      bottomLeft: bl,
      bottomRight: br,
    );
  }

  /// Converts to a JSON map.
  Map<String, dynamic> toJson() {
    switch (mode) {
      case BorderRadiusMode.all:
        final value = all ?? 0.0;
        return {
          'topLeft': value,
          'topRight': value,
          'bottomLeft': value,
          'bottomRight': value,
        };
      case BorderRadiusMode.only:
        return {
          'topLeft': topLeft ?? 0.0,
          'topRight': topRight ?? 0.0,
          'bottomLeft': bottomLeft ?? 0.0,
          'bottomRight': bottomRight ?? 0.0,
        };
    }
  }

  /// Creates a copy with the specified values changed.
  BorderRadiusValue copyWith({
    BorderRadiusMode? mode,
    double? all,
    double? topLeft,
    double? topRight,
    double? bottomLeft,
    double? bottomRight,
  }) {
    return BorderRadiusValue(
      mode: mode ?? this.mode,
      all: all ?? this.all,
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      bottomRight: bottomRight ?? this.bottomRight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorderRadiusValue &&
          mode == other.mode &&
          all == other.all &&
          topLeft == other.topLeft &&
          topRight == other.topRight &&
          bottomLeft == other.bottomLeft &&
          bottomRight == other.bottomRight;

  @override
  int get hashCode => Object.hash(
        mode,
        all,
        topLeft,
        topRight,
        bottomLeft,
        bottomRight,
      );
}
