import 'repair_diagnostics.dart';

/// Builds repair prompts with structured diagnostics for AI correction.
///
/// Provides clear, actionable error information that helps the AI
/// understand exactly what went wrong and how to fix it.
class RepairPrompt {
  /// Build a repair prompt for PatchOps errors.
  ///
  /// [originalPatches] - The original JSON array of patches that failed.
  /// [diagnostics] - Structured diagnostics about what went wrong.
  /// [context] - Optional additional context about the document state.
  static String buildPatchRepairPrompt({
    required String originalPatches,
    required DiagnosticReport diagnostics,
    String? context,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('# PatchOps Repair Required');
    buffer.writeln();
    buffer.writeln('The previous patch operations failed validation.');
    buffer.writeln();

    buffer.writeln('## Original Patches');
    buffer.writeln('```json');
    buffer.writeln(originalPatches);
    buffer.writeln('```');
    buffer.writeln();

    buffer.writeln('## Diagnostics');
    buffer.writeln(diagnostics.toPromptFormat());
    buffer.writeln();

    if (context != null) {
      buffer.writeln('## Additional Context');
      buffer.writeln(context);
      buffer.writeln();
    }

    buffer.writeln('## Repair Instructions');
    buffer.writeln();
    buffer.writeln('Fix the issues above and output corrected PatchOps.');
    buffer.writeln();
    buffer.writeln('Key rules:');
    buffer.writeln('1. InsertNode must appear BEFORE any operation that references the node');
    buffer.writeln('2. DetachChild must appear BEFORE DeleteNode for the same node');
    buffer.writeln('3. All node IDs must be valid (existing or created in this batch)');
    buffer.writeln('4. Property paths must follow JSON Pointer format (/props/text, /style/fill/color/hex)');
    buffer.writeln();
    buffer.writeln('Output ONLY the corrected JSON array of PatchOps:');

    return buffer.toString();
  }

  /// Build a repair prompt for DSL parse errors.
  ///
  /// [originalDsl] - The original DSL that failed to parse.
  /// [diagnostics] - Structured diagnostics about what went wrong.
  static String buildDslRepairPrompt({
    required String originalDsl,
    required DiagnosticReport diagnostics,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('# DSL Repair Required');
    buffer.writeln();
    buffer.writeln('The previous DSL output failed to parse.');
    buffer.writeln();

    buffer.writeln('## Original DSL');
    buffer.writeln('```');
    buffer.writeln(originalDsl);
    buffer.writeln('```');
    buffer.writeln();

    buffer.writeln('## Diagnostics');
    buffer.writeln(diagnostics.toPromptFormat());
    buffer.writeln();

    buffer.writeln('## Repair Instructions');
    buffer.writeln();
    buffer.writeln('Fix the issues above and output corrected DSL.');
    buffer.writeln();
    buffer.writeln('Key rules:');
    buffer.writeln('1. Start with `dsl:1` version header');
    buffer.writeln('2. Include `frame Name - w WIDTH h HEIGHT` declaration');
    buffer.writeln('3. Use 2-space indentation for hierarchy');
    buffer.writeln('4. Node format: `type#id "content" - prop value prop value`');
    buffer.writeln('5. Valid types: container, row, column, text, img, icon, spacer, use');
    buffer.writeln();
    buffer.writeln('Output ONLY the corrected DSL:');

    return buffer.toString();
  }

  /// Build a repair prompt for JSON IR errors.
  ///
  /// [originalJson] - The original JSON that failed validation.
  /// [diagnostics] - Structured diagnostics about what went wrong.
  static String buildJsonRepairPrompt({
    required String originalJson,
    required DiagnosticReport diagnostics,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('# JSON Repair Required');
    buffer.writeln();
    buffer.writeln('The previous JSON output failed validation.');
    buffer.writeln();

    buffer.writeln('## Original JSON');
    buffer.writeln('```json');
    buffer.writeln(originalJson);
    buffer.writeln('```');
    buffer.writeln();

    buffer.writeln('## Diagnostics');
    buffer.writeln(diagnostics.toPromptFormat());
    buffer.writeln();

    buffer.writeln('## Repair Instructions');
    buffer.writeln();
    buffer.writeln('Fix the issues above and output corrected JSON.');
    buffer.writeln();
    buffer.writeln('Key rules:');
    buffer.writeln('1. All nodes must have unique IDs');
    buffer.writeln('2. childIds must reference existing nodes');
    buffer.writeln('3. Component instanceProps must reference valid componentId');
    buffer.writeln('4. Frame rootNodeId must reference an existing node');
    buffer.writeln();
    buffer.writeln('Output ONLY the corrected JSON:');

    return buffer.toString();
  }

  /// Build a summary of common fixes for the AI.
  static String buildCommonFixesReference() {
    return '''
# Common Fixes Reference

## Node References
- Error: Node "n_xyz" does not exist
- Fix: Add InsertNode for "n_xyz" before referencing it

## Parent-Child Relationships
- Error: Orphaned node "n_abc"
- Fix: Add AttachChild to connect it to a parent

## Property Paths
- Error: Invalid property path "/props/text/content"
- Fix: Use "/props/text" for text content (not nested)

## Order of Operations
Correct order for creating and attaching a node:
1. InsertNode (create the node)
2. AttachChild (attach to parent)

Correct order for removing a node:
1. DetachChild (remove from parent)
2. DeleteNode (delete the node)

## Type-Specific Properties
- container: /props/clipContent, /props/scrollDirection
- text: /props/text, /props/fontSize, /props/fontWeight, /props/color
- icon: /props/icon, /props/iconSet, /props/size, /props/color
- image: /props/src, /props/fit, /props/alt

## Layout Properties
- /layout/size/width/mode: "hug" | "fill" | "fixed"
- /layout/size/width/value: number (when mode is fixed)
- /layout/autoLayout/gap: number
- /layout/autoLayout/padding/top|right|bottom|left: number

## Style Properties
- /style/fill/color/hex: "#RRGGBB" or "#RRGGBBAA"
- /style/cornerRadius/all: number
- /style/opacity: 0.0 to 1.0
- /style/visible: true | false
''';
  }
}
