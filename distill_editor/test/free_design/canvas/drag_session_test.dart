import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('DragMode', () {
    test('has move, resize, and marquee modes', () {
      expect(DragMode.values, contains(DragMode.move));
      expect(DragMode.values, contains(DragMode.resize));
      expect(DragMode.values, contains(DragMode.marquee));
    });
  });

  group('ResizeHandle', () {
    test('isLeft returns true for left handles', () {
      expect(ResizeHandle.topLeft.isLeft, isTrue);
      expect(ResizeHandle.middleLeft.isLeft, isTrue);
      expect(ResizeHandle.bottomLeft.isLeft, isTrue);

      expect(ResizeHandle.topCenter.isLeft, isFalse);
      expect(ResizeHandle.topRight.isLeft, isFalse);
      expect(ResizeHandle.middleRight.isLeft, isFalse);
      expect(ResizeHandle.bottomCenter.isLeft, isFalse);
      expect(ResizeHandle.bottomRight.isLeft, isFalse);
    });

    test('isRight returns true for right handles', () {
      expect(ResizeHandle.topRight.isRight, isTrue);
      expect(ResizeHandle.middleRight.isRight, isTrue);
      expect(ResizeHandle.bottomRight.isRight, isTrue);

      expect(ResizeHandle.topCenter.isRight, isFalse);
      expect(ResizeHandle.topLeft.isRight, isFalse);
      expect(ResizeHandle.middleLeft.isRight, isFalse);
      expect(ResizeHandle.bottomCenter.isRight, isFalse);
      expect(ResizeHandle.bottomLeft.isRight, isFalse);
    });

    test('isTop returns true for top handles', () {
      expect(ResizeHandle.topLeft.isTop, isTrue);
      expect(ResizeHandle.topCenter.isTop, isTrue);
      expect(ResizeHandle.topRight.isTop, isTrue);

      expect(ResizeHandle.middleLeft.isTop, isFalse);
      expect(ResizeHandle.middleRight.isTop, isFalse);
      expect(ResizeHandle.bottomLeft.isTop, isFalse);
      expect(ResizeHandle.bottomCenter.isTop, isFalse);
      expect(ResizeHandle.bottomRight.isTop, isFalse);
    });

    test('isBottom returns true for bottom handles', () {
      expect(ResizeHandle.bottomLeft.isBottom, isTrue);
      expect(ResizeHandle.bottomCenter.isBottom, isTrue);
      expect(ResizeHandle.bottomRight.isBottom, isTrue);

      expect(ResizeHandle.topLeft.isBottom, isFalse);
      expect(ResizeHandle.topCenter.isBottom, isFalse);
      expect(ResizeHandle.topRight.isBottom, isFalse);
      expect(ResizeHandle.middleLeft.isBottom, isFalse);
      expect(ResizeHandle.middleRight.isBottom, isFalse);
    });

    test('isHorizontalOnly for side handles', () {
      expect(ResizeHandle.middleLeft.isHorizontalOnly, isTrue);
      expect(ResizeHandle.middleRight.isHorizontalOnly, isTrue);

      expect(ResizeHandle.topLeft.isHorizontalOnly, isFalse);
      expect(ResizeHandle.topCenter.isHorizontalOnly, isFalse);
      expect(ResizeHandle.bottomCenter.isHorizontalOnly, isFalse);
    });

    test('isVerticalOnly for top/bottom center handles', () {
      expect(ResizeHandle.topCenter.isVerticalOnly, isTrue);
      expect(ResizeHandle.bottomCenter.isVerticalOnly, isTrue);

      expect(ResizeHandle.topLeft.isVerticalOnly, isFalse);
      expect(ResizeHandle.middleLeft.isVerticalOnly, isFalse);
      expect(ResizeHandle.bottomRight.isVerticalOnly, isFalse);
    });
  });

  group('DragSession.move', () {
    test('creates session with correct mode', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.move(
        targets: {target},
        startPositions: {target: const Offset(100, 100)},
        startSizes: {target: const Size(200, 150)},
      );

      expect(session.mode, equals(DragMode.move));
      expect(session.targets, contains(target));
      expect(session.accumulator, equals(Offset.zero));
    });

    test('getCurrentBounds calculates offset correctly', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.move(
        targets: {target},
        startPositions: {target: const Offset(100, 100)},
        startSizes: {target: const Size(200, 150)},
      );

      // Simulate drag
      session.accumulator = const Offset(50, 25);

      final bounds = session.getCurrentBounds(target);
      expect(bounds, isNotNull);
      expect(bounds!.left, equals(150)); // 100 + 50
      expect(bounds.top, equals(125)); // 100 + 25
      expect(bounds.width, equals(200)); // Size preserved
      expect(bounds.height, equals(150)); // Size preserved
    });

    test('getCurrentBounds returns null for unknown target', () {
      const target = FrameTarget('frame_1');
      const unknownTarget = FrameTarget('frame_2');

      final session = DragSession.move(
        targets: {target},
        startPositions: {target: const Offset(100, 100)},
        startSizes: {target: const Size(200, 150)},
      );

      expect(session.getCurrentBounds(unknownTarget), isNull);
    });
  });

  group('DragSession.resize', () {
    test('creates session with correct mode and handle', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.resize(
        target: target,
        handle: ResizeHandle.bottomRight,
        startPosition: const Offset(100, 100),
        startSize: const Size(200, 150),
      );

      expect(session.mode, equals(DragMode.resize));
      expect(session.handle, equals(ResizeHandle.bottomRight));
      expect(session.targets, contains(target));
    });

    test('bottomRight handle increases size', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.resize(
        target: target,
        handle: ResizeHandle.bottomRight,
        startPosition: const Offset(100, 100),
        startSize: const Size(200, 150),
      );

      session.accumulator = const Offset(30, 20);

      final bounds = session.getCurrentBounds(target);
      expect(bounds, isNotNull);
      expect(bounds!.left, equals(100)); // Position unchanged
      expect(bounds.top, equals(100)); // Position unchanged
      expect(bounds.width, equals(230)); // 200 + 30
      expect(bounds.height, equals(170)); // 150 + 20
    });

    test('topLeft handle decreases size and moves position', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.resize(
        target: target,
        handle: ResizeHandle.topLeft,
        startPosition: const Offset(100, 100),
        startSize: const Size(200, 150),
      );

      session.accumulator = const Offset(30, 20);

      final bounds = session.getCurrentBounds(target);
      expect(bounds, isNotNull);
      expect(bounds!.left, equals(130)); // 100 + 30
      expect(bounds.top, equals(120)); // 100 + 20
      expect(bounds.width, equals(170)); // 200 - 30
      expect(bounds.height, equals(130)); // 150 - 20
    });

    test('topRight handle moves top and increases width', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.resize(
        target: target,
        handle: ResizeHandle.topRight,
        startPosition: const Offset(100, 100),
        startSize: const Size(200, 150),
      );

      session.accumulator = const Offset(30, 20);

      final bounds = session.getCurrentBounds(target);
      expect(bounds, isNotNull);
      expect(bounds!.left, equals(100)); // Position unchanged
      expect(bounds.top, equals(120)); // 100 + 20
      expect(bounds.width, equals(230)); // 200 + 30
      expect(bounds.height, equals(130)); // 150 - 20
    });

    test('enforces minimum size 50', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.resize(
        target: target,
        handle: ResizeHandle.bottomRight,
        startPosition: const Offset(100, 100),
        startSize: const Size(100, 80),
      );

      // Try to shrink below minimum
      session.accumulator = const Offset(-80, -60);

      final bounds = session.getCurrentBounds(target);
      expect(bounds, isNotNull);
      expect(bounds!.width, equals(50)); // Clamped to minimum
      expect(bounds.height, equals(50)); // Clamped to minimum
    });

    test('enforces minimum size with position compensation for topLeft', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.resize(
        target: target,
        handle: ResizeHandle.topLeft,
        startPosition: const Offset(100, 100),
        startSize: const Size(100, 80),
      );

      // Try to shrink below minimum
      session.accumulator = const Offset(80, 60);

      final bounds = session.getCurrentBounds(target);
      expect(bounds, isNotNull);
      expect(bounds!.width, equals(50)); // Clamped to minimum
      expect(bounds.height, equals(50)); // Clamped to minimum
      // Position compensated when hitting minimum from left/top
      expect(bounds.left, equals(150)); // 100 + (100 - 50) = 150
      expect(bounds.top, equals(130)); // 100 + (80 - 50) = 130
    });
  });

  group('DragSession.generatePatches', () {
    test('generates SetFrameProp for frame move', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.move(
        targets: {target},
        startPositions: {target: const Offset(100, 100)},
        startSizes: {target: const Size(200, 150)},
      );
      session.accumulator = const Offset(50, 25);

      final patches = session.generatePatches();

      expect(patches, hasLength(1));
      expect(patches.first, isA<SetFrameProp>());

      final patch = patches.first as SetFrameProp;
      expect(patch.frameId, equals('frame_1'));
      expect(patch.path, equals('/canvas/position'));
      expect(patch.value['x'], equals(150.0));
      expect(patch.value['y'], equals(125.0));
    });

    test('generates SetProp for node move', () {
      const target = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
        patchTarget: 'node_1',
      );
      final session = DragSession.move(
        targets: {target},
        startPositions: {target: const Offset(10, 20)},
        startSizes: {target: const Size(100, 80)},
      );
      session.accumulator = const Offset(5, 10);

      final patches = session.generatePatches();

      expect(patches, hasLength(1));
      expect(patches.first, isA<SetProp>());

      final patch = patches.first as SetProp;
      expect(patch.id, equals('node_1'));
      expect(patch.path, equals('/layout/position'));
      expect(patch.value['mode'], equals('absolute'));
      expect(patch.value['x'], equals(15.0));
      expect(patch.value['y'], equals(30.0));
    });

    test('skips nodes inside instances (canPatch == false)', () {
      const target = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'inst1::node_1',
        patchTarget: null, // Inside instance
      );
      final session = DragSession.move(
        targets: {target},
        startPositions: {target: const Offset(10, 20)},
        startSizes: {target: const Size(100, 80)},
      );
      session.accumulator = const Offset(5, 10);

      final patches = session.generatePatches();

      expect(patches, isEmpty);
    });

    test('generates position and size patches for frame resize', () {
      const target = FrameTarget('frame_1');
      final session = DragSession.resize(
        target: target,
        handle: ResizeHandle.bottomRight,
        startPosition: const Offset(100, 100),
        startSize: const Size(200, 150),
      );
      session.accumulator = const Offset(30, 20);

      final patches = session.generatePatches();

      expect(patches, hasLength(2));

      final positionPatch = patches[0] as SetFrameProp;
      expect(positionPatch.path, equals('/canvas/position'));

      final sizePatch = patches[1] as SetFrameProp;
      expect(sizePatch.path, equals('/canvas/size'));
      expect(sizePatch.value['width'], equals(230.0));
      expect(sizePatch.value['height'], equals(170.0));
    });
  });

  group('DragSession.marquee', () {
    test('creates marquee session', () {
      final session = DragSession.marquee(
        startPosition: const Offset(100, 100),
      );

      expect(session.mode, equals(DragMode.marquee));
      expect(session.targets, isEmpty);
    });
  });
}
