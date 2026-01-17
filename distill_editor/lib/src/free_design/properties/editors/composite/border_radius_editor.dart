import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../core/editor_input_container.dart';
import '../core/editor_styling.dart';
import '../primitives/number_editor.dart';
import 'border_radius_value.dart';

/// A composite editor for border radius values with intelligent mode cycling.
///
/// Features:
/// - Two modes: all, only
/// - Smart mode detection from JSON (auto-collapses to simplest mode)
/// - Mode cycling via suffix button
/// - Expandable detail inputs for only mode (4 corners)
/// - Uses batch updates for mode transitions
///
/// Usage:
/// ```dart
/// BorderRadiusEditor(
///   value: BorderRadiusValue.fromJson(node.style.cornerRadius?.toJson() ?? {}),
///   onChanged: (value) {
///     final json = value.toJson();
///     store.updateNodeProps(nodeId, {
///       '/style/cornerRadius/topLeft': json['topLeft'],
///       '/style/cornerRadius/topRight': json['topRight'],
///       '/style/cornerRadius/bottomLeft': json['bottomLeft'],
///       '/style/cornerRadius/bottomRight': json['bottomRight'],
///     });
///   },
/// )
/// ```
class BorderRadiusEditor extends StatefulWidget {
  final BorderRadiusValue value;
  final ValueChanged<BorderRadiusValue>? onChanged;
  final bool disabled;

  const BorderRadiusEditor({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
  });

  @override
  State<BorderRadiusEditor> createState() => _BorderRadiusEditorState();
}

class _BorderRadiusEditorState extends State<BorderRadiusEditor> {
  late BorderRadiusValue _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(BorderRadiusEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value = widget.value;
    }
  }

  void _updateValue(BorderRadiusValue newValue) {
    setState(() => _value = newValue);
    widget.onChanged?.call(newValue);
  }

  void _onModeChanged() {
    final nextMode = switch (_value.mode) {
      BorderRadiusMode.all => BorderRadiusMode.only,
      BorderRadiusMode.only => BorderRadiusMode.all,
    };

    final newValue = switch (nextMode) {
      BorderRadiusMode.all => BorderRadiusValue.all(
        _value.all ?? _value.topLeft ?? 0,
      ),
      BorderRadiusMode.only => BorderRadiusValue.only(
        topLeft: _value.topLeft ?? _value.all ?? 0,
        topRight: _value.topRight ?? _value.all ?? 0,
        bottomLeft: _value.bottomLeft ?? _value.all ?? 0,
        bottomRight: _value.bottomRight ?? _value.all ?? 0,
      ),
    };

    _updateValue(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Primary input
        _buildPrimaryInput(context),

        // Row 2: Detail inputs (only mode)
        if (_value.mode != BorderRadiusMode.all) ...[
          SizedBox(height: context.spacing.xs),
          _buildDetailRow(context),
        ],
      ],
    );
  }

  Widget _buildPrimaryInput(BuildContext context) {
    final suffix = _BorderRadiusModeSuffix(
      mode: _value.mode,
      onModeChanged: _onModeChanged,
      disabled: widget.disabled,
    );

    if (_value.mode == BorderRadiusMode.all) {
      return NumberEditor(
        value: _value.all,
        onChanged: (value) {
          _updateValue(BorderRadiusValue.all((value ?? 0).toDouble()));
        },
        suffix: suffix,
        placeholder: '-',
        disabled: widget.disabled,
        allowDecimals: true,
        min: 0,
      );
    }

    // Summary display for only mode
    return _SummaryInput(
      summary: _getSummary(),
      suffix: suffix,
      disabled: widget.disabled,
    );
  }

  String _getSummary() {
    final tl = _value.topLeft?.toStringAsFixed(0) ?? '-';
    final tr = _value.topRight?.toStringAsFixed(0) ?? '-';
    final bl = _value.bottomLeft?.toStringAsFixed(0) ?? '-';
    final br = _value.bottomRight?.toStringAsFixed(0) ?? '-';
    return '$tl, $tr, $bl, $br';
  }

  Widget _buildDetailRow(BuildContext context) {
    // Only mode - 2 rows of 2 inputs (TL, TR / BL, BR)
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: NumberEditor(
                value: _value.topLeft,
                onChanged: (value) {
                  _updateValue(
                    BorderRadiusValue.only(
                      topLeft: value?.toDouble(),
                      topRight: _value.topRight,
                      bottomLeft: _value.bottomLeft,
                      bottomRight: _value.bottomRight,
                    ),
                  );
                },
                placeholder: 'TL',
                disabled: widget.disabled,
                allowDecimals: true,
                min: 0,
              ),
            ),
            SizedBox(width: context.spacing.xxs),
            Expanded(
              child: NumberEditor(
                value: _value.topRight,
                onChanged: (value) {
                  _updateValue(
                    BorderRadiusValue.only(
                      topLeft: _value.topLeft,
                      topRight: value?.toDouble(),
                      bottomLeft: _value.bottomLeft,
                      bottomRight: _value.bottomRight,
                    ),
                  );
                },
                placeholder: 'TR',
                disabled: widget.disabled,
                allowDecimals: true,
                min: 0,
              ),
            ),
          ],
        ),
        SizedBox(height: context.spacing.xxs),
        Row(
          children: [
            Expanded(
              child: NumberEditor(
                value: _value.bottomLeft,
                onChanged: (value) {
                  _updateValue(
                    BorderRadiusValue.only(
                      topLeft: _value.topLeft,
                      topRight: _value.topRight,
                      bottomLeft: value?.toDouble(),
                      bottomRight: _value.bottomRight,
                    ),
                  );
                },
                placeholder: 'BL',
                disabled: widget.disabled,
                allowDecimals: true,
                min: 0,
              ),
            ),
            SizedBox(width: context.spacing.xxs),
            Expanded(
              child: NumberEditor(
                value: _value.bottomRight,
                onChanged: (value) {
                  _updateValue(
                    BorderRadiusValue.only(
                      topLeft: _value.topLeft,
                      topRight: _value.topRight,
                      bottomLeft: _value.bottomLeft,
                      bottomRight: value?.toDouble(),
                    ),
                  );
                },
                placeholder: 'BR',
                disabled: widget.disabled,
                allowDecimals: true,
                min: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Mode cycling suffix button.
class _BorderRadiusModeSuffix extends StatelessWidget {
  final BorderRadiusMode mode;
  final VoidCallback onModeChanged;
  final bool disabled;

  const _BorderRadiusModeSuffix({
    required this.mode,
    required this.onModeChanged,
    this.disabled = false,
  });

  IconData get _icon {
    return switch (mode) {
      BorderRadiusMode.all => Icons.crop_square,
      BorderRadiusMode.only => Icons.grid_4x4,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onModeChanged,
      child: Icon(
        _icon,
        size: 14,
        color: disabled
            ? EditorColors.borderDisabled(context)
            : EditorColors.borderHovered(context),
      ),
    );
  }
}

/// Summary input for only mode.
class _SummaryInput extends StatelessWidget {
  final String summary;
  final Widget suffix;
  final bool disabled;

  const _SummaryInput({
    required this.summary,
    required this.suffix,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return EditorInputContainer(
      suffix: suffix,
      disabled: disabled,
      child: Padding(
        padding: EditorSpacing.horizontal,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            summary,
            style: EditorTextStyles.input(context, disabled: disabled),
          ),
        ),
      ),
    );
  }
}
