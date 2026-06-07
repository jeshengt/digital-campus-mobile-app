import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationForegroundListener extends StatefulWidget {
  const NotificationForegroundListener({
    super.key,
    required this.child,
    NotificationService? notificationService,
    DateTime? startedAt,
  }) : _notificationService = notificationService,
       _startedAt = startedAt;

  final Widget child;
  final NotificationService? _notificationService;
  final DateTime? _startedAt;

  @override
  State<NotificationForegroundListener> createState() =>
      _NotificationForegroundListenerState();
}

class _NotificationForegroundListenerState
    extends State<NotificationForegroundListener> {
  late final NotificationService _notificationService;
  StreamSubscription<List<AppNotification>>? _subscription;
  final Set<String> _knownNotificationIds = <String>{};
  late final DateTime _startedAt;
  bool _hasPrimed = false;

  @override
  void initState() {
    super.initState();
    _startedAt = widget._startedAt ?? DateTime.now();
    _notificationService =
        widget._notificationService ?? FirebaseNotificationService();
    _subscription = _notificationService.watchCurrentUserNotifications().listen(
      _handleNotifications,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _handleNotifications(List<AppNotification> notifications) {
    final incomingIds = notifications
        .map((notification) => notification.notificationId)
        .toSet();

    if (!_hasPrimed) {
      _knownNotificationIds
        ..clear()
        ..addAll(incomingIds);
      _hasPrimed = true;
      return;
    }

    final newNotifications = notifications.where((notification) {
      return !_knownNotificationIds.contains(notification.notificationId) &&
          !notification.isRead &&
          notification.createdAt.isAfter(_startedAt) &&
          notification.type == notificationTypeFacilityBookingStatus;
    }).toList();

    _knownNotificationIds
      ..clear()
      ..addAll(incomingIds);

    if (newNotifications.isEmpty || !mounted) {
      return;
    }

    final newestNotification = newNotifications.first;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(newestNotification.message)));
  }
}
