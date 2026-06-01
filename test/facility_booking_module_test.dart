import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/routes/app_routes.dart';
import 'package:utmgo/app/theme/app_theme.dart';
import 'package:utmgo/core/errors/app_exception.dart';
import 'package:utmgo/features/admin/screens/admin_dashboard_screen.dart';
import 'package:utmgo/features/booking/models/facility.dart';
import 'package:utmgo/features/booking/models/facility_booking.dart';
import 'package:utmgo/features/booking/models/facility_slot_capacity.dart';
import 'package:utmgo/features/booking/models/facility_slot_occurrence.dart';
import 'package:utmgo/features/booking/models/facility_slot_reservation.dart';
import 'package:utmgo/features/booking/models/facility_slot_template.dart';
import 'package:utmgo/features/booking/screens/admin_facility_management_screen.dart';
import 'package:utmgo/features/booking/screens/staff_booking_review_screen.dart';
import 'package:utmgo/features/booking/screens/staff_slot_management_screen.dart';
import 'package:utmgo/features/booking/screens/student_facility_booking_screen.dart';
import 'package:utmgo/features/booking/services/facility_booking_service.dart';
import 'package:utmgo/features/booking/utils/booking_validation.dart';
import 'package:utmgo/features/staff/screens/staff_dashboard_screen.dart';
import 'package:utmgo/features/student/screens/student_dashboard_screen.dart';

