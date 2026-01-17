import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_styling.dart';
import 'mixins/debounce_mixin.dart';

/// Base text input widget with shared behavior for all text-based editors.
///
/// Handles:
/// - Controller and focus node management
/// - Debounced change callbacks (emits during typing)
/// - Immediate commit on blur/submit (cancels debounce, emits if changed)
/// - Hover state tracking (exposed via callback)
///
/// Only emits [onChanged] if the value actually changed during the focus
/// session. This prevents empty inputs from emitting on blur when the user
/// clicks in and out without typing.
///
/// This widget returns just the TextField - the container chrome
/// (border, prefix/suffix) is handled by [EditorInputContainer].
class BaseTextInput extends StatefulWidget {
  /// Current value to display.
  final String? value;

  /// Called when the value changes (debounced during typing, immediate on
  /// blur/submit).
  final ValueChanged<String>? onChanged;

  /// Placeholder text when empty.
  final String? placeholder;

  /// Text alignment within the field.
  final TextAlign textAlign;

  /// Input formatters to restrict input.
  final List<TextInputFormatter>? inputFormatters;

  /// Keyboard type for the input.
  final TextInputType? keyboardType;

  /// Whether the input is disabled.
  final bool disabled;

  /// Maximum lines. 1 = single-line, > 1 = multiline.
  final int maxLines;

  /// Minimum lines (only applies when maxLines > 1).
  final int? minLines;

  /// Debounce duration for onChange callbacks.
  final Duration debounceDuration;

  /// Called when hover state changes.
  final ValueChanged<bool>? onHoverChanged;

  /// Called when focus state changes.
  final ValueChanged<bool>? onFocusChanged;

  /// Optional external focus node.
  final FocusNode? focusNode;

  const BaseTextInput({
    super.key,
    this.value,
    this.onChanged,
    this.placeholder,
    this.textAlign = TextAlign.left,
    this.inputFormatters,
    this.keyboardType,
    this.disabled = false,
    this.maxLines = 1,
    this.minLines,
    this.debounceDuration = const Duration(milliseconds: 0),
    this.onHoverChanged,
    this.onFocusChanged,
    this.focusNode,
  });

  @override
  State<BaseTextInput> createState() => _BaseTextInputState();
}

class _BaseTextInputState extends State<BaseTextInput> with DebounceMixin {
  late TextEditingController _controller;
  FocusNode? _internalFocusNode;

  /// Tracks the value when focus was gained to detect actual changes.
  String? _valueOnFocus;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(BaseTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value ?? '';
    }
    // Handle focus node changes
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
    // Only dispose of the internal focus node, not an external one
    _internalFocusNode?.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);

    if (_focusNode.hasFocus) {
      // Track value when focus is gained
      _valueOnFocus = _controller.text;
    } else {
      // Only emit if value actually changed during this focus session
      if (_controller.text != _valueOnFocus) {
        cancelDebounce();
        widget.onChanged?.call(_controller.text);
      }
      _valueOnFocus = null;
    }
  }

  void _onTextChanged(String value) {
    debounce(widget.debounceDuration, () {
      widget.onChanged?.call(value);
    });
  }

  void _onSubmitted(String value) {
    // Only emit if value actually changed
    if (value != _valueOnFocus) {
      cancelDebounce();
      widget.onChanged?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverChanged?.call(true),
      onExit: (_) => widget.onHoverChanged?.call(false),
      child: TextSelectionTheme(
        data: editorTextSelectionTheme(context),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !widget.disabled,
          textAlign: widget.textAlign,
          keyboardType:
              widget.maxLines > 1
                  ? TextInputType.multiline
                  : widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.maxLines,
          minLines: widget.maxLines > 1 ? (widget.minLines ?? 1) : null,
          style: EditorTextStyles.input(context, disabled: widget.disabled),
          cursorColor: EditorColors.borderFocused(context),
          mouseCursor: SystemMouseCursors.basic,
          decoration: InputDecoration(
            hintText: widget.placeholder ?? '-',
            hintStyle:
                widget.placeholder == 'null'
                    ? EditorTextStyles.nullPlaceholder(
                      context,
                      disabled: widget.disabled,
                    )
                    : EditorTextStyles.placeholder(
                      context,
                      disabled: widget.disabled,
                    ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding:
                widget.maxLines > 1
                    ? EditorSpacing.multiline
                    : EditorSpacing.horizontal,
            isDense: true,
          ),
          onChanged: _onTextChanged,
          onSubmitted: widget.maxLines > 1 ? null : _onSubmitted,
        ),
      ),
    );
  }
}
