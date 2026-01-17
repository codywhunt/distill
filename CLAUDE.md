# Claude Code Guidelines for Distill

## Running Flutter Tests

Flutter test output is extremely verbose (prints a line for every test state change), which can exceed Claude's output limits. Use the JSON reporter with `jq` to get concise summaries.

### Basic test summary
```bash
flutter test path/to/tests --reporter json 2>&1 | jq -s '
  {
    total: [.[] | select(.type == "testDone")] | length,
    passed: [.[] | select(.type == "testDone" and .result == "success")] | length,
    failed: [.[] | select(.type == "testDone" and .result == "failure")] | length,
    success: .[-1].success
  }
'
```

### With failure details
```bash
flutter test path/to/tests --reporter json 2>&1 | jq -s '
  {
    total: [.[] | select(.type == "testDone")] | length,
    passed: [.[] | select(.type == "testDone" and .result == "success")] | length,
    failed: [.[] | select(.type == "testDone" and .result == "failure")] | length,
    failures: [.[] | select(.type == "error") | {test: .testID, error: .error}][:5],
    success: .[-1].success
  }
'
```

### Get names of failing tests by ID
```bash
flutter test path/to/tests --reporter json 2>&1 | jq -s '
  [.[] | select(.type == "testStart" and .test.id == TEST_ID) | .test.name]
'
```

### Quick pass/fail check
```bash
flutter test path/to/tests --reporter json 2>&1 | jq -s '.[-1] | {success: .success}'
```
