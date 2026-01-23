import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Common test setup
  const viewportSize = Size(800, 600);
  const defaultPhysics = CanvasPhysicsConfig();
  final constrainedPhysics = CanvasPhysicsConfig(
    minZoom: 0.5,
    maxZoom: 2.0,
  );

  group('InitialViewportState', () {
    test('holds pan and zoom values', () {
      const state = InitialViewportState(
        pan: Offset(100, 200),
        zoom: 1.5,
      );

      expect(state.pan, equals(const Offset(100, 200)));
      expect(state.zoom, equals(1.5));
    });

    test('toString includes pan and zoom', () {
      const state = InitialViewportState(
        pan: Offset(100, 200),
        zoom: 1.5,
      );

      final str = state.toString();
      expect(str, contains('pan'));
      expect(str, contains('zoom'));
      expect(str, contains('100'));
      expect(str, contains('200'));
      expect(str, contains('1.5'));
    });
  });

  group('InitialViewport.topLeft', () {
    test('places origin at top-left with default zoom', () {
      const viewport = InitialViewport.topLeft();
      final state = viewport.calculate(viewportSize, defaultPhysics);

      expect(state.pan, equals(Offset.zero));
      expect(state.zoom, equals(1.0));
    });

    test('respects custom initial zoom', () {
      const viewport = InitialViewport.topLeft(zoom: 2.0);
      final state = viewport.calculate(viewportSize, defaultPhysics);

      expect(state.pan, equals(Offset.zero));
      expect(state.zoom, equals(2.0));
    });

    test('clamps zoom to physics constraints', () {
      const viewport = InitialViewport.topLeft(zoom: 10.0);
      final state = viewport.calculate(viewportSize, constrainedPhysics);

      expect(state.pan, equals(Offset.zero));
      expect(state.zoom, equals(2.0)); // Clamped to maxZoom
    });

    test('clamps zoom below minZoom', () {
      const viewport = InitialViewport.topLeft(zoom: 0.1);
      final state = viewport.calculate(viewportSize, constrainedPhysics);

      expect(state.zoom, equals(0.5)); // Clamped to minZoom
    });
  });

  group('InitialViewport.centerOrigin', () {
    test('centers origin in viewport', () {
      const viewport = InitialViewport.centerOrigin();
      final state = viewport.calculate(viewportSize, defaultPhysics);

      expect(state.pan, equals(const Offset(400, 300))); // Half of 800x600
      expect(state.zoom, equals(1.0));
    });

    test('pan equals half of viewport size at zoom 1.0', () {
      const viewport = InitialViewport.centerOrigin();
      final state = viewport.calculate(const Size(1000, 800), defaultPhysics);

      expect(state.pan, equals(const Offset(500, 400)));
    });

    test('respects custom zoom', () {
      const viewport = InitialViewport.centerOrigin(zoom: 1.5);
      final state = viewport.calculate(viewportSize, defaultPhysics);

      expect(state.pan, equals(const Offset(400, 300)));
      expect(state.zoom, equals(1.5));
    });

    test('clamps zoom to physics constraints', () {
      const viewport = InitialViewport.centerOrigin(zoom: 5.0);
      final state = viewport.calculate(viewportSize, constrainedPhysics);

      expect(state.zoom, equals(2.0)); // Clamped to maxZoom
    });
  });

  group('InitialViewport.centerOn', () {
    test('centers specified world point in viewport', () {
      const viewport = InitialViewport.centerOn(Offset(100, 200));
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // At zoom 1.0, pan = viewportCenter - worldPoint
      // pan = (400, 300) - (100, 200) = (300, 100)
      expect(state.pan, equals(const Offset(300, 100)));
      expect(state.zoom, equals(1.0));
    });

    test('calculates correct pan for different world points', () {
      const viewport = InitialViewport.centerOn(Offset(0, 0));
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Centering on origin should give same result as centerOrigin
      expect(state.pan, equals(const Offset(400, 300)));
    });

    test('handles negative world coordinates', () {
      const viewport = InitialViewport.centerOn(Offset(-100, -50));
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // pan = viewportCenter - worldPoint * zoom
      // pan = (400, 300) - (-100, -50) = (500, 350)
      expect(state.pan, equals(const Offset(500, 350)));
    });

    test('respects zoom parameter', () {
      const viewport = InitialViewport.centerOn(Offset(100, 100), zoom: 2.0);
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // pan = viewportCenter - worldPoint * zoom
      // pan = (400, 300) - (100 * 2, 100 * 2) = (200, 100)
      expect(state.pan, equals(const Offset(200, 100)));
      expect(state.zoom, equals(2.0));
    });

    test('clamps zoom to physics constraints', () {
      const viewport = InitialViewport.centerOn(Offset(100, 100), zoom: 5.0);
      final state = viewport.calculate(viewportSize, constrainedPhysics);

      expect(state.zoom, equals(2.0)); // Clamped to maxZoom
    });
  });

  group('InitialViewport.fitRect', () {
    test('fits rect with default padding (50)', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 400, 300),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Available space: 800-100=700 width, 600-100=500 height
      // Scale: min(700/400, 500/300) = min(1.75, 1.67) = 1.67
      expect(state.zoom, closeTo(1.666, 0.01));
    });

    test('centers rect horizontally when narrower than viewport', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 200, 400),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Rect is narrower than viewport, should be centered horizontally
      expect(state.pan.dx, greaterThan(0));
    });

    test('centers rect vertically when shorter than viewport', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 600, 200),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Rect is shorter than viewport, should be centered vertically
      expect(state.pan.dy, greaterThan(0));
    });

    test('fits wide rect (constrained by width)', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 1400, 100),
        padding: EdgeInsets.zero,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // 800/1400 < 600/100, so width-constrained
      expect(state.zoom, closeTo(800 / 1400, 0.01));
    });

    test('fits tall rect (constrained by height)', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 100, 1200),
        padding: EdgeInsets.zero,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // 800/100 > 600/1200, so height-constrained
      expect(state.zoom, closeTo(600 / 1200, 0.01));
    });

    test('fits square rect correctly', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 500, 500),
        padding: EdgeInsets.zero,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // 800/500 > 600/500, so height-constrained
      expect(state.zoom, closeTo(600 / 500, 0.01));
    });

    test('falls back to centerOrigin for empty rect', () {
      final viewport = InitialViewport.fitRect(Rect.zero);
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Should use centerOrigin fallback
      expect(state.pan, equals(const Offset(400, 300)));
      expect(state.zoom, equals(1.0));
    });

    test('falls back to centerOrigin for non-finite rect', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(double.nan, 0, 100, 100),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Should use centerOrigin fallback
      expect(state.pan, equals(const Offset(400, 300)));
    });

    test('returns safe defaults when padding exceeds viewport', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        padding: const EdgeInsets.all(500), // Exceeds 800x600 viewport
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Available space is negative, should return safe defaults
      expect(state.pan, equals(Offset.zero));
      expect(state.zoom, equals(1.0));
    });

    test('respects minZoom constraint', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 10000, 10000),
        padding: EdgeInsets.zero,
        minZoom: 0.5,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Calculated zoom would be very small (0.06-0.08)
      // But minZoom constraint should apply
      expect(state.zoom, greaterThanOrEqualTo(0.5));
    });

    test('respects maxZoom constraint', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        padding: EdgeInsets.zero,
        maxZoom: 2.0,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Calculated zoom would be very large (60-80)
      // But maxZoom constraint should apply
      expect(state.zoom, lessThanOrEqualTo(2.0));
    });

    test('applies physics clampZoom after custom constraints', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        maxZoom: 10.0, // Our constraint allows up to 10
      );
      // But physics only allows up to 2.0
      final state = viewport.calculate(viewportSize, constrainedPhysics);

      expect(state.zoom, lessThanOrEqualTo(2.0));
    });

    test('respects asymmetric padding', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 400, 300),
        padding: const EdgeInsets.only(left: 100, right: 50, top: 20, bottom: 30),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Available: 800-150=650 width, 600-50=550 height
      // Should calculate zoom based on available space
      expect(state.zoom, greaterThan(0));
    });

    test('handles zero padding', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(0, 0, 800, 600),
        padding: EdgeInsets.zero,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Exact fit at zoom 1.0
      expect(state.zoom, equals(1.0));
    });

    test('handles rect not at origin', () {
      final viewport = InitialViewport.fitRect(
        const Rect.fromLTWH(500, 500, 400, 300),
        padding: EdgeInsets.zero,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Pan should account for rect position
      expect(state.pan.dx, lessThan(0)); // Need negative pan to show rect at 500
    });
  });

  group('InitialViewport.fitContent', () {
    test('calls getBounds callback during calculate', () {
      bool callbackCalled = false;
      final viewport = InitialViewport.fitContent(
        () {
          callbackCalled = true;
          return const Rect.fromLTWH(0, 0, 400, 300);
        },
      );

      viewport.calculate(viewportSize, defaultPhysics);
      expect(callbackCalled, isTrue);
    });

    test('uses fitRect when getBounds returns valid rect', () {
      final viewport = InitialViewport.fitContent(
        () => const Rect.fromLTWH(0, 0, 400, 300),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // Should have calculated a zoom to fit
      expect(state.zoom, greaterThan(1.0)); // Will zoom in to fit
    });

    test('uses fallback when getBounds returns null', () {
      final viewport = InitialViewport.fitContent(
        () => null,
        fallback: const InitialViewport.topLeft(),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // topLeft fallback: pan at zero
      expect(state.pan, equals(Offset.zero));
    });

    test('uses fallback when getBounds returns empty rect', () {
      final viewport = InitialViewport.fitContent(
        () => Rect.zero,
        fallback: const InitialViewport.topLeft(),
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // topLeft fallback
      expect(state.pan, equals(Offset.zero));
    });

    test('default fallback is centerOrigin', () {
      final viewport = InitialViewport.fitContent(
        () => null,
        // Not specifying fallback, should default to centerOrigin
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      // centerOrigin: pan at viewport center
      expect(state.pan, equals(const Offset(400, 300)));
    });

    test('passes padding to underlying fitRect', () {
      final viewport = InitialViewport.fitContent(
        () => const Rect.fromLTWH(0, 0, 400, 300),
        padding: EdgeInsets.zero,
      );
      final stateNoPadding = viewport.calculate(viewportSize, defaultPhysics);

      final viewportWithPadding = InitialViewport.fitContent(
        () => const Rect.fromLTWH(0, 0, 400, 300),
        padding: const EdgeInsets.all(100),
      );
      final stateWithPadding =
          viewportWithPadding.calculate(viewportSize, defaultPhysics);

      // Different padding should give different zoom
      expect(stateNoPadding.zoom, isNot(equals(stateWithPadding.zoom)));
    });

    test('passes minZoom to underlying fitRect', () {
      final viewport = InitialViewport.fitContent(
        () => const Rect.fromLTWH(0, 0, 10000, 10000),
        minZoom: 0.5,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      expect(state.zoom, greaterThanOrEqualTo(0.5));
    });

    test('passes maxZoom to underlying fitRect', () {
      final viewport = InitialViewport.fitContent(
        () => const Rect.fromLTWH(0, 0, 10, 10),
        maxZoom: 2.0,
      );
      final state = viewport.calculate(viewportSize, defaultPhysics);

      expect(state.zoom, lessThanOrEqualTo(2.0));
    });
  });
}
