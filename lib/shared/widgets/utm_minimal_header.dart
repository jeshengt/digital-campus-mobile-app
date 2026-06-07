import 'package:flutter/material.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';
import '../../features/notifications/widgets/notification_bell.dart';

class UtmMinimalHeader extends StatelessWidget {
  const UtmMinimalHeader({
    super.key,
    this.semanticLabel,
    this.showProfileAction = true,
  });

  static const logoAsset = 'assets/images/utmlogoheader.png';
  static const darkLogoAsset = 'assets/images/utmlogoheader_dark.png';

  final String? semanticLabel;
  final bool showProfileAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveLogoAsset = isDark ? darkLogoAsset : logoAsset;

    final header = SizedBox(
      height: 58,
      child: Row(
        children: [
          Semantics(
            image: true,
            label: 'UTM Go logo',
            child: SizedBox(
              width: 118,
              height: 46,
              child: Image.asset(
                effectiveLogoAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const Spacer(),
          if (showProfileAction) const NotificationBell(),
          if (showProfileAction) const SizedBox(width: 8),
          if (showProfileAction) const _ProfileActionButton(),
        ],
      ),
    );

    if (semanticLabel == null) {
      return header;
    }

    return Semantics(label: semanticLabel, header: true, child: header);
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton();

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? colors.glass.withValues(alpha: 0.1)
        : colors.brandMaroon.withValues(alpha: 0.1);
    final foregroundColor = isDark
        ? colors.textPrimary.withValues(alpha: 0.76)
        : colors.brandMaroon;

    return Semantics(
      label: 'Open profile',
      button: true,
      child: IconButton(
        tooltip: 'Profile',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.profile),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(48),
          fixedSize: const Size.square(48),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: const CircleBorder(),
        ),
        icon: const Icon(Icons.person_outline_rounded),
      ),
    );
  }
}
