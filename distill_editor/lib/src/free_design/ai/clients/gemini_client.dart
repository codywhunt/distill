import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_client.dart';

/// Google Gemini API client.
class GeminiClient implements LlmClient {
  final String apiKey;
  final String model;

  GeminiClient({
    required this.apiKey,
    required this.model,
  });

  @override
  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 4096,
    double? temperature,
  }) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': user},
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': maxTokens,
          if (temperature != null) 'temperature': temperature,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        'Gemini API error: ${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw LlmException('Gemini API error: no candidates returned');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List;
    if (parts.isEmpty) {
      throw LlmException('Gemini API error: no parts in response');
    }
    return parts[0]['text'] as String? ?? '';
  }
}
