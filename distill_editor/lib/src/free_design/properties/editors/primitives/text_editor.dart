import 'package:flutter/material.dart';

import '../core/base_text_input.dart';
import '../core/editor_input_container.dart';
import '../core/editor_styling.dart';
import '../core/mixins/hover_state_mixin.dart';
import '../core/validation.dart';

/// A text input editor for string values.
///
/// Features:
/// - Single-line or multiline input
/// - Debounced updates during typing (300ms)
/// - Immediate update on blur/submit
/// - Optional validation
/// - Optional prefix/suffix widgets
///
/// Usage:
/// ```dart
/// TextEditor(
///   value: 'Hello',
///   onChanged: (value) => store.updateNodeProp(nodeId, '/props/text', value),
///   placeholder: 'Enter text...',
///   validator: Validators.notEmpty(),
/// )
/// ```
///
/// See also:
/// - [NumberEditor] for numeric input
/// - [BooleanEditor] for true/false values
class TextEditor extends StatefulWidget {
  /// Current string value.
  final String? value;

  /// Called when the value changes.
  final ValueChanged<String?>? onChanged;

  /// Placeholder text when empty.
  final String? placeholder;

  /// Suffix widget (e.g., character count).
  final Widget? suffix;

  /// Prefix widget (e.g., icon).
  final Widget? prefix;

  /// Maximum lines. 1 = single-line, > 1 = multiline.
  final int maxLines;

  /// Minimum lines (only applies when maxLines > 1).
  final int? minLines;

  /// Whether the input is disabled.
  final bool disabled;

  /// Optional validator for the value.
  final Validator<String>? validator;

  /// Optional external focus node.
  final FocusNode? focusNode;

  const TextEditor({
    super.key,
    this.value,
    this.onChanged,
    this.placeholder,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.minLines,
    this.disabled = false,
    this.validator,
    this.focusNode,
  });

  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> with HoverStateMixin {
  bool _isFocused = false;
  ValidationResult? _validationResult;
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  bool get isHoverDisabled => widget.disabled;

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final value = text.isEmpty ? null : text;

    // Validate if validator is provided
    if (widget.validator != null) {
      final result = widget.validator!(value);
      setState(() => _validationResult = result);
      if (!result.isValid) {
        return; // Don't emit invalid values
      }
    }

    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _validationResult != null && !_validationResult!.isValid;

    if (widget.maxLines > 1) {
      return _buildMultilineInput(context, hasError);
    }

    return EditorInputContainer(
      prefix: widget.prefix,
      suffix: widget.suffix,
      focused: _isFocused,
      disabled: widget.disabled,
      hasError: hasError,
      focusNode: _effectiveFocusNode,
      child: BaseTextInput(
        value: widget.value,
        placeholder: widget.placeholder,
        disabled: widget.disabled,
        debounceDuration: const Duration(milliseconds: 0),
        onChanged: _onChanged,
        onFocusChanged: (focused) => setState(() => _isFocused = focused),
        focusNode: _effectiveFocusNode,
      ),
    );
  }

  Widget _buildMultilineInput(BuildContext context, bool hasError) {
    final borderColor = EditorColors.getBorderColor(
      context,
      hasError: hasError,
      disabled: widget.disabled,
      focused: _isFocused,
      hovered: isHovered,
    );

    final effectiveMinLines = widget.minLines ?? 1;
    final minHeight = effectiveMinLines * EditorSpacing.lineHeight;

    return MouseRegion(
      onEnter: onHoverEnter,
      onExit: onHoverExit,
      child: Container(
        constraints: BoxConstraints(
          minHeight:
              (widget.minLines != null || widget.maxLines != 1)
                  ? minHeight
                  : editorHeight,
          maxHeight: widget.maxLines * EditorSpacing.lineHeight + 18,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(editorBorderRadius(context)),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: BaseTextInput(
          value: widget.value,
          placeholder: widget.placeholder,
          disabled: widget.disabled,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          debounceDuration: const Duration(milliseconds: 0),
          onChanged: _onChanged,
          onFocusChanged: (focused) => setState(() => _isFocused = focused),
        ),
      ),
    );
  }
}
