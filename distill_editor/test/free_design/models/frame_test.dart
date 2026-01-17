import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('Frame', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'f_test',
        name: 'Test Frame',
        rootNodeId: 'n_root',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      expect(frame.id, 'f_test');
      expect(frame.name, 'Test Frame');
      expect(frame.rootNodeId, 'n_root');
      expect(frame.canvas.position, Offset.zero);
      expect(frame.canvas.size, const Size(375, 812));
    });

    test('JSON round-trip preserves data', () {
      final createdAt = DateTime(2024, 1, 15, 10, 30);
      final updatedAt = DateTime(2024, 1, 15, 14, 45);
      final frame = Frame(
        id: 'f_phone',
        name: 'iPhone 15 Pro',
        rootNodeId: 'n_phone_root',
        canvas: const CanvasPlacement(
          position: Offset(100, 200),
          size: Size(393, 852),
        ),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = frame.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = Frame.fromJson(decoded);

      expect(restored.id, frame.id);
      expect(restored.name, frame.name);
      expect(restored.rootNodeId, frame.rootNodeId);
      expect(restored.canvas.position.dx, 100);
      expect(restored.canvas.position.dy, 200);
      expect(restored.canvas.size.width, 393);
      expect(restored.canvas.size.height, 852);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
    });

    test('copyWith creates modified copy', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'f_test',
        name: 'Original',
        rootNodeId: 'n_root',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      final modified = frame.copyWith(name: 'Modified');

      expect(modified.name, 'Modified');
      expect(modified.id, frame.id);
      expect(frame.name, 'Original'); // Original unchanged
    });
  });

  group('CanvasPlacement', () {
    test('JSON round-trip', () {
      const canvas = CanvasPlacement(
        position: Offset(50, 100),
        size: Size(400, 600),
      );

      final json = canvas.toJson();
      final restored = CanvasPlacement.fromJson(json);

      expect(restored.position.dx, 50);
      expect(restored.position.dy, 100);
      expect(restored.size.width, 400);
      expect(restored.size.height, 600);
    });

    test('copyWith modifies position', () {
      const canvas = CanvasPlacement(
        position: Offset(10, 20),
        size: Size(100, 200),
      );

      final modified = canvas.copyWith(position: const Offset(30, 40));

      expect(modified.position, const Offset(30, 40));
      expect(modified.size, canvas.size); // Size unchanged
    });

    test('bounds returns correct rect', () {
      const canvas = CanvasPlacement(
        position: Offset(10, 20),
        size: Size(100, 200),
      );

      expect(canvas.bounds, const Rect.fromLTWH(10, 20, 100, 200));
    });
  });
}
