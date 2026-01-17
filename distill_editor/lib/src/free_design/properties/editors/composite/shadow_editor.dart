import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../primitives/number_editor.dart';
import '../primitives/button_editor.dart';
import '../slots/editor_prefixes.dart';
import '../pickers/color_picker_menu.dart';
import 'shadow_value.dart';

/// A composite editor for shadow values.
///
/// Features:
/// - Color picker with swatch preview
/// - Y offset (most common) and blur inputs
/// - Expandable advanced section for X offset and spread
/// - Can clear shadow to remove it
///
/// Usage:
/// ```dart
/// ShadowEditor(
///   value: ShadowValue.fromJson(node.style.shadow?.toJson() ?? {}),
///   onChanged: (value) {
///     store.updateNodeProp(
///       nodeId,
///       '/style/shadow',
///       value.isEmpty ? null : value.toJson(),
///     );
///   },
/// )
/// ```
class ShadowEditor extends StatefulWidget {
  final ShadowValue value;
  final ValueChanged<ShadowValue>? onChanged;
  final bool disabled;

  const ShadowEditor({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
  });

  @override
  State<ShadowEditor> createState() => _ShadowEditorState();
}

class _ShadowEditorState extends State<ShadowEditor> {
  late ShadowValue _value;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    // Auto-expand advanced if X offset or spread are non-default
    _showAdvanced = _value.offsetX != 0.0 || _value.spread != 0.0;
  }

  @override
  void didUpdateWidget(ShadowEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value = widget.value;
    }
  }

  void _updateValue(ShadowValue newValue) {
    setState(() => _value = newValue);
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    if (_value.isEmpty) {
      // Show "None" button that opens to add shadow
      return ButtonEditor(
        displayValue: null,
        placeholder: 'None',
        onTap: () {
          // Set default shadow (black with 20% opacity, Y offset 4, blur 8)
          _updateValue(
            ShadowValue.dropShadow(
              color: Colors.black.withValues(alpha: 0.2),
              offsetY: 4.0,
              blur: 8.0,
            ),
          );
        },
        disabled: widget.disabled,
      );
    }

    // Show color + basic inputs
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Color picker
        ColorPickerPopover(
          initialColor: _value.color ?? Colors.black.withValues(alpha: 0.2),
          onChanged: (color) {
            _updateValue(_value.copyWith(color: color));
          },
          child: ButtonEditor(
            displayValue: _colorToHex(_value.color!),
            prefix: ColorSwatchPrefix(color: _value.color),
            onClear: () {
              // Clear shadow
              _updateValue(const ShadowValue.none());
            },
            disabled: widget.disabled,
          ),
        ),
        SizedBox(height: context.spacing.xs),

        // Y offset and Blur (most common controls)
        Row(
          children: [
            Expanded(
              child: NumberEditor(
                value: _value.offsetY,
                onChanged: (value) {
                  _updateValue(
                    _value.copyWith(offsetY: (value ?? 0.0).toDouble()),
                  );
                },
                placeholder: 'Y',
                disabled: widget.disabled,
                allowDecimals: true,
              ),
            ),
            SizedBox(width: context.spacing.xxs),
            Expanded(
              child: NumberEditor(
                value: _value.blur,
                onChanged: (value) {
                  final blur = (value ?? 0.0).toDouble();
                  if (blur == 0 && _value.spread == 0) {
                    // Zero blur and spread = remove shadow
                    _updateValue(const ShadowValue.none());
                  } else {
                    _updateValue(_value.copyWith(blur: blur));
                  }
                },
                placeholder: 'Blur',
                disabled: widget.disabled,
                allowDecimals: true,
                min: 0,
              ),
            ),
          ],
        ),

        // Advanced toggle
        if (!_showAdvanced) ...[
          SizedBox(height: context.spacing.xs),
          GestureDetector(
            onTap: () => setState(() => _showAdvanced = true),
            child: Text(
              'Advanced',
              style: TextStyle(
                fontSize: 11,
                color: context.isDarkMode
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.5),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],

        // Advanced inputs (X offset and spread)
        if (_showAdvanced) ...[
          SizedBox(height: context.spacing.xs),
          Row(
            children: [
              Expanded(
                child: NumberEditor(
                  value: _value.offsetX,
                  onChanged: (value) {
                    _updateValue(
                      _value.copyWith(offsetX: (value ?? 0.0).toDouble()),
                    );
                  },
                  placeholder: 'X',
                  disabled: widget.disabled,
                  allowDecimals: true,
                ),
              ),
              SizedBox(width: context.spacing.xxs),
              Expanded(
                child: NumberEditor(
                  value: _value.spread,
                  onChanged: (value) {
                    final spread = (value ?? 0.0).toDouble();
                    if (spread == 0 && _value.blur == 0) {
                      // Zero blur and spread = remove shadow
                      _updateValue(const ShadowValue.none());
                    } else {
                      _updateValue(_value.copyWith(spread: spread));
                    }
                  },
                  placeholder: 'Spread',
                  disabled: widget.disabled,
                  allowDecimals: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
