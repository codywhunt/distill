import 'dart:ui';

import 'package:distill_canvas/utilities.dart';

import '../patch/patch_op.dart';
import 'drag_target.dart';
import 'drop_preview.dart';

export 'package:distill_canvas/utilities.dart' show ResizeEdge;

/// The mode of a drag operation.
enum DragMode {
  /// Moving selected objects.
  move,

  /// Resizing a selected object.
  resize,

  /// Marquee selection (drag to select).
  marquee,
}

/// Handle positions for resize operations.
enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  /// Whether this handle affects the left edge.
  bool get isLeft =>
      this == topLeft || this == middleLeft || this == bottomLeft;

  /// Whether this handle affects the right edge.
  bool get isRight =>
      this == topRight || this == middleRight || this == bottomRight;

  /// Whether this handle affects the top edge.
  bool get isTop => this == topLeft || this == topCenter || this == topRight;

  /// Whether this handle affects the bottom edge.
  bool get isBottom =>
      this == bottomLeft || this == bottomCenter || this == bottomRight;

  /// Whether this handle only affects horizontal size.
  bool get isHorizontalOnly => this == middleLeft || this == middleRight;

  /// Whether this handle only affects vertical size.
  bool get isVerticalOnly => this == topCenter || this == bottomCenter;

  /// Get the active edges for this resize handle for snap engine.
  Set<ResizeEdge> get activeEdges {
    final edges = <ResizeEdge>{};
    if (isLeft) edges.add(ResizeEdge.left);
    if (isRight) edges.add(ResizeEdge.right);
    if (isTop) edges.add(ResizeEdge.top);
    if (isBottom) edges.add(ResizeEdge.bottom);
    return edges;
  }
}

/// Minimum size for resized objects.
const double kMinimumSize = 50.0;

/// Ephemeral state during a drag operation.
///
/// A drag session is created when the user starts dragging and destroyed
/// when they release. Patches are only generated on drop via [generatePatches].
class DragSession {
  /// The drag mode.
  final DragMode mode;

  /// The targets being dragged.
  final Set<DragTarget> targets;

  /// Starting positions for each target (in world coordinates for frames,
  /// relative for nodes).
  final Map<DragTarget, Offset> startPositions;

  /// Starting sizes for each target (for resize mode).
  final Map<DragTarget, Size> startSizes;

  /// The resize handle being dragged (for resize mode).
  final ResizeHandle? handle;

  /// Running delta accumulator (raw user input).
  Offset accumulator;

  /// Snap offset applied on top of accumulator.
  ///
  /// This is separate from [accumulator] to avoid jank when entering/exiting
  /// snap zones. The effective position is [accumulator] + [snapOffset].
  Offset snapOffset;

  /// Active snap guides to render.
  List<SnapGuide> activeGuides;

  /// Start position for marquee mode (world coordinates).
  final Offset? marqueeStart;

  /// Currently hovered drop target (document node ID for patching).
  String? dropTarget;

  /// Expanded ID of the drop target (for bounds lookup in render tree).
  /// This is the specific instance in the expanded scene that was hit-tested.
  String? dropTargetExpandedId;

  /// Insertion index within drop target.
  int? insertionIndex;

  /// Frame containing drop target.
  String? dropFrameId;

  /// Original parent IDs for each node target (for reparenting detection).
  final Map<String, String> originalParents;

  /// Reflow offsets for siblings during drag (for animation preview).
  /// Maps expandedId → offset to apply temporarily.
  Map<String, Offset> reflowOffsets;

  /// Filtered children list for insertion (excludes dragged nodes).
  /// Computed once during drag update and reused for indicator + reflow.
  List<String> insertionChildren;

  /// Last insertion index for hysteresis (prevents flip-flop at center).
  int? lastInsertionIndex;

  /// Last cursor position when insertion index changed (for hysteresis).
  Offset? lastInsertionCursor;

  /// Single source of truth for drop preview state.
  ///
  /// This replaces the scattered fields (dropTarget, dropTargetExpandedId,
  /// insertionIndex, reflowOffsets, insertionChildren) with one authoritative
  /// model computed by DropPreviewEngine.
  DropPreview? dropPreview;

