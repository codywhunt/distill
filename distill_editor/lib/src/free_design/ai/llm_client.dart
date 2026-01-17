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
  static const claudeSonnet = LlmModel(
    'anthropic/claude-sonnet-4',
    'Claude Sonnet 4',
  );
  static const claudeHaiku = LlmModel(
    'anthropic/claude-haiku-4',
    'Claude Haiku 4',
  );

  // OpenAI (via OpenRouter)
  static const gpt4o = LlmModel('openai/gpt-4o', 'GPT-4o');
  static const gpt4oMini = LlmModel('openai/gpt-4o-mini', 'GPT-4o Mini');

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
  static const llama4Maverick = LlmModel(
    'meta-llama/llama-4-maverick',
    'Llama 4 Maverick',
  );
  static const llama33_70b = LlmModel(
    'meta-llama/llama-3.3-70b-instruct',
    'Llama 3.3 70B',
  );

  /// All available preset models.
  static const all = [
    claudeSonnet,
    claudeHaiku,
    gpt4o,
    gpt4oMini,
    geminiPro,
    geminiFlash,
    llama4Maverick,
    llama33_70b,
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
