/// Token counting metrics for DSL efficiency evaluation.
///
/// Measures token usage per DSL construct to identify optimization
/// opportunities for AI generation cost reduction.
library;

import 'dart:convert';

import '../eval_models.dart';

/// Counts tokens in DSL text using a simplified tokenization model.
///
/// This approximates LLM tokenization (GPT-4/Claude style) where:
/// - Whitespace splits tokens
/// - Punctuation (except alphanumeric) is often a separate token
/// - Numbers and short words are often single tokens
/// - Longer words may be split into subwords
class TokenCounter {
  const TokenCounter();

  /// Count total tokens in a DSL string.
  int countTokens(String dsl) {
    if (dsl.isEmpty) return 0;

    // Simplified tokenization model that approximates LLM tokenizers:
    // 1. Split on whitespace and newlines
    // 2. Split on punctuation boundaries
    // 3. Apply subword splitting for longer words
    var count = 0;
    final segments = _tokenize(dsl);
    count = segments.length;
    return count;
  }

  /// Tokenize a string into approximate LLM tokens.
  List<String> _tokenize(String text) {
    final tokens = <String>[];

    // Split into lines first, then process each line
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      // Tokenize each line
      final lineTokens = _tokenizeLine(line);
      tokens.addAll(lineTokens);

      // Newlines are typically their own token
      if (i < lines.length - 1) {
        tokens.add('\n');
      }
    }

    return tokens;
  }

  List<String> _tokenizeLine(String line) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (var i = 0; i < line.length; i++) {
      final char = line[i];

      if (_isWhitespace(char)) {
        // Flush buffer and add whitespace as token
        if (buffer.isNotEmpty) {
          tokens.addAll(_splitLongWord(buffer.toString()));
          buffer.clear();
        }
        // Spaces are often merged with adjacent tokens, but we count them
        // conservatively as potential tokens
        if (char == ' ') {
          // Consecutive spaces might be one token, single space often merged
          // We'll be conservative and not count single spaces
        } else {
          tokens.add(char);
        }
      } else if (_isPunctuation(char)) {
        // Flush buffer and add punctuation as its own token
        if (buffer.isNotEmpty) {
          tokens.addAll(_splitLongWord(buffer.toString()));
          buffer.clear();
        }
        tokens.add(char);
      } else {
        buffer.write(char);
      }
    }

    // Flush remaining buffer
    if (buffer.isNotEmpty) {
      tokens.addAll(_splitLongWord(buffer.toString()));
    }

    return tokens;
  }

  /// Split longer words into subword tokens (approximating BPE).
  List<String> _splitLongWord(String word) {
    // Short words (<=4 chars) are typically single tokens
    if (word.length <= 4) return [word];

    // Medium words (5-8 chars) might be 1-2 tokens
    if (word.length <= 8) {
      // Common programming words are often single tokens
      if (_commonWords.contains(word.toLowerCase())) {
        return [word];
      }
      // Otherwise estimate ~1.5 tokens
      return [word];
    }

    // Longer words get split more aggressively
    // Approximate: 1 token per 4 characters for long words
    final numTokens = (word.length / 4).ceil();
    final result = <String>[];
    for (var i = 0; i < numTokens; i++) {
      final start = i * 4;
      final end = (start + 4).clamp(0, word.length);
      if (start < word.length) {
        result.add(word.substring(start, end));
      }
    }
    return result;
  }

  bool _isWhitespace(String char) => char == ' ' || char == '\t';

  bool _isPunctuation(String char) {
    const punctuation = r'{}[]().,;:!?@#$%^&*+-=<>/\|`~"' "'";
    return punctuation.contains(char);
  }

  static const _commonWords = {
    'container',
    'column',
    'text',
    'image',
    'icon',
    'spacer',
    'frame',
    'true',
    'false',
    'fill',
    'center',
    'start',
    'stretch',
    'vertical',
    'horizontal',
  };

  /// Analyze a DSL string and return detailed token metrics.
  DslTokenAnalysis analyze(String dsl) {
    final lines = dsl.split('\n');
    final nodeLines = <String>[];
    final propCounts = <String, int>{};
    var totalNodes = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Version header
      if (trimmed.startsWith('dsl:')) continue;

      // Frame declaration
      if (trimmed.startsWith('frame ')) continue;

      // Node line
      final nodeMatch = RegExp(r'^(\w+)(?:#\w+)?').firstMatch(trimmed);
      if (nodeMatch != null) {
        totalNodes++;
        final nodeType = nodeMatch.group(1)!;
        propCounts[nodeType] = (propCounts[nodeType] ?? 0) + 1;
        nodeLines.add(trimmed);

        // Count properties
        final propsMatch = RegExp(r' - (.+)$').firstMatch(trimmed);
        if (propsMatch != null) {
          final propsStr = propsMatch.group(1)!;
          final props = _parsePropertyKeys(propsStr);
          for (final prop in props) {
            propCounts['prop:$prop'] = (propCounts['prop:$prop'] ?? 0) + 1;
          }
        }
      }
    }

    final totalTokens = countTokens(dsl);

    return DslTokenAnalysis(
      totalTokens: totalTokens,
      totalLines: lines.where((l) => l.trim().isNotEmpty).length,
      totalNodes: totalNodes,
      constructCounts: propCounts,
      tokensPerLine: lines.isNotEmpty
          ? totalTokens / lines.where((l) => l.trim().isNotEmpty).length
          : 0,
      tokensPerNode: totalNodes > 0 ? totalTokens / totalNodes : 0,
    );
  }

  List<String> _parsePropertyKeys(String propsStr) {
    final keys = <String>[];
    final parts = propsStr.split(' ');
    var i = 0;
    while (i < parts.length) {
      final part = parts[i];
      if (part.isEmpty) {
        i++;
        continue;
      }

      // Check if it's a property key
      if (_isPropertyKey(part)) {
        keys.add(part);
      }
      i++;
    }
    return keys;
  }

  bool _isPropertyKey(String word) {
    const keys = {
      'w',
      'h',
      'gap',
      'pad',
      'align',
      'pos',
      'bg',
      'fg',
      'r',
      'border',
      'shadow',
      'opacity',
      'visible',
      'size',
      'weight',
      'color',
      'textAlign',
      'family',
      'icon',
      'iconSet',
      'src',
      'fit',
      'alt',
      'clip',
      'scroll',
      'flex',
      'x',
      'y',
      'abs',
    };
    return keys.contains(word);
  }

  /// Calculate token metrics for a collection of DSL samples.
  TokenMetrics calculateMetrics(List<DslSample> samples) {
    final byConstruct = <String, _ConstructAccumulator>{};
    var totalTokens = 0;
    var totalNodes = 0;
    var totalLines = 0;
    var totalDslTokens = 0;
    var totalJsonTokens = 0;

    for (final sample in samples) {
      final analysis = analyze(sample.dsl);
      totalTokens += analysis.totalTokens;
      totalNodes += analysis.totalNodes;
      totalLines += analysis.totalLines;
      totalDslTokens += analysis.totalTokens;

      // Estimate JSON equivalent tokens (typically 3-4x DSL tokens)
      totalJsonTokens += (analysis.totalTokens * 4).round();

      // Accumulate per-construct counts
      for (final entry in analysis.constructCounts.entries) {
        byConstruct.putIfAbsent(
            entry.key, () => _ConstructAccumulator(entry.key));
        byConstruct[entry.key]!.add(entry.value, analysis.totalTokens);
      }
    }

    final constructMetrics = <String, ConstructTokens>{};
    for (final entry in byConstruct.entries) {
      constructMetrics[entry.key] = entry.value.toConstructTokens();
    }

    return TokenMetrics(
      totalTokens: totalTokens,
      byConstruct: constructMetrics,
      tokenRatio:
          totalJsonTokens > 0 ? totalDslTokens / totalJsonTokens : 0,
      avgTokensPerNode: totalNodes > 0 ? totalTokens / totalNodes : 0,
      tokensPerLine: totalLines > 0 ? totalTokens / totalLines : 0,
    );
  }
}

