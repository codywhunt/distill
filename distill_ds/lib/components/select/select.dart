import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distill_ds/design_system.dart';

/// An item in a select dropdown.
class HoloSelectItem<T> {
  /// The value associated with this item.
  final T value;

  /// The display label.
  final String label;

  /// Optional secondary text (e.g., dimensions).
  final String? subtitle;

  /// Optional leading icon.
  final IconData? icon;

  /// Whether this item is disabled and cannot be selected.
  final bool isDisabled;

  /// Reason why the item is disabled (shown in tooltip).
  final String? disabledReason;

  const HoloSelectItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.isDisabled = false,
    this.disabledReason,
  });
}

/// A group of select items with an optional header.
class HoloSelectGroup<T> {
  /// Optional group header label.
  final String? label;

  /// The items in this group.
  final List<HoloSelectItem<T>> items;

  const HoloSelectGroup({this.label, required this.items});
}

/// Signature for building a custom item widget in [HoloSelect].
///
/// The [item] is the select item being built.
/// [isSelected] is true if this item is the currently selected value.
/// [isHighlighted] is true if this item is focused/hovered.
typedef HoloSelectItemBuilder<T> =
    Widget Function(
      BuildContext context,
      HoloSelectItem<T> item,
      bool isSelected,
      bool isHighlighted,
    );

/// A select/dropdown component with full accessibility support.
///
/// Features:
/// - Keyboard navigation (arrow keys, Enter, Escape)
/// - Type-ahead search (optional)
/// - Grouped items with headers
/// - Checkmark for selected item
/// - Custom item builder support
///
/// Example:
/// ```dart
/// HoloSelect<String>(
///   value: selectedDevice,
///   onChanged: (value) => setState(() => selectedDevice = value),
///   items: [
///     HoloSelectItem(value: 'iphone-16', label: 'iPhone 16'),
///     HoloSelectItem(value: 'iphone-se', label: 'iPhone SE'),
///   ],
///   placeholder: 'Select device',
///   leadingIcon: LucideIcons.smartphone,
/// )
/// ```
///
/// With groups:
/// ```dart
/// HoloSelect<String>.grouped(
///   value: selectedDevice,
///   onChanged: (value) => setState(() => selectedDevice = value),
///   groups: [
///     HoloSelectGroup(label: 'Phones', items: [...]),
///     HoloSelectGroup(label: 'Tablets', items: [...]),
///   ],
/// )
/// ```
class HoloSelect<T> extends StatefulWidget {
  /// The currently selected value.
  final T? value;

  /// Called when the selection changes.
  final ValueChanged<T?> onChanged;

  /// The items to display (for simple lists).
  final List<HoloSelectItem<T>>? items;

  /// Grouped items (for categorized lists).
  final List<HoloSelectGroup<T>>? groups;

  /// Placeholder text when no value is selected.
  final String? placeholder;

  /// Leading icon for the trigger button.
  final IconData? leadingIcon;

  /// Width of the trigger button.
  final double? triggerWidth;

  /// Width of the dropdown menu.
  final double? menuWidth;

  /// Maximum height of the dropdown before scrolling.
  final double? maxHeight;

  /// Whether the select is disabled.
  final bool isDisabled;

  /// Optional custom builder for item widgets.
  ///
  /// When provided, this builder is used instead of the default item rendering.
  /// The builder receives the item, selection state, and highlight state.
  final HoloSelectItemBuilder<T>? itemBuilder;

  /// Whether the trigger should expand to fill available width.
  ///
  /// When true, the label and chevron are spaced apart (label left, chevron right).
  /// When false (default), the trigger sizes to fit content with minimal gap.
  ///
  /// Use `expand: true` in contexts like property panels where the trigger
  /// should fill its container.
  final bool expand;

  /// Creates a simple select with a flat list of items.
  const HoloSelect({
    super.key,
    required this.value,
    required this.onChanged,
    required List<HoloSelectItem<T>> this.items,
    this.placeholder,
    this.leadingIcon,
    this.triggerWidth,
    this.menuWidth,
    this.maxHeight = 600,
    this.isDisabled = false,
    this.itemBuilder,
    this.expand = false,
  }) : groups = null;

