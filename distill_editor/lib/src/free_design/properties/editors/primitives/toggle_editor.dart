import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../core/editor_styling.dart';

/// A generic toggle editor using segmented control with icons.
///
/// Each option maps to an icon. Supports tooltips and custom icon widgets.
///
/// Features:
/// - Segmented control with icon-based options
/// - Optional tooltips for each option
/// - Optional custom icon widgets
/// - 28px height matching other editors
/// - Clicking selected option clears value (unless required)
///
/// Example usage:
/// ```dart
/// ToggleEditor<String>(
///   value: 'left',
///   options: {
///     'left': Icons.align_horizontal_left,
///     'center': Icons.align_horizontal_center,
///     'right': Icons.align_horizontal_right,
///   },
///   optionLabels: {
///     'left': 'Left',
///     'center': 'Center',
///     'right': 'Right',
///   },
///   onChanged: (value) => store.updateNodeProp(nodeId, '/alignment', value),
/// )
/// ```
///
/// See also:
/// - [BooleanEditor] for true/false values
/// - [DropdownEditor] for selection from options with labels
class ToggleEditor<T> extends StatelessWidget {
  /// Current selected value.
  final T? value;

  /// Map of option values to their icons.
  final Map<T, IconData> options;

  /// Called when the value changes.
  final ValueChanged<T?>? onChanged;

  /// Optional labels for tooltips (keyed by option value).
  /// If not provided, uses toString() of the value.
  final Map<T, String>? optionLabels;

  /// Optional custom icon widgets (keyed by option value).
  /// If set for an option, takes precedence over the IconData icon.
  final Map<T, Widget>? customIcons;

  /// Whether the input is disabled.
  final bool disabled;

  /// Whether a value is required (prevents deselection to null).
  final bool required;

  const ToggleEditor({
    super.key,
    this.value,
    required this.options,
    this.onChanged,
    this.optionLabels,
    this.customIcons,
    this.disabled = false,
    this.required = false,
  });

  Set<T> get _selectedValues {
    if (value != null && options.containsKey(value)) {
      return {value!};
    }

    // Fallback to first option if required
    if (options.isNotEmpty && required && value == null) {
      return {options.keys.first};
    }

    return <T>{};
  }

  void _handleSelectionChanged(Set<dynamic> selectedValues) {
    // Handle unselecting the current value
    if (!required &&
        selectedValues.length == 1 &&
        selectedValues.first == value) {
      onChanged?.call(null);
      return;
    }

    final newValue = selectedValues.isNotEmpty
        ? selectedValues.first as T
        : null;
    onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: editorHeight,
      child: SegmentedControl<T>(
        heightOverride: editorHeight,
        gapOverride: 2,
        showElevation: false,
        items: options.entries.map((entry) {
          final label = optionLabels?[entry.key] ?? entry.key.toString();
          return SegmentedControlItem<T>(
            value: entry.key,
            icon: entry.value,
            iconWidget: customIcons?[entry.key],
            tooltip: HologramTooltip(
              message: label,
              child: const SizedBox.shrink(),
            ),
          );
        }).toList(),
        selectedValues: _selectedValues,
        onChanged: disabled ? (_) {} : _handleSelectionChanged,
      ),
    );
  }
}
