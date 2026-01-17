import 'dart:convert';
import 'dart:ui';

import 'package:distill_editor/src/free_design/free_design.dart';
import 'package:distill_editor/src/free_design/services/clipboard_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClipboardPayload', () {
    Node createTestNode(String id, {List<String> childIds = const []}) {
      return Node(
        id: id,
        name: 'Test $id',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          position: const PositionModeAbsolute(x: 100, y: 200),
        ),
        childIds: childIds,
      );
    }

    test('creates with required fields', () {
      final payload = ClipboardPayload(
        rootIds: ['node_A'],
        nodes: [createTestNode('node_A')],
        anchor: const Offset(100, 200),
      );

      expect(payload.type, ClipboardPayload.payloadType);
      expect(payload.version, ClipboardPayload.currentVersion);
      expect(payload.rootIds, ['node_A']);
      expect(payload.nodes.length, 1);
      expect(payload.anchor, const Offset(100, 200));
      expect(payload.sourceDocumentId, isNull);
      expect(payload.sourceFrameId, isNull);
    });

    test('creates with optional source fields', () {
      final payload = ClipboardPayload(
        sourceDocumentId: 'doc_123',
        sourceFrameId: 'frame_456',
        rootIds: ['node_A'],
        nodes: [createTestNode('node_A')],
        anchor: const Offset(0, 0),
      );

      expect(payload.sourceDocumentId, 'doc_123');
      expect(payload.sourceFrameId, 'frame_456');
    });

    group('JSON serialization', () {
      test('type field is distill_clipboard', () {
        final payload = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(0, 0),
        );

        final json = payload.toJson();
        expect(json['type'], 'distill_clipboard');
      });

      test('anchor serializes as {x, y} object', () {
        final payload = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(120, 80),
        );

        final json = payload.toJson();
        expect(json['anchor'], {'x': 120.0, 'y': 80.0});
      });

      test('round-trip preserves all data', () {
        final original = ClipboardPayload(
          sourceDocumentId: 'doc_123',
          sourceFrameId: 'frame_456',
          rootIds: ['node_A', 'node_B'],
          nodes: [
            createTestNode('node_A', childIds: ['node_A_child']),
            createTestNode('node_A_child'),
            createTestNode('node_B'),
          ],
          anchor: const Offset(50, 75),
        );

        final jsonString = original.toJsonString();
        final restored = ClipboardPayload.tryFromJson(jsonString);

        expect(restored, isNotNull);
        expect(restored!.type, original.type);
        expect(restored.version, original.version);
        expect(restored.sourceDocumentId, original.sourceDocumentId);
        expect(restored.sourceFrameId, original.sourceFrameId);
        expect(restored.rootIds, original.rootIds);
        expect(restored.nodes.length, original.nodes.length);
        expect(restored.anchor, original.anchor);
      });

      test('version field is preserved', () {
        final payload = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(0, 0),
        );

        final json = payload.toJson();
        expect(json['version'], ClipboardPayload.currentVersion);

        final restored = ClipboardPayload.fromJson(json);
        expect(restored.version, ClipboardPayload.currentVersion);
      });

      test('source field is optional in JSON', () {
        final payloadWithSource = ClipboardPayload(
          sourceDocumentId: 'doc_123',
          rootIds: ['node_A'],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(0, 0),
        );

        final jsonWithSource = payloadWithSource.toJson();
        expect(jsonWithSource.containsKey('source'), isTrue);

        final payloadWithoutSource = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(0, 0),
        );

        final jsonWithoutSource = payloadWithoutSource.toJson();
        expect(jsonWithoutSource.containsKey('source'), isFalse);
      });
    });

    group('tryFromJson', () {
      test('returns null for invalid JSON', () {
        expect(ClipboardPayload.tryFromJson('not json'), isNull);
        expect(ClipboardPayload.tryFromJson('{invalid}'), isNull);
      });

      test('returns null for non-object JSON', () {
        expect(ClipboardPayload.tryFromJson('"string"'), isNull);
        expect(ClipboardPayload.tryFromJson('123'), isNull);
        expect(ClipboardPayload.tryFromJson('[]'), isNull);
      });

      test('returns null for non-distill clipboard data', () {
        final otherJson = jsonEncode({
          'type': 'something_else',
          'data': 'some data',
        });
        expect(ClipboardPayload.tryFromJson(otherJson), isNull);
      });

      test('returns null for missing type field', () {
        final noType = jsonEncode({
          'version': 1,
          'rootIds': ['node_A'],
          'nodes': [],
          'anchor': {'x': 0, 'y': 0},
        });
        expect(ClipboardPayload.tryFromJson(noType), isNull);
      });

      test('returns null for missing anchor field', () {
        final noAnchor = jsonEncode({
          'type': 'distill_clipboard',
          'version': 1,
          'rootIds': ['node_A'],
          'nodes': [],
        });
        expect(ClipboardPayload.tryFromJson(noAnchor), isNull);
      });

      test('returns null for invalid version', () {
        final invalidVersion = jsonEncode({
          'type': 'distill_clipboard',
          'version': 0,
          'rootIds': [],
          'nodes': [],
          'anchor': {'x': 0, 'y': 0},
        });
        expect(ClipboardPayload.tryFromJson(invalidVersion), isNull);
      });

      test('parses valid distill clipboard data', () {
        final validJson = jsonEncode({
          'type': 'distill_clipboard',
          'version': 1,
          'rootIds': ['node_A'],
          'nodes': [
            {
              'id': 'node_A',
              'type': 'container',
              'props': {},
            }
          ],
          'anchor': {'x': 10, 'y': 20},
        });

        final payload = ClipboardPayload.tryFromJson(validJson);
        expect(payload, isNotNull);
        expect(payload!.rootIds, ['node_A']);
        expect(payload.anchor, const Offset(10, 20));
      });
    });

    group('isEmpty / isNotEmpty', () {
      test('isEmpty returns true for empty payload', () {
        final emptyNodes = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [],
          anchor: const Offset(0, 0),
        );
        expect(emptyNodes.isEmpty, isTrue);
        expect(emptyNodes.isNotEmpty, isFalse);

        final emptyRoots = ClipboardPayload(
          rootIds: [],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(0, 0),
        );
        expect(emptyRoots.isEmpty, isTrue);
      });

      test('isNotEmpty returns true for valid payload', () {
        final payload = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(0, 0),
        );
        expect(payload.isEmpty, isFalse);
        expect(payload.isNotEmpty, isTrue);
      });
    });

    group('equality', () {
      test('equal payloads are equal', () {
        final node = createTestNode('node_A');
        final payload1 = ClipboardPayload(
          sourceDocumentId: 'doc_123',
          rootIds: ['node_A'],
          nodes: [node],
          anchor: const Offset(10, 20),
        );
        final payload2 = ClipboardPayload(
          sourceDocumentId: 'doc_123',
          rootIds: ['node_A'],
          nodes: [node],
          anchor: const Offset(10, 20),
        );

        expect(payload1, equals(payload2));
        expect(payload1.hashCode, equals(payload2.hashCode));
      });

      test('different payloads are not equal', () {
        final payload1 = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [createTestNode('node_A')],
          anchor: const Offset(10, 20),
        );
        final payload2 = ClipboardPayload(
          rootIds: ['node_B'],
          nodes: [createTestNode('node_B')],
          anchor: const Offset(10, 20),
        );

        expect(payload1, isNot(equals(payload2)));
      });
    });
  });
}
