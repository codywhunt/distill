import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_client.dart';

/// Anthropic Messages API client.
class AnthropicClient implements LlmClient {
  final String apiKey;
  final String model;
  final String endpoint;
  final String apiVersion;

  AnthropicClient({
    required this.apiKey,
    required this.model,
    this.endpoint = 'https://api.anthropic.com/v1/messages',
    this.apiVersion = '2023-06-01',
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
        'x-api-key': apiKey,
        'anthropic-version': apiVersion,
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
        if (temperature != null) 'temperature': temperature,
      }),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        'Anthropic API error: ${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['content'] as List;
    final textBlock = content.firstWhere(
      (c) => c['type'] == 'text',
      orElse: () => {'text': ''},
    );
    return textBlock['text'] as String? ?? '';
  }
}
