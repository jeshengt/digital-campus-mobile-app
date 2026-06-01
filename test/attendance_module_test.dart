import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/routes/app_routes.dart';
import 'package:utmgo/app/theme/app_theme.dart';
import 'package:utmgo/core/errors/app_exception.dart';
import 'package:utmgo/features/attendance/models/attendance_record.dart';
import 'package:utmgo/features/attendance/models/attendance_session.dart';
import 'package:utmgo/features/attendance/screens/lecturer_attendance_list_screen.dart';
import 'package:utmgo/features/attendance/screens/lecturer_create_session_screen.dart';
import 'package:utmgo/features/attendance/screens/lecturer_session_qr_screen.dart';
import 'package:utmgo/features/attendance/screens/student_attendance_history_screen.dart';
import 'package:utmgo/features/attendance/screens/student_scan_attendance_screen.dart';
import 'package:utmgo/features/attendance/services/attendance_pdf_export_service.dart';
import 'package:utmgo/features/attendance/services/attendance_qr_export_service.dart';
import 'package:utmgo/features/attendance/services/attendance_service.dart';
import 'package:utmgo/features/attendance/utils/attendance_helpers.dart';
import 'package:utmgo/features/lecturer/screens/lecturer_dashboard_screen.dart';
import 'package:utmgo/features/student/screens/student_dashboard_screen.dart';
import 'package:utmgo/services/location/attendance_location_provider.dart';

