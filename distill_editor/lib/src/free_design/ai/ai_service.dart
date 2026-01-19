import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui';

import '../compiler/outline_compiler.dart';
import '../dsl/dsl_parser.dart';
import '../models/editor_document.dart';
import '../models/frame.dart';
import '../models/node.dart';
import '../patch/patch_op.dart';
import '../patch/patch_validator.dart';
import '../store/editor_document_store.dart';
import 'clients/mock_client.dart';
import 'clients/openai_client.dart';
import 'frame_generator.dart';
import 'llm_client.dart';
import 'patch_ops_parser.dart';
import 'prompts/edit_via_patches_prompt.dart';
import 'prompts/generate_dsl_prompt.dart';
import 'repair/repair_diagnostics.dart';
import 'repair/repair_prompt.dart';

void _log(String message) {
  developer.log(message, name: 'FreeDesignAI');
  // ignore: avoid_print
  print('[FreeDesignAI] $message');
}

/// OpenRouter API endpoint.
const _openRouterEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

/// AI service for Free Design.
///
/// Provides AI-powered features:
/// - Frame generation from natural language
/// - Token-efficient editing via PatchOps
/// - Token-efficient generation via DSL
/// - (Future) Flutter code generation
///
/// Uses OpenRouter to access all AI models through a unified API.
/// Set OPENROUTER_API_KEY environment variable to enable.
class FreeDesignAiService {
  final FrameGenerator _frameGenerator;
  final LlmClient _llmClient;
  final OutlineCompiler _outlineCompiler;
  final PatchOpsParser _patchOpsParser;
  final PatchValidator _patchValidator;
  final DslParser _dslParser;

  FreeDesignAiService._(LlmClient client)
      : _frameGenerator = FrameGenerator(client),
        _llmClient = client,
        _outlineCompiler = const OutlineCompiler(),
        _patchOpsParser = const PatchOpsParser(),
        _patchValidator = const PatchValidator(),
        _dslParser = DslParser();

  /// Create an AI service with the specified model and API key.
  ///
  /// Uses OpenRouter API endpoint.
  factory FreeDesignAiService({
    required LlmModel model,
    required String apiKey,
  }) {
    final client = OpenAiClient(
      apiKey: apiKey,
      model: model.modelId,
      endpoint: _openRouterEndpoint,
    );
    return FreeDesignAiService._(client);
  }

  /// Create an AI service with a mock client for testing.
  factory FreeDesignAiService.mock([MockLlmClient? client]) {
    return FreeDesignAiService._(client ?? MockLlmClient());
  }

  /// Generate a frame from a natural language description.
  ///
  /// Returns the generation result, which can be applied using [applyResult].
  Future<FrameGenerationResult> generateFrame({
    required String prompt,
    required EditorDocument document,
    Offset? position,
    Size? size,
  }) {
    return _frameGenerator.generate(
      prompt: prompt,
      document: document,
      position: position ?? const Offset(0, 0),
      size: size ?? const Size(375, 812),
    );
  }

  /// Update an existing frame based on a natural language description.
  ///
  /// [prompt] - The user's description of the changes to make.
  /// [frame] - The frame to update.
  /// [nodes] - The nodes belonging to the frame.
  /// [targetNodeIds] - Optional list of specific node IDs to focus changes on.
  ///
  /// Returns the updated frame and nodes, which can be applied using [applyUpdateResult].
  Future<FrameGenerationResult> updateFrame({
    required String prompt,
    required Frame frame,
    required Map<String, Node> nodes,
    List<String>? targetNodeIds,
  }) {
    return _frameGenerator.update(
      prompt: prompt,
      frame: frame,
      nodes: nodes,
      targetNodeIds: targetNodeIds,
    );
  }

