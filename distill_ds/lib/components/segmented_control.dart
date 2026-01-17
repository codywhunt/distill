import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distill_ds/design_system.dart';

/// A class that represents a single item within a [SegmentedControl].
class SegmentedControlItem<T> {
  /// The icon to display in the segment.
  final IconData? icon;

  /// A custom widget to display instead of an icon.
  /// If provided, this takes precedence over [icon].
  final Widget? iconWidget;

  /// The label text to display in the segment.
  final String? label;

  /// The value associated with this segment.
  final T value;

  /// Whether this segment is enabled.
  final bool enabled;

  /// The tooltip message to display when hovering over the segment.
  final HologramTooltip? tooltip;

  /// Creates a segmented control item.
  ///
  /// The [value] parameter is required.
  const SegmentedControlItem({
    this.icon,
    this.iconWidget,
    this.label,
    required this.value,
    this.enabled = true,
    this.tooltip,
  });
}

/// A customizable segmented control widget that supports both icon and label variants.
///
/// The [SegmentedControl] supports both single-select and multi-select modes.
class SegmentedControl<T> extends StatefulWidget {
  /// The list of items to display in the segmented control.
  final List<SegmentedControlItem<T>> items;

  /// The currently selected values.
  final Set<T> selectedValues;

  /// The callback that is called when the selection changes.
  final void Function(Set<T> newValues) onChanged;

  /// Whether multiple segments can be selected simultaneously.
  final bool multiSelect;

  final double? heightOverride;

  final bool? showElevation;

  final double? gapOverride;

  /// Creates a segmented control.
  ///
  /// The [items], [selectedValues], and [onChanged] parameters are required.
  const SegmentedControl({
    super.key,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    this.multiSelect = false,
    this.heightOverride,
    this.showElevation = true,
    this.gapOverride,
  });

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> {
  // Map to track hover state of each segment
  final Map<T, bool> _hoverStates = {};

  // Map to track focus state of each segment
  final Map<T, FocusNode> _focusNodes = {};

  // Initialize hover states when widget is created
  @override
  void initState() {
    super.initState();
    _initializeHoverStates();
    _initializeFocusNodes();
  }

  // Update hover states when widget items change
  @override
  void didUpdateWidget(SegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _initializeHoverStates();
      _updateFocusNodes();
    }
  }

