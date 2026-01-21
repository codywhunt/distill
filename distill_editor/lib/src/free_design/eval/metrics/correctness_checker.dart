/// Correctness verification for DSL/IR/Render pipeline.
///
/// Verifies round-trip fidelity, parse correctness, and invariants.
library;

import '../../dsl/dsl_exporter.dart';
import '../../dsl/dsl_parser.dart';
import '../../models/editor_document.dart';
import '../../models/node.dart';
import '../../models/node_layout.dart';
import '../../models/node_style.dart';
import '../eval_models.dart';

/// Verifies correctness of the DSL/IR pipeline.
class CorrectnessChecker {
  final DslParser _parser;
  final DslExporter _exporter;

  CorrectnessChecker({
    DslParser? parser,
    DslExporter? exporter,
  })  : _parser = parser ?? DslParser(),
        _exporter = exporter ?? const DslExporter();

  /// Run all correctness checks and return a report.
  CorrectnessReport runAllChecks(List<CorrectnessTestCase> testCases) {
    final failures = <TestFailure>[];
    var parseSuccessCount = 0;
    var roundTripSuccessCount = 0;
    var totalParseTests = 0;
    var totalRoundTripTests = 0;

    for (final testCase in testCases) {
      switch (testCase.type) {
        case CorrectnessTestType.parse:
          totalParseTests++;
          final result = _runParseTest(testCase);
          if (result == null) {
            parseSuccessCount++;
          } else {
            failures.add(result);
          }

        case CorrectnessTestType.roundTrip:
          totalRoundTripTests++;
          final result = _runRoundTripTest(testCase);
          if (result == null) {
            roundTripSuccessCount++;
          } else {
            failures.add(result);
          }

        case CorrectnessTestType.parseError:
          totalParseTests++;
          final result = _runExpectedErrorTest(testCase);
          if (result == null) {
            parseSuccessCount++;
          } else {
            failures.add(result);
          }
      }
    }

    final totalTests = testCases.length;
    final passed = totalTests - failures.length;

    return CorrectnessReport(
      totalTests: totalTests,
      passed: passed,
      failed: failures.length,
      passRate: totalTests > 0 ? passed / totalTests : 1.0,
      roundTripFidelity: totalRoundTripTests > 0
          ? roundTripSuccessCount / totalRoundTripTests
          : 1.0,
      renderAccuracy: 1.0, // TODO: Implement render accuracy checks
      parseSuccessRate:
          totalParseTests > 0 ? parseSuccessCount / totalParseTests : 1.0,
      failures: failures,
    );
  }

  /// Test that valid DSL parses successfully.
  TestFailure? _runParseTest(CorrectnessTestCase testCase) {
    try {
      _parser.parse(testCase.input);
      return null; // Success
    } catch (e) {
      return TestFailure(
        testName: testCase.name,
        category: FailureCategory.parseError,
        message: e.toString(),
        input: testCase.input,
      );
    }
  }

  /// Test DSL→IR→DSL round-trip fidelity.
  TestFailure? _runRoundTripTest(CorrectnessTestCase testCase) {
    try {
      // Parse original DSL
      final result1 = _parser.parse(testCase.input);

      // Create document and export
      final doc = _createDocFromParseResult(result1);
      final exported = _exporter.exportFrame(doc, result1.frame.id);

      // Parse exported DSL
      final result2 = _parser.parse(exported);

      // Compare structures
      final diff = _compareParseResults(result1, result2);
      if (diff != null) {
        return TestFailure(
          testName: testCase.name,
          category: FailureCategory.roundTripMismatch,
          message: diff,
          input: testCase.input,
          expected: testCase.input,
          actual: exported,
        );
      }

      return null; // Success
    } catch (e) {
      return TestFailure(
        testName: testCase.name,
        category: FailureCategory.roundTripMismatch,
        message: e.toString(),
        input: testCase.input,
      );
    }
  }

  /// Test that invalid DSL produces expected error.
  TestFailure? _runExpectedErrorTest(CorrectnessTestCase testCase) {
    try {
      _parser.parse(testCase.input);
      // If we get here, parsing succeeded when it shouldn't have
      return TestFailure(
        testName: testCase.name,
        category: FailureCategory.parseError,
        message: 'Expected parse error but parsing succeeded',
        input: testCase.input,
        expected: testCase.expectedError ?? 'An error',
      );
    } catch (e) {
      // Check if error matches expected
      if (testCase.expectedError != null &&
          !e.toString().contains(testCase.expectedError!)) {
        return TestFailure(
          testName: testCase.name,
          category: FailureCategory.parseError,
          message: 'Wrong error message',
          input: testCase.input,
          expected: testCase.expectedError,
          actual: e.toString(),
        );
      }
      return null; // Success - got expected error
    }
  }

  EditorDocument _createDocFromParseResult(DslParseResult result) {
    return EditorDocument(
      documentId: 'test',
      frames: {result.frame.id: result.frame},
      nodes: result.nodes,
    );
  }