  /// Generate a new frame via DSL (token-efficient).
  ///
  /// This method reduces output token usage by ~75% compared to [generateFrame]
  /// by having the AI output compact DSL format instead of verbose JSON.
  ///
  /// [prompt] - Natural language description of the UI to create.
  /// [context] - Optional context about the design system or constraints.
  /// [position] - Where to place the frame on the canvas.
  /// [size] - Target frame dimensions (default: 375x812 for mobile).
  /// [maxRepairAttempts] - Number of repair attempts if parsing fails (default: 2).
  ///
  /// Returns a [FrameGenerationResult] containing the parsed frame and nodes.
  /// Throws [DslGenerationException] if generation fails after repair attempts.
  Future<FrameGenerationResult> generateViaDsl({
    required String prompt,
    String? context,
    Offset? position,
    Size? size,
    int maxRepairAttempts = 2,
  }) async {
    final targetWidth = size?.width.toInt() ?? 375;
    final targetHeight = size?.height.toInt() ?? 812;
    final targetPosition = position ?? Offset.zero;

    var attempt = 0;
    String? lastDslResponse;
    String? lastError;

    while (attempt <= maxRepairAttempts) {
      try {
        // Build prompt
        final systemPrompt = GenerateDslPrompt.buildSystemPrompt();
        final userPrompt = attempt == 0
            ? GenerateDslPrompt.buildUserPrompt(
                userRequest: prompt,
                context: context,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
              )
            : _buildDslRepairPrompt(lastDslResponse!, lastError!);

        _log('generateViaDsl: Sending request (attempt ${attempt + 1})');

        // Call LLM
        // Initial generation: 0.5 balances creativity with consistency
        // Repair attempts: 0.2 for maximum determinism to fix errors reliably
        final temperature = attempt == 0 ? 0.5 : 0.2;
        final response = await _llmClient.complete(
          system: systemPrompt,
          user: userPrompt,
          temperature: temperature,
          maxTokens: 4096,
        );

        _log('generateViaDsl: LLM response:\n$response');

        lastDslResponse = response;

        // Extract DSL from response (may be in code block)
        final dsl = _extractDsl(response);

        _log('generateViaDsl: Extracted DSL:\n$dsl');

        // Parse DSL to Frame + Nodes
        final result = _dslParser.parse(dsl);

        // Adjust frame position to requested canvas position
        final adjustedFrame = result.frame.copyWith(
          canvas: result.frame.canvas.copyWith(
            position: targetPosition,
          ),
        );

        _log('generateViaDsl: Success - parsed frame with ${result.nodes.length} nodes');

        return FrameGenerationResult(
          frame: adjustedFrame,
          nodes: result.nodes,
        );
      } on DslParseException catch (e) {
        lastError = e.message;
        attempt++;

        if (attempt > maxRepairAttempts) {
          throw DslGenerationException(
            'Failed to generate valid DSL after $maxRepairAttempts repairs',
            lastError,
          );
        }

        _log('generateViaDsl: Parse failed, attempting repair: ${e.message}');
      }
    }

    throw DslGenerationException(
      'Unexpected failure in generateViaDsl',
      lastError,
    );
  }

  /// Extract DSL content from LLM response.
  String _extractDsl(String response) {
    // Try to extract from code block with various language tags
    // Handles: ```dsl, ```dsl:1, ``` (no tag)
    final codeBlockMatch = RegExp(
      r'```(?:dsl(?::\d+)?)?\s*\n([\s\S]*?)\s*```',
      multiLine: true,
    ).firstMatch(response);

    if (codeBlockMatch != null) {
      final content = codeBlockMatch.group(1)!.trim();
      // If content starts with dsl:, return as-is
      if (content.startsWith('dsl:')) {
        return content;
      }
      // Otherwise prepend dsl:1 header if missing
      return 'dsl:1\n$content';
    }

    // Check if response starts with dsl: header
    final trimmed = response.trim();
    if (trimmed.startsWith('dsl:')) {
      return trimmed;
    }

    // Try to find dsl: anywhere in response
    final dslMatch = RegExp(r'dsl:\d+[\s\S]*').firstMatch(response);
    if (dslMatch != null) {
      return dslMatch.group(0)!;
    }

    throw DslParseException('No DSL content found in response');
  }