  DragSession._({
    required this.mode,
    required this.targets,
    required this.startPositions,
    required this.startSizes,
    this.handle,
    required this.accumulator,
    required this.activeGuides,
    this.marqueeStart,
    this.originalParents = const {},
  }) : snapOffset = Offset.zero,
       dropTarget = null,
       dropTargetExpandedId = null,
       insertionIndex = null,
       dropFrameId = null,
       reflowOffsets = const {},
       insertionChildren = const [],
       lastInsertionIndex = null,
       lastInsertionCursor = null,
       dropPreview = null;

  /// Creates a move drag session.
  factory DragSession.move({
    required Set<DragTarget> targets,
    required Map<DragTarget, Offset> startPositions,
    required Map<DragTarget, Size> startSizes,
    Map<String, String> originalParents = const {},
  }) {
    return DragSession._(
      mode: DragMode.move,
      targets: targets,
      startPositions: startPositions,
      startSizes: startSizes,
      handle: null,
      accumulator: Offset.zero,
      activeGuides: const [],
      originalParents: originalParents,
    );
  }

  /// Creates a resize drag session.
  factory DragSession.resize({
    required DragTarget target,
    required ResizeHandle handle,
    required Offset startPosition,
    required Size startSize,
  }) {
    return DragSession._(
      mode: DragMode.resize,
      targets: {target},
      startPositions: {target: startPosition},
      startSizes: {target: startSize},
      handle: handle,
      accumulator: Offset.zero,
      activeGuides: const [],
    );
  }

  /// Creates a marquee selection session.
  factory DragSession.marquee({required Offset startPosition}) {
    return DragSession._(
      mode: DragMode.marquee,
      targets: const {},
      startPositions: const {},
      startSizes: const {},
      handle: null,
      accumulator: startPosition, // Current position (updated during drag)
      activeGuides: const [],
      marqueeStart: startPosition, // Start position (fixed)
    );
  }

  /// Get the effective offset including snap adjustment.
  Offset get effectiveOffset => accumulator + snapOffset;

  /// Get the current bounds for a target without committing.
  ///
  /// Returns null if the target isn't part of this session.
  Rect? getCurrentBounds(DragTarget target) {
    final startPos = startPositions[target];
    if (startPos == null) return null;

    if (mode == DragMode.move) {
      final startSize = startSizes[target] ?? const Size(100, 100);
      // Use effectiveOffset to include snap adjustment for smooth visuals
      final offset = effectiveOffset;
      return Rect.fromLTWH(
        startPos.dx + offset.dx,
        startPos.dy + offset.dy,
        startSize.width,
        startSize.height,
      );
    } else if (mode == DragMode.resize) {
      final startSize = startSizes[target];
      if (startSize == null || handle == null) return null;

      // Resize uses accumulator directly (snap is already applied to accumulator)
      return _calculateResizedBounds(startPos, startSize, accumulator, handle!);
    }

    return null;
  }

  /// Get the current marquee rectangle.
  ///
  /// Returns null if this isn't a marquee session.
  Rect? getMarqueeRect() {
    if (mode != DragMode.marquee || marqueeStart == null) return null;

    // marqueeStart is fixed, accumulator tracks current position
    return Rect.fromPoints(marqueeStart!, accumulator);
  }

