import 'package:flutter/foundation.dart';

/// Immutable state object that tracks interaction states for a widget.
///
/// Used by [HoloTappable] and other interactive widgets to communicate
/// the current interaction state to their builders.
///
/// Example:
/// ```dart
/// HoloTappable(
///   builder: (context, states, child) => Container(
///     color: states.isHovered ? Colors.blue : Colors.grey,
///     child: child,
///   ),
/// )
/// ```
@immutable
class WidgetStates {
  /// Whether the pointer is currently hovering over the widget.
  final bool isHovered;

  /// Whether the widget is currently being pressed.
  final bool isPressed;

  /// Whether the widget currently has keyboard focus.
  final bool isFocused;

  /// Whether the widget is disabled and should not respond to interactions.
  final bool isDisabled;

  /// Whether the widget is in a selected state.
  final bool isSelected;

  /// Creates a new [WidgetStates] instance.
  const WidgetStates({
    this.isHovered = false,
    this.isPressed = false,
    this.isFocused = false,
    this.isDisabled = false,
    this.isSelected = false,
  });

  /// The default state with no interactions.
  static const none = WidgetStates();

  /// Creates a copy of this state with the given fields replaced.
  WidgetStates copyWith({
    bool? isHovered,
    bool? isPressed,
    bool? isFocused,
    bool? isDisabled,
    bool? isSelected,
  }) {
    return WidgetStates(
      isHovered: isHovered ?? this.isHovered,
      isPressed: isPressed ?? this.isPressed,
      isFocused: isFocused ?? this.isFocused,
      isDisabled: isDisabled ?? this.isDisabled,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  /// Resolves a value based on the current state.
  ///
  /// Priority order (first match wins):
  /// 1. disabled
  /// 2. pressed
  /// 3. hovered
  /// 4. focused
  /// 5. selected
  /// 6. base (default)
  ///
  /// Example:
  /// ```dart
  /// final color = states.resolve(
  ///   base: Colors.grey,
  ///   hovered: Colors.blue,
  ///   pressed: Colors.darkBlue,
  ///   disabled: Colors.grey.withOpacity(0.5),
  /// );
  /// ```
  T resolve<T>({
    required T base,
    T? hovered,
    T? pressed,
    T? focused,
    T? disabled,
    T? selected,
  }) {
    if (isDisabled && disabled != null) return disabled;
    if (isPressed && pressed != null) return pressed;
    if (isHovered && hovered != null) return hovered;
    if (isFocused && focused != null) return focused;
    if (isSelected && selected != null) return selected;
    return base;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WidgetStates &&
        other.isHovered == isHovered &&
        other.isPressed == isPressed &&
        other.isFocused == isFocused &&
        other.isDisabled == isDisabled &&
        other.isSelected == isSelected;
  }

  @override
  int get hashCode =>
      Object.hash(isHovered, isPressed, isFocused, isDisabled, isSelected);

  @override
  String toString() {
    final states = <String>[];
    if (isHovered) states.add('hovered');
    if (isPressed) states.add('pressed');
    if (isFocused) states.add('focused');
    if (isDisabled) states.add('disabled');
    if (isSelected) states.add('selected');
    return 'WidgetStates(${states.isEmpty ? 'none' : states.join(', ')})';
  }
}
