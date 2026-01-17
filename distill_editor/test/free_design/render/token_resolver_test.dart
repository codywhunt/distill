import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('TokenResolver', () {
    group('empty resolver', () {
      test('returns null for unknown color token', () {
        final resolver = TokenResolver.emptyResolver;

        expect(resolver.resolveColor('color.primary'), isNull);
        expect(resolver.resolveColor('color.unknown'), isNull);
      });

      test('returns null for unknown spacing token', () {
        final resolver = TokenResolver.emptyResolver;

        expect(resolver.resolveSpacing('spacing.md'), isNull);
      });

      test('returns null for unknown radius token', () {
        final resolver = TokenResolver.emptyResolver;

        expect(resolver.resolveRadius('radius.lg'), isNull);
      });
    });

    group('with custom tokens', () {
      late TokenResolver resolver;

      setUp(() {
        resolver = TokenResolver(
          TokenSchema(
            color: {
              'primary': '#007AFF',
              'secondary': '#5856D6',
              'surface': {'background': '#FFFFFF'},
              'text': {'primary': '#000000'},
            },
            spacing: {'xs': 4.0, 'sm': 8.0, 'md': 16.0, 'lg': 24.0},
            radius: {'sm': 4.0, 'md': 8.0, 'lg': 16.0, 'full': 9999.0},
          ),
        );
      });

      test('resolves color tokens', () {
        expect(resolver.resolveColor('color.primary'), const Color(0xFF007AFF));
        expect(
          resolver.resolveColor('color.secondary'),
          const Color(0xFF5856D6),
        );
      });

      test('resolves nested color tokens', () {
        expect(
          resolver.resolveColor('color.surface.background'),
          const Color(0xFFFFFFFF),
        );
        expect(
          resolver.resolveColor('color.text.primary'),
          const Color(0xFF000000),
        );
      });

      test('resolves spacing tokens', () {
        expect(resolver.resolveSpacing('spacing.xs'), 4.0);
        expect(resolver.resolveSpacing('spacing.sm'), 8.0);
        expect(resolver.resolveSpacing('spacing.md'), 16.0);
        expect(resolver.resolveSpacing('spacing.lg'), 24.0);
      });

      test('resolves radius tokens', () {
        expect(resolver.resolveRadius('radius.sm'), 4.0);
        expect(resolver.resolveRadius('radius.md'), 8.0);
        expect(resolver.resolveRadius('radius.lg'), 16.0);
        expect(resolver.resolveRadius('radius.full'), 9999.0);
      });

      test('returns null for unknown tokens', () {
        expect(resolver.resolveColor('color.unknown'), isNull);
        expect(resolver.resolveSpacing('spacing.unknown'), isNull);
        expect(resolver.resolveRadius('radius.unknown'), isNull);
      });
    });

    group('defaults factory', () {
      late TokenResolver resolver;

      setUp(() {
        resolver = TokenResolver.defaults();
      });

      test('provides default color tokens', () {
        expect(resolver.resolveColor('color.primary'), isNotNull);
        expect(resolver.resolveColor('color.secondary'), isNotNull);
        expect(resolver.resolveColor('color.surface'), isNotNull);
        expect(resolver.resolveColor('color.error'), isNotNull);
      });

      test('provides default spacing tokens', () {
        expect(resolver.resolveSpacing('spacing.none'), 0.0);
        expect(resolver.resolveSpacing('spacing.xs'), 4.0);
        expect(resolver.resolveSpacing('spacing.sm'), 8.0);
        expect(resolver.resolveSpacing('spacing.md'), 16.0);
        expect(resolver.resolveSpacing('spacing.lg'), 24.0);
        expect(resolver.resolveSpacing('spacing.xl'), 32.0);
      });

      test('provides default radius tokens', () {
        expect(resolver.resolveRadius('radius.none'), 0.0);
        expect(resolver.resolveRadius('radius.sm'), 4.0);
        expect(resolver.resolveRadius('radius.md'), 8.0);
        expect(resolver.resolveRadius('radius.lg'), 12.0);
        expect(resolver.resolveRadius('radius.full'), 9999.0);
      });
    });

    group('isTokenRef', () {
      test('returns true for color refs', () {
        expect(TokenResolver.isTokenRef('color.primary'), true);
        expect(TokenResolver.isTokenRef('color.surface.background'), true);
      });

      test('returns true for spacing refs', () {
        expect(TokenResolver.isTokenRef('spacing.md'), true);
        expect(TokenResolver.isTokenRef('spacing.lg'), true);
      });

      test('returns true for radius refs', () {
        expect(TokenResolver.isTokenRef('radius.lg'), true);
        expect(TokenResolver.isTokenRef('radius.full'), true);
      });

      test('returns false for non-token strings', () {
        expect(TokenResolver.isTokenRef('#FF0000'), false);
        expect(TokenResolver.isTokenRef('red'), false);
        expect(TokenResolver.isTokenRef('100'), false);
        expect(TokenResolver.isTokenRef('unknown.value'), false);
      });
    });

    group('resolveNumeric', () {
      late TokenResolver resolver;

      setUp(() {
        resolver = TokenResolver(
          TokenSchema(spacing: {'md': 16.0}, radius: {'lg': 24.0}),
        );
      });

      test('returns value directly for FixedNumeric', () {
        expect(resolver.resolveNumeric(const FixedNumeric(42)), 42.0);
        expect(resolver.resolveNumeric(const FixedNumeric(0)), 0.0);
      });

      test('resolves TokenNumeric through schema', () {
        expect(resolver.resolveNumeric(const TokenNumeric('spacing.md')), 16.0);
        expect(resolver.resolveNumeric(const TokenNumeric('radius.lg')), 24.0);
      });

      test('returns fallback for unresolved TokenNumeric', () {
        expect(
          resolver.resolveNumeric(
            const TokenNumeric('spacing.unknown'),
            fallback: 99.0,
          ),
          99.0,
        );
      });
    });

    group('toString', () {
      test('includes schema info', () {
        final resolver = TokenResolver.defaults();
        final str = resolver.toString();

        expect(str, contains('TokenResolver'));
        expect(str, contains('schema'));
      });
    });
  });
}
