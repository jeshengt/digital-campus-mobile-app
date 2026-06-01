import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/user_role.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_feature_header.dart';
import '../../../shared/widgets/utm_glass_panel.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/system_analytics_snapshot.dart';
import '../services/system_analytics_service.dart';

class SystemAnalyticsScreen extends StatefulWidget {
  const SystemAnalyticsScreen({super.key, this.analyticsService});

  final SystemAnalyticsService? analyticsService;

  @override
  State<SystemAnalyticsScreen> createState() => _SystemAnalyticsScreenState();
}

class _SystemAnalyticsScreenState extends State<SystemAnalyticsScreen> {
  late SystemAnalyticsService _analyticsService;
  late Stream<SystemAnalyticsSnapshot> _analyticsStream;

  @override
  void initState() {
    super.initState();
    _setAnalyticsService();
  }

  @override
  void didUpdateWidget(SystemAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analyticsService != widget.analyticsService) {
      _setAnalyticsService();
    }
  }

  void _setAnalyticsService() {
    _analyticsService =
        widget.analyticsService ?? FirebaseSystemAnalyticsService();
    _analyticsStream = _analyticsService.watchSystemAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Analytics'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<SystemAnalyticsSnapshot>(
              stream: _analyticsStream,
              builder: (context, snapshot) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingMedium,
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingLarge,
                  ),
                  children: [
                    const UtmFeatureHeader(
                      icon: Icons.analytics_outlined,
                      title: 'Campus Overview',
                      subtitle: 'Monitor campus activity and key metrics.',
                    ),
                    const SizedBox(height: AppDimensions.spacingLarge),
                    if (snapshot.hasError)
                      const _AnalyticsMessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load analytics',
                        message:
                            'Check that this account has admin access and try again.',
                      )
                    else if (!snapshot.hasData)
                      const _AnalyticsMessageState(
                        icon: Icons.query_stats_rounded,
                        title: 'Loading analytics',
                        message: 'Collecting read-only campus metrics.',
                        showProgress: true,
                      )
                    else if (snapshot.data!.isEmpty)
                      const _AnalyticsMessageState(
                        icon: Icons.insights_outlined,
                        title: 'No analytics data yet',
                        message:
                            'Metrics will appear after users, bookings, attendance, or bus routes are created.',
                      )
                    else
                      _AnalyticsDashboard(snapshot: snapshot.data!),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsDashboard extends StatelessWidget {
  const _AnalyticsDashboard({required this.snapshot});

  final SystemAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricGrid(
          cards: [
            _MetricCardData(
              icon: Icons.people_alt_outlined,
              label: 'Users',
              value: snapshot.totalUsers,
              detail: '${snapshot.verifiedUsers} verified',
              color: colors.brandMaroon,
            ),
            _MetricCardData(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Attendance',
              value: snapshot.totalAttendanceSessions,
              detail: '${snapshot.totalAttendanceRecords} records',
              color: colors.success,
            ),
            _MetricCardData(
              icon: Icons.meeting_room_outlined,
              label: 'Bookings',
              value: snapshot.totalBookings,
              detail: '${snapshot.pendingBookings} pending',
              color: colors.warning,
            ),
            _MetricCardData(
              icon: Icons.directions_bus_filled_outlined,
              label: 'Bus Routes',
              value: snapshot.totalBusRoutes,
              detail: '${snapshot.liveBusBroadcasts} live',
              color: colors.brandGold,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingLarge),
        _AnalyticsSection(
          title: 'Role Distribution',
          rows: [
            for (final role in UserRole.values)
              _AnalyticsRowData(
                label: role.label,
                value: snapshot.roleCount(role),
                total: snapshot.totalUsers,
                color: role == UserRole.admin
                    ? colors.brandMaroon
                    : colors.brandGold,
              ),
            _AnalyticsRowData(
              label: 'Verified emails',
              value: snapshot.verifiedUsers,
              total: snapshot.totalUsers,
              color: colors.success,
            ),
            _AnalyticsRowData(
              label: 'Unverified emails',
              value: snapshot.unverifiedUsers,
              total: snapshot.totalUsers,
              color: colors.error,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _AnalyticsSection(
          title: 'Attendance Status',
          rows: [
            _AnalyticsRowData(
              label: 'Active sessions',
              value: snapshot.activeAttendanceSessions,
              total: snapshot.totalAttendanceSessions,
              color: colors.success,
            ),
            _AnalyticsRowData(
              label: 'Closed sessions',
              value: snapshot.closedAttendanceSessions,
              total: snapshot.totalAttendanceSessions,
              color: colors.textTertiary,
            ),
            _AnalyticsRowData(
              label: 'Location validated records',
              value: snapshot.locationValidatedAttendanceRecords,
              total: snapshot.totalAttendanceRecords,
              color: colors.brandMaroon,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _AnalyticsSection(
          title: 'Facilities and Bookings',
          rows: [
            _AnalyticsRowData(
              label: 'Available facilities',
              value: snapshot.availableFacilities,
              total: snapshot.totalFacilities,
              color: colors.success,
            ),
            _AnalyticsRowData(
              label: 'Unavailable facilities',
              value: snapshot.unavailableFacilities,
              total: snapshot.totalFacilities,
              color: colors.error,
            ),
            _AnalyticsRowData(
              label: 'Pending bookings',
              value: snapshot.pendingBookings,
              total: snapshot.totalBookings,
              color: colors.warning,
            ),
            _AnalyticsRowData(
              label: 'Approved bookings',
              value: snapshot.approvedBookings,
              total: snapshot.totalBookings,
              color: colors.success,
            ),
            _AnalyticsRowData(
              label: 'Cancelled bookings',
              value: snapshot.cancelledBookings,
              total: snapshot.totalBookings,
              color: colors.textTertiary,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMedium),
        _AnalyticsSection(
          title: 'Bus Operations',
          rows: [
            _AnalyticsRowData(
              label: 'Active routes',
              value: snapshot.activeBusRoutes,
              total: snapshot.totalBusRoutes,
              color: colors.success,
            ),
            _AnalyticsRowData(
              label: 'Inactive routes',
              value: snapshot.inactiveBusRoutes,
              total: snapshot.totalBusRoutes,
              color: colors.textTertiary,
            ),
            _AnalyticsRowData(
              label: 'Assigned routes',
              value: snapshot.assignedBusRoutes,
              total: snapshot.totalBusRoutes,
              color: colors.brandMaroon,
            ),
            _AnalyticsRowData(
              label: 'Unassigned routes',
              value: snapshot.unassignedBusRoutes,
              total: snapshot.totalBusRoutes,
              color: colors.warning,
            ),
            _AnalyticsRowData(
              label: 'Live broadcasts',
              value: snapshot.liveBusBroadcasts,
              total: snapshot.totalBusRoutes,
              color: colors.success,
            ),
            _AnalyticsRowData(
              label: 'Stale broadcasts',
              value: snapshot.staleBusBroadcasts,
              total: snapshot.totalBusRoutes,
              color: colors.error,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<_MetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >=
                (AppDimensions.dashboardCardMinWidth * 2 +
                    AppDimensions.spacingMedium)
            ? 2
            : 1;
        final width =
            (constraints.maxWidth -
                (AppDimensions.spacingMedium * (columns - 1))) /
            columns;

        return Wrap(
          spacing: AppDimensions.spacingMedium,
          runSpacing: AppDimensions.spacingMedium,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _MetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Semantics(
      container: true,
      label: '${data.label}: ${data.value}',
      child: UtmGlassPanel(
        backgroundColor: colors.glassStrong,
        borderRadius: AppDimensions.radiusExtraLarge,
        padding: const EdgeInsets.all(AppDimensions.spacingMedium),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: data.color.withValues(alpha: 0.14)),
              ),
              child: Icon(data.icon, color: data.color),
            ),
            const SizedBox(width: AppDimensions.spacingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    data.value.toString(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppDimensions.spacingTiny),
                  Text(
                    data.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({required this.title, required this.rows});

  final String title;
  final List<_AnalyticsRowData> rows;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return UtmGlassPanel(
      backgroundColor: colors.glassStrong,
      borderRadius: AppDimensions.radiusExtraLarge,
      padding: const EdgeInsets.all(AppDimensions.spacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDimensions.spacingMedium),
          for (final row in rows) ...[
            _AnalyticsBreakdownRow(row: row),
            if (row != rows.last)
              const SizedBox(height: AppDimensions.spacingMedium),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsBreakdownRow extends StatelessWidget {
  const _AnalyticsBreakdownRow({required this.row});

  final _AnalyticsRowData row;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final progress = row.total <= 0 ? 0.0 : row.value / row.total;

    return Semantics(
      label: '${row.label}: ${row.value}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                row.value.toString(),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmall),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: colors.mutedSurface,
              color: row.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMessageState extends StatelessWidget {
  const _AnalyticsMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return UtmGlassPanel(
      backgroundColor: colors.glassStrong,
      borderRadius: AppDimensions.radiusExtraLarge,
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Column(
        children: [
          Icon(icon, color: colors.brandMaroon, size: 40),
          const SizedBox(height: AppDimensions.spacingMedium),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDimensions.spacingSmall),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (showProgress) ...[
            const SizedBox(height: AppDimensions.spacingMedium),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final String detail;
  final Color color;
}

class _AnalyticsRowData {
  const _AnalyticsRowData({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;
}
