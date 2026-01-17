import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/editor_input_container.dart';
import '../core/editor_styling.dart';

/// A read-only button-style input that opens a picker/dialog on click.
///
/// Features:
/// - Click-to-edit interaction
/// - Optional prefix widget (e.g., color square preview)
/// - Optional suffix widget (e.g., units, clear button)
/// - Keyboard support (Enter/Space to activate)
/// - Hover-sensitive clear button
///
/// Usage:
/// ```dart
/// ButtonEditor(
///   displayValue: '#FF0000',
///   prefix: ColorSquare(color: Colors.red),
///   onTap: () => showColorPicker(),
///   onClear: () => store.updateNodeProp(nodeId, '/style/fill', null),
/// )
/// ```
///
/// See also:
/// - [NumberEditor] for numeric input
/// - [TextEditor] for text input
/// - [DropdownEditor] for selection from options
class ButtonEditor extends StatefulWidget {
  /// The value to display (formatted for display).
  final String? displayValue;

  /// Placeholder when displayValue is null/empty.
  final String placeholder;

  /// Called when the input is tapped.
  final VoidCallback? onTap;

  /// Optional prefix widget (e.g., color square).
  final Widget? prefix;

  /// Optional suffix widget (e.g., units, arrow).
  final Widget? suffix;

  /// Whether the input is disabled.
  final bool disabled;

  /// Whether the input has a validation error.
  final bool hasError;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Called when the clear button is tapped.
  /// When provided, a clear button will appear on hover if the input has a value.
  final VoidCallback? onClear;

  /// Whether the clear button should replace the suffix instead of appearing beside it.
  final bool clearReplacesSuffix;

  const ButtonEditor({
    super.key,
    this.displayValue,
    this.placeholder = '-',
    this.onTap,
    this.prefix,
    this.suffix,
    this.disabled = false,
    this.hasError = false,
    this.focusNode,
    this.onClear,
    this.clearReplacesSuffix = false,
  });

  @override
  State<ButtonEditor> createState() => _ButtonEditorState();
}

class _ButtonEditorState extends State<ButtonEditor> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ButtonEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _internalFocusNode?.removeListener(_onFocusChanged);
      if (widget.focusNode == null && _internalFocusNode == null) {
        _internalFocusNode = FocusNode();
      }
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _handleTap() {
    if (widget.disabled) return;
    widget.onTap?.call();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.disabled) return KeyEventResult.ignored;

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Builds the suffix widget, showing clear button on hover if applicable.
  Widget? _buildSuffix(BuildContext context) {
    final hasValue =
        widget.displayValue != null && widget.displayValue!.isNotEmpty;
    final showClear =
        _isHovered && hasValue && widget.onClear != null && !widget.disabled;

    if (showClear) {
      final clearButton = _ClearButton(onClear: widget.onClear!);
      if (widget.clearReplacesSuffix) {
        // Replace suffix with clear button
        return clearButton;
      }
      // Show clear button alongside existing suffix
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          clearButton,
          if (widget.suffix != null) widget.suffix!,
        ],
      );
    }
    return widget.suffix;
  }

  @override
  Widget build(BuildContext context) {
    final hasValue =
        widget.displayValue != null && widget.displayValue!.isNotEmpty;

    return MouseRegion(
      onEnter:
          widget.disabled ? null : (_) => setState(() => _isHovered = true),
      onExit:
          widget.disabled ? null : (_) => setState(() => _isHovered = false),
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: EditorInputContainer(
          onTap: _handleTap,
          // Don't pass focusNode - button inputs shouldn't grab focus on tap
          prefix: widget.prefix,
          suffix: _buildSuffix(context),
          focused: _isFocused,
          disabled: widget.disabled,
          hasError: widget.hasError,
          child: Padding(
            padding: EditorSpacing.horizontal,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _buildContent(context, hasValue),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool hasValue) {
    // No value - show placeholder
    if (!hasValue) {
      return Text(
        widget.placeholder,
        style:
            widget.placeholder == 'null'
                ? EditorTextStyles.nullPlaceholder(
                  context,
                  disabled: widget.disabled,
                )
                : EditorTextStyles.placeholder(
                  context,
                  disabled: widget.disabled,
                ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }

    // Regular text value - use null placeholder style if value is "null"
    final isNullValue = widget.displayValue == 'null';
    return Text(
      widget.displayValue!,
      style:
          isNullValue
              ? EditorTextStyles.nullPlaceholder(
                context,
                disabled: widget.disabled,
              )
              : EditorTextStyles.input(context, disabled: widget.disabled),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

/// A small clear button for editor suffixes.
class _ClearButton extends StatelessWidget {
  final VoidCallback onClear;

  const _ClearButton({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClear,
      child: Icon(
        Icons.close,
        size: 14,
        color: EditorColors.borderHovered(context),
      ),
    );
  }
}
