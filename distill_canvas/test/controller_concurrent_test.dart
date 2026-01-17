import 'dart:async';

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InfiniteCanvasController concurrent operations', () {
    testWidgets('cancelAnimations stops active animation', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start animation
      unawaited(
        controller.animateTo(
          pan: const Offset(-1000, -1000),
          duration: const Duration(seconds: 2),
        ),
      );

      // Pump one frame to start animation
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isAnimating.value, isTrue);

      // Cancel animation
      controller.cancelAnimations();
      await tester.pump();

      expect(controller.isAnimating.value, isFalse);
    });

    testWidgets('rapid successive zoom calls accumulate correctly', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.zoom, equals(1.0));

      // Rapid succession of zoom changes
      controller.zoomBy(1.1);
      controller.zoomBy(1.1);
      controller.zoomBy(1.1);

      // Should accumulate: 1.0 * 1.1 * 1.1 * 1.1 = 1.331
      expect(controller.zoom, closeTo(1.331, 0.001));
    });

    test('rapid pan operations are additive', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(controller.pan, equals(Offset.zero));

      controller.panBy(const Offset(10, 0));
      controller.panBy(const Offset(10, 0));
      controller.panBy(const Offset(10, 0));

      expect(controller.pan, equals(const Offset(30, 0)));
    });

    testWidgets('starting new animation cancels previous', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();
      var secondAnimationCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start first animation
      unawaited(
        controller.animateTo(
          pan: const Offset(-1000, 0),
          duration: const Duration(seconds: 2),
        ),
      );

      // Pump one frame to start animation
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isAnimating.value, isTrue);

      // Start second animation (should cancel first via _runAnimation's cancelAnimations())
      unawaited(
        controller
            .animateTo(
              pan: const Offset(0, -500),
              duration: const Duration(milliseconds: 200),
            )
            .then((_) => secondAnimationCompleted = true),
      );

      await tester.pumpAndSettle();

      // Second animation should complete
      expect(secondAnimationCompleted, isTrue);

      // Pan should be at second animation's target
      expect(controller.pan.dy, equals(-500.0));
    });

    testWidgets('animation completes and fires future', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();
      var animationCompleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(
        controller
            .animateTo(
              pan: const Offset(-100, -100),
              duration: const Duration(milliseconds: 200),
            )
            .then((_) {
              animationCompleted = true;
            }),
      );

      expect(animationCompleted, isFalse);

      await tester.pumpAndSettle();

      expect(animationCompleted, isTrue);
      expect(controller.pan, equals(const Offset(-100, -100)));
    });

    testWidgets('isAnimating reflects animation state', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isAnimating.value, isFalse);

      unawaited(
        controller.animateTo(
          pan: const Offset(-100, -100),
          duration: const Duration(milliseconds: 200),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isAnimating.value, isTrue);

      await tester.pumpAndSettle();
      expect(controller.isAnimating.value, isFalse);
    });

    testWidgets('animateToFit can be interrupted by animateTo', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InfiniteCanvas(
                controller: controller,
                layers: CanvasLayers(
                  content: (context, ctrl) => const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start animateToFit
      unawaited(
        controller.animateToFit(
          const Rect.fromLTWH(0, 0, 500, 500),
          padding: const EdgeInsets.all(50),
          duration: const Duration(seconds: 2),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isAnimating.value, isTrue);

      // Start another animation
      unawaited(
        controller.animateTo(
          pan: const Offset(0, 0),
          zoom: 1.0,
          duration: const Duration(milliseconds: 200),
        ),
      );

      await tester.pumpAndSettle();

      // Should end at the second animation's target
      expect(controller.pan, equals(Offset.zero));
      expect(controller.zoom, equals(1.0));
    });

    testWidgets('centerOn works correctly', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InfiniteCanvas(
                controller: controller,
                layers: CanvasLayers(
                  content: (context, ctrl) => const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Use instant centerOn instead of animated version
      controller.centerOn(const Offset(500, 500));

      // Verify the world point is centered
      // At zoom 1, center of viewport (400, 300) should map to world (500, 500)
      // pan = viewportCenter - worldPoint * zoom = (400, 300) - (500, 500) = (-100, -200)
      expect(controller.pan.dx, closeTo(-100, 1));
      expect(controller.pan.dy, closeTo(-200, 1));
    });

    test('rapid setZoom operations work correctly', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(controller.zoom, equals(1.0));

      controller.setZoom(1.5);
      controller.setZoom(2.0);
      controller.setZoom(1.2);

      // Should be at final value
      expect(controller.zoom, equals(1.2));
    });

    test('rapid setPan operations work correctly', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(controller.pan, equals(Offset.zero));

      controller.setPan(const Offset(100, 100));
      controller.setPan(const Offset(200, 200));
      controller.setPan(const Offset(150, 150));

      // Should be at final value
      expect(controller.pan, equals(const Offset(150, 150)));
    });
  });
}
