import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('FrameTarget', () {
    test('equality based on frameId', () {
      const target1 = FrameTarget('frame_1');
      const target2 = FrameTarget('frame_1');
      const target3 = FrameTarget('frame_2');

      expect(target1, equals(target2));
      expect(target1, isNot(equals(target3)));
    });

    test('hashCode consistent with equality', () {
      const target1 = FrameTarget('frame_1');
      const target2 = FrameTarget('frame_1');

      expect(target1.hashCode, equals(target2.hashCode));
    });

    test('toString includes frameId', () {
      const target = FrameTarget('frame_1');
      expect(target.toString(), contains('frame_1'));
    });
  });

  group('NodeTarget', () {
    test('equality based on all fields', () {
      const target1 = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
        patchTarget: 'node_1',
      );
      const target2 = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
        patchTarget: 'node_1',
      );
      const target3 = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_2',
        patchTarget: 'node_2',
      );

      expect(target1, equals(target2));
      expect(target1, isNot(equals(target3)));
    });

    test('equality considers patchTarget', () {
      const target1 = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'inst1::node_1',
        patchTarget: 'inst1',
      );
      const target2 = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'inst1::node_1',
        patchTarget: null,
      );

      expect(target1, isNot(equals(target2)));
    });

    test('hashCode consistent with equality', () {
      const target1 = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
        patchTarget: 'node_1',
      );
      const target2 = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
        patchTarget: 'node_1',
      );

      expect(target1.hashCode, equals(target2.hashCode));
    });

    test('canPatch returns true when patchTarget is not null', () {
      const target = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
        patchTarget: 'node_1',
      );

      expect(target.canPatch, isTrue);
    });

    test('canPatch returns false when patchTarget is null', () {
      const target = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'inst1::node_1',
        patchTarget: null,
      );

      expect(target.canPatch, isFalse);
    });

    test('toString includes relevant info', () {
      const target = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
        patchTarget: 'node_1',
      );

      final str = target.toString();
      expect(str, contains('frame_1'));
      expect(str, contains('node_1'));
    });
  });

  group('DragTarget type checking', () {
    test('FrameTarget is DragTarget', () {
      const DragTarget target = FrameTarget('frame_1');
      expect(target, isA<DragTarget>());
      expect(target, isA<FrameTarget>());
    });

    test('NodeTarget is DragTarget', () {
      const DragTarget target = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
      );
      expect(target, isA<DragTarget>());
      expect(target, isA<NodeTarget>());
    });

    test('can switch on DragTarget', () {
      const DragTarget frameTarget = FrameTarget('frame_1');
      const DragTarget nodeTarget = NodeTarget(
        frameId: 'frame_1',
        expandedId: 'node_1',
      );

      String describe(DragTarget target) {
        return switch (target) {
          FrameTarget(:final frameId) => 'Frame: $frameId',
          NodeTarget(:final expandedId) => 'Node: $expandedId',
        };
      }

      expect(describe(frameTarget), equals('Frame: frame_1'));
      expect(describe(nodeTarget), equals('Node: node_1'));
    });
  });
}
