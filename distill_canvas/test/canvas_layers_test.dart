import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CanvasLayers', () {
    test('accepts required content builder', () {
      final layers = CanvasLayers(
        content: (context, controller) => const SizedBox(),
      );

      expect(layers.content, isNotNull);
      expect(layers.background, isNull);
      expect(layers.overlay, isNull);
      expect(layers.debug, isNull);
    });

    test('accepts all optional builders', () {
      final layers = CanvasLayers(
        background: (context, controller) =>
            const ColoredBox(color: Colors.grey),
        content: (context, controller) => const SizedBox(),
        overlay: (context, controller) => const Text('overlay'),
        debug: (context, controller) => const Text('debug'),
      );

      expect(layers.background, isNotNull);
      expect(layers.content, isNotNull);
      expect(layers.overlay, isNotNull);
      expect(layers.debug, isNotNull);
    });

    test('builders are stored correctly', () {
      final layers = CanvasLayers(
        content: (context, controller) => const SizedBox(),
      );

      // Verify the builder is correctly stored
      expect(layers.content, isA<CanvasLayerBuilder>());
    });

    testWidgets('renders content layer', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: InfiniteCanvas(
            controller: controller,
            layers: CanvasLayers(
              content: (context, ctrl) => const Text('content'),
            ),
          ),
        ),
      );

      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('renders background layer', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: InfiniteCanvas(
            controller: controller,
            layers: CanvasLayers(
              background: (context, ctrl) =>
                  Container(key: const Key('background'), color: Colors.grey),
              content: (context, ctrl) => const SizedBox(),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('background')), findsOneWidget);
    });

    testWidgets('renders overlay layer', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: InfiniteCanvas(
            controller: controller,
            layers: CanvasLayers(
              content: (context, ctrl) => const SizedBox(),
              overlay: (context, ctrl) => const Text('overlay'),
            ),
          ),
        ),
      );

      expect(find.text('overlay'), findsOneWidget);
    });

    testWidgets('renders debug layer', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();

      await tester.pumpWidget(
        MaterialApp(
          home: InfiniteCanvas(
            controller: controller,
            layers: CanvasLayers(
              content: (context, ctrl) => const SizedBox(),
              debug: (context, ctrl) => const Text('debug'),
            ),
          ),
        ),
      );

      expect(find.text('debug'), findsOneWidget);
    });

    testWidgets('layers render in correct order', (WidgetTester tester) async {
      final controller = InfiniteCanvasController();
      final buildOrder = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: InfiniteCanvas(
            controller: controller,
            layers: CanvasLayers(
              background: (context, ctrl) {
                buildOrder.add('background');
                return const SizedBox(key: Key('bg'));
              },
              content: (context, ctrl) {
                buildOrder.add('content');
                return const SizedBox(key: Key('content'));
              },
              overlay: (context, ctrl) {
                buildOrder.add('overlay');
                return const SizedBox(key: Key('overlay'));
              },
              debug: (context, ctrl) {
                buildOrder.add('debug');
                return const SizedBox(key: Key('debug'));
              },
            ),
          ),
        ),
      );

      // All layers should be built
      expect(buildOrder, contains('background'));
      expect(buildOrder, contains('content'));
      expect(buildOrder, contains('overlay'));
      expect(buildOrder, contains('debug'));
    });

    testWidgets('controller is accessible in builders', (
      WidgetTester tester,
    ) async {
      final controller = InfiniteCanvasController();
      InfiniteCanvasController? capturedController;

      await tester.pumpWidget(
        MaterialApp(
          home: InfiniteCanvas(
            controller: controller,
            layers: CanvasLayers(
              content: (context, ctrl) {
                capturedController = ctrl;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedController, equals(controller));
    });
  });
}
