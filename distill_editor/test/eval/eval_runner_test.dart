import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/eval/eval.dart';

void main() {
  late EvalRunner runner;

  setUp(() {
    runner = EvalRunner();
  });

  group('EvalRunner', () {
    group('runFullEvaluation', () {
      test('returns complete report', () async {
        final report = await runner.runFullEvaluation();

        expect(report.tokens, isNotNull);
        expect(report.expressiveness, isNotNull);
        expect(report.correctness, isNotNull);
        expect(report.timestamp, isNotNull);
        expect(report.gitCommit, isNotNull);
      });

      test('tokens metrics are populated', () async {
        final report = await runner.runFullEvaluation();

        expect(report.tokens.totalTokens, greaterThan(0));
        expect(report.tokens.tokenRatio, greaterThan(0));
        expect(report.tokens.avgTokensPerNode, greaterThan(0));
      });

      test('expressiveness report is populated', () async {
        final report = await runner.runFullEvaluation();

        expect(report.expressiveness.totalPatterns, greaterThan(0));
        expect(report.expressiveness.supportedPatterns, greaterThan(0));
        expect(report.expressiveness.coverage, greaterThan(0));
      });

      test('correctness report shows tests', () async {
        final report = await runner.runFullEvaluation();

        expect(report.correctness.totalTests, greaterThan(0));
        expect(report.correctness.passRate, greaterThanOrEqualTo(0));
      });

      test('can use custom samples', () async {
        const samples = [
          DslSample(
            name: 'Custom',
            dsl: '''dsl:1
frame Custom
  container#root''',
          ),
        ];

        final report = await runner.runFullEvaluation(tokenSamples: samples);

        expect(report.tokens.totalTokens, greaterThan(0));
      });

      test('can use custom correctness tests', () async {
        const tests = [
          CorrectnessTestCase.parse(
            name: 'Custom parse',
            input: '''dsl:1
frame Test
  container#root''',
          ),
        ];

        final report = await runner.runFullEvaluation(correctnessTests: tests);

        expect(report.correctness.totalTests, 1);
        expect(report.correctness.passed, 1);
      });
    });

    group('measureTokenEfficiency', () {
      test('calculates metrics for samples', () {
        const samples = [
          DslSample(
            name: 'Simple',
            dsl: '''dsl:1
frame Simple
  container#root - w 100 h 100''',
          ),
        ];

        final metrics = runner.measureTokenEfficiency(samples);

        expect(metrics.totalTokens, greaterThan(0));
        expect(metrics.tokenRatio, greaterThan(0));
        expect(metrics.tokenRatio, lessThan(1.0));
      });
    });

    group('checkExpressiveness', () {
      test('returns expressiveness report', () {
        final report = runner.checkExpressiveness();

        expect(report.totalPatterns, greaterThan(0));
        expect(report.coverage, greaterThan(0));
        expect(report.coverage, lessThanOrEqualTo(1.0));
      });
    });

    group('verifyCorrectness', () {
      test('runs correctness tests', () {
        const tests = [
          CorrectnessTestCase.parse(
            name: 'Test 1',
            input: '''dsl:1
frame Test
  container#root''',
          ),
          CorrectnessTestCase.roundTrip(
            name: 'Test 2',
            input: '''dsl:1
frame Test
  column#root - gap 16''',
          ),
        ];

        final report = runner.verifyCorrectness(tests);

        expect(report.totalTests, 2);
        expect(report.passed, 2);
        expect(report.passRate, 1.0);
      });
    });

    group('compareToBaseline', () {
      test('detects improvement in token efficiency', () async {
        final baseline = EvalReport(
          tokens: const TokenMetrics(
            totalTokens: 100,
            byConstruct: {},
            tokenRatio: 0.3,
            avgTokensPerNode: 10,
            tokensPerLine: 5,
          ),
          expressiveness: const ExpressivenessReport(
            totalPatterns: 50,
            supportedPatterns: 35,
            coverage: 0.7,
            gaps: [],
          ),
          correctness: const CorrectnessReport(
            totalTests: 10,
            passed: 10,
            failed: 0,
            passRate: 1.0,
            roundTripFidelity: 1.0,
            renderAccuracy: 1.0,
            parseSuccessRate: 1.0,
            failures: [],
          ),
          timestamp: DateTime.now(),
          gitCommit: 'baseline',
        );

        final current = EvalReport(
          tokens: const TokenMetrics(
            totalTokens: 90,
            byConstruct: {},
            tokenRatio: 0.25, // improved
            avgTokensPerNode: 9,
            tokensPerLine: 4.5,
          ),
          expressiveness: const ExpressivenessReport(
            totalPatterns: 50,
            supportedPatterns: 35,
            coverage: 0.7,
            gaps: [],
          ),
          correctness: const CorrectnessReport(
            totalTests: 10,
            passed: 10,
            failed: 0,
            passRate: 1.0,
            roundTripFidelity: 1.0,
            renderAccuracy: 1.0,
            parseSuccessRate: 1.0,
            failures: [],
          ),
          timestamp: DateTime.now(),
          gitCommit: 'current',
        );

        final comparison = runner.compareToBaseline(current, baseline);

        expect(comparison.tokenDelta.improved, isTrue);
        expect(comparison.tokenDelta.ratioChange, lessThan(0));
        expect(comparison.improved, isTrue);
      });

      test('detects regression in correctness', () async {
        final baseline = EvalReport(
          tokens: const TokenMetrics(
            totalTokens: 100,
            byConstruct: {},
            tokenRatio: 0.25,
            avgTokensPerNode: 10,
            tokensPerLine: 5,
          ),
          expressiveness: const ExpressivenessReport(
            totalPatterns: 50,
            supportedPatterns: 35,
            coverage: 0.7,
            gaps: [],
          ),
          correctness: const CorrectnessReport(
            totalTests: 10,
            passed: 10,
            failed: 0,
            passRate: 1.0,
            roundTripFidelity: 1.0,
            renderAccuracy: 1.0,
            parseSuccessRate: 1.0,
            failures: [],
          ),
          timestamp: DateTime.now(),
          gitCommit: 'baseline',
        );

        final current = EvalReport(
          tokens: const TokenMetrics(
            totalTokens: 90,
            byConstruct: {},
            tokenRatio: 0.22, // improved
            avgTokensPerNode: 9,
            tokensPerLine: 4.5,
          ),
          expressiveness: const ExpressivenessReport(
            totalPatterns: 50,
            supportedPatterns: 35,
            coverage: 0.7,
            gaps: [],
          ),
          correctness: const CorrectnessReport(
            totalTests: 10,
            passed: 8, // regressed!
            failed: 2,
            passRate: 0.8,
            roundTripFidelity: 0.9,
            renderAccuracy: 1.0,
            parseSuccessRate: 0.9,
            failures: [],
          ),
          timestamp: DateTime.now(),
          gitCommit: 'current',
        );

        final comparison = runner.compareToBaseline(current, baseline);

        expect(comparison.correctnessDelta.regressed, isTrue);
        expect(comparison.improved, isFalse); // Regression blocks improvement
      });
    });
  });

  group('EvalReport', () {
    test('toJson produces valid map', () async {
      final report = await runner.runFullEvaluation();
      final json = report.toJson();

      expect(json['tokens'], isNotNull);
      expect(json['expressiveness'], isNotNull);
      expect(json['correctness'], isNotNull);
      expect(json['timestamp'], isNotNull);
      expect(json['gitCommit'], isNotNull);
    });

    test('toPrettyJson produces formatted string', () async {
      final report = await runner.runFullEvaluation();
      final json = report.toPrettyJson();

      expect(json, contains('"tokens"'));
      expect(json, contains('"expressiveness"'));
      expect(json, contains('"correctness"'));
    });

    test('fromJson round-trips correctly', () async {
      final original = await runner.runFullEvaluation();
      final json = original.toJson();
      final restored = EvalReport.fromJson(json);

      expect(restored.tokens.totalTokens, original.tokens.totalTokens);
      expect(restored.expressiveness.coverage, original.expressiveness.coverage);
      expect(restored.correctness.passRate, original.correctness.passRate);
      expect(restored.gitCommit, original.gitCommit);
    });
  });
}
