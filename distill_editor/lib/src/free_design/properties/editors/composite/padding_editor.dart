import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../core/editor_input_container.dart';
import '../core/editor_styling.dart';
import '../primitives/number_editor.dart';
import 'padding_value.dart';

/// A composite editor for padding values with intelligent mode cycling.
///
/// Features:
/// - Three modes: all, symmetric, only
/// - Smart mode detection from JSON (auto-collapses to simplest mode)
/// - Mode cycling via suffix button
/// - Expandable detail inputs for symmetric/only modes
/// - Uses batch updates for mode transitions
///
/// Usage:
/// ```dart
/// PaddingEditor(
///   value: PaddingValue.fromJson(node.style.padding?.toJson() ?? {}),
///   onChanged: (value) {
///     final json = value.toJson();
///     store.updateNodeProps(nodeId, {
///       '/style/padding/left': json['left'],
///       '/style/padding/top': json['top'],
///       '/style/padding/right': json['right'],
///       '/style/padding/bottom': json['bottom'],
///     });
///   },
/// )
/// ```
class PaddingEditor extends StatefulWidget {
  final PaddingValue value;
  final ValueChanged<PaddingValue>? onChanged;
  final bool disabled;

  const PaddingEditor({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
  });

  @override
  State<PaddingEditor> createState() => _PaddingEditorState();
}

class _PaddingEditorState extends State<PaddingEditor> {
  late PaddingValue _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(PaddingEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value = widget.value;
    }
  }

  void _updateValue(PaddingValue newValue) {
    setState(() => _value = newValue);
    widget.onChanged?.call(newValue);
  }

  void _onModeChanged() {
    final nextMode = switch (_value.mode) {
      PaddingMode.all => PaddingMode.symmetric,
      PaddingMode.symmetric => PaddingMode.only,
      PaddingMode.only => PaddingMode.all,
    };

    final newValue = switch (nextMode) {
      PaddingMode.all => PaddingValue.all(
        _value.all ?? _value.horizontal ?? _value.left ?? 0,
      ),
      PaddingMode.symmetric => PaddingValue.symmetric(
        horizontal: _value.horizontal ?? _value.all ?? _value.left ?? 0,
        vertical: _value.vertical ?? _value.all ?? _value.top ?? 0,
      ),
      PaddingMode.only => PaddingValue.only(
        left: _value.left ?? _value.horizontal ?? _value.all ?? 0,
        top: _value.top ?? _value.vertical ?? _value.all ?? 0,
        right: _value.right ?? _value.horizontal ?? _value.all ?? 0,
        bottom: _value.bottom ?? _value.vertical ?? _value.all ?? 0,
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

        // Row 2: Detail inputs (symmetric/only modes)
        if (_value.mode != PaddingMode.all) ...[
          SizedBox(height: context.spacing.xs),
          _buildDetailRow(context),
        ],
      ],
    );
  }

  Widget _buildPrimaryInput(BuildContext context) {
    final suffix = _PaddingModeSuffix(
      mode: _value.mode,
      onModeChanged: _onModeChanged,
      disabled: widget.disabled,
    );

    if (_value.mode == PaddingMode.all) {
      return NumberEditor(
        value: _value.all,
        onChanged: (value) {
          _updateValue(PaddingValue.all((value ?? 0).toDouble()));
        },
        suffix: suffix,
        placeholder: '-',
        disabled: widget.disabled,
        allowDecimals: true,
        min: 0,
      );
    }

    // Summary display for symmetric/only modes
    return _SummaryInput(
      summary: _getSummary(),
      suffix: suffix,
      disabled: widget.disabled,
    );
  }

  String _getSummary() {
    if (_value.mode == PaddingMode.symmetric) {
      final h = _value.horizontal?.toStringAsFixed(0) ?? '-';
      final v = _value.vertical?.toStringAsFixed(0) ?? '-';
      return '$h, $v';
    }
    // Only mode
    final l = _value.left?.toStringAsFixed(0) ?? '-';
    final t = _value.top?.toStringAsFixed(0) ?? '-';
    final r = _value.right?.toStringAsFixed(0) ?? '-';
    final b = _value.bottom?.toStringAsFixed(0) ?? '-';
    return '$l, $t, $r, $b';
  }

  Widget _buildDetailRow(BuildContext context) {
    if (_value.mode == PaddingMode.symmetric) {
      return Row(
        children: [
          Expanded(
            child: NumberEditor(
              value: _value.horizontal,
              onChanged: (value) {
                _updateValue(
                  PaddingValue.symmetric(
                    horizontal: value?.toDouble(),
                    vertical: _value.vertical,
                  ),
                );
              },
              placeholder: 'H',
              disabled: widget.disabled,
              allowDecimals: true,
              min: 0,
            ),
          ),
          SizedBox(width: context.spacing.xxs),
          Expanded(
            child: NumberEditor(
              value: _value.vertical,
              onChanged: (value) {
                _updateValue(
                  PaddingValue.symmetric(
                    horizontal: _value.horizontal,
                    vertical: value?.toDouble(),
                  ),
                );
              },
              placeholder: 'V',
              disabled: widget.disabled,
              allowDecimals: true,
              min: 0,
            ),
          ),
        ],
      );
    }

    // Only mode - 2 rows of 2 inputs
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: NumberEditor(
                value: _value.left,
                onChanged: (value) {
                  _updateValue(
                    PaddingValue.only(
                      left: value?.toDouble(),
                      top: _value.top,
                      right: _value.right,
                      bottom: _value.bottom,
                    ),
                  );
                },
                placeholder: 'L',
                disabled: widget.disabled,
                allowDecimals: true,
                min: 0,
              ),
            ),
            SizedBox(width: context.spacing.xxs),
            Expanded(
              child: NumberEditor(
                value: _value.top,
                onChanged: (value) {
                  _updateValue(
                    PaddingValue.only(
                      left: _value.left,
                      top: value?.toDouble(),
                      right: _value.right,
                      bottom: _value.bottom,
                    ),
                  );
                },
                placeholder: 'T',
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
                value: _value.right,
                onChanged: (value) {
                  _updateValue(
                    PaddingValue.only(
                      left: _value.left,
                      top: _value.top,
                      right: value?.toDouble(),
                      bottom: _value.bottom,
                    ),
                  );
                },
                placeholder: 'R',
                disabled: widget.disabled,
                allowDecimals: true,
                min: 0,
              ),
            ),
            SizedBox(width: context.spacing.xxs),
            Expanded(
              child: NumberEditor(
                value: _value.bottom,
                onChanged: (value) {
                  _updateValue(
                    PaddingValue.only(
                      left: _value.left,
                      top: _value.top,
                      right: _value.right,
                      bottom: value?.toDouble(),
                    ),
                  );
                },
                placeholder: 'B',
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
class _PaddingModeSuffix extends StatelessWidget {
  final PaddingMode mode;
  final VoidCallback onModeChanged;
  final bool disabled;

  const _PaddingModeSuffix({
    required this.mode,
    required this.onModeChanged,
    this.disabled = false,
  });

  IconData get _icon {
    return switch (mode) {
      PaddingMode.all => Icons.crop_square,
      PaddingMode.symmetric => Icons.horizontal_rule,
      PaddingMode.only => Icons.grid_4x4,
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

/// Summary input for symmetric/only modes.
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
