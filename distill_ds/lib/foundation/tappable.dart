import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widget_states.dart';

/// A signature for building a widget based on interaction states.
typedef HoloTappableBuilder =
    Widget Function(BuildContext context, WidgetStates states, Widget? child);

/// A foundational interactive widget that tracks hover, press, focus,
/// and disabled states.
///
/// [HoloTappable] is the building block for all interactive components
/// in the design system. It handles:
/// - Hover detection (mouse enter/exit)
/// - Press detection (tap down/up/cancel)
/// - Focus management (keyboard focus)
/// - Disabled state (prevents interactions)
/// - Cursor changes
/// - Keyboard activation (Enter/Space)
/// - Optional press scale animation
///
/// The [builder] function receives the current [WidgetStates] and can
/// render accordingly.
///
/// Example:
/// ```dart
/// HoloTappable(
///   onTap: () => print('Tapped!'),
///   pressScale: HoloTappable.defaultPressScale, // 0.95 scale on press
///   builder: (context, states, child) => Container(
///     color: states.isHovered ? Colors.blue : Colors.grey,
///     child: child,
///   ),
///   child: Text('Click me'),
/// )
/// ```
class HoloTappable extends StatefulWidget {
  /// The default scale factor when pressed (0.95 = 95% of original size).
  static const double defaultPressScale = 0.98;

  /// The default duration for scale animations.
  static const Duration defaultScaleDuration = Duration(milliseconds: 100);

  /// The default curve for scale animations.
  static const Curve defaultScaleCurve = Curves.easeOutCubic;

  /// Called when the widget is tapped.
  final VoidCallback? onTap;

  /// Called when the widget is long-pressed.
  final VoidCallback? onLongPress;

  /// Called when a secondary button (right-click) is pressed.
  final VoidCallback? onSecondaryTap;

  /// Called with the global position when the tap is initiated.
  final void Function(Offset position)? onTapDown;

  /// Builds the widget based on the current interaction states.
  final HoloTappableBuilder builder;

  /// An optional static child passed to the builder.
  ///
  /// Use this for content that doesn't change based on state,
  /// allowing Flutter to optimize rebuilds.
  final Widget? child;

  /// Whether the widget is enabled and can receive interactions.
  ///
  /// When false, the widget will have [WidgetStates.isDisabled] set to true
  /// and will not respond to any gestures.
  final bool enabled;

  /// Whether the widget is in a selected state.
  final bool selected;

  /// The mouse cursor to use when hovering over this widget.
  final MouseCursor cursor;

  /// The mouse cursor to use when the widget is disabled.
  final MouseCursor disabledCursor;

  /// Whether this widget should be focusable.
  final bool canRequestFocus;

  /// An optional focus node to use for this widget.
  final FocusNode? focusNode;

  /// Whether to automatically focus this widget when it's first built.
  final bool autofocus;

  /// Called when the hover state changes.
  final void Function(bool isHovered)? onHoverChange;

  /// Called when the focus state changes.
  final void Function(bool isFocused)? onFocusChange;

  // ─────────────────────────────────────────────────────────────────────────
  // Press Animation Properties
  // ─────────────────────────────────────────────────────────────────────────

  /// The scale factor to animate to when pressed.
  ///
  /// Set to `null` to disable the press animation (default).
  /// Use [defaultPressScale] (0.95) for a subtle, tactile feel.
  ///
  /// Example:
  /// ```dart
  /// HoloTappable(
  ///   pressScale: 0.95, // Scale to 95% when pressed
  ///   ...
  /// )
  /// ```
  final double? pressScale;

  /// The duration of the scale animation.
  ///
  /// Defaults to [defaultScaleDuration] (100ms).
  final Duration scaleDuration;

  /// The curve for the scale animation.
  ///
  /// Defaults to [defaultScaleCurve] (easeOutCubic).
  final Curve scaleCurve;

  /// Creates a [HoloTappable] widget.
  const HoloTappable({
    super.key,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onTapDown,
    required this.builder,
    this.child,
    this.enabled = true,
    this.selected = false,
    this.cursor = SystemMouseCursors.click,
    this.disabledCursor = SystemMouseCursors.basic,
    this.canRequestFocus = true,
    this.focusNode,
    this.autofocus = false,
    this.onHoverChange,
    this.onFocusChange,
    this.pressScale,
    this.scaleDuration = defaultScaleDuration,
    this.scaleCurve = defaultScaleCurve,
  });

