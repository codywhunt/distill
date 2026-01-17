/// Rendering module for the free design DSL.
///
/// Provides the render pipeline that converts an [ExpandedScene] to
/// Flutter widgets:
/// - [RenderDocument] - Fully-compiled document ready for rendering
/// - [RenderCompiler] - Compiles ExpandedScene to RenderDocument
/// - [TokenResolver] - Resolves design token references
/// - [RenderEngine] - Converts RenderDocument to widgets
library;

export 'render_compiler.dart';
export 'render_document.dart';
export 'render_engine.dart';
export 'token_resolver.dart';
