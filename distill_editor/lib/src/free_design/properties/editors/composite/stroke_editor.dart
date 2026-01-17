import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../primitives/number_editor.dart';
import '../primitives/button_editor.dart';
import '../slots/editor_prefixes.dart';
import '../pickers/color_picker_menu.dart';
import 'stroke_value.dart';

/// A composite editor for stroke/border values.
///
/// Features:
/// - Color picker with swatch preview
/// - Width number input
/// - Can clear stroke to remove it
///
/// Usage:
/// ```dart
/// StrokeEditor(
///   value: StrokeValue.fromJson(node.style.stroke?.toJson() ?? {}),
///   onChanged: (value) {
///     store.updateNodeProp(
///       nodeId,
///       '/style/stroke',
///       value.isEmpty ? null : value.toJson(),
///     );
///   },
/// )
/// ```
class StrokeEditor extends StatefulWidget {
  final StrokeValue value;
  final ValueChanged<StrokeValue>? onChanged;
  final bool disabled;

  const StrokeEditor({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
  });

  @override
  State<StrokeEditor> createState() => _StrokeEditorState();
}

class _StrokeEditorState extends State<StrokeEditor> {
  late StrokeValue _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(StrokeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value = widget.value;
    }
  }

  void _updateValue(StrokeValue newValue) {
    setState(() => _value = newValue);
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    if (_value.isEmpty) {
      // Show "None" button that opens to add stroke
      return ButtonEditor(
        displayValue: null,
        placeholder: 'None',
        onTap: () {
          // Set default stroke (black, 1px)
          _updateValue(StrokeValue.solid(color: Colors.black, width: 1.0));
        },
        disabled: widget.disabled,
      );
    }

    // Show color + width inputs
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color picker
        ColorPickerPopover(
          initialColor: _value.color ?? Colors.black,
          onChanged: (color) {
            _updateValue(_value.copyWith(color: color));
          },
          child: ButtonEditor(
            displayValue: _colorToHex(_value.color!),
            prefix: ColorSwatchPrefix(color: _value.color),
            onClear: () {
              // Clear stroke
              _updateValue(const StrokeValue.none());
            },
            disabled: widget.disabled,
          ),
        ),
        SizedBox(height: context.spacing.xs),

        // Width input
        NumberEditor(
          value: _value.width,
          onChanged: (value) {
            final width = (value ?? 0).toDouble();
            if (width == 0) {
              // Zero width = remove stroke
              _updateValue(const StrokeValue.none());
            } else {
              _updateValue(_value.copyWith(width: width));
            }
          },
          placeholder: 'Width',
          disabled: widget.disabled,
          allowDecimals: true,
          min: 0,
        ),
      ],
    );
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
