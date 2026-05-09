import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

class UtmInfoCard extends StatelessWidget {
  const UtmInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.statusLabel,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? statusLabel;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent =
        accentColor ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      container: true,
      label: statusLabel == null ? title : '$title, $statusLabel',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: effectiveAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMedium,
                      ),
                    ),
                    child: Icon(icon, color: effectiveAccent, size: 24),
                  ),
                  const Spacer(),
                  if (statusLabel != null) _StatusPill(label: statusLabel!),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSmall,
        vertical: AppDimensions.spacingTiny,
      ),
      decoration: BoxDecoration(
        color: AppColors.utmGoldTint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.utmGold.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.warning,
          fontSize: 11,
        ),
      ),
    );
  }
}
