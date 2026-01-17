import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/models.dart';
import '../../patch/patch_op.dart';
import '../drag_session.dart';
import '../drag_target.dart';
import '../../../../modules/canvas/canvas_state.dart';
import 'frame_renderer.dart';
import 'insertion_indicator_overlay.dart';
import 'marquee_overlay.dart';
import 'resize_handles.dart';
import 'selection_overlay.dart' as overlay;
import 'snap_guides_overlay.dart';

/// Main canvas widget for the Free Design DSL.
///
/// Orchestrates all layers (background, content, overlay) and handles
/// gesture events with priority-based hit testing.
///
/// Uses Listener pattern (like canvas_view.dart) to avoid the ~300ms tap delay
/// that occurs when both onTap and onDoubleTap are present.
class FreeDesignCanvas extends StatefulWidget {
  const FreeDesignCanvas({required this.state, this.controller, super.key});

  final CanvasState state;

  /// Optional external controller. If not provided, one will be created internally.
  ///
  /// Use this when you need to access the controller from outside (e.g., for
  /// zoom controls in a toolbar).
  final InfiniteCanvasController? controller;

  @override
  State<FreeDesignCanvas> createState() => _FreeDesignCanvasState();
}

class _FreeDesignCanvasState extends State<FreeDesignCanvas> {
  InfiniteCanvasController? _internalController;
  final _focusNode = FocusNode();

  /// Returns the active controller (external or internal).
  InfiniteCanvasController get _controller =>
      widget.controller ?? _internalController!;

