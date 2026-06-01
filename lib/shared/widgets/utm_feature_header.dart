import 'package:flutter/material.dart';

import 'utm_action_surface.dart';

class UtmFeatureHeader extends StatelessWidget {
  const UtmFeatureHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return UtmActionSurface(
      icon: icon,
      title: title,
      subtitle: subtitle,
      minHeight: 80,
      wide: true,
    );
  }
}
