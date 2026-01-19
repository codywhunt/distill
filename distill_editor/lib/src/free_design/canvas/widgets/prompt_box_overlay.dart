import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' show min;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, KeyDownEvent, LogicalKeyboardKey;
import 'package:distill_ds/design_system.dart';

import '../../ai/ai_service.dart';
import '../../ai/llm_client.dart';
import '../../dsl/dsl_exporter.dart';
import '../../models/models.dart' hide CrossAxisAlignment, MainAxisAlignment;
import '../../patch/patch_op.dart';
import '../drag_target.dart';
import '../../../../modules/canvas/canvas_state.dart';

void _log(String message) {
  developer.log(message, name: 'PromptBox');
  // ignore: avoid_print
  print('[PromptBox] $message');
}

/// Persistent prompt box overlay at the bottom center of the canvas.
///
/// Features:
/// - Context chips showing selected frames/nodes
/// - Text input with placeholder
/// - Action buttons (+, @, model selector, submit)
/// - Handles new frame generation and updates to existing frames/nodes
class PromptBoxOverlay extends StatefulWidget {
  const PromptBoxOverlay({
    required this.state,
    required this.onError,
    super.key,
  });

  final CanvasState state;

  /// Called when an error occurs.
  final void Function(String message) onError;

  @override
  State<PromptBoxOverlay> createState() => _PromptBoxOverlayState();
}

