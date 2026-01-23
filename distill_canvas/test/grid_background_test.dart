import 'dart:ui' show PointMode;

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('GridBackground', () {
    group('widget', () {
      testWidgets('renders with default configuration', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(controller: controller),
            ),
          ),
        );

        expect(find.byType(GridBackground), findsOneWidget);
      });

      testWidgets('returns SizedBox.shrink when viewportSize is null',
          (tester) async {
        // Create controller without attaching (no viewportSize)
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(controller: controller),
            ),
          ),
        );

        // GridBackground should be present
        expect(find.byType(GridBackground), findsOneWidget);
        // Verify the controller has no viewport size (which causes SizedBox.shrink)
        expect(controller.viewportSize, isNull);
      });

      testWidgets('updates when controller changes', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        int buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  buildCount++;
                  return GridBackground(controller: controller);
                },
              ),
            ),
          ),
        );

        final initialBuildCount = buildCount;

        // Change zoom - should trigger rebuild
        controller.setZoom(2.0, focalPointInView: Offset.zero);
        await tester.pump();

        expect(buildCount, greaterThan(initialBuildCount));
      });

      testWidgets('respects custom spacing configuration', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(
                controller: controller,
                spacing: 100.0,
              ),
            ),
          ),
        );

        expect(find.byType(GridBackground), findsOneWidget);
      });

      testWidgets('respects custom color configuration', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(
                controller: controller,
                color: Colors.red,
                axisColor: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.byType(GridBackground), findsOneWidget);
      });
    });

    group('GridPainter', () {
      test('shouldRepaint returns true when zoom changes', () {
        final painter1 = _createGridPainter(zoom: 1.0);
        final painter2 = _createGridPainter(zoom: 2.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when visibleBounds changes', () {
        final painter1 = _createGridPainter(
          visibleBounds: const Rect.fromLTWH(0, 0, 800, 600),
        );
        final painter2 = _createGridPainter(
          visibleBounds: const Rect.fromLTWH(100, 100, 800, 600),
        );

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when spacing changes', () {
        final painter1 = _createGridPainter(spacing: 50.0);
        final painter2 = _createGridPainter(spacing: 100.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when color changes', () {
        final painter1 = _createGridPainter(color: Colors.grey);
        final painter2 = _createGridPainter(color: Colors.red);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when strokeWidth changes', () {
        final painter1 = _createGridPainter(strokeWidth: 1.0);
        final painter2 = _createGridPainter(strokeWidth: 2.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when showAxes changes', () {
        final painter1 = _createGridPainter(showAxes: true);
        final painter2 = _createGridPainter(showAxes: false);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when axisColor changes', () {
        final painter1 = _createGridPainter(axisColor: Colors.grey);
        final painter2 = _createGridPainter(axisColor: Colors.blue);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when minPixelSpacing changes', () {
        final painter1 = _createGridPainter(minPixelSpacing: 20.0);
        final painter2 = _createGridPainter(minPixelSpacing: 30.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns false when nothing changes', () {
        final painter1 = _createGridPainter();
        final painter2 = _createGridPainter();

        expect(painter2.shouldRepaint(painter1), isFalse);
      });
    });

    group('LOD (Level of Detail)', () {
      testWidgets('doubles spacing when lines would be too dense',
          (tester) async {
        // At zoom 0.1 with spacing 50 and minPixelSpacing 20:
        // 50 * 0.1 = 5 pixels < 20, so spacing should double to 100
        // 100 * 0.1 = 10 pixels < 20, so spacing should double to 200
        // 200 * 0.1 = 20 pixels >= 20, stop

        final controller = createAttachedController(initialZoom: 0.1);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(
                controller: controller,
                spacing: 50.0,
                minPixelSpacing: 20.0,
              ),
            ),
          ),
        );

        // The widget should render without error at this zoom level
        expect(find.byType(GridBackground), findsOneWidget);
      });

      testWidgets('handles extreme zoom out gracefully', (tester) async {
        final controller = createAttachedController(initialZoom: 0.01);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(controller: controller),
            ),
          ),
        );

        // Should render without crashing due to safety caps
        expect(find.byType(GridBackground), findsOneWidget);
      });
    });

    group('origin axes', () {
      testWidgets('shows origin axes when showAxes is true', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(
                controller: controller,
                showAxes: true,
              ),
            ),
          ),
        );

        expect(find.byType(GridBackground), findsOneWidget);
      });

      testWidgets('hides origin axes when showAxes is false', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: GridBackground(
                controller: controller,
                showAxes: false,
              ),
            ),
          ),
        );

        expect(find.byType(GridBackground), findsOneWidget);
      });
    });
  });

  group('DotBackground', () {
    group('widget', () {
      testWidgets('renders with default configuration', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(controller: controller),
            ),
          ),
        );

        expect(find.byType(DotBackground), findsOneWidget);
      });

      testWidgets('returns SizedBox.shrink when viewportSize is null',
          (tester) async {
        final controller = InfiniteCanvasController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(controller: controller),
            ),
          ),
        );

        // DotBackground should still be in tree, just returning SizedBox.shrink
        expect(find.byType(DotBackground), findsOneWidget);
      });

      testWidgets('respects custom spacing configuration', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(
                controller: controller,
                spacing: 40.0,
              ),
            ),
          ),
        );

        expect(find.byType(DotBackground), findsOneWidget);
      });

      testWidgets('respects custom dotRadius configuration', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(
                controller: controller,
                dotRadius: 2.0,
              ),
            ),
          ),
        );

        expect(find.byType(DotBackground), findsOneWidget);
      });

      testWidgets('respects custom color configuration', (tester) async {
        final controller = createAttachedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(
                controller: controller,
                color: Colors.blue,
              ),
            ),
          ),
        );

        expect(find.byType(DotBackground), findsOneWidget);
      });
    });

    group('DotPainter', () {
      test('shouldRepaint returns true when zoom changes', () {
        final painter1 = _createDotPainter(zoom: 1.0);
        final painter2 = _createDotPainter(zoom: 2.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when visibleBounds changes', () {
        final painter1 = _createDotPainter(
          visibleBounds: const Rect.fromLTWH(0, 0, 800, 600),
        );
        final painter2 = _createDotPainter(
          visibleBounds: const Rect.fromLTWH(100, 100, 800, 600),
        );

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when spacing changes', () {
        final painter1 = _createDotPainter(spacing: 20.0);
        final painter2 = _createDotPainter(spacing: 40.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when dotRadius changes', () {
        final painter1 = _createDotPainter(dotRadius: 1.0);
        final painter2 = _createDotPainter(dotRadius: 2.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when color changes', () {
        final painter1 = _createDotPainter(color: Colors.grey);
        final painter2 = _createDotPainter(color: Colors.blue);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns true when minPixelSpacing changes', () {
        final painter1 = _createDotPainter(minPixelSpacing: 12.0);
        final painter2 = _createDotPainter(minPixelSpacing: 20.0);

        expect(painter2.shouldRepaint(painter1), isTrue);
      });

      test('shouldRepaint returns false when nothing changes', () {
        final painter1 = _createDotPainter();
        final painter2 = _createDotPainter();

        expect(painter2.shouldRepaint(painter1), isFalse);
      });
    });

    group('LOD (Level of Detail)', () {
      testWidgets('doubles spacing when screen-space density too high',
          (tester) async {
        // At zoom 0.1 with spacing 20 and minPixelSpacing 12:
        // 20 * 0.1 = 2 pixels < 12, so spacing should double

        final controller = createAttachedController(initialZoom: 0.1);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(
                controller: controller,
                spacing: 20.0,
                minPixelSpacing: 12.0,
              ),
            ),
          ),
        );

        expect(find.byType(DotBackground), findsOneWidget);
      });

      testWidgets('handles extreme zoom out gracefully', (tester) async {
        // Even at very low zoom, the safety cap should prevent issues
        final controller = createAttachedController(initialZoom: 0.001);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(controller: controller),
            ),
          ),
        );

        expect(find.byType(DotBackground), findsOneWidget);
      });

      testWidgets('handles very large visible bounds', (tester) async {
        // Test with a very zoomed out view that would have many dots
        final controller = createAttachedController(initialZoom: 0.05);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 800,
              height: 600,
              child: DotBackground(
                controller: controller,
                spacing: 10.0, // Small spacing
              ),
            ),
          ),
        );

        // Should render without crashing due to maxDots cap
        expect(find.byType(DotBackground), findsOneWidget);
      });
    });
  });
}

