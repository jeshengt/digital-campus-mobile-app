import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class UtmSoftGlowBackground extends StatelessWidget {
  const UtmSoftGlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maroonAlpha = isDark ? 0.12 : 0.1;
    final goldAlpha = isDark ? 0.08 : 0.1;
    final lowerMaroonAlpha = isDark ? 0.08 : 0.05;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.background,
                colors.heroEnd.withValues(alpha: isDark ? 0.34 : 0.42),
                colors.background,
              ],
            ),
          ),
        ),
        Positioned(
          left: -180,
          top: -190,
          width: 520,
          height: 520,
          child: _Glow(
            color: colors.brandMaroon.withValues(alpha: maroonAlpha),
          ),
        ),
        Positioned(
          right: -180,
          top: -150,
          width: 500,
          height: 500,
          child: _Glow(color: colors.brandGold.withValues(alpha: goldAlpha)),
        ),
        Positioned(
          left: 40,
          right: -220,
          bottom: -240,
          height: 540,
          child: _Glow(
            color: colors.brandMaroon.withValues(alpha: lowerMaroonAlpha),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
