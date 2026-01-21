import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/eval/metrics/token_counter.dart';

void main() {
  const counter = TokenCounter();

  group('TokenCounter', () {
    group('countTokens', () {
      test('counts empty string as 0 tokens', () {
        expect(counter.countTokens(''), 0);
      });

      test('counts single word', () {
        final count = counter.countTokens('hello');
        expect(count, greaterThan(0));
      });

      test('counts simple DSL line', () {
        final count = counter.countTokens('container#root');
        expect(count, greaterThan(0));
      });

      test('counts DSL with properties', () {
        final count = counter.countTokens('container#root - w 100 h 100');
        expect(count, greaterThan(5)); // Should have multiple tokens
      });

      test('counts multi-line DSL', () {
        const dsl = '''dsl:1
frame Test
  container#root''';
        final count = counter.countTokens(dsl);
        expect(count, greaterThan(5));
      });

      test('punctuation becomes separate tokens', () {
        // "#" should be its own token
        final countWithHash = counter.countTokens('container#root');
        final countWithoutHash = counter.countTokens('containerroot');
        expect(countWithHash, greaterThan(countWithoutHash));
      });
    });

    group('analyze', () {
      test('analyzes simple DSL', () {
        const dsl = '''dsl:1
frame Test
  container#root''';

        final analysis = counter.analyze(dsl);

        expect(analysis.totalTokens, greaterThan(0));
        expect(analysis.totalLines, 3);
        expect(analysis.totalNodes, 1);
        expect(analysis.constructCounts, contains('container'));
      });

      test('counts multiple node types', () {
        const dsl = '''dsl:1
frame Test
  column#root - gap 16
    text#a "Hello"
    text#b "World"''';

        final analysis = counter.analyze(dsl);

        expect(analysis.totalNodes, 3);
        expect(analysis.constructCounts['column'], 1);
        expect(analysis.constructCounts['text'], 2);
      });

      test('counts properties', () {
        const dsl = '''dsl:1
frame Test
  container#root - w 100 h 100 bg #FF0000 r 8''';

        final analysis = counter.analyze(dsl);

        expect(analysis.constructCounts['prop:w'], 1);
        expect(analysis.constructCounts['prop:h'], 1);
        expect(analysis.constructCounts['prop:bg'], 1);
        expect(analysis.constructCounts['prop:r'], 1);
      });

      test('calculates tokens per node', () {
        const dsl = '''dsl:1
frame Test
  column#root - gap 16
    text#a "Hello"
    text#b "World"''';

        final analysis = counter.analyze(dsl);

        expect(analysis.tokensPerNode, greaterThan(0));
        expect(analysis.tokensPerLine, greaterThan(0));
      });
    });

    group('calculateMetrics', () {
      test('calculates metrics for single sample', () {
        const samples = [
          DslSample(
            name: 'Test',
            dsl: '''dsl:1
frame Test
  container#root - w 100 h 100''',
          ),
        ];

        final metrics = counter.calculateMetrics(samples);

        expect(metrics.totalTokens, greaterThan(0));
        expect(metrics.tokenRatio, greaterThan(0));
        expect(metrics.avgTokensPerNode, greaterThan(0));
      });

      test('calculates metrics for multiple samples', () {
        const samples = [
          DslSample(
            name: 'Simple',
            category: 'simple',
            dsl: '''dsl:1
frame Simple
  container#root''',
          ),
          DslSample(
            name: 'Complex',
            category: 'complex',
            dsl: '''dsl:1
frame Complex
  column#root - gap 16 pad 24
    text#title "Title" - size 24 weight 700
    text#body "Body text"''',
          ),
        ];

        final metrics = counter.calculateMetrics(samples);

        expect(metrics.totalTokens, greaterThan(0));
        expect(metrics.byConstruct, isNotEmpty);
      });

      test('token ratio is less than 1', () {
        const samples = [
          DslSample(
            name: 'Test',
            dsl: '''dsl:1
frame Test
  container#root - w 100 h 100''',
          ),
        ];

        final metrics = counter.calculateMetrics(samples);

        // DSL should be more compact than JSON
        expect(metrics.tokenRatio, lessThan(1.0));
      });
    });
  });

  group('DslTokenAnalysis', () {
    test('toJson produces valid map', () {
      const analysis = DslTokenAnalysis(
        totalTokens: 100,
        totalLines: 10,
        totalNodes: 5,
        constructCounts: {'container': 3, 'text': 2},
        tokensPerLine: 10.0,
        tokensPerNode: 20.0,
      );

      final json = analysis.toJson();

      expect(json['totalTokens'], 100);
      expect(json['totalLines'], 10);
      expect(json['totalNodes'], 5);
      expect(json['constructCounts'], {'container': 3, 'text': 2});
    });
  });
}