class _PromptBoxOverlayState extends State<PromptBoxOverlay> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  LlmModel _selectedModel = LlmModel.defaultModel;
  bool _isHovered = false;

  /// Track active generation count for UI feedback (spinner in action row).
  int _activeGenerations = 0;

  /// Cached AI service for the current model.
  FreeDesignAiService? _aiService;

  /// Get or create the AI service for the selected model.
  FreeDesignAiService? _getAiService() {
    // Create service lazily with the currently selected model
    _aiService ??= createAiServiceWithModel(_selectedModel);
    return _aiService;
  }

  /// Update the selected model and clear the cached service.
  void _setSelectedModel(LlmModel model) {
    if (model != _selectedModel) {
      setState(() {
        _selectedModel = model;
        _aiService = null; // Clear cache so next call creates new service
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    // Register callback for focus requests from canvas
    widget.state.onRequestPromptFocus = _handleFocusRequest;
  }

  void _onFocusChange() {
    // Rebuild when focus changes to update background color
    setState(() {});
  }

  void _handleFocusRequest() {
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    // Unregister callback
    widget.state.onRequestPromptFocus = null;
    _focusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final prompt = _textController.text.trim();
    if (prompt.isEmpty) return;

    final aiService = _getAiService();
    if (aiService == null) {
      widget.onError('AI service not configured. Set OPENROUTER_API_KEY environment variable.');
      return;
    }

    // Capture selection at submit time (before clearing input)
    final selectedFrames = Set<String>.from(widget.state.selectedFrameIds);
    final selectedNodes = Set<NodeTarget>.from(widget.state.selectedNodes);

    // Clear input immediately so user can start typing next prompt
    _textController.clear();

    // Increment active generation count
    setState(() => _activeGenerations++);

    try {
      // Check if we should use generate vs update
      final shouldGenerate = _shouldUseGenerate(selectedFrames, selectedNodes);

      if (shouldGenerate) {
        // New frame generation
        await _generateNewFrame(
          prompt,
          aiService,
          existingFrameId: selectedFrames.firstOrNull,
        );
      } else {
        // Update existing frame/node
        await _updateSelection(prompt, aiService, selectedFrames, selectedNodes);
      }
    } catch (e) {
      widget.onError('Generation failed: $e');
    } finally {
      if (mounted) {
        setState(() => _activeGenerations--);
      }
    }
  }

  /// Determine if we should use generate mode vs update mode.
  ///
  /// Returns true (generate mode) when:
  /// - No selection at all
  /// - Single frame selected that is blank (only root container, no children)
  bool _shouldUseGenerate(
    Set<String> selectedFrames,
    Set<NodeTarget> selectedNodes,
  ) {
    // If nodes are selected, always use update mode
    if (selectedNodes.isNotEmpty) {
      return false;
    }

    // If no frames selected, use generate mode
    if (selectedFrames.isEmpty) {
      return true;
    }

    // If multiple frames selected, use update mode
    if (selectedFrames.length > 1) {
      return false;
    }

    // Single frame selected - check if it's blank (empty frame)
    final frameId = selectedFrames.first;
    final frame = widget.state.document.frames[frameId];
    if (frame == null) return false;

    // Get the root node
    final rootNode = widget.state.document.nodes[frame.rootNodeId];
    if (rootNode == null) return false;

    // Frame is blank if root has no children
    return rootNode.childIds.isEmpty;
  }

  Future<void> _generateNewFrame(
    String prompt,
    FreeDesignAiService aiService, {
    String? existingFrameId,
  }) async {
    // If replacing an existing blank frame, use its position/size
    Offset position;
    Size size;
    String? existingRootNodeId;

    if (existingFrameId != null) {
      final existingFrame = widget.state.document.frames[existingFrameId];
      if (existingFrame != null) {
        position = existingFrame.canvas.position;
        size = existingFrame.canvas.size;
        existingRootNodeId = existingFrame.rootNodeId;
      } else {
        // Fallback if frame not found
        position = const Offset(0, 0);
        size = const Size(393, 852);
      }
    } else {
      // Generate at canvas center for now
      // TODO: Get canvas center from viewport
      position = const Offset(0, 0);
      size = const Size(393, 852);
    }

    // Create a placeholder frame immediately for the "Generating..." state
    final now = DateTime.now();
    final frameId = existingFrameId ?? 'frame_${now.millisecondsSinceEpoch}';
    final rootNodeId =
        existingRootNodeId ?? 'node_${now.millisecondsSinceEpoch}';

    final placeholderFrame = Frame(
      id: frameId,
      name: 'Generating...',
      rootNodeId: rootNodeId,
      canvas: CanvasPlacement(position: position, size: size),
      createdAt: now,
      updatedAt: now,
    );

    final placeholderRoot = Node(
      id: rootNodeId,
      name: 'Root',
      type: NodeType.container,
      props: const ContainerProps(),
      layout: const NodeLayout(size: SizeMode.fill()),
      style: const NodeStyle(),
    );

    // If replacing existing frame, remove it first, then add placeholder
    final patches = <PatchOp>[];
    if (existingFrameId != null && existingRootNodeId != null) {
      patches.add(RemoveFrame(existingFrameId));
      patches.add(DeleteNode(existingRootNodeId));
    }
    patches.add(InsertNode(placeholderRoot));
    patches.add(InsertFrame(placeholderFrame));

    widget.state.store.applyPatches(patches);
    widget.state.startGenerating(frameId);
    widget.state.select(FrameTarget(frameId));

    try {
      _log('generateViaDsl: Starting generation for prompt: "$prompt"');

      // Use token-efficient DSL generation (~75% fewer tokens)
      final result = await aiService.generateViaDsl(
        prompt: prompt,
        position: position,
        size: size,
      );

      _log(
        'generateViaDsl: Success - created frame "${result.frame.name}" with ${result.nodes.length} nodes',
      );

      // Remove placeholder and apply real result
      widget.state.store.applyPatches([
        RemoveFrame(frameId),
        DeleteNode(rootNodeId),
      ]);
      aiService.applyResult(widget.state.store, result);

      // Select the new frame
      widget.state.select(FrameTarget(result.frame.id));
    } on DslGenerationException catch (e) {
      _log('generateViaDsl: ERROR - ${e.message}');
      if (e.parseError != null) {
        _log('generateViaDsl: Parse error - ${e.parseError}');
      }
      rethrow;
    } finally {
      widget.state.finishGenerating(frameId);
    }
  }

  Future<void> _updateSelection(
    String prompt,
    FreeDesignAiService aiService,
    Set<String> selectedFrames,
    Set<NodeTarget> selectedNodes,
  ) async {
    // Determine which frame to update
    // Priority: selected frame > frame containing selected node
    String? frameId;
    List<String> focusNodeIds = [];

    if (selectedFrames.isNotEmpty) {
      // Use first selected frame
      frameId = selectedFrames.first;
      // When whole frame is selected, focus on root node
      final frame = widget.state.document.frames[frameId];
      if (frame != null) {
        focusNodeIds = [frame.rootNodeId];
      }
    } else if (selectedNodes.isNotEmpty) {
      // Use frame containing the first selected node
      final firstNode = selectedNodes.first;
      frameId = firstNode.frameId;

      // Collect target node IDs (document node IDs, not expanded IDs)
      for (final nodeTarget in selectedNodes) {
        if (nodeTarget.frameId == frameId && nodeTarget.patchTarget != null) {
          focusNodeIds.add(nodeTarget.patchTarget!);
        }
      }
    }

    if (frameId == null) {
      widget.onError('No frame selected for update.');
      return;
    }

    final frame = widget.state.document.frames[frameId];
    if (frame == null) {
      widget.onError('Selected frame not found.');
      return;
    }

    // Mark frame as updating (shows animated border)
    widget.state.startUpdating(frameId);

    try {
      _log('editViaPatches: Starting edit for prompt: "$prompt"');
      _log('editViaPatches: Frame: $frameId, Focus nodes: $focusNodeIds');

      // Use token-efficient PatchOps editing (~98% fewer tokens)
      final patches = await aiService.editViaPatches(
        document: widget.state.document,
        frameId: frameId,
        focusNodeIds: focusNodeIds,
        userRequest: prompt,
      );

      _log('editViaPatches: Success - received ${patches.length} patches');
      for (final patch in patches) {
        _log('editViaPatches:   - $patch');
      }

      // Apply the patches directly
      widget.state.store.applyPatches(patches);
    } on PatchOpsValidationException catch (e) {
      _log('editViaPatches: ERROR - ${e.message}');
      for (final error in e.errors) {
        _log('editViaPatches:   - $error');
      }
      rethrow;
    } finally {
      widget.state.finishUpdating(frameId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Positioned.fill + IgnorePointer for gesture passthrough
    return Positioned.fill(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = min(600.0, constraints.maxWidth - 64);

            // Determine background color based on state:
            // - Focused: fullContrast
            // - Hovered: primary
            // - Default: secondary
            final backgroundColor =
                _focusNode.hasFocus
                    ? context.colors.background.fullContrast.withValues(
                      alpha: 0.95,
                    )
                    : _isHovered
                    ? context.colors.background.fullContrast.withValues(
                      alpha: 0.9,
                    )
                    : context.colors.background.secondary.withValues(
                      alpha: 0.85,
                    );

            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(context.radius.xxl),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        width: maxWidth,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(
                            context.radius.xxl,
                          ),
                          border: Border.all(
                            color: context.colors.overlay.overlay10,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _InputArea(
                              state: widget.state,
                              textController: _textController,
                              focusNode: _focusNode,
                              onSubmit: _handleSubmit,
                            ),
                            _ActionRow(
                              state: widget.state,
                              currentModel: _selectedModel,
                              onModelChanged: (model) {
                                if (model != null) {
                                  _setSelectedModel(model);
                                }
                              },
                              onSubmit: _handleSubmit,
                              // Can always submit if there's text - concurrent generations allowed
                              canSubmit: _textController.text.trim().isNotEmpty,
                              activeGenerations: _activeGenerations,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Input area with context chips and text field.
class _InputArea extends StatelessWidget {
  const _InputArea({
    required this.state,
    required this.textController,
    required this.focusNode,
    required this.onSubmit,
  });

  final CanvasState state;
  final TextEditingController textController;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Context chips row (if selection exists)
          ListenableBuilder(
            listenable: state,
            builder: (context, _) {
              final hasSelection =
                  state.selectedFrameIds.isNotEmpty ||
                  state.selectedNodes.isNotEmpty;
              if (!hasSelection) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(bottom: context.spacing.sm),
                child: _ContextChips(state: state),
              );
            },
          ),

          // Text input with Escape key handling
          KeyboardListener(
            focusNode: FocusNode(), // Separate focus node for keyboard events
            onKeyEvent: (event) {
              // Escape key unfocuses the text field
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                focusNode.unfocus();
              }
            },
            child: TextField(
              cursorColor: context.colors.foreground.primary,
              mouseCursor: SystemMouseCursors.basic,
              controller: textController,
              focusNode: focusNode,
              // Always enabled - allows concurrent generations
              decoration: InputDecoration.collapsed(
                hintText: 'Describe what you want to build...',
                hintStyle: context.typography.body.medium.copyWith(
                  color: context.colors.foreground.muted,
                ),
              ),
              style: context.typography.body.medium.copyWith(
                color: context.colors.foreground.primary,
              ),
              maxLines: null,
              minLines: 1,
              // Use onSubmitted for Enter key handling
              onSubmitted: (_) => onSubmit(),
              keyboardType: TextInputType.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Context chips showing selected frames and nodes.
class _ContextChips extends StatelessWidget {
  const _ContextChips({required this.state});

  final CanvasState state;

  static const _maxVisibleChips = 3;

  @override
  Widget build(BuildContext context) {
    final chips = _buildChipData();
    if (chips.isEmpty) return const SizedBox.shrink();

    final visibleChips = chips.take(_maxVisibleChips).toList();
    final overflowCount = chips.length - _maxVisibleChips;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final chip in visibleChips) ...[
          _ContextChip(icon: chip.icon, label: chip.label),
          SizedBox(width: context.spacing.xs),
        ],
        if (overflowCount > 0)
          _ContextChip(
            icon: LucideIcons.plus200,
            label: '+$overflowCount',
            isMuted: true,
          ),
      ],
    );
  }

  List<_ChipData> _buildChipData() {
    final chips = <_ChipData>[];
    final seenFrameIds = <String>{};

    // Add selected frames
    for (final frameId in state.selectedFrameIds) {
      final frame = state.document.frames[frameId];
      if (frame != null) {
        chips.add(_ChipData(LucideIcons.frame200, frame.name));
        seenFrameIds.add(frameId);
      }
    }

    // Add selected nodes (with parent frame if not already shown)
    for (final nodeTarget in state.selectedNodes) {
      final frame = state.document.frames[nodeTarget.frameId];
      if (frame == null) continue;

      // Add parent frame chip if not already shown
      if (!seenFrameIds.contains(nodeTarget.frameId)) {
        chips.add(_ChipData(LucideIcons.frame200, frame.name));
        seenFrameIds.add(nodeTarget.frameId);
      }

      // Get node info - try patchTarget to get document node name
      final scene = state.getExpandedScene(nodeTarget.frameId);
      final expandedNode = scene?.nodes[nodeTarget.expandedId];
      if (expandedNode != null) {
        // Get name from document node if available
        final patchId = expandedNode.patchTargetId;
        final docNode = patchId != null ? state.document.nodes[patchId] : null;
        final nodeName = docNode?.name ?? _getNodeTypeName(expandedNode.type);

        chips.add(_ChipData(_getNodeTypeIcon(expandedNode.type), nodeName));
      }
    }

    return chips;
  }

  IconData _getNodeTypeIcon(NodeType type) => switch (type) {
    NodeType.container => LucideIcons.square200,
    NodeType.text => LucideIcons.type200,
    NodeType.icon => LucideIcons.star200,
    NodeType.image => LucideIcons.image200,
    NodeType.instance => LucideIcons.copy200,
    NodeType.spacer => LucideIcons.moveVertical200,
    NodeType.slot => LucideIcons.squareDashed200,
  };

  String _getNodeTypeName(NodeType type) => switch (type) {
    NodeType.container => 'Container',
    NodeType.text => 'Text',
    NodeType.icon => 'Icon',
    NodeType.image => 'Image',
    NodeType.instance => 'Instance',
    NodeType.spacer => 'Spacer',
    NodeType.slot => 'Slot',
  };
}

class _ChipData {
  const _ChipData(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Single context chip.
class _ContextChip extends StatelessWidget {
  const _ContextChip({
    required this.icon,
    required this.label,
    this.isMuted = false,
  });

  final IconData icon;
  final String label;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.overlay.overlay05,
        borderRadius: BorderRadius.circular(context.radius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color:
                isMuted
                    ? context.colors.foreground.muted
                    : context.colors.foreground.primary,
          ),
          SizedBox(width: context.spacing.xxs),
          Text(
            label,
            style: context.typography.body.small.copyWith(
              color:
                  isMuted
                      ? context.colors.foreground.muted
                      : context.colors.foreground.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Action row with buttons and model selector.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.state,
    required this.currentModel,
    required this.onModelChanged,
    required this.onSubmit,
    required this.canSubmit,
    required this.activeGenerations,
  });

  final CanvasState state;
  final LlmModel currentModel;
  final ValueChanged<LlmModel?> onModelChanged;
  final VoidCallback onSubmit;
  final bool canSubmit;
  final int activeGenerations;

  void _showDebugDialog(BuildContext context) {
    final selectedFrames = state.selectedFrameIds;
    final selectedNodes = state.selectedNodes;

    if (selectedFrames.isEmpty && selectedNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No frame or node selected')),
      );
      return;
    }

    // Build debug info
    String? frameId;
    List<String> nodeIds = [];

    if (selectedFrames.isNotEmpty) {
      frameId = selectedFrames.first;
    } else if (selectedNodes.isNotEmpty) {
      frameId = selectedNodes.first.frameId;
      for (final nodeTarget in selectedNodes) {
        if (nodeTarget.patchTarget != null) {
          nodeIds.add(nodeTarget.patchTarget!);
        }
      }
    }

    if (frameId == null) return;

    final frame = state.document.frames[frameId];
    if (frame == null) return;

    // Build JSON output
    final buffer = StringBuffer();

    // Frame JSON
    buffer.writeln('=== Frame: ${frame.name} ===');
    buffer.writeln('ID: ${frame.id}');
    buffer.writeln('Root Node: ${frame.rootNodeId}');
    buffer.writeln(
      'Size: ${frame.canvas.size.width.toInt()}x${frame.canvas.size.height.toInt()}',
    );
    buffer.writeln();

    // If specific nodes selected, show those
    if (nodeIds.isNotEmpty) {
      buffer.writeln('=== Selected Nodes ===');
      for (final nodeId in nodeIds) {
        final node = state.document.nodes[nodeId];
        if (node != null) {
          buffer.writeln();
          buffer.writeln('--- Node: ${node.name} (${node.id}) ---');
          const encoder = JsonEncoder.withIndent('  ');
          buffer.writeln(encoder.convert(node.toJson()));
        }
      }
    } else {
      // Show all nodes in frame
      buffer.writeln('=== All Nodes ===');
      final nodes = _collectFrameNodes(frame.rootNodeId);
      for (final node in nodes.values) {
        buffer.writeln();
        buffer.writeln('--- ${node.name} (${node.id}) ---');
        const encoder = JsonEncoder.withIndent('  ');
        buffer.writeln(encoder.convert(node.toJson()));
      }
    }

    // Also generate DSL
    buffer.writeln();
    buffer.writeln('=== DSL ===');
    try {
      const exporter = DslExporter();
      final dsl = exporter.exportFrame(state.document, frameId);
      buffer.writeln(dsl);
    } catch (e) {
      buffer.writeln('Error exporting DSL: $e');
    }

    final content = buffer.toString();

    // Log to console
    _log('Debug info:\n$content');

    // Show dialog
    showDialog<void>(
      context: context,
      builder: (context) => _DebugDialog(content: content),
    );
  }

  Map<String, Node> _collectFrameNodes(String rootNodeId) {
    final nodes = <String, Node>{};
    final queue = <String>[rootNodeId];

    while (queue.isNotEmpty) {
      final nodeId = queue.removeAt(0);
      final node = state.document.nodes[nodeId];
      if (node != null) {
        nodes[nodeId] = node;
        queue.addAll(node.childIds);
      }
    }

    return nodes;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // + button (stubbed)
          HoloIconButton(
            icon: HoloIconData.icon(LucideIcons.plus200),
            onPressed: () {}, // Stub
            size: 28,
            iconSize: 14,
            tooltip: 'Add context',
          ),
          const SizedBox(width: 4),

          // @ button (stubbed)
          HoloIconButton(
            icon: HoloIconData.icon(LucideIcons.atSign200),
            onPressed: () {}, // Stub
            size: 28,
            iconSize: 14,
            tooltip: 'Mention',
          ),
          const SizedBox(width: 4),

          // Debug button - show JSON/DSL for selection
          HoloIconButton(
            icon: HoloIconData.icon(LucideIcons.code200),
            onPressed: () => _showDebugDialog(context),
            size: 28,
            iconSize: 14,
            tooltip: 'Show JSON/DSL',
          ),
          const SizedBox(width: 8),

          // Model selector
          _ModelSelector(currentModel: currentModel, onChanged: onModelChanged),

          const Spacer(),

          // Show active generation count if any
          if (activeGenerations > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.accent.purple.primary.withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(context.radius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: context.colors.accent.purple.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$activeGenerations',
                    style: context.typography.body.small.copyWith(
                      color: context.colors.accent.purple.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Submit button - always enabled when there's text
          HoloIconButton(
            icon: HoloIconData.icon(LucideIcons.arrowUp200),
            onPressed: canSubmit ? onSubmit : null,
            style: HoloButtonStyle.primary(context),
            size: 28,
            iconSize: 14,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

/// Debug dialog showing JSON and DSL for selection.
class _DebugDialog extends StatelessWidget {
  const _DebugDialog({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Debug: JSON & DSL'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.background.secondary,
                  borderRadius: BorderRadius.circular(context.radius.md),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    content,
                    style: context.typography.body.small.copyWith(
                      color: context.colors.foreground.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Model selector dropdown.
class _ModelSelector extends StatelessWidget {
  const _ModelSelector({required this.currentModel, required this.onChanged});

  final LlmModel currentModel;
  final ValueChanged<LlmModel?> onChanged;

  @override
  Widget build(BuildContext context) {
    final availableModels = LlmModel.all;

    // Graceful degradation if current model not in list
    final effectiveModel =
        availableModels.contains(currentModel)
            ? currentModel
            : LlmModel.geminiFlash;

    return HoloSelect<LlmModel>(
      value: effectiveModel,
      onChanged: onChanged,
      expand: true,
      items:
          availableModels
              .map((m) => HoloSelectItem(value: m, label: m.displayName))
              .toList(),
      triggerWidth: 160,
    );
  }
}