  /// Build a repair prompt for failed DSL parsing.
  String _buildDslRepairPrompt(String originalResponse, String error) {
    return '''
The previous DSL output had a parsing error:

Original output:
```
$originalResponse
```

Error: $error

Please output corrected DSL that fixes this error.
Ensure:
- Start with `dsl:1` version header
- Include `frame Name - w WIDTH h HEIGHT` declaration
- Use consistent 2-space indentation
- All property values are valid

Output ONLY the corrected DSL:
''';
  }

  /// Edit existing nodes via PatchOps (token-efficient).
  ///
  /// This method reduces token usage by ~98% compared to [updateFrame] by:
  /// - Sending a compact outline instead of full JSON
  /// - Returning only patch operations instead of full documents
  ///
  /// [document] - The current editor document.
  /// [frameId] - The frame containing the nodes to edit.
  /// [focusNodeIds] - The specific nodes being edited.
  /// [userRequest] - What the user wants to change.
  /// [maxRepairAttempts] - Number of repair attempts if validation fails (default: 2).
  ///
  /// Returns a list of [PatchOp] that can be applied to the document.
  /// Throws [PatchOpsValidationException] if validation fails after repair attempts.
  Future<List<PatchOp>> editViaPatches({
    required EditorDocument document,
    required String frameId,
    required List<String> focusNodeIds,
    required String userRequest,
    int maxRepairAttempts = 2,
  }) async {
    var attempt = 0;
    String? lastPatchesJson;
    List<String>? lastErrors;
    ValidationResult? lastValidation;

    while (attempt <= maxRepairAttempts) {
      try {
        // Generate outline context
        final outline = _outlineCompiler.compile(
          document,
          focusNodeIds: focusNodeIds,
          frameId: frameId,
          maxDepth: 2,
        );

        // Include detailed JSON for single focus node
        Map<String, dynamic>? focusJson;
        if (focusNodeIds.length == 1) {
          final node = document.nodes[focusNodeIds.first];
          focusJson = node?.toJson();
        }

        // Build prompt
        final systemPrompt = EditViaPatchesPrompt.buildSystemPrompt();
        final userPrompt = attempt == 0
            ? EditViaPatchesPrompt.buildUserPrompt(
                outline: outline,
                focusNodeJson: focusJson,
                userRequest: userRequest,
              )
            : _buildRepairPrompt(
                lastPatchesJson!,
                lastErrors!,
                validation: lastValidation,
              );

        _log('editViaPatches: Sending request (attempt ${attempt + 1})');

        // Call LLM
        // Initial edit: 0.3 for precise changes
        // Repair attempts: 0.1 for maximum determinism to fix validation errors
        final temperature = attempt == 0 ? 0.3 : 0.1;
        final response = await _llmClient.complete(
          system: systemPrompt,
          user: userPrompt,
          temperature: temperature,
          maxTokens: 8192, // Needs room for InsertNode operations with full JSON
        );

        _log('editViaPatches: LLM response:\n$response');

        // Parse PatchOps
        final patches = _patchOpsParser.parse(response);
        lastPatchesJson = response;

        _log('editViaPatches: Parsed ${patches.length} patches');

        // Validate
        final validation = _patchValidator.validate(patches, document);

        if (!validation.isValid) {
          lastErrors = validation.errors;
          lastValidation = validation;
          attempt++;

          if (attempt > maxRepairAttempts) {
            throw PatchOpsValidationException(
              'Failed to generate valid patches after $maxRepairAttempts repairs',
              validation.errors,
            );
          }

          _log('editViaPatches: Validation failed, attempting repair...');
          continue;
        }

        if (validation.warnings.isNotEmpty) {
          _log('editViaPatches: Warnings: ${validation.warnings}');
        }

        _log('editViaPatches: Success with ${patches.length} valid patches');
        return patches;
      } on PatchOpsParseException catch (e) {
        lastErrors = [e.message];
        attempt++;

        if (attempt > maxRepairAttempts) {
          throw PatchOpsValidationException(
            'Failed to parse patches after $maxRepairAttempts repairs',
            [e.message],
          );
        }

        _log('editViaPatches: Parse failed, attempting repair...');
      }
    }

    throw PatchOpsValidationException(
      'Unexpected failure in editViaPatches',
      lastErrors ?? [],
    );
  }