  // Track last tap for double-tap detection
  int _lastTapTime = 0;
  Offset _lastTapPosition = Offset.zero;
  static const _doubleTapThreshold = Duration(milliseconds: 300);
  static const _doubleTapDistanceThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    // Only create internal controller if no external one provided
    if (widget.controller == null) {
      _internalController = InfiniteCanvasController();
    }
  }

  @override
  void dispose() {
    // Only dispose internal controller (external is managed by parent)
    _internalController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.state, _controller]),
      builder: (context, _) {
        // Use KeyboardListener + Listener pattern to avoid tap delay
        // and handle keyboard shortcuts properly (like canvas_view.dart)
        return KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Listener(
            onPointerDown: _handlePointerDown,
            child: InfiniteCanvas(
              controller: _controller,
              backgroundColor: context.colors.background.secondary,
              // Fit all frames with padding on initial load
              initialViewport: InitialViewport.fitContent(
                _getAllFramesBounds,
                padding: const EdgeInsets.all(100),
                maxZoom: 1.0,
                fallback: const InitialViewport.centerOrigin(),
              ),
              physicsConfig: const CanvasPhysicsConfig(
                minZoom: 0.1,
                maxZoom: 4.0,
              ),
              momentumConfig: CanvasMomentumConfig.figmaLike,
              layers: CanvasLayers(
                background: _buildBackground,
                content: _buildContent,
                overlay: _buildOverlay,
              ),
              // Keep drag/hover handlers but remove tap handlers
              // (handled by Listener for instant response)
              onDragStartWorld: _handleDragStart,
              onDragUpdateWorld: _handleDragUpdate,
              onDragEndWorld: _handleDragEnd,
              onHoverWorld: _handleHover,
              // Don't handle scroll when over a frame in interact mode
              shouldHandleScroll: _shouldHandleScroll,
            ),
          ),
        );
      },
    );
  }

  /// Get bounds of all frames, or a default rect if no frames.
  Rect _getAllFramesBounds() {
    if (widget.state.document.frames.isEmpty) {
      return const Rect.fromLTWH(-500, -500, 1000, 1000);
    }

    Rect? bounds;
    for (final frame in widget.state.document.frames.values) {
      final frameBounds = frame.canvas.bounds;
      bounds = bounds?.expandToInclude(frameBounds) ?? frameBounds;
    }
    return bounds ?? const Rect.fromLTWH(-500, -500, 1000, 1000);
  }

  Widget _buildBackground(BuildContext context, InfiniteCanvasController ctrl) {
    return DotBackground(
      controller: ctrl,
      spacing: 20.0,
      dotRadius: 1.0,
      color: context.colors.overlay.overlay10,
      minPixelSpacing: 12,
    );
  }

  Widget _buildContent(BuildContext context, InfiniteCanvasController ctrl) {
    // Cull frames outside viewport
    final viewportSize = MediaQuery.sizeOf(context);
    final visible = ctrl.getVisibleWorldBounds(viewportSize);

    final visibleFrames = widget.state.document.frames.values.where(
      (f) => visible.overlaps(f.canvas.bounds),
    );

    // Don't show placeholders during drag - user needs to see content
    final showPlaceholder = false;

    return Stack(
      clipBehavior: Clip.none,
      children:
          visibleFrames.map((frame) {
            // Use preview position/size during drag if this frame is being dragged
            final previewBounds = _getFramePreviewBounds(frame);

            return CanvasItem(
              position: previewBounds.topLeft,
              child: SizedBox(
                width: previewBounds.width,
                height: previewBounds.height,
                child: FrameRenderer(
                  frameId: frame.id,
                  state: widget.state,
                  showPlaceholder: showPlaceholder,
                ),
              ),
            );
          }).toList(),
    );
  }

  /// Get the current bounds for a frame, accounting for active drag sessions.
  Rect _getFramePreviewBounds(Frame frame) {
    final session = widget.state.dragSession;
    if (session == null) {
      return frame.canvas.bounds;
    }

    // Check if this frame is being dragged or resized
    final target = FrameTarget(frame.id);
    final bounds = session.getCurrentBounds(target);
    if (bounds != null) {
      return bounds;
    }

    return frame.canvas.bounds;
  }

  Widget _buildOverlay(BuildContext context, InfiniteCanvasController ctrl) {
    return Stack(
      children: [
        FreeDesignSnapGuidesOverlay(state: widget.state, controller: ctrl),
        MarqueeOverlay(state: widget.state, controller: ctrl),
        InsertionIndicatorOverlay(state: widget.state, controller: ctrl),
        overlay.SelectionOverlay(
          state: widget.state,
          controller: ctrl,
          onFrameLabelTap: _selectFrame,
        ),
        ResizeHandles(state: widget.state, controller: ctrl),
        // Note: PromptBoxOverlay is rendered outside the canvas in CanvasCenterContent
        // so that pointer events work correctly (not intercepted by canvas Listener)
      ],
    );
  }

  /// Select a frame by ID (used by frame label tap).
  void _selectFrame(String frameId) {
    final addToSelection = HardwareKeyboard.instance.isShiftPressed;
    widget.state.select(FrameTarget(frameId), addToSelection: addToSelection);
  }

  // === Pointer Handlers ===

  /// Handle pointer down for instant selection (no gesture disambiguation delay).
  ///
  /// Also detects double-taps manually since we're bypassing GestureDetector.
  void _handlePointerDown(PointerDownEvent event) {
    // Only handle primary button (left click / touch)
    if (event.buttons != kPrimaryButton) return;

    // Request focus so keyboard shortcuts work after clicking on canvas
    _focusNode.requestFocus();

    final localPos = event.localPosition;
    final worldPos = _controller.viewToWorld(localPos);

    // Check for double-tap first (applies to all targets)
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - _lastTapTime;
    final distDiff = (localPos - _lastTapPosition).distance;
    final isDoubleTap =
        timeDiff < _doubleTapThreshold.inMilliseconds &&
        distDiff < _doubleTapDistanceThreshold;

    // Priority 0: Check if clicking on a frame label (screen-space)
    final frameLabelHit = _hitTestFrameLabels(localPos);
    if (frameLabelHit != null) {
      if (isDoubleTap) {
        // Double-click on frame label: zoom to fit frame
        _zoomToFitFrame(frameLabelHit);
        _lastTapTime = 0;
      } else {
        // Single-click: select frame
        _selectFrame(frameLabelHit);
        _lastTapTime = now;
        _lastTapPosition = localPos;
      }
      return;
    }

    // Handle canvas content clicks
    if (isDoubleTap) {
      _handleDoubleTap(worldPos);
      _lastTapTime = 0; // Reset to avoid triple-tap
    } else {
      _handleTap(worldPos);
      _lastTapTime = now;
      _lastTapPosition = localPos;
    }
  }

  /// Hit test frame labels in screen-space.
  /// Returns frameId if hit, null otherwise.
  String? _hitTestFrameLabels(Offset viewPos) {
    for (final frame in widget.state.document.frames.values) {
      final worldBounds = frame.canvas.bounds;
      final viewBounds = _controller.worldToViewRect(worldBounds);

      // Frame label is positioned above the frame
      final labelLeft = viewBounds.left;
      final labelTop = viewBounds.top - 24;
      final labelWidth = 150.0; // Approximate width
      final labelHeight = 20.0; // Approximate height

      final labelRect = Rect.fromLTWH(
        labelLeft,
        labelTop,
        labelWidth,
        labelHeight,
      );

      if (labelRect.contains(viewPos)) {
        return frame.id;
      }
    }
    return null;
  }

  /// Handle keyboard events for shortcuts.
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Don't handle keyboard shortcuts when a text field has focus
    // This allows the prompt box TextField to receive all key events
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus != _focusNode) {
      // Check if focus is in a text input by looking at the focus node's context
      final focusContext = primaryFocus.context;
      if (focusContext != null) {
        // If the focused widget is an EditableText or its descendant, don't intercept
        final editableText =
            focusContext.findAncestorWidgetOfExactType<EditableText>();
        if (editableText != null) {
          return KeyEventResult.ignored;
        }
      }
    }

    // Undo - Cmd+Z (macOS) or Ctrl+Z (other)
    final isUndo =
        event.logicalKey == LogicalKeyboardKey.keyZ &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        !HardwareKeyboard.instance.isShiftPressed;
    if (isUndo) {
      widget.state.store.undo();
      return KeyEventResult.handled;
    }

    // Redo - Cmd+Shift+Z or Ctrl+Shift+Z or Ctrl+Y
    final isRedo =
        (event.logicalKey == LogicalKeyboardKey.keyZ &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            HardwareKeyboard.instance.isShiftPressed) ||
        (event.logicalKey == LogicalKeyboardKey.keyY &&
            HardwareKeyboard.instance.isControlPressed);
    if (isRedo) {
      widget.state.store.redo();
      return KeyEventResult.handled;
    }

    // Delete key - delete selected items
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _deleteSelection();
      return KeyEventResult.handled;
    }

    // Escape - deselect all
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.state.deselectAll();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Delete all selected frames and nodes.
  void _deleteSelection() {
    final selection = widget.state.selection;
    if (selection.isEmpty) return;

    final patches = <PatchOp>[];

    for (final target in selection) {
      switch (target) {
        case FrameTarget(:final frameId):
          patches.add(RemoveFrame(frameId));

        case NodeTarget(:final patchTarget):
          // Only delete nodes that can be patched (not inside instances)
          if (patchTarget != null) {
            patches.add(DeleteNode(patchTarget));
          }
      }
    }

    if (patches.isNotEmpty) {
      widget.state.store.applyPatches(patches);
      widget.state.deselectAll();
    }
  }

  // === Gesture Handlers ===

  void _handleTap(Offset worldPos) {
    // Priority 1: Resize handle hit test - don't deselect if clicking on handles
    if (widget.state.selection.length == 1) {
      final viewPos = _controller.worldToView(worldPos);
      final handle = widget.state.hitTestResizeHandle(
        viewPos,
        _controller.worldToView,
        kHandleHitRadius,
      );
      if (handle != null) {
        // Clicking on a resize handle - don't change selection
        return;
      }
    }

    // Priority 2: Node hit test within frames
    // Frames are now selected only via their labels (Priority 0)
    final frameTarget = widget.state.hitTestFrame(worldPos);
    if (frameTarget != null) {
      // Skip node selection if frame is in interact mode - let content handle events
      if (widget.state.isInteractMode(frameTarget.frameId)) {
        return;
      }

      // Check for node within this frame (including root node)
      final nodeTarget = widget.state.hitTestNode(
        worldPos,
        frameTarget.frameId,
      );
      if (nodeTarget != null) {
        final addToSelection = HardwareKeyboard.instance.isShiftPressed;
        widget.state.select(nodeTarget, addToSelection: addToSelection);
        return;
      }
    }

    // Priority 3: Empty space - deselect
    widget.state.deselectAll();
  }

  void _handleDoubleTap(Offset worldPos) {
    // Check if tapping on a frame
    final frameTarget = widget.state.hitTestFrame(worldPos);

    if (frameTarget == null) {
      // Double-clicked on empty space - create blank frame and select it
      // User can then use the prompt box to generate content
      _createBlankFrameAndSelect(worldPos);
      return;
    }

    // Skip if frame is in interact mode
    if (widget.state.isInteractMode(frameTarget.frameId)) {
      return;
    }

    // Check for node hit within frame
    final nodeTarget = widget.state.hitTestNode(worldPos, frameTarget.frameId);
    if (nodeTarget != null) {
      // Double-click on node: zoom to fit that node
      _zoomToFitNode(nodeTarget);
      return;
    }

    // Double-click on frame content (no specific node): zoom to fit frame
    _zoomToFitFrame(frameTarget.frameId);
  }

  /// Animate viewport to fit a frame with padding.
  void _zoomToFitFrame(String frameId) {
    final frame = widget.state.document.frames[frameId];
    if (frame == null) return;

    _controller.animateToFit(
      frame.canvas.bounds,
      padding: const EdgeInsets.all(200),
    );

    // Focus the prompt box so user can start typing immediately
    widget.state.requestPromptFocus();
  }

  /// Animate viewport to fit a node with padding.
  void _zoomToFitNode(NodeTarget target) {
    final frame = widget.state.document.frames[target.frameId];
    if (frame == null) return;

    // Get node bounds in frame-local coordinates
    final localBounds = widget.state.getNodeBounds(
      target.frameId,
      target.expandedId,
    );
    if (localBounds == null) return;

    // Convert to world coordinates
    final worldBounds = localBounds.shift(frame.canvas.position);

    _controller.animateToFit(worldBounds, padding: const EdgeInsets.all(300));

    // Focus the prompt box so user can start typing immediately
    widget.state.requestPromptFocus();
  }

  /// Create a new blank frame at the given position, select it, and zoom to it.
  ///
  /// The user can then use the prompt box overlay to describe what they want,
  /// and the AI will generate content into the selected frame.
  void _createBlankFrameAndSelect(Offset worldPos) {
    // Generate unique IDs
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final frameId = 'frame_$timestamp';
    final rootNodeId = 'node_${timestamp}_root';

    // Default frame size (iPhone-ish)
    const frameSize = Size(375, 812);

    // Center the frame on the double-click position
    final centeredPosition = Offset(
      worldPos.dx - frameSize.width / 2,
      worldPos.dy - frameSize.height / 2,
    );

    final now = DateTime.now();

    // Create blank frame
    final frame = Frame(
      id: frameId,
      name: 'New Frame',
      rootNodeId: rootNodeId,
      canvas: CanvasPlacement(position: centeredPosition, size: frameSize),
      createdAt: now,
      updatedAt: now,
    );

    final rootNode = Node(
      id: rootNodeId,
      name: 'Root',
      type: NodeType.container,
      props: const ContainerProps(),
      layout: const NodeLayout(size: SizeMode.fill()),
      style: NodeStyle(fill: SolidFill(HexColor('#FFFFFF'))),
    );

    // Apply to store
    widget.state.store.applyPatches([InsertNode(rootNode), InsertFrame(frame)]);

    // Select the new frame (this shows context in the prompt box)
    widget.state.select(FrameTarget(frameId));

    // Animate viewport to fit the new frame
    _controller.animateToFit(
      frame.canvas.bounds,
      padding: const EdgeInsets.all(200),
    );

    // Focus the prompt box so user can start typing immediately
    widget.state.requestPromptFocus();
  }

  void _handleDragStart(CanvasDragStartDetails details) {
    final worldPos = details.worldPosition;
    final viewPos = details.viewPosition;

    // Priority 0: Check for frame label drag (screen-space)
    final frameLabelHit = _hitTestFrameLabels(viewPos);
    if (frameLabelHit != null) {
      // Select frame if not already selected
      if (!widget.state.selectedFrameIds.contains(frameLabelHit)) {
        final addToSelection = HardwareKeyboard.instance.isShiftPressed;
        widget.state.select(
          FrameTarget(frameLabelHit),
          addToSelection: addToSelection,
        );
      }
      // Start drag
      widget.state.startDrag();
      return;
    }

    // Priority 1: Check for resize handle
    if (widget.state.selection.length == 1) {
      final handle = widget.state.hitTestResizeHandle(
        viewPos,
        _controller.worldToView,
        kHandleHitRadius,
      );
      if (handle != null) {
        widget.state.startResize(handle);
        return;
      }
    }

    // Priority 2: Check if dragging selected item (frame or node)
    final frameTarget = widget.state.hitTestFrame(worldPos);
    if (frameTarget != null) {
      // Skip drag handling if frame is in interact mode - let content handle events
      if (widget.state.isInteractMode(frameTarget.frameId)) {
        return;
      }

      // Check if we have nodes selected and are clicking within a selected node's frame
      final selectedNodes = widget.state.selectedNodes;
      if (selectedNodes.isNotEmpty) {
        final selectedFrameIds = selectedNodes.map((n) => n.frameId).toSet();
        if (selectedFrameIds.contains(frameTarget.frameId)) {
          // Dragging with nodes selected - start node drag
          widget.state.startDrag();
          return;
        }
      }

      // Check if frame itself is selected
      if (widget.state.selectedFrameIds.contains(frameTarget.frameId)) {
        widget.state.startDrag();
        return;
      }
    }

    // Start marquee selection
    widget.state.startMarquee(worldPos);
  }

  void _handleDragUpdate(CanvasDragUpdateDetails details) {
    if (!widget.state.isDragging) return;

    final session = widget.state.dragSession!;

    // Handle marquee separately (uses absolute position, not delta)
    if (session.mode == DragMode.marquee) {
      widget.state.updateMarquee(details.worldPosition);
      return;
    }

    // Update drop target for move operations
    if (session.mode == DragMode.move && session.targets.isNotEmpty) {
      final target = session.targets.first;

      // Only track drop target for nodes (not frames)
      if (target is NodeTarget) {
        // Detect drop target container
        final frameId = target.frameId;
        final dropTarget = widget.state.hitTestContainer(
          frameId,
          details.worldPosition,
        );

        // Update session drop target
        session.dropTarget = dropTarget;
        session.dropFrameId = frameId;

        // Calculate insertion index if valid drop target
        if (dropTarget != null) {
          session.insertionIndex = widget.state.calculateInsertionIndex(
            frameId,
            dropTarget,
            details.worldPosition,
          );

          // Calculate reflow offsets for sibling animation
          if (session.insertionIndex != null) {
            final draggedSize =
                session.startSizes[target] ?? const Size(100, 100);
            session.reflowOffsets = widget.state.calculateReflowOffsets(
              frameId,
              dropTarget,
              session.insertionIndex!,
              draggedSize,
            );
          } else {
            session.reflowOffsets = {};
          }
        } else {
          session.insertionIndex = null;
          session.reflowOffsets = {};
        }
      }
    }

    final worldDelta = details.worldDelta;

    // Check for grid snap (Shift key)
    final gridSize = HardwareKeyboard.instance.isShiftPressed ? 10.0 : null;
    // Check for smart guides disable (Meta/Cmd key)
    final useSmartGuides = !HardwareKeyboard.instance.isMetaPressed;

    if (session.mode == DragMode.resize) {
      widget.state.updateResize(
        worldDelta,
        gridSize: gridSize,
        useSmartGuides: useSmartGuides,
        zoom: _controller.zoom,
      );
    } else if (session.mode == DragMode.move) {
      widget.state.updateDrag(
        worldDelta,
        gridSize: gridSize,
        useSmartGuides: useSmartGuides,
        zoom: _controller.zoom,
      );
    }
  }

  void _handleDragEnd(CanvasDragEndDetails details) {
    if (!widget.state.isDragging) return;

    final session = widget.state.dragSession!;
    if (session.mode == DragMode.marquee) {
      widget.state.endMarquee();
    } else {
      widget.state.endDrag();
    }
  }

  void _handleHover(Offset worldPos) {
    final frameTarget = widget.state.hitTestFrame(worldPos);
    if (frameTarget != null) {
      // Skip hover detection for frames in interact mode
      if (widget.state.isInteractMode(frameTarget.frameId)) {
        widget.state.setHovered(null);
        return;
      }

      // Check for node within this frame
      final nodeTarget = widget.state.hitTestNode(
        worldPos,
        frameTarget.frameId,
      );
      if (nodeTarget != null) {
        widget.state.setHovered(nodeTarget);
        return;
      }
    }
    widget.state.setHovered(frameTarget);
  }

  /// Determine if the canvas should handle scroll events at the given view position.
  ///
  /// Returns false when over a frame in interact mode, allowing the frame's
  /// scrollable content to receive scroll events instead of canvas pan.
  bool _shouldHandleScroll(Offset viewPos) {
    final worldPos = _controller.viewToWorld(viewPos);
    final frameTarget = widget.state.hitTestFrame(worldPos);
    if (frameTarget != null &&
        widget.state.isInteractMode(frameTarget.frameId)) {
      return false;
    }
    return true;
  }
}
