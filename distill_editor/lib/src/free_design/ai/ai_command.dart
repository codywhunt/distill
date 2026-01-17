import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../store/editor_document_store.dart';
import 'ai_service.dart';

void _log(String message) {
  developer.log(message, name: 'AiCommand');
  // ignore: avoid_print
  print('[AiCommand] $message');
}

/// Execute AI frame generation.
///
/// Shows a prompt dialog and generates a frame from the user's description.
Future<void> executeAiGenerateFrame(
  BuildContext context,
  EditorDocumentStore store,
  FreeDesignAiService aiService,
) async {
  // Capture messenger before async gap
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  // Show prompt dialog
  final prompt = await showDialog<String>(
    context: context,
    builder: (context) => const AiPromptDialog(),
  );

  if (prompt == null || prompt.isEmpty) return;

  // Show loading indicator
  scaffoldMessenger.showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Generating frame...'),
        ],
      ),
      duration: Duration(minutes: 2), // Long duration, will be dismissed manually
    ),
  );

  try {
    _log('generateViaDsl: Starting generation for prompt: "$prompt"');

    // Generate frame from prompt using token-efficient DSL (~75% fewer tokens)
    final result = await aiService.generateViaDsl(
      prompt: prompt,
    );

    _log('generateViaDsl: Success - created frame "${result.frame.name}" with ${result.nodes.length} nodes');

    // Apply result to store
    aiService.applyResult(store, result);

    // Show success message
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Created "${result.frame.name}"'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    _log('generateViaDsl: ERROR - $e');

    // Show error message
    scaffoldMessenger.hideCurrentSnackBar();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// Dialog for entering AI prompt.
class AiPromptDialog extends StatefulWidget {
  const AiPromptDialog({super.key});

  @override
  State<AiPromptDialog> createState() => AiPromptDialogState();
}

class AiPromptDialogState extends State<AiPromptDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      Navigator.pop(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = getConfiguredProviderName();

    return AlertDialog(
      title: const Text('Generate Frame with AI'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (providerName != null) ...[
              Text(
                'Using: $providerName',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: 'Describe the UI you want to create...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Text(
              'Example: "A login screen with email and password fields, '
              'a blue sign in button, and a forgot password link"',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
