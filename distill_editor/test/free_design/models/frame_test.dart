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

  group('Frame Kind', () {
    test('design frame has FrameKind.design', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'f_test',
        name: 'Test Frame',
        rootNodeId: 'n_root',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        kind: FrameKind.design,
        componentId: null,
        createdAt: now,
        updatedAt: now,
      );

      expect(frame.kind, FrameKind.design);
      expect(frame.componentId, isNull);
    });

    test('component frame has FrameKind.component', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'f_comp',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        canvas: const CanvasPlacement(
          position: Offset(100, 200),
          size: Size(200, 50),
        ),
        kind: FrameKind.component,
        componentId: 'comp_button',
        createdAt: now,
        updatedAt: now,
      );

      expect(frame.kind, FrameKind.component);
      expect(frame.componentId, 'comp_button');
    });

    test('JSON round-trip preserves kind and componentId', () {
      final createdAt = DateTime(2024, 1, 15, 10, 30);
      final updatedAt = DateTime(2024, 1, 15, 14, 45);
      final frame = Frame(
        id: 'f_comp',
        name: 'Button Component',
        rootNodeId: 'comp_button::btn_root',
        canvas: const CanvasPlacement(
          position: Offset(50, 100),
          size: Size(200, 50),
        ),
        kind: FrameKind.component,
        componentId: 'comp_button',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = frame.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = Frame.fromJson(decoded);

      expect(restored.kind, FrameKind.component);
      expect(restored.componentId, 'comp_button');
    });

    test('copyWith works with kind and componentId', () {
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

      expect(frame.kind, FrameKind.design);
      expect(frame.componentId, isNull);

      final modified = frame.copyWith(
        kind: FrameKind.component,
        componentId: 'comp_button',
      );

      expect(modified.kind, FrameKind.component);
      expect(modified.componentId, 'comp_button');
      expect(frame.kind, FrameKind.design); // Original unchanged
    });

    test('JSON without kind field defaults to design', () {
      final json = {
        'id': 'f_test',
        'name': 'Test',
        'rootNodeId': 'n_root',
        'canvas': {
          'position': {'x': 0.0, 'y': 0.0},
          'size': {'width': 375.0, 'height': 812.0},
        },
        'createdAt': '2024-01-15T10:30:00.000',
        'updatedAt': '2024-01-15T10:30:00.000',
        // No 'kind' or 'componentId' fields
      };

      final frame = Frame.fromJson(json);
      expect(frame.kind, FrameKind.design);
      expect(frame.componentId, isNull);
    });

    test('kind defaults to design when not specified in constructor', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'f_test',
        name: 'Test',
        rootNodeId: 'n_root',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      expect(frame.kind, FrameKind.design);
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
