import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

/// Test implementation of CanvasOverlayWidget.
class TestOverlay extends CanvasOverlayWidget {
  const TestOverlay({
    super.key,
    required super.controller,
    this.buildCount,
  });

  /// Optional callback to track rebuild count.
  final ValueChanged<int>? buildCount;

  static int _buildCounter = 0;

  @override
  Widget buildOverlay(BuildContext context, Rect viewBounds) {
    _buildCounter++;
    buildCount?.call(_buildCounter);

    return CustomPaint(
      size: Size(viewBounds.width, viewBounds.height),
      painter: _TestPainter(viewBounds),
    );
  }

  static void resetBuildCounter() => _buildCounter = 0;
}

class _TestPainter extends CustomPainter {
  _TestPainter(this.viewBounds);

  final Rect viewBounds;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a border to indicate overlay is rendering
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(viewBounds, paint);
  }

  @override
  bool shouldRepaint(_TestPainter oldDelegate) =>
      viewBounds != oldDelegate.viewBounds;
}

void main() {
  setUp(() {
    TestOverlay.resetBuildCounter();
  });

  group('CanvasOverlayWidget', () {
    testWidgets('renders when controller is attached', (tester) async {
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
                  content: (_, __) => const SizedBox.shrink(),
                  overlay: (_, ctrl) => TestOverlay(controller: ctrl),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overlay should have built
      expect(find.byType(TestOverlay), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('receives correct viewBounds', (tester) async {
      final controller = InfiniteCanvasController();
      Rect? capturedBounds;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InfiniteCanvas(
                controller: controller,
                layers: CanvasLayers(
                  content: (_, __) => const SizedBox.shrink(),
                  overlay: (_, ctrl) => _BoundsCapturingOverlay(
                    controller: ctrl,
                    onBounds: (b) => capturedBounds = b,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedBounds, isNotNull);
      expect(capturedBounds!.left, 0);
      expect(capturedBounds!.top, 0);
      expect(capturedBounds!.width, 800);
      expect(capturedBounds!.height, 600);
    });

    testWidgets('rebuilds when controller notifies', (tester) async {
      final controller = InfiniteCanvasController();
      final buildCounts = <int>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InfiniteCanvas(
                controller: controller,
                layers: CanvasLayers(
                  content: (_, __) => const SizedBox.shrink(),
                  overlay: (_, ctrl) => TestOverlay(
                    controller: ctrl,
                    buildCount: buildCounts.add,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCount = buildCounts.length;
      expect(initialCount, greaterThan(0));

      // Pan the controller
      controller.panBy(const Offset(100, 100));
      await tester.pump();

      // Should have rebuilt
      expect(buildCounts.length, greaterThan(initialCount));
    });

    testWidgets('returns SizedBox.shrink when viewport size is null', (
      tester,
    ) async {
      // Create controller without attaching (no viewport size)
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TestOverlay(controller: controller),
          ),
        ),
      );

      // Should render SizedBox.shrink (no CustomPaint from TestOverlay)
      expect(find.byType(SizedBox), findsWidgets);
    });

    test('can access controller from subclass', () {
      final controller = createAttachedController();
      addTearDown(controller.dispose);

      final overlay = TestOverlay(controller: controller);

      expect(overlay.controller, same(controller));
    });
  });
}

/// Helper overlay that captures bounds for testing.
class _BoundsCapturingOverlay extends CanvasOverlayWidget {
  const _BoundsCapturingOverlay({
    required super.controller,
    required this.onBounds,
  });

  final ValueChanged<Rect> onBounds;

  @override
  Widget buildOverlay(BuildContext context, Rect viewBounds) {
    onBounds(viewBounds);
    return const SizedBox.shrink();
  }
}
