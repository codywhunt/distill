import 'package:distill_canvas/src/_internal/viewport.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasViewport', () {
    group('coordinate conversion', () {
      test('viewToWorld converts correctly at zoom 1', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        expect(
          viewport.viewToWorld(const Offset(100, 100)),
          equals(const Offset(100, 100)),
        );
      });

      test('viewToWorld converts correctly with pan', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: const Offset(50, 50));

        // View (100, 100) with pan (50, 50) = world (50, 50)
        expect(
          viewport.viewToWorld(const Offset(100, 100)),
          equals(const Offset(50, 50)),
        );
      });

      test('viewToWorld converts correctly with zoom', () {
        final viewport = CanvasViewport(zoom: 2.0, pan: Offset.zero);

        // View (100, 100) at zoom 2 = world (50, 50)
        expect(
          viewport.viewToWorld(const Offset(100, 100)),
          equals(const Offset(50, 50)),
        );
      });

      test('viewToWorld converts correctly with pan and zoom', () {
        final viewport = CanvasViewport(zoom: 2.0, pan: const Offset(100, 100));

        // (viewPoint - pan) / zoom = (100, 100 - 100, 100) / 2 = (0, 0)
        expect(
          viewport.viewToWorld(const Offset(100, 100)),
          equals(Offset.zero),
        );
      });

      test('worldToView is inverse of viewToWorld', () {
        final viewport = CanvasViewport(zoom: 1.5, pan: const Offset(30, 40));

        const worldPoint = Offset(100, 200);
        final viewPoint = viewport.worldToView(worldPoint);
        final backToWorld = viewport.viewToWorld(viewPoint);

        expect(backToWorld.dx, closeTo(worldPoint.dx, 0.0001));
        expect(backToWorld.dy, closeTo(worldPoint.dy, 0.0001));
      });

      test('viewToWorldRect converts correctly', () {
        final viewport = CanvasViewport(zoom: 2.0, pan: const Offset(100, 100));

        const viewRect = Rect.fromLTWH(100, 100, 200, 200);
        final worldRect = viewport.viewToWorldRect(viewRect);

        // (100 - 100) / 2 = 0, (200) / 2 = 100
        expect(worldRect.left, equals(0.0));
        expect(worldRect.top, equals(0.0));
        expect(worldRect.width, equals(100.0));
        expect(worldRect.height, equals(100.0));
      });

      test('worldToViewRect is inverse of viewToWorldRect', () {
        final viewport = CanvasViewport(zoom: 1.5, pan: const Offset(30, 40));

        const worldRect = Rect.fromLTWH(100, 200, 50, 80);
        final viewRect = viewport.worldToViewRect(worldRect);
        final backToWorld = viewport.viewToWorldRect(viewRect);

        expect(backToWorld.left, closeTo(worldRect.left, 0.0001));
        expect(backToWorld.top, closeTo(worldRect.top, 0.0001));
        expect(backToWorld.width, closeTo(worldRect.width, 0.0001));
        expect(backToWorld.height, closeTo(worldRect.height, 0.0001));
      });

      test('worldToViewSize scales by zoom', () {
        final viewport = CanvasViewport(zoom: 2.0, pan: Offset.zero);

        expect(
          viewport.worldToViewSize(const Size(100, 50)),
          equals(const Size(200, 100)),
        );
      });

      test('viewToWorldSize scales by zoom', () {
        final viewport = CanvasViewport(zoom: 2.0, pan: Offset.zero);

        expect(
          viewport.viewToWorldSize(const Size(200, 100)),
          equals(const Size(100, 50)),
        );
      });
    });

    group('edge cases', () {
      test('negative coordinates work correctly', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        expect(
          viewport.viewToWorld(const Offset(-100, -100)),
          equals(const Offset(-100, -100)),
        );
        expect(
          viewport.worldToView(const Offset(-100, -100)),
          equals(const Offset(-100, -100)),
        );
      });

      test('negative coordinates with pan', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: const Offset(-50, -50));

        // View (-100, -100) with pan (-50, -50) = world (-50, -50)
        expect(
          viewport.viewToWorld(const Offset(-100, -100)),
          equals(const Offset(-50, -50)),
        );
      });

      test('negative coordinates with zoom', () {
        final viewport = CanvasViewport(zoom: 2.0, pan: Offset.zero);

        expect(
          viewport.viewToWorld(const Offset(-100, -100)),
          equals(const Offset(-50, -50)),
        );
      });

      test('very small zoom values work', () {
        final viewport = CanvasViewport(zoom: 0.01, pan: Offset.zero);

        // View (1, 1) at zoom 0.01 = world (100, 100)
        expect(
          viewport.viewToWorld(const Offset(1, 1)),
          equals(const Offset(100, 100)),
        );
      });

      test('very large zoom values work', () {
        final viewport = CanvasViewport(zoom: 100.0, pan: Offset.zero);

        // View (100, 100) at zoom 100 = world (1, 1)
        expect(
          viewport.viewToWorld(const Offset(100, 100)),
          equals(const Offset(1, 1)),
        );
      });

      test('zero offset at origin', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        expect(viewport.viewToWorld(Offset.zero), equals(Offset.zero));
        expect(viewport.worldToView(Offset.zero), equals(Offset.zero));
      });

      test('handles very large coordinates', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        const largePoint = Offset(1e10, 1e10);
        expect(viewport.viewToWorld(largePoint), equals(largePoint));
        expect(viewport.worldToView(largePoint), equals(largePoint));
      });
    });

    group('transform', () {
      test('transform is cached', () {
        final viewport = CanvasViewport(zoom: 1.5, pan: const Offset(10, 20));

        final transform1 = viewport.transform;
        final transform2 = viewport.transform;

        // Same instance (cached)
        expect(identical(transform1, transform2), isTrue);
      });

      test('transform cache invalidates on zoom change', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        final transform1 = viewport.transform;
        viewport.zoom = 2.0;
        final transform2 = viewport.transform;

        expect(identical(transform1, transform2), isFalse);
      });

      test('transform cache invalidates on pan change', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        final transform1 = viewport.transform;
        viewport.pan = const Offset(100, 100);
        final transform2 = viewport.transform;

        expect(identical(transform1, transform2), isFalse);
      });

      test('setting same zoom value does not invalidate cache', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        final transform1 = viewport.transform;
        viewport.zoom = 1.0; // Same value
        final transform2 = viewport.transform;

        // Cache should still be valid
        expect(identical(transform1, transform2), isTrue);
      });

      test('setting same pan value does not invalidate cache', () {
        final viewport = CanvasViewport(zoom: 1.0, pan: Offset.zero);

        final transform1 = viewport.transform;
        viewport.pan = Offset.zero; // Same value
        final transform2 = viewport.transform;

        expect(identical(transform1, transform2), isTrue);
      });
    });

    group('copyWith', () {
      test('creates independent copy', () {
        final original = CanvasViewport(zoom: 1.5, pan: const Offset(10, 20));
        final copy = original.copyWith();

        expect(copy.zoom, equals(original.zoom));
        expect(copy.pan, equals(original.pan));

        // Modifying copy doesn't affect original
        copy.zoom = 3.0;
        expect(original.zoom, equals(1.5));
      });

      test('copyWith zoom', () {
        final original = CanvasViewport(zoom: 1.5, pan: const Offset(10, 20));
        final copy = original.copyWith(zoom: 2.0);

        expect(copy.zoom, equals(2.0));
        expect(copy.pan, equals(const Offset(10, 20)));
      });

      test('copyWith pan', () {
        final original = CanvasViewport(zoom: 1.5, pan: const Offset(10, 20));
        final copy = original.copyWith(pan: const Offset(30, 40));

        expect(copy.zoom, equals(1.5));
        expect(copy.pan, equals(const Offset(30, 40)));
      });
    });

    group('equality', () {
      test('equal viewports are equal', () {
        final v1 = CanvasViewport(zoom: 1.5, pan: const Offset(10, 20));
        final v2 = CanvasViewport(zoom: 1.5, pan: const Offset(10, 20));

        expect(v1, equals(v2));
        expect(v1.hashCode, equals(v2.hashCode));
      });

      test('different zoom are not equal', () {
        final v1 = CanvasViewport(zoom: 1.0, pan: const Offset(10, 20));
        final v2 = CanvasViewport(zoom: 2.0, pan: const Offset(10, 20));

        expect(v1, isNot(equals(v2)));
      });

      test('different pan are not equal', () {
        final v1 = CanvasViewport(zoom: 1.0, pan: const Offset(10, 20));
        final v2 = CanvasViewport(zoom: 1.0, pan: const Offset(30, 40));

        expect(v1, isNot(equals(v2)));
      });
    });

    group('toString', () {
      test('formats correctly', () {
        final viewport = CanvasViewport(zoom: 1.5, pan: const Offset(10, 20));

        expect(
          viewport.toString(),
          equals('CanvasViewport(zoom: 1.50, pan: Offset(10.0, 20.0))'),
        );
      });
    });
  });
}
