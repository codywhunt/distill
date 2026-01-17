import '../compiler/outline_compiler.dart';
import '../dsl/dsl_exporter.dart';
import '../models/editor_document.dart';
import '../store/editor_document_store.dart';

/// Service for managing derived projections from the canonical JSON IR.
///
/// The EditorDocument (JSON IR) is the single source of truth.
/// This service generates and caches derived formats:
/// - **Outline**: Compact tree view for AI context (~70-90% fewer tokens)
/// - **DSL**: Text format for AI generation (~75% fewer tokens)
///
/// Key principles:
/// - Projections are disposable and regenerable
/// - Cache invalidation is automatic via store listeners
/// - Lazy generation - projections computed on demand
class ProjectionService {
  final EditorDocumentStore _store;
  final OutlineCompiler _outlineCompiler;
  final DslExporter _dslExporter;

  /// Cache for outline projections.
  /// Key: "$frameId:$focusNodeIds" (focus nodes joined by comma)
  final Map<String, _CachedProjection<String>> _outlineCache = {};

  /// Cache for DSL projections.
  /// Key: frameId
  final Map<String, _CachedProjection<String>> _dslCache = {};

  /// Version counter incremented on each document change.
  int _version = 0;

  ProjectionService({
    required EditorDocumentStore store,
    OutlineCompiler? outlineCompiler,
    DslExporter? dslExporter,
  })  : _store = store,
        _outlineCompiler = outlineCompiler ?? const OutlineCompiler(),
        _dslExporter = dslExporter ?? const DslExporter() {
    _store.addListener(_onDocumentChanged);
  }

  /// Current document.
  EditorDocument get document => _store.document;

  /// Dispose of resources.
  void dispose() {
    _store.removeListener(_onDocumentChanged);
    _outlineCache.clear();
    _dslCache.clear();
  }

  /// Get outline projection for a frame.
  ///
  /// [frameId] - The frame to generate outline for.
  /// [focusNodeIds] - Nodes to mark as "editing" in the outline.
  /// [maxDepth] - Maximum depth for expanded nodes (default: 2).
  ///
  /// Returns cached outline if available and valid, otherwise generates fresh.
  String getOutline({
    required String frameId,
    List<String> focusNodeIds = const [],
    int maxDepth = 2,
  }) {
    final cacheKey = _outlineCacheKey(frameId, focusNodeIds);
    final cached = _outlineCache[cacheKey];

    if (cached != null && cached.version == _version) {
      return cached.value;
    }

    // Generate fresh outline
    final outline = _outlineCompiler.compile(
      document,
      focusNodeIds: focusNodeIds,
      frameId: frameId,
      maxDepth: maxDepth,
    );

    _outlineCache[cacheKey] = _CachedProjection(outline, _version);
    return outline;
  }

  /// Get DSL projection for a frame.
  ///
  /// [frameId] - The frame to export as DSL.
  /// [includeIds] - Whether to include explicit node IDs (default: true).
  ///
  /// Returns cached DSL if available and valid, otherwise generates fresh.
  String getDsl({
    required String frameId,
    bool includeIds = true,
  }) {
    // Include 'includeIds' in cache key since it affects output
    final cacheKey = '$frameId:$includeIds';
    final cached = _dslCache[cacheKey];

    if (cached != null && cached.version == _version) {
      return cached.value;
    }

    // Generate fresh DSL
    final dsl = _dslExporter.exportFrame(
      document,
      frameId,
      includeIds: includeIds,
    );

    _dslCache[cacheKey] = _CachedProjection(dsl, _version);
    return dsl;
  }

  /// Get DSL for multiple frames.
  ///
  /// [frameIds] - The frames to export.
  /// [includeIds] - Whether to include explicit node IDs.
  String getMultiFrameDsl({
    required List<String> frameIds,
    bool includeIds = true,
  }) {
    return _dslExporter.exportFrames(
      document,
      frameIds,
      includeIds: includeIds,
    );
  }

  /// Get DSL for entire document.
  String getFullDocumentDsl({bool includeIds = true}) {
    return _dslExporter.exportDocument(document, includeIds: includeIds);
  }

  /// Invalidate all caches.
  ///
  /// Call this when the document has changed externally
  /// (e.g., after loading a new document).
  void invalidateAll() {
    _version++;
    _outlineCache.clear();
    _dslCache.clear();
  }

  /// Invalidate cache for a specific frame.
  ///
  /// More efficient than [invalidateAll] when only one frame changed.
  void invalidateFrame(String frameId) {
    _version++;

    // Remove all outline caches for this frame
    _outlineCache.removeWhere((key, _) => key.startsWith('$frameId:'));

    // Remove DSL caches for this frame
    _dslCache.removeWhere((key, _) => key.startsWith('$frameId:'));
  }

  /// Get cache statistics for debugging.
  ProjectionCacheStats getCacheStats() {
    return ProjectionCacheStats(
      outlineCacheSize: _outlineCache.length,
      dslCacheSize: _dslCache.length,
      currentVersion: _version,
    );
  }

  // ===========================================================================
  // Private
  // ===========================================================================

  void _onDocumentChanged() {
    // Increment version to invalidate all cached projections
    _version++;

    // Note: We don't clear caches here - they'll be lazily regenerated
    // when accessed. This is more efficient if only some projections
    // are actually needed.
  }

  String _outlineCacheKey(String frameId, List<String> focusNodeIds) {
    final sortedIds = [...focusNodeIds]..sort();
    return '$frameId:${sortedIds.join(',')}';
  }
}

/// Cached projection with version tracking.
class _CachedProjection<T> {
  final T value;
  final int version;

  _CachedProjection(this.value, this.version);
}

/// Statistics about projection cache state.
class ProjectionCacheStats {
  final int outlineCacheSize;
  final int dslCacheSize;
  final int currentVersion;

  const ProjectionCacheStats({
    required this.outlineCacheSize,
    required this.dslCacheSize,
    required this.currentVersion,
  });

  @override
  String toString() =>
      'ProjectionCacheStats(outlines: $outlineCacheSize, dsl: $dslCacheSize, version: $currentVersion)';
}
