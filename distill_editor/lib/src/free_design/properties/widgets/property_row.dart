import 'package:flutter/widgets.dart';
import 'package:distill_ds/design_system.dart';

/// Simple row for a property editor with label and input.
class PropertyRow extends StatelessWidget {
  const PropertyRow({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: typography.body.medium.copyWith(
                color: colors.foreground.muted,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}