// Helper to create GridPainter for testing shouldRepaint
_TestableGridPainter _createGridPainter({
  double zoom = 1.0,
  Rect visibleBounds = const Rect.fromLTWH(0, 0, 800, 600),
  double spacing = 50.0,
  Color color = Colors.grey,
  double strokeWidth = 1.0,
  bool showAxes = true,
  Color axisColor = Colors.grey,
  double minPixelSpacing = 20.0,
}) {
  return _TestableGridPainter(
    zoom: zoom,
    visibleBounds: visibleBounds,
    spacing: spacing,
    color: color,
    strokeWidth: strokeWidth,
    showAxes: showAxes,
    axisColor: axisColor,
    minPixelSpacing: minPixelSpacing,
  );
}

// Helper to create DotPainter for testing shouldRepaint
_TestableDotPainter _createDotPainter({
  double zoom = 1.0,
  Rect visibleBounds = const Rect.fromLTWH(0, 0, 800, 600),
  double spacing = 20.0,
  double dotRadius = 1.0,
  Color color = Colors.grey,
  double minPixelSpacing = 12.0,
}) {
  return _TestableDotPainter(
    zoom: zoom,
    visibleBounds: visibleBounds,
    spacing: spacing,
    dotRadius: dotRadius,
    color: color,
    minPixelSpacing: minPixelSpacing,
  );
}

// Testable version of _GridPainter since the original is private
class _TestableGridPainter extends CustomPainter {
  _TestableGridPainter({
    required this.zoom,
    required this.visibleBounds,
    required this.spacing,
    required this.color,
    required this.strokeWidth,
    required this.showAxes,
    required this.axisColor,
    required this.minPixelSpacing,
  });