  /// Build a repair prompt for failed patch validation.
  ///
  /// Uses structured diagnostics when a ValidationResult is available,
  /// otherwise falls back to simple error list.
  String _buildRepairPrompt(
    String originalResponse,
    List<String> errors, {
    ValidationResult? validation,
  }) {
    // Use structured diagnostics if validation result is available
    if (validation != null) {
      final diagnostics = validation.toDiagnosticReport();
      return RepairPrompt.buildPatchRepairPrompt(
        originalPatches: originalResponse,
        diagnostics: diagnostics,
      );
    }

    // Fallback to simple format for parse errors
    final simpleDiagnostics = DiagnosticReport(
      errors.map((e) => RepairDiagnostic(
        code: RepairErrorCode.patchInvalidOp,
        message: e,
      )).toList(),
    );

    return RepairPrompt.buildPatchRepairPrompt(
      originalPatches: originalResponse,
      diagnostics: simpleDiagnostics,
    );
  }

  /// Apply a generation result to a document store.
  ///
  /// This creates and applies the necessary patches to insert
  /// the generated frame and nodes.
  void applyResult(EditorDocumentStore store, FrameGenerationResult result) {
    final patches = <PatchOp>[
      // Insert all nodes first
      for (final node in result.nodes.values) InsertNode(node),
      // Then insert the frame
      InsertFrame(result.frame),
    ];
    store.applyPatches(patches);
  }

  /// Apply an update result to a document store.
  ///
  /// This handles replacing existing nodes and removing deleted nodes.
  /// Unlike [applyResult], this preserves the frame and only updates its contents.
  ///
  /// [originalNodeIds] - The IDs of nodes that belonged to the frame before the update.
  void applyUpdateResult(
    EditorDocumentStore store,
    FrameGenerationResult result, {
    required Set<String> originalNodeIds,
  }) {
    final patches = <PatchOp>[];

    // Find nodes to delete (in original but not in result)
    final newNodeIds = result.nodes.keys.toSet();
    for (final oldId in originalNodeIds) {
      if (!newNodeIds.contains(oldId)) {
        patches.add(DeleteNode(oldId));
      }
    }

    // Update or insert nodes
    for (final node in result.nodes.values) {
      if (originalNodeIds.contains(node.id)) {
        // Replace existing node
        patches.add(ReplaceNode(id: node.id, node: node));
      } else {
        // Insert new node
        patches.add(InsertNode(node));
      }
    }

    // Update frame metadata (name, rootNodeId if changed)
    final frameId = result.frame.id;
    patches.add(SetFrameProp(frameId: frameId, path: '/name', value: result.frame.name));
    patches.add(SetFrameProp(frameId: frameId, path: '/rootNodeId', value: result.frame.rootNodeId));
    patches.add(SetFrameProp(frameId: frameId, path: '/updatedAt', value: DateTime.now().toIso8601String()));

    store.applyPatches(patches);
  }
}

/// Get an environment variable, checking both compile-time (dart-define) and
/// runtime (Platform.environment) sources.
///
/// Compile-time values take precedence over runtime values.
String _getEnv(String name) {
  // First check compile-time environment (works on all platforms including web)
  const compileTime = {
    'OPENROUTER_API_KEY': String.fromEnvironment('OPENROUTER_API_KEY'),
    'AI_MODEL': String.fromEnvironment('AI_MODEL'),
  };

  final compileValue = compileTime[name] ?? '';
  if (compileValue.isNotEmpty) {
    return compileValue;
  }

  // Fall back to runtime environment (native platforms only)
  // Platform.environment is not available on web, so we catch the error
  try {
    return Platform.environment[name] ?? '';
  } catch (_) {
    // Platform not available (web), return empty
    return '';
  }
}

