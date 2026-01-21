# Self-Improvement Loop Instructions for Claude Code

This document provides instructions for Claude Code to autonomously improve the DSL/IR/Rendering architecture.

## Overview

The improvement loop follows these phases:
1. **Evaluate** - Run metrics to measure current state
2. **Critique** - Analyze results and identify opportunities
3. **Propose** - Design a targeted improvement
4. **Implement** - Make the code changes
5. **Verify** - Run tests to confirm improvement
6. **Validate** - Commit if improved, revert if regressed

## Starting an Iteration

1. **Read current state**:
   ```bash
   cat distill_editor/.claude/loop_state.json
   ```

2. **Run evaluation** (via Flutter test since project uses dart:ui):
   ```bash
   cd distill_editor && flutter test test/eval/eval_runner_test.dart --reporter json 2>&1 | jq -s '{
     total: [.[] | select(.type == "testDone")] | length,
     passed: [.[] | select(.type == "testDone" and .result == "success")] | length,
     success: .[-1].success
   }'
   ```

3. **Compare to baseline**: Check if metrics improved or regressed from `baseline` in loop_state.json

4. **Analyze and critique**: Review test failures, token counts, expressiveness gaps

## Proposing an Improvement

1. Identify the highest-impact, lowest-risk improvement opportunity
2. Create hypothesis in loop_state.json:
   ```json
   {
     "currentHypothesis": {
       "id": "improve_001",
       "category": "tokenEfficiency",
       "description": "Add 3-char hex color support",
       "rationale": "Saves 3 tokens per color value",
       "targetFiles": ["grammar.dart", "dsl_parser.dart", "dsl_exporter.dart"],
       "risk": "low",
       "expectedImpact": 0.02,
       "invariants": ["Round-trip fidelity = 100%", "All existing tests pass"]
     }
   }
   ```
3. Create git branch: `git checkout -b improve/{hypothesis_id}`

## Implementing Changes

1. Make targeted code changes to the files identified in the hypothesis
2. Follow existing code patterns and conventions
3. Add tests for any new functionality
4. Keep changes focused and minimal

### Key Files by Area

**DSL Grammar & Parsing**:
- `lib/src/free_design/dsl/grammar.dart` - Property constants
- `lib/src/free_design/dsl/dsl_parser.dart` - Parser logic
- `lib/src/free_design/dsl/dsl_exporter.dart` - Export logic

**IR Models**:
- `lib/src/free_design/models/node.dart` - Node structure
- `lib/src/free_design/models/node_layout.dart` - Layout properties
- `lib/src/free_design/models/node_style.dart` - Style properties

**Rendering**:
- `lib/src/free_design/render/render_compiler.dart` - IR to render
- `lib/src/free_design/render/render_engine.dart` - Widget generation

## Verifying Changes

1. **Run full test suite** (use JSON reporter for concise output):
   ```bash
   flutter test test/free_design/ --reporter json 2>&1 | jq -s '{
     total: [.[] | select(.type == "testDone")] | length,
     passed: [.[] | select(.type == "testDone" and .result == "success")] | length,
     failed: [.[] | select(.type == "testDone" and .result == "failure")] | length,
     success: .[-1].success
   }'
   ```

2. **Run evaluation again** to measure impact:
   ```bash
   dart run lib/src/free_design/eval/eval_runner.dart --json
   ```

3. **All tests MUST pass** - no exceptions

## Committing or Reverting

### If improved AND tests pass:
```bash
git add -A
git commit -m "$(cat <<'EOF'
Improve: {description}

- {change 1}
- {change 2}

Metrics:
- Token ratio: {before} → {after}
- Coverage: {before} → {after}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
git checkout main
git merge improve/{id}
```

Update loop_state.json:
```json
{
  "status": "idle",
  "iteration": {previous + 1},
  "currentHypothesis": null,
  "history": [
    ...previous,
    {
      "id": "iter_{n}",
      "hypothesis": "{description}",
      "outcome": "improved",
      "deltaTokens": -{amount},
      "commit": "{hash}",
      "timestamp": "{ISO8601}",
      "learnings": ["{any lessons learned}"]
    }
  ]
}
```

### If tests fail OR regressed:
```bash
git checkout main
git branch -D improve/{id}
```

Update loop_state.json with failure record and learnings.

## Invariants (NEVER BREAK)

These must always be preserved:

- [ ] DSL version header format (`dsl:1`)
- [ ] JSON serialization compatibility (IR models)
- [ ] Existing DSL parses without error
- [ ] Round-trip fidelity = 100% for existing constructs
- [ ] Component ID namespacing format (`comp::node`)
- [ ] Token resolution paths work correctly
- [ ] All existing tests pass

## Improvement Categories

### Token Efficiency
- Reduce characters/tokens needed for common patterns
- Add better defaults to omit properties
- Support shorthand syntax

### Expressiveness
- Add new node types or properties
- Support more UI patterns
- Enable better composition

### Correctness
- Fix edge cases in parsing/export
- Add missing validation
- Improve error messages

## CLI Commands Reference

| Phase | Command |
|-------|---------|
| Evaluate | `flutter test test/eval/ --reporter json 2>&1 \| jq -s '{...}'` |
| Test DSL | `flutter test test/free_design/dsl/ --reporter json 2>&1 \| jq -s '{...}'` |
| Test All | `flutter test test/free_design/ --reporter json 2>&1 \| jq -s '{...}'` |
| Git Status | `git status` |
| Create Branch | `git checkout -b improve/{id}` |
| Merge | `git checkout main && git merge improve/{id}` |
| Revert | `git checkout main && git branch -D improve/{id}` |

## Triggering the Loop

The loop can be triggered via:
- Direct prompt: "Run one iteration of the self-improvement loop"
- Batch mode: "Run improvement loop until no progress for 3 iterations"
- Specific focus: "Run improvement loop focusing on token efficiency"
