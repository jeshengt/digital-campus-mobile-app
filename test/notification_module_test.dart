import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/routes/app_routes.dart';
import 'package:utmgo/app/theme/app_theme.dart';
import 'package:utmgo/features/booking/models/facility_booking.dart';
import 'package:utmgo/features/booking/utils/booking_validation.dart';
import 'package:utmgo/features/notifications/models/app_notification.dart';
import 'package:utmgo/features/notifications/screens/notifications_screen.dart';
import 'package:utmgo/features/notifications/services/notification_service.dart';
import 'package:utmgo/features/notifications/utils/facility_booking_notification_builder.dart';
import 'package:utmgo/features/notifications/widgets/notification_bell.dart';
import 'package:utmgo/features/notifications/widgets/notification_foreground_listener.dart';

void main() {
  group('Notification models', () {
    test('maps notification data', () {
      final notification = _sampleNotification();

      final parsed = AppNotification.fromMap(notification.toMap());

      expect(parsed.notificationId, 'notification-1');
      expect(parsed.userId, 'student-1');
      expect(parsed.type, notificationTypeFacilityBookingStatus);
      expect(parsed.bookingId, 'booking-1');
      expect(parsed.facilityName, 'Seminar Room A');
      expect(parsed.status, bookingStatusApproved);
      expect(parsed.isRead, isFalse);
      expect(parsed.createdAt, DateTime(2026, 6, 2, 10));
    });

    test('builds facility booking status notification copy', () {
      final notification = buildFacilityBookingStatusNotification(
        notificationId: 'notification-1',
        booking: _sampleBooking(),
        status: bookingStatusCancelled,
        createdAt: DateTime(2026, 6, 2, 11),
      );

      expect(notification.userId, 'student-1');
      expect(notification.title, 'Facility booking cancelled');
      expect(
        notification.message,
        'Your Seminar Room A booking has been cancelled.',
      );
      expect(notification.type, notificationTypeFacilityBookingStatus);
      expect(notification.isRead, isFalse);
    });
  });

  group('Notification routes and widgets', () {
    test('registers notifications route', () {
      final routes = AppRoutes.routes(isFirebaseReady: true);

      expect(routes.containsKey(AppRoutes.notifications), isTrue);
      expect(AppRoutes.notifications, '/notifications');
    });

    testWidgets('notification bell shows unread count and opens inbox', (
      tester,
    ) async {
      final service = _FakeNotificationService(
        notifications: [
          _sampleNotification(),
          _sampleNotification(id: 'n2'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.notifications: (_) =>
                const Scaffold(body: Text('Notifications route opened')),
          },
          home: Scaffold(body: NotificationBell(notificationService: service)),
        ),
      );

      await tester.pump();

      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications route opened'), findsOneWidget);
    });

    testWidgets('notifications screen shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationsScreen(
            notificationService: _FakeNotificationService(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(
        find.text('Your notifications will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('notifications screen marks booking notification read on tap', (
      tester,
    ) async {
      final service = _FakeNotificationService(
        notifications: [_sampleNotification()],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.studentFacilityBooking: (_) =>
                const Scaffold(body: Text('Student booking route opened')),
          },
          home: NotificationsScreen(notificationService: service),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Facility booking approved'));
      await tester.pumpAndSettle();

      expect(service.readNotificationIds, ['notification-1']);
      expect(find.text('Student booking route opened'), findsOneWidget);
    });

    testWidgets('foreground listener shows alert for new unread notification', (
      tester,
    ) async {
      final controller = StreamController<List<AppNotification>>.broadcast();
      final service = _FakeNotificationService(stream: controller.stream);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: NotificationForegroundListener(
            notificationService: service,
            startedAt: DateTime(2026, 6, 2, 9),
            child: const Scaffold(body: Text('Dashboard')),
          ),
        ),
      );

      await tester.pump();
      controller.add(const <AppNotification>[]);
      await tester.pump();
      controller.add([_sampleNotification()]);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Your Seminar Room A booking has been approved.'),
        findsOneWidget,
      );

      await controller.close();
    });
  });
}

AppNotification _sampleNotification({
  String id = 'notification-1',
  bool isRead = false,
  String status = bookingStatusApproved,
}) {
  return AppNotification(
    notificationId: id,
    userId: 'student-1',
    title: 'Facility booking approved',
    message: 'Your Seminar Room A booking has been approved.',
    type: notificationTypeFacilityBookingStatus,
    bookingId: 'booking-1',
    facilityId: 'facility-1',
    facilityName: 'Seminar Room A',
    status: status,
    isRead: isRead,
    createdAt: DateTime(2026, 6, 2, 10),
  );
}

FacilityBooking _sampleBooking() {
  return FacilityBooking(
    bookingId: 'booking-1',
    slotOccurrenceId: 'slot-1',
    facilityId: 'facility-1',
    templateId: 'template-1',
    facilityName: 'Seminar Room A',
    studentId: 'student-1',
    studentName: 'Aina',
    studentEmail: 'aina@example.com',
    requestedDate: DateTime(2026, 6, 3),
    startTime: DateTime(2026, 6, 3, 9),
    endTime: DateTime(2026, 6, 3, 10),
    status: bookingStatusPending,
    reviewedBy: null,
    reviewedAt: null,
    createdAt: DateTime(2026, 6, 1, 9),
    updatedAt: DateTime(2026, 6, 1, 9),
  );
}

class _FakeNotificationService implements NotificationService {
  _FakeNotificationService({
    List<AppNotification> notifications = const <AppNotification>[],
    Stream<List<AppNotification>>? stream,
  }) : _notifications = notifications,
       _stream = stream;

  final List<AppNotification> _notifications;
  final Stream<List<AppNotification>>? _stream;
  final readNotificationIds = <String>[];

  @override
  Stream<List<AppNotification>> watchCurrentUserNotifications() {
    return _stream ?? Stream.value(_notifications);
  }

  @override
  Stream<int> watchUnreadCount() {
    return watchCurrentUserNotifications().map((notifications) {
      return notifications.where((notification) => !notification.isRead).length;
    });
  }

  @override
  Future<void> markAsRead(AppNotification notification) async {
    readNotificationIds.add(notification.notificationId);
  }
}