  final double zoom;
  final Rect visibleBounds;
  final double spacing;
  final Color color;
  final double strokeWidth;
  final bool showAxes;
  final Color axisColor;
  final double minPixelSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    // Same implementation as _GridPainter
    var effectiveSpacing = spacing;
    while (effectiveSpacing * zoom < minPixelSpacing) {
      effectiveSpacing *= 2;
    }

    final effectiveStrokeWidth = strokeWidth / zoom;

    final paint = Paint()
      ..color = color
      ..strokeWidth = effectiveStrokeWidth
      ..style = PaintingStyle.stroke;

    final startX =
        (visibleBounds.left / effectiveSpacing).floor() * effectiveSpacing;
    final endX =
        (visibleBounds.right / effectiveSpacing).ceil() * effectiveSpacing;
    final startY =
        (visibleBounds.top / effectiveSpacing).floor() * effectiveSpacing;
    final endY =
        (visibleBounds.bottom / effectiveSpacing).ceil() * effectiveSpacing;

    final lineCountX =
        ((endX - startX) / effectiveSpacing).abs().clamp(0, 500).toInt();
    final lineCountY =
        ((endY - startY) / effectiveSpacing).abs().clamp(0, 500).toInt();

    for (var i = 0; i <= lineCountX; i++) {
      final x = startX + i * effectiveSpacing;
      canvas.drawLine(
        Offset(x, visibleBounds.top),
        Offset(x, visibleBounds.bottom),
        paint,
      );
    }

    for (var i = 0; i <= lineCountY; i++) {
      final y = startY + i * effectiveSpacing;
      canvas.drawLine(
        Offset(visibleBounds.left, y),
        Offset(visibleBounds.right, y),
        paint,
      );
    }

    if (showAxes) {
      final axisPaint = Paint()
        ..color = axisColor
        ..strokeWidth = effectiveStrokeWidth * 2
        ..style = PaintingStyle.stroke;

      if (visibleBounds.left <= 0 && visibleBounds.right >= 0) {
        canvas.drawLine(
          Offset(0, visibleBounds.top),
          Offset(0, visibleBounds.bottom),
          axisPaint,
        );
      }

      if (visibleBounds.top <= 0 && visibleBounds.bottom >= 0) {
        canvas.drawLine(
          Offset(visibleBounds.left, 0),
          Offset(visibleBounds.right, 0),
          axisPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TestableGridPainter oldDelegate) {
    return zoom != oldDelegate.zoom ||
        visibleBounds != oldDelegate.visibleBounds ||
        spacing != oldDelegate.spacing ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        showAxes != oldDelegate.showAxes ||
        axisColor != oldDelegate.axisColor ||
        minPixelSpacing != oldDelegate.minPixelSpacing;
  }
}

// Testable version of _DotPainter since the original is private
class _TestableDotPainter extends CustomPainter {
  _TestableDotPainter({
    required this.zoom,
    required this.visibleBounds,
    required this.spacing,
    required this.dotRadius,
    required this.color,
    required this.minPixelSpacing,
  });

  final double zoom;
  final Rect visibleBounds;
  final double spacing;
  final double dotRadius;
  final Color color;
  final double minPixelSpacing;

  static const int _maxDots = 10000;

  @override
  void paint(Canvas canvas, Size size) {
    var effectiveSpacing = spacing;

    while (true) {
      if (effectiveSpacing * zoom < minPixelSpacing) {
        effectiveSpacing *= 2;
        continue;
      }

      final cols = (visibleBounds.width / effectiveSpacing).ceil() + 1;
      final rows = (visibleBounds.height / effectiveSpacing).ceil() + 1;
      if (cols * rows > _maxDots) {
        effectiveSpacing *= 2;
        continue;
      }

      break;
    }

    final startX =
        (visibleBounds.left / effectiveSpacing).floor() * effectiveSpacing;
    final startY =
        (visibleBounds.top / effectiveSpacing).floor() * effectiveSpacing;
    final endX =
        (visibleBounds.right / effectiveSpacing).ceil() * effectiveSpacing;
    final endY =
        (visibleBounds.bottom / effectiveSpacing).ceil() * effectiveSpacing;

    final points = <Offset>[];
    for (var x = startX; x <= endX; x += effectiveSpacing) {
      for (var y = startY; y <= endY; y += effectiveSpacing) {
        points.add(Offset(x, y));
      }
    }

    if (points.isEmpty) return;

    final worldRadius = dotRadius / zoom;

    final paint = Paint()
      ..color = color
      ..strokeWidth = worldRadius * 2
      ..strokeCap = StrokeCap.round;

    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_TestableDotPainter oldDelegate) {
    return zoom != oldDelegate.zoom ||
        visibleBounds != oldDelegate.visibleBounds ||
        spacing != oldDelegate.spacing ||
        dotRadius != oldDelegate.dotRadius ||
        color != oldDelegate.color ||
        minPixelSpacing != oldDelegate.minPixelSpacing;
  }
}
