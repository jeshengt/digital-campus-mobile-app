import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_dimensions.dart';

class UtmActionSurface extends StatelessWidget {
  const UtmActionSurface({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.statusLabel,
    this.accentColor,
    this.onTap,
    this.minHeight = 132,
    this.wide = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? statusLabel;
  final Color? accentColor;
  final VoidCallback? onTap;
  final double minHeight;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final effectiveAccent = accentColor ?? colors.brandMaroon;
    final radius = BorderRadius.circular(AppDimensions.radiusExtraLarge);
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: wide
            ? Row(
                children: [
                  _ActionIcon(icon: icon, color: effectiveAccent),
                  const SizedBox(width: AppDimensions.spacingMedium),
                  Expanded(
                    child: _ActionCopy(title: title, subtitle: subtitle),
                  ),
                  if (statusLabel != null) ...[
                    const SizedBox(width: AppDimensions.spacingSmall),
                    _StatusPill(label: statusLabel!),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _ActionIcon(icon: icon, color: effectiveAccent),
                      const Spacer(),
                      if (statusLabel != null) _StatusPill(label: statusLabel!),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingLarge),
                  _ActionCopy(title: title, subtitle: subtitle),
                ],
              ),
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: statusLabel == null ? title : '$title, $statusLabel',
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.brandMaroonSoft.withValues(alpha: 0.74),
                colors.brandGoldSoft.withValues(alpha: 0.5),
                colors.glass.withValues(alpha: 0.24),
              ],
            ),
          ),
          child: onTap == null
              ? content
              : InkWell(borderRadius: radius, onTap: onTap, child: content),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _ActionCopy extends StatelessWidget {
  const _ActionCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingTiny),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSmall,
        vertical: AppDimensions.spacingTiny,
      ),
      decoration: BoxDecoration(
        color: colors.brandGoldSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: colors.warning, fontSize: 11),
      ),
    );
  }
}
