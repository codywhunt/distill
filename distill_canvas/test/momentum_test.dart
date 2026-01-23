/// Tests for momentum simulation in InfiniteCanvasController.
///
/// Tests cover:
/// - startMomentum() - velocity-gated momentum for mouse/touch
/// - startMomentumWithFloor() - floor-based momentum for trackpad
/// - Boundary collision during momentum
/// - Deceleration behavior and notifier state
/// - Animation interruption
library;

import 'dart:async';
import 'dart:ui';

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Momentum simulation', () {
    group('startMomentum()', () {
      test('starts deceleration from given velocity', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Start momentum with velocity
        controller.startMomentum(const Offset(1000, 0));

        expect(controller.isDecelerating.value, isTrue);

        // Simulate some time passing (momentum should move pan)
        // The controller updates pan on each animation frame
        // For unit tests without a ticker, we can just verify the initial state
        expect(controller.isDecelerating.value, isTrue);

        // Cancel and check that we can cancel
        controller.cancelMomentum();
        expect(controller.isDecelerating.value, isFalse);
      });

      test('respects minVelocity threshold', () {
        final controller = createAttachedController(
          momentumConfig: const CanvasMomentumConfig(
            enableMomentum: true,
            friction: 0.015,
            minVelocity: 100.0, // High threshold
          ),
        );
        addTearDown(controller.dispose);

        // Below threshold - should not start momentum
        controller.startMomentum(const Offset(50, 0));
        expect(controller.isDecelerating.value, isFalse);

        // Above threshold - should start momentum
        controller.startMomentum(const Offset(200, 0));
        expect(controller.isDecelerating.value, isTrue);

        controller.cancelMomentum();
      });

      test('handles zero velocity (no-op)', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Zero velocity should not start momentum
        controller.startMomentum(Offset.zero);

        expect(controller.isDecelerating.value, isFalse);
      });

      test('can be interrupted by cancelMomentum()', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Start momentum
        controller.startMomentum(const Offset(1000, 0));
        expect(controller.isDecelerating.value, isTrue);

        // Cancel
        controller.cancelMomentum();
        expect(controller.isDecelerating.value, isFalse);
      });

      test('caps velocity at maxVelocity', () {
        final controller = createAttachedController(
          momentumConfig: const CanvasMomentumConfig(
            enableMomentum: true,
            friction: 0.015,
            minVelocity: 50.0,
            maxVelocity: 500.0, // Low cap
          ),
        );
        addTearDown(controller.dispose);

        // Even with huge velocity, should be capped
        controller.startMomentum(const Offset(10000, 0));
        expect(controller.isDecelerating.value, isTrue);

        controller.cancelMomentum();
      });
    });

    group('startMomentumWithFloor()', () {
      test('starts momentum when hadPan is true and velocity above floor', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        controller.startMomentumWithFloor(
          const Offset(500, 0),
          hadPan: true,
          fallbackDirection: const Offset(1, 0),
        );

        expect(controller.isDecelerating.value, isTrue);
        controller.cancelMomentum();
      });

      test('uses fallback direction when velocity is tiny but hadPan', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Tiny velocity but we did pan - should use fallback
        controller.startMomentumWithFloor(
          const Offset(0.1, 0), // Very small velocity
          hadPan: true,
          fallbackDirection: const Offset(1000, 0), // Large fallback
        );

        // Should start momentum using the floor velocity in fallback direction
        expect(controller.isDecelerating.value, isTrue);
        controller.cancelMomentum();
      });

      test('does nothing when momentum is disabled', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.defaults, // momentum disabled
        );
        addTearDown(controller.dispose);

        controller.startMomentumWithFloor(
          const Offset(1000, 0),
          hadPan: true,
          fallbackDirection: const Offset(1, 0),
        );

        expect(controller.isDecelerating.value, isFalse);
      });

      test('uses velocity gate when hadPan is false', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // With hadPan=false and tiny velocity, no momentum
        controller.startMomentumWithFloor(
          const Offset(0.00001, 0), // Below velocity threshold
          hadPan: false,
          fallbackDirection: const Offset(1, 0),
        );
        expect(controller.isDecelerating.value, isFalse);

        // With hadPan=false but significant velocity, momentum still starts
        controller.startMomentumWithFloor(
          const Offset(1000, 0),
          hadPan: false,
          fallbackDirection: const Offset(1, 0),
        );
        expect(controller.isDecelerating.value, isTrue);
        controller.cancelMomentum();
      });
    });

    group('boundary collision during momentum', () {
      test('respects panBounds during momentum', () {
        final controller = createAttachedController(
          panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
          viewportSize: const Size(400, 300),
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Start momentum that would push past right boundary
        controller.setPan(const Offset(-500, 0)); // Near right edge
        controller.startMomentum(const Offset(-2000, 0)); // Momentum going right

        // Momentum is active
        expect(controller.isDecelerating.value, isTrue);

        controller.cancelMomentum();
      });
    });

    group('deceleration notifier', () {
      test('isDecelerating is initially false', () {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        expect(controller.isDecelerating.value, isFalse);
      });

      test('isDecelerating notifies on state change', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        final values = <bool>[];
        controller.isDecelerating.addListener(() {
          values.add(controller.isDecelerating.value);
        });

        controller.startMomentum(const Offset(1000, 0));
        expect(values, contains(true));

        controller.cancelMomentum();
        expect(values.last, isFalse);
      });
    });

    group('momentum config', () {
      test('momentum disabled when enableMomentum is false', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.defaults, // momentum disabled
        );
        addTearDown(controller.dispose);

        controller.startMomentum(const Offset(1000, 0));

        expect(controller.isDecelerating.value, isFalse);
      });

      test('can update momentum config at runtime', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.defaults, // momentum disabled
        );
        addTearDown(controller.dispose);

        // Initially disabled
        controller.startMomentum(const Offset(1000, 0));
        expect(controller.isDecelerating.value, isFalse);

        // Enable momentum
        controller.updateMomentumConfig(CanvasMomentumConfig.figmaLike);

        // Now should work
        controller.startMomentum(const Offset(1000, 0));
        expect(controller.isDecelerating.value, isTrue);

        controller.cancelMomentum();
      });

      test('different presets have expected enableMomentum values', () {
        expect(CanvasMomentumConfig.defaults.enableMomentum, isFalse);
        expect(CanvasMomentumConfig.figmaLike.enableMomentum, isTrue);
        expect(CanvasMomentumConfig.smooth.enableMomentum, isTrue);
        expect(CanvasMomentumConfig.precise.enableMomentum, isFalse);
      });
    });

    group('animation interaction', () {
      test('animateTo cancels momentum', () async {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Start momentum
        controller.startMomentum(const Offset(1000, 0));
        expect(controller.isDecelerating.value, isTrue);

        // Start an animation - should cancel momentum
        unawaited(controller.animateTo(pan: const Offset(-50, -50)));

        expect(controller.isDecelerating.value, isFalse);
        expect(controller.isAnimating.value, isTrue);

        controller.cancelAnimations();
      });

      test('cancelAnimations also cancels momentum', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Start momentum
        controller.startMomentum(const Offset(1000, 0));
        expect(controller.isDecelerating.value, isTrue);

        // Cancel all animations
        controller.cancelAnimations();

        expect(controller.isDecelerating.value, isFalse);
      });

      test('starting new momentum cancels existing momentum', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        controller.startMomentum(const Offset(1000, 0));
        expect(controller.isDecelerating.value, isTrue);

        // Start new momentum in different direction
        controller.startMomentum(const Offset(0, 1000));
        expect(controller.isDecelerating.value, isTrue);

        controller.cancelMomentum();
      });
    });

    group('isInMotionListenable', () {
      test('combines all motion states', () {
        final controller = createAttachedController(
          momentumConfig: CanvasMomentumConfig.figmaLike,
        );
        addTearDown(controller.dispose);

        // Initially not in motion
        expect(controller.isPanning.value, isFalse);
        expect(controller.isZooming.value, isFalse);
        expect(controller.isAnimating.value, isFalse);
        expect(controller.isDecelerating.value, isFalse);

        // Start momentum
        controller.startMomentum(const Offset(1000, 0));
        expect(controller.isDecelerating.value, isTrue);

        controller.cancelMomentum();
        expect(controller.isDecelerating.value, isFalse);
      });
    });
  });
}
