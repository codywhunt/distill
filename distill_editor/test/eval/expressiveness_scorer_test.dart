import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/eval/metrics/expressiveness_scorer.dart';
import 'package:distill_editor/src/free_design/eval/eval_models.dart';

void main() {
  const scorer = ExpressivenessScorer();

  group('ExpressivenessScorer', () {
    group('patternCatalog', () {
      test('contains layout patterns', () {
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'layout.column'),
          isTrue,
        );
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'layout.row'),
          isTrue,
        );
      });

      test('contains style patterns', () {
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'style.solidFill'),
          isTrue,
        );
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'style.borderRadius'),
          isTrue,
        );
      });

      test('contains text patterns', () {
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'text.basic'),
          isTrue,
        );
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'text.fontSize'),
          isTrue,
        );
      });

      test('contains component patterns', () {
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'component.use'),
          isTrue,
        );
        expect(
          ExpressivenessScorer.patternCatalog.any((p) => p.id == 'component.slot'),
          isTrue,
        );
      });

      test('has both supported and unsupported patterns', () {
        final supported =
            ExpressivenessScorer.patternCatalog.where((p) => p.supported);
        final unsupported =
            ExpressivenessScorer.patternCatalog.where((p) => !p.supported);

        expect(supported, isNotEmpty);
        expect(unsupported, isNotEmpty);
      });

      test('all patterns have required fields', () {
        for (final pattern in ExpressivenessScorer.patternCatalog) {
          expect(pattern.id, isNotEmpty);
          expect(pattern.name, isNotEmpty);
          expect(pattern.category, isNotEmpty);
          expect(pattern.description, isNotEmpty);
        }
      });

      test('supported patterns have DSL examples', () {
        final supportedPatterns =
            ExpressivenessScorer.patternCatalog.where((p) => p.supported);

        for (final pattern in supportedPatterns) {
          expect(
            pattern.dslExample,
            isNotNull,
            reason: 'Supported pattern ${pattern.id} should have dslExample',
          );
        }
      });
    });

    group('evaluate', () {
      test('returns report with correct totals', () {
        final report = scorer.evaluate();

        expect(report.totalPatterns, ExpressivenessScorer.patternCatalog.length);
        expect(
          report.supportedPatterns + report.gaps.length,
          report.totalPatterns,
        );
      });

      test('coverage is between 0 and 1', () {
        final report = scorer.evaluate();

        expect(report.coverage, greaterThanOrEqualTo(0));
        expect(report.coverage, lessThanOrEqualTo(1));
      });

      test('gaps contain unsupported patterns', () {
        final report = scorer.evaluate();

        for (final gap in report.gaps) {
          final pattern = ExpressivenessScorer.patternCatalog
              .firstWhere((p) => p.id == gap.patternId);
          expect(pattern.supported, isFalse);
        }
      });

      test('gaps are sorted by priority', () {
        final report = scorer.evaluate();

        if (report.gaps.length > 1) {
          for (var i = 0; i < report.gaps.length - 1; i++) {
            expect(
              report.gaps[i].priority.index,
              lessThanOrEqualTo(report.gaps[i + 1].priority.index),
            );
          }
        }
      });
    });

    group('getPatternsByCategory', () {
      test('returns patterns grouped by category', () {
        final byCategory = scorer.getPatternsByCategory();

        expect(byCategory.containsKey('Layout'), isTrue);
        expect(byCategory.containsKey('Style'), isTrue);
        expect(byCategory.containsKey('Text'), isTrue);
        expect(byCategory.containsKey('Icon'), isTrue);
        expect(byCategory.containsKey('Image'), isTrue);
        expect(byCategory.containsKey('Component'), isTrue);
      });

      test('all patterns are categorized', () {
        final byCategory = scorer.getPatternsByCategory();
        final totalCategorized =
            byCategory.values.fold<int>(0, (sum, list) => sum + list.length);

        expect(totalCategorized, ExpressivenessScorer.patternCatalog.length);
      });
    });

    group('getSupportedPatterns', () {
      test('returns only supported patterns', () {
        final supported = scorer.getSupportedPatterns();

        for (final pattern in supported) {
          expect(pattern.supported, isTrue);
        }
      });
    });

    group('getGaps', () {
      test('returns only unsupported patterns', () {
        final gaps = scorer.getGaps();

        for (final pattern in gaps) {
          expect(pattern.supported, isFalse);
        }
      });

      test('gaps are sorted by priority', () {
        final gaps = scorer.getGaps();

        if (gaps.length > 1) {
          for (var i = 0; i < gaps.length - 1; i++) {
            final currentPriority = gaps[i].priority?.index ?? 2;
            final nextPriority = gaps[i + 1].priority?.index ?? 2;
            expect(currentPriority, lessThanOrEqualTo(nextPriority));
          }
        }
      });
    });

    group('isPatternSupported', () {
      test('returns true for supported patterns', () {
        expect(scorer.isPatternSupported('layout.column'), isTrue);
        expect(scorer.isPatternSupported('text.basic'), isTrue);
        expect(scorer.isPatternSupported('style.solidFill'), isTrue);
      });

      test('returns false for unsupported patterns', () {
        expect(scorer.isPatternSupported('style.linearGradient'), isFalse);
        expect(scorer.isPatternSupported('layout.responsive'), isFalse);
      });

      test('returns false for unknown patterns', () {
        expect(scorer.isPatternSupported('unknown.pattern'), isFalse);
      });
    });
  });

  group('UIPattern', () {
    test('toJson produces valid map', () {
      const pattern = UIPattern(
        id: 'test.pattern',
        name: 'Test Pattern',
        category: 'Test',
        description: 'A test pattern',
        supported: true,
        dslExample: 'test "example"',
        priority: PatternPriority.high,
      );

      final json = pattern.toJson();

      expect(json['id'], 'test.pattern');
      expect(json['name'], 'Test Pattern');
      expect(json['category'], 'Test');
      expect(json['description'], 'A test pattern');
      expect(json['supported'], isTrue);
      expect(json['dslExample'], 'test "example"');
      expect(json['priority'], 'high');
    });
  });
}
