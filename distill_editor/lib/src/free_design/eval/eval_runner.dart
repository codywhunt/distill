/// Evaluation runner for the self-improving loop.
///
/// This is the main CLI entry point for running evaluations.
/// Run with: dart run lib/src/free_design/eval/eval_runner.dart --json
library;

import 'dart:convert';
import 'dart:io';

import 'eval_models.dart';
import 'metrics/token_counter.dart';
import 'metrics/expressiveness_scorer.dart';
import 'metrics/correctness_checker.dart';

/// Main evaluation runner that orchestrates all metrics.
class EvalRunner {
  final TokenCounter _tokenCounter;
  final ExpressivenessScorer _expressivenessScorer;
  final CorrectnessChecker _correctnessChecker;

  EvalRunner({
    TokenCounter? tokenCounter,
    ExpressivenessScorer? expressivenessScorer,
    CorrectnessChecker? correctnessChecker,
  })  : _tokenCounter = tokenCounter ?? const TokenCounter(),
        _expressivenessScorer =
            expressivenessScorer ?? const ExpressivenessScorer(),
        _correctnessChecker = correctnessChecker ?? CorrectnessChecker();

  /// Run full evaluation suite.
  Future<EvalReport> runFullEvaluation({
    List<DslSample>? tokenSamples,
    List<CorrectnessTestCase>? correctnessTests,
  }) async {
    // Get git commit hash
    final gitCommit = await _getGitCommit();

    // Run token efficiency evaluation
    final tokenMetrics = measureTokenEfficiency(
      tokenSamples ?? _getDefaultTokenSamples(),
    );

    // Run expressiveness evaluation
    final expressivenessReport = checkExpressiveness();

    // Run correctness evaluation
    final correctnessReport = verifyCorrectness(
      correctnessTests ?? _getDefaultCorrectnessTests(),
    );

    return EvalReport(
      tokens: tokenMetrics,
      expressiveness: expressivenessReport,
      correctness: correctnessReport,
      timestamp: DateTime.now(),
      gitCommit: gitCommit,
    );
  }

  /// Measure token efficiency for DSL samples.
  TokenMetrics measureTokenEfficiency(List<DslSample> samples) {
    return _tokenCounter.calculateMetrics(samples);
  }

  /// Check DSL expressiveness against pattern catalog.
  ExpressivenessReport checkExpressiveness() {
    return _expressivenessScorer.evaluate();
  }

  /// Verify correctness with test cases.
  CorrectnessReport verifyCorrectness(List<CorrectnessTestCase> testCases) {
    return _correctnessChecker.runAllChecks(testCases);
  }

  /// Compare current report to baseline.
  EvalComparison compareToBaseline(EvalReport current, EvalReport baseline) {
    final tokenDelta = TokenDelta(
      tokenChange: current.tokens.totalTokens - baseline.tokens.totalTokens,
      ratioChange: current.tokens.tokenRatio - baseline.tokens.tokenRatio,
      improved: current.tokens.tokenRatio < baseline.tokens.tokenRatio,
    );

    final expressivenessDelta = ExpressivenessDelta(
      patternChange: current.expressiveness.supportedPatterns -
          baseline.expressiveness.supportedPatterns,
      coverageChange:
          current.expressiveness.coverage - baseline.expressiveness.coverage,
      improved:
          current.expressiveness.coverage > baseline.expressiveness.coverage,
    );

    final correctnessDelta = CorrectnessDelta(
      passedChange: current.correctness.passed - baseline.correctness.passed,
      fidelityChange: current.correctness.roundTripFidelity -
          baseline.correctness.roundTripFidelity,
      improved: current.correctness.passRate > baseline.correctness.passRate,
      regressed: current.correctness.passRate < baseline.correctness.passRate,
    );

    // Overall improvement: better or same correctness, and improvement elsewhere
    final improved = !correctnessDelta.regressed &&
        (tokenDelta.improved || expressivenessDelta.improved);

    return EvalComparison(
      baseline: baseline,
      current: current,
      tokenDelta: tokenDelta,
      expressivenessDelta: expressivenessDelta,
      correctnessDelta: correctnessDelta,
      improved: improved,
    );
  }

