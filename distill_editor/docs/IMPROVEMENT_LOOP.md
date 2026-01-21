# Self-Improving Agent Loop for DSL/IR/Rendering Architecture

This document describes the self-improving loop architecture that enables Claude Code to autonomously improve the DSL, IR, and rendering pipeline.

## Overview

The improvement loop is an autonomous cycle where Claude Code iteratively improves the DSL/IR/Rendering architecture by:

1. **Evaluating** current metrics
2. **Critiquing** results to find improvement opportunities
3. **Proposing** targeted improvements
4. **Implementing** code changes
5. **Verifying** improvements with tests
6. **Validating** by committing or reverting

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 CLAUDE CODE IMPROVEMENT LOOP                    │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   EVALUATE   │───▶│   CRITIQUE   │───▶│   PROPOSE    │      │
│  │  (run tests) │    │  (analyze)   │    │  (plan fix)  │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│         ▲                                       │               │
│         │                                       ▼               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │   VALIDATE   │◀───│   VERIFY     │◀───│  IMPLEMENT   │      │
│  │  (git commit)│    │  (run tests) │    │ (edit files) │      │
│  └──────────────┘    └──────────────┘    └──────────────┘      │
│                                                                 │
│  Agent: Claude Code CLI | Infra: Dart tests + metrics          │
└─────────────────────────────────────────────────────────────────┘
```

## Optimization Goals

The loop optimizes for three objectives:

| Objective | Description | Target |
|-----------|-------------|--------|
| **Token Efficiency** | Reduce DSL tokens for AI generation cost | tokenRatio < 0.25 |
| **Expressiveness** | Enable more UI patterns | coverage > 95% |
| **Correctness** | Ensure IR→Render fidelity | 100% tests pass |

## Evaluation Harness

### Directory Structure

```
distill_editor/
├── lib/src/free_design/eval/
│   ├── eval.dart                    # Barrel export
│   ├── eval_models.dart             # Metrics models
│   ├── eval_runner.dart             # Main CLI runner
│   └── metrics/
│       ├── token_counter.dart       # Token counting
│       ├── expressiveness_scorer.dart # Pattern coverage
│       └── correctness_checker.dart # Parse/round-trip tests
├── test/eval/
│   ├── fixtures/
│   │   ├── token_efficiency/        # DSL samples
│   │   ├── expressiveness/          # UI pattern catalog
│   │   └── correctness/             # Round-trip tests
│   ├── token_counter_test.dart
│   ├── expressiveness_scorer_test.dart
│   ├── correctness_checker_test.dart
│   └── eval_runner_test.dart
└── .claude/
    ├── loop_state.json              # Persistent loop state
    └── loop_instructions.md         # Instructions for Claude Code
```

### Running the Evaluation

```bash
# Full evaluation with JSON output
cd distill_editor && dart run lib/src/free_design/eval/eval_runner.dart --json

# Verbose human-readable output
cd distill_editor && dart run lib/src/free_design/eval/eval_runner.dart --verbose
```

### Sample Output

```json
{
  "tokens": {
    "totalTokens": 450,
    "tokenRatio": 0.23,
    "avgTokensPerNode": 8.5,
    "tokensPerLine": 5.2
  },
  "expressiveness": {
    "totalPatterns": 52,
    "supportedPatterns": 36,
    "coverage": 0.69,
    "gaps": [...]
  },
  "correctness": {
    "totalTests": 12,
    "passed": 12,
    "failed": 0,
    "passRate": 1.0,
    "roundTripFidelity": 1.0
  }
}
```

## Metrics

### Token Efficiency

| Metric | Description | Target |
|--------|-------------|--------|
| `tokenRatio` | DSL tokens / equivalent JSON tokens | < 0.25 |
| `avgTokensPerNode` | Average tokens per DSL node | < 8.0 |
| `tokensPerLine` | Average tokens per line | < 6.0 |

### Expressiveness

| Metric | Description | Target |
|--------|-------------|--------|
| `coverage` | % of UI patterns expressible | > 95% |
| `supportedPatterns` | Count of supported patterns | Maximize |
| `gaps` | Patterns that can't be expressed | Minimize |

### Correctness

| Metric | Description | Target |
|--------|-------------|--------|
| `passRate` | % of tests passing | 100% |
| `roundTripFidelity` | DSL→IR→DSL equality | 100% |
| `parseSuccessRate` | Valid DSL parses correctly | 100% |

## Loop State

The loop state is persisted in `.claude/loop_state.json`:

```json
{
  "status": "idle",
  "iteration": 5,
  "currentHypothesis": null,
  "baseline": {
    "tokenEfficiency": 0.23,
    "patternCoverage": 0.87,
    "roundTripFidelity": 1.0,
    "testsPassing": 142
  },
  "history": [
    {
      "id": "iter_001",
      "hypothesis": "Add 3-char hex color support",
      "outcome": "improved",
      "deltaTokens": -0.02,
      "commit": "abc123"
    }
  ],
  "learnings": [
    "Parser changes require exporter changes for round-trip"
  ]
}
```

## Invariants

These must NEVER be broken:

- [ ] DSL version header format (`dsl:1`)
- [ ] JSON serialization compatibility (IR models)
- [ ] Existing DSL parses without error
- [ ] Round-trip fidelity = 100% for existing constructs
- [ ] Component ID namespacing format (`comp::node`)
- [ ] Token resolution paths work correctly
- [ ] All existing tests pass

## Improvement Categories

### Token Efficiency

| Target | Approach |
|--------|----------|
| Default omission | Export only non-default values |
| Color shorthand | Support 3-char hex (#FFF) |
| Common patterns | Add presets for common UI elements |
| Inherited defaults | Child nodes inherit parent styles |

### Expressiveness

| Pattern | Priority | Approach |
|---------|----------|----------|
| Gradients | High | Add `LinearGradient`, `RadialGradient` fills |
| Rich text | High | Add inline span support |
| Responsive | High | Add breakpoint system |
| Transforms | Medium | Add `rotate`, `scale`, `translate` |
| Blur | Medium | Add `blur` style property |

### Correctness

| Area | Improvement |
|------|-------------|
| Round-trip | Add comprehensive tests |
| Token resolution | Add edge case handling |
| Error messages | Make errors more actionable |
| Empty nodes | Define and test behavior |

## Running the Loop

### Single Iteration
```
Run one iteration of the self-improvement loop
```

### Batch Mode
```
Run improvement loop until no progress for 3 iterations
```

### Focused Mode
```
Run improvement loop focusing on token efficiency
```

## Test Commands

```bash
# Run eval infrastructure tests
flutter test test/eval/ --reporter json 2>&1 | jq -s '{
  total: [.[] | select(.type == "testDone")] | length,
  passed: [.[] | select(.type == "testDone" and .result == "success")] | length,
  success: .[-1].success
}'

# Run DSL tests (must not regress)
flutter test test/free_design/dsl/ --reporter json 2>&1 | jq -s '{...}'

# Full test suite
flutter test test/free_design/ --reporter json 2>&1 | jq -s '{...}'
```

## Contributing Improvements

When making manual improvements to the DSL:

1. Run evaluation to establish baseline
2. Make your changes
3. Run tests to verify no regression
4. Run evaluation again to measure impact
5. Document the improvement in commit message
6. Update loop_state.json baseline if appropriate
