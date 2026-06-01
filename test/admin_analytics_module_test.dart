import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/routes/app_routes.dart';
import 'package:utmgo/app/theme/app_theme.dart';
import 'package:utmgo/features/admin/models/system_analytics_snapshot.dart';
import 'package:utmgo/features/admin/screens/admin_dashboard_screen.dart';
import 'package:utmgo/features/admin/screens/system_analytics_screen.dart';
import 'package:utmgo/features/admin/services/system_analytics_service.dart';
import 'package:utmgo/features/attendance/models/attendance_record.dart';
import 'package:utmgo/features/attendance/models/attendance_session.dart';
import 'package:utmgo/features/booking/models/facility.dart';
import 'package:utmgo/features/booking/models/facility_booking.dart';
import 'package:utmgo/features/booking/utils/booking_validation.dart';
import 'package:utmgo/features/bus_tracking/models/bus_location.dart';
import 'package:utmgo/features/bus_tracking/models/bus_route_point.dart';
import 'package:utmgo/features/bus_tracking/models/campus_bus.dart';
import 'package:utmgo/features/profile/models/app_user.dart';
import 'package:utmgo/models/user_role.dart';

void main() {
  group('Admin analytics routes and screens', () {
    test('registers system analytics route', () {
      final routes = AppRoutes.routes(isFirebaseReady: true);

      expect(routes.containsKey(AppRoutes.adminSystemAnalytics), isTrue);
      expect(AppRoutes.adminSystemAnalytics, '/admin/analytics');
    });

    testWidgets('admin dashboard opens system analytics route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
            AppRoutes.adminSystemAnalytics: (_) =>
                const Scaffold(body: Text('Analytics route opened')),
          },
          initialRoute: AppRoutes.adminDashboard,
        ),
      );

      await tester.tap(find.text('Analytics'));
      await tester.pumpAndSettle();

      expect(find.text('Analytics route opened'), findsOneWidget);
    });

    testWidgets('admin dashboard hides unused management cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
          },
          initialRoute: AppRoutes.adminDashboard,
        ),
      );

      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Facilities'), findsOneWidget);
      expect(find.text('Bus Routes'), findsOneWidget);
      expect(find.text('User management'), findsNothing);
      expect(find.text('Protected access'), findsNothing);
    });

    testWidgets('analytics screen renders loading state', (tester) async {
      final controller = StreamController<SystemAnalyticsSnapshot>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _analyticsApp(_FakeSystemAnalyticsService(controller.stream)),
      );

      expect(find.text('Loading analytics'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('analytics screen renders error state', (tester) async {
      await tester.pumpWidget(
        _analyticsApp(
          _FakeSystemAnalyticsService(
            Stream<SystemAnalyticsSnapshot>.error(Exception('denied')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Could not load analytics'), findsOneWidget);
      expect(find.textContaining('admin access'), findsOneWidget);
    });

    testWidgets('analytics screen renders empty state', (tester) async {
      await tester.pumpWidget(
        _analyticsApp(
          _FakeSystemAnalyticsService(Stream.value(_emptySnapshot())),
        ),
      );
      await tester.pump();

      expect(find.text('No analytics data yet'), findsOneWidget);
    });

    testWidgets('analytics screen renders populated metrics', (tester) async {
      await tester.pumpWidget(
        _analyticsApp(
          _FakeSystemAnalyticsService(Stream.value(_sampleSnapshot())),
        ),
      );
      await tester.pump();

      expect(find.text('Users'), findsOneWidget);
      expect(find.text('3 verified'), findsOneWidget);
      expect(find.text('Role Distribution'), findsOneWidget);
      expect(find.text('Attendance Status'), findsOneWidget);
      expect(find.text('Facilities and Bookings'), findsOneWidget);
      expect(find.text('Bus Operations'), findsOneWidget);
      expect(find.text('Live broadcasts'), findsOneWidget);
      expect(find.text('Stale broadcasts'), findsOneWidget);
    });
  });

  group('System analytics aggregation', () {
    test('counts users, attendance, bookings, facilities, and buses', () {
      final now = DateTime(2026, 5, 30, 12);
      final snapshot = _sampleSnapshot(now: now);

      expect(snapshot.totalUsers, 5);
      expect(snapshot.roleCount(UserRole.student), 1);
      expect(snapshot.roleCount(UserRole.lecturer), 1);
      expect(snapshot.roleCount(UserRole.driver), 1);
      expect(snapshot.roleCount(UserRole.staff), 1);
      expect(snapshot.roleCount(UserRole.admin), 1);
      expect(snapshot.verifiedUsers, 3);
      expect(snapshot.unverifiedUsers, 2);

      expect(snapshot.totalAttendanceSessions, 4);
      expect(snapshot.activeAttendanceSessions, 2);
      expect(snapshot.closedAttendanceSessions, 1);
      expect(snapshot.totalAttendanceRecords, 2);
      expect(snapshot.locationValidatedAttendanceRecords, 1);

      expect(snapshot.totalFacilities, 2);
      expect(snapshot.availableFacilities, 1);
      expect(snapshot.unavailableFacilities, 1);
      expect(snapshot.totalBookings, 3);
      expect(snapshot.pendingBookings, 1);
      expect(snapshot.approvedBookings, 1);
      expect(snapshot.cancelledBookings, 1);

      expect(snapshot.totalBusRoutes, 3);
      expect(snapshot.activeBusRoutes, 2);
      expect(snapshot.inactiveBusRoutes, 1);
      expect(snapshot.assignedBusRoutes, 2);
      expect(snapshot.unassignedBusRoutes, 1);
      expect(snapshot.liveBusBroadcasts, 1);
      expect(snapshot.staleBusBroadcasts, 1);
    });
  });
}

Widget _analyticsApp(SystemAnalyticsService service) {
  return MaterialApp(
    theme: AppTheme.light,
    home: SystemAnalyticsScreen(analyticsService: service),
  );
}

SystemAnalyticsSnapshot _sampleSnapshot({DateTime? now}) {
  final effectiveNow = now ?? DateTime(2026, 5, 30, 12);
  return buildSystemAnalyticsSnapshot(
    users: [
      _user('student-1', UserRole.student, verified: true),
      _user('lecturer-1', UserRole.lecturer),
      _user('driver-1', UserRole.driver, verified: true),
      _user('staff-1', UserRole.staff),
      _user('admin-1', UserRole.admin, verified: true),
    ],
    attendanceSessions: [
      _session(
        'session-1',
        status: 'active',
        expiryTime: null,
        now: effectiveNow,
      ),
      _session(
        'session-2',
        status: 'active',
        expiryTime: effectiveNow.add(const Duration(minutes: 5)),
        now: effectiveNow,
      ),
      _session(
        'session-3',
        status: 'active',
        expiryTime: effectiveNow.subtract(const Duration(minutes: 1)),
        now: effectiveNow,
      ),
      _session('session-4', status: 'closed', now: effectiveNow),
    ],
    attendanceRecords: [
      _record(
        'session-1_student-1',
        locationValidated: true,
        now: effectiveNow,
      ),
      _record(
        'session-2_student-1',
        locationValidated: false,
        now: effectiveNow,
      ),
    ],
    facilities: [
      _facility('facility-1', facilityStatusAvailable, effectiveNow),
      _facility('facility-2', facilityStatusUnavailable, effectiveNow),
    ],
    bookings: [
      _booking('booking-1', bookingStatusPending, effectiveNow),
      _booking('booking-2', bookingStatusApproved, effectiveNow),
      _booking('booking-3', bookingStatusCancelled, effectiveNow),
    ],
    buses: const [
      CampusBus(
        busId: 'bus-1',
        routeName: 'Green Line',
        driverIds: ['driver-1'],
        status: 'active',
        routePoints: [
          BusRoutePoint(latitude: 1.5583, longitude: 103.6371),
          BusRoutePoint(latitude: 1.5600, longitude: 103.6400),
        ],
      ),
      CampusBus(
        busId: 'bus-2',
        routeName: 'Blue Line',
        status: 'inactive',
        routePoints: [
          BusRoutePoint(latitude: 1.5583, longitude: 103.6371),
          BusRoutePoint(latitude: 1.5600, longitude: 103.6400),
        ],
      ),
      CampusBus(
        busId: 'bus-3',
        routeName: 'Gold Line',
        driverIds: ['driver-2', 'driver-3'],
        status: 'active',
        routePoints: [
          BusRoutePoint(latitude: 1.5583, longitude: 103.6371),
          BusRoutePoint(latitude: 1.5600, longitude: 103.6400),
        ],
      ),
    ],
    busLocations: [
      _busLocation(
        busId: 'bus-1',
        isBroadcasting: true,
        updatedAt: effectiveNow.subtract(const Duration(seconds: 20)),
      ),
      _busLocation(
        busId: 'bus-2',
        isBroadcasting: true,
        updatedAt: effectiveNow.subtract(const Duration(seconds: 31)),
      ),
      _busLocation(
        busId: 'bus-3',
        isBroadcasting: false,
        updatedAt: effectiveNow.subtract(const Duration(seconds: 5)),
      ),
    ],
    now: effectiveNow,
  );
}

SystemAnalyticsSnapshot _emptySnapshot() {
  return buildSystemAnalyticsSnapshot(
    users: const [],
    attendanceSessions: const [],
    attendanceRecords: const [],
    facilities: const [],
    bookings: const [],
    buses: const [],
    busLocations: const [],
    now: DateTime(2026, 5, 30, 12),
  );
}

AppUser _user(String uid, UserRole role, {bool verified = false}) {
  return AppUser(
    uid: uid,
    name: uid,
    email: '$uid@example.com',
    role: role,
    emailVerified: verified,
  );
}

AttendanceSession _session(
  String sessionId, {
  required String status,
  DateTime? expiryTime,
  required DateTime now,
}) {
  return AttendanceSession(
    sessionId: sessionId,
    lecturerId: 'lecturer-1',
    courseCode: 'SECJ1013',
    requiresLocation: false,
    latitude: null,
    longitude: null,
    geofenceRadius: null,
    qrCodeValue: 'qr-$sessionId',
    startTime: now.subtract(const Duration(minutes: 10)),
    expiryTime: expiryTime,
    status: status,
    createdAt: now.subtract(const Duration(minutes: 10)),
  );
}

AttendanceRecord _record(
  String recordId, {
  required bool locationValidated,
  required DateTime now,
}) {
  return AttendanceRecord(
    recordId: recordId,
    sessionId: recordId.split('_').first,
    courseCode: 'SECJ1013',
    studentId: 'student-1',
    studentName: 'Student One',
    studentEmail: 'student-1@example.com',
    scannedAt: now,
    locationValidated: locationValidated,
    latitude: locationValidated ? 1.5583 : null,
    longitude: locationValidated ? 103.6371 : null,
    distanceMeters: locationValidated ? 12 : null,
    status: 'present',
    remarks: '',
  );
}

Facility _facility(String id, String status, DateTime now) {
  return Facility(
    facilityId: id,
    name: id,
    type: 'Room',
    location: 'Campus',
    capacity: 20,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

FacilityBooking _booking(String id, String status, DateTime now) {
  return FacilityBooking(
    bookingId: id,
    slotOccurrenceId: 'slot-$id',
    facilityId: 'facility-1',
    templateId: 'template-1',
    facilityName: 'Seminar Room',
    studentId: 'student-1',
    studentName: 'Student One',
    studentEmail: 'student-1@example.com',
    requestedDate: DateTime(now.year, now.month, now.day),
    startTime: now,
    endTime: now.add(const Duration(hours: 1)),
    status: status,
    reviewedBy: status == bookingStatusPending ? null : 'staff-1',
    reviewedAt: status == bookingStatusPending ? null : now,
    createdAt: now,
    updatedAt: now,
  );
}

BusLocation _busLocation({
  required String busId,
  required bool isBroadcasting,
  required DateTime updatedAt,
}) {
  return BusLocation(
    busId: busId,
    driverId: 'driver-1',
    latitude: 1.5583,
    longitude: 103.6371,
    speed: 10,
    heading: 90,
    isBroadcasting: isBroadcasting,
    updatedAt: updatedAt,
  );
}

class _FakeSystemAnalyticsService implements SystemAnalyticsService {
  const _FakeSystemAnalyticsService(this.stream);

  final Stream<SystemAnalyticsSnapshot> stream;

  @override
  Stream<SystemAnalyticsSnapshot> watchSystemAnalytics() {
    return stream;
  }
}
