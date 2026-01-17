import 'package:flutter/widgets.dart';
import 'package:distill_ds/design_system.dart';

/// Section header with title and optional divider.
class PropertySectionHeader extends StatelessWidget {
  const PropertySectionHeader({
    required this.title,
    this.showTopDivider = true,
    super.key,
  });

  final String title;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTopDivider) ...[
            SizedBox(height: spacing.lg),
            Container(height: 1, color: colors.overlay.overlay10),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.lg,
              spacing.md,
              spacing.md,
            ),
            child: Text(
              title,
              style: typography.body.medium.copyWith(
                color: colors.foreground.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
