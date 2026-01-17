import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/base_text_input.dart';
import '../core/editor_input_container.dart';
import '../core/validation.dart';

/// A number input editor with optional constraints and suffix.
///
/// Features:
/// - Integer or decimal input based on [allowDecimals]
/// - Optional min/max value constraints
/// - Optional suffix widget (e.g., units like "px")
/// - Debounced updates during typing (300ms)
/// - Immediate update on blur/submit
/// - Optional validation
///
/// Usage:
/// ```dart
/// NumberEditor(
///   value: 16.0,
///   onChanged: (value) => store.updateNodeProp(nodeId, '/style/width', value),
///   min: 0,
///   max: 100,
///   suffix: Text('px'),
///   validator: Validators.range(0, 100),
/// )
/// ```
///
/// See also:
/// - [TextEditor] for text input
/// - [BooleanEditor] for true/false values
/// - [DropdownEditor] for selection from options
class NumberEditor extends StatefulWidget {
  /// Current numeric value.
  final num? value;

  /// Called when the value changes.
  final ValueChanged<num?>? onChanged;

  /// Minimum allowed value.
  final num? min;

  /// Maximum allowed value.
  final num? max;

  /// Suffix widget (e.g., units text).
  final Widget? suffix;

  /// Prefix widget (e.g., icon).
  final Widget? prefix;

  /// Whether to allow decimal values.
  final bool allowDecimals;

  /// Whether the input is disabled.
  final bool disabled;

  /// Placeholder text when empty.
  final String? placeholder;

  /// Optional validator for the value.
  final Validator<num>? validator;

  /// Optional external focus node.
  final FocusNode? focusNode;

  const NumberEditor({
    super.key,
    this.value,
    this.onChanged,
    this.min,
    this.max,
    this.suffix,
    this.prefix,
    this.allowDecimals = true,
    this.disabled = false,
    this.placeholder,
    this.validator,
    this.focusNode,
  });

  @override
  State<NumberEditor> createState() => _NumberEditorState();
}

class _NumberEditorState extends State<NumberEditor> {
  bool _isFocused = false;
  ValidationResult? _validationResult;

  List<TextInputFormatter> get _inputFormatters {
    if (widget.allowDecimals) {
      return [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))];
    }
    return [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))];
  }

  String _formatValue(num? value) {
    if (value == null) return '';
    if (value.isInfinite) return 'Infinity';
    if (!widget.allowDecimals) return value.toInt().toString();
    // Remove trailing zeros for cleaner display
    final str = value.toString();
    if (str.contains('.')) {
      return str.replaceAll(RegExp(r'\.?0+$'), '');
    }
    return str;
  }

  num? _parseValue(String text) {
    if (text.isEmpty) return null;
    if (text.toLowerCase() == 'infinity') return double.infinity;
    if (widget.allowDecimals) {
      return double.tryParse(text);
    }
    return int.tryParse(text);
  }

  num? _constrainValue(num? value) {
    if (value == null) return null;

    num constrained = value;
    if (widget.min != null && value < widget.min!) {
      constrained = widget.min!;
    }
    if (widget.max != null && value > widget.max!) {
      constrained = widget.max!;
    }
    return constrained;
  }

  void _onChanged(String text) {
    final parsed = _parseValue(text);
    final constrained = _constrainValue(parsed);

    // Validate if validator is provided
    if (widget.validator != null) {
      final result = widget.validator!(constrained);
      setState(() => _validationResult = result);
      if (!result.isValid) {
        return; // Don't emit invalid values
      }
    }

    widget.onChanged?.call(constrained);
  }

  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _validationResult != null && !_validationResult!.isValid;

    return EditorInputContainer(
      prefix: widget.prefix,
      suffix: widget.suffix,
      focused: _isFocused,
      disabled: widget.disabled,
      hasError: hasError,
      focusNode: _effectiveFocusNode,
      child: BaseTextInput(
        value: _formatValue(widget.value),
        placeholder: widget.placeholder,
        textAlign: TextAlign.left,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.allowDecimals,
          signed: true,
        ),
        inputFormatters: _inputFormatters,
        disabled: widget.disabled,
        debounceDuration: const Duration(milliseconds: 0),
        onChanged: _onChanged,
        onFocusChanged: (focused) => setState(() => _isFocused = focused),
        focusNode: _effectiveFocusNode,
      ),
    );
  }
}
