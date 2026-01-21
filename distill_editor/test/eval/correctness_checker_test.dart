import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/eval/metrics/correctness_checker.dart';
import 'package:distill_editor/src/free_design/eval/eval_models.dart';

void main() {
  late CorrectnessChecker checker;

  setUp(() {
    checker = CorrectnessChecker();
  });

  group('CorrectnessChecker', () {
    group('parse tests', () {
      test('valid simple DSL parses successfully', () {
        const testCase = CorrectnessTestCase.parse(
          name: 'Simple container',
          input: '''dsl:1
frame Test
  container#root''',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
        expect(report.failures, isEmpty);
      });

      test('valid DSL with properties parses', () {
        const testCase = CorrectnessTestCase.parse(
          name: 'Container with props',
          input: '''dsl:1
frame Test
  container#root - w 200 h 100 bg #FF0000 r 8''',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
      });

      test('valid nested DSL parses', () {
        const testCase = CorrectnessTestCase.parse(
          name: 'Nested structure',
          input: '''dsl:1
frame Test
  column#root - gap 16
    text#a "Hello"
    text#b "World"''',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
      });
    });

    group('round-trip tests', () {
      test('simple container round-trips correctly', () {
        const testCase = CorrectnessTestCase.roundTrip(
          name: 'Simple container',
          input: '''dsl:1
frame Test
  container#root''',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
        expect(report.roundTripFidelity, 1.0);
      });

      test('container with size round-trips', () {
        const testCase = CorrectnessTestCase.roundTrip(
          name: 'Container with size',
          input: '''dsl:1
frame Test
  container#root - w 200 h 100''',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
      });

      test('column layout round-trips', () {
        const testCase = CorrectnessTestCase.roundTrip(
          name: 'Column layout',
          input: '''dsl:1
frame Test
  column#root - gap 16
    text#child "Hello"''',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
      });

      test('styled container round-trips', () {
        const testCase = CorrectnessTestCase.roundTrip(
          name: 'Styled container',
          input: '''dsl:1
frame Test
  container#root - bg #FF0000 r 8 border 1 #CCCCCC''',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
      });
    });

    group('expected error tests', () {
      test('missing version header fails', () {
        const testCase = CorrectnessTestCase.expectError(
          name: 'Missing version',
          input: '''frame Test
  container#root''',
          expectedError: 'version',
        );

        final report = checker.runAllChecks([testCase]);

        // Should pass because we expected an error and got one
        expect(report.passed, 1);
        expect(report.failed, 0);
      });

      test('invalid node type fails', () {
        const testCase = CorrectnessTestCase.expectError(
          name: 'Invalid type',
          input: '''dsl:1
frame Test
  invalidtype#root''',
          expectedError: 'Unknown node type',
        );

        final report = checker.runAllChecks([testCase]);

        expect(report.passed, 1);
        expect(report.failed, 0);
      });
    });

    group('multiple test cases', () {
      test('runs all test cases', () {
        const testCases = [
          CorrectnessTestCase.parse(
            name: 'Parse 1',
            input: '''dsl:1
frame Test1
  container#root''',
          ),
          CorrectnessTestCase.parse(
            name: 'Parse 2',
            input: '''dsl:1
frame Test2
  text#root "Hello"''',
          ),
          CorrectnessTestCase.roundTrip(
            name: 'Round-trip 1',
            input: '''dsl:1
frame Test3
  row#root - gap 8''',
          ),
        ];

        final report = checker.runAllChecks(testCases);

        expect(report.totalTests, 3);
        expect(report.passed, 3);
        expect(report.failed, 0);
      });

      test('calculates pass rate correctly', () {
        const testCases = [
          CorrectnessTestCase.parse(
            name: 'Valid',
            input: '''dsl:1
frame Test
  container#root''',
          ),
          CorrectnessTestCase.expectError(
            name: 'Invalid',
            input: '''dsl:1
frame Test
  badtype#root''',
            expectedError: 'Unknown',
          ),
        ];

        final report = checker.runAllChecks(testCases);

        expect(report.passRate, 1.0); // Both should pass (one parse, one expected error)
      });
    });

    group('verifyInvariants', () {
      test('valid DSL passes all invariants', () {
        const dsl = '''dsl:1
frame Test
  container#root''';

        final failures = checker.verifyInvariants(dsl);

        expect(failures, isEmpty);
      });

      test('missing version header fails invariant', () {
        const dsl = '''frame Test
  container#root''';

        final failures = checker.verifyInvariants(dsl);

        expect(failures.any((f) => f.message.contains('dsl:1')), isTrue);
      });

      test('missing frame declaration fails invariant', () {
        const dsl = '''dsl:1
  container#root''';

        final failures = checker.verifyInvariants(dsl);

        expect(failures.any((f) => f.message.contains('frame')), isTrue);
      });

      test('odd indentation fails invariant', () {
        const dsl = '''dsl:1
frame Test
   container#root'''; // 3-space indent

        final failures = checker.verifyInvariants(dsl);

        expect(failures.any((f) => f.message.contains('2-space')), isTrue);
      });
    });
  });

  group('CorrectnessTestCase', () {
    test('parse constructor sets correct type', () {
      const testCase = CorrectnessTestCase.parse(
        name: 'Test',
        input: 'dsl:1',
      );

      expect(testCase.type, CorrectnessTestType.parse);
      expect(testCase.expectedError, isNull);
    });

    test('roundTrip constructor sets correct type', () {
      const testCase = CorrectnessTestCase.roundTrip(
        name: 'Test',
        input: 'dsl:1',
      );

      expect(testCase.type, CorrectnessTestType.roundTrip);
    });

    test('expectError constructor sets correct type and error', () {
      const testCase = CorrectnessTestCase.expectError(
        name: 'Test',
        input: 'invalid',
        expectedError: 'expected error',
      );

      expect(testCase.type, CorrectnessTestType.parseError);
      expect(testCase.expectedError, 'expected error');
    });
  });

  group('CorrectnessReport', () {
    test('toJson produces valid map', () {
      const report = CorrectnessReport(
        totalTests: 10,
        passed: 8,
        failed: 2,
        passRate: 0.8,
        roundTripFidelity: 0.9,
        renderAccuracy: 1.0,
        parseSuccessRate: 0.95,
        failures: [],
      );

      final json = report.toJson();

      expect(json['totalTests'], 10);
      expect(json['passed'], 8);
      expect(json['failed'], 2);
      expect(json['passRate'], 0.8);
    });
  });
}
