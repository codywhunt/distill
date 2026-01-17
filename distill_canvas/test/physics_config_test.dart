import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasPhysicsConfig', () {
    group('clampZoom', () {
      test('returns value within bounds unchanged', () {
        const config = CanvasPhysicsConfig(minZoom: 0.5, maxZoom: 2.0);

        expect(config.clampZoom(1.0), equals(1.0));
        expect(config.clampZoom(0.5), equals(0.5));
        expect(config.clampZoom(2.0), equals(2.0));
      });

      test('clamps below min', () {
        const config = CanvasPhysicsConfig(minZoom: 0.5, maxZoom: 2.0);

        expect(config.clampZoom(0.1), equals(0.5));
        expect(config.clampZoom(0.0), equals(0.5));
      });

      test('clamps above max', () {
        const config = CanvasPhysicsConfig(minZoom: 0.5, maxZoom: 2.0);

        expect(config.clampZoom(3.0), equals(2.0));
        expect(config.clampZoom(10.0), equals(2.0));
      });
    });

    group('clampPan', () {
      test('returns input unchanged when panBounds is null', () {
        const config = CanvasPhysicsConfig();
        const pan = Offset(1000, 2000);
        const viewportSize = Size(800, 600);

        expect(config.clampPan(pan, 1.0, viewportSize), equals(pan));
      });

      test('constrains viewport to stay within bounds', () {
        const config = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
        );
        const viewportSize = Size(400, 300);
        const zoom = 1.0;

        // Pan that would show area outside bounds (viewport showing x: -200 to 200)
        // At pan=(0,0) with zoom=1, viewport shows world rect from (0,0) to (400,300)
        // Pan is in view-space: pan.dx = -visibleLeft * zoom
        // So pan=(-200, 0) means visibleLeft = 200, showing world x: 200 to 600

        // Try to pan left so viewport would start at x=-100 (outside bounds)
        // visibleLeft = -pan.dx / zoom = 100 / 1 = 100... wait let me recalculate
        // pan = Offset(-visibleLeft * zoom, -visibleTop * zoom)
        // So pan = (100, 0) means visibleLeft = -100, showing world x: -100 to 300
        // This should clamp to visibleLeft = 0, so pan = (0, 0)

        final result = config.clampPan(
          const Offset(100, 0),
          zoom,
          viewportSize,
        );
        // With bounds 0..1000 and viewport width 400, visibleLeft should clamp to 0..600
        // pan = (100, 0) -> visibleLeft = -100 -> clamps to 0 -> pan = (0, 0)
        expect(result.dx, equals(0.0));
      });

      test('constrains viewport right edge to bounds', () {
        const config = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
        );
        const viewportSize = Size(400, 300);
        const zoom = 1.0;

        // Try to pan right so viewport would extend past x=1000
        // pan = (-800, 0) means visibleLeft = 800, showing world x: 800 to 1200
        // Should clamp to visibleLeft = 600, so viewport shows 600 to 1000
        // Clamped pan = (-600, 0)

        final result = config.clampPan(
          const Offset(-800, 0),
          zoom,
          viewportSize,
        );
        expect(result.dx, equals(-600.0));
      });

      test('centers content when viewport wider than bounds', () {
        const config = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 200, 1000),
        );
        const viewportSize = Size(400, 300);
        const zoom = 1.0;

        // Viewport (400) is wider than bounds (200)
        // Should center: visibleLeft = bounds.center.dx - viewportWidth/2
        // = 100 - 200 = -100
        // pan.dx = -visibleLeft * zoom = 100

        final result = config.clampPan(const Offset(0, 0), zoom, viewportSize);
        expect(result.dx, equals(100.0));
      });

      test('centers content when viewport taller than bounds', () {
        const config = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 1000, 200),
        );
        const viewportSize = Size(400, 600);
        const zoom = 1.0;

        // Viewport (600) is taller than bounds (200)
        // Should center: visibleTop = bounds.center.dy - viewportHeight/2
        // = 100 - 300 = -200
        // pan.dy = -visibleTop * zoom = 200

        final result = config.clampPan(const Offset(0, 0), zoom, viewportSize);
        expect(result.dy, equals(200.0));
      });

      test('handles viewport larger than bounds in both dimensions', () {
        const config = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 200, 200),
        );
        const viewportSize = Size(400, 400);
        const zoom = 1.0;

        // Both dimensions should center
        // Center X: visibleLeft = 100 - 200 = -100 -> pan.dx = 100
        // Center Y: visibleTop = 100 - 200 = -100 -> pan.dy = 100

        final result = config.clampPan(const Offset(0, 0), zoom, viewportSize);
        expect(result.dx, equals(100.0));
        expect(result.dy, equals(100.0));
      });

      test('works with negative world coordinates', () {
        const config = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(-500, -500, 1000, 1000),
        );
        const viewportSize = Size(400, 300);
        const zoom = 1.0;

        // Bounds: -500 to 500 in both axes
        // Try to pan so viewport starts at x=-600 (outside)
        // pan = (600, 0) -> visibleLeft = -600 -> clamps to -500
        // pan.dx = 500

        final result = config.clampPan(
          const Offset(600, 0),
          zoom,
          viewportSize,
        );
        expect(result.dx, equals(500.0));
      });

      test('accounts for zoom level', () {
        const config = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
        );
        const viewportSize = Size(400, 300);
        const zoom = 2.0;

        // At zoom 2.0, viewport shows half the world space: 200x150 world units
        // visibleWidth = 400 / 2 = 200
        // So visibleLeft can range from 0 to 800 (1000 - 200)

        // pan = (-1800, 0) at zoom 2 -> visibleLeft = 1800/2 = 900 -> clamps to 800
        // clamped pan.dx = -800 * 2 = -1600

        final result = config.clampPan(
          const Offset(-1800, 0),
          zoom,
          viewportSize,
        );
        expect(result.dx, equals(-1600.0));
      });
    });

    group('presets', () {
      test('defaults has expected values', () {
        const config = CanvasPhysicsConfig.defaults;

        expect(config.minZoom, equals(0.1));
        expect(config.maxZoom, equals(10.0));
        expect(config.panBounds, isNull);
      });

      test('constrained has expected values', () {
        const config = CanvasPhysicsConfig.constrained;

        expect(config.minZoom, equals(0.5));
        expect(config.maxZoom, equals(2.0));
        expect(config.panBounds, isNull);
      });
    });

    group('equality', () {
      test('equal configs are equal', () {
        const config1 = CanvasPhysicsConfig(
          minZoom: 0.5,
          maxZoom: 2.0,
          panBounds: Rect.fromLTWH(0, 0, 100, 100),
        );
        const config2 = CanvasPhysicsConfig(
          minZoom: 0.5,
          maxZoom: 2.0,
          panBounds: Rect.fromLTWH(0, 0, 100, 100),
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different panBounds are not equal', () {
        const config1 = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 100, 100),
        );
        const config2 = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 200, 200),
        );

        expect(config1, isNot(equals(config2)));
      });

      test('null vs non-null panBounds are not equal', () {
        const config1 = CanvasPhysicsConfig();
        const config2 = CanvasPhysicsConfig(
          panBounds: Rect.fromLTWH(0, 0, 100, 100),
        );

        expect(config1, isNot(equals(config2)));
      });
    });
  });
}
