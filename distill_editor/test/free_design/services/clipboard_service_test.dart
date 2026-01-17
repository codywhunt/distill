import 'dart:ui';

import 'package:distill_editor/src/free_design/free_design.dart';
import 'package:distill_editor/src/free_design/services/clipboard_payload.dart';
import 'package:distill_editor/src/free_design/services/clipboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClipboardService', () {
    late ClipboardService service;

    setUp(() {
      service = ClipboardService();
    });

    ClipboardPayload createTestPayload({String rootId = 'node_A'}) {
      return ClipboardPayload(
        rootIds: [rootId],
        nodes: [
          Node(
            id: rootId,
            type: NodeType.container,
            props: ContainerProps(),
          ),
        ],
        anchor: const Offset(100, 200),
      );
    }

    group('copy', () {
      test('stores payload to internal clipboard', () async {
        final payload = createTestPayload();

        await service.copy(payload);

        expect(service.getInternal(), payload);
      });

      test('sets lastOperation to copy', () async {
        final payload = createTestPayload();

        await service.copy(payload);

        expect(service.lastOperation, ClipboardOperation.copy);
      });

      test('hasContent returns true after copy', () async {
        final payload = createTestPayload();

        await service.copy(payload);

        expect(service.hasContent, isTrue);
      });
    });

    group('cut', () {
      test('stores payload to internal clipboard', () async {
        final payload = createTestPayload();

        await service.cut(payload);

        expect(service.getInternal(), payload);
      });

      test('sets lastOperation to cut', () async {
        final payload = createTestPayload();

        await service.cut(payload);

        expect(service.lastOperation, ClipboardOperation.cut);
      });
    });

    group('markDuplicate', () {
      test('sets lastOperation to duplicate', () {
        service.markDuplicate();

        expect(service.lastOperation, ClipboardOperation.duplicate);
      });

      test('does not clear internal clipboard', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        service.markDuplicate();

        expect(service.getInternal(), payload);
      });
    });

    group('getInternal', () {
      test('returns null initially', () {
        expect(service.getInternal(), isNull);
      });

      test('returns stored payload after copy', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        expect(service.getInternal(), payload);
      });

      test('returns most recent payload', () async {
        final payload1 = createTestPayload(rootId: 'node_1');
        final payload2 = createTestPayload(rootId: 'node_2');

        await service.copy(payload1);
        await service.copy(payload2);

        expect(service.getInternal()?.rootIds, ['node_2']);
      });
    });

    group('paste', () {
      test('returns internal clipboard after copy', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        final result = await service.paste();

        expect(result, payload);
      });

      test('returns internal clipboard after cut', () async {
        final payload = createTestPayload();
        await service.cut(payload);

        final result = await service.paste();

        expect(result, payload);
      });

      test('returns internal clipboard as fallback when no recent copy/cut', () async {
        final payload = createTestPayload();
        await service.copy(payload);
        service.markDuplicate(); // Clear the copy operation marker

        // paste() will try system clipboard first, then fall back to internal
        final result = await service.paste();

        // Since system clipboard is likely empty/invalid in test, should return internal
        expect(result, payload);
      });

      test('returns null when clipboard is empty', () async {
        final result = await service.paste();

        expect(result, isNull);
      });

      test('internal clipboard persists until overwritten', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        // Multiple pastes should work
        final result1 = await service.paste();
        final result2 = await service.paste();

        expect(result1, payload);
        expect(result2, payload);
      });
    });

    group('clear', () {
      test('clears internal clipboard', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        service.clear();

        expect(service.getInternal(), isNull);
        expect(service.hasContent, isFalse);
      });

      test('clears lastOperation', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        service.clear();

        expect(service.lastOperation, isNull);
      });
    });

    group('hasContent', () {
      test('returns false initially', () {
        expect(service.hasContent, isFalse);
      });

      test('returns true after copy', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        expect(service.hasContent, isTrue);
      });

      test('returns false after clear', () async {
        final payload = createTestPayload();
        await service.copy(payload);
        service.clear();

        expect(service.hasContent, isFalse);
      });
    });

    group('operation flow', () {
      test('copy then paste returns internal', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        final result = await service.paste();

        expect(result, payload);
        expect(service.lastOperation, ClipboardOperation.copy);
      });

      test('cut then paste returns internal', () async {
        final payload = createTestPayload();
        await service.cut(payload);

        final result = await service.paste();

        expect(result, payload);
        expect(service.lastOperation, ClipboardOperation.cut);
      });

      test('duplicate does not use system clipboard', () async {
        final payload = createTestPayload();
        await service.copy(payload);

        // Duplicate uses getInternal(), not paste()
        service.markDuplicate();
        final result = service.getInternal();

        expect(result, payload);
        expect(service.lastOperation, ClipboardOperation.duplicate);
      });
    });
  });
}
