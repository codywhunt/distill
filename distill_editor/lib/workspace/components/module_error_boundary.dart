import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../workspace_state.dart';

/// Error boundary widget that catches and displays errors from module content.
///
/// Prevents a single module's error from crashing the entire workspace.
/// Shows a user-friendly error message with the option to report or retry.
class ModuleErrorBoundary extends StatefulWidget {
  const ModuleErrorBoundary({
    super.key,
    required this.module,
    required this.child,
  });

  final ModuleType module;
  final Widget child;

  @override
  State<ModuleErrorBoundary> createState() => _ModuleErrorBoundaryState();
}

class _ModuleErrorBoundaryState extends State<ModuleErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ModuleErrorView(
        module: widget.module,
        error: _error!,
        stackTrace: _stackTrace,
        onRetry: _retry,
      );
    }

    return _ErrorCatcher(onError: _handleError, child: widget.child);
  }

  void _handleError(Object error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });

    // Log the error for debugging
    debugPrint('Error in ${widget.module.label} module: $error');
    debugPrint(stackTrace.toString());
  }

  void _retry() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }
}

/// Internal widget that catches errors during build.
class _ErrorCatcher extends StatelessWidget {
  const _ErrorCatcher({required this.onError, required this.child});

  final void Function(Object error, StackTrace stackTrace) onError;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Use ErrorWidget.builder to catch build errors
    final originalErrorBuilder = ErrorWidget.builder;

    ErrorWidget.builder = (FlutterErrorDetails details) {
      // Schedule the error handling after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onError(details.exception, details.stack ?? StackTrace.current);
      });

      // Return empty widget - the error view will be shown on next build
      return const SizedBox.shrink();
    };

    // Wrap in Builder to ensure we reset the error builder after this subtree
    return Builder(
      builder: (context) {
        // Reset after this frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ErrorWidget.builder = originalErrorBuilder;
        });
        return child;
      },
    );
  }
}

/// Error view shown when a module crashes.
class _ModuleErrorView extends StatelessWidget {
  const _ModuleErrorView({
    required this.module,
    required this.error,
    this.stackTrace,
    required this.onRetry,
  });

  final ModuleType module;
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.background.secondary,
      padding: EdgeInsets.all(context.spacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.colors.accent.red.overlay,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: 32,
                  color: context.colors.accent.red.primary,
                ),
              ),
              SizedBox(height: context.spacing.lg),

              // Title
              Text(
                '${module.label} encountered an error',
                style: context.typography.headings.medium.copyWith(
                  color: context.colors.foreground.primary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.spacing.sm),

              // Error message
              Text(
                error.toString(),
                style: context.typography.body.small.copyWith(
                  color: context.colors.foreground.muted,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: context.spacing.xl),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Retry button
                  HoloTappable(
                    onTap: onRetry,
                    builder: (context, states, _) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacing.lg,
                          vertical: context.spacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: states.resolve(
                            base: context.colors.background.primary,
                            hovered: context.colors.overlay.overlay05,
                            pressed: context.colors.overlay.overlay10,
                          ),
                          borderRadius: BorderRadius.circular(
                            context.radius.md,
                          ),
                          border: Border.all(
                            color: context.colors.overlay.overlay10,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.refreshCw,
                              size: 16,
                              color: context.colors.foreground.primary,
                            ),
                            SizedBox(width: context.spacing.xs),
                            Text(
                              'Retry',
                              style: context.typography.body.mediumStrong
                                  .copyWith(
                                    color: context.colors.foreground.primary,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
