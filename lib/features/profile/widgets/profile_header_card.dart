import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/utm_glass_panel.dart';
import '../models/app_user.dart';
import '../utils/profile_form_helpers.dart';

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key, required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final displayName = profile.name.isEmpty ? 'Your profile' : profile.name;
    final identifier = profileIdentifierValue(
      role: profile.role,
      matricNumber: profile.matricNumber,
      staffId: profile.staffId,
    ).trim();

    return Semantics(
      container: true,
      label: '$displayName, ${profile.role.label} profile',
      child: UtmGlassPanel(
        backgroundColor: Colors.transparent,
        borderRadius: AppDimensions.radiusExtraLarge,
        blurSigma: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusExtraLarge),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.brandMaroonSoft.withValues(alpha: 0.74),
                colors.brandGoldSoft.withValues(alpha: 0.48),
                colors.glass.withValues(alpha: 0.34),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineMedium?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSmall),
                Text(
                  profile.email,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMedium),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppDimensions.spacingSmall,
                  runSpacing: AppDimensions.spacingSmall,
                  children: [
                    _ProfilePill(
                      icon: Icons.badge_outlined,
                      label: profile.role.label.toUpperCase(),
                    ),
                    if (identifier.isNotEmpty)
                      _ProfilePill(
                        icon: Icons.credit_card_rounded,
                        label: identifier,
                        muted: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.icon,
    required this.label,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final foreground = muted ? colors.textSecondary : colors.brandMaroon;

    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: muted
            ? colors.glass.withValues(alpha: 0.46)
            : colors.brandMaroonSoft.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: AppDimensions.spacingTiny),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
