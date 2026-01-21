/// Models for the self-improving evaluation harness.
///
/// These models track metrics for token efficiency, expressiveness,
/// and correctness of the DSL/IR/Rendering pipeline.
library;

import 'dart:convert';

/// Complete evaluation report with all metrics.
class EvalReport {
  final TokenMetrics tokens;
  final ExpressivenessReport expressiveness;
  final CorrectnessReport correctness;
  final DateTime timestamp;
  final String gitCommit;

  const EvalReport({
    required this.tokens,
    required this.expressiveness,
    required this.correctness,
    required this.timestamp,
    required this.gitCommit,
  });

  Map<String, dynamic> toJson() => {
        'tokens': tokens.toJson(),
        'expressiveness': expressiveness.toJson(),
        'correctness': correctness.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'gitCommit': gitCommit,
      };

  factory EvalReport.fromJson(Map<String, dynamic> json) => EvalReport(
        tokens: TokenMetrics.fromJson(json['tokens'] as Map<String, dynamic>),
        expressiveness: ExpressivenessReport.fromJson(
            json['expressiveness'] as Map<String, dynamic>),
        correctness: CorrectnessReport.fromJson(
            json['correctness'] as Map<String, dynamic>),
        timestamp: DateTime.parse(json['timestamp'] as String),
        gitCommit: json['gitCommit'] as String,
      );

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Token efficiency metrics.
class TokenMetrics {
  /// Total tokens across all DSL samples.
  final int totalTokens;

  /// Token count per DSL construct type.
  final Map<String, ConstructTokens> byConstruct;

  /// DSL tokens / equivalent JSON tokens ratio.
  /// Lower is better; target is <0.25.
  final double tokenRatio;

  /// Average tokens per node.
  final double avgTokensPerNode;

  /// Tokens per line of DSL.
  final double tokensPerLine;

  const TokenMetrics({
    required this.totalTokens,
    required this.byConstruct,
    required this.tokenRatio,
    required this.avgTokensPerNode,
    required this.tokensPerLine,
  });

  Map<String, dynamic> toJson() => {
        'totalTokens': totalTokens,
        'byConstruct':
            byConstruct.map((k, v) => MapEntry(k, v.toJson())),
        'tokenRatio': tokenRatio,
        'avgTokensPerNode': avgTokensPerNode,
        'tokensPerLine': tokensPerLine,
      };

  factory TokenMetrics.fromJson(Map<String, dynamic> json) => TokenMetrics(
        totalTokens: json['totalTokens'] as int,
        byConstruct: (json['byConstruct'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, ConstructTokens.fromJson(v as Map<String, dynamic>)),
        ),
        tokenRatio: (json['tokenRatio'] as num).toDouble(),
        avgTokensPerNode: (json['avgTokensPerNode'] as num).toDouble(),
        tokensPerLine: (json['tokensPerLine'] as num).toDouble(),
      );
}

/// Token breakdown for a specific DSL construct.
class ConstructTokens {
  final String constructType;
  final int occurrences;
  final int totalTokens;
  final double avgTokens;

  const ConstructTokens({
    required this.constructType,
    required this.occurrences,
    required this.totalTokens,
    required this.avgTokens,
  });

  Map<String, dynamic> toJson() => {
        'constructType': constructType,
        'occurrences': occurrences,
        'totalTokens': totalTokens,
        'avgTokens': avgTokens,
      };

  factory ConstructTokens.fromJson(Map<String, dynamic> json) =>
      ConstructTokens(
        constructType: json['constructType'] as String,
        occurrences: json['occurrences'] as int,
        totalTokens: json['totalTokens'] as int,
        avgTokens: (json['avgTokens'] as num).toDouble(),
      );
}

/// Expressiveness evaluation report.
class ExpressivenessReport {
  /// Total UI patterns in the catalog.
  final int totalPatterns;

  /// Patterns that can be expressed in current DSL.
  final int supportedPatterns;

  /// Coverage percentage (supportedPatterns / totalPatterns).
  final double coverage;

  /// Patterns that cannot be expressed.
  final List<UnsupportedPattern> gaps;

  const ExpressivenessReport({
    required this.totalPatterns,
    required this.supportedPatterns,
    required this.coverage,
    required this.gaps,
  });