  /// Compare two parse results for semantic equality.
  String? _compareParseResults(DslParseResult a, DslParseResult b) {
    // Compare frame names
    if (a.frame.name != b.frame.name) {
      return 'Frame name mismatch: "${a.frame.name}" vs "${b.frame.name}"';
    }

    // Compare canvas size
    if (a.frame.canvas.size != b.frame.canvas.size) {
      return 'Canvas size mismatch: ${a.frame.canvas.size} vs ${b.frame.canvas.size}';
    }

    // Compare node counts
    if (a.nodes.length != b.nodes.length) {
      return 'Node count mismatch: ${a.nodes.length} vs ${b.nodes.length}';
    }

    // Compare individual nodes
    for (final nodeId in a.nodes.keys) {
      if (!b.nodes.containsKey(nodeId)) {
        return 'Missing node in round-trip: $nodeId';
      }

      final nodeA = a.nodes[nodeId]!;
      final nodeB = b.nodes[nodeId]!;

      final nodeDiff = _compareNodes(nodeA, nodeB);
      if (nodeDiff != null) {
        return 'Node $nodeId: $nodeDiff';
      }
    }

    return null; // No differences
  }

  /// Compare two nodes for semantic equality.
  String? _compareNodes(Node a, Node b) {
    if (a.type != b.type) {
      return 'Type mismatch: ${a.type} vs ${b.type}';
    }

    if (a.childIds.length != b.childIds.length) {
      return 'Child count mismatch: ${a.childIds.length} vs ${b.childIds.length}';
    }

    // Compare layout
    final layoutDiff = _compareLayouts(a.layout, b.layout);
    if (layoutDiff != null) return 'Layout: $layoutDiff';

    // Compare style
    final styleDiff = _compareStyles(a.style, b.style);
    if (styleDiff != null) return 'Style: $styleDiff';

    return null;
  }

  String? _compareLayouts(NodeLayout a, NodeLayout b) {
    if (a.size.width.runtimeType != b.size.width.runtimeType) {
      return 'Width type mismatch';
    }
    if (a.size.height.runtimeType != b.size.height.runtimeType) {
      return 'Height type mismatch';
    }
    if (a.position.runtimeType != b.position.runtimeType) {
      return 'Position type mismatch';
    }

    // Compare auto-layout
    final autoA = a.autoLayout;
    final autoB = b.autoLayout;
    if ((autoA == null) != (autoB == null)) {
      return 'Auto-layout presence mismatch';
    }
    if (autoA != null && autoB != null) {
      if (autoA.direction != autoB.direction) {
        return 'Direction mismatch: ${autoA.direction} vs ${autoB.direction}';
      }
      if (autoA.mainAlign != autoB.mainAlign) {
        return 'Main align mismatch';
      }
      if (autoA.crossAlign != autoB.crossAlign) {
        return 'Cross align mismatch';
      }
    }

    return null;
  }

  String? _compareStyles(NodeStyle a, NodeStyle b) {
    if ((a.fill == null) != (b.fill == null)) {
      return 'Fill presence mismatch';
    }
    if (a.opacity != b.opacity) {
      return 'Opacity mismatch: ${a.opacity} vs ${b.opacity}';
    }
    if (a.visible != b.visible) {
      return 'Visibility mismatch';
    }
    if ((a.cornerRadius == null) != (b.cornerRadius == null)) {
      return 'Corner radius presence mismatch';
    }
    if ((a.stroke == null) != (b.stroke == null)) {
      return 'Stroke presence mismatch';
    }

    return null;
  }

  /// Verify DSL invariants.
  List<TestFailure> verifyInvariants(String dsl) {
    final failures = <TestFailure>[];

    // Invariant 1: Version header format
    if (!dsl.startsWith('dsl:1')) {
      failures.add(const TestFailure(
        testName: 'Version Header',
        category: FailureCategory.invariantViolation,
        message: 'DSL must start with "dsl:1"',
      ));
    }

    // Invariant 2: Frame declaration exists
    if (!dsl.contains(RegExp(r'^frame\s', multiLine: true))) {
      failures.add(const TestFailure(
        testName: 'Frame Declaration',
        category: FailureCategory.invariantViolation,
        message: 'DSL must contain a frame declaration',
      ));
    }

    // Invariant 3: Proper indentation (2-space increments)
    final lines = dsl.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final leadingSpaces = line.length - line.trimLeft().length;
      if (leadingSpaces > 0 && leadingSpaces % 2 != 0) {
        failures.add(TestFailure(
          testName: 'Indentation',
          category: FailureCategory.invariantViolation,
          message: 'Line ${i + 1}: Indentation must be 2-space increments',
          input: line,
        ));
      }
    }

    return failures;
  }
}

/// A test case for correctness checking.
class CorrectnessTestCase {
  final String name;
  final String input;
  final CorrectnessTestType type;
  final String? expectedError;

  const CorrectnessTestCase({
    required this.name,
    required this.input,
    required this.type,
    this.expectedError,
  });

  /// Create a parse test case.
  const CorrectnessTestCase.parse({
    required this.name,
    required this.input,
  })  : type = CorrectnessTestType.parse,
        expectedError = null;

  /// Create a round-trip test case.
  const CorrectnessTestCase.roundTrip({
    required this.name,
    required this.input,
  })  : type = CorrectnessTestType.roundTrip,
        expectedError = null;

  /// Create an expected-error test case.
  const CorrectnessTestCase.expectError({
    required this.name,
    required this.input,
    this.expectedError,
  }) : type = CorrectnessTestType.parseError;
}

enum CorrectnessTestType {
  parse,
  roundTrip,
  parseError,
}
