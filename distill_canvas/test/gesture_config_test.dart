import 'dart:ui';

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasGestureConfig', () {
    group('getDragThreshold', () {
      test('returns dragThreshold for mouse', () {
        const config = CanvasGestureConfig(dragThreshold: 5.0);

        expect(config.getDragThreshold(PointerDeviceKind.mouse), equals(5.0));
      });

      test('returns dragThreshold for trackpad', () {
        const config = CanvasGestureConfig(dragThreshold: 5.0);

        expect(
          config.getDragThreshold(PointerDeviceKind.trackpad),
          equals(5.0),
        );
      });

      test('returns touchDragThreshold for touch', () {
        const config = CanvasGestureConfig(
          dragThreshold: 5.0,
          touchDragThreshold: 10.0,
        );

        expect(config.getDragThreshold(PointerDeviceKind.touch), equals(10.0));
      });

      test('returns touchDragThreshold for stylus', () {
        const config = CanvasGestureConfig(
          dragThreshold: 5.0,
          touchDragThreshold: 10.0,
        );

        expect(config.getDragThreshold(PointerDeviceKind.stylus), equals(10.0));
      });

      test('uses default multiplier when touchDragThreshold is null', () {
        const config = CanvasGestureConfig(dragThreshold: 10.0);

        // Default multiplier is 1.5
        expect(config.getDragThreshold(PointerDeviceKind.touch), equals(15.0));
        expect(config.getDragThreshold(PointerDeviceKind.stylus), equals(15.0));
      });

      test('respects explicit touchDragThreshold over multiplier', () {
        const config = CanvasGestureConfig(
          dragThreshold: 10.0,
          touchDragThreshold: 8.0, // Less than default would be (15.0)
        );

        expect(config.getDragThreshold(PointerDeviceKind.touch), equals(8.0));
      });

      test('returns dragThreshold for null kind', () {
        const config = CanvasGestureConfig(dragThreshold: 5.0);

        expect(config.getDragThreshold(null), equals(5.0));
      });

      test('returns dragThreshold for unknown device kind', () {
        const config = CanvasGestureConfig(dragThreshold: 5.0);

        expect(config.getDragThreshold(PointerDeviceKind.unknown), equals(5.0));
      });
    });

    group('defaultTouchThresholdMultiplier', () {
      test('constant is 1.5', () {
        expect(
          CanvasGestureConfig.defaultTouchThresholdMultiplier,
          equals(1.5),
        );
      });
    });

    group('presets', () {
      test('all preset has expected values', () {
        const config = CanvasGestureConfig.all;

        expect(config.enablePan, isTrue);
        expect(config.enableZoom, isTrue);
        expect(config.enableSpacebarPan, isTrue);
        expect(config.enableMiddleMousePan, isTrue);
        expect(config.enableScrollPan, isTrue);
        expect(config.dragThreshold, equals(5.0));
        expect(config.touchDragThreshold, isNull);
        expect(config.hoverThrottleMs, equals(16));
      });

      test('none preset disables everything', () {
        const config = CanvasGestureConfig.none;

        expect(config.enablePan, isFalse);
        expect(config.enableZoom, isFalse);
        expect(config.enableSpacebarPan, isFalse);
        expect(config.enableMiddleMousePan, isFalse);
        expect(config.enableScrollPan, isFalse);
      });

      test('zoomOnly preset disables pan but enables zoom', () {
        const config = CanvasGestureConfig.zoomOnly;

        expect(config.enablePan, isFalse);
        expect(config.enableZoom, isTrue);
        expect(config.enableSpacebarPan, isFalse);
        expect(config.enableMiddleMousePan, isFalse);
        expect(config.enableScrollPan, isFalse);
      });

      test('panOnly preset disables zoom but enables pan', () {
        const config = CanvasGestureConfig.panOnly;

        expect(config.enablePan, isTrue);
        expect(config.enableZoom, isFalse);
        expect(config.enableSpacebarPan, isTrue);
        expect(config.enableMiddleMousePan, isTrue);
        expect(config.enableScrollPan, isTrue);
      });
    });

    group('copyWith', () {
      test('preserves unmodified values', () {
        const original = CanvasGestureConfig(
          enablePan: true,
          enableZoom: false,
          dragThreshold: 8.0,
          touchDragThreshold: 12.0,
        );

        final copy = original.copyWith(hoverThrottleMs: 32);

        expect(copy.enablePan, isTrue);
        expect(copy.enableZoom, isFalse);
        expect(copy.dragThreshold, equals(8.0));
        expect(copy.touchDragThreshold, equals(12.0));
        expect(copy.hoverThrottleMs, equals(32));
      });

      test('updates touchDragThreshold', () {
        const original = CanvasGestureConfig(dragThreshold: 5.0);

        final copy = original.copyWith(touchDragThreshold: 15.0);

        expect(copy.dragThreshold, equals(5.0));
        expect(copy.touchDragThreshold, equals(15.0));
      });

      test('updates dragThreshold', () {
        const original = CanvasGestureConfig(
          dragThreshold: 5.0,
          touchDragThreshold: 10.0,
        );

        final copy = original.copyWith(dragThreshold: 8.0);

        expect(copy.dragThreshold, equals(8.0));
        expect(copy.touchDragThreshold, equals(10.0));
      });
    });

    group('equality', () {
      test('equal configs are equal', () {
        const config1 = CanvasGestureConfig(
          dragThreshold: 5.0,
          touchDragThreshold: 10.0,
        );
        const config2 = CanvasGestureConfig(
          dragThreshold: 5.0,
          touchDragThreshold: 10.0,
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different touchDragThreshold are not equal', () {
        const config1 = CanvasGestureConfig(touchDragThreshold: 10.0);
        const config2 = CanvasGestureConfig(touchDragThreshold: 15.0);

        expect(config1, isNot(equals(config2)));
      });

      test('null vs non-null touchDragThreshold are not equal', () {
        const config1 = CanvasGestureConfig();
        const config2 = CanvasGestureConfig(touchDragThreshold: 10.0);

        expect(config1, isNot(equals(config2)));
      });

      test('different dragThreshold are not equal', () {
        const config1 = CanvasGestureConfig(dragThreshold: 5.0);
        const config2 = CanvasGestureConfig(dragThreshold: 8.0);

        expect(config1, isNot(equals(config2)));
      });
    });
  });
}