void main() {
  group('Facility booking models', () {
    test('maps facility data', () {
      final now = DateTime(2026, 5, 25, 9);
      final facility = Facility(
        facilityId: 'facility-1',
        name: 'Seminar Room A',
        type: 'Room',
        location: 'Library Level 2',
        capacity: 40,
        status: facilityStatusAvailable,
        createdAt: now,
        updatedAt: now,
      );

      final parsed = Facility.fromMap(facility.toMap());

      expect(parsed.facilityId, 'facility-1');
      expect(parsed.name, 'Seminar Room A');
      expect(parsed.capacity, 40);
      expect(parsed.status, facilityStatusAvailable);
    });

    test('maps booking data', () {
      final booking = _sampleBooking();

      final parsed = FacilityBooking.fromMap(booking.toMap());

      expect(parsed.bookingId, booking.bookingId);
      expect(parsed.slotOccurrenceId, booking.slotOccurrenceId);
      expect(parsed.templateId, 'template-1');
      expect(parsed.facilityName, 'Seminar Room A');
      expect(parsed.studentEmail, 'aina@example.com');
      expect(parsed.status, bookingStatusPending);
      expect(parsed.startTime.hour, 9);
    });

    test('maps slot capacity data', () {
      final capacity = _sampleSlotCapacity(
        pendingCount: 2,
        approvedCount: 3,
        activeCount: 5,
      );

      final parsed = FacilitySlotCapacity.fromMap(capacity.toMap());

      expect(parsed.slotOccurrenceId, capacity.slotOccurrenceId);
      expect(parsed.facilityId, 'facility-1');
      expect(parsed.pendingCount, 2);
      expect(parsed.approvedCount, 3);
      expect(parsed.activeCount, 5);
    });

    test(
      'maps slot template data for date, daily, weekdays, and weekly modes',
      () {
        final dateTemplate = _sampleSlotTemplate(
          slotMode: slotModeDate,
          slotDate: DateTime(2026, 5, 26),
          weekday: null,
        );
        final dailyTemplate = _sampleSlotTemplate(
          templateId: 'template-2',
          slotMode: slotModeDaily,
          weekday: null,
        );
        final weekdaysTemplate = _sampleSlotTemplate(
          templateId: 'template-3',
          slotMode: slotModeWeekdays,
          weekday: null,
        );
        final weeklyTemplate = _sampleSlotTemplate(
          templateId: 'template-4',
          slotMode: slotModeWeekly,
        );

        final parsedDate = FacilitySlotTemplate.fromMap(dateTemplate.toMap());
        final parsedDaily = FacilitySlotTemplate.fromMap(dailyTemplate.toMap());
        final parsedWeekdays = FacilitySlotTemplate.fromMap(
          weekdaysTemplate.toMap(),
        );
        final parsedWeekly = FacilitySlotTemplate.fromMap(
          weeklyTemplate.toMap(),
        );

        expect(parsedDate.slotMode, slotModeDate);
        expect(parsedDate.slotDate, DateTime(2026, 5, 26));
        expect(parsedDate.weekday, isNull);
        expect(parsedDaily.slotMode, slotModeDaily);
        expect(parsedDaily.weekday, isNull);
        expect(parsedWeekdays.slotMode, slotModeWeekdays);
        expect(parsedWeekdays.weekday, isNull);
        expect(parsedWeekly.slotMode, slotModeWeekly);
        expect(parsedWeekly.weekday, DateTime.monday);
      },
    );

    test('parses legacy weekly slot templates without slot mode', () {
      final parsed = FacilitySlotTemplate.fromMap({
        'templateId': 'template-1',
        'facilityId': 'facility-1',
        'weekday': DateTime.monday,
        'startMinutes': 540,
        'endMinutes': 600,
        'status': slotTemplateStatusActive,
        'createdBy': 'staff-1',
        'createdAt': DateTime(2026, 5, 25, 8),
        'updatedAt': DateTime(2026, 5, 25, 8),
      });

      expect(parsed.templateId, 'template-1');
      expect(parsed.facilityId, 'facility-1');
      expect(parsed.slotMode, slotModeWeekly);
      expect(parsed.weekday, DateTime.monday);
      expect(parsed.status, slotTemplateStatusActive);
    });
  });

  group('Facility booking helpers', () {
    test('creates deterministic slot and student booking IDs', () {
      final date = DateTime(2026, 5, 25);
      final start = DateTime(2026, 5, 25, 9);
      final end = DateTime(2026, 5, 25, 10);

      final slotOccurrenceId = slotOccurrenceIdFor(
        facilityId: 'facility-1',
        templateId: 'template-1',
        requestedDate: date,
        startTime: start,
        endTime: end,
      );
      final normalizedSlotId = bookingDocumentId(
        slotOccurrenceId: slotOccurrenceId,
      );
      final bookingId = bookingIdForStudentSlot(
        studentId: 'student-1',
        slotOccurrenceId: normalizedSlotId,
      );

      expect(normalizedSlotId, slotOccurrenceId);
      expect(slotOccurrenceId, 'facility-1_template-1_20260525_0900_1000');
      expect(bookingId, 'student-1_facility-1_template-1_20260525_0900_1000');
    });

    test('generates available weekly slot occurrences', () {
      final from = DateTime(2026, 5, 25, 8);
      final template = _sampleSlotTemplate();
      final reserved = FacilitySlotReservation(
        slotOccurrenceId: slotOccurrenceIdFor(
          facilityId: 'facility-1',
          templateId: 'template-1',
          requestedDate: DateTime(2026, 5, 25),
          startTime: DateTime(2026, 5, 25, 9),
          endTime: DateTime(2026, 5, 25, 10),
        ),
        facilityId: 'facility-1',
        templateId: 'template-1',
        bookingId: 'facility-1_template-1_20260525_0900_1000',
        studentId: 'student-1',
        requestedDate: DateTime(2026, 5, 25),
        startTime: DateTime(2026, 5, 25, 9),
        endTime: DateTime(2026, 5, 25, 10),
        status: bookingStatusPending,
        createdAt: from,
        updatedAt: from,
      );

      final occurrences = generateAvailableSlotOccurrences(
        templates: [template],
        reservations: [reserved],
        from: from,
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.single.requestedDate, DateTime(2026, 6, 1));
      expect(occurrences.single.startTime.hour, 9);
    });

    test('keeps slots available until active holds reach capacity', () {
      final from = DateTime(2026, 5, 25, 8);
      final template = _sampleSlotTemplate();
      final occurrence = FacilitySlotOccurrence.fromTemplate(
        template: template,
        date: DateTime(2026, 5, 25),
      );

      final belowCapacity = generateAvailableSlotOccurrences(
        templates: [template],
        reservations: [
          _sampleReservation(
            slotOccurrenceId: occurrence.slotOccurrenceId,
            requestedDate: occurrence.requestedDate,
            startTime: occurrence.startTime,
            endTime: occurrence.endTime,
          ),
        ],
        capacities: [
          _sampleSlotCapacity(
            slotOccurrenceId: occurrence.slotOccurrenceId,
            pendingCount: 1,
            activeCount: 1,
          ),
        ],
        facilityCapacity: 2,
        from: from,
        days: 1,
      );
      final atCapacity = generateAvailableSlotOccurrences(
        templates: [template],
        reservations: const <FacilitySlotReservation>[],
        capacities: [
          _sampleSlotCapacity(
            slotOccurrenceId: occurrence.slotOccurrenceId,
            pendingCount: 2,
            activeCount: 2,
          ),
        ],
        facilityCapacity: 2,
        from: from,
        days: 1,
      );

      expect(belowCapacity, hasLength(1));
      expect(atCapacity, isEmpty);
    });

    test('calculates capacity counter transitions', () {
      final now = DateTime(2026, 5, 25, 8);
      final occurrence = _sampleOccurrence();
      final submitted = nextCapacityForSubmit(
        current: null,
        slot: occurrence,
        facilityCapacity: 2,
        now: now,
      );
      final approved = nextCapacityForApproval(
        current: submitted,
        facilityCapacity: 2,
        now: now.add(const Duration(minutes: 1)),
      );
      final cancelled = nextCapacityForCancellation(
        current: approved,
        previousStatus: bookingStatusApproved,
        now: now.add(const Duration(minutes: 2)),
      );

      expect(submitted.pendingCount, 1);
      expect(submitted.activeCount, 1);
      expect(approved.pendingCount, 0);
      expect(approved.approvedCount, 1);
      expect(approved.activeCount, 1);
      expect(cancelled.approvedCount, 0);
      expect(cancelled.activeCount, 0);
    });

    test('blocks capacity transitions above facility capacity', () {
      final full = _sampleSlotCapacity(activeCount: 1);

      expect(
        () => nextCapacityForSubmit(
          current: full,
          slot: _sampleOccurrence(),
          facilityCapacity: 1,
          now: DateTime(2026, 5, 25, 8),
        ),
        throwsStateError,
      );
      expect(
        () => nextCapacityForApproval(
          current: full.copyWith(approvedCount: 1, pendingCount: 1),
          facilityCapacity: 1,
          now: DateTime(2026, 5, 25, 8),
        ),
        throwsStateError,
      );
    });

    test('generates exact-date and daily slot occurrences', () {
      final from = DateTime(2026, 5, 25, 8);
      final dateTemplate = _sampleSlotTemplate(
        slotMode: slotModeDate,
        slotDate: DateTime(2026, 5, 27),
        weekday: null,
      );
      final dailyTemplate = _sampleSlotTemplate(
        templateId: 'template-2',
        slotMode: slotModeDaily,
        weekday: null,
      );

      final dateOccurrences = generateAvailableSlotOccurrences(
        templates: [dateTemplate],
        reservations: const <FacilitySlotReservation>[],
        from: from,
      );
      final dailyOccurrences = generateAvailableSlotOccurrences(
        templates: [dailyTemplate],
        reservations: const <FacilitySlotReservation>[],
        from: from,
        days: 3,
      );

      expect(dateOccurrences, hasLength(1));
      expect(dateOccurrences.single.requestedDate, DateTime(2026, 5, 27));
      expect(dailyOccurrences, hasLength(3));
      expect(dailyOccurrences.first.requestedDate, DateTime(2026, 5, 25));
      expect(dailyOccurrences.last.requestedDate, DateTime(2026, 5, 27));
    });

    test('generates weekday slot occurrences from Monday to Friday only', () {
      final occurrences = generateAvailableSlotOccurrences(
        templates: [
          _sampleSlotTemplate(slotMode: slotModeWeekdays, weekday: null),
        ],
        reservations: const <FacilitySlotReservation>[],
        from: DateTime(2026, 5, 25, 8),
        days: 7,
      );

      expect(occurrences, hasLength(5));
      expect(
        occurrences.map((occurrence) => occurrence.requestedDate.weekday),
        [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ],
      );
    });

    test('hides past slot occurrences', () {
      final occurrences = generateAvailableSlotOccurrences(
        templates: [
          _sampleSlotTemplate(
            slotMode: slotModeDaily,
            weekday: null,
            startMinutes: 540,
            endMinutes: 600,
          ),
        ],
        reservations: const <FacilitySlotReservation>[],
        from: DateTime(2026, 5, 25, 10, 1),
        days: 1,
      );

      expect(occurrences, isEmpty);
    });

    test('validates booking drafts', () {
      expect(
        validateBookingDraft(facilityId: '', slot: _sampleOccurrence()),
        'Choose a facility',
      );
      expect(
        validateBookingDraft(facilityId: 'facility-1', slot: null),
        'Choose a time slot',
      );
      expect(
        validateBookingDraft(
          facilityId: 'facility-1',
          slot: _sampleOccurrence(),
        ),
        isNull,
      );
    });

    test('validates slot template drafts', () {
      expect(
        validateSlotTemplateDraft(
          facilityId: '',
          slotMode: slotModeWeekly,
          slotDate: null,
          weekday: DateTime.monday,
          startMinutes: 540,
          endMinutes: 600,
        ),
        'Choose a facility',
      );
      expect(
        validateSlotTemplateDraft(
          facilityId: 'facility-1',
          slotMode: slotModeWeekdays,
          slotDate: null,
          weekday: null,
          startMinutes: 540,
          endMinutes: 600,
        ),
        isNull,
      );
      expect(
        validateSlotTemplateDraft(
          facilityId: 'facility-1',
          slotMode: slotModeWeekly,
          slotDate: null,
          weekday: DateTime.monday,
          startMinutes: 600,
          endMinutes: 540,
        ),
        'End time must be after start time',
      );
      expect(
        validateSlotTemplateDraft(
          facilityId: 'facility-1',
          slotMode: slotModeDate,
          slotDate: null,
          weekday: null,
          startMinutes: 540,
          endMinutes: 600,
        ),
        'Choose a slot date',
      );
      expect(
        validateSlotTemplateDraft(
          facilityId: 'facility-1',
          slotMode: slotModeDaily,
          slotDate: null,
          weekday: null,
          startMinutes: 540,
          endMinutes: 600,
        ),
        isNull,
      );
      expect(
        validateSlotTemplateDraft(
          facilityId: 'facility-1',
          slotMode: slotModeWeekly,
          slotDate: null,
          weekday: DateTime.monday,
          startMinutes: 540,
          endMinutes: 600,
        ),
        isNull,
      );
    });

    test('validates facility drafts', () {
      expect(
        validateFacilityDraft(
          name: '',
          type: 'Room',
          location: 'Library',
          capacity: '40',
        ),
        'Facility name is required',
      );
      expect(
        validateFacilityDraft(
          name: 'Seminar Room A',
          type: 'Room',
          location: 'Library',
          capacity: '0',
        ),
        'Capacity must be greater than 0',
      );
      expect(
        validateFacilityDraft(
          name: 'Seminar Room A',
          type: 'Room',
          location: 'Library',
          capacity: '40',
        ),
        isNull,
      );
    });
  });

  group('Facility booking routes and screens', () {
    test('registers facility booking routes', () {
      final routes = AppRoutes.routes(isFirebaseReady: true);

      expect(routes.containsKey(AppRoutes.studentFacilityBooking), isTrue);
      expect(routes.containsKey(AppRoutes.staffBookingReview), isTrue);
      expect(routes.containsKey(AppRoutes.staffSlotManagement), isTrue);
      expect(routes.containsKey(AppRoutes.adminFacilityManagement), isTrue);
    });

    testWidgets('student dashboard opens booking route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.studentDashboard: (_) => const StudentDashboardScreen(),
            AppRoutes.studentFacilityBooking: (_) =>
                const Scaffold(body: Text('Student booking route opened')),
          },
          initialRoute: AppRoutes.studentDashboard,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Book a Facility'));
      await tester.pumpAndSettle();

      expect(find.text('Student booking route opened'), findsOneWidget);
    });

    testWidgets('staff dashboard opens booking review route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.staffDashboard: (_) => const StaffDashboardScreen(),
            AppRoutes.staffBookingReview: (_) =>
                const Scaffold(body: Text('Staff review route opened')),
          },
          initialRoute: AppRoutes.staffDashboard,
        ),
      );

      await tester.tap(find.text('Booking Requests'));
      await tester.pumpAndSettle();

      expect(find.text('Staff review route opened'), findsOneWidget);
    });

    testWidgets('staff dashboard opens slot management route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.staffDashboard: (_) => const StaffDashboardScreen(),
            AppRoutes.staffSlotManagement: (_) =>
                const Scaffold(body: Text('Slot management route opened')),
          },
          initialRoute: AppRoutes.staffDashboard,
        ),
      );

      await tester.tap(find.text('Facility Time Slots'));
      await tester.pumpAndSettle();

      expect(find.text('Slot management route opened'), findsOneWidget);
    });

    testWidgets('admin dashboard opens facility management route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
            AppRoutes.adminFacilityManagement: (_) =>
                const Scaffold(body: Text('Facility management route opened')),
          },
          initialRoute: AppRoutes.adminDashboard,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facilities'));
      await tester.pumpAndSettle();

      expect(find.text('Facility management route opened'), findsOneWidget);
    });

    testWidgets('student booking screen shows empty states', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(
            facilityBookingService: _FakeFacilityBookingService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No facilities yet'), findsOneWidget);
      expect(find.text('No bookings yet'), findsOneWidget);
    });

    testWidgets('student booking screen shows own booking states', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [_sampleFacility()],
              studentBookings: [
                _sampleBooking(),
                _sampleBooking(
                  bookingId: 'booking-2',
                  status: bookingStatusApproved,
                ),
                _sampleBooking(
                  bookingId: 'booking-3',
                  status: bookingStatusCancelled,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Seminar Room A'), findsWidgets);
      expect(find.text(bookingStatusPending), findsOneWidget);
      expect(
        find.byKey(const Key('cancelStudentBooking_booking-1')),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text(bookingStatusApproved), findsOneWidget);
      expect(find.text(bookingStatusCancelled), findsOneWidget);
    });

    testWidgets('student booking flow shows staff-provided slots only', (
      tester,
    ) async {
      final service = _FakeFacilityBookingService(
        facilities: [_sampleFacility()],
        slotTemplates: [_futureSlotTemplate()],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(facilityBookingService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bookFacility_facility-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bookingDateButton')), findsNothing);
      expect(find.byKey(const Key('bookingStartTimeButton')), findsNothing);
      expect(find.byKey(const Key('bookingEndTimeButton')), findsNothing);
      expect(find.text('Choose an available slot'), findsOneWidget);
      expect(find.text('09:00 - 10:00'), findsWidgets);

      await tester.tap(find.text('09:00 - 10:00').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitBookingButton')));
      await tester.pumpAndSettle();

      expect(service.submittedSlotIds, hasLength(1));
    });

    testWidgets('student booking shows capacity full submit error', (
      tester,
    ) async {
      final service = _FakeFacilityBookingService(
        facilities: [_sampleFacility()],
        slotTemplates: [_futureSlotTemplate()],
        submitError: const AppException(bookingCapacityFullMessage),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(facilityBookingService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bookFacility_facility-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00 - 10:00').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitBookingButton')));
      await tester.pumpAndSettle();

      expect(find.text(bookingCapacityFullMessage), findsOneWidget);
      expect(find.byKey(const Key('submitBookingButton')), findsOneWidget);
      expect(find.text('Submit booking'), findsOneWidget);
    });

    testWidgets('student booking shows save retry error', (tester) async {
      final service = _FakeFacilityBookingService(
        facilities: [_sampleFacility()],
        slotTemplates: [_futureSlotTemplate()],
        submitError: const AppException(bookingSaveDeniedMessage),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(facilityBookingService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bookFacility_facility-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00 - 10:00').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submitBookingButton')));
      await tester.pumpAndSettle();

      expect(find.text(bookingSaveDeniedMessage), findsOneWidget);
      expect(find.text('Submit booking'), findsOneWidget);
    });

    testWidgets('student booking hides reserved slots', (tester) async {
      final template = _futureSlotTemplate();
      final occurrences = generateAvailableSlotOccurrences(
        templates: [template],
        reservations: const <FacilitySlotReservation>[],
        from: DateTime.now(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [_sampleFacility(capacity: 1)],
              slotTemplates: [template],
              reservations: [
                for (final occurrence in occurrences)
                  _sampleReservation(
                    slotOccurrenceId: occurrence.slotOccurrenceId,
                    requestedDate: occurrence.requestedDate,
                    startTime: occurrence.startTime,
                    endTime: occurrence.endTime,
                  ),
              ],
              capacities: [
                for (final occurrence in occurrences)
                  _sampleSlotCapacity(
                    slotOccurrenceId: occurrence.slotOccurrenceId,
                    pendingCount: 1,
                    activeCount: 1,
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bookFacility_facility-1')));
      await tester.pumpAndSettle();

      expect(find.text('No slots available'), findsOneWidget);
    });

    testWidgets('staff review screen shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No booking requests'), findsOneWidget);
    });

    testWidgets('staff review screen renders approve and cancel actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [_sampleBooking()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('approveBooking_booking-1')), findsOneWidget);
      expect(
        find.byKey(const Key('cancelStaffBooking_booking-1')),
        findsOneWidget,
      );
    });

    testWidgets('admin facility screen shows empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminFacilityManagementScreen(
            facilityBookingService: _FakeFacilityBookingService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No facilities configured'), findsOneWidget);
    });

    testWidgets('staff slot management shows templates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffSlotManagementScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [_sampleFacility()],
              slotTemplates: [_sampleSlotTemplate()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Booking Availability'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Weekly - 09:00 - 10:00 - active'), findsOneWidget);
    });

    testWidgets('staff slot form shows mode-specific controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffSlotManagementScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [_sampleFacility()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addSlotTemplateButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slotModeDropdown')), findsOneWidget);
      expect(find.byKey(const Key('slotDateButton')), findsNothing);
      expect(find.byKey(const Key('slotWeekdayDropdown')), findsNothing);

      await tester.tap(find.byKey(const Key('slotModeDropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Weekdays'), findsOneWidget);
      await tester.tap(find.text('One date').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slotDateButton')), findsOneWidget);
      expect(find.byKey(const Key('slotWeekdayDropdown')), findsNothing);

      await tester.tap(find.byKey(const Key('slotModeDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slotDateButton')), findsNothing);
      expect(find.byKey(const Key('slotWeekdayDropdown')), findsOneWidget);
    });
  });
}

