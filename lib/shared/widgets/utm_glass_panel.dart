import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_dimensions.dart';

class UtmGlassPanel extends StatelessWidget {
  const UtmGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppDimensions.radiusLarge,
    this.backgroundColor,
    this.borderColor,
    this.blurSigma = 24,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double blurSigma;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? colors.glass,
            borderRadius: radius,
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 44,
                      offset: const Offset(0, 22),
                    ),
                  ]
                : null,
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}
