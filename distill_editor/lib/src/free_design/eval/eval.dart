/// Evaluation harness for DSL self-improvement loop.
///
/// Provides metrics and tooling for measuring:
/// - Token efficiency (DSL compactness)
/// - Expressiveness (UI pattern coverage)
/// - Correctness (parse/round-trip fidelity)
library;

export 'eval_models.dart';
export 'eval_runner.dart';
export 'metrics/token_counter.dart';
export 'metrics/expressiveness_scorer.dart';
export 'metrics/correctness_checker.dart';
