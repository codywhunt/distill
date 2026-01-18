# PRD: Priority 4 - DSL Round-Trip Fidelity

## Overview

The DSL (Domain-Specific Language) is the contract between human editing and AI generation. The parser and exporter are **fully implemented and actively used**, but have **zero test coverage**. This is a critical gap that could cause silent data loss.

**Status:** Implementation complete, testing critical gap
**Risk Level:** HIGH - actively used in production with no verification

---

## Current State

### What's Implemented ✅

**Parser** (`dsl_parser.dart` - 637 lines):
- Parses DSL into Frame + Nodes
- Handles 2-space indentation hierarchy
- Supports explicit IDs (`#id` syntax)
- Extracts quoted content for text
- Token references (`{color.primary}` syntax)
- Error messages with line numbers
- All 7 node types supported

**Exporter** (`dsl_exporter.dart` - 460 lines):
- Exports Frame + Nodes back to DSL
- Deterministic output (consistent property order)
- Omits defaults (doesn't export hug mode, etc.)
- Proper NumericValue handling (fixed vs token)
- Uses `{token.path}` syntax for tokens

**Active Usage:**
- `generateViaDsl()` in `ai_service.dart` uses parser
- Extraction logic handles code blocks and raw DSL
- Repair mode attempts up to 2 corrections on parse failures
- Used in `prompt_box_overlay.dart` for frame generation

### Property Coverage

| Category | Supported | Missing |
|----------|-----------|---------|
| Frame | size, name | - |
| Node types | all 7 | - |
| Position | auto, absolute | - |
| Size | fixed, hug, fill | - |
| Auto-layout | direction, gap, padding, align | - |
| Fill | solid colors, tokens | gradients |
| Stroke | width, color | - |
| Corner radius | uniform, per-corner | - |
| Opacity | yes | - |
| Text | content, size, weight, color, align | line-height, letter-spacing, decoration |
| Icon | name, set, size, color | - |
| Image | src, fit | alt |
| Instance | componentId | overrides |
| Shadow | - | NOT SUPPORTED |

---

## The Problem

### Zero Test Coverage

Despite being actively used in AI generation, there are **no dedicated DSL tests**:

- ❌ No round-trip tests (`parse(export(doc)) == doc`)
- ❌ No property coverage tests
- ❌ No fuzz tests
- ❌ No edge case tests
- ❌ No grammar validation tests

### Risk Scenarios

1. **Silent data loss**: AI generates valid DSL, parser drops property, user doesn't notice
2. **Inconsistent behavior**: Export includes property that parser can't read back
3. **Edge case failures**: Special characters, deep nesting, empty values cause parse errors
4. **Regression risk**: Changes to parser/exporter have no safety net

---

## Success Criteria

| Criterion | Validation Method |
|-----------|-------------------|
| Every Node property has round-trip test | Test matrix |
| Every NodeLayout property has round-trip test | Test matrix |
| Every NodeStyle property has round-trip test | Test matrix |
| 1000 random docs round-trip without diff | Fuzz test |
| Empty string text preserved | Unit test |
| Unicode in text content preserved | Unit test |
| Token references preserved | Unit test |
| Deeply nested nodes (10+ levels) work | Unit test |
| All 7 node types round-trip | Unit test |
| Special characters escaped correctly | Unit test |

---

## Implementation Plan

### Phase 1: Property Coverage Matrix

Create systematic tests for every property:

```dart
// test/free_design/dsl/dsl_roundtrip_test.dart

void main() {
  group('Node properties round-trip', () {
    test('position.x preserves value', () {
      final node = createNode(layout: NodeLayout(
        position: Position(x: 123.5, y: 0),
      ));
      expectRoundTrip(node);
    });

    test('position.y preserves value', () { ... });
    test('size.width.fixed preserves value', () { ... });
    test('size.width.fill mode preserved', () { ... });
    // ... all properties
  });

  group('NodeStyle properties round-trip', () {
    test('fill.solid color preserved', () { ... });
    test('fill with token reference preserved', () { ... });
    test('cornerRadius.all preserved', () { ... });
    test('cornerRadius per-corner preserved', () { ... });
    // ... all style properties
  });

  group('Text node properties round-trip', () {
    test('text content preserved', () { ... });
    test('fontSize preserved', () { ... });
    test('fontWeight preserved', () { ... });
    // ... all text properties
  });
}

void expectRoundTrip(Node original) {
  final dsl = DslExporter.exportNode(original);
  final parsed = DslParser.parseNode(dsl);
  expect(parsed, equals(original), reason: 'DSL: $dsl');
}
```

### Phase 2: Edge Case Tests

```dart
group('DSL edge cases', () {
  test('empty string text preserved', () {
    final node = textNode(text: '');
    expectRoundTrip(node);
  });

  test('text with quotes preserved', () {
    final node = textNode(text: 'Say "hello"');
    expectRoundTrip(node);
  });

  test('text with newlines preserved', () {
    final node = textNode(text: 'Line 1\nLine 2');
    expectRoundTrip(node);
  });

  test('unicode text preserved', () {
    final texts = ['你好', '🎉🚀', 'émoji', 'مرحبا'];
    for (final text in texts) {
      final node = textNode(text: text);
      expectRoundTrip(node);
    }
  });

  test('token reference preserved', () {
    final node = containerNode(style: NodeStyle(
      fill: Fill(type: FillType.solid, color: '{color.primary}'),
    ));
    expectRoundTrip(node);
  });

  test('deep nesting (15 levels) preserved', () {
    final deep = createDeepTree(depth: 15);
    expectFrameRoundTrip(deep);
  });

  test('zero values preserved', () {
    final node = containerNode(
      layout: NodeLayout(position: Position(x: 0, y: 0)),
      style: NodeStyle(opacity: 0, cornerRadius: CornerRadius.all(0)),
    );
    expectRoundTrip(node);
  });

  test('negative values preserved', () {
    final node = containerNode(
      layout: NodeLayout(position: Position(x: -100, y: -50)),
    );
    expectRoundTrip(node);
  });
});
```

### Phase 3: Fuzz Testing

```dart
// test/free_design/dsl/dsl_fuzz_test.dart

void main() {
  group('DSL fuzz testing', () {
    test('1000 random documents round-trip', () {
      final fuzzer = DocumentFuzzer(seed: 12345);
      final failures = <FuzzFailure>[];

      for (var i = 0; i < 1000; i++) {
        final doc = fuzzer.generateDocument();
        try {
          for (final frame in doc.frames.values) {
            final dsl = DslExporter.exportFrame(frame: frame, nodes: doc.nodes);
            final parsed = DslParser.parseFrame(dsl);
            final differences = compareFrames(frame, doc.nodes, parsed);
            if (differences.isNotEmpty) {
              failures.add(FuzzFailure(i, dsl, differences));
            }
          }
        } catch (e) {
          failures.add(FuzzFailure(i, null, [e.toString()]));
        }
      }

      expect(failures, isEmpty, reason: 'Failures:\n${failures.take(5).join('\n')}');
    });
  });
}
```

### Phase 4: Missing Property Support

Add DSL support for missing properties:

1. **Text properties**: `lineH 1.5`, `tracking 0.5`
2. **Instance overrides**: Nested syntax for override values
3. **Shadows**: `shadow 0,2,8,#0002` syntax
4. **Gradients**: `bg linear(#FFF, #000, 180)` syntax (low priority)

---

## Test File Locations

```
test/free_design/dsl/
├── dsl_parser_test.dart           # Parser unit tests
├── dsl_exporter_test.dart         # Exporter unit tests
├── dsl_roundtrip_test.dart        # Property coverage matrix
├── dsl_edge_cases_test.dart       # Edge case tests
├── dsl_fuzz_test.dart             # Fuzz testing
└── helpers/
    ├── document_fuzzer.dart       # Random document generator
    └── frame_comparator.dart      # Deep comparison utility
```

---

## Priority

**This should be done BEFORE any AI prompt improvements.**

The AI actively generates DSL. If the DSL round-trip is lossy, improving AI prompts won't help - the generated content will still lose properties silently.

---

## Estimated Effort

| Phase | Effort |
|-------|--------|
| Property coverage matrix | 1 day |
| Edge case tests | 0.5 day |
| Fuzz testing infrastructure | 1 day |
| Missing property support | 1-2 days |
| **Total** | **3-4 days** |
