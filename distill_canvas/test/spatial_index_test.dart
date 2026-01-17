import 'dart:ui';

import 'package:distill_canvas/utilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuadTree', () {
    late QuadTree<String> tree;

    setUp(() {
      tree = QuadTree<String>(
        const Rect.fromLTWH(-1000, -1000, 2000, 2000),
        maxObjects: 4,
        maxDepth: 4,
      );
    });

    group('insert and query', () {
      test('inserts and retrieves single item', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));

        expect(tree.length, 1);

        final results = tree.query(const Rect.fromLTWH(-50, -50, 200, 200));
        expect(results, contains('a'));
      });

      test('retrieves multiple items in region', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 50, 50));
        tree.insert('b', const Rect.fromLTWH(100, 0, 50, 50));
        tree.insert('c', const Rect.fromLTWH(0, 100, 50, 50));
        tree.insert('d', const Rect.fromLTWH(500, 500, 50, 50));

        // Query region that contains a, b, c but not d
        final results = tree
            .query(const Rect.fromLTWH(-10, -10, 200, 200))
            .toList();

        expect(results, containsAll(['a', 'b', 'c']));
        expect(results, isNot(contains('d')));
      });

      test('returns empty for region with no items', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 50, 50));

        final results = tree.query(const Rect.fromLTWH(500, 500, 100, 100));
        expect(results, isEmpty);
      });

      test('handles items overlapping multiple quadrants', () {
        // Item spanning multiple quadrants
        tree.insert('big', const Rect.fromLTWH(-100, -100, 200, 200));

        // Should be found when querying any overlapping region
        expect(
          tree.query(const Rect.fromLTWH(-50, -50, 10, 10)),
          contains('big'),
        );
        expect(
          tree.query(const Rect.fromLTWH(50, 50, 10, 10)),
          contains('big'),
        );
      });
    });

    group('hitTest', () {
      test('finds item containing point', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));
        tree.insert('b', const Rect.fromLTWH(200, 200, 100, 100));

        expect(tree.hitTest(const Offset(50, 50)), contains('a'));
        expect(tree.hitTest(const Offset(250, 250)), contains('b'));
      });

      test('returns empty for miss', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));

        expect(tree.hitTest(const Offset(500, 500)), isEmpty);
      });

      test('returns multiple overlapping items', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));
        tree.insert('b', const Rect.fromLTWH(50, 50, 100, 100));

        // Point (75, 75) is inside both
        final results = tree.hitTest(const Offset(75, 75)).toList();
        expect(results, containsAll(['a', 'b']));
      });
    });

    group('remove', () {
      test('removes item', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));
        tree.insert('b', const Rect.fromLTWH(200, 200, 100, 100));

        tree.remove('a');

        expect(tree.query(const Rect.fromLTWH(-10, -10, 150, 150)), isEmpty);
        expect(
          tree.query(const Rect.fromLTWH(150, 150, 200, 200)),
          contains('b'),
        );
      });

      test('handles removing non-existent item gracefully', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));

        // Should not throw
        tree.remove('non-existent');

        expect(tree.length, 1);
      });
    });

    group('update', () {
      test('updates item bounds', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));

        // Move item to new location
        tree.update('a', const Rect.fromLTWH(500, 500, 100, 100));

        // Should not be found at old location
        expect(tree.query(const Rect.fromLTWH(-10, -10, 150, 150)), isEmpty);

        // Should be found at new location
        expect(
          tree.query(const Rect.fromLTWH(450, 450, 200, 200)),
          contains('a'),
        );
      });
    });

    group('clear', () {
      test('removes all items', () {
        tree.insert('a', const Rect.fromLTWH(0, 0, 100, 100));
        tree.insert('b', const Rect.fromLTWH(200, 200, 100, 100));
        tree.insert('c', const Rect.fromLTWH(400, 400, 100, 100));

        tree.clear();

        expect(tree.length, 0);
        expect(
          tree.query(const Rect.fromLTWH(-1000, -1000, 2000, 2000)),
          isEmpty,
        );
      });
    });

    group('subdivision', () {
      test('subdivides when exceeding maxObjects', () {
        // Insert more than maxObjects (4)
        for (var i = 0; i < 10; i++) {
          tree.insert('item-$i', Rect.fromLTWH(i * 50.0, i * 50.0, 30, 30));
        }

        // All items should still be queryable after subdivision
        final results = tree
            .query(const Rect.fromLTWH(-100, -100, 1000, 1000))
            .toSet();
        expect(results.length, 10);

        // Each individual item should be findable
        for (var i = 0; i < 10; i++) {
          expect(results, contains('item-$i'));
        }
      });
    });

    group('edge cases', () {
      test('handles items at boundary', () {
        tree.insert('boundary', const Rect.fromLTWH(-1000, -1000, 100, 100));

        expect(
          tree.query(const Rect.fromLTWH(-1050, -1050, 200, 200)),
          contains('boundary'),
        );
      });

      test('handles zero-size items', () {
        tree.insert('point', const Rect.fromLTWH(100, 100, 0, 0));

        // Query should still find it
        expect(
          tree.query(const Rect.fromLTWH(99, 99, 2, 2)),
          contains('point'),
        );
      });
    });
  });
}
