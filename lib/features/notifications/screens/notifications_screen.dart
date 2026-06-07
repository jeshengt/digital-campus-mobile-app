import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/layouts/utm_background_scaffold.dart';
import '../../../shared/widgets/utm_glass_panel.dart';
import '../../../shared/widgets/utm_top_app_bar.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    NotificationService? notificationService,
  }) : _notificationService = notificationService;

  final NotificationService? _notificationService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService =
        widget._notificationService ?? FirebaseNotificationService();
  }

  @override
  Widget build(BuildContext context) {
    return UtmBackgroundScaffold(
      appBar: const UtmTopAppBar(title: 'Notifications'),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxDashboardWidth,
            ),
            child: StreamBuilder<List<AppNotification>>(
              stream: _notificationService.watchCurrentUserNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const _NotificationEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load notifications',
                    message: 'Please try again later.',
                  );
                }

                final notifications =
                    snapshot.data ?? const <AppNotification>[];
                if (notifications.isEmpty) {
                  return const _NotificationEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications yet',
                    message: 'Your notifications will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingMedium,
                    AppDimensions.spacingLarge,
                    AppDimensions.spacingLarge,
                  ),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () => _openNotification(notification),
                    );
                  },
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppDimensions.spacingMedium),
                  itemCount: notifications.length,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(AppNotification notification) async {
    try {
      await _notificationService.markAsRead(notification);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark notification as read.')),
      );
    }

    if (!mounted) {
      return;
    }

    if (notification.type == notificationTypeFacilityBookingStatus) {
      Navigator.pushNamed(context, AppRoutes.studentMyBookings);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusColor(colors, notification.status);

    return UtmGlassPanel(
      borderColor: notification.isRead
          ? colors.glassBorder
          : colors.brandGold.withValues(alpha: 0.72),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMedium),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusMedium,
                    ),
                  ),
                  child: Icon(
                    _statusIcon(notification.status),
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(
                                top: AppDimensions.spacingSmall,
                              ),
                              decoration: BoxDecoration(
                                color: colors.brandGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingTiny),
                      Text(
                        notification.message,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSmall),
                      Text(
                        notification.facilityName,
                        style: textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
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

  Color _statusColor(UtmThemeColors colors, String status) {
    return switch (status) {
      'approved' => colors.success,
      'cancelled' => colors.textTertiary,
      _ => colors.brandMaroon,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'approved' => Icons.check_circle_outline_rounded,
      'cancelled' => Icons.cancel_outlined,
      _ => Icons.notifications_none_rounded,
    };
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingLarge),
      child: Center(
        child: UtmGlassPanel(
          padding: const EdgeInsets.all(AppDimensions.spacingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.brandMaroon, size: 40),
              const SizedBox(height: AppDimensions.spacingMedium),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSmall),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
