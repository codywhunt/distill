/// Snap System
///
/// Figma-style smart alignment snapping.
/// Finds alignment guides between dragged entities and nearby entities.

import 'dart:math' as math;
import 'dart:ui';

import '../core/entity.dart';
import '../core/world.dart';

/// Result of snap calculation
class SnapResult {
  /// Offset to apply to get snapped position
  final Offset snapOffset;

  /// Visual guides to render
  final List<SnapGuide> guides;

  /// Whether any snap was applied
  bool get didSnap => snapOffset != Offset.zero;

  const SnapResult({
    required this.snapOffset,
    required this.guides,
  });

  static const none = SnapResult(snapOffset: Offset.zero, guides: []);
}

/// A visual snap guide line
class SnapGuide {
  final Offset start;
  final Offset end;
  final SnapGuideType type;

  const SnapGuide({
    required this.start,
    required this.end,
    required this.type,
  });
}

enum SnapGuideType {
  edge,   // Solid line - edge alignment
  center, // Dashed line - center alignment
}

/// Snap engine configuration
class SnapConfig {
  /// Screen-space distance threshold for snapping
  final double threshold;

  /// Enable edge-to-edge snapping
  final bool snapEdges;

  /// Enable center-to-center snapping
  final bool snapCenters;

  /// Enable grid snapping as fallback
  final bool snapGrid;

  /// Grid size in world units
  final double gridSize;

  const SnapConfig({
    this.threshold = 8.0,
    this.snapEdges = true,
    this.snapCenters = true,
    this.snapGrid = false,
    this.gridSize = 10.0,
  });
}

/// Calculates snap alignment between entities
class SnapSystem {
  final SnapConfig config;

  SnapSystem({this.config = const SnapConfig()});

  /// Calculate snap for moving entities
  SnapResult calculate({
    required Rect movingBounds,
    required Iterable<Rect> targetBounds,
    required double zoom,
  }) {
    final threshold = config.threshold / zoom; // Convert to world units

    // Collect all snap candidates
    final xCandidates = <_SnapCandidate>[];
    final yCandidates = <_SnapCandidate>[];

    // Moving entity edges/centers
    final movingLeft = movingBounds.left;
    final movingRight = movingBounds.right;
    final movingTop = movingBounds.top;
    final movingBottom = movingBounds.bottom;
    final movingCenterX = movingBounds.center.dx;
    final movingCenterY = movingBounds.center.dy;

    for (final target in targetBounds) {
      if (config.snapEdges) {
        // Left edge alignments
        _addCandidate(xCandidates, movingLeft, target.left, threshold,
            SnapGuideType.edge, target.top, target.bottom);
        _addCandidate(xCandidates, movingLeft, target.right, threshold,
            SnapGuideType.edge, target.top, target.bottom);

        // Right edge alignments
        _addCandidate(xCandidates, movingRight, target.left, threshold,
            SnapGuideType.edge, target.top, target.bottom);
        _addCandidate(xCandidates, movingRight, target.right, threshold,
            SnapGuideType.edge, target.top, target.bottom);

        // Top edge alignments
        _addCandidate(yCandidates, movingTop, target.top, threshold,
            SnapGuideType.edge, target.left, target.right);
        _addCandidate(yCandidates, movingTop, target.bottom, threshold,
            SnapGuideType.edge, target.left, target.right);

        // Bottom edge alignments
        _addCandidate(yCandidates, movingBottom, target.top, threshold,
            SnapGuideType.edge, target.left, target.right);
        _addCandidate(yCandidates, movingBottom, target.bottom, threshold,
            SnapGuideType.edge, target.left, target.right);
      }

      if (config.snapCenters) {
        // Center alignments
        _addCandidate(xCandidates, movingCenterX, target.center.dx, threshold,
            SnapGuideType.center, target.top, target.bottom);
        _addCandidate(yCandidates, movingCenterY, target.center.dy, threshold,
            SnapGuideType.center, target.left, target.right);
      }
    }

    // Find best snap for each axis
    final bestX = _findBestSnap(xCandidates);
    final bestY = _findBestSnap(yCandidates);

    // Build snap offset
    var snapOffset = Offset.zero;
    if (bestX != null) {
      snapOffset = Offset(bestX.snapDelta, snapOffset.dy);
    }
    if (bestY != null) {
      snapOffset = Offset(snapOffset.dx, bestY.snapDelta);
    }

    // Grid snap fallback
    if (config.snapGrid && snapOffset == Offset.zero) {
      snapOffset = _snapToGrid(movingBounds.topLeft);
    }

    // Build guides
    final guides = <SnapGuide>[];
    if (bestX != null) {
      final snappedX = (bestX.movingValue + bestX.snapDelta);
      guides.add(SnapGuide(
        start: Offset(snappedX, math.min(movingBounds.top, bestX.guideStart)),
        end: Offset(snappedX, math.max(movingBounds.bottom, bestX.guideEnd)),
        type: bestX.type,
      ));
    }
    if (bestY != null) {
      final snappedY = (bestY.movingValue + bestY.snapDelta);
      guides.add(SnapGuide(
        start: Offset(math.min(movingBounds.left, bestY.guideStart), snappedY),
        end: Offset(math.max(movingBounds.right, bestY.guideEnd), snappedY),
        type: bestY.type,
      ));
    }

    return SnapResult(snapOffset: snapOffset, guides: guides);
  }

  void _addCandidate(
    List<_SnapCandidate> candidates,
    double movingValue,
    double targetValue,
    double threshold,
    SnapGuideType type,
    double guideStart,
    double guideEnd,
  ) {
    final delta = targetValue - movingValue;
    if (delta.abs() <= threshold) {
      candidates.add(_SnapCandidate(
        movingValue: movingValue,
        targetValue: targetValue,
        snapDelta: delta,
        type: type,
        guideStart: guideStart,
        guideEnd: guideEnd,
      ));
    }
  }

  _SnapCandidate? _findBestSnap(List<_SnapCandidate> candidates) {
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.snapDelta.abs().compareTo(b.snapDelta.abs()));
    return candidates.first;
  }

  Offset _snapToGrid(Offset point) {
    final snappedX = (point.dx / config.gridSize).round() * config.gridSize;
    final snappedY = (point.dy / config.gridSize).round() * config.gridSize;
    return Offset(snappedX - point.dx, snappedY - point.dy);
  }

  /// Get nearby entity bounds for snapping (excludes dragged entities)
  List<Rect> getNearbyBounds(
    World world,
    Rect queryArea, {
    Set<Entity>? exclude,
  }) {
    final bounds = <Rect>[];
    for (final (entity, worldBounds) in world.worldBounds.entries) {
      if (exclude?.contains(entity) ?? false) continue;
      if (worldBounds.rect.overlaps(queryArea.inflate(100))) {
        bounds.add(worldBounds.rect);
      }
    }
    return bounds;
  }
}

class _SnapCandidate {
  final double movingValue;
  final double targetValue;
  final double snapDelta;
  final SnapGuideType type;
  final double guideStart;
  final double guideEnd;

  _SnapCandidate({
    required this.movingValue,
    required this.targetValue,
    required this.snapDelta,
    required this.type,
    required this.guideStart,
    required this.guideEnd,
  });
}
