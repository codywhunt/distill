import 'package:flutter/widgets.dart';

import 'widget_states.dart';

/// A generic class that maps [WidgetStates] to values of type [T].
///
/// Use this to define different values for different interaction states
/// (hovered, pressed, focused, disabled, selected).
///
/// Example:
/// ```dart
/// final backgroundColor = StateValue<Color>(
///   base: Colors.grey,
///   hovered: Colors.blue,
///   pressed: Colors.darkBlue,
///   disabled: Colors.grey.withOpacity(0.5),
/// );
///
/// // Later, resolve based on current state:
/// final color = backgroundColor.resolve(states);
/// ```
@immutable
class StateValue<T> {
  /// The default value when no state-specific value matches.
  final T base;

  /// The value to use when the widget is hovered.
  final T? hovered;

  /// The value to use when the widget is pressed.
  final T? pressed;

  /// The value to use when the widget is focused.
  final T? focused;

  /// The value to use when the widget is disabled.
  final T? disabled;

  /// The value to use when the widget is selected.
  final T? selected;

  /// Creates a [StateValue] with the given state-specific values.
  const StateValue({
    required this.base,
    this.hovered,
    this.pressed,
    this.focused,
    this.disabled,
    this.selected,
  });

  /// Creates a [StateValue] from just a base value.
  ///
  /// Useful when you want to pass a simple value where a [StateValue] is expected.
  const StateValue.all(T value)
    : base = value,
      hovered = null,
      pressed = null,
      focused = null,
      disabled = null,
      selected = null;

  /// Resolves the value based on the given [states].
  ///
  /// Priority order (first match wins):
  /// 1. disabled
  /// 2. pressed
  /// 3. hovered
  /// 4. focused
  /// 5. selected
  /// 6. base (default)
  T resolve(WidgetStates states) {
    if (states.isDisabled && disabled != null) return disabled as T;
    if (states.isPressed && pressed != null) return pressed as T;
    if (states.isHovered && hovered != null) return hovered as T;
    if (states.isFocused && focused != null) return focused as T;
    if (states.isSelected && selected != null) return selected as T;
    return base;
  }

  /// Creates a copy of this [StateValue] with the given fields replaced.
  StateValue<T> copyWith({
    T? base,
    T? hovered,
    T? pressed,
    T? focused,
    T? disabled,
    T? selected,
  }) {
    return StateValue<T>(
      base: base ?? this.base,
      hovered: hovered ?? this.hovered,
      pressed: pressed ?? this.pressed,
      focused: focused ?? this.focused,
      disabled: disabled ?? this.disabled,
      selected: selected ?? this.selected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StateValue<T> &&
        other.base == base &&
        other.hovered == hovered &&
        other.pressed == pressed &&
        other.focused == focused &&
        other.disabled == disabled &&
        other.selected == selected;
  }

  @override
  int get hashCode =>
      Object.hash(base, hovered, pressed, focused, disabled, selected);

  @override
  String toString() {
    return 'StateValue<$T>(base: $base, hovered: $hovered, pressed: $pressed, '
        'focused: $focused, disabled: $disabled, selected: $selected)';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type Aliases for Common Types
// ─────────────────────────────────────────────────────────────────────────────

/// A [StateValue] specialized for [Color] values.
typedef StateColor = StateValue<Color>;

/// A [StateValue] specialized for [double] values.
typedef StateDouble = StateValue<double>;

/// A [StateValue] specialized for [EdgeInsets] values.
typedef StateEdgeInsets = StateValue<EdgeInsets>;

/// A [StateValue] specialized for [BoxDecoration] values.
typedef StateDecoration = StateValue<BoxDecoration>;

/// A [StateValue] specialized for [TextStyle] values.
typedef StateTextStyle = StateValue<TextStyle>;

// ─────────────────────────────────────────────────────────────────────────────
// Ergonomic Extensions
// ─────────────────────────────────────────────────────────────────────────────

/// Extension on [Color] to easily create a [StateColor].
///
/// Example:
/// ```dart
/// HoloButton(
///   backgroundColor: Colors.blue.states(
///     hovered: Colors.lightBlue,
///     pressed: Colors.darkBlue,
///   ),
/// )
/// ```
extension ColorStateExtension on Color {
  /// Creates a [StateColor] with this color as the base.
  StateColor states({
    Color? hovered,
    Color? pressed,
    Color? focused,
    Color? disabled,
    Color? selected,
  }) {
    return StateColor(
      base: this,
      hovered: hovered,
      pressed: pressed,
      focused: focused,
      disabled: disabled,
      selected: selected,
    );
  }

  /// Resolves this color or a state-variant based on the given [states].
  ///
  /// A convenience method for inline state resolution without creating
  /// an intermediate [StateColor] object.
  ///
  /// Example:
  /// ```dart
  /// color: baseColor.when(states,
  ///   hovered: hoverColor,
  ///   pressed: pressColor,
  /// ),
  /// ```
  Color when(
    WidgetStates states, {
    Color? hovered,
    Color? pressed,
    Color? focused,
    Color? disabled,
    Color? selected,
  }) {
    if (states.isDisabled && disabled != null) return disabled;
    if (states.isPressed && pressed != null) return pressed;
    if (states.isHovered && hovered != null) return hovered;
    if (states.isFocused && focused != null) return focused;
    if (states.isSelected && selected != null) return selected;
    return this;
  }
}

/// Extension on [double] to easily create a [StateDouble].
extension DoubleStateExtension on double {
  /// Creates a [StateDouble] with this value as the base.
  StateDouble states({
    double? hovered,
    double? pressed,
    double? focused,
    double? disabled,
    double? selected,
  }) {
    return StateDouble(
      base: this,
      hovered: hovered,
      pressed: pressed,
      focused: focused,
      disabled: disabled,
      selected: selected,
    );
  }

  /// Resolves this value or a state-variant based on the given [states].
  double when(
    WidgetStates states, {
    double? hovered,
    double? pressed,
    double? focused,
    double? disabled,
    double? selected,
  }) {
    if (states.isDisabled && disabled != null) return disabled;
    if (states.isPressed && pressed != null) return pressed;
    if (states.isHovered && hovered != null) return hovered;
    if (states.isFocused && focused != null) return focused;
    if (states.isSelected && selected != null) return selected;
    return this;
  }
}

/// Extension on [EdgeInsets] to easily create a [StateEdgeInsets].
extension EdgeInsetsStateExtension on EdgeInsets {
  /// Creates a [StateEdgeInsets] with this value as the base.
  StateEdgeInsets states({
    EdgeInsets? hovered,
    EdgeInsets? pressed,
    EdgeInsets? focused,
    EdgeInsets? disabled,
    EdgeInsets? selected,
  }) {
    return StateEdgeInsets(
      base: this,
      hovered: hovered,
      pressed: pressed,
      focused: focused,
      disabled: disabled,
      selected: selected,
    );
  }
}

/// Extension on [TextStyle] to easily create a [StateTextStyle].
extension TextStyleStateExtension on TextStyle {
  /// Creates a [StateTextStyle] with this style as the base.
  StateTextStyle states({
    TextStyle? hovered,
    TextStyle? pressed,
    TextStyle? focused,
    TextStyle? disabled,
    TextStyle? selected,
  }) {
    return StateTextStyle(
      base: this,
      hovered: hovered,
      pressed: pressed,
      focused: focused,
      disabled: disabled,
      selected: selected,
    );
  }
}