  Future<String> _getGitCommit() async {
    try {
      final result = await Process.run('git', ['rev-parse', '--short', 'HEAD']);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return 'unknown';
  }

  /// Default DSL samples for token efficiency testing.
  List<DslSample> _getDefaultTokenSamples() {
    return const [
      // Simple layout
      DslSample(
        name: 'Simple Container',
        category: 'simple',
        dsl: '''dsl:1
frame SimpleContainer
  container#root - w 100 h 100 bg #FFFFFF''',
      ),

      // Column layout
      DslSample(
        name: 'Vertical Stack',
        category: 'simple',
        dsl: '''dsl:1
frame VerticalStack
  column#root - gap 16 pad 24
    text#title "Hello"
    text#subtitle "World"''',
      ),

      // Row layout
      DslSample(
        name: 'Horizontal Stack',
        category: 'simple',
        dsl: '''dsl:1
frame HorizontalStack
  row#root - gap 12 align center,center
    icon#icon "home"
    text#label "Home"''',
      ),

      // Form-like layout
      DslSample(
        name: 'Login Form',
        category: 'complex',
        dsl: '''dsl:1
frame LoginForm
  column#root - gap 24 pad 24 bg #FFFFFF w fill h fill
    text#title "Welcome Back" - size 24 weight 700 color #000000
    column#fields - gap 16
      text#email_label "Email" - size 14 weight 500 color #666666
      container#email_input - h 48 pad 12 bg #F5F5F5 r 8
        text#email_placeholder "email@example.com" - size 16 color #999999
      text#password_label "Password" - size 14 weight 500 color #666666
      container#password_input - h 48 pad 12 bg #F5F5F5 r 8
        text#password_placeholder "Enter password" - size 16 color #999999
    container#submit - h 48 bg #007AFF r 8 align center,center
      text#submit_text "Sign In" - size 16 weight 600 color #FFFFFF''',
      ),

      // Nested components
      DslSample(
        name: 'Card Layout',
        category: 'nested',
        dsl: '''dsl:1
frame Card
  container#card - pad 16 bg #FFFFFF r 12 shadow 0,4,12,0 #00000020
    column#content - gap 12
      img#image "https://example.com/img.jpg" - w fill h 200 fit cover r 8
      text#title "Card Title" - size 18 weight 600
      text#description "This is a description" - size 14 color #666666
      row#footer - gap 8 align end,center
        text#price "\$99" - size 16 weight 700 color #007AFF
        container#button - pad 8,16 bg #007AFF r 6
          text#button_text "Buy" - size 14 weight 600 color #FFFFFF''',
      ),

      // Absolute positioning
      DslSample(
        name: 'Overlay Layout',
        category: 'absolute',
        dsl: '''dsl:1
frame Overlay
  container#root - w fill h fill
    img#background "bg.jpg" - w fill h fill fit cover
    container#overlay - pos abs x 0 y 0 w fill h fill bg #00000080
    column#content - pos abs x 24 y 100 gap 16
      text#title "Welcome" - size 32 weight 700 color #FFFFFF
      text#subtitle "Start your journey" - size 16 color #FFFFFFCC''',
      ),
    ];
  }

  /// Default correctness test cases.
  List<CorrectnessTestCase> _getDefaultCorrectnessTests() {
    return const [
      // Basic parsing tests
      CorrectnessTestCase.parse(
        name: 'Parse simple container',
        input: '''dsl:1
frame Test
  container#root''',
      ),
      CorrectnessTestCase.parse(
        name: 'Parse column with gap',
        input: '''dsl:1
frame Test
  column#root - gap 16''',
      ),
      CorrectnessTestCase.parse(
        name: 'Parse text with content',
        input: '''dsl:1
frame Test
  text#t "Hello World"''',
      ),
      CorrectnessTestCase.parse(
        name: 'Parse with all layout props',
        input: '''dsl:1
frame Test
  container#root - w 200 h 100 pad 16 bg #FF0000 r 8''',
      ),

      // Round-trip tests
      CorrectnessTestCase.roundTrip(
        name: 'Round-trip simple frame',
        input: '''dsl:1
frame Test
  container#root''',
      ),
      CorrectnessTestCase.roundTrip(
        name: 'Round-trip column layout',
        input: '''dsl:1
frame Test
  column#root - gap 16 pad 24
    text#child "Hello"''',
      ),
      CorrectnessTestCase.roundTrip(
        name: 'Round-trip with styles',
        input: '''dsl:1
frame Test
  container#root - w 200 h 100 bg #FF5500 r 8 border 1 #CCCCCC''',
      ),
      CorrectnessTestCase.roundTrip(
        name: 'Round-trip nested structure',
        input: '''dsl:1
frame Test
  column#root - gap 16
    row#row1 - gap 8
      text#a "A"
      text#b "B"
    row#row2 - gap 8
      text#c "C"
      text#d "D"''',
      ),

      // Error tests
      CorrectnessTestCase.expectError(
        name: 'Missing version header',
        input: '''frame Test
  container#root''',
        expectedError: 'version',
      ),
      CorrectnessTestCase.expectError(
        name: 'Invalid node type',
        input: '''dsl:1
frame Test
  invalidtype#root''',
        expectedError: 'Unknown node type',
      ),
    ];
  }
}

// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

/// CLI entry point.
Future<void> main(List<String> args) async {
  final runner = EvalRunner();
  final jsonOutput = args.contains('--json');
  final verbose = args.contains('--verbose') || args.contains('-v');

  try {
    final report = await runner.runFullEvaluation();

    if (jsonOutput) {
      print(report.toPrettyJson());
    } else {
      _printReport(report, verbose: verbose);
    }
  } catch (e, st) {
    if (jsonOutput) {
      print(jsonEncode({
        'error': e.toString(),
        'stackTrace': st.toString(),
      }));
    } else {
      stderr.writeln('Evaluation failed: $e');
      if (verbose) stderr.writeln(st);
    }
    exit(1);
  }
}

void _printReport(EvalReport report, {bool verbose = false}) {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║              DSL EVALUATION REPORT                           ║');
  print('╠══════════════════════════════════════════════════════════════╣');
  print('║ Timestamp: ${report.timestamp.toIso8601String().padRight(39)}║');
  print('║ Git Commit: ${report.gitCommit.padRight(38)}║');
  print('╠══════════════════════════════════════════════════════════════╣');

  // Token Efficiency
  print('║ TOKEN EFFICIENCY                                             ║');
  print('╟──────────────────────────────────────────────────────────────╢');
  print('║ Total Tokens: ${report.tokens.totalTokens.toString().padRight(35)}║');
  print('║ Token Ratio (DSL/JSON): ${report.tokens.tokenRatio.toStringAsFixed(3).padRight(25)}║');
  print('║ Avg Tokens/Node: ${report.tokens.avgTokensPerNode.toStringAsFixed(2).padRight(32)}║');
  print('║ Tokens/Line: ${report.tokens.tokensPerLine.toStringAsFixed(2).padRight(37)}║');

  // Expressiveness
  print('╠══════════════════════════════════════════════════════════════╣');
  print('║ EXPRESSIVENESS                                               ║');
  print('╟──────────────────────────────────────────────────────────────╢');
  print('║ Pattern Coverage: ${(report.expressiveness.coverage * 100).toStringAsFixed(1)}% (${report.expressiveness.supportedPatterns}/${report.expressiveness.totalPatterns})'.padRight(63) + '║');

  if (verbose && report.expressiveness.gaps.isNotEmpty) {
    print('║ Top Gaps:                                                    ║');
    for (final gap in report.expressiveness.gaps.take(5)) {
      print('║   - ${gap.name} (${gap.priority.name})'.padRight(63) + '║');
    }
  }

  // Correctness
  print('╠══════════════════════════════════════════════════════════════╣');
  print('║ CORRECTNESS                                                  ║');
  print('╟──────────────────────────────────────────────────────────────╢');
  print('║ Tests: ${report.correctness.passed}/${report.correctness.totalTests} passed (${(report.correctness.passRate * 100).toStringAsFixed(1)}%)'.padRight(63) + '║');
  print('║ Round-Trip Fidelity: ${(report.correctness.roundTripFidelity * 100).toStringAsFixed(1)}%'.padRight(63) + '║');
  print('║ Parse Success Rate: ${(report.correctness.parseSuccessRate * 100).toStringAsFixed(1)}%'.padRight(63) + '║');

  if (verbose && report.correctness.failures.isNotEmpty) {
    print('║ Failures:                                                    ║');
    for (final failure in report.correctness.failures.take(5)) {
      print('║   - ${failure.testName}: ${failure.message}'.padRight(63).substring(0, 63) + '║');
    }
  }

  print('╚══════════════════════════════════════════════════════════════╝');
}
