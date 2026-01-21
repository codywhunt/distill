/// AI service for Free Design.
///
/// Provides AI-powered frame generation from natural language descriptions.
/// Uses OpenRouter to access all AI models through a unified API.
library;

export 'ai_command.dart';
export 'ai_service.dart';
export 'frame_generator.dart';
export 'llm_client.dart';
export 'patch_ops_parser.dart';

// Clients
export 'clients/openai_client.dart';

// Prompts
export 'prompts/edit_via_patches_prompt.dart';
export 'prompts/generate_dsl_prompt.dart';

// Repair
export 'repair/repair.dart';