void main() {
  group('Attendance models', () {
    test('maps attendance session data', () {
      final now = DateTime(2026, 5, 15, 9);
      final session = AttendanceSession(
        sessionId: 'session-1',
        lecturerId: 'lecturer-1',
        courseCode: 'SECJ1013',
        requiresLocation: true,
        latitude: 1.5583,
        longitude: 103.6371,
        geofenceRadius: 100,
        qrCodeValue: 'opaque-token',
        startTime: now,
        expiryTime: now.add(const Duration(minutes: 15)),
        status: attendanceStatusActive,
        createdAt: now,
      );

      final map = session.toMap();
      final parsed = AttendanceSession.fromMap(map);

      expect(map['qrCodeValue'], 'opaque-token');
      expect(parsed.courseCode, 'SECJ1013');
      expect(parsed.requiresLocation, isTrue);
      expect(parsed.geofenceRadius, 100);
      expect(parsed.status, attendanceStatusActive);
    });

    test('maps QR-only no-expiry attendance session data', () {
      final now = DateTime(2026, 5, 15, 9);
      final session = AttendanceSession(
        sessionId: 'session-1',
        lecturerId: 'lecturer-1',
        courseCode: 'SECJ1013',
        requiresLocation: false,
        latitude: null,
        longitude: null,
        geofenceRadius: null,
        qrCodeValue: 'opaque-token',
        startTime: now,
        expiryTime: null,
        status: attendanceStatusActive,
        createdAt: now,
      );

      final parsed = AttendanceSession.fromMap(session.toMap());

      expect(parsed.requiresLocation, isFalse);
      expect(parsed.latitude, isNull);
      expect(parsed.geofenceRadius, isNull);
      expect(parsed.expiryTime, isNull);
      expect(parsed.isActive, isTrue);
    });

    test('maps attendance record data', () {
      final now = DateTime(2026, 5, 15, 9, 5);
      final record = AttendanceRecord(
        recordId: 'session-1_student-1',
        sessionId: 'session-1',
        courseCode: 'SECJ1013',
        studentId: 'student-1',
        studentName: 'Aina Rahman',
        studentEmail: 'aina@example.com',
        scannedAt: now,
        locationValidated: true,
        latitude: 1.5583,
        longitude: 103.6371,
        distanceMeters: 12.5,
        status: attendanceRecordStatusPresent,
        remarks: 'Validated by QR and location',
      );

      final parsed = AttendanceRecord.fromMap(record.toMap());

      expect(parsed.recordId, 'session-1_student-1');
      expect(parsed.courseCode, 'SECJ1013');
      expect(parsed.studentName, 'Aina Rahman');
      expect(parsed.studentEmail, 'aina@example.com');
      expect(parsed.locationValidated, isTrue);
      expect(parsed.distanceMeters, 12.5);
      expect(parsed.status, attendanceRecordStatusPresent);
    });

    test('maps QR-only attendance record data', () {
      final now = DateTime(2026, 5, 15, 9, 5);
      final record = AttendanceRecord(
        recordId: 'session-1_student-1',
        sessionId: 'session-1',
        courseCode: 'SECJ1013',
        studentId: 'student-1',
        studentName: 'Aina Rahman',
        studentEmail: 'aina@example.com',
        scannedAt: now,
        locationValidated: false,
        latitude: null,
        longitude: null,
        distanceMeters: null,
        status: attendanceRecordStatusPresent,
        remarks: 'Validated by QR',
      );

      final parsed = AttendanceRecord.fromMap(record.toMap());

      expect(parsed.locationValidated, isFalse);
      expect(parsed.latitude, isNull);
      expect(parsed.distanceMeters, isNull);
      expect(parsed.remarks, 'Validated by QR');
    });
  });

  group('Attendance helpers', () {
    test('normalizes QR values and creates deterministic record IDs', () {
      expect(normalizeQrCodeValue('  abc  '), 'abc');
      expect(
        sessionIdFromAttendanceQr('utmgo-att:session-1:1:abcd'),
        'session-1',
      );
      expect(sessionIdFromAttendanceQr('old-token'), isNull);
      expect(sessionIdFromAttendanceQr('utmgo-att:bad/id:1:abcd'), isNull);
      expect(
        attendanceRecordId(sessionId: 'session-1', studentId: 'student-1'),
        'session-1_student-1',
      );
    });

    test('checks session active state', () {
      final now = DateTime(2026, 5, 15, 9);

      expect(
        isSessionActive(
          status: attendanceStatusActive,
          expiryTime: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isTrue,
      );
      expect(
        isSessionActive(
          status: attendanceStatusClosed,
          expiryTime: now.add(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
      expect(
        isSessionActive(
          status: attendanceStatusActive,
          expiryTime: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        isSessionActive(
          status: attendanceStatusClosed,
          expiryTime: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        isSessionActive(
          status: attendanceStatusActive,
          expiryTime: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('validates geofence boundary values', () {
      expect(isInsideGeofence(distanceMeters: 99.9, radiusMeters: 100), isTrue);
      expect(isInsideGeofence(distanceMeters: 100, radiusMeters: 100), isTrue);
      expect(
        isInsideGeofence(distanceMeters: 100.1, radiusMeters: 100),
        isFalse,
      );
    });

    test('calculates approximate distance between campus coordinates', () {
      final distance = distanceBetweenMeters(
        startLatitude: 1.5583,
        startLongitude: 103.6371,
        endLatitude: 1.5584,
        endLongitude: 103.6371,
      );

      expect(distance, greaterThan(10));
      expect(distance, lessThan(12));
    });
  });

  group('Attendance QR export', () {
    test('formats QR poster metadata', () {
      final session = _sampleSession(expiryTime: DateTime(2026, 5, 20, 14, 5));

      expect(
        AttendanceQrPosterGenerator.fileNameFor(session),
        'utmgo_secj1013_attendance_qr.png',
      );
      expect(
        AttendanceQrPosterGenerator.expiryLabelFor(session),
        '20/05/2026 14:05',
      );
      expect(
        AttendanceQrPosterGenerator.locationLabelFor(session),
        'Location required (100m)',
      );
      expect(
        AttendanceQrPosterGenerator.expiryLabelFor(
          _sampleSession(requiresLocation: false, noExpiry: true),
        ),
        'No expiry',
      );
    });

    testWidgets('generates QR poster PNG bytes', (tester) async {
      final bytes = await tester.runAsync(
        () => const AttendanceQrPosterGenerator().generatePng(
          session: _sampleSession(requiresLocation: false, noExpiry: true),
          lecturerName: 'Dr Amina Rahman',
        ),
      );

      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(1000));
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    });
  });

  group('Attendance PDF export', () {
    test('formats PDF export metadata', () {
      final session = _sampleSession(expiryTime: DateTime(2026, 5, 20, 14, 5));

      expect(
        AttendancePdfReportGenerator.fileNameFor(session),
        'utmgo_secj1013_attendance_list.pdf',
      );
      expect(
        AttendancePdfReportGenerator.expiryLabelFor(session),
        '20/05/2026 14:05',
      );
      expect(
        AttendancePdfReportGenerator.locationLabelFor(session),
        'Location required (100m)',
      );
    });

    test('generates attendance list PDF bytes', () async {
      final session = _sampleSession();
      final bytes = await const AttendancePdfReportGenerator().generatePdf(
        session: session,
        records: [_sampleRecord(session)],
        lecturerName: 'Dr Amina Rahman',
        generatedAt: DateTime(2026, 5, 20, 14, 5),
      );

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });

  group('Attendance routes and screens', () {
    test('registers attendance routes', () {
      final routes = AppRoutes.routes(isFirebaseReady: true);

      expect(routes.containsKey(AppRoutes.lecturerCreateAttendance), isTrue);
      expect(routes.containsKey(AppRoutes.lecturerAttendanceQr), isTrue);
      expect(routes.containsKey(AppRoutes.lecturerAttendanceList), isTrue);
      expect(routes.containsKey(AppRoutes.studentScanAttendance), isTrue);
      expect(routes.containsKey(AppRoutes.studentAttendanceHistory), isTrue);
    });

    testWidgets('lecturer dashboard opens create attendance route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.lecturerDashboard: (_) => const LecturerDashboardScreen(),
            AppRoutes.lecturerCreateAttendance: (_) =>
                const Scaffold(body: Text('Create route opened')),
          },
          initialRoute: AppRoutes.lecturerDashboard,
        ),
      );

      await tester.tap(find.text('Generate Attendance QR'));
      await tester.pumpAndSettle();

      expect(find.text('Create route opened'), findsOneWidget);
    });

    testWidgets('lecturer dashboard hides unused local PDF export card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.lecturerDashboard: (_) => const LecturerDashboardScreen(),
          },
          initialRoute: AppRoutes.lecturerDashboard,
        ),
      );

      expect(find.text('Generate Attendance QR'), findsOneWidget);
      expect(find.text('Attendance Lists'), findsOneWidget);
      expect(find.text('Track Buses'), findsOneWidget);
      expect(find.text('Local PDF export'), findsNothing);
    });

    testWidgets('student dashboard opens attendance history route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.studentDashboard: (_) => const StudentDashboardScreen(),
            AppRoutes.studentAttendanceHistory: (_) =>
                const Scaffold(body: Text('History route opened')),
          },
          initialRoute: AppRoutes.studentDashboard,
        ),
      );

      await tester.tap(find.text('Attendance History'));
      await tester.pumpAndSettle();

      expect(find.text('History route opened'), findsOneWidget);
    });

    testWidgets('create session form validates required fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LecturerCreateSessionScreen(
            attendanceService: _FakeAttendanceService(),
            locationProvider: const _FakeLocationProvider(),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('createAttendanceSubmitButton')));
      await tester.pump();

      expect(find.text('Course code is required'), findsOneWidget);
      expect(find.text('Latitude is required'), findsNothing);
      expect(find.text('Longitude is required'), findsNothing);
    });

    testWidgets('create session form allows course-only QR session', (
      tester,
    ) async {
      final service = _FakeAttendanceService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.lecturerAttendanceQr: (_) =>
                const Scaffold(body: Text('QR route opened')),
          },
          home: LecturerCreateSessionScreen(
            attendanceService: service,
            locationProvider: const _FakeLocationProvider(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'secj1013');
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('createAttendanceSubmitButton')));
      await tester.pumpAndSettle();

      expect(service.createdRequiresLocation, isFalse);
      expect(service.createdDurationMinutes, isNull);
      expect(find.text('QR route opened'), findsOneWidget);
    });

    testWidgets('student scan shows invalid QR state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentScanAttendanceScreen(
            attendanceService: _FakeAttendanceService(),
            locationProvider: const _FakeLocationProvider(),
            initialQrCode: 'missing',
            enableCamera: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Invalid or expired attendance QR.'), findsOneWidget);
    });

    testWidgets('student scan shows outside geofence state', (tester) async {
      final service = _FakeAttendanceService(
        session: _sampleSession(radius: 100),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentScanAttendanceScreen(
            attendanceService: service,
            locationProvider: const _FakeLocationProvider(distanceMeters: 150),
            initialQrCode: 'utmgo-att:session-1:1:abcd',
            enableCamera: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('You are 150m away from the session location.'),
        findsOneWidget,
      );
    });

    testWidgets('student scan records QR-only session without location', (
      tester,
    ) async {
      final service = _FakeAttendanceService(
        session: _sampleSession(requiresLocation: false, noExpiry: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentScanAttendanceScreen(
            attendanceService: service,
            locationProvider: const _FakeLocationProvider(throwOnUse: true),
            initialQrCode: 'utmgo-att:session-1:1:abcd',
            enableCamera: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Attendance recorded'), findsOneWidget);
      expect(find.text('QR verified'), findsOneWidget);
    });

    testWidgets('student scan shows success state', (tester) async {
      final service = _FakeAttendanceService(session: _sampleSession());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentScanAttendanceScreen(
            attendanceService: service,
            locationProvider: const _FakeLocationProvider(distanceMeters: 12),
            initialQrCode: 'utmgo-att:session-1:1:abcd',
            enableCamera: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Attendance recorded'), findsOneWidget);
      expect(find.text('SECJ1013'), findsOneWidget);
    });

    testWidgets('lecturer attendance list shows empty sessions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LecturerAttendanceListScreen(
            attendanceService: _FakeAttendanceService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No sessions yet'), findsOneWidget);
    });

    testWidgets('lecturer attendance list opens QR for active sessions', (
      tester,
    ) async {
      final session = _sampleSession(requiresLocation: false, noExpiry: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.lecturerAttendanceQr: (_) =>
                const Scaffold(body: Text('QR route opened')),
          },
          home: LecturerAttendanceListScreen(
            attendanceService: _FakeAttendanceService(session: session),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('View QR'), findsOneWidget);
      expect(find.text('QR only - No expiry'), findsOneWidget);

      await tester.tap(find.byTooltip('View QR'));
      await tester.pumpAndSettle();

      expect(find.text('QR route opened'), findsOneWidget);
    });

    testWidgets('lecturer can end an active attendance session', (
      tester,
    ) async {
      final session = _sampleSession(requiresLocation: false, noExpiry: true);
      final service = _FakeAttendanceService(session: session);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LecturerAttendanceListScreen(attendanceService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('End session'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End session').last);
      await tester.pumpAndSettle();

      expect(service.closedSessionId, session.sessionId);
      expect(find.text('Attendance session ended.'), findsOneWidget);
    });

    testWidgets('lecturer attendance list hides QR for expired sessions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LecturerAttendanceListScreen(
            attendanceService: _FakeAttendanceService(
              session: _sampleSession(isExpired: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('View QR'), findsNothing);
    });

    testWidgets('lecturer attendance list shows records for a session', (
      tester,
    ) async {
      final session = _sampleSession();
      final service = _FakeAttendanceService(
        session: session,
        records: [_sampleRecord(session)],
      );
      final pdfExportService = _FakePdfExportService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: session),
            builder: (_) => LecturerAttendanceListScreen(
              attendanceService: service,
              pdfExportService: pdfExportService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 present'), findsOneWidget);
      expect(find.text('Aina Rahman'), findsOneWidget);
      expect(find.text('Save as PDF'), findsOneWidget);
      expect(find.text('Share as PDF'), findsOneWidget);
    });

    testWidgets('lecturer attendance list shares records as PDF', (
      tester,
    ) async {
      final session = _sampleSession();
      final record = _sampleRecord(session);
      final pdfExportService = _FakePdfExportService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: session),
            builder: (_) => LecturerAttendanceListScreen(
              attendanceService: _FakeAttendanceService(
                session: session,
                records: [record],
              ),
              pdfExportService: pdfExportService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Share as PDF'));
      await tester.pumpAndSettle();

      expect(pdfExportService.sharedSessionId, session.sessionId);
      expect(pdfExportService.sharedRecordCount, 1);
      expect(find.text('Attendance PDF ready to share.'), findsOneWidget);
    });

    testWidgets('lecturer attendance list saves records as PDF', (
      tester,
    ) async {
      final session = _sampleSession();
      final record = _sampleRecord(session);
      final pdfExportService = _FakePdfExportService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: session),
            builder: (_) => LecturerAttendanceListScreen(
              attendanceService: _FakeAttendanceService(
                session: session,
                records: [record],
              ),
              pdfExportService: pdfExportService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Save as PDF'));
      await tester.pumpAndSettle();

      expect(pdfExportService.savedSessionId, session.sessionId);
      expect(pdfExportService.savedRecordCount, 1);
      expect(find.text('Attendance PDF saved.'), findsOneWidget);
    });

    testWidgets('selected active attendance list opens QR from app bar', (
      tester,
    ) async {
      final session = _sampleSession();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.lecturerAttendanceQr: (_) =>
                const Scaffold(body: Text('QR route opened')),
          },
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: session),
            builder: (_) => LecturerAttendanceListScreen(
              attendanceService: _FakeAttendanceService(session: session),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('View QR'), findsOneWidget);

      await tester.tap(find.byTooltip('View QR'));
      await tester.pumpAndSettle();

      expect(find.text('QR route opened'), findsOneWidget);
    });

    testWidgets('active lecturer QR screen shows share and save actions', (
      tester,
    ) async {
      final session = _sampleSession(requiresLocation: false, noExpiry: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: session),
            builder: (_) => LecturerSessionQrScreen(
              attendanceService: _FakeAttendanceService(session: session),
              qrExportService: _FakeQrExportService(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(find.text('Share QR'), findsOneWidget);
      expect(find.text('Save QR'), findsOneWidget);
    });

    testWidgets('expired lecturer QR screen hides share and save actions', (
      tester,
    ) async {
      final session = _sampleSession(isExpired: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: session),
            builder: (_) => LecturerSessionQrScreen(
              attendanceService: _FakeAttendanceService(session: session),
              qrExportService: _FakeQrExportService(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Share QR'), findsNothing);
      expect(find.text('Save QR'), findsNothing);
    });

    testWidgets('lecturer QR screen shares and saves QR poster', (
      tester,
    ) async {
      final session = _sampleSession(requiresLocation: false, noExpiry: true);
      final exportService = _FakeQrExportService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: session),
            builder: (_) => LecturerSessionQrScreen(
              attendanceService: _FakeAttendanceService(session: session),
              qrExportService: exportService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share QR'));
      await tester.pumpAndSettle();

      expect(exportService.sharedSessionId, session.sessionId);
      expect(find.text('QR ready to share.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save QR'));
      await tester.pumpAndSettle();

      expect(exportService.savedSessionId, session.sessionId);
      expect(find.text('Attendance QR saved to gallery.'), findsOneWidget);
    });

    testWidgets('student attendance history shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentAttendanceHistoryScreen(
            attendanceService: _FakeAttendanceService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No attendance yet'), findsOneWidget);
    });

    testWidgets('student attendance history shows own records', (tester) async {
      final session = _sampleSession();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentAttendanceHistoryScreen(
            attendanceService: _FakeAttendanceService(
              records: [_sampleRecord(session)],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My attendance'), findsOneWidget);
      expect(find.text('1 verified record'), findsOneWidget);
      expect(find.text('SECJ1013'), findsOneWidget);
    });
  });
}

AttendanceSession _sampleSession({
  double radius = 100,
  bool isExpired = false,
  bool requiresLocation = true,
  DateTime? expiryTime,
  bool noExpiry = false,
}) {
  final now = DateTime.now();
  return AttendanceSession(
    sessionId: 'session-1',
    lecturerId: 'lecturer-1',
    courseCode: 'SECJ1013',
    requiresLocation: requiresLocation,
    latitude: requiresLocation ? 1.5583 : null,
    longitude: requiresLocation ? 103.6371 : null,
    geofenceRadius: requiresLocation ? radius : null,
    qrCodeValue: 'utmgo-att:session-1:1:abcd',
    startTime: now,
    expiryTime: noExpiry
        ? null
        : expiryTime ??
              (isExpired
                  ? now.subtract(const Duration(minutes: 1))
                  : now.add(const Duration(minutes: 15))),
    status: attendanceStatusActive,
    createdAt: now,
  );
}

AttendanceRecord _sampleRecord(AttendanceSession session) {
  return AttendanceRecord(
    recordId: attendanceRecordId(
      sessionId: session.sessionId,
      studentId: 'student-1',
    ),
    sessionId: session.sessionId,
    courseCode: session.courseCode,
    studentId: 'student-1',
    studentName: 'Aina Rahman',
    studentEmail: 'aina@example.com',
    scannedAt: DateTime.now(),
    locationValidated: session.requiresLocation,
    latitude: session.requiresLocation ? 1.5583 : null,
    longitude: session.requiresLocation ? 103.6371 : null,
    distanceMeters: session.requiresLocation ? 12 : null,
    status: attendanceRecordStatusPresent,
    remarks: session.requiresLocation
        ? 'Validated by QR and location'
        : 'Validated by QR',
  );
}

class _FakeAttendanceService implements AttendanceService {
  _FakeAttendanceService({
    this.session,
    this.records = const <AttendanceRecord>[],
  });

  final AttendanceSession? session;
  final List<AttendanceRecord> records;
  bool? createdRequiresLocation;
  int? createdDurationMinutes;
  String? closedSessionId;

  @override
  Future<AttendanceSession> createSession({
    required String courseCode,
    required bool requiresLocation,
    double? latitude,
    double? longitude,
    double? geofenceRadius,
    int? durationMinutes,
  }) async {
    createdRequiresLocation = requiresLocation;
    createdDurationMinutes = durationMinutes;
    return _sampleSession(
      radius: geofenceRadius ?? 100,
      requiresLocation: requiresLocation,
      noExpiry: durationMinutes == null,
      expiryTime: durationMinutes == null
          ? null
          : DateTime.now().add(Duration(minutes: durationMinutes)),
    );
  }

  @override
  Future<void> closeSession(String sessionId) async {
    closedSessionId = sessionId;
  }

  @override
  Future<AttendanceSession?> findActiveSessionByQrCode(
    String qrCodeValue,
  ) async {
    if (qrCodeValue == session?.qrCodeValue) {
      return session;
    }

    return null;
  }

  @override
  Future<AttendanceRecord> submitAttendance({
    required AttendanceSession session,
    double? latitude,
    double? longitude,
    double? distanceMeters,
  }) async {
    if (session.requiresLocation && distanceMeters == null) {
      throw const AppException('Location validation is required.');
    }

    if (session.requiresLocation &&
        distanceMeters != null &&
        session.geofenceRadius != null &&
        distanceMeters > session.geofenceRadius!) {
      throw AppException(
        'You are ${distanceMeters.toStringAsFixed(0)}m away from the session location.',
      );
    }

    return _sampleRecord(session);
  }

  @override
  Stream<List<AttendanceRecord>> watchRecordsForSession(String sessionId) {
    return Stream.value(records);
  }

  @override
  Stream<List<AttendanceRecord>> watchCurrentStudentRecords() {
    return Stream.value(records);
  }

  @override
  Stream<List<AttendanceSession>> watchLecturerSessions() {
    return Stream.value(session == null ? [] : [session!]);
  }
}

class _FakeQrExportService implements AttendanceQrExportService {
  String? sharedSessionId;
  String? savedSessionId;

  @override
  Future<AttendanceQrExportResult> shareQr({
    required AttendanceSession session,
    Rect? sharePositionOrigin,
  }) async {
    sharedSessionId = session.sessionId;
    return const AttendanceQrExportResult(message: 'QR ready to share.');
  }

  @override
  Future<AttendanceQrExportResult> saveQrToGallery({
    required AttendanceSession session,
  }) async {
    savedSessionId = session.sessionId;
    return const AttendanceQrExportResult(
      message: 'Attendance QR saved to gallery.',
    );
  }
}

class _FakePdfExportService implements AttendancePdfExportService {
  String? savedSessionId;
  int? savedRecordCount;
  String? sharedSessionId;
  int? sharedRecordCount;

  @override
  Future<AttendancePdfExportResult> saveAttendanceList({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
  }) async {
    savedSessionId = session.sessionId;
    savedRecordCount = records.length;
    return const AttendancePdfExportResult(message: 'Attendance PDF saved.');
  }

  @override
  Future<AttendancePdfExportResult> shareAttendanceList({
    required AttendanceSession session,
    required List<AttendanceRecord> records,
    Rect? sharePositionOrigin,
  }) async {
    sharedSessionId = session.sessionId;
    sharedRecordCount = records.length;
    return const AttendancePdfExportResult(
      message: 'Attendance PDF ready to share.',
    );
  }
}

class _FakeLocationProvider implements AttendanceLocationProvider {
  const _FakeLocationProvider({
    this.distanceMeters = 0,
    this.throwOnUse = false,
  });

  final double distanceMeters;
  final bool throwOnUse;

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    if (throwOnUse) {
      throw StateError('Location provider should not be used.');
    }

    return distanceMeters;
  }

  @override
  Future<CampusPosition> getCurrentPosition() async {
    if (throwOnUse) {
      throw StateError('Location provider should not be used.');
    }

    return const CampusPosition(latitude: 1.5583, longitude: 103.6371);
  }
}