/// Factory for creating AI service from environment variables.
///
/// Uses OpenRouter to access all AI models through a unified API.
/// Checks both compile-time (--dart-define) and runtime (exported shell variables).
///
/// Returns null if OPENROUTER_API_KEY is not configured.
///
/// Environment variables:
/// - `OPENROUTER_API_KEY` - Required. Your OpenRouter API key.
/// - `AI_MODEL` - Optional. Model ID in OpenRouter format (e.g., "anthropic/claude-sonnet-4").
///   Defaults to Claude Sonnet 4.
///
/// Example models:
/// - `anthropic/claude-sonnet-4` (default)
/// - `anthropic/claude-haiku-4`
/// - `openai/gpt-4o`
/// - `google/gemini-2.5-pro-preview`
/// - `meta-llama/llama-4-maverick`
///
/// See https://openrouter.ai/models for all available models.
FreeDesignAiService? createAiServiceFromEnv() {
  final apiKey = _getEnv('OPENROUTER_API_KEY');
  if (apiKey.isEmpty) {
    return null;
  }

  final modelId = _getEnv('AI_MODEL');
  final model = modelId.isNotEmpty
      ? LlmModel.fromId(modelId)
      : LlmModel.defaultModel;

  _log('Creating AI service with model: ${model.displayName} (${model.modelId})');
  return FreeDesignAiService(model: model, apiKey: apiKey);
}

/// Get info about the configured AI provider and model.
///
/// Returns null if OPENROUTER_API_KEY is not set.
AiConfigInfo? getConfiguredAiInfo() {
  final apiKey = _getEnv('OPENROUTER_API_KEY');
  if (apiKey.isEmpty) {
    return null;
  }

  final modelId = _getEnv('AI_MODEL');
  final model = modelId.isNotEmpty
      ? LlmModel.fromId(modelId)
      : LlmModel.defaultModel;

  return AiConfigInfo('OpenRouter', model.displayName, model.modelId);
}

/// Get a description of which AI provider is configured.
String? getConfiguredProviderName() {
  final info = getConfiguredAiInfo();
  return info != null ? '${info.provider} (${info.modelName})' : null;
}

/// Get the OpenRouter API key from environment.
///
/// Returns null if not configured.
String? getOpenRouterApiKey() {
  final apiKey = _getEnv('OPENROUTER_API_KEY');
  return apiKey.isNotEmpty ? apiKey : null;
}

/// Create an AI service with a specific model.
///
/// Returns null if OPENROUTER_API_KEY is not configured.
FreeDesignAiService? createAiServiceWithModel(LlmModel model) {
  final apiKey = getOpenRouterApiKey();
  if (apiKey == null) return null;

  _log('Creating AI service with model: ${model.displayName} (${model.modelId})');
  return FreeDesignAiService(model: model, apiKey: apiKey);
}

/// Information about the configured AI provider and model.
class AiConfigInfo {
  final String provider;
  final String modelName;
  final String modelId;

  const AiConfigInfo(this.provider, this.modelName, this.modelId);
}

/// Exception thrown when patch validation fails after repair attempts.
class PatchOpsValidationException implements Exception {
  final String message;
  final List<String> errors;

  PatchOpsValidationException(this.message, this.errors);

  @override
  String toString() {
    final buffer = StringBuffer('PatchOpsValidationException: $message');
    if (errors.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }
    return buffer.toString();
  }
}

/// Exception thrown when DSL generation fails after repair attempts.
class DslGenerationException implements Exception {
  final String message;
  final String? parseError;

  DslGenerationException(this.message, [this.parseError]);

  @override
  String toString() {
    final buffer = StringBuffer('DslGenerationException: $message');
    if (parseError != null) {
      buffer.writeln();
      buffer.writeln('Parse error: $parseError');
    }
    return buffer.toString();
  }
}
