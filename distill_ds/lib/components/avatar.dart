import 'package:flutter/material.dart';

import '../tokens/theme.dart';
import '../foundation/tappable.dart';

/// Avatar sizes.
enum HoloAvatarSize {
  /// 20x20
  xs(20),
  /// 24x24
  sm(24),
  /// 32x32
  md(32),
  /// 40x40
  lg(40);

  const HoloAvatarSize(this.size);
  final double size;
}

/// Avatar shapes.
enum HoloAvatarShape {
  circle,
  rounded,
}

/// A user avatar component.
///
/// Displays either:
/// - A photo from a URL
/// - Initials derived from the name
///
/// ```dart
/// HoloAvatar(
///   name: 'John Doe',
///   imageUrl: 'https://example.com/avatar.jpg',
///   size: HoloAvatarSize.md,
/// )
/// ```
class HoloAvatar extends StatelessWidget {
  const HoloAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = HoloAvatarSize.md,
    this.shape = HoloAvatarShape.circle,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  });

  /// The user's name (used for initials fallback).
  final String name;

  /// Optional image URL.
  final String? imageUrl;

  /// Size of the avatar.
  final HoloAvatarSize size;

  /// Shape of the avatar.
  final HoloAvatarShape shape;

  /// Custom background color (defaults to accent purple).
  final Color? backgroundColor;

  /// Custom foreground/text color (defaults to white).
  final Color? foregroundColor;

  /// Optional tap callback.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;

    final bgColor = backgroundColor ?? colors.accent.purple.primary;
    final fgColor = foregroundColor ?? Colors.white;

    final borderRadius = shape == HoloAvatarShape.circle
        ? BorderRadius.circular(size.size / 2)
        : BorderRadius.circular(radius.sm);

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl!,
          width: size.size,
          height: size.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitials(context, bgColor, fgColor),
        ),
      );
    } else {
      content = _buildInitials(context, bgColor, fgColor);
    }

    if (onTap != null) {
      return HoloTappable(
        onTap: onTap,
        builder: (context, states, child) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: states.isHovered ? 0.9 : 1.0,
            child: content,
          );
        },
      );
    }

    return content;
  }

  Widget _buildInitials(BuildContext context, Color bgColor, Color fgColor) {
    final typography = context.typography;
    final initials = _getInitials(name);

    // Select font size based on avatar size
    final textStyle = switch (size) {
      HoloAvatarSize.xs => typography.body.small,
      HoloAvatarSize.sm => typography.body.small,
      HoloAvatarSize.md => typography.body.mediumStrong,
      HoloAvatarSize.lg => typography.body.largeStrong,
    };

    final borderRadius = shape == HoloAvatarShape.circle
        ? BorderRadius.circular(size.size / 2)
        : BorderRadius.circular(context.radius.sm);

    return Container(
      width: size.size,
      height: size.size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Text(
          initials,
          style: textStyle.copyWith(color: fgColor),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }

    // First letter of first and last name
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
