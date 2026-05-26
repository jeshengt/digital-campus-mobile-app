import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/bus_location.dart';
import '../models/campus_bus.dart';
import '../utils/bus_tracking_helpers.dart';

class BusStatusCard extends StatelessWidget {
  const BusStatusCard({
    super.key,
    required this.bus,
    required this.location,
    this.onTap,
    this.isSelected = false,
  });

  final CampusBus bus;
  final BusLocation? location;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final live = location?.isBroadcasting ?? false;
    final eta = formatEta(
      location == null
          ? null
          : estimateEta(location: location!, destination: bus.destinationPoint),
    );

    return Semantics(
      button: onTap != null,
      label: '${bus.routeName}, ${live ? 'live' : 'offline'}',
      child: Card(
        color: isSelected ? AppColors.utmMaroonTint : AppColors.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: live
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                  child: Icon(
                    Icons.directions_bus_filled_rounded,
                    color: live ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bus.routeName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          _LivePill(live: live),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingTiny),
                      Text(
                        bus.status,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingSmall),
                      Wrap(
                        spacing: AppDimensions.spacingSmall,
                        runSpacing: AppDimensions.spacingSmall,
                        children: [
                          _MetricChip(icon: Icons.schedule_rounded, label: eta),
                          if (location != null)
                            _MetricChip(
                              icon: Icons.speed_rounded,
                              label:
                                  '${(location!.speed * 3.6).toStringAsFixed(0)} km/h',
                            ),
                          if (location != null)
                            _MetricChip(
                              icon: Icons.update_rounded,
                              label: formatUpdatedAt(location!.updatedAt),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSmall,
        vertical: AppDimensions.spacingTiny,
      ),
      decoration: BoxDecoration(
        color: live
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.border,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        live ? 'Live' : 'Offline',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: live ? AppColors.success : AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingSmall,
        vertical: AppDimensions.spacingTiny,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: AppDimensions.spacingTiny),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
