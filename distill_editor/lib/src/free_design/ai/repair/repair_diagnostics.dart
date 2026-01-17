/// Structured diagnostics for AI repair mode.
///
/// Provides machine-readable error formats that help the AI
/// understand exactly what went wrong and how to fix it.

/// A structured diagnostic for AI repair.
///
/// Unlike raw error strings, diagnostics provide:
/// - Error codes for pattern matching
/// - Context about what was expected vs actual
/// - Suggested fixes the AI can apply
class RepairDiagnostic {
  /// Unique error code for this type of issue.
  final RepairErrorCode code;

  /// Human-readable error message.
  final String message;

  /// The location where the error occurred (node ID, path, line number, etc.)
  final String? location;

  /// What was expected.
  final String? expected;

  /// What was actually found.
  final String? actual;

  /// Suggested fix actions.
  final List<String> suggestions;

  /// Severity level.
  final DiagnosticSeverity severity;

  const RepairDiagnostic({
    required this.code,
    required this.message,
    this.location,
    this.expected,
    this.actual,
    this.suggestions = const [],
    this.severity = DiagnosticSeverity.error,
  });

  /// Convert to a format suitable for AI prompts.
  String toPromptFormat() {
    final buffer = StringBuffer();

    buffer.write('[${code.name}] $message');

    if (location != null) {
      buffer.write(' at $location');
    }

    if (expected != null || actual != null) {
      buffer.writeln();
      if (expected != null) {
        buffer.writeln('  Expected: $expected');
      }
      if (actual != null) {
        buffer.writeln('  Actual: $actual');
      }
    }

    if (suggestions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('  Suggestions:');
      for (final suggestion in suggestions) {
        buffer.writeln('    - $suggestion');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() => toPromptFormat();
}

/// Error codes for repair diagnostics.
enum RepairErrorCode {
  // Structural errors
  missingNode,
  orphanedNode,
  cyclicReference,
  invalidParentChild,
  duplicateNodeId,

  // Property errors
  invalidPropertyPath,
  invalidPropertyValue,
  typeMismatch,
  missingRequiredProperty,

  // Reference errors
  invalidNodeReference,
  invalidFrameReference,
  invalidComponentReference,

  // DSL syntax errors
  dslSyntaxError,
  dslInvalidIndentation,
  dslUnknownNodeType,
  dslInvalidProperty,

  // PatchOp errors
  patchInvalidOp,
  patchMissingField,
  patchInvalidTarget,
  patchConflict,

  // Semantic errors
  invalidLayout,
  invalidStyle,
  unreachableNode,
}

/// Severity levels for diagnostics.
enum DiagnosticSeverity {
  /// Fatal error - operation cannot continue.
  error,

  /// Warning - operation can continue but may have issues.
  warning,

  /// Informational hint for improvement.
  hint,
}

/// Collection of diagnostics from a validation or parse operation.
class DiagnosticReport {
  final List<RepairDiagnostic> diagnostics;

  const DiagnosticReport(this.diagnostics);

  /// Create an empty report.
  const DiagnosticReport.empty() : diagnostics = const [];

  /// Whether there are any errors (not warnings).
  bool get hasErrors =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.error);

  /// Whether there are any warnings.
  bool get hasWarnings =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.warning);

  /// Get only error-level diagnostics.
  List<RepairDiagnostic> get errors =>
      diagnostics.where((d) => d.severity == DiagnosticSeverity.error).toList();

  /// Get only warning-level diagnostics.
  List<RepairDiagnostic> get warnings =>
      diagnostics.where((d) => d.severity == DiagnosticSeverity.warning).toList();

  /// Format all diagnostics for AI prompt.
  String toPromptFormat() {
    if (diagnostics.isEmpty) return 'No issues found.';

    final buffer = StringBuffer();

    final errorList = errors;
    final warningList = warnings;

    if (errorList.isNotEmpty) {
      buffer.writeln('Errors (${errorList.length}):');
      for (var i = 0; i < errorList.length; i++) {
        buffer.writeln('${i + 1}. ${errorList[i].toPromptFormat()}');
      }
    }

    if (warningList.isNotEmpty) {
      if (errorList.isNotEmpty) buffer.writeln();
      buffer.writeln('Warnings (${warningList.length}):');
      for (var i = 0; i < warningList.length; i++) {
        buffer.writeln('${i + 1}. ${warningList[i].toPromptFormat()}');
      }
    }

    return buffer.toString();
  }

  /// Merge with another report.
  DiagnosticReport merge(DiagnosticReport other) {
    return DiagnosticReport([...diagnostics, ...other.diagnostics]);
  }

  @override
  String toString() => toPromptFormat();
}

/// Builder for creating diagnostics.
class DiagnosticBuilder {
  final List<RepairDiagnostic> _diagnostics = [];

