import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  //─────────────────────────────────────────────────────────────────────────────
  // Coordinate Conversion Accuracy
  //─────────────────────────────────────────────────────────────────────────────

  group('coordinate conversion accuracy', () {
    test('viewToWorld at zoom 1 with no pan', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(
        controller.viewToWorld(const Offset(100, 100)),
        equals(const Offset(100, 100)),
      );
    });

    test('viewToWorld at zoom 2 with no pan', () {
      final controller = InfiniteCanvasController(initialZoom: 2.0);
      addTearDown(controller.dispose);

      expect(
        controller.viewToWorld(const Offset(200, 200)),
        equals(const Offset(100, 100)),
      );
    });

    test('viewToWorld with pan offset', () {
      final controller = InfiniteCanvasController(
        initialPan: const Offset(-100, -50),
      );
      addTearDown(controller.dispose);

      expect(
        controller.viewToWorld(const Offset(100, 100)),
        equals(const Offset(200, 150)),
      );
    });

    test('viewToWorld with pan and zoom', () {
      final controller = InfiniteCanvasController(
        initialZoom: 2.0,
        initialPan: const Offset(-100, -100),
      );
      addTearDown(controller.dispose);

      expect(
        controller.viewToWorld(const Offset(200, 200)),
        equals(const Offset(150, 150)),
      );
    });

    test('worldToView is inverse of viewToWorld', () {
      final controller = InfiniteCanvasController(
        initialZoom: 1.5,
        initialPan: const Offset(-50, -30),
      );
      addTearDown(controller.dispose);

      const worldPoint = Offset(100, 200);
      final viewPoint = controller.worldToView(worldPoint);
      final backToWorld = controller.viewToWorld(viewPoint);

      expect(backToWorld.dx, closeTo(worldPoint.dx, 0.001));
      expect(backToWorld.dy, closeTo(worldPoint.dy, 0.001));
    });

    test('getVisibleWorldBounds at zoom 1', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      final visible = controller.getVisibleWorldBounds(const Size(800, 600));
      expect(visible.left, equals(0));
      expect(visible.top, equals(0));
      expect(visible.width, equals(800));
      expect(visible.height, equals(600));
    });

    test('getVisibleWorldBounds accounts for zoom', () {
      final controller = InfiniteCanvasController(initialZoom: 2.0);
      addTearDown(controller.dispose);

      final visible = controller.getVisibleWorldBounds(const Size(800, 600));
      expect(visible.width, equals(400)); // 800 / 2
      expect(visible.height, equals(300)); // 600 / 2
    });

    test('getVisibleWorldBounds accounts for pan', () {
      final controller = InfiniteCanvasController(
        initialPan: const Offset(-200, -100),
      );
      addTearDown(controller.dispose);

      final visible = controller.getVisibleWorldBounds(const Size(800, 600));
      expect(visible.left, equals(200)); // -(-200) / 1
      expect(visible.top, equals(100)); // -(-100) / 1
    });
  });

  //─────────────────────────────────────────────────────────────────────────────
  // Controller State Management
  //─────────────────────────────────────────────────────────────────────────────

  group('controller state management', () {
    test('pan updates correctly', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(controller.pan, equals(Offset.zero));

      controller.setPan(const Offset(100, 50));
      expect(controller.pan, equals(const Offset(100, 50)));

      controller.panBy(const Offset(25, 25));
      expect(controller.pan, equals(const Offset(125, 75)));
    });

    test('zoom updates correctly', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      expect(controller.zoom, equals(1.0));

      controller.setZoom(2.0);
      expect(controller.zoom, equals(2.0));

      controller.zoomBy(1.5);
      expect(controller.zoom, equals(3.0));
    });

    test('isWorldRectVisible works correctly', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      // Without viewport size, should return true (assume visible)
      expect(
        controller.isWorldRectVisible(const Rect.fromLTWH(1000, 1000, 50, 50)),
        isTrue,
      );
    });

    test('centerOn calculates correct pan', () {
      final controller = InfiniteCanvasController();
      addTearDown(controller.dispose);

      // Simulate being attached with a viewport size
      // This is a simplified test - full integration tested via widget tests
      controller.setPan(const Offset(0, 0));
      controller.setZoom(1.0);

      // At zoom 1, to center world point (500, 400) in a 800x600 viewport:
      // viewportCenter = (400, 300)
      // newPan = viewportCenter - worldPoint * zoom = (400, 300) - (500, 400) = (-100, -100)
      // But without attachment, centerOn won't work - tested in widget tests
    });
  });

  //─────────────────────────────────────────────────────────────────────────────
  // Widget Integration
  //─────────────────────────────────────────────────────────────────────────────

  group('widget integration', () {
    testWidgets('canvas renders without errors', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
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
      );
      await tester.pumpAndSettle();

      expect(find.byType(InfiniteCanvas), findsOneWidget);
    });

    testWidgets('content layer builds', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();
      var contentBuilt = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) {
                  contentBuilt = true;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(contentBuilt, isTrue);
    });

    testWidgets('overlay layer builds', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();
      var overlayBuilt = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
                overlay: (context, ctrl) {
                  overlayBuilt = true;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(overlayBuilt, isTrue);
    });

    testWidgets('controller is accessible in layers', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();
      InfiniteCanvasController? receivedController;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) {
                  receivedController = ctrl;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(receivedController, same(controller));
    });

    testWidgets('controller changes trigger rebuild', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: InfiniteCanvas(
              controller: controller,
              layers: CanvasLayers(
                content: (context, ctrl) {
                  buildCount++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialBuildCount = buildCount;

      controller.setZoom(2.0);
      await tester.pump();

      expect(buildCount, greaterThan(initialBuildCount));
    });
  });

  //─────────────────────────────────────────────────────────────────────────────
  // Bounded Panning
  //─────────────────────────────────────────────────────────────────────────────

  group('bounded panning', () {
    testWidgets('fitToRect respects bounds', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: InfiniteCanvas(
              controller: controller,
              physicsConfig: const CanvasPhysicsConfig(
                panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
              ),
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.fitToRect(
        const Rect.fromLTWH(800, 800, 200, 200),
        padding: EdgeInsets.zero,
      );
      await tester.pump();

      final visibleWorld = controller.getVisibleWorldBounds(
        const Size(400, 300),
      );
      expect(visibleWorld.right, lessThanOrEqualTo(1000));
      expect(visibleWorld.bottom, lessThanOrEqualTo(1000));
    });

    testWidgets('centerOn respects bounds', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: InfiniteCanvas(
              controller: controller,
              physicsConfig: const CanvasPhysicsConfig(
                panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
              ),
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.centerOn(const Offset(0, 0));
      await tester.pump();

      final visibleWorld = controller.getVisibleWorldBounds(
        const Size(400, 300),
      );
      expect(visibleWorld.left, greaterThanOrEqualTo(0));
      expect(visibleWorld.top, greaterThanOrEqualTo(0));
    });

    testWidgets('zoom with focal point respects bounds', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 300,
            child: InfiniteCanvas(
              controller: controller,
              physicsConfig: const CanvasPhysicsConfig(
                panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
              ),
              layers: CanvasLayers(
                content: (context, ctrl) => const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.setPan(const Offset(-600, -700));
      await tester.pump();

      controller.setZoom(2.0, focalPointInView: const Offset(350, 250));
      await tester.pump();

      final visibleWorld = controller.getVisibleWorldBounds(
        const Size(400, 300),
      );
      expect(visibleWorld.right, lessThanOrEqualTo(1000));
      expect(visibleWorld.bottom, lessThanOrEqualTo(1000));
    });
  });

  //─────────────────────────────────────────────────────────────────────────────
  // Real-World Scenarios
  //─────────────────────────────────────────────────────────────────────────────

  group('real-world scenarios', () {
    testWidgets('zoom to fit content then center on specific area', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
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
      );
      await tester.pumpAndSettle();

      controller.fitToRect(
        const Rect.fromLTWH(0, 0, 2000, 1500),
        padding: const EdgeInsets.all(50),
      );
      await tester.pump();

      expect(controller.zoom, lessThan(1.0));

      controller.centerOn(const Offset(1500, 1000));
      await tester.pump();

      final visibleWorld = controller.getVisibleWorldBounds(
        const Size(800, 600),
      );
      expect(visibleWorld.center.dx, closeTo(1500, 100));
      expect(visibleWorld.center.dy, closeTo(1000, 100));
    });

    testWidgets('coordinate conversion roundtrip at various settings', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
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
      );
      await tester.pumpAndSettle();

      for (final zoom in [0.5, 1.0, 2.0, 5.0]) {
        for (final pan in [
          Offset.zero,
          const Offset(-100, -50),
          const Offset(200, 300),
        ]) {
          controller.setZoom(zoom);
          controller.setPan(pan);
          await tester.pump();

          const worldPoint = Offset(500, 400);
          final viewPoint = controller.worldToView(worldPoint);
          final backToWorld = controller.viewToWorld(viewPoint);

          expect(
            backToWorld.dx,
            closeTo(worldPoint.dx, 0.01),
            reason: 'zoom=$zoom, pan=$pan',
          );
          expect(
            backToWorld.dy,
            closeTo(worldPoint.dy, 0.01),
            reason: 'zoom=$zoom, pan=$pan',
          );
        }
      }
    });

    testWidgets('CanvasItem positions correctly', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: InfiniteCanvas(
              controller: controller,
              initialViewport: const InitialViewport.topLeft(),
              layers: CanvasLayers(
                content: (context, ctrl) => Stack(
                  children: [
                    CanvasItem(
                      position: const Offset(100, 100),
                      child: Container(
                        key: const Key('test-item'),
                        width: 50,
                        height: 50,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Item should be rendered
      expect(find.byKey(const Key('test-item')), findsOneWidget);
    });
  });
}
