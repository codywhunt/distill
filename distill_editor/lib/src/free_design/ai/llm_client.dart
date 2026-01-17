/// LLM client interface and model definitions for AI services.
///
/// Supports multiple providers:
/// - Anthropic (Claude)
/// - OpenAI (GPT)
/// - Google (Gemini)
/// - Groq (Llama via OpenAI-compatible API)
/// - Cerebras (Llama via OpenAI-compatible API)
library;

/// Supported LLM providers.
enum LlmProvider {
  anthropic,
  openai,
  gemini,
  groq,
  cerebras,
}

/// Model configuration.
class LlmModel {
  final LlmProvider provider;
  final String modelId;
  final String displayName;

  const LlmModel(this.provider, this.modelId, this.displayName);

  // Anthropic
  static const claudeSonnet = LlmModel(
    LlmProvider.anthropic,
    'claude-sonnet-4-5-20250929',
    'Claude Sonnet 4.5',
  );
  static const claudeHaiku = LlmModel(
    LlmProvider.anthropic,
    'claude-haiku-4-5-20251001',
    'Claude Haiku 4.5',
  );

  // OpenAI
  static const gpt4o = LlmModel(
    LlmProvider.openai,
    'gpt-4o',
    'GPT-4o',
  );
  static const gpt4oMini = LlmModel(
    LlmProvider.openai,
    'gpt-4o-mini',
    'GPT-4o Mini',
  );

  // Google Gemini
  static const geminiPro = LlmModel(
    LlmProvider.gemini,
    'gemini-3-pro',
    'Gemini 3 Pro',
  );
  static const geminiFlash = LlmModel(
    LlmProvider.gemini,
    'gemini-3-flash',
    'Gemini 3 Flash',
  );

  // Groq (OpenAI-compatible)
  static const groqLlama70b = LlmModel(
    LlmProvider.groq,
    'llama-3.3-70b-versatile',
    'Llama 3.3 70B (Groq)',
  );
  static const groqLlama8b = LlmModel(
    LlmProvider.groq,
    'llama-3.1-8b-instant',
    'Llama 3.1 8B (Groq)',
  );

  // Cerebras (OpenAI-compatible)
  static const cerebrasLlama70b = LlmModel(
    LlmProvider.cerebras,
    'llama-3.3-70b',
    'Llama 3.3 70B (Cerebras)',
  );
  static const cerebrasZaiGlm = LlmModel(
    LlmProvider.cerebras,
    'zai-glm-4.7',
    'Zai GLM 4.7 (Cerebras)',
  );

  /// All available models.
  static const all = [
    claudeSonnet,
    claudeHaiku,
    gpt4o,
    gpt4oMini,
    geminiPro,
    geminiFlash,
    groqLlama70b,
    groqLlama8b,
    cerebrasLlama70b,
    cerebrasZaiGlm,
  ];
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