  Map<String, dynamic> toJson() => {
        'totalPatterns': totalPatterns,
        'supportedPatterns': supportedPatterns,
        'coverage': coverage,
        'gaps': gaps.map((g) => g.toJson()).toList(),
      };

  factory ExpressivenessReport.fromJson(Map<String, dynamic> json) =>
      ExpressivenessReport(
        totalPatterns: json['totalPatterns'] as int,
        supportedPatterns: json['supportedPatterns'] as int,
        coverage: (json['coverage'] as num).toDouble(),
        gaps: (json['gaps'] as List)
            .map((g) => UnsupportedPattern.fromJson(g as Map<String, dynamic>))
            .toList(),
      );
}

/// A UI pattern that cannot be expressed in current DSL.
class UnsupportedPattern {
  final String patternId;
  final String name;
  final String category;
  final String description;
  final PatternPriority priority;

  const UnsupportedPattern({
    required this.patternId,
    required this.name,
    required this.category,
    required this.description,
    required this.priority,
  });

  Map<String, dynamic> toJson() => {
        'patternId': patternId,
        'name': name,
        'category': category,
        'description': description,
        'priority': priority.name,
      };

  factory UnsupportedPattern.fromJson(Map<String, dynamic> json) =>
      UnsupportedPattern(
        patternId: json['patternId'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        priority: PatternPriority.values.byName(json['priority'] as String),
      );
}

enum PatternPriority { critical, high, medium, low }

/// Correctness evaluation report.
class CorrectnessReport {
  /// Total tests run.
  final int totalTests;

  /// Tests that passed.
  final int passed;

  /// Tests that failed.
  final int failed;

  /// Pass rate (passed / totalTests).
  final double passRate;

  /// DSL→IR→DSL round-trip fidelity (percentage).
  final double roundTripFidelity;

  /// IR→Widget render accuracy (percentage).
  final double renderAccuracy;

  /// Parse success rate (percentage).
  final double parseSuccessRate;

  /// Details of any failures.
  final List<TestFailure> failures;

  const CorrectnessReport({
    required this.totalTests,
    required this.passed,
    required this.failed,
    required this.passRate,
    required this.roundTripFidelity,
    required this.renderAccuracy,
    required this.parseSuccessRate,
    required this.failures,
  });

  Map<String, dynamic> toJson() => {
        'totalTests': totalTests,
        'passed': passed,
        'failed': failed,
        'passRate': passRate,
        'roundTripFidelity': roundTripFidelity,
        'renderAccuracy': renderAccuracy,
        'parseSuccessRate': parseSuccessRate,
        'failures': failures.map((f) => f.toJson()).toList(),
      };

