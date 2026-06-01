import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_minimal_header.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLarge,
                AppDimensions.spacingMedium,
                AppDimensions.spacingLarge,
                AppDimensions.spacingLarge,
              ),
              children: const [
                UtmMinimalHeader(semanticLabel: 'Student dashboard'),
                SizedBox(height: AppDimensions.spacingLarge),
                _StudentScanPanel(),
                SizedBox(height: AppDimensions.spacingMedium),
                _StudentQuickActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<Color> _studentCardGradientColors(UtmThemeColors colors) {
  return [
    colors.brandMaroonSoft.withValues(alpha: 0.74),
    colors.brandGoldSoft.withValues(alpha: 0.5),
    colors.glass.withValues(alpha: 0.24),
  ];
}

class _StudentScanPanel extends StatelessWidget {
  const _StudentScanPanel();

  @override
  Widget build(BuildContext context) {
    return _StudentActionCard(
      title: 'Scan Attendance QR',
      subtitle: 'Scan the QR code to record your attendance.',
      icon: Icons.qr_code_scanner_rounded,
      isWide: true,
      onTap: () =>
          Navigator.pushNamed(context, AppRoutes.studentScanAttendance),
    );
  }
}

class _StudentQuickActions extends StatelessWidget {
  const _StudentQuickActions();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth < 560;
        final booking = _StudentActionCard(
          title: 'Book a Facility',
          subtitle: 'Reserve an available time slot.',
          icon: Icons.event_available_outlined,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.studentFacilityBooking),
        );
        final buses = _StudentActionCard(
          title: 'Track Buses',
          subtitle: 'View live locations for campus buses.',
          icon: Icons.directions_bus_filled_outlined,
          onTap: () => Navigator.pushNamed(context, AppRoutes.busTrackingMap),
        );
        final history = _StudentActionCard(
          title: 'Attendance History',
          subtitle: 'View your attendance records.',
          icon: Icons.fact_check_outlined,
          isWide: useGrid,
          onTap: () =>
              Navigator.pushNamed(context, AppRoutes.studentAttendanceHistory),
        );

        if (!useGrid) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: booking),
              const SizedBox(width: AppDimensions.spacingMedium),
              Expanded(child: buses),
              const SizedBox(width: AppDimensions.spacingMedium),
              Expanded(child: history),
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: booking),
                const SizedBox(width: AppDimensions.spacingMedium),
                Expanded(child: buses),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMedium),
            history,
          ],
        );
      },
    );
  }
}

class _StudentActionCard extends StatelessWidget {
  const _StudentActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isWide = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppDimensions.radiusExtraLarge);

    return Semantics(
      button: true,
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius),
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
                colors: _studentCardGradientColors(colors),
              ),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: isWide ? 104 : 132),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingMedium),
                  child: isWide
                      ? Row(
                          children: [
                            _StudentActionIcon(icon: icon),
                            const SizedBox(width: AppDimensions.spacingMedium),
                            Expanded(
                              child: _StudentActionCopy(
                                title: title,
                                subtitle: subtitle,
                                textTheme: textTheme,
                                colors: colors,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _StudentActionIcon(icon: icon),
                            const SizedBox(height: AppDimensions.spacingLarge),
                            _StudentActionCopy(
                              title: title,
                              subtitle: subtitle,
                              textTheme: textTheme,
                              colors: colors,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentActionIcon extends StatelessWidget {
  const _StudentActionIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colors.brandMaroon.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
      child: Icon(icon, color: colors.brandMaroon, size: 24),
    );
  }
}

class _StudentActionCopy extends StatelessWidget {
  const _StudentActionCopy({
    required this.title,
    required this.subtitle,
    required this.textTheme,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final TextTheme textTheme;
  final UtmThemeColors colors;

  @override
  Widget build(BuildContext context) {
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