  @override
  void dispose() {
    // Dispose all focus nodes
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // Set hover state for all items to false initially
  void _initializeHoverStates() {
    _hoverStates.clear();
    for (var item in widget.items) {
      _hoverStates[item.value] = false;
    }
  }

  // Initialize focus nodes for all items
  void _initializeFocusNodes() {
    _focusNodes.clear();
    for (var item in widget.items) {
      _focusNodes[item.value] = FocusNode();
    }
  }

  // Update focus nodes when items change
  void _updateFocusNodes() {
    // First, dispose any focus nodes for items that no longer exist
    final currentItemValues = widget.items.map((item) => item.value).toSet();
    final obsoleteFocusNodes =
        _focusNodes.keys
            .where((key) => !currentItemValues.contains(key))
            .toList();

    for (final key in obsoleteFocusNodes) {
      _focusNodes[key]?.dispose();
      _focusNodes.remove(key);
    }

    // Then add new focus nodes for new items
    for (var item in widget.items) {
      if (!_focusNodes.containsKey(item.value)) {
        _focusNodes[item.value] = FocusNode();
      }
    }
  }

  // Handle segment taps
  void _handleTap(T value) {
    // Don't request focus when tapped - only tab navigation should set focus

    // Skip if the item is disabled
    if (!_isItemEnabled(value)) {
      return;
    }

    if (!widget.multiSelect) {
      // Single-select mode: only one item can be selected at a time
      widget.onChanged({value});
    } else {
      // Multi-select mode: toggle the selected state
      final newSelectedValues = Set<T>.from(widget.selectedValues);
      if (newSelectedValues.contains(value)) {
        newSelectedValues.remove(value);
      } else {
        newSelectedValues.add(value);
      }
      widget.onChanged(newSelectedValues);
    }
  }

  // Check if an item is enabled
  bool _isItemEnabled(T value) {
    final item = widget.items.firstWhere(
      (item) => item.value == value,
      orElse: () => SegmentedControlItem(value: value, enabled: false),
    );
    return item.enabled;
  }

  // Get the fixed height for all segments
  double _getHeight() {
    return widget.heightOverride ?? 23; // 23px + 3px padding = 26px total
  }

  // Get the fixed icon size for all segments
  double _getIconSize() {
    return 14;
  }

  // Get text style based for the control
  TextStyle _getTextStyle(BuildContext context) {
    return context.typography.body.smallStrong;
  }

  // Get the padding for items
  EdgeInsets _getItemPadding() {
    return const EdgeInsets.symmetric(horizontal: 8);
  }

  // Get background color based on selection and hover state
  Color _getBackgroundColor(
    BuildContext context,
    bool isSelected,
    bool isHovered,
    bool isEnabled,
  ) {
    if (isSelected) {
      return context.colors.background.fullContrast;
    }

    if (isHovered && isEnabled) {
      return context.colors.overlay.overlay03;
    }

    return Colors.transparent;
  }

  // Get foreground color based on selection and enabled state
  Color _getForegroundColor(
    BuildContext context,
    bool isSelected,
    bool isEnabled,
  ) {
    if (!isEnabled) {
      return context.colors.foreground.disabled;
    }

    return isSelected
        ? context.colors.foreground.primary
        : context.colors.foreground.muted;
  }

  // Get the border radius based on item position
  BorderRadius _getBorderRadius(bool isFirst, bool isLast) {
    const double outerRadius = 4.5;
    const double innerRadius = 2.0;

    return BorderRadius.only(
      topLeft: Radius.circular(isFirst ? outerRadius : innerRadius),
      bottomLeft: Radius.circular(isFirst ? outerRadius : innerRadius),
      topRight: Radius.circular(isLast ? outerRadius : innerRadius),
      bottomRight: Radius.circular(isLast ? outerRadius : innerRadius),
    );
  }

  // Build a segment with an icon
  Widget _buildIconSegment(
    BuildContext context,
    SegmentedControlItem<T> item,
    bool isSelected,
    bool isFirst,
    bool isLast,
  ) {
    final isHovered = _hoverStates[item.value] ?? false;
    final focusNode = _focusNodes[item.value] ?? FocusNode();

    Widget segment = Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        // Force rebuild when focus changes to update border
        setState(() {});
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            if (item.enabled) {
              _handleTap(item.value);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoverStates[item.value] = true),
        onExit: (_) => setState(() => _hoverStates[item.value] = false),
        cursor:
            item.enabled ? SystemMouseCursors.basic : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: item.enabled ? () => _handleTap(item.value) : null,
          child: Container(
            constraints: BoxConstraints(minWidth: _getHeight()),
            height: _getHeight(),
            decoration: BoxDecoration(
              color: _getBackgroundColor(
                context,
                isSelected,
                isHovered,
                item.enabled,
              ),
              borderRadius: _getBorderRadius(isFirst, isLast),
              // Always have a border, but make it transparent when not focused
              border: Border.all(
                color:
                    focusNode.hasFocus
                        ? context.colors.accent.purple.primary
                        : Colors.transparent,
                width: 1,
              ),
              boxShadow:
                  widget.showElevation != null &&
                          widget.showElevation! &&
                          isSelected
                      ? context.shadows.elevation100
                      : null,
            ),
            child: Center(
              child:
                  item.iconWidget != null
                      ? IconTheme(
                        data: IconThemeData(
                          color: _getForegroundColor(
                            context,
                            isSelected,
                            item.enabled,
                          ),
                          size: _getIconSize(),
                        ),
                        child: item.iconWidget!,
                      )
                      : Icon(
                        item.icon,
                        size: _getIconSize(),
                        color: _getForegroundColor(
                          context,
                          isSelected,
                          item.enabled,
                        ),
                      ),
            ),
          ),
        ),
      ),
    );

    // Wrap with tooltip if one is provided
    if (item.tooltip != null) {
      return HologramTooltip(
        message: item.tooltip!.message,
        shortcut: item.tooltip!.shortcut,
        child: segment,
      );
    }

    return segment;
  }

  // Build a segment with a label
  Widget _buildLabelSegment(
    BuildContext context,
    SegmentedControlItem<T> item,
    bool isSelected,
    bool isFirst,
    bool isLast,
  ) {
    final isHovered = _hoverStates[item.value] ?? false;
    final focusNode = _focusNodes[item.value] ?? FocusNode();

    Widget segment = Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        // Force rebuild when focus changes to update border
        setState(() {});
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            if (item.enabled) {
              _handleTap(item.value);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoverStates[item.value] = true),
        onExit: (_) => setState(() => _hoverStates[item.value] = false),
        cursor:
            item.enabled ? SystemMouseCursors.basic : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: item.enabled ? () => _handleTap(item.value) : null,
          child: Container(
            height: _getHeight(),
            padding: _getItemPadding(),
            decoration: BoxDecoration(
              color: _getBackgroundColor(
                context,
                isSelected,
                isHovered,
                item.enabled,
              ),
              borderRadius: _getBorderRadius(isFirst, isLast),
              // Always have a border, but make it transparent when not focused
              border: Border.all(
                color:
                    focusNode.hasFocus
                        ? context.colors.accent.purple.primary
                        : Colors.transparent,
                width: 1,
              ),
              boxShadow:
                  widget.showElevation != null &&
                          widget.showElevation! &&
                          isSelected
                      ? context.shadows.elevation100
                      : null,
            ),
            child: Center(
              child: Text(
                item.label ?? '',
                style: _getTextStyle(context).copyWith(
                  color: _getForegroundColor(context, isSelected, item.enabled),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with tooltip if one is provided
    if (item.tooltip != null) {
      return HologramTooltip(
        message: item.tooltip!.message,
        shortcut: item.tooltip!.shortcut,
        child: segment,
      );
    }

    return segment;
  }

  // Build a segment with both icon and label
  Widget _buildIconAndLabelSegment(
    BuildContext context,
    SegmentedControlItem<T> item,
    bool isSelected,
    bool isFirst,
    bool isLast,
  ) {
    final isHovered = _hoverStates[item.value] ?? false;
    final focusNode = _focusNodes[item.value] ?? FocusNode();

    Widget segment = Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        // Force rebuild when focus changes to update border
        setState(() {});
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            if (item.enabled) {
              _handleTap(item.value);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoverStates[item.value] = true),
        onExit: (_) => setState(() => _hoverStates[item.value] = false),
        cursor:
            item.enabled ? SystemMouseCursors.basic : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: item.enabled ? () => _handleTap(item.value) : null,
          child: Container(
            height: _getHeight(),
            padding: _getItemPadding(),
            decoration: BoxDecoration(
              color: _getBackgroundColor(
                context,
                isSelected,
                isHovered,
                item.enabled,
              ),
              borderRadius: _getBorderRadius(isFirst, isLast),
              // Always have a border, but make it transparent when not focused
              border: Border.all(
                color:
                    focusNode.hasFocus
                        ? context.colors.accent.purple.primary
                        : Colors.transparent,
                width: 1,
              ),
              boxShadow:
                  widget.showElevation != null &&
                          widget.showElevation! &&
                          isSelected
                      ? context.shadows.elevation100
                      : null,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  item.iconWidget != null
                      ? IconTheme(
                        data: IconThemeData(
                          color: _getForegroundColor(
                            context,
                            isSelected,
                            item.enabled,
                          ),
                          size: _getIconSize(),
                        ),
                        child: item.iconWidget!,
                      )
                      : Icon(
                        item.icon,
                        size: _getIconSize(),
                        color: _getForegroundColor(
                          context,
                          isSelected,
                          item.enabled,
                        ),
                      ),
                  const SizedBox(width: 6),
                  Text(
                    item.label ?? '',
                    style: _getTextStyle(context).copyWith(
                      color: _getForegroundColor(
                        context,
                        isSelected,
                        item.enabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with tooltip if one is provided
    if (item.tooltip != null) {
      return HologramTooltip(
        message: item.tooltip!.message,
        shortcut: item.tooltip!.shortcut,
        child: segment,
      );
    }

    return segment;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.gapOverride ?? 1.5),
      width: double.infinity, // Allow container to expand to full width
      decoration: BoxDecoration(
        color: context.colors.overlay.overlay05,
        borderRadius: BorderRadius.circular(context.radius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max, // Fill available space
        children: _buildItemsWithSpacing(context),
      ),
    );
  }

  // Helper method to build items with spacing between them
  List<Widget> _buildItemsWithSpacing(BuildContext context) {
    final List<Widget> result = [];
    final int lastIndex = widget.items.length - 1;

    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final isSelected = widget.selectedValues.contains(item.value);
      final isFirst = i == 0;
      final isLast = i == lastIndex;

      // Add the appropriate segment widget wrapped in Expanded for even width distribution
      final hasIcon = item.icon != null || item.iconWidget != null;
      if (hasIcon && item.label != null) {
        result.add(
          Expanded(
            child: _buildIconAndLabelSegment(
              context,
              item,
              isSelected,
              isFirst,
              isLast,
            ),
          ),
        );
      } else if (hasIcon) {
        result.add(
          Expanded(
            child: _buildIconSegment(
              context,
              item,
              isSelected,
              isFirst,
              isLast,
            ),
          ),
        );
      } else {
        result.add(
          Expanded(
            child: _buildLabelSegment(
              context,
              item,
              isSelected,
              isFirst,
              isLast,
            ),
          ),
        );
      }

      // Add spacing after each item except the last one
      if (i < lastIndex) {
        result.add(SizedBox(width: widget.gapOverride ?? 1));
      }
    }

    return result;
  }
}

/// A specialized version of [SegmentedControl] that displays only icons.
class SegmentedControlIcon<T> extends StatelessWidget {
  /// The list of items to display in the segmented control.
  final List<SegmentedControlItem<T>> items;

  /// The currently selected values.
  final Set<T> selectedValues;

  /// The callback that is called when the selection changes.
  final void Function(Set<T> newValues) onChanged;

  /// Whether multiple segments can be selected simultaneously.
  final bool multiSelect;

  /// Creates a segmented control with icon-only items.
  ///
  /// The [items], [selectedValues], and [onChanged] parameters are required.
  const SegmentedControlIcon({
    super.key,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    this.multiSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure all items have icons
    final iconItems =
        items.map((item) {
          return SegmentedControlItem<T>(
            icon: item.icon ?? Icons.circle,
            value: item.value,
            enabled: item.enabled,
            tooltip: item.tooltip,
          );
        }).toList();

    return SegmentedControl<T>(
      items: iconItems,
      selectedValues: selectedValues,
      onChanged: onChanged,
      multiSelect: multiSelect,
    );
  }
}

/// A specialized version of [SegmentedControl] that displays only labels.
class SegmentedControlLabel<T> extends StatelessWidget {
  /// The list of items to display in the segmented control.
  final List<SegmentedControlItem<T>> items;

  /// The currently selected values.
  final Set<T> selectedValues;

  /// The callback that is called when the selection changes.
  final void Function(Set<T> newValues) onChanged;

  /// Whether multiple segments can be selected simultaneously.
  final bool multiSelect;

  /// Whether to show elevation shadow on selected segments.
  final bool showElevation;

  /// Creates a segmented control with label-only items.
  ///
  /// The [items], [selectedValues], and [onChanged] parameters are required.
  const SegmentedControlLabel({
    super.key,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    this.multiSelect = false,
    this.showElevation = true,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure all items have labels
    final labelItems =
        items.map((item) {
          return SegmentedControlItem<T>(
            label: item.label ?? item.value.toString(),
            value: item.value,
            enabled: item.enabled,
            tooltip: item.tooltip,
          );
        }).toList();

    return SegmentedControl<T>(
      items: labelItems,
      selectedValues: selectedValues,
      onChanged: onChanged,
      multiSelect: multiSelect,
      showElevation: showElevation,
    );
  }
}