  /// Add a missing node error.
  void missingNode(String nodeId, {String? referencedBy}) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.missingNode,
      message: 'Node "$nodeId" does not exist',
      location: referencedBy != null ? 'referenced by $referencedBy' : null,
      suggestions: [
        'Create the node using InsertNode before referencing it',
        'Check if the node ID is spelled correctly',
      ],
    ));
  }

  /// Add an orphaned node error.
  void orphanedNode(String nodeId) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.orphanedNode,
      message: 'Node "$nodeId" is not attached to any parent',
      location: nodeId,
      suggestions: [
        'Use AttachChild to attach the node to a parent',
        'Delete the node if it is not needed',
      ],
    ));
  }

  /// Add a cyclic reference error.
  void cyclicReference(List<String> cycle) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.cyclicReference,
      message: 'Circular parent-child relationship detected',
      actual: cycle.join(' → '),
      suggestions: [
        'Remove one of the parent-child relationships to break the cycle',
      ],
    ));
  }

  /// Add an invalid property path error.
  void invalidPropertyPath(String nodeId, String path) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.invalidPropertyPath,
      message: 'Invalid property path "$path"',
      location: nodeId,
      suggestions: [
        'Check that the path follows JSON Pointer format (e.g., /props/text)',
        'Verify the property exists for this node type',
      ],
    ));
  }

  /// Add a type mismatch error.
  void typeMismatch(String nodeId, String path, String expectedType, String actualType) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.typeMismatch,
      message: 'Type mismatch for property "$path"',
      location: nodeId,
      expected: expectedType,
      actual: actualType,
      suggestions: [
        'Convert the value to the correct type',
      ],
    ));
  }

  /// Add an invalid node reference error.
  void invalidNodeReference(String nodeId, String field) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.invalidNodeReference,
      message: 'Invalid node reference in "$field"',
      location: nodeId,
      suggestions: [
        'Ensure the referenced node exists',
        'Create the node before referencing it',
      ],
    ));
  }

  /// Add a DSL syntax error.
  void dslSyntaxError(int lineNumber, String message, {String? lineContent}) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.dslSyntaxError,
      message: message,
      location: 'line $lineNumber',
      actual: lineContent,
      suggestions: [
        'Check the DSL syntax reference',
        'Ensure proper formatting and quoting',
      ],
    ));
  }

  /// Add a DSL indentation error.
  void dslInvalidIndentation(int lineNumber, int expected, int actual) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.dslInvalidIndentation,
      message: 'Invalid indentation',
      location: 'line $lineNumber',
      expected: '$expected spaces (multiple of 2)',
      actual: '$actual spaces',
      suggestions: [
        'Use 2-space increments for indentation',
        'Align child nodes 2 spaces deeper than parents',
      ],
    ));
  }

  /// Add a DSL unknown node type error.
  void dslUnknownNodeType(int lineNumber, String nodeType) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.dslUnknownNodeType,
      message: 'Unknown node type "$nodeType"',
      location: 'line $lineNumber',
      suggestions: [
        'Use one of: container, row, column, text, img, icon, spacer, use',
      ],
    ));
  }

  /// Add a patch missing field error.
  void patchMissingField(String opType, String field, int index) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.patchMissingField,
      message: '$opType is missing required field "$field"',
      location: 'patch index $index',
      suggestions: [
        'Add the "$field" field to the $opType operation',
      ],
    ));
  }

  /// Add a patch invalid target error.
  void patchInvalidTarget(String opType, String targetId, int index) {
    _diagnostics.add(RepairDiagnostic(
      code: RepairErrorCode.patchInvalidTarget,
      message: '$opType references non-existent node "$targetId"',
      location: 'patch index $index',
      suggestions: [
        'Ensure InsertNode for "$targetId" appears before this operation',
        'Check if the node ID is spelled correctly',
      ],
    ));
  }

  /// Add a warning.
  void warning(RepairErrorCode code, String message, {String? location}) {
    _diagnostics.add(RepairDiagnostic(
      code: code,
      message: message,
      location: location,
      severity: DiagnosticSeverity.warning,
    ));
  }

  /// Build the diagnostic report.
  DiagnosticReport build() => DiagnosticReport(_diagnostics);
}
