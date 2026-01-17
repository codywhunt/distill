import 'dart:ui';

import 'package:distill_editor/src/free_design/free_design.dart';
import 'package:distill_editor/src/free_design/services/clipboard_payload.dart';
import 'package:distill_editor/src/free_design/services/clipboard_service.dart';
import 'package:distill_editor/src/free_design/services/node_remapper.dart';
import 'package:distill_editor/src/free_design/services/selection_roots.dart';
import 'package:distill_editor/src/free_design/store/editor_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration tests for copy/paste functionality.
///
/// Tests the full flow from selection to clipboard to paste,
/// using internal clipboard only (no system clipboard dependency).
void main() {
  group('Copy/Paste Integration', () {
    late EditorDocumentStore store;
    late ClipboardService clipboardService;
    late String frameId;
    late String rootNodeId;

    setUp(() {
      store = EditorDocumentStore.empty();
      clipboardService = ClipboardService();

      // Create a frame with a root node
      store.createEmptyFrame(
        position: const Offset(0, 0),
        size: const Size(375, 812),
        name: 'Test Frame',
      );

      frameId = store.document.frames.keys.first;
      rootNodeId = store.document.frames[frameId]!.rootNodeId;
    });

    Node createTestNode(
      String id, {
      List<String> childIds = const [],
      double x = 0,
      double y = 0,
    }) {
      return Node(
        id: id,
        name: 'Test $id',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          position: PositionModeAbsolute(x: x, y: y),
          size: SizeMode.fixed(100, 50),
        ),
        childIds: childIds,
      );
    }

    /// Helper to simulate the copy operation.
    ClipboardPayload? buildPayload(Set<DragTarget> selection) {
      if (!canCopy(selection)) return null;

      final document = store.document;
      final parentIndex = store.parentIndex;

      final rootIds = getTopLevelRoots(
        selection: selection,
        parentIndex: parentIndex,
        frames: document.frames,
        nodes: document.nodes,
      );

      if (rootIds.isEmpty) return null;

      final nodes = collectSubtree(rootIds, document.nodes);
      final anchor = computeAnchor(rootIds, document.nodes);

      return ClipboardPayload(
        sourceDocumentId: document.documentId,
        sourceFrameId: frameId,
        rootIds: rootIds,
        nodes: nodes,
        anchor: anchor,
      );
    }

    /// Helper to execute paste operation.
    List<String> executePaste(
      ClipboardPayload payload, {
      required String targetParentId,
      Offset offset = Offset.zero,
      int index = -1,
      bool isDuplicate = false,
    }) {
      final remapper = NodeRemapper();
      var remappedNodes = remapper.remapNodes(payload.nodes);
      final remappedRootIds = remapper.remapRootIds(payload.rootIds);

      // Apply offset to positioned roots
      if (offset != Offset.zero) {
        final rootIdSet = remappedRootIds.toSet();
        remappedNodes = remappedNodes.map((node) {
          if (!rootIdSet.contains(node.id)) return node;
          if (!node.layout.isPositioned) return node;

          return node.copyWith(
            layout: node.layout.copyWith(
              position: PositionModeAbsolute(
                x: (node.layout.x ?? 0) + offset.dx,
                y: (node.layout.y ?? 0) + offset.dy,
              ),
            ),
          );
        }).toList();
      }

      return store.executePaste(
        nodes: remappedNodes,
        rootIds: remappedRootIds,
        targetParentId: targetParentId,
        index: index,
        label: isDuplicate ? 'Duplicate' : 'Paste',
      );
    }

    group('Copy scenarios', () {
      test('copy single node', () {
        // Add a node
        final node = createTestNode('node_A', x: 50, y: 100);
        store.addNode(node, parentId: rootNodeId);

        // Create selection
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };

        // Build payload
        final payload = buildPayload(selection);

        expect(payload, isNotNull);
        expect(payload!.rootIds, ['node_A']);
        expect(payload.nodes.length, 1);
        expect(payload.anchor, const Offset(50, 100));
      });

      test('copy node with children (subtree)', () {
        // Add parent with child
        final child = createTestNode('node_child', x: 10, y: 20);
        final parent = createTestNode('node_parent', childIds: ['node_child'], x: 50, y: 100);
        store.addNode(parent, parentId: rootNodeId);
        store.addNode(child, parentId: 'node_parent');

        // Select only parent
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_parent', patchTarget: 'node_parent'),
        };

        final payload = buildPayload(selection);

        expect(payload, isNotNull);
        expect(payload!.rootIds, ['node_parent']);
        expect(payload.nodes.length, 2); // Parent + child
        expect(payload.nodes.map((n) => n.id), containsAll(['node_parent', 'node_child']));
      });

      test('copy multiple selected nodes (deterministic order)', () {
        // Add multiple nodes at different positions
        final nodeA = createTestNode('node_A', x: 100, y: 200);
        final nodeB = createTestNode('node_B', x: 50, y: 100); // Higher and left
        final nodeC = createTestNode('node_C', x: 50, y: 200); // Same y as A, left

        store.addNode(nodeA, parentId: rootNodeId);
        store.addNode(nodeB, parentId: rootNodeId);
        store.addNode(nodeC, parentId: rootNodeId);

        // Select all
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
          NodeTarget(frameId: frameId, expandedId: 'node_B', patchTarget: 'node_B'),
          NodeTarget(frameId: frameId, expandedId: 'node_C', patchTarget: 'node_C'),
        };

        final payload = buildPayload(selection);

        expect(payload, isNotNull);
        // Sorted by y, then x: B (100,50), C (200,50), A (200,100)
        expect(payload!.rootIds, ['node_B', 'node_C', 'node_A']);
      });

      test('copy with parent+child selected returns only parent', () {
        // Add parent with child
        final child = createTestNode('node_child');
        final parent = createTestNode('node_parent', childIds: ['node_child']);
        store.addNode(parent, parentId: rootNodeId);
        store.addNode(child, parentId: 'node_parent');

        // Select both parent and child
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_parent', patchTarget: 'node_parent'),
          NodeTarget(frameId: frameId, expandedId: 'node_child', patchTarget: 'node_child'),
        };

        final payload = buildPayload(selection);

        expect(payload, isNotNull);
        // Only parent is a root (child's parent is selected)
        expect(payload!.rootIds, ['node_parent']);
        // But subtree still includes child
        expect(payload.nodes.length, 2);
      });

      test('cannot copy instance children (patchTarget == null)', () {
        // Instance children have null patchTarget
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'instance_child', patchTarget: null),
        };

        final payload = buildPayload(selection);

        expect(payload, isNull);
      });

      test('copy frame target copies root node', () {
        final selection = <DragTarget>{
          FrameTarget(frameId),
        };

        final payload = buildPayload(selection);

        expect(payload, isNotNull);
        expect(payload!.rootIds, [rootNodeId]);
      });
    });

    group('Paste scenarios', () {
      test('paste into selected node', () {
        // Add target node
        final target = createTestNode('target_node');
        store.addNode(target, parentId: rootNodeId);

        // Create payload with a node
        final sourceNode = createTestNode('source_node', x: 10, y: 20);
        final payload = ClipboardPayload(
          rootIds: ['source_node'],
          nodes: [sourceNode],
          anchor: const Offset(10, 20),
        );

        // Paste into target
        final newIds = executePaste(payload, targetParentId: 'target_node');

        expect(newIds.length, 1);
        expect(store.document.nodes.containsKey(newIds.first), isTrue);

        // Verify it's a child of target
        final targetNode = store.document.nodes['target_node']!;
        expect(targetNode.childIds, contains(newIds.first));
      });

      test('paste into frame root (no node selected)', () {
        final sourceNode = createTestNode('source_node');
        final payload = ClipboardPayload(
          rootIds: ['source_node'],
          nodes: [sourceNode],
          anchor: Offset.zero,
        );

        final newIds = executePaste(payload, targetParentId: rootNodeId);

        final root = store.document.nodes[rootNodeId]!;
        expect(root.childIds, contains(newIds.first));
      });

      test('paste at cursor position (positioned nodes)', () {
        final sourceNode = createTestNode('source_node', x: 100, y: 200);
        final payload = ClipboardPayload(
          rootIds: ['source_node'],
          nodes: [sourceNode],
          anchor: const Offset(100, 200),
        );

        // Paste with offset (simulating cursor at 300, 400)
        final cursorOffset = const Offset(300, 400) - payload.anchor;
        final newIds = executePaste(
          payload,
          targetParentId: rootNodeId,
          offset: cursorOffset,
        );

        final pastedNode = store.document.nodes[newIds.first]!;
        expect(pastedNode.layout.x, 300);
        expect(pastedNode.layout.y, 400);
      });

      test('paste preserves relative positions (multi-select)', () {
        // Two nodes with different positions
        final nodeA = createTestNode('node_A', x: 100, y: 100);
        final nodeB = createTestNode('node_B', x: 200, y: 150);

        final payload = ClipboardPayload(
          rootIds: ['node_A', 'node_B'],
          nodes: [nodeA, nodeB],
          anchor: const Offset(100, 100), // anchor at node_A
        );

        // Paste with offset
        final offset = const Offset(50, 50);
        final newIds = executePaste(
          payload,
          targetParentId: rootNodeId,
          offset: offset,
        );

        // Both nodes should be offset by same amount
        final pastedA = store.document.nodes[newIds[0]]!;
        final pastedB = store.document.nodes[newIds[1]]!;

        expect(pastedA.layout.x, 150); // 100 + 50
        expect(pastedA.layout.y, 150); // 100 + 50
        expect(pastedB.layout.x, 250); // 200 + 50
        expect(pastedB.layout.y, 200); // 150 + 50
      });

      test('cross-frame paste works', () {
        // Create second frame
        store.createEmptyFrame(
          position: const Offset(400, 0),
          size: const Size(375, 812),
          name: 'Frame 2',
        );

        final frame2Id = store.document.frames.keys.firstWhere((id) => id != frameId);
        final frame2RootId = store.document.frames[frame2Id]!.rootNodeId;

        // Add node to first frame
        final sourceNode = createTestNode('source_node');
        store.addNode(sourceNode, parentId: rootNodeId);

        // Copy from first frame
        final payload = ClipboardPayload(
          sourceFrameId: frameId,
          rootIds: ['source_node'],
          nodes: [sourceNode],
          anchor: Offset.zero,
        );

        // Paste to second frame
        final newIds = executePaste(payload, targetParentId: frame2RootId);

        // Verify pasted to second frame
        final frame2Root = store.document.nodes[frame2RootId]!;
        expect(frame2Root.childIds, contains(newIds.first));
      });

      test('paste subtree maintains parent-child relationships', () {
        final child = createTestNode('child_node');
        final parent = createTestNode('parent_node', childIds: ['child_node']);

        final payload = ClipboardPayload(
          rootIds: ['parent_node'],
          nodes: [parent, child],
          anchor: Offset.zero,
        );

        final newIds = executePaste(payload, targetParentId: rootNodeId);

        // newIds contains only roots
        expect(newIds.length, 1);

        // But the pasted parent should have a child
        final pastedParent = store.document.nodes[newIds.first]!;
        expect(pastedParent.childIds.length, 1);

        // And that child should exist
        final pastedChildId = pastedParent.childIds.first;
        expect(store.document.nodes.containsKey(pastedChildId), isTrue);
      });
    });

    group('Cut scenarios', () {
      test('cut removes original nodes', () {
        final node = createTestNode('node_A');
        store.addNode(node, parentId: rootNodeId);

        // Simulate cut: copy then delete
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };
        final payload = buildPayload(selection);
        clipboardService.cut(payload!);

        // Delete original
        store.removeNode('node_A');

        expect(store.document.nodes.containsKey('node_A'), isFalse);
        expect(clipboardService.hasContent, isTrue);
      });

      test('cut + paste = move operation', () {
        final node = createTestNode('node_A', x: 50, y: 50);
        store.addNode(node, parentId: rootNodeId);

        // Cut
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };
        final payload = buildPayload(selection);
        clipboardService.cut(payload!);
        store.removeNode('node_A');

        // Verify original gone
        expect(store.document.nodes.containsKey('node_A'), isFalse);

        // Paste
        final newIds = executePaste(payload, targetParentId: rootNodeId);

        // Verify new node exists
        expect(newIds.length, 1);
        expect(store.document.nodes.containsKey(newIds.first), isTrue);
      });

      test('undo cut restores nodes', () {
        final node = createTestNode('node_A');
        store.addNode(node, parentId: rootNodeId);

        // Record initial state
        final initialNodeCount = store.document.nodes.length;

        // Cut (delete)
        store.removeNode('node_A');
        expect(store.document.nodes.containsKey('node_A'), isFalse);

        // Undo
        store.undo();
        expect(store.document.nodes.containsKey('node_A'), isTrue);
        expect(store.document.nodes.length, initialNodeCount);
      });
    });

    group('Duplicate scenarios', () {
      test('duplicate creates offset copy (positioned nodes)', () {
        final node = createTestNode('node_A', x: 100, y: 100);
        store.addNode(node, parentId: rootNodeId);

        // Build payload
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };
        final payload = buildPayload(selection);

        // Duplicate with offset
        final duplicateOffset = const Offset(20, 20);
        final newIds = executePaste(
          payload!,
          targetParentId: rootNodeId,
          offset: duplicateOffset,
          isDuplicate: true,
        );

        // Original still exists
        expect(store.document.nodes.containsKey('node_A'), isTrue);

        // Duplicate exists with offset
        final duplicated = store.document.nodes[newIds.first]!;
        expect(duplicated.layout.x, 120); // 100 + 20
        expect(duplicated.layout.y, 120); // 100 + 20
      });

      test('duplicate is synchronous', () {
        final node = createTestNode('node_A');
        store.addNode(node, parentId: rootNodeId);

        // Build payload (synchronous)
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };
        final payload = buildPayload(selection);

        // Execute paste (synchronous)
        final newIds = executePaste(
          payload!,
          targetParentId: rootNodeId,
          isDuplicate: true,
        );

        // Immediately available
        expect(newIds.length, 1);
        expect(store.document.nodes.containsKey(newIds.first), isTrue);
      });

      test('duplicate creates sibling not child', () {
        // Add a node as child of root
        final node = createTestNode('node_A');
        store.addNode(node, parentId: rootNodeId);

        // Build payload
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };
        final payload = buildPayload(selection);

        // For duplicate, target should be the PARENT of the original (rootNodeId)
        // not the node itself
        final originalParent = store.getParent('node_A');
        expect(originalParent, rootNodeId);

        // Execute paste as sibling (same parent as original)
        final newIds = executePaste(
          payload!,
          targetParentId: originalParent!,
          isDuplicate: true,
        );

        // Duplicate should be sibling of original (same parent)
        final duplicateParent = store.getParent(newIds.first);
        expect(duplicateParent, rootNodeId);

        // Original should NOT have the duplicate as a child
        final originalNode = store.document.nodes['node_A']!;
        expect(originalNode.childIds, isNot(contains(newIds.first)));

        // Root should have both original and duplicate as children
        final root = store.document.nodes[rootNodeId]!;
        expect(root.childIds, contains('node_A'));
        expect(root.childIds, contains(newIds.first));
      });

      test('duplicate inserts directly after original node', () {
        // Add multiple nodes as children of root
        final nodeA = createTestNode('node_A');
        final nodeB = createTestNode('node_B');
        final nodeC = createTestNode('node_C');
        store.addNode(nodeA, parentId: rootNodeId);
        store.addNode(nodeB, parentId: rootNodeId);
        store.addNode(nodeC, parentId: rootNodeId);

        // Verify initial order: A, B, C
        var root = store.document.nodes[rootNodeId]!;
        expect(root.childIds, ['node_A', 'node_B', 'node_C']);

        // Build payload for node_B
        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_B', patchTarget: 'node_B'),
        };
        final payload = buildPayload(selection);

        // Find index of B and insert after it
        final parentNode = store.document.nodes[rootNodeId]!;
        final originalIndex = parentNode.childIds.indexOf('node_B');
        final insertIndex = originalIndex + 1;

        // Execute paste at the correct index
        final newIds = executePaste(
          payload!,
          targetParentId: rootNodeId,
          index: insertIndex,
          isDuplicate: true,
        );

        // Verify order: A, B, duplicate, C
        root = store.document.nodes[rootNodeId]!;
        expect(root.childIds[0], 'node_A');
        expect(root.childIds[1], 'node_B');
        expect(root.childIds[2], newIds.first); // Duplicate inserted after B
        expect(root.childIds[3], 'node_C');
      });

      test('multiple duplicates create unique IDs', () {
        final node = createTestNode('node_A');
        store.addNode(node, parentId: rootNodeId);

        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };
        final payload = buildPayload(selection);

        // Duplicate twice
        final ids1 = executePaste(payload!, targetParentId: rootNodeId, isDuplicate: true);
        final ids2 = executePaste(payload, targetParentId: rootNodeId, isDuplicate: true);

        // Different IDs
        expect(ids1.first, isNot(equals(ids2.first)));

        // Both exist
        expect(store.document.nodes.containsKey(ids1.first), isTrue);
        expect(store.document.nodes.containsKey(ids2.first), isTrue);
      });
    });

    group('Edge cases', () {
      test('empty selection returns no-op', () {
        final selection = <DragTarget>{};
        final payload = buildPayload(selection);

        expect(payload, isNull);
      });

      test('paste with empty clipboard is no-op', () {
        final emptyPayload = ClipboardPayload(
          rootIds: [],
          nodes: [],
          anchor: Offset.zero,
        );

        expect(emptyPayload.isEmpty, isTrue);
      });

      test('undo paste removes all pasted nodes', () {
        final parent = createTestNode('parent', childIds: ['child']);
        final child = createTestNode('child');

        final payload = ClipboardPayload(
          rootIds: ['parent'],
          nodes: [parent, child],
          anchor: Offset.zero,
        );

        final initialNodeCount = store.document.nodes.length;

        final newIds = executePaste(payload, targetParentId: rootNodeId);
        expect(store.document.nodes.length, initialNodeCount + 2);

        store.undo();
        expect(store.document.nodes.length, initialNodeCount);
        expect(store.document.nodes.containsKey(newIds.first), isFalse);
      });

      test('paste non-positioned node (auto-layout child) does not translate', () {
        // Create a node with auto layout (no absolute position)
        final autoNode = Node(
          id: 'auto_node',
          name: 'Auto Node',
          type: NodeType.container,
          props: ContainerProps(),
          layout: NodeLayout(
            position: const PositionModeAuto(),
            size: SizeMode.fixed(100, 50),
          ),
        );

        final payload = ClipboardPayload(
          rootIds: ['auto_node'],
          nodes: [autoNode],
          anchor: Offset.zero,
        );

        // Try to paste with offset
        final offset = const Offset(100, 100);
        final newIds = executePaste(
          payload,
          targetParentId: rootNodeId,
          offset: offset,
        );

        final pastedNode = store.document.nodes[newIds.first]!;
        // Auto-layout node should not have position applied
        expect(pastedNode.layout.isPositioned, isFalse);
      });
    });

    group('Clipboard service integration', () {
      test('copy stores to internal clipboard', () async {
        final node = createTestNode('node_A');
        store.addNode(node, parentId: rootNodeId);

        final selection = <DragTarget>{
          NodeTarget(frameId: frameId, expandedId: 'node_A', patchTarget: 'node_A'),
        };
        final payload = buildPayload(selection);

        await clipboardService.copy(payload!);

        expect(clipboardService.hasContent, isTrue);
        expect(clipboardService.getInternal(), isNotNull);
      });

      test('paste returns internal clipboard after copy', () async {
        final node = createTestNode('node_A');
        final payload = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [node],
          anchor: Offset.zero,
        );

        await clipboardService.copy(payload);

        final pastePayload = await clipboardService.paste();

        expect(pastePayload, isNotNull);
        expect(pastePayload!.rootIds, payload.rootIds);
      });

      test('cut then paste returns internal clipboard', () async {
        final node = createTestNode('node_A');
        final payload = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [node],
          anchor: Offset.zero,
        );

        await clipboardService.cut(payload);

        final pastePayload = await clipboardService.paste();

        expect(pastePayload, isNotNull);
        expect(pastePayload!.rootIds, payload.rootIds);
      });

      test('getInternal returns synchronously for duplicate', () {
        final node = createTestNode('node_A');
        final payload = ClipboardPayload(
          rootIds: ['node_A'],
          nodes: [node],
          anchor: Offset.zero,
        );

        clipboardService.copy(payload);

        // Synchronous access
        final internal = clipboardService.getInternal();
        expect(internal, isNotNull);
        expect(internal!.rootIds, payload.rootIds);
      });
    });
  });
}
