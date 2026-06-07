import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../services/notification_service.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, NotificationService? notificationService})
    : _notificationService = notificationService;

  final NotificationService? _notificationService;

  @override
  Widget build(BuildContext context) {
    final notificationService = _notificationService;
    if (notificationService == null && Firebase.apps.isEmpty) {
      return const SizedBox.shrink();
    }

    final service = notificationService ?? FirebaseNotificationService();
    final colors = UtmThemeColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? colors.glass.withValues(alpha: 0.1)
        : colors.brandMaroon.withValues(alpha: 0.1);
    final foregroundColor = isDark
        ? colors.textPrimary.withValues(alpha: 0.76)
        : colors.brandMaroon;

    return StreamBuilder<int>(
      stream: service.watchUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Semantics(
          label: unreadCount > 0
              ? 'Open notifications, $unreadCount unread'
              : 'Open notifications',
          button: true,
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.notifications),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              fixedSize: const Size.square(48),
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              shape: const CircleBorder(),
            ),
            icon: _NotificationBellIcon(unreadCount: unreadCount),
          ),
        );
      },
    );
  }
}

class _NotificationBellIcon extends StatelessWidget {
  const _NotificationBellIcon({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colors = UtmThemeColors.of(context);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const Icon(Icons.notifications_none_rounded),
        if (unreadCount > 0)
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: colors.brandGold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
