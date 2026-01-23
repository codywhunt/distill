/// Performance baseline tests for distill_canvas.
///
/// These tests establish baseline metrics for rebuild counts, notification
/// frequency, and repaint frequency during gestures. The baselines are used
/// to validate that refactoring doesn't regress performance.
///
/// Run with: flutter test test/benchmark/performance_baseline_test.dart
library;

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('Performance baseline', () {
    group('Rebuild frequency', () {
      testWidgets('content layer rebuild count during 1-second scroll pan', (
        WidgetTester tester,
      ) async {
        int rebuildCount = 0;
        final controller = InfiniteCanvasController();

        await tester.pumpWidget(
          buildCanvasTestHarness(
            controller: controller,
            content: (context, ctrl) {
              rebuildCount++;
              return const SizedBox();
            },
          ),
        );
        await tester.pumpAndSettle();

        final initialRebuilds = rebuildCount;

        // Simulate 1-second scroll pan at 60fps = 60 frames
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));

        for (int i = 0; i < 60; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, 5)));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();

        final scrollRebuilds = rebuildCount - initialRebuilds;

        // BASELINE: Expect ~60 rebuilds (one per scroll event)
        // This is expected behavior - content layer rebuilds on every viewport change
        // ignore: avoid_print
        print('BASELINE: 1-second scroll pan rebuilds = $scrollRebuilds');
        expect(
          scrollRebuilds,
          greaterThan(50),
          reason: 'Content layer should rebuild on scroll pan',
        );
      });

      testWidgets('content layer rebuild count during 1-second zoom gesture', (
        WidgetTester tester,
      ) async {
        int rebuildCount = 0;
        final controller = InfiniteCanvasController();

        await tester.pumpWidget(
          buildCanvasTestHarness(
            controller: controller,
            content: (context, ctrl) {
              rebuildCount++;
              return const SizedBox();
            },
          ),
        );
        await tester.pumpAndSettle();

        final initialRebuilds = rebuildCount;

        // Simulate 1-second zoom gesture at 60fps
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));

        // Hold meta key for zoom
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);

        for (int i = 0; i < 60; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, -2)));
          await tester.pump(const Duration(milliseconds: 16));
        }

        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pumpAndSettle();

        final zoomRebuilds = rebuildCount - initialRebuilds;

        // BASELINE: Expect ~60 rebuilds during zoom
        // ignore: avoid_print
        print('BASELINE: 1-second zoom gesture rebuilds = $zoomRebuilds');
        expect(
          zoomRebuilds,
          greaterThan(50),
          reason: 'Content layer should rebuild on zoom',
        );
      });
    });

    group('Notification frequency', () {
      testWidgets('notification count during 1-second scroll', (
        WidgetTester tester,
      ) async {
        int notificationCount = 0;
        final controller = InfiniteCanvasController();

        controller.addListener(() {
          notificationCount++;
        });

        await tester.pumpWidget(
          buildCanvasTestHarness(controller: controller),
        );
        await tester.pumpAndSettle();

        final initialNotifications = notificationCount;

        // Simulate scroll events
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));

        for (int i = 0; i < 60; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, 5)));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();

        final scrollNotifications = notificationCount - initialNotifications;

        // BASELINE: Expect ~60 notifications (one per scroll event)
        // ignore: avoid_print
        print('BASELINE: 1-second scroll notifications = $scrollNotifications');
        expect(
          scrollNotifications,
          greaterThan(50),
          reason: 'Controller should notify on scroll',
        );
      });
    });

    group('Repaint frequency', () {
      testWidgets('repaint frequency during zoom gesture', (
        WidgetTester tester,
      ) async {
        int repaintCount = 0;
        final controller = InfiniteCanvasController();

        await tester.pumpWidget(
          buildCanvasTestHarness(
            controller: controller,
            content: (context, ctrl) {
              return CustomPaint(
                painter: CountingPainter(
                  onPaint: () => repaintCount++,
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        final initialRepaints = repaintCount;

        // Simulate zoom gesture
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(pointer.hover(const Offset(400, 300)));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);

        for (int i = 0; i < 60; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, -2)));
          await tester.pump(const Duration(milliseconds: 16));
        }

        await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
        await tester.pumpAndSettle();

        final zoomRepaints = repaintCount - initialRepaints;

        // BASELINE: Repaints should roughly match rebuilds
        // ignore: avoid_print
        print('BASELINE: 1-second zoom repaints = $zoomRepaints');
        expect(
          zoomRepaints,
          greaterThan(50),
          reason: 'CustomPainter should repaint during zoom',
        );
      });
    });

    group('Controller pan/zoom API performance', () {
      test('panBy triggers single notification', () {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        int notificationCount = 0;
        controller.addListener(() => notificationCount++);

        controller.panBy(const Offset(100, 50));

        expect(notificationCount, equals(1));
      });

      test('setZoom triggers single notification', () {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        int notificationCount = 0;
        controller.addListener(() => notificationCount++);

        controller.setZoom(2.0);

        expect(notificationCount, equals(1));
      });

      test('multiple panBy calls trigger multiple notifications', () {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        int notificationCount = 0;
        controller.addListener(() => notificationCount++);

        for (int i = 0; i < 100; i++) {
          controller.panBy(const Offset(1, 0));
        }

        expect(notificationCount, equals(100));
      });
    });
  });
}
