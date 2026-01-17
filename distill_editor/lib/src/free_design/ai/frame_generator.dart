import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui';

import '../models/editor_document.dart';
import '../models/frame.dart';
import '../models/node.dart';
import 'llm_client.dart';
import 'prompts/frame_generation_prompt.dart';
import 'prompts/update_prompt.dart';

void _log(String message) {
  developer.log(message, name: 'FreeDesignAI');
  // ignore: avoid_print
  print('[FreeDesignAI] $message');
}

/// Result of AI frame generation.
class FrameGenerationResult {
  /// The generated frame.
  final Frame frame;

  /// All nodes in the frame (keyed by node ID).
  final Map<String, Node> nodes;

  const FrameGenerationResult({
    required this.frame,
    required this.nodes,
  });
}

/// Generates frames from natural language descriptions using an LLM.
class FrameGenerator {
  final LlmClient _client;

  FrameGenerator(this._client);

  /// Generate a frame from a natural language description.
  ///
  /// [prompt] - The user's description of the UI to create.
  /// [document] - The current document (for context like existing frame names).
  /// [position] - Where to place the frame on the canvas.
  /// [size] - The size of the frame (defaults to iPhone-ish dimensions).
  Future<FrameGenerationResult> generate({
    required String prompt,
    required EditorDocument document,
    Offset position = Offset.zero,
    Size size = const Size(375, 812),
  }) async {
    final systemPrompt = FrameGenerationPrompt.build(
      existingFrameNames: document.frames.values.map((f) => f.name).toList(),
      width: size.width,
      height: size.height,
      x: position.dx,
      y: position.dy,
    );

    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('FRAME GENERATION REQUEST');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('User prompt: $prompt');
    _log('Frame size: ${size.width}x${size.height}');
    _log('Position: (${position.dx}, ${position.dy})');
    _log('Existing frames: ${document.frames.values.map((f) => f.name).join(', ')}');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('Sending request to LLM...');

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.complete(
        system: systemPrompt,
        user: prompt,
        maxTokens: 32768,
        temperature: 0.3,
      );

      stopwatch.stop();
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('LLM RESPONSE (${stopwatch.elapsedMilliseconds}ms)');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log(response);
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final result = _parseResponse(response, position: position, size: size);
      _log('Successfully parsed: Frame "${result.frame.name}" with ${result.nodes.length} nodes');

      return result;
    } catch (e) {
      stopwatch.stop();
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('ERROR (${stopwatch.elapsedMilliseconds}ms): $e');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      rethrow;
    }
  }

  /// Parse the LLM response into a FrameGenerationResult.
  ///
  /// [position] and [size] override the LLM's canvas placement to ensure
  /// the frame appears exactly where requested.
  FrameGenerationResult _parseResponse(
    String response, {
    required Offset position,
    required Size size,
  }) {
    // Extract JSON from ```json blocks
    final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(response);
    final jsonStr = jsonMatch?.group(1) ?? response;

    // Check for truncation - if JSON block wasn't closed or ends mid-object
    final hasClosingBlock = response.contains('```json') &&
        RegExp(r'```json[\s\S]*```').hasMatch(response);
    if (!hasClosingBlock && response.contains('```json')) {
      throw LlmException(
        'Response was truncated - the AI output exceeded its limit. '
        'Try a simpler request or select fewer elements to update.',
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      // Provide more helpful error for truncation
      if (jsonStr.contains('{') && !jsonStr.trimRight().endsWith('}')) {
        throw LlmException(
          'Response was truncated - the AI output exceeded its limit. '
          'Try a simpler request or select fewer elements to update.',
        );
      }
      throw LlmException(
        'Failed to parse LLM response as JSON: $e\nResponse: $response',
      );
    }

    // Validate required fields
    if (!json.containsKey('frame')) {
      throw LlmException(
        'Invalid response: missing "frame" object\nResponse: $response',
      );
    }
    if (!json.containsKey('nodes')) {
      throw LlmException(
        'Invalid response: missing "nodes" object\nResponse: $response',
      );
    }

    final frameJson = json['frame'] as Map<String, dynamic>;
    final nodesJson = json['nodes'] as Map<String, dynamic>;

    // Validate rootNodeId
    final rootNodeId = frameJson['rootNodeId'] as String?;
    if (rootNodeId == null) {
      throw LlmException(
        'Invalid response: frame missing rootNodeId\nResponse: $response',
      );
    }
    if (!nodesJson.containsKey(rootNodeId)) {
      throw LlmException(
        'Invalid response: rootNodeId "$rootNodeId" not found in nodes\nResponse: $response',
      );
    }

    // Parse frame - use the requested position/size, not LLM's
    final now = DateTime.now();
    final frame = Frame(
      id: frameJson['id'] as String? ?? _generateId('frame'),
      name: frameJson['name'] as String? ?? 'Generated Frame',
      rootNodeId: rootNodeId,
      canvas: CanvasPlacement(position: position, size: size),
      createdAt: now,
      updatedAt: now,
    );

    // Parse nodes
    final nodes = <String, Node>{};
    for (final entry in nodesJson.entries) {
      try {
        final nodeJson = entry.value as Map<String, dynamic>;
        // Ensure ID matches key
        nodeJson['id'] = entry.key;
        // Normalize childIds/children field
        if (nodeJson.containsKey('children') && !nodeJson.containsKey('childIds')) {
          nodeJson['childIds'] = nodeJson['children'];
        }
        nodes[entry.key] = Node.fromJson(nodeJson);
      } catch (e) {
        throw LlmException(
          'Failed to parse node "${entry.key}": $e\nNode JSON: ${entry.value}',
        );
      }
    }

    // Validate all child references exist
    for (final node in nodes.values) {
      for (final childId in node.childIds) {
        if (!nodes.containsKey(childId)) {
          throw LlmException(
            'Node "${node.id}" references non-existent child "$childId"',
          );
        }
      }
    }

    return FrameGenerationResult(frame: frame, nodes: nodes);
  }

  /// Update an existing frame based on a natural language description.
  ///
  /// [prompt] - The user's description of the changes to make.
  /// [frame] - The frame to update.
  /// [nodes] - The nodes belonging to the frame.
  /// [targetNodeIds] - Optional list of specific node IDs to focus changes on.
  Future<FrameGenerationResult> update({
    required String prompt,
    required Frame frame,
    required Map<String, Node> nodes,
    List<String>? targetNodeIds,
  }) async {
    final systemPrompt = UpdatePrompt.build(
      frame: frame,
      nodes: nodes,
      targetNodeIds: targetNodeIds,
      userPrompt: prompt,
    );

    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('FRAME UPDATE REQUEST');
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('User prompt: $prompt');
    _log('Frame: "${frame.name}" (${frame.id})');
    _log('Nodes: ${nodes.length}');
    if (targetNodeIds != null && targetNodeIds.isNotEmpty) {
      _log('Target nodes: ${targetNodeIds.join(', ')}');
    }
    _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    _log('Sending request to LLM...');

    final stopwatch = Stopwatch()..start();

    // Use higher token limit for updates since we need to return all nodes
    // Scale based on node count: ~1000 tokens per node as rough estimate
    final estimatedTokens = nodes.length * 1000;
    final maxTokens = estimatedTokens.clamp(16384, 131072);
    _log('Using maxTokens: $maxTokens (estimated from ${nodes.length} nodes)');

    try {
      final response = await _client.complete(
        system: systemPrompt,
        user: prompt,
        maxTokens: maxTokens,
        temperature: 0.3,
      );

      stopwatch.stop();
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('LLM RESPONSE (${stopwatch.elapsedMilliseconds}ms)');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log(response);
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Parse with preserved position/size from original frame
      final result = _parseResponse(
        response,
        position: frame.canvas.position,
        size: frame.canvas.size,
      );
      _log('Successfully parsed update: Frame "${result.frame.name}" with ${result.nodes.length} nodes');

      return result;
    } catch (e) {
      stopwatch.stop();
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _log('ERROR (${stopwatch.elapsedMilliseconds}ms): $e');
      _log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      rethrow;
    }
  }

  int _idCounter = 0;
  String _generateId(String prefix) =>
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
}
