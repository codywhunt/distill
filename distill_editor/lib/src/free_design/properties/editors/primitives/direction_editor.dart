import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../../models/node_layout.dart';
import '../core/editor_styling.dart';

/// A direction selector editor using segmented control with icons.
///
/// Features:
/// - Segmented control with Horizontal/Vertical options
/// - Icon-based visualization (view_column for horizontal, view_agenda for vertical)
/// - 28px height matching other editors
/// - Tooltips for each direction
///
/// Usage:
/// ```dart
/// DirectionEditor(
///   value: LayoutDirection.horizontal,
///   onChanged: (direction) => store.updateNodeProp(
///     nodeId,
///     '/layout/autoLayout/direction',
///     direction.name,
///   ),
/// )
/// ```
///
/// See also:
/// - [BooleanEditor] for true/false values
/// - [DropdownEditor] for selection from options
class DirectionEditor extends StatelessWidget {
  /// Current layout direction.
  final LayoutDirection value;

  /// Called when the direction changes.
  final ValueChanged<LayoutDirection>? onChanged;

  /// Whether the input is disabled.
  final bool disabled;

  const DirectionEditor({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
  });

  String get _selectedValue {
    return value == LayoutDirection.horizontal ? 'horizontal' : 'vertical';
  }

  Set<String> get _selectedValues {
    return <String>{_selectedValue};
  }

  void _handleSelectionChanged(Set<dynamic> selectedValues) {
    if (selectedValues.isEmpty) return;

    final selectedValue = selectedValues.first as String;
    final newDirection = selectedValue == 'horizontal'
        ? LayoutDirection.horizontal
        : LayoutDirection.vertical;

    onChanged?.call(newDirection);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: editorHeight,
      child: SegmentedControl<String>(
        heightOverride: editorHeight,
        showElevation: false,
        gapOverride: 2,
        items: [
          SegmentedControlItem<String>(
            value: 'horizontal',
            icon: Icons.view_column.holo,
            tooltip: HologramTooltip(
              message: 'Horizontal',
              child: const SizedBox.shrink(),
            ),
          ),
          SegmentedControlItem<String>(
            value: 'vertical',
            icon: Icons.view_agenda.holo,
            tooltip: HologramTooltip(
              message: 'Vertical',
              child: const SizedBox.shrink(),
            ),
          ),
        ],
        selectedValues: _selectedValues,
        onChanged: disabled ? (_) {} : _handleSelectionChanged,
      ),
    );
  }
}
