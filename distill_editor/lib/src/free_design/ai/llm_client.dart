/// LLM client interface and model definitions for AI services.
///
/// Uses OpenRouter to access all models through a unified API.
/// Set OPENROUTER_API_KEY and optionally AI_MODEL environment variables.
library;

/// Model configuration for OpenRouter.
///
/// Models use OpenRouter's naming convention: `provider/model-name`
/// See https://openrouter.ai/models for available models.
class LlmModel {
  final String modelId;
  final String displayName;

  const LlmModel(this.modelId, this.displayName);

  /// Create a model from an OpenRouter model ID.
  factory LlmModel.fromId(String modelId) {
    // Check if it matches a preset
    final preset = all.where((m) => m.modelId == modelId).firstOrNull;
    if (preset != null) return preset;

    // Create custom model
    return LlmModel(modelId, modelId);
  }

  // Anthropic (via OpenRouter)
  static const claudeOpus = LlmModel(
    'anthropic/claude-opus-4.5',
    'Claude Opus 4.5',
  );
  static const claudeSonnet = LlmModel(
    'anthropic/claude-sonnet-4.5',
    'Claude Sonnet 4.5',
  );
  static const claudeHaiku = LlmModel(
    'anthropic/claude-haiku-4.5',
    'Claude Haiku 4.5',
  );

  // OpenAI (via OpenRouter)
  static const gpt52 = LlmModel('openai/gpt-5.2', 'GPT-5.2');
  static const gpt51CodexMini = LlmModel(
    'openai/gpt-5.1-codex-mini',
    'GPT-5.1 Codex Mini',
  );
  static const gpt52Codex = LlmModel('openai/gpt-5.2-codex', 'GPT-5.2 Codex');

  // Google Gemini (via OpenRouter)
  static const geminiPro = LlmModel(
    'google/gemini-3-pro-preview',
    'Gemini 3 Pro',
  );
  static const geminiFlash = LlmModel(
    'google/gemini-3-flash-preview',
    'Gemini 3 Flash',
  );

  // Meta Llama (via OpenRouter)
  static const grokCodeFast1 = LlmModel(
    'x-ai/grok-code-fast-1',
    'xAI Grok Code Fast 1',
  );
  static const gptOss120b = LlmModel('openai/gpt-oss-120b', 'GPT-OSS 120B');
  static const glm47 = LlmModel('z-ai/glm-4.7', 'GLM 4.7');

  /// All available preset models.
  static const all = [
    claudeOpus,
    claudeSonnet,
    claudeHaiku,
    gpt52,
    gpt51CodexMini,
    gpt52Codex,
    geminiPro,
    geminiFlash,
    grokCodeFast1,
    gptOss120b,
    glm47,
  ];

  /// Default model when none specified.
  static const defaultModel = geminiFlash;
}

/// Unified LLM client interface.
abstract class LlmClient {
  /// Complete a prompt with the LLM.
  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 4096,
    double? temperature,
  });
}

/// Exception thrown by LLM clients.
class LlmException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  LlmException(this.message, {this.statusCode, this.responseBody});

  @override
  String toString() => message;
}