  /// Creates a select with grouped items.
  const HoloSelect.grouped({
    super.key,
    required this.value,
    required this.onChanged,
    required List<HoloSelectGroup<T>> this.groups,
    this.placeholder,
    this.leadingIcon,
    this.triggerWidth,
    this.menuWidth,
    this.maxHeight = 600,
    this.isDisabled = false,
    this.itemBuilder,
    this.expand = false,
  }) : items = null;

  @override
  State<HoloSelect<T>> createState() => _HoloSelectState<T>();
}

class _HoloSelectState<T> extends State<HoloSelect<T>> {
  final HoloPopoverController _popoverController = HoloPopoverController();
  final FocusNode _menuFocusNode = FocusNode(debugLabel: 'HoloSelectMenu');
  int _focusedIndex = -1;

  List<HoloSelectItem<T>> get _allItems {
    if (widget.items != null) return widget.items!;
    if (widget.groups != null) {
      return widget.groups!.expand((g) => g.items).toList();
    }
    return [];
  }

  HoloSelectItem<T>? get _selectedItem {
    if (widget.value == null) return null;
    try {
      return _allItems.firstWhere((item) => item.value == widget.value);
    } catch (_) {
      return null;
    }
  }

  String get _displayLabel {
    final selected = _selectedItem;
    if (selected != null) return selected.label;
    return widget.placeholder ?? 'Select...';
  }

  IconData? get _displayIcon {
    return _selectedItem?.icon ?? widget.leadingIcon;
  }

  @override
  void initState() {
    super.initState();
    _popoverController.addListener(_handlePopoverChange);
  }

  @override
  void dispose() {
    _popoverController.removeListener(_handlePopoverChange);
    _popoverController.dispose();
    _menuFocusNode.dispose();
    super.dispose();
  }

