/// Core data models for drag and drop operations.
///
/// This library provides the foundational types for the drag & drop system:
///
/// - [DropIntent]: What kind of drop operation (reorder, reparent, none)
/// - [DropPreview]: Single source of truth for drop state during drag
/// - [DropCommitPlan]: Information needed to commit a drop to the document
/// - [DragSession]: Ephemeral state during a drag operation
/// - [ContainerHit]: Result of hitting a container during drag
/// - [FrameLookups]: Pre-computed ID mappings for a frame
///
/// ## Design Principles
///
/// 1. **Single source of truth**: [DropPreview] contains all computed drop state
/// 2. **ID domain separation**: Expanded IDs for rendering, doc IDs for patching
/// 3. **Pre-computed visuals**: Indicator rect and reflow offsets are computed once
/// 4. **Invariant enforcement**: Debug asserts verify critical constraints
///
/// ## Usage
///
/// ```dart
/// import 'package:distill_editor/src/free_design/canvas/drag/drag.dart';
///
/// // Create a move drag session
/// final session = DragSession.move(
///   targets: selection,
///   startPositions: positions,
///   startSizes: sizes,
///   originalParents: parentMap,
///   lockedFrameId: frameId,
/// );
///
/// // Compute drop preview on each update
/// session.dropPreview = builder.compute(...);
///
/// // Commit on drop
/// final plan = DropCommitPlan.fromPreview(session.dropPreview!, originalParents);
/// if (plan.canCommit) {
///   applyPatches(generateDropPatches(plan));
/// }
/// ```
library;

export 'container_hit.dart';
export 'drag_debug.dart';
export 'drag_session.dart';
export 'drop_commit_plan.dart';
export 'drop_intent.dart';
export 'drop_preview.dart';
export 'drop_patches.dart';
export 'drop_preview_builder.dart';
export 'frame_lookups.dart';
