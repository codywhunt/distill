import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// Dropdown input for property panel.
class PropertyDropdownInput<T> extends StatelessWidget {
  const PropertyDropdownInput({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<HoloSelectItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return HoloSelect<T>(
      value: value,
      items: items,
      expand: true,
      onChanged: (v) {
        if (v != null) {
          onChanged(v);
        }
      },
    );
  }
}
