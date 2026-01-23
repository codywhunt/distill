/// Tests for gesture handling in InfiniteCanvas.
///
/// Tests cover:
/// - shouldHandleScroll callback
/// - Zoom via scroll wheel (with Cmd/Ctrl modifier)
/// - Controller motion state notifiers
/// - Gesture config options
///
/// Note: Drag/tap gesture tests are challenging in widget tests due to gesture
/// arena competition. The controller API is tested separately in integration_test.dart.
library;

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('shouldHandleScroll callback', () {
    testWidgets('callback receives view coordinates', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();
      Offset? receivedPosition;

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          shouldHandleScroll: (viewPos) {
            receivedPosition = viewPos;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pump();

      expect(receivedPosition, isNotNull);
      expect(receivedPosition!.dx, closeTo(400, 1));
      expect(receivedPosition!.dy, closeTo(300, 1));
    });

    testWidgets('returns true -> canvas handles scroll (pan occurs)', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          shouldHandleScroll: (_) => true,
        ),
      );
      await tester.pumpAndSettle();

      final initialPan = controller.pan;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();

      // Pan should change (scroll panning is enabled by default)
      expect(controller.pan, isNot(equals(initialPan)));
    });

    testWidgets('returns false -> event propagates (no pan change)', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          shouldHandleScroll: (_) => false,
        ),
      );
      await tester.pumpAndSettle();

      final initialPan = controller.pan;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();

      // Pan should NOT change
      expect(controller.pan, equals(initialPan));
    });

    testWidgets('null callback -> always handles scroll', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          // No shouldHandleScroll callback
        ),
      );
      await tester.pumpAndSettle();

      final initialPan = controller.pan;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();

      // Pan should change
      expect(controller.pan, isNot(equals(initialPan)));
    });

    testWidgets('position-based conditional handling', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          // Handle scroll only in left half
          shouldHandleScroll: (viewPos) => viewPos.dx < 400,
        ),
      );
      await tester.pumpAndSettle();

      final initialPan = controller.pan;

      // Scroll in right half (should NOT handle, no pan change)
      var pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(600, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();

      expect(controller.pan, equals(initialPan));

      // Scroll in left half (should handle, pan changes)
      pointer = TestPointer(2, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(200, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();

      expect(controller.pan, isNot(equals(initialPan)));
    });

    testWidgets('affects Cmd+scroll zoom as well', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          shouldHandleScroll: (_) => false, // Never handle
        ),
      );
      await tester.pumpAndSettle();

      final initialZoom = controller.zoom;

      // Try Cmd+scroll to zoom
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      // Zoom should NOT change because shouldHandleScroll returned false
      expect(controller.zoom, equals(initialZoom));
    });
  });

  group('Zoom gestures', () {
    testWidgets('Cmd+scroll zooms viewport', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(controller: controller),
      );
      await tester.pumpAndSettle();

      expect(controller.zoom, equals(1.0));

      // Create pointer and scroll
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));

      // Cmd+scroll to zoom (negative Y = zoom in)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      // Zoom should have increased
      expect(controller.zoom, greaterThan(1.0));
    });

    testWidgets('zoom respects min/max constraints', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          physicsConfig: const CanvasPhysicsConfig(
            minZoom: 0.5,
            maxZoom: 2.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zoom in past max
      controller.setZoom(5.0);
      expect(controller.zoom, equals(2.0));

      // Zoom out past min
      controller.setZoom(0.1);
      expect(controller.zoom, equals(0.5));
    });

    testWidgets('isZooming notifier updates during scroll zoom', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(controller: controller),
      );
      await tester.pumpAndSettle();

      expect(controller.isZooming.value, isFalse);

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pump();

      expect(controller.isZooming.value, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      // Wait for debounce timer
      await tester.pump(const Duration(milliseconds: 150));

      expect(controller.isZooming.value, isFalse);
    });
  });

  group('Controller motion states', () {
    test('initial motion states are false', () {
      final controller = createAttachedController();
      addTearDown(controller.dispose);

      expect(controller.isPanning.value, isFalse);
      expect(controller.isZooming.value, isFalse);
      expect(controller.isAnimating.value, isFalse);
      expect(controller.isDecelerating.value, isFalse);
    });

    test('setIsPanning updates notifier', () {
      final controller = createAttachedController();
      addTearDown(controller.dispose);

      final values = <bool>[];
      controller.isPanning.addListener(() {
        values.add(controller.isPanning.value);
      });

      controller.setIsPanning(true);
      expect(values, [true]);

      controller.setIsPanning(false);
      expect(values, [true, false]);
    });

    test('setIsZooming updates notifier', () {
      final controller = createAttachedController();
      addTearDown(controller.dispose);

      final values = <bool>[];
      controller.isZooming.addListener(() {
        values.add(controller.isZooming.value);
      });

      controller.setIsZooming(true);
      expect(values, [true]);

      controller.setIsZooming(false);
      expect(values, [true, false]);
    });

    test('isInMotionValue updates when any motion state changes', () {
      final controller = createAttachedController();
      addTearDown(controller.dispose);

      final values = <bool>[];
      controller.isInMotionValue.addListener(() {
        values.add(controller.isInMotionValue.value);
      });

      // Initially false
      expect(controller.isInMotionValue.value, isFalse);

      // Panning sets it true
      controller.setIsPanning(true);
      expect(values, [true]);
      expect(controller.isInMotion, isTrue);

      // Still true with zooming added
      controller.setIsZooming(true);
      expect(values, [true]); // No change notification (already true)

      // Still true after panning stops (zooming still active)
      controller.setIsPanning(false);
      expect(values, [true]); // Still no change

      // False after all motion stops
      controller.setIsZooming(false);
      expect(values, [true, false]);
      expect(controller.isInMotion, isFalse);
    });

    test('isInMotion getter returns correct value', () {
      final controller = createAttachedController();
      addTearDown(controller.dispose);

      expect(controller.isInMotion, isFalse);

      controller.setIsPanning(true);
      expect(controller.isInMotion, isTrue);

      controller.setIsPanning(false);
      expect(controller.isInMotion, isFalse);
    });
  });

  group('Gesture config options', () {
    testWidgets('enableZoom: false disables scroll zoom', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          gestureConfig: const CanvasGestureConfig(enableZoom: false),
        ),
      );
      await tester.pumpAndSettle();

      final initialZoom = controller.zoom;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      // Zoom should not have changed
      expect(controller.zoom, equals(initialZoom));
    });

    testWidgets('enableScrollPan: false disables scroll panning', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        buildCanvasTestHarness(
          controller: controller,
          gestureConfig: const CanvasGestureConfig(enableScrollPan: false),
        ),
      );
      await tester.pumpAndSettle();

      final initialPan = controller.pan;

      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 100)));
      await tester.pumpAndSettle();

      // Pan should not have changed from scroll
      expect(controller.pan, equals(initialPan));
    });
  });

  group('Hot reload behavior', () {
    testWidgets('controller survives widget rebuild', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      Widget buildCanvas({Color? backgroundColor}) {
        return buildCanvasTestHarness(
          controller: controller,
          backgroundColor: backgroundColor,
        );
      }

      await tester.pumpWidget(buildCanvas(backgroundColor: Colors.white));
      await tester.pumpAndSettle();

      controller.setPan(const Offset(-100, -50));
      controller.setZoom(1.5);

      // Rebuild with different props (simulates hot reload)
      await tester.pumpWidget(buildCanvas(backgroundColor: Colors.grey));
      await tester.pumpAndSettle();

      // Controller state should be preserved
      expect(controller.pan, equals(const Offset(-100, -50)));
      expect(controller.zoom, equals(1.5));
    });
  });
}
