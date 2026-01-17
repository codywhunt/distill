import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../core/editor_styling.dart';

/// A boolean input editor using segmented control.
///
/// Features:
/// - Segmented control with True/False options
/// - Supports text labels or icons
/// - Clicking the selected option clears the value (sets to null)
/// - 28px height matching other editors
///
/// Usage:
/// ```dart
/// BooleanEditor(
///   value: true,
///   onChanged: (value) => store.updateNodeProp(nodeId, '/props/visible', value),
///   trueLabel: 'Yes',
///   falseLabel: 'No',
/// )
/// ```
///
/// Or with icons:
/// ```dart
/// BooleanEditor(
///   value: true,
///   onChanged: (value) => store.updateNodeProp(nodeId, '/props/enabled', value),
///   trueIcon: Icons.check,
///   falseIcon: Icons.close,
/// )
/// ```
///
/// See also:
/// - [NumberEditor] for numeric input
/// - [TextEditor] for text input
/// - [DropdownEditor] for selection from options
class BooleanEditor extends StatelessWidget {
  /// Current boolean value (null means unset).
  final bool? value;

  /// Called when the value changes (null means cleared).
  final ValueChanged<bool?>? onChanged;

  /// Label for the true state.
  final String trueLabel;

  /// Label for the false state.
  final String falseLabel;

  /// Icon for the true state (optional).
  final IconData? trueIcon;

  /// Icon for the false state (optional).
  final IconData? falseIcon;

  /// Whether the input is disabled.
  final bool disabled;

  const BooleanEditor({
    super.key,
    this.value,
    this.onChanged,
    this.trueLabel = 'True',
    this.falseLabel = 'False',
    this.trueIcon,
    this.falseIcon,
    this.disabled = false,
  });

  bool get _useIcons => trueIcon != null && falseIcon != null;

  String? get _selectedValue {
    if (value == null) return null;
    return value! ? 'true' : 'false';
  }

  Set<String> get _selectedValues {
    final selected = _selectedValue;
    if (selected == null) return <String>{};
    return <String>{selected};
  }

  void _handleSelectionChanged(Set<dynamic> selectedValues) {
    if (selectedValues.isEmpty) {
      onChanged?.call(null);
      return;
    }

    final selectedValue = selectedValues.first as String;

    // If clicking the already-selected option, clear the value
    if (selectedValue == _selectedValue) {
      onChanged?.call(null);
      return;
    }

    final boolValue = selectedValue == 'true';
    onChanged?.call(boolValue);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: editorHeight,
      child: SegmentedControl<String>(
        heightOverride: editorHeight,
        showElevation: false,
        gapOverride: 2,
        items: _useIcons
            ? [
                SegmentedControlItem<String>(
                  value: 'false',
                  icon: falseIcon,
                  tooltip: HologramTooltip(
                    message: falseLabel,
                    child: const SizedBox.shrink(),
                  ),
                ),
                SegmentedControlItem<String>(
                  value: 'true',
                  icon: trueIcon,
                  tooltip: HologramTooltip(
                    message: trueLabel,
                    child: const SizedBox.shrink(),
                  ),
                ),
              ]
            : [
                SegmentedControlItem<String>(label: trueLabel, value: 'true'),
                SegmentedControlItem<String>(label: falseLabel, value: 'false'),
              ],
        selectedValues: _selectedValues,
        onChanged: disabled ? (_) {} : _handleSelectionChanged,
      ),
    );
  }
}
