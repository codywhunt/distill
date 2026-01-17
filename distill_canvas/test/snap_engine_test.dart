import 'package:distill_canvas/utilities.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SnapEngine', () {
    late SnapEngine engine;

    setUp(() {
      engine = const SnapEngine(
        threshold: 10.0,
        enableEdgeSnap: true,
        enableCenterSnap: true,
      );
    });

    group('edge snapping', () {
      test('snaps left edge to left edge', () {
        const moving = Rect.fromLTWH(53, 0, 50, 50); // left at 53
        const other = Rect.fromLTWH(50, 100, 50, 50); // left at 50

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap to x=50 (other's left edge, 3px away < 10px threshold)
        expect(result.snappedBounds.left, 50);
        expect(result.didSnap, isTrue);
        expect(result.guides.length, 1);
        expect(result.guides.first.axis, Axis.vertical);
      });

      test('snaps right edge to left edge', () {
        const moving = Rect.fromLTWH(0, 0, 50, 50);
        const other = Rect.fromLTWH(52, 100, 50, 50);

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap right edge (50) to other's left edge (52)
        expect(result.snappedBounds.right, 52);
        expect(result.didSnap, isTrue);
      });

      test('snaps top edge to top edge', () {
        const moving = Rect.fromLTWH(0, 98, 50, 50);
        const other = Rect.fromLTWH(100, 100, 50, 50);

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap to y=100 (other's top edge)
        expect(result.snappedBounds.top, 100);
        expect(result.didSnap, isTrue);
      });

      test('snaps bottom edge to top edge', () {
        const moving = Rect.fromLTWH(0, 0, 50, 52);
        const other = Rect.fromLTWH(100, 50, 50, 50);

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap bottom edge (52) to other's top edge (50)
        expect(result.snappedBounds.bottom, 50);
        expect(result.didSnap, isTrue);
      });
    });

    group('center snapping', () {
      test('snaps center X to center X', () {
        // Use center-only engine to avoid edge snap interference
        const centerEngine = SnapEngine(
          threshold: 10.0,
          enableEdgeSnap: false,
          enableCenterSnap: true,
        );

        const moving = Rect.fromLTWH(0, 0, 50, 50); // center X at 25
        const other = Rect.fromLTWH(5, 500, 50, 50); // center X at 30

        final result = centerEngine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap center X from 25 to 30
        expect(result.snappedBounds.center.dx, 30);
        expect(result.didSnap, isTrue);
        expect(
          result.guides.any((g) => g.type == SnapGuideType.center),
          isTrue,
        );
      });

      test('snaps center Y to center Y', () {
        // Use center-only engine to avoid edge snap interference
        const centerEngine = SnapEngine(
          threshold: 10.0,
          enableEdgeSnap: false,
          enableCenterSnap: true,
        );

        const moving = Rect.fromLTWH(0, 0, 50, 50); // center Y at 25
        const other = Rect.fromLTWH(500, 5, 50, 50); // center Y at 30

        final result = centerEngine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap center Y from 25 to 30
        expect(result.snappedBounds.center.dy, 30);
        expect(result.didSnap, isTrue);
      });
    });

    group('threshold behavior', () {
      test('does not snap beyond threshold', () {
        const moving = Rect.fromLTWH(0, 0, 50, 50);
        const other = Rect.fromLTWH(70, 70, 50, 50); // 20px away

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should not snap (distance > threshold)
        expect(result.didSnap, isFalse);
        expect(result.snappedBounds, moving);
      });

      test('threshold scales with zoom', () {
        const moving = Rect.fromLTWH(0, 0, 50, 50);
        const other = Rect.fromLTWH(55, 0, 50, 50); // 5 world units away

        // At zoom 0.5, threshold in world units is 10/0.5 = 20
        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 0.5,
        );

        // Should snap because 5 < 20
        expect(result.didSnap, isTrue);
      });

      test('picks closest snap when multiple candidates', () {
        const moving = Rect.fromLTWH(50, 0, 50, 50);
        const other1 = Rect.fromLTWH(0, 100, 50, 50); // right edge at 50
        const other2 = Rect.fromLTWH(55, 100, 50, 50); // left edge at 55

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other1, other2],
          zoom: 1.0,
        );

        // Should snap to the closer one (50, distance 0 vs 55, distance 5)
        expect(result.snappedBounds.left, 50);
      });
    });

    group('configuration options', () {
      test('respects enableEdgeSnap = false', () {
        const engine = SnapEngine(
          threshold: 10.0,
          enableEdgeSnap: false,
          enableCenterSnap: true,
        );

        // Objects with aligned edges but NOT aligned centers
        const moving = Rect.fromLTWH(
          48,
          0,
          50,
          50,
        ); // left at 48, center X at 73
        const other = Rect.fromLTWH(
          50,
          200,
          100,
          100,
        ); // left at 50, center X at 100

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should not snap because edge snap is disabled and centers don't align
        expect(result.didSnap, isFalse);
        expect(result.snappedBounds.left, 48); // unchanged
      });

      test('respects enableCenterSnap = false', () {
        const engine = SnapEngine(
          threshold: 10.0,
          enableEdgeSnap: true,
          enableCenterSnap: false,
        );

        const moving = Rect.fromLTWH(0, 0, 50, 50);
        const other = Rect.fromLTWH(0, 100, 60, 50); // center X at 30

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap to left edge (0) but not center
        expect(result.snappedBounds.left, 0);
        expect(
          result.guides.every((g) => g.type == SnapGuideType.edge),
          isTrue,
        );
      });
    });

    group('grid snapping', () {
      test('snaps to grid when no object snap', () {
        const engine = SnapEngine(
          threshold: 10.0,
          enableEdgeSnap: true,
          enableCenterSnap: true,
          gridSize: 25.0,
        );

        const moving = Rect.fromLTWH(27, 48, 50, 50);

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [], // No other objects
          zoom: 1.0,
        );

        // Should snap to grid (25, 50)
        expect(result.snappedBounds.left, 25);
        expect(result.snappedBounds.top, 50);
        // Grid snap doesn't produce guides
        expect(result.guides, isEmpty);
      });

      test('object snap takes priority over grid snap', () {
        const engine = SnapEngine(
          threshold: 10.0,
          enableEdgeSnap: true,
          enableCenterSnap: true,
          gridSize: 25.0,
        );

        const moving = Rect.fromLTWH(27, 0, 50, 50);
        const other = Rect.fromLTWH(30, 100, 50, 50);

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other],
          zoom: 1.0,
        );

        // Should snap to object (30) not grid (25)
        expect(result.snappedBounds.left, 30);
        expect(result.guides, isNotEmpty);
      });
    });

    group('dual axis snapping', () {
      test('snaps both X and Y independently', () {
        const moving = Rect.fromLTWH(48, 97, 50, 50);
        const other1 = Rect.fromLTWH(50, 200, 50, 50); // left at 50
        const other2 = Rect.fromLTWH(200, 100, 50, 50); // top at 100

        final result = engine.calculate(
          movingBounds: moving,
          otherBounds: [other1, other2],
          zoom: 1.0,
        );

        // Should snap X to 50 and Y to 100
        expect(result.snappedBounds.left, 50);
        expect(result.snappedBounds.top, 100);
        expect(result.guides.length, 2);
      });
    });
  });

  group('SnapResult', () {
    test('none constructor creates non-snapped result', () {
      const bounds = Rect.fromLTWH(10, 20, 30, 40);
      const result = SnapResult.none(bounds);

      expect(result.snappedBounds, bounds);
      expect(result.guides, isEmpty);
      expect(result.didSnap, isFalse);
    });
  });

  group('SnapGuide', () {
    test('stores all properties correctly', () {
      const guide = SnapGuide(
        axis: Axis.vertical,
        position: 100.0,
        start: 50.0,
        end: 200.0,
        type: SnapGuideType.center,
      );

      expect(guide.axis, Axis.vertical);
      expect(guide.position, 100.0);
      expect(guide.start, 50.0);
      expect(guide.end, 200.0);
      expect(guide.type, SnapGuideType.center);
    });

    test('defaults to edge type', () {
      const guide = SnapGuide(axis: Axis.horizontal, position: 50.0);

      expect(guide.type, SnapGuideType.edge);
      expect(guide.start, isNull);
      expect(guide.end, isNull);
    });
  });
}