/// Analysis result for a single DSL string.
class DslTokenAnalysis {
  final int totalTokens;
  final int totalLines;
  final int totalNodes;
  final Map<String, int> constructCounts;
  final double tokensPerLine;
  final double tokensPerNode;

  const DslTokenAnalysis({
    required this.totalTokens,
    required this.totalLines,
    required this.totalNodes,
    required this.constructCounts,
    required this.tokensPerLine,
    required this.tokensPerNode,
  });

  Map<String, dynamic> toJson() => {
        'totalTokens': totalTokens,
        'totalLines': totalLines,
        'totalNodes': totalNodes,
        'constructCounts': constructCounts,
        'tokensPerLine': tokensPerLine,
        'tokensPerNode': tokensPerNode,
      };

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(toJson());
}

/// A DSL sample for evaluation.
class DslSample {
  final String name;
  final String dsl;
  final String? category;

  const DslSample({
    required this.name,
    required this.dsl,
    this.category,
  });
}

class _ConstructAccumulator {
  final String constructType;
  int occurrences = 0;
  int totalTokens = 0;

  _ConstructAccumulator(this.constructType);

  void add(int count, int tokens) {
    occurrences += count;
    // Rough estimate: distribute tokens across occurrences
    totalTokens += tokens ~/ 10; // Approximate per-construct tokens
  }

  ConstructTokens toConstructTokens() => ConstructTokens(
        constructType: constructType,
        occurrences: occurrences,
        totalTokens: totalTokens,
        avgTokens: occurrences > 0 ? totalTokens / occurrences : 0,
      );
}
