import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../core/editor_styling.dart';

/// A dropdown item for selection.
class DropdownItem<T> {
  /// The value associated with this item.
  final T value;

  /// The display label.
  final String label;

  /// Optional description/subtitle.
  final String? description;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether this item is disabled.
  final bool isDisabled;

  const DropdownItem({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.isDisabled = false,
  });
}

/// A dropdown editor for selecting from a list of options.
///
/// Features:
/// - Generic type support for any value type
/// - Optional icon and description per item
/// - Keyboard navigation (arrow keys, Enter, Escape)
/// - 28px height matching other editors
/// - Full expansion to fill container width
///
/// Usage:
/// ```dart
/// DropdownEditor<AlignmentType>(
///   value: AlignmentType.center,
///   items: [
///     DropdownItem(
///       value: AlignmentType.start,
///       label: 'Start',
///       icon: Icons.align_horizontal_left,
///     ),
///     DropdownItem(
///       value: AlignmentType.center,
///       label: 'Center',
///       icon: Icons.align_horizontal_center,
///     ),
///     DropdownItem(
///       value: AlignmentType.end,
///       label: 'End',
///       icon: Icons.align_horizontal_right,
///     ),
///   ],
///   onChanged: (value) => store.updateNodeProp(nodeId, '/layout/alignment', value?.name),
/// )
/// ```
///
/// See also:
/// - [NumberEditor] for numeric input
/// - [TextEditor] for text input
/// - [BooleanEditor] for true/false values
class DropdownEditor<T> extends StatelessWidget {
  /// Current selected value.
  final T? value;

  /// Available items to select from.
  final List<DropdownItem<T>> items;

  /// Called when the value changes.
  final ValueChanged<T?>? onChanged;

  /// Placeholder text when no value is selected.
  final String? placeholder;

  /// Whether the input is disabled.
  final bool disabled;

  const DropdownEditor({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.placeholder,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    // Convert DropdownItem to HoloSelectItem
    final holoItems = items.map((item) {
      return HoloSelectItem<T>(
        value: item.value,
        label: item.label,
        subtitle: item.description,
        icon: item.icon,
        isDisabled: item.isDisabled,
        disabledReason: item.isDisabled ? item.description : null,
      );
    }).toList();

    return SizedBox(
      height: editorHeight,
      child: HoloSelect<T>(
        value: value,
        items: holoItems,
        onChanged: disabled ? (_) {} : (value) => onChanged?.call(value),
        placeholder: placeholder ?? 'Select...',
        isDisabled: disabled,
        expand: true, // Fill container width
        maxHeight: 300,
      ),
    );
  }
}