Facility _sampleFacility({
  String facilityId = 'facility-1',
  String status = facilityStatusAvailable,
  int capacity = 40,
}) {
  final now = DateTime(2026, 5, 25, 8);
  return Facility(
    facilityId: facilityId,
    name: 'Seminar Room A',
    type: 'Room',
    location: 'Library Level 2',
    capacity: capacity,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

FacilityBooking _sampleBooking({
  String bookingId = 'booking-1',
  String? slotOccurrenceId,
  String status = bookingStatusPending,
}) {
  return FacilityBooking(
    bookingId: bookingId,
    slotOccurrenceId: slotOccurrenceId ?? bookingId,
    facilityId: 'facility-1',
    templateId: 'template-1',
    facilityName: 'Seminar Room A',
    studentId: 'student-1',
    studentName: 'Aina Rahman',
    studentEmail: 'aina@example.com',
    requestedDate: DateTime(2026, 5, 25),
    startTime: DateTime(2026, 5, 25, 9),
    endTime: DateTime(2026, 5, 25, 10),
    status: status,
    reviewedBy: status == bookingStatusPending ? null : 'staff-1',
    reviewedAt: status == bookingStatusPending
        ? null
        : DateTime(2026, 5, 25, 8, 30),
    createdAt: DateTime(2026, 5, 25, 8),
    updatedAt: DateTime(2026, 5, 25, 8),
  );
}

FacilitySlotTemplate _sampleSlotTemplate({
  String templateId = 'template-1',
  String slotMode = slotModeWeekly,
  DateTime? slotDate,
  int? weekday = DateTime.monday,
  int startMinutes = 540,
  int endMinutes = 600,
  String status = slotTemplateStatusActive,
}) {
  final now = DateTime(2026, 5, 25, 8);
  return FacilitySlotTemplate(
    templateId: templateId,
    facilityId: 'facility-1',
    slotMode: slotMode,
    slotDate: slotDate,
    weekday: weekday,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    status: status,
    createdBy: 'staff-1',
    createdAt: now,
    updatedAt: now,
  );
}

FacilitySlotTemplate _futureSlotTemplate() {
  return _sampleSlotTemplate(
    weekday: DateTime.now().add(const Duration(days: 1)).weekday,
  );
}

FacilitySlotOccurrence _sampleOccurrence() {
  return FacilitySlotOccurrence.fromTemplate(
    template: _sampleSlotTemplate(),
    date: DateTime(2026, 5, 25),
  );
}

FacilitySlotReservation _sampleReservation({
  String? slotOccurrenceId,
  String? bookingId,
  DateTime? requestedDate,
  DateTime? startTime,
  DateTime? endTime,
  String status = bookingStatusPending,
}) {
  final occurrence = _sampleOccurrence();
  final now = DateTime(2026, 5, 25, 8);
  return FacilitySlotReservation(
    slotOccurrenceId: slotOccurrenceId ?? occurrence.slotOccurrenceId,
    facilityId: 'facility-1',
    templateId: 'template-1',
    bookingId: bookingId ?? slotOccurrenceId ?? occurrence.slotOccurrenceId,
    studentId: 'student-1',
    requestedDate: requestedDate ?? occurrence.requestedDate,
    startTime: startTime ?? occurrence.startTime,
    endTime: endTime ?? occurrence.endTime,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

FacilitySlotCapacity _sampleSlotCapacity({
  String? slotOccurrenceId,
  int pendingCount = 0,
  int approvedCount = 0,
  int? activeCount,
}) {
  final occurrence = _sampleOccurrence();
  final now = DateTime(2026, 5, 25, 8);
  return FacilitySlotCapacity(
    slotOccurrenceId: slotOccurrenceId ?? occurrence.slotOccurrenceId,
    facilityId: 'facility-1',
    requestedDate: occurrence.requestedDate,
    startTime: occurrence.startTime,
    endTime: occurrence.endTime,
    pendingCount: pendingCount,
    approvedCount: approvedCount,
    activeCount: activeCount ?? pendingCount + approvedCount,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeFacilityBookingService implements FacilityBookingService {
  _FakeFacilityBookingService({
    this.facilities = const <Facility>[],
    this.studentBookings = const <FacilityBooking>[],
    this.reviewBookings = const <FacilityBooking>[],
    this.slotTemplates = const <FacilitySlotTemplate>[],
    this.reservations = const <FacilitySlotReservation>[],
    this.capacities = const <FacilitySlotCapacity>[],
    this.submitError,
  });

  final List<Facility> facilities;
  final List<FacilityBooking> studentBookings;
  final List<FacilityBooking> reviewBookings;
  final List<FacilitySlotTemplate> slotTemplates;
  final List<FacilitySlotReservation> reservations;
  final List<FacilitySlotCapacity> capacities;
  final Object? submitError;
  final approvedBookingIds = <String>[];
  final cancelledBookingIds = <String>[];
  final submittedSlotIds = <String>[];

  @override
  Stream<List<Facility>> watchAvailableFacilities() {
    return Stream.value(
      facilities
          .where((facility) => facility.status == facilityStatusAvailable)
          .toList(),
    );
  }

  @override
  Stream<List<Facility>> watchFacilities() {
    return Stream.value(facilities);
  }

  @override
  Stream<List<FacilityBooking>> watchCurrentStudentBookings() {
    return Stream.value(studentBookings);
  }

  @override
  Stream<List<FacilityBooking>> watchBookingRequests() {
    return Stream.value(reviewBookings);
  }

  @override
  Stream<List<FacilitySlotTemplate>> watchSlotTemplatesForFacility(
    String facilityId,
  ) {
    return Stream.value(
      slotTemplates
          .where((template) => template.facilityId == facilityId)
          .toList(),
    );
  }

  @override
  Stream<List<FacilitySlotTemplate>> watchAvailableSlotTemplatesForFacility(
    String facilityId,
  ) {
    return Stream.value(
      slotTemplates
          .where(
            (template) =>
                template.facilityId == facilityId &&
                template.status == slotTemplateStatusActive,
          )
          .toList(),
    );
  }

  @override
  Stream<List<FacilitySlotReservation>> watchReservationsForFacility(
    String facilityId,
  ) {
    return Stream.value(
      reservations
          .where((reservation) => reservation.facilityId == facilityId)
          .toList(),
    );
  }

  @override
  Stream<List<FacilitySlotCapacity>> watchSlotCapacitiesForFacility(
    String facilityId,
  ) {
    return Stream.value(
      capacities
          .where((capacity) => capacity.facilityId == facilityId)
          .toList(),
    );
  }

  @override
  Future<Facility> createFacility(Facility facility) async {
    return facility.copyWith(facilityId: 'created-facility');
  }

  @override
  Future<void> updateFacility(Facility facility) async {}

  @override
  Future<void> deleteFacility(String facilityId) async {}

  @override
  Future<FacilitySlotTemplate> createSlotTemplate(
    FacilitySlotTemplate template,
  ) async {
    return template.copyWith(templateId: 'created-template');
  }

  @override
  Future<void> updateSlotTemplate(FacilitySlotTemplate template) async {}

  @override
  Future<void> deleteSlotTemplate(FacilitySlotTemplate template) async {}

  @override
  Future<FacilityBooking> submitBooking({
    required Facility facility,
    required FacilitySlotOccurrence slot,
  }) async {
    final error = submitError;
    if (error != null) {
      throw error;
    }

    submittedSlotIds.add(slot.slotOccurrenceId);
    return _sampleBooking(bookingId: slot.slotOccurrenceId);
  }

  @override
  Future<void> cancelStudentBooking(FacilityBooking booking) async {
    cancelledBookingIds.add(booking.bookingId);
  }

  @override
  Future<void> approveBooking(FacilityBooking booking) async {
    approvedBookingIds.add(booking.bookingId);
  }

  @override
  Future<void> cancelBookingAsStaff(FacilityBooking booking) async {
    cancelledBookingIds.add(booking.bookingId);
  }
}
