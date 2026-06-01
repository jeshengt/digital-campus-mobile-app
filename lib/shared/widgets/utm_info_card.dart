import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'utm_action_surface.dart';

class UtmInfoCard extends StatelessWidget {
  const UtmInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.statusLabel,
    this.accentColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? statusLabel;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final effectiveAccent = accentColor ?? colors.brandMaroon;

    return UtmActionSurface(
      icon: icon,
      title: title,
      subtitle: description,
      statusLabel: statusLabel,
      accentColor: effectiveAccent,
      onTap: onTap,
    );
  }
}
