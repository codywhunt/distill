/// Shared test utilities for distill_canvas tests.
///
/// This file is not a test itself - it provides utilities for other tests.
/// Import it in your test files with:
/// ```dart
/// import 'test_helpers.dart';
/// ```
library;

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// Empty main to satisfy test runner when this file is run directly
void main() {}

/// Minimal TickerProvider for tests that don't need animations.
///
/// Use this when testing controller methods that don't involve animations,
/// or when you need to manually control animation timing.
class TestVsync implements TickerProvider {
  const TestVsync();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Creates an attached controller with optional bounds for unit tests.
///
/// This is the standard pattern for testing controller methods that require
/// attachment (viewport size, physics config, etc.) without needing a full
/// widget tree.
///
/// Example:
/// ```dart
/// test('pan respects bounds', () {
///   final controller = createAttachedController(
///     panBounds: const Rect.fromLTWH(0, 0, 1000, 1000),
///   );
///   addTearDown(controller.dispose);
///
///   controller.panBy(const Offset(-500, 0));
///   expect(controller.pan.dx, equals(-200.0));
/// });
/// ```
InfiniteCanvasController createAttachedController({
  Rect? panBounds,
  Size viewportSize = const Size(800, 600),
  double initialZoom = 1.0,
  Offset initialPan = Offset.zero,
  double? minZoom,
  double? maxZoom,
  CanvasMomentumConfig momentumConfig = CanvasMomentumConfig.defaults,
}) {
  final controller = InfiniteCanvasController(
    initialZoom: initialZoom,
    initialPan: initialPan,
  );
  controller.attach(
    vsync: const TestVsync(),
    physics: CanvasPhysicsConfig(
      panBounds: panBounds,
      minZoom: minZoom ?? 0.1,
      maxZoom: maxZoom ?? 10.0,
    ),
    viewportSize: viewportSize,
  );
  controller.updateMomentumConfig(momentumConfig);
  return controller;
}

/// Builds a standard test harness for InfiniteCanvas widget tests.
///
/// Wraps the canvas in MaterialApp and constrains to specified size.
///
/// Example:
/// ```dart
/// testWidgets('tap fires callback', (tester) async {
///   final controller = InfiniteCanvasController();
///   Offset? tappedPos;
///
///   await tester.pumpWidget(
///     buildCanvasTestHarness(
///       controller: controller,
///       onTapWorld: (pos) => tappedPos = pos,
///     ),
///   );
///   await tester.pumpAndSettle();
///
///   await tester.tapAt(const Offset(400, 300));
///   expect(tappedPos, isNotNull);
/// });
/// ```
Widget buildCanvasTestHarness({
  required InfiniteCanvasController controller,
  Size size = const Size(800, 600),
  CanvasGestureConfig gestureConfig = CanvasGestureConfig.all,
  CanvasPhysicsConfig physicsConfig = const CanvasPhysicsConfig(),
  CanvasMomentumConfig momentumConfig = CanvasMomentumConfig.defaults,
  Color? backgroundColor,
  CanvasLayerBuilder? content,
  CanvasLayerBuilder? overlay,
  void Function(Offset)? onTapWorld,
  void Function(Offset)? onDoubleTapWorld,
  void Function(Offset)? onLongPressWorld,
  void Function(CanvasDragStartDetails)? onDragStartWorld,
  void Function(CanvasDragUpdateDetails)? onDragUpdateWorld,
  void Function(CanvasDragEndDetails)? onDragEndWorld,
  void Function(Offset)? onHoverWorld,
  void Function()? onHoverExitWorld,
  bool Function(Offset)? shouldHandleScroll,
}) {
  return MaterialApp(
    home: SizedBox(
      width: size.width,
      height: size.height,
      child: InfiniteCanvas(
        controller: controller,
        gestureConfig: gestureConfig,
        physicsConfig: physicsConfig,
        momentumConfig: momentumConfig,
        backgroundColor: backgroundColor,
        layers: CanvasLayers(
          content: content ?? (context, ctrl) => const SizedBox(),
          overlay: overlay,
        ),
        onTapWorld: onTapWorld,
        onDoubleTapWorld: onDoubleTapWorld,
        onLongPressWorld: onLongPressWorld,
        onDragStartWorld: onDragStartWorld,
        onDragUpdateWorld: onDragUpdateWorld,
        onDragEndWorld: onDragEndWorld,
        onHoverWorld: onHoverWorld,
        onHoverExitWorld: onHoverExitWorld,
        shouldHandleScroll: shouldHandleScroll,
      ),
    ),
  );
}

/// A CustomPainter that counts paint calls.
///
/// Useful for measuring repaint frequency in performance tests.
///
/// Example:
/// ```dart
/// int repaintCount = 0;
/// CustomPaint(
///   painter: CountingPainter(
///     onPaint: () => repaintCount++,
///     color: Colors.blue,
///   ),
/// )
/// ```
class CountingPainter extends CustomPainter {
  CountingPainter({
    required this.onPaint,
    this.color = Colors.blue,
  });

  final VoidCallback onPaint;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CountingPainter oldDelegate) =>
      color != oldDelegate.color;
}
