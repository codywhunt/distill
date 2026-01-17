import 'package:distill_ds/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../src/free_design/models/frame.dart';
import '../../../src/free_design/store/editor_document_store.dart';
import '../canvas_state.dart';

/// A single row in the frame list panel.
///
/// Displays:
/// - Frame icon
/// - Frame name (double-click to edit)
/// - Delete button (visible when selected)
///
/// Inline editing is triggered by double-clicking on the name text only,
/// not the entire row.
class FrameListItem extends StatefulWidget {
  const FrameListItem({
    required this.frame,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Frame frame;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<FrameListItem> createState() => _FrameListItemState();
}

class _FrameListItemState extends State<FrameListItem> {
  bool _isEditing = false;
  late TextEditingController _textController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Commit on blur (unless cancelled)
    if (!_focusNode.hasFocus && _isEditing) {
      _commitEdit();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _textController.text = widget.frame.name;
    });
    // Focus and select all after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _textController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _textController.text.length,
        );
      }
    });
  }

  void _commitEdit() {
    final newName = _textController.text.trim();
    if (newName.isNotEmpty && newName != widget.frame.name) {
      context.read<CanvasState>().store.updateFrameProp(
        widget.frame.id,
        '/name',
        newName,
      );
    }
    setState(() => _isEditing = false);
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return HoloTappable(
      onTap: widget.onTap,
      cursor: SystemMouseCursors.basic,
      selected: widget.isSelected,
      builder: (context, states, _) {
        final effectiveHovered = states.isHovered;
        final effectiveSelected = states.isSelected || widget.isSelected;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          height: 26,
          decoration: BoxDecoration(
            color: effectiveSelected
                ? context.colors.accent.purple.primary
                : (effectiveHovered ? context.colors.overlay.overlay05 : null),
            borderRadius: BorderRadius.circular(context.radius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(
              children: [
                // Frame icon
                Icon(
                  LucideIcons.frame200,
                  size: 13,
                  color: effectiveSelected
                      ? Colors.white
                      : effectiveHovered
                          ? context.colors.foreground.primary
                          : context.colors.foreground.muted,
                ),

                const SizedBox(width: 8),

                // Name (double-click to edit)
                Expanded(
                  child: _isEditing
                      ? _buildEditField(context, effectiveSelected)
                      : _buildNameText(context, effectiveSelected, effectiveHovered),
                ),

                // Delete button (visible when selected or hovered)
                if (effectiveSelected || effectiveHovered)
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        LucideIcons.trash2200,
                        size: 13,
                        color: effectiveSelected
                            ? Colors.white.withValues(alpha: 0.7)
                            : context.colors.foreground.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameText(BuildContext context, bool isSelected, bool isHovered) {
    return GestureDetector(
      onDoubleTap: _startEditing,
      child: Text(
        widget.frame.name,
        style: context.typography.body.medium.copyWith(
          color: isSelected
              ? Colors.white
              : isHovered
                  ? context.colors.foreground.primary
                  : context.colors.foreground.muted,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildEditField(BuildContext context, bool isSelected) {
    return KeyboardListener(
      focusNode: FocusNode(), // Separate focus node for keyboard events
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _cancelEdit();
        }
      },
      child: TextField(
        controller: _textController,
        focusNode: _focusNode,
        style: context.typography.body.medium.copyWith(
          color: isSelected ? Colors.white : context.colors.foreground.primary,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
        ),
        onSubmitted: (_) => _commitEdit(),
      ),
    );
  }
}