  factory CorrectnessReport.fromJson(Map<String, dynamic> json) =>
      CorrectnessReport(
        totalTests: json['totalTests'] as int,
        passed: json['passed'] as int,
        failed: json['failed'] as int,
        passRate: (json['passRate'] as num).toDouble(),
        roundTripFidelity: (json['roundTripFidelity'] as num).toDouble(),
        renderAccuracy: (json['renderAccuracy'] as num).toDouble(),
        parseSuccessRate: (json['parseSuccessRate'] as num).toDouble(),
        failures: (json['failures'] as List)
            .map((f) => TestFailure.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

/// Details of a test failure.
class TestFailure {
  final String testName;
  final FailureCategory category;
  final String message;
  final String? input;
  final String? expected;
  final String? actual;

  const TestFailure({
    required this.testName,
    required this.category,
    required this.message,
    this.input,
    this.expected,
    this.actual,
  });

  Map<String, dynamic> toJson() => {
        'testName': testName,
        'category': category.name,
        'message': message,
        if (input != null) 'input': input,
        if (expected != null) 'expected': expected,
        if (actual != null) 'actual': actual,
      };

  factory TestFailure.fromJson(Map<String, dynamic> json) => TestFailure(
        testName: json['testName'] as String,
        category: FailureCategory.values.byName(json['category'] as String),
        message: json['message'] as String,
        input: json['input'] as String?,
        expected: json['expected'] as String?,
        actual: json['actual'] as String?,
      );
}

enum FailureCategory {
  parseError,
  roundTripMismatch,
  renderError,
  invariantViolation,
  tokenResolutionError,
}

/// Comparison between two evaluation reports.
class EvalComparison {
  final EvalReport baseline;
  final EvalReport current;
  final TokenDelta tokenDelta;
  final ExpressivenessDelta expressivenessDelta;
  final CorrectnessDelta correctnessDelta;
  final bool improved;

  const EvalComparison({
    required this.baseline,
    required this.current,
    required this.tokenDelta,
    required this.expressivenessDelta,
    required this.correctnessDelta,
    required this.improved,
  });

  Map<String, dynamic> toJson() => {
        'baseline': baseline.toJson(),
        'current': current.toJson(),
        'tokenDelta': tokenDelta.toJson(),
        'expressivenessDelta': expressivenessDelta.toJson(),
        'correctnessDelta': correctnessDelta.toJson(),
        'improved': improved,
      };
}

/// Change in token metrics.
class TokenDelta {
  final int tokenChange;
  final double ratioChange;
  final bool improved;

  const TokenDelta({
    required this.tokenChange,
    required this.ratioChange,
    required this.improved,
  });

  Map<String, dynamic> toJson() => {
        'tokenChange': tokenChange,
        'ratioChange': ratioChange,
        'improved': improved,
      };
}

/// Change in expressiveness metrics.
class ExpressivenessDelta {
  final int patternChange;
  final double coverageChange;
  final bool improved;

  const ExpressivenessDelta({
    required this.patternChange,
    required this.coverageChange,
    required this.improved,
  });

  Map<String, dynamic> toJson() => {
        'patternChange': patternChange,
        'coverageChange': coverageChange,
        'improved': improved,
      };
}

/// Change in correctness metrics.
class CorrectnessDelta {
  final int passedChange;
  final double fidelityChange;
  final bool improved;
  final bool regressed;

  const CorrectnessDelta({
    required this.passedChange,
    required this.fidelityChange,
    required this.improved,
    required this.regressed,
  });

  Map<String, dynamic> toJson() => {
        'passedChange': passedChange,
        'fidelityChange': fidelityChange,
        'improved': improved,
        'regressed': regressed,
      };
}

/// Hypothesis for an improvement.
class ImprovementHypothesis {
  final String id;
  final ImprovementCategory category;
  final String description;
  final String rationale;
  final List<String> targetFiles;
  final RiskLevel risk;
  final double expectedImpact;
  final List<String> invariants;

  const ImprovementHypothesis({
    required this.id,
    required this.category,
    required this.description,
    required this.rationale,
    required this.targetFiles,
    required this.risk,
    required this.expectedImpact,
    required this.invariants,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'description': description,
        'rationale': rationale,
        'targetFiles': targetFiles,
        'risk': risk.name,
        'expectedImpact': expectedImpact,
        'invariants': invariants,
      };

  factory ImprovementHypothesis.fromJson(Map<String, dynamic> json) =>
      ImprovementHypothesis(
        id: json['id'] as String,
        category:
            ImprovementCategory.values.byName(json['category'] as String),
        description: json['description'] as String,
        rationale: json['rationale'] as String,
        targetFiles:
            (json['targetFiles'] as List).cast<String>(),
        risk: RiskLevel.values.byName(json['risk'] as String),
        expectedImpact: (json['expectedImpact'] as num).toDouble(),
        invariants: (json['invariants'] as List).cast<String>(),
      );
}

enum ImprovementCategory {
  tokenEfficiency,
  expressiveness,
  correctness,
}

enum RiskLevel { low, medium, high }

/// Loop iteration history entry.
class IterationRecord {
  final String id;
  final String hypothesis;
  final IterationOutcome outcome;
  final double? deltaTokens;
  final double? deltaCoverage;
  final String? commit;
  final DateTime timestamp;
  final List<String> learnings;

  const IterationRecord({
    required this.id,
    required this.hypothesis,
    required this.outcome,
    this.deltaTokens,
    this.deltaCoverage,
    this.commit,
    required this.timestamp,
    this.learnings = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hypothesis': hypothesis,
        'outcome': outcome.name,
        if (deltaTokens != null) 'deltaTokens': deltaTokens,
        if (deltaCoverage != null) 'deltaCoverage': deltaCoverage,
        if (commit != null) 'commit': commit,
        'timestamp': timestamp.toIso8601String(),
        'learnings': learnings,
      };

  factory IterationRecord.fromJson(Map<String, dynamic> json) =>
      IterationRecord(
        id: json['id'] as String,
        hypothesis: json['hypothesis'] as String,
        outcome: IterationOutcome.values.byName(json['outcome'] as String),
        deltaTokens: (json['deltaTokens'] as num?)?.toDouble(),
        deltaCoverage: (json['deltaCoverage'] as num?)?.toDouble(),
        commit: json['commit'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        learnings: (json['learnings'] as List?)?.cast<String>() ?? [],
      );
}

enum IterationOutcome {
  improved,
  noChange,
  regressed,
  failed,
}

/// Persistent loop state.
class LoopState {
  final LoopStatus status;
  final int iteration;
  final ImprovementHypothesis? currentHypothesis;
  final BaselineMetrics baseline;
  final List<IterationRecord> history;
  final List<String> learnings;

  const LoopState({
    required this.status,
    required this.iteration,
    this.currentHypothesis,
    required this.baseline,
    required this.history,
    required this.learnings,
  });

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'iteration': iteration,
        if (currentHypothesis != null)
          'currentHypothesis': currentHypothesis!.toJson(),
        'baseline': baseline.toJson(),
        'history': history.map((h) => h.toJson()).toList(),
        'learnings': learnings,
      };

  factory LoopState.fromJson(Map<String, dynamic> json) => LoopState(
        status: LoopStatus.values.byName(json['status'] as String),
        iteration: json['iteration'] as int,
        currentHypothesis: json['currentHypothesis'] != null
            ? ImprovementHypothesis.fromJson(
                json['currentHypothesis'] as Map<String, dynamic>)
            : null,
        baseline:
            BaselineMetrics.fromJson(json['baseline'] as Map<String, dynamic>),
        history: (json['history'] as List)
            .map((h) => IterationRecord.fromJson(h as Map<String, dynamic>))
            .toList(),
        learnings: (json['learnings'] as List).cast<String>(),
      );

  LoopState copyWith({
    LoopStatus? status,
    int? iteration,
    ImprovementHypothesis? currentHypothesis,
    bool clearHypothesis = false,
    BaselineMetrics? baseline,
    List<IterationRecord>? history,
    List<String>? learnings,
  }) =>
      LoopState(
        status: status ?? this.status,
        iteration: iteration ?? this.iteration,
        currentHypothesis:
            clearHypothesis ? null : (currentHypothesis ?? this.currentHypothesis),
        baseline: baseline ?? this.baseline,
        history: history ?? this.history,
        learnings: learnings ?? this.learnings,
      );

  static LoopState initial() => LoopState(
        status: LoopStatus.idle,
        iteration: 0,
        baseline: const BaselineMetrics(
          tokenEfficiency: 0.0,
          patternCoverage: 0.0,
          roundTripFidelity: 0.0,
          testsPassing: 0,
        ),
        history: const [],
        learnings: const [],
      );

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}

enum LoopStatus {
  idle,
  evaluating,
  critiquing,
  proposing,
  implementing,
  verifying,
  committing,
  paused,
  failed,
}

/// Summary baseline metrics for comparison.
class BaselineMetrics {
  final double tokenEfficiency;
  final double patternCoverage;
  final double roundTripFidelity;
  final int testsPassing;

  const BaselineMetrics({
    required this.tokenEfficiency,
    required this.patternCoverage,
    required this.roundTripFidelity,
    required this.testsPassing,
  });

  Map<String, dynamic> toJson() => {
        'tokenEfficiency': tokenEfficiency,
        'patternCoverage': patternCoverage,
        'roundTripFidelity': roundTripFidelity,
        'testsPassing': testsPassing,
      };

  factory BaselineMetrics.fromJson(Map<String, dynamic> json) =>
      BaselineMetrics(
        tokenEfficiency: (json['tokenEfficiency'] as num).toDouble(),
        patternCoverage: (json['patternCoverage'] as num).toDouble(),
        roundTripFidelity: (json['roundTripFidelity'] as num).toDouble(),
        testsPassing: json['testsPassing'] as int,
      );
}
