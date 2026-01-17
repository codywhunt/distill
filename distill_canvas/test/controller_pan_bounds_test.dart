import 'dart:async';

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InfiniteCanvasController pan bounds', () {
    // Helper to create an attached controller with bounds
    InfiniteCanvasController createBoundedController({
      required Rect panBounds,
      Size viewportSize = const Size(800, 600),
      double initialZoom = 1.0,
      Offset initialPan = Offset.zero,
    }) {
      final controller = InfiniteCanvasController(
        initialZoom: initialZoom,
        initialPan: initialPan,
      );
      // Use attach() to set viewport size and physics
      // Note: vsync is only needed for animations
      controller.attach(
        vsync: const _TestVsync(),
        physics: CanvasPhysicsConfig(panBounds: panBounds),
        viewportSize: viewportSize,
      );
      return controller;
    }

    group('panBy', () {
      test('respects bounds', () {
        // Bounds: 0,0 to 1000,1000
        // Viewport: 800x600 at zoom 1 = 800x600 world units
        // Valid visibleLeft range: 0 to 200 (1000-800)
        // Valid pan.dx range: 0 to -200
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        );
        addTearDown(controller.dispose);

        // Start at (0,0) which shows world 0..800 x 0..600
        expect(controller.pan, equals(Offset.zero));

        // Try to pan right (negative view delta moves content left)
        // Should not go past the boundary
        controller.panBy(const Offset(-500, 0));

        // Pan should be clamped to -200 (showing world 200..1000)
        expect(controller.pan.dx, equals(-200.0));
      });

      test('stops at boundary', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        );
        addTearDown(controller.dispose);

        // Try to pan left (positive view delta) past the start
        controller.panBy(const Offset(100, 0));

        // Should stay at 0 since we're already at left boundary
        expect(controller.pan.dx, equals(0.0));
      });

      test('allows movement within bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        );
        addTearDown(controller.dispose);

        // Pan right by 100 (within the valid range of 0 to -200)
        controller.panBy(const Offset(-100, 0));

        expect(controller.pan.dx, equals(-100.0));
      });
    });

    group('setPan', () {
      test('clamps pan outside bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        );
        addTearDown(controller.dispose);

        // Try to set pan way outside bounds
        controller.setPan(const Offset(-1000, -1000));

        // Should clamp to valid range: dx in [0, -200], dy in [0, -400]
        expect(controller.pan.dx, equals(-200.0));
        expect(controller.pan.dy, equals(-400.0));
      });

      test('allows pan within bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        );
        addTearDown(controller.dispose);

        controller.setPan(const Offset(-100, -100));

        expect(controller.pan, equals(const Offset(-100, -100)));
      });
    });

    group('setZoom with focal point', () {
      test('respects bounds after focal point adjustment', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Set initial pan within bounds
        controller.setPan(const Offset(-100, -50));

        // Zoom in with focal point at center
        controller.setZoom(2.0, focalPointInView: const Offset(200, 150));

        // At zoom 2.0, viewport shows 200x150 world units
        // Valid pan.dx range: 0 to -1600 (since visible width = 200, max left = 800)
        // The focal point adjustment may push pan out of bounds, should be clamped
        expect(controller.pan.dx, greaterThanOrEqualTo(-1600.0));
        expect(controller.pan.dx, lessThanOrEqualTo(0.0));
      });
    });

    group('centerOn', () {
      test('clamps when center would exceed bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Try to center on a point that would put viewport outside bounds
        controller.centerOn(const Offset(0, 0));

        // At zoom 1.0, centering on (0,0) would need pan = (200, 150)
        // But that would show world rect from (-200, -150) to (200, 150)
        // Which is outside bounds. Should clamp to show (0,0) to (400, 300)
        // So pan should be (0, 0)
        expect(controller.pan.dx, equals(0.0));
        expect(controller.pan.dy, equals(0.0));
      });

      test('works normally within bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Center on (500, 500) - well within bounds
        controller.centerOn(const Offset(500, 500));

        // At zoom 1.0, centering on (500, 500) needs pan that places
        // center of viewport (200, 150) at world (500, 500)
        // pan = viewportCenter - worldPoint * zoom = (200, 150) - (500, 500) = (-300, -350)
        expect(controller.pan.dx, equals(-300.0));
        expect(controller.pan.dy, equals(-350.0));
      });
    });

    group('fitToRect', () {
      test('clamps result within bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Fit to a rect at the edge of bounds
        controller.fitToRect(
          const Rect.fromLTWH(0, 0, 200, 150),
          padding: EdgeInsets.zero,
        );

        // Should position viewport to show the rect, clamped to bounds
        // The zoom might change, but pan should be within bounds
        final visibleWorld = controller.getVisibleWorldBounds(
          const Size(400, 300),
        );
        expect(visibleWorld.left, greaterThanOrEqualTo(0.0));
        expect(visibleWorld.top, greaterThanOrEqualTo(0.0));
      });
    });

    group('updatePhysics', () {
      test('re-clamps pan when bounds change', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        );
        addTearDown(controller.dispose);

        // Set pan within original bounds
        controller.setPan(const Offset(-100, -100));
        expect(controller.pan, equals(const Offset(-100, -100)));

        // Change to smaller bounds
        controller.updatePhysics(
          const CanvasPhysicsConfig(panBounds: Rect.fromLTWH(0, 0, 850, 650)),
        );

        // With viewport 800x600, new valid pan range:
        // dx: 0 to -50, dy: 0 to -50
        // Previous pan (-100, -100) should clamp to (-50, -50)
        expect(controller.pan.dx, equals(-50.0));
        expect(controller.pan.dy, equals(-50.0));
      });

      test('re-clamps pan when bounds removed', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
        );
        addTearDown(controller.dispose);

        controller.setPan(const Offset(-100, -100));

        // Remove bounds
        controller.updatePhysics(const CanvasPhysicsConfig());

        // Pan should remain unchanged since no bounds
        expect(controller.pan, equals(const Offset(-100, -100)));
      });
    });

    group('updateViewportSize', () {
      test('re-clamps pan when viewport size changes', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Set pan at edge of valid range for 400x300 viewport
        // Valid dx range: 0 to -600 (1000-400)
        controller.setPan(const Offset(-500, -500));
        expect(controller.pan, equals(const Offset(-500, -500)));

        // Increase viewport size
        controller.updateViewportSize(const Size(800, 800));

        // With larger viewport (800x800), valid range shrinks:
        // dx: 0 to -200, dy: 0 to -200
        // Previous pan (-500, -500) should clamp to (-200, -200)
        expect(controller.pan.dx, equals(-200.0));
        expect(controller.pan.dy, equals(-200.0));
      });
    });

    group('attach', () {
      test('clamps initial state outside bounds', () {
        final controller = InfiniteCanvasController(
          initialPan: const Offset(-1000, -1000),
          initialZoom: 1.0,
        );
        addTearDown(controller.dispose);

        // Before attach, pan is unclamped
        expect(controller.pan, equals(const Offset(-1000, -1000)));

        // Attach with bounds
        controller.attach(
          vsync: const _TestVsync(),
          physics: const CanvasPhysicsConfig(
            panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
          ),
          viewportSize: const Size(800, 600),
        );

        // After attach, pan should be clamped
        // Valid range: dx 0 to -200, dy 0 to -400
        expect(controller.pan.dx, equals(-200.0));
        expect(controller.pan.dy, equals(-400.0));
      });

      test('clamps explicit initial state outside bounds', () {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        controller.attach(
          vsync: const _TestVsync(),
          physics: const CanvasPhysicsConfig(
            panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
          ),
          viewportSize: const Size(800, 600),
          initialState: const InitialViewportState(
            pan: Offset(-1000, -1000),
            zoom: 1.0,
          ),
        );

        // Initial state should be clamped
        expect(controller.pan.dx, equals(-200.0));
        expect(controller.pan.dy, equals(-400.0));
      });
    });

    group('ensureVisible', () {
      test('pans as close as possible when target outside bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Try to ensure visible a rect outside bounds
        controller.ensureVisible(
          const Rect.fromLTWH(-100, -100, 50, 50),
          margin: EdgeInsets.zero,
        );

        // Pan should be clamped at boundary, showing as much as possible
        expect(controller.pan.dx, greaterThanOrEqualTo(0.0));
      });

      test('works for target inside bounds', () {
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Ensure visible a rect that's off screen but within bounds
        controller.ensureVisible(
          const Rect.fromLTWH(800, 800, 100, 100),
          margin: EdgeInsets.zero,
        );

        // Should pan to show the rect
        final visibleWorld = controller.getVisibleWorldBounds(
          const Size(400, 300),
        );
        expect(
          visibleWorld.overlaps(const Rect.fromLTWH(800, 800, 100, 100)),
          isTrue,
        );
      });
    });

    group('viewport centering for oversized viewports', () {
      test('centers when viewport wider than bounds', () {
        // Bounds 200 wide, viewport 400 wide
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 200, 1000),
          viewportSize: const Size(400, 300),
        );
        addTearDown(controller.dispose);

        // Content should be centered horizontally
        // bounds.center.dx = 100, viewport center offset = 200
        // visibleLeft = 100 - 200 = -100
        // pan.dx = 100
        expect(controller.pan.dx, equals(100.0));
      });

      test('centers when viewport taller than bounds', () {
        // Bounds 200 tall, viewport 400 tall
        final controller = createBoundedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 200),
          viewportSize: const Size(300, 400),
        );
        addTearDown(controller.dispose);

        // Content should be centered vertically
        expect(controller.pan.dy, equals(100.0));
      });
    });
  });

  group('InfiniteCanvasController bounded pan animations', () {
    testWidgets('animateTo clamps target before animating', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvas(
              controller: controller,
              physicsConfig: const CanvasPhysicsConfig(
                panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
              ),
              layers: CanvasLayers(
                content: (context, transform) => const SizedBox(),
              ),
            ),
          ),
        ),
      );

      // Widget is now built and controller is attached
      await tester.pumpAndSettle();

      // Animate to a pan value outside bounds
      unawaited(controller.animateTo(pan: const Offset(-5000, -5000)));
      await tester.pumpAndSettle();

      // Should end at boundary, not the requested value
      // Exact values depend on viewport size, but should be clamped
      expect(controller.pan.dx, greaterThan(-5000.0));
      expect(controller.pan.dy, greaterThan(-5000.0));
    });

    testWidgets('animateToCenterOn clamps target', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: InfiniteCanvas(
                controller: controller,
                physicsConfig: const CanvasPhysicsConfig(
                  panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
                ),
                layers: CanvasLayers(
                  content: (context, transform) => const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Try to center on a point that would put viewport outside bounds
      await controller.animateToCenterOn(const Offset(-500, -500));
      await tester.pumpAndSettle();

      // Pan should be clamped to keep viewport within bounds
      expect(controller.pan.dx, greaterThanOrEqualTo(0.0));
      expect(controller.pan.dy, greaterThanOrEqualTo(0.0));
    });
  });
}

/// Minimal TickerProvider for tests that don't need animations.
class _TestVsync implements TickerProvider {
  const _TestVsync();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
