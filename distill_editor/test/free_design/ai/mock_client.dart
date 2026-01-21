import 'package:distill_editor/src/free_design/ai/llm_client.dart';

/// Mock LLM client for testing.
class MockLlmClient implements LlmClient {
  final String Function(String system, String user)? responseBuilder;
  final Duration delay;

  MockLlmClient({
    this.responseBuilder,
    this.delay = const Duration(milliseconds: 500),
  });

  @override
  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 4096,
    double? temperature,
  }) async {
    await Future<void>.delayed(delay);

    if (responseBuilder != null) {
      return responseBuilder!(system, user);
    }

    // Default: return a simple frame JSON
    return '''
```json
{
  "frame": {
    "id": "frame_mock",
    "name": "Mock Frame",
    "rootNodeId": "node_root",
    "canvas": {"position": {"x": 0, "y": 0}, "size": {"width": 375, "height": 812}}
  },
  "nodes": {
    "node_root": {
      "id": "node_root",
      "name": "Root",
      "type": "container",
      "childIds": [],
      "layout": {"size": {"width": {"mode": "fill"}, "height": {"mode": "fill"}}},
      "style": {"fill": {"type": "solid", "color": {"hex": "#FFFFFF"}}},
      "props": {}
    }
  }
}
```
''';
  }
}