  /// Generate patches for all targets based on accumulated delta.
  ///
  /// Only targets with [NodeTarget.canPatch] == true will generate patches.
  /// Nodes inside component instances are skipped (v1 limitation).
  List<PatchOp> generatePatches() {
    final patches = <PatchOp>[];

    for (final target in targets) {
      switch (target) {
        case FrameTarget(:final frameId):
          final startPos = startPositions[target];
          if (startPos == null) continue;

          if (mode == DragMode.move) {
            // Use effectiveOffset to include snap adjustment
            final newPos = startPos + effectiveOffset;
            patches.add(
              SetFrameProp(
                frameId: frameId,
                path: '/canvas/position',
                value: {'x': newPos.dx, 'y': newPos.dy},
              ),
            );
          } else if (mode == DragMode.resize && handle != null) {
            final startSize = startSizes[target];
            if (startSize == null) continue;

            final bounds = _calculateResizedBounds(
              startPos,
              startSize,
              accumulator,
              handle!,
            );

            patches.add(
              SetFrameProp(
                frameId: frameId,
                path: '/canvas/position',
                value: {'x': bounds.left, 'y': bounds.top},
              ),
            );
            patches.add(
              SetFrameProp(
                frameId: frameId,
                path: '/canvas/size',
                value: {'width': bounds.width, 'height': bounds.height},
              ),
            );
          }

        case NodeTarget(:final patchTarget, :final frameId):
          // Skip nodes inside instances (canPatch == false)
          if (patchTarget == null) continue;

          final startPos = startPositions[target];
          if (startPos == null) continue;

          if (mode == DragMode.move) {
            // Check if parent changed (reparenting)
            final originalParent = originalParents[patchTarget];
            final newParent = dropTarget;

            if (newParent != null &&
                dropFrameId == frameId &&
                originalParent != null &&
                newParent != originalParent) {
              // Reparenting - generate MoveNode patch
              patches.add(
                MoveNode(
                  id: patchTarget,
                  newParentId: newParent,
                  index: insertionIndex ?? -1,
                ),
              );

              // Also update position (use absolute for MVP)
              final newPos = startPos + effectiveOffset;
              patches.add(
                SetProp(
                  id: patchTarget,
                  path: '/layout/position',
                  value: {'mode': 'absolute', 'x': newPos.dx, 'y': newPos.dy},
                ),
              );
            } else {
              // Same parent - just update position
              final newPos = startPos + effectiveOffset;
              patches.add(
                SetProp(
                  id: patchTarget,
                  path: '/layout/position',
                  value: {'mode': 'absolute', 'x': newPos.dx, 'y': newPos.dy},
                ),
              );
            }
          } else if (mode == DragMode.resize && handle != null) {
            final startSize = startSizes[target];
            if (startSize == null) continue;

            final bounds = _calculateResizedBounds(
              startPos,
              startSize,
              accumulator,
              handle!,
            );

            patches.add(
              SetProp(
                id: patchTarget,
                path: '/layout/position',
                value: {'mode': 'absolute', 'x': bounds.left, 'y': bounds.top},
              ),
            );
            patches.add(
              SetProp(
                id: patchTarget,
                path: '/layout/size/width',
                value: bounds.width,
              ),
            );
            patches.add(
              SetProp(
                id: patchTarget,
                path: '/layout/size/height',
                value: bounds.height,
              ),
            );
          }
      }
    }

    return patches;
  }

  /// Calculate resized bounds based on handle and delta.
  static Rect _calculateResizedBounds(
    Offset startPos,
    Size startSize,
    Offset delta,
    ResizeHandle handle,
  ) {
    var left = startPos.dx;
    var top = startPos.dy;
    var width = startSize.width;
    var height = startSize.height;

    // Apply delta based on handle position
    if (handle.isLeft) {
      left += delta.dx;
      width -= delta.dx;
    } else if (handle.isRight) {
      width += delta.dx;
    }

    if (handle.isTop) {
      top += delta.dy;
      height -= delta.dy;
    } else if (handle.isBottom) {
      height += delta.dy;
    }

    // Enforce minimum size with position compensation
    if (width < kMinimumSize) {
      if (handle.isLeft) {
        // Compensate position when hitting min from left
        left -= kMinimumSize - width;
      }
      width = kMinimumSize;
    }

    if (height < kMinimumSize) {
      if (handle.isTop) {
        // Compensate position when hitting min from top
        top -= kMinimumSize - height;
      }
      height = kMinimumSize;
    }

    return Rect.fromLTWH(left, top, width, height);
  }

  @override
  String toString() =>
      'DragSession($mode, targets: ${targets.length}, delta: $accumulator)';
}
