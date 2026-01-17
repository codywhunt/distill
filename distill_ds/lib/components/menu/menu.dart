import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distill_ds/design_system.dart';

/// A menu container that displays a list of menu items.
///
/// Styled as a floating panel with proper shadows and borders.
/// Supports keyboard navigation (arrow keys, Enter, Escape).
///
/// Example:
/// ```dart
/// HoloMenu(
///   children: [
///     HoloMenuItem(
///       label: 'Copy',
///       shortcut: '⌘C',
///       onTap: () => copy(),
///     ),
///     HoloMenuDivider(),
///     HoloMenuItem(
///       label: 'Delete',
///       isDestructive: true,
///       onTap: () => delete(),
///     ),
///   ],
/// )
/// ```
class HoloMenu extends StatefulWidget {
  /// The menu items to display.
  ///
  /// Typically a list of [HoloMenuItem], [HoloMenuDivider], and [HoloMenuSection].
  final List<Widget> children;

  /// The width of the menu.
  ///
  /// If null, the menu will size to fit its content.
  final double? width;

  /// Maximum height before scrolling.
  final double? maxHeight;

  const HoloMenu({
    super.key,
    required this.children,
    this.width,
    this.maxHeight,
  });

  @override
  State<HoloMenu> createState() => _HoloMenuState();
}

class _HoloMenuState extends State<HoloMenu> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'HoloMenu');
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  int _focusedIndex = -1;

  List<int> get _selectableIndices {
    final indices = <int>[];
    for (var i = 0; i < widget.children.length; i++) {
      final child = widget.children[i];
      if (child is HoloMenuItem && child.onTap != null) {
        indices.add(i);
      }
    }
    return indices;
  }

  @override
  void initState() {
    super.initState();
    // Auto-focus the menu when it appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _moveFocus(int delta) {
    final indices = _selectableIndices;
    if (indices.isEmpty) return;

    final currentIndexPosition = indices.indexOf(_focusedIndex);
    int newPosition;

    if (currentIndexPosition == -1) {
      // No current focus, start at beginning or end
      newPosition = delta > 0 ? 0 : indices.length - 1;
    } else {
      // Wrap around at boundaries
      newPosition = (currentIndexPosition + delta) % indices.length;
      if (newPosition < 0) newPosition = indices.length - 1;
    }

    setState(() {
      _focusedIndex = indices[newPosition];
    });

    // Scroll to keep focused item visible
    _scrollToFocusedItem(indices[newPosition]);
  }

  void _scrollToFocusedItem(int index) {
    final key = _itemKeys[index];
    if (key?.currentContext == null) return;

    // Ensure the focused item is visible
    Scrollable.ensureVisible(
      key!.currentContext!,
      alignment: 0.5, // Center the item in the scroll view
      duration: const Duration(milliseconds: 100),
    );
  }

  void _selectFocused() {
    if (_focusedIndex >= 0 && _focusedIndex < widget.children.length) {
      final child = widget.children[_focusedIndex];
      if (child is HoloMenuItem) {
        child.onTap?.call();
      }
    }
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
        _selectFocused();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        final indices = _selectableIndices;
        if (indices.isNotEmpty) {
          setState(() => _focusedIndex = indices.first);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        final indices = _selectableIndices;
        if (indices.isNotEmpty) {
          setState(() => _focusedIndex = indices.last);
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _wrapChild(widget.children[i], i),
      ],
    );

    if (widget.maxHeight != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight!),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: content,
        ),
      );
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        width: widget.width,
        constraints: BoxConstraints(minWidth: widget.width ?? 160),
        decoration: BoxDecoration(
          color: colors.background.fullContrast,
          borderRadius: BorderRadius.circular(context.radius.md),
          boxShadow: context.shadows.elevation100,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      ),
    );
  }

  Widget _wrapChild(Widget child, int index) {
    if (child is HoloMenuItem) {
      // Create or reuse a GlobalKey for this index
      _itemKeys[index] ??= GlobalKey(debugLabel: 'HoloMenuItem_$index');

      return _HoloMenuItemWrapper(
        key: _itemKeys[index],
        item: child,
        isFocused: _focusedIndex == index,
        onHover: (hovered) {
          if (hovered) {
            setState(() => _focusedIndex = index);
          }
        },
      );
    }
    return child;
  }
}

/// A single menu item with label, optional icon, and keyboard shortcut.
class HoloMenuItem extends StatelessWidget {
  /// The item label text.
  final String label;

  /// An optional leading icon.
  final IconData? icon;

  /// An optional keyboard shortcut hint (e.g., "⌘C").
  final String? shortcut;

  /// Called when the item is tapped.
  final VoidCallback? onTap;

  /// Whether this item is currently selected (shows checkmark).
  final bool isSelected;

  /// Whether this item is destructive (styled in red).
  final bool isDestructive;

  const HoloMenuItem({
    super.key,
    required this.label,
    this.icon,
    this.shortcut,
    this.onTap,
    this.isSelected = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    // This is a placeholder - the actual rendering happens in _HoloMenuItemWrapper
    // to handle focus state from the parent menu.
    return const SizedBox.shrink();
  }
}

/// Internal wrapper that handles the actual rendering of menu items.
class _HoloMenuItemWrapper extends StatelessWidget {
  final HoloMenuItem item;
  final bool isFocused;
  final ValueChanged<bool> onHover;

  const _HoloMenuItemWrapper({
    super.key,
    required this.item,
    required this.isFocused,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEnabled = item.onTap != null;

    return HoloTappable(
      onTap: item.onTap,
      cursor: SystemMouseCursors.basic,
      enabled: isEnabled,
      canRequestFocus: false,
      onHoverChange: onHover,
      builder: (context, states, _) {
        final isHighlighted = states.isHovered || isFocused;

        Color fgColor;
        if (item.isDestructive) {
          fgColor = colors.accent.red.primary;
        } else if (!isEnabled) {
          fgColor = colors.foreground.disabled;
        } else {
          fgColor = colors.foreground.primary;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isHighlighted ? colors.overlay.overlay03 : null,
            borderRadius: BorderRadius.circular(context.radius.xs),
          ),
          child: Row(
            children: [
              // Checkmark or icon space
              SizedBox(
                width: 16,
                child:
                    item.isSelected
                        ? Icon(LucideIcons.check200, size: 14, color: fgColor)
                        : item.icon != null
                        ? Icon(item.icon, size: 14, color: fgColor)
                        : null,
              ),
              const SizedBox(width: 8),

              // Label
              Expanded(
                child: Text(
                  item.label,
                  style: context.typography.body.medium.copyWith(
                    color: fgColor,
                  ),
                ),
              ),

              // Shortcut
              if (item.shortcut != null) ...[
                const SizedBox(width: 16),
                Text(
                  item.shortcut!,
                  style: context.typography.mono.small.copyWith(
                    color: colors.foreground.weak,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A horizontal divider between menu items.
class HoloMenuDivider extends StatelessWidget {
  const HoloMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: colors.overlay.overlay10,
    );
  }
}

/// A section within a menu, with an optional header label.
///
/// Renders a divider above (if not first), an optional label, and its children.
class HoloMenuSection extends StatelessWidget {
  /// Optional section header label.
  final String? label;

  /// The items in this section.
  final List<Widget> children;

  const HoloMenuSection({super.key, this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HoloMenuDivider(),
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              label!,
              style: context.typography.body.small.copyWith(
                color: colors.foreground.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}
