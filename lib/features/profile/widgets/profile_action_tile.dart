import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool isDestructive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final foregroundColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : colors.textPrimary;
    final iconColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : colors.brandMaroon;
    final iconBackground = isDestructive
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
        : colors.brandMaroonSoft.withValues(alpha: 0.72);
    final radius = BorderRadius.circular(AppDimensions.radiusLarge);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMedium,
                vertical: AppDimensions.spacingSmall,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: foregroundColor,
                            ),
                          )
                        : Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: AppDimensions.spacingMedium),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: foregroundColor,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppDimensions.spacingTiny),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isDestructive)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSecondary,
                    ),
                  if (isDestructive)
                    const SizedBox(width: AppDimensions.spacingLarge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