  void _handlePopoverChange() {
    if (_popoverController.isOpen) {
      // Focus the menu and highlight the selected item
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _menuFocusNode.requestFocus();
        final selectedIndex = _allItems.indexWhere(
          (item) => item.value == widget.value,
        );
        if (selectedIndex >= 0) {
          setState(() => _focusedIndex = selectedIndex);
        }
      });
    } else {
      setState(() => _focusedIndex = -1);
    }
  }

  void _selectItem(HoloSelectItem<T> item) {
    if (item.isDisabled) return;
    widget.onChanged(item.value);
    _popoverController.hide();
  }

  void _moveFocus(int delta) {
    final items = _allItems;
    if (items.isEmpty) return;

    int newIndex;
    if (_focusedIndex < 0) {
      // Find first non-disabled item
      newIndex =
          delta > 0
              ? items.indexWhere((i) => !i.isDisabled)
              : items.lastIndexWhere((i) => !i.isDisabled);
      if (newIndex < 0) return; // All disabled
    } else {
      // Find next non-disabled item in direction
      newIndex = _focusedIndex;
      int attempts = 0;
      do {
        newIndex = (newIndex + delta) % items.length;
        if (newIndex < 0) newIndex = items.length - 1;
        attempts++;
      } while (items[newIndex].isDisabled && attempts < items.length);

      if (items[newIndex].isDisabled) return; // All disabled
    }

    setState(() => _focusedIndex = newIndex);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _moveFocus(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _moveFocus(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        if (_focusedIndex >= 0 && _focusedIndex < _allItems.length) {
          final item = _allItems[_focusedIndex];
          if (!item.isDisabled) {
            _selectItem(item);
          }
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _popoverController.hide();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        setState(() => _focusedIndex = 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        setState(() => _focusedIndex = _allItems.length - 1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoloPopover(
      controller: _popoverController,
      anchor: HoloPopoverAnchor.bottomLeft,
      offset: const Offset(0, 4),
      popoverBuilder: (context) => _buildMenu(context),
      child: HoloSelectTrigger(
        label: _displayLabel,
        leadingIcon: _displayIcon,
        isOpen: _popoverController.isOpen,
        isDisabled: widget.isDisabled,
        isPlaceholder: _selectedItem == null,
        width: widget.triggerWidth,
        expand: widget.expand,
        onTap: widget.isDisabled ? null : _popoverController.toggle,
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final colors = context.colors;

    Widget content;
    if (widget.groups != null) {
      content = _buildGroupedContent(context);
    } else {
      content = _buildFlatContent(context);
    }

    return Focus(
      focusNode: _menuFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        width: widget.menuWidth ?? widget.triggerWidth,
        constraints: BoxConstraints(
          minWidth: widget.menuWidth ?? widget.triggerWidth ?? 160,
          maxHeight: widget.maxHeight ?? 300,
        ),
        decoration: BoxDecoration(
          color: colors.background.fullContrast,
          borderRadius: BorderRadius.circular(context.radius.md),
          boxShadow: context.shadows.elevation100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.radius.md - 1),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildFlatContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _allItems.length; i++)
          _buildItem(context, _allItems[i], i),
      ],
    );
  }

  Widget _buildGroupedContent(BuildContext context) {
    final colors = context.colors;
    final children = <Widget>[];
    int itemIndex = 0;

    for (var groupIndex = 0; groupIndex < widget.groups!.length; groupIndex++) {
      final group = widget.groups![groupIndex];

      // Add divider before groups (except first)
      if (groupIndex > 0) {
        children.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: colors.stroke,
          ),
        );
      }

      // Add group header if present
      if (group.label != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              group.label!,
              style: context.typography.body.small.copyWith(
                color: colors.foreground.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }

      // Add items
      for (final item in group.items) {
        children.add(_buildItem(context, item, itemIndex));
        itemIndex++;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildItem(BuildContext context, HoloSelectItem<T> item, int index) {
    final colors = context.colors;
    final isSelected = widget.value == item.value;
    final isFocused = _focusedIndex == index;
    final isDisabled = item.isDisabled;

    Widget itemWidget = HoloTappable(
      onTap: isDisabled ? null : () => _selectItem(item),
      canRequestFocus: false,
      cursor:
          isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.basic,
      onHoverChange:
          isDisabled
              ? null
              : (hovered) {
                if (hovered) {
                  setState(() => _focusedIndex = index);
                }
              },
      builder: (context, states, _) {
        final isHighlighted = !isDisabled && (states.isHovered || isFocused);

        // Use custom builder if provided
        if (widget.itemBuilder != null) {
          return widget.itemBuilder!(context, item, isSelected, isHighlighted);
        }

        // Default item rendering
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isHighlighted ? colors.overlay.overlay03 : null,
            borderRadius: BorderRadius.circular(context.radius.xs),
          ),
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Row(
              children: [
                // Checkmark or icon space
                SizedBox(
                  width: 16,
                  child:
                      isSelected
                          ? Icon(
                            LucideIcons.check200,
                            size: 14,
                            color: colors.foreground.primary,
                          )
                          : item.icon != null
                          ? Icon(
                            item.icon,
                            size: 14,
                            color: colors.foreground.muted,
                          )
                          : null,
                ),
                const SizedBox(width: 8),

                // Label
                Expanded(
                  child: Text(
                    item.label,
                    style: context.typography.body.medium.copyWith(
                      color:
                          isDisabled
                              ? colors.foreground.muted
                              : colors.foreground.primary,
                    ),
                  ),
                ),

                // Subtitle (e.g., dimensions)
                if (item.subtitle != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    item.subtitle!,
                    style: context.typography.mono.small.copyWith(
                      color: colors.foreground.weak,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    // Wrap with tooltip for disabled items
    if (isDisabled && item.disabledReason != null) {
      itemWidget = Tooltip(
        message: item.disabledReason!,
        waitDuration: const Duration(milliseconds: 300),
        child: itemWidget,
      );
    }

    return itemWidget;
  }
}
