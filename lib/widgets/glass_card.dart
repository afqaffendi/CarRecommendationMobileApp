import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Clean white card with soft warm shadow — replaces the dark glassmorphism style.
/// The [blur] parameter is kept for API compatibility but is no longer used.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color? backgroundColor;
  final bool blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.backgroundColor,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.warmSurface,
        borderRadius: borderRadius,
        border: Border.all(color: AppTheme.cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B7355).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF8B7355).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
