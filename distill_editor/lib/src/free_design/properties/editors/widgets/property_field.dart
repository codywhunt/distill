import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// A simplified property field that provides a label-input layout.
///
/// This is the standard two-column layout for property editors, providing:
/// - Label on the left (fixed width)
/// - Editor widget on the right (flexible)
/// - Optional tooltip on label hover
///
/// Example usage:
/// ```dart
/// PropertyField(
///   label: 'Width',
///   tooltip: 'The width of the element',
///   child: NumberEditor(
///     value: 100,
///     onChanged: (v) => store.updateNodeProp(nodeId, '/style/width', v),
///     suffix: Text('px'),
///   ),
/// )
/// ```
class PropertyField extends StatelessWidget {
  /// The property label text.
  final String label;

  /// Optional tooltip shown on hover.
  final String? tooltip;

  /// The editor widget (input).
  final Widget child;

  /// Cross axis alignment. Use [CrossAxisAlignment.start] for multiline inputs.
  final CrossAxisAlignment crossAxisAlignment;

  const PropertyField({
    super.key,
    required this.label,
    this.tooltip,
    required this.child,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          // Label column (fixed width)
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerLeft,
              child: tooltip != null
                  ? Tooltip(
                      message: tooltip!,
                      child: Text(
                        label,
                        style: context.typography.body.medium.copyWith(
                          color: context.colors.foreground.muted,
                        ),
                      ),
                    )
                  : Text(
                      label,
                      style: context.typography.body.medium.copyWith(
                        color: context.colors.foreground.muted,
                      ),
                    ),
            ),
          ),
          SizedBox(width: context.spacing.sm),
          // Editor column (flexible)
          Expanded(child: child),
        ],
      ),
    );
  }
}
