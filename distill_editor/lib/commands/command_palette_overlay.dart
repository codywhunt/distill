import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distill_ds/design_system.dart';
import 'package:provider/provider.dart';

import 'command.dart';
import 'command_palette_state.dart';

/// Overlay widget for the command palette.
///
/// Renders a modal overlay with search input and command list.
///
/// Uses [Visibility] and [IgnorePointer] rather than conditionally mounting
/// to avoid Flutter web assertion errors when the TextField is removed during
/// pointer event processing.
class CommandPaletteOverlay extends StatelessWidget {
  const CommandPaletteOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CommandPaletteState>();
    final isOpen = state.isOpen;

    // Always keep the widget tree mounted but hidden when closed.
    // This prevents Flutter web's text input binding from failing when
    // the TextField is removed during pointer event processing.
    return IgnorePointer(
      ignoring: !isOpen,
      child: Visibility(
        visible: isOpen,
        maintainState: true,
        maintainAnimation: true,
        child: Stack(
          children: [
            // Backdrop
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: state.close,
                child: Container(color: Colors.black.withValues(alpha: 0.4)),
              ),
            ),

            // Palette
            Center(child: _CommandPaletteDialog(state: state)),
          ],
        ),
      ),
    );
  }
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.state});

  final CommandPaletteState state;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _maybeRequestFocus();
  }

  @override
  void didUpdateWidget(_CommandPaletteDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle focus when palette opens/closes
    if (widget.state.isOpen && !oldWidget.state.isOpen) {
      _maybeRequestFocus();
    } else if (!widget.state.isOpen && oldWidget.state.isOpen) {
      _focusNode.unfocus();
      _controller.clear();
    }
  }

  void _maybeRequestFocus() {
    if (widget.state.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.state.isOpen) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.state.selectPrevious();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.state.selectNext();
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      _executeSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.state.close();
    }
  }

  void _executeSelected() {
    final command = widget.state.selectedCommand;
    if (command != null) {
      widget.state.close();
      command.execute(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: _handleKeyEvent,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: context.colors.background.primary,
            borderRadius: BorderRadius.circular(context.radius.lg),
            boxShadow: context.shadows.elevation300,
            border: Border.all(color: context.colors.stroke),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radius.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input
                _SearchInput(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: widget.state.updateQuery,
                ),

                // Divider
                Container(height: 1, color: context.colors.stroke),

                // Results
                Flexible(
                  child: widget.state.filteredCommands.isEmpty
                      ? const _NoResults()
                      : _CommandList(
                          commands: widget.state.filteredCommands,
                          selectedIndex: widget.state.selectedIndex,
                          onSelect: (index) {
                            widget.state.setSelectedIndex(index);
                            _executeSelected();
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.spacing.sm),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: context.typography.body.medium,
        decoration: InputDecoration(
          hintText: 'Type a command...',
          hintStyle: context.typography.body.medium.copyWith(
            color: context.colors.foreground.muted,
          ),
          prefixIcon: Icon(
            LucideIcons.search,
            size: 18,
            color: context.colors.foreground.muted,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: context.spacing.sm,
            vertical: context.spacing.sm,
          ),
        ),
      ),
    );
  }
}

class _CommandList extends StatelessWidget {
  const _CommandList({
    required this.commands,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Command> commands;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      itemCount: commands.length,
      itemBuilder: (context, index) {
        final command = commands[index];
        final isSelected = index == selectedIndex;

        return _CommandTile(
          command: command,
          isSelected: isSelected,
          onTap: () => onSelect(index),
        );
      },
    );
  }
}

class _CommandTile extends StatefulWidget {
  const _CommandTile({
    required this.command,
    required this.isSelected,
    required this.onTap,
  });

  final Command command;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CommandTile> createState() => _CommandTileState();
}

class _CommandTileState extends State<_CommandTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isSelected || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.sm,
          ),
          color: isHighlighted
              ? context.colors.background.secondary
              : Colors.transparent,
          child: Row(
            children: [
              if (widget.command.icon != null) ...[
                Icon(
                  widget.command.icon,
                  size: 18,
                  color: context.colors.foreground.muted,
                ),
                SizedBox(width: context.spacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.command.label,
                      style: context.typography.body.medium.copyWith(
                        color: context.colors.foreground.primary,
                      ),
                    ),
                    if (widget.command.description != null)
                      Text(
                        widget.command.description!,
                        style: context.typography.body.small.copyWith(
                          color: context.colors.foreground.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(context.spacing.lg),
      child: Text(
        'No commands found',
        style: context.typography.body.medium.copyWith(
          color: context.colors.foreground.muted,
        ),
      ),
    );
  }
}