  /// Creates a simple [HoloTappable] that wraps a child without a builder.
  ///
  /// Use this for simple cases where you don't need to react to state changes.
  /// The child is rendered as-is, but interactions are still tracked.
  static Widget simple({
    Key? key,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    required Widget child,
    bool enabled = true,
    MouseCursor cursor = SystemMouseCursors.click,
    double? pressScale,
  }) {
    return HoloTappable(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      enabled: enabled,
      cursor: cursor,
      pressScale: pressScale,
      builder: (_, __, c) => c!,
      child: child,
    );
  }

  @override
  State<HoloTappable> createState() => _HoloTappableState();
}

class _HoloTappableState extends State<HoloTappable> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  FocusNode? _focusNode;
  bool _ownsNode = false;

  @override
  void initState() {
    super.initState();
    _initFocusNode();
  }

  void _initFocusNode() {
    // Only create focus node when focus is needed
    if (!widget.canRequestFocus) {
      _focusNode = null;
      _ownsNode = false;
      return;
    }

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsNode = false;
    } else {
      _focusNode = FocusNode(
        debugLabel: 'HoloTappable',
        canRequestFocus: widget.enabled,
      );
      _ownsNode = true;
    }
  }

  @override
  void didUpdateWidget(HoloTappable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle canRequestFocus changes
    if (widget.canRequestFocus != oldWidget.canRequestFocus ||
        widget.focusNode != oldWidget.focusNode) {
      if (_ownsNode && _focusNode != null) {
        _focusNode!.dispose();
      }
      _initFocusNode();
    }

    // Update focus node properties if it exists
    if (_focusNode != null) {
      _focusNode!.canRequestFocus = widget.enabled && widget.canRequestFocus;
    }

    // Reset states if disabled
    if (!widget.enabled && oldWidget.enabled) {
      setState(() {
        _isHovered = false;
        _isPressed = false;
      });
    }
  }

  @override
  void dispose() {
    if (_ownsNode && _focusNode != null) {
      _focusNode!.dispose();
    }
    super.dispose();
  }

  WidgetStates get _states => WidgetStates(
    isHovered: _isHovered,
    isPressed: _isPressed,
    isFocused: _isFocused,
    isDisabled: !widget.enabled,
    isSelected: widget.selected,
  );

  void _handleHoverEnter(PointerEnterEvent event) {
    if (!widget.enabled) return;
    setState(() => _isHovered = true);
    widget.onHoverChange?.call(true);
  }

  void _handleHoverExit(PointerExitEvent event) {
    if (!widget.enabled) return;
    setState(() => _isHovered = false);
    widget.onHoverChange?.call(false);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = true);
    widget.onTapDown?.call(details.globalPosition);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.enabled) return;
    setState(() => _isPressed = false);
  }

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (!widget.enabled) return;
    widget.onLongPress?.call();
  }

  void _handleSecondaryTap() {
    if (!widget.enabled) return;
    widget.onSecondaryTap?.call();
  }

  void _handleFocusChange(bool focused) {
    setState(() => _isFocused = focused);
    widget.onFocusChange?.call(focused);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;

    // Activate on Enter or Space key down
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final cursor = widget.enabled ? widget.cursor : widget.disabledCursor;

    Widget content = widget.builder(context, _states, widget.child);

    // Wrap with scale animation if pressScale is set
    if (widget.pressScale != null) {
      content = AnimatedScale(
        scale: _isPressed ? widget.pressScale! : 1.0,
        duration: widget.scaleDuration,
        curve: widget.scaleCurve,
        child: content,
      );
    }

    // Core gesture detection
    Widget result = GestureDetector(
      onTap: widget.enabled ? _handleTap : null,
      onTapDown: widget.enabled ? _handleTapDown : null,
      onTapUp: widget.enabled ? _handleTapUp : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      onLongPress:
          widget.enabled && widget.onLongPress != null
              ? _handleLongPress
              : null,
      onSecondaryTap:
          widget.enabled && widget.onSecondaryTap != null
              ? _handleSecondaryTap
              : null,
      behavior: HitTestBehavior.opaque,
      child: content,
    );

    // Only wrap with Focus when keyboard focus is needed
    if (widget.canRequestFocus && _focusNode != null) {
      result = Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onFocusChange: _handleFocusChange,
        onKeyEvent: _handleKeyEvent,
        child: result,
      );
    }

    return MouseRegion(
      onEnter: _handleHoverEnter,
      onExit: _handleHoverExit,
      cursor: cursor,
      child: result,
    );
  }
}
