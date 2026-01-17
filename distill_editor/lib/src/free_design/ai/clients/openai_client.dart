import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../llm_client.dart';

void _log(String message) {
  developer.log(message, name: 'OpenAiClient');
  // ignore: avoid_print
  print('[OpenAiClient] $message');
}

/// OpenAI-compatible client.
///
/// Works with OpenAI, OpenRouter, and other OpenAI-compatible APIs.
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
    _log('Request to $endpoint');
    _log('Model: $model');
    _log('System prompt: ${system.length} chars');
    _log('User prompt: ${user.length} chars');

    final http.Response response;
    try {
      response = await http.post(
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
    } catch (e, stackTrace) {
      _log('Network error: $e');
      _log('Stack trace:\n$stackTrace');
      rethrow;
    }

    _log('Response status: ${response.statusCode}');

    if (response.statusCode != 200) {
      _log('Error response body: ${response.body}');
      throw LlmException(
        'API error: ${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // Log usage info if available
    final usage = json['usage'] as Map<String, dynamic>?;
    if (usage != null) {
      _log('Tokens - prompt: ${usage['prompt_tokens']}, completion: ${usage['completion_tokens']}, total: ${usage['total_tokens']}');
    }

    final choices = json['choices'] as List;
    if (choices.isEmpty) {
      _log('Error: no choices returned');
      throw LlmException('API error: no choices returned');
    }

    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = message['content'] as String? ?? '';

    _log('Response content: ${content.length} chars');
    _log('Response preview: ${content.substring(0, content.length.clamp(0, 500))}${content.length > 500 ? '...' : ''}');

    return content;
  }
}
