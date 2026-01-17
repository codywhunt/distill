import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_client.dart';

/// OpenAI-compatible client.
///
/// Works with OpenAI, Groq, and Cerebras APIs (all use the same format).
class OpenAiClient implements LlmClient {
  final String apiKey;
  final String model;
  final String endpoint;

  OpenAiClient({
    required this.apiKey,
    required this.model,
    this.endpoint = 'https://api.openai.com/v1/chat/completions',
  });

  @override
  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 4096,
    double? temperature,
  }) async {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        if (temperature != null) 'temperature': temperature,
      }),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        'OpenAI API error: ${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List;
    if (choices.isEmpty) {
      throw LlmException('OpenAI API error: no choices returned');
    }
    final message = choices[0]['message'] as Map<String, dynamic>;
    return message['content'] as String? ?? '';
  }
}
