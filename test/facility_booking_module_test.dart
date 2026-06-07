import 'dart:async';

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
import 'package:utmgo/features/booking/screens/student_my_bookings_screen.dart';
import 'package:utmgo/features/booking/services/facility_booking_service.dart';
import 'package:utmgo/features/booking/services/staff_booking_review_preferences.dart';
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
      expect(routes.containsKey(AppRoutes.studentMyBookings), isTrue);
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

    testWidgets('student facility screen shows facilities only', (
      tester,
    ) async {
      final service = _FakeFacilityBookingService(
        studentBookings: [_sampleBooking()],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(facilityBookingService: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No facilities yet'), findsOneWidget);
      final myBookingsButton = find.byKey(const Key('studentMyBookingsButton'));
      expect(myBookingsButton, findsOneWidget);
      expect(tester.getSize(myBookingsButton).width, 320);
      expect(
        tester.getCenter(myBookingsButton).dx,
        tester.getCenter(find.byType(ListView)).dx,
      );
      expect(find.text('No bookings yet'), findsNothing);
      expect(
        find.byKey(const Key('cancelStudentBooking_booking-1')),
        findsNothing,
      );
      expect(service.watchCurrentStudentBookingsCallCount, 0);
    });

    testWidgets('student facility screen opens my bookings route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.studentMyBookings: (_) =>
                const Scaffold(body: Text('My bookings route opened')),
          },
          home: StudentFacilityBookingScreen(
            facilityBookingService: _FakeFacilityBookingService(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('studentMyBookingsButton')));
      await tester.pumpAndSettle();

      expect(find.text('My bookings route opened'), findsOneWidget);
    });

    testWidgets('student facility search is visible and filters start hidden', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [_sampleFacility()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('studentFacilitySearchField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('studentFacilityFilterToggle')),
        findsOneWidget,
      );
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.text('Facility type'), findsNothing);
      expect(find.text('Location'), findsNothing);
      expect(find.byKey(const Key('studentFacilitySortFilter')), findsNothing);
      expect(
        find.byKey(const Key('studentFacilityClearFilters')),
        findsNothing,
      );
    });

    testWidgets('student facility search matches name type and location', (
      tester,
    ) async {
      _useTallTestSurface(tester);
      final service = _FakeFacilityBookingService(
        facilities: [
          _sampleFacility(),
          _sampleFacility(
            facilityId: 'facility-2',
            name: 'Computer Lab B',
            type: 'Lab',
            location: 'Block N28',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(facilityBookingService: service),
        ),
      );

      await tester.pumpAndSettle();
      final searchField = find.byKey(const Key('studentFacilitySearchField'));

      await tester.tap(searchField);
      await tester.pump();
      await tester.enterText(searchField, 'c');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(searchField, 'computer');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bookFacility_facility-2')), findsOneWidget);
      expect(find.byKey(const Key('bookFacility_facility-1')), findsNothing);

      await tester.enterText(searchField, 'room');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bookFacility_facility-1')), findsOneWidget);
      expect(find.byKey(const Key('bookFacility_facility-2')), findsNothing);

      await tester.enterText(searchField, 'n28');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bookFacility_facility-2')), findsOneWidget);
      expect(find.byKey(const Key('bookFacility_facility-1')), findsNothing);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(service.watchAvailableFacilitiesCallCount, 1);
      expect(service.watchCurrentStudentBookingsCallCount, 0);
    });

    testWidgets(
      'student facility type and location filters combine and clear',
      (tester) async {
        _useTallTestSurface(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: StudentFacilityBookingScreen(
              facilityBookingService: _FakeFacilityBookingService(
                facilities: [
                  _sampleFacility(),
                  _sampleFacility(
                    facilityId: 'facility-2',
                    name: 'Computer Lab B',
                    type: 'Lab',
                    location: 'Block N28',
                  ),
                  _sampleFacility(
                    facilityId: 'facility-3',
                    name: 'Computer Lab C',
                    type: 'Lab',
                    location: 'Library Level 2',
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await _expandStudentFacilityFilters(tester);

        expect(find.text('Facility type'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        expect(
          find.byKey(const Key('studentFacilitySortFilter')),
          findsOneWidget,
        );
        expect(find.text('Name A-Z'), findsOneWidget);

        await tester.tap(find.text('All types'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lab').last);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bookFacility_facility-1')), findsNothing);
        expect(
          find.byKey(const Key('bookFacility_facility-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('bookFacility_facility-3')),
          findsOneWidget,
        );

        await tester.tap(find.text('All locations'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Block N28').last);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('bookFacility_facility-2')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('bookFacility_facility-3')), findsNothing);
        expect(find.text('1 of 3'), findsOneWidget);

        await tester.tap(find.byKey(const Key('studentFacilityClearFilters')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('bookFacility_facility-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('bookFacility_facility-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('bookFacility_facility-3')),
          findsOneWidget,
        );
        expect(find.text('Facility type'), findsNothing);
        expect(find.text('3 of 3'), findsOneWidget);
      },
    );

    testWidgets(
      'student facility sort reorders filtered facilities and clears',
      (tester) async {
        _useTallTestSurface(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: StudentFacilityBookingScreen(
              facilityBookingService: _FakeFacilityBookingService(
                facilities: [
                  _sampleFacility(
                    facilityId: 'facility-3',
                    name: 'Gamma Lab',
                    type: 'Lab',
                    location: 'Block B',
                  ),
                  _sampleFacility(
                    facilityId: 'facility-1',
                    name: 'Alpha Lab',
                    type: 'Lab',
                    location: 'Block C',
                  ),
                  _sampleFacility(
                    facilityId: 'facility-2',
                    name: 'Beta Room',
                    type: 'Room',
                    location: 'Block A',
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-1')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-2')))
                .dy,
          ),
        );
        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-2')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-3')))
                .dy,
          ),
        );

        await _expandStudentFacilityFilters(tester);
        await tester.tap(find.text('Name A-Z'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Location A-Z').last);
        await tester.pumpAndSettle();

        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-2')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-3')))
                .dy,
          ),
        );
        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-3')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-1')))
                .dy,
          ),
        );

        await tester.enterText(
          find.byKey(const Key('studentFacilitySearchField')),
          'lab',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('bookFacility_facility-2')), findsNothing);
        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-3')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-1')))
                .dy,
          ),
        );

        await tester.enterText(
          find.byKey(const Key('studentFacilitySearchField')),
          '',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Location A-Z'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Type A-Z').last);
        await tester.pumpAndSettle();
        expect(find.text('Type A-Z'), findsOneWidget);
        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-1')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-3')))
                .dy,
          ),
        );
        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-3')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-2')))
                .dy,
          ),
        );

        await tester.tap(find.byKey(const Key('studentFacilityClearFilters')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('studentFacilitySortFilter')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('studentFacilityClearFilters')),
          findsNothing,
        );
        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-1')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-2')))
                .dy,
          ),
        );
        expect(
          tester
              .getTopLeft(find.byKey(const Key('bookFacility_facility-2')))
              .dy,
          lessThan(
            tester
                .getTopLeft(find.byKey(const Key('bookFacility_facility-3')))
                .dy,
          ),
        );
      },
    );

    testWidgets('student facility filtered empty differs from true empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentFacilityBookingScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [_sampleFacility()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('studentFacilitySearchField')),
        'not found',
      );
      await tester.pumpAndSettle();

      expect(find.text('No matching facilities'), findsOneWidget);
      expect(find.text('No facilities yet'), findsNothing);
      expect(
        find.byKey(const Key('studentFacilityClearFilteredEmpty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('studentFacilityClearFilters')),
        findsNothing,
      );
      expect(find.text('0 of 1'), findsOneWidget);
    });

    testWidgets('student my bookings screen shows empty state', (tester) async {
      final service = _FakeFacilityBookingService();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentMyBookingsScreen(facilityBookingService: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No bookings yet'), findsOneWidget);
      expect(service.watchCurrentStudentBookingsCallCount, 1);
      expect(service.watchAvailableFacilitiesCallCount, 0);
    });

    testWidgets('student my bookings screen shows loading and error states', (
      tester,
    ) async {
      final controller = StreamController<List<FacilityBooking>>();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentMyBookingsScreen(
            facilityBookingService: _FakeFacilityBookingService(
              studentBookingsStream: controller.stream,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      controller.addError(const AppException('Booking stream failed.'));
      await tester.pump();

      expect(find.text('Could not load bookings'), findsOneWidget);
      expect(find.text('Booking stream failed.'), findsOneWidget);
    });

    testWidgets('student my bookings screen shows states and cancels pending', (
      tester,
    ) async {
      final service = _FakeFacilityBookingService(
        studentBookings: [
          _sampleBooking(),
          _sampleBooking(bookingId: 'booking-2', status: bookingStatusApproved),
          _sampleBooking(
            bookingId: 'booking-3',
            status: bookingStatusCancelled,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StudentMyBookingsScreen(facilityBookingService: service),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Seminar Room A'), findsNWidgets(3));
      expect(find.text(bookingStatusPending), findsOneWidget);
      expect(
        find.byKey(const Key('cancelStudentBooking_booking-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cancelStudentBooking_booking-2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('cancelStudentBooking_booking-3')),
        findsNothing,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text(bookingStatusApproved), findsOneWidget);
      expect(find.text(bookingStatusCancelled), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancelStudentBooking_booking-1')));
      await tester.pump();

      expect(service.cancelledBookingIds, ['booking-1']);
      expect(find.text('Booking cancelled.'), findsOneWidget);
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
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
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
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('approveBooking_booking-1')),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('approveBooking_booking-1')), findsOneWidget);
      expect(
        find.byKey(const Key('cancelStaffBooking_booking-1')),
        findsOneWidget,
      );
    });

    testWidgets('staff review screen minimizes filters by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [_sampleBooking()],
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filters'), findsOneWidget);
      expect(
        find.byKey(const Key('staffBookingFilterSummary')),
        findsOneWidget,
      );
      expect(find.text('Default view'), findsOneWidget);
      expect(find.byKey(const Key('staffBookingFilterToggle')), findsOneWidget);
      expect(find.byKey(const Key('staffBookingSearchField')), findsNothing);
      expect(find.byKey(const Key('staffBookingClearFilters')), findsNothing);
    });

    testWidgets('staff review expands sort and filter controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [_sampleBooking()],
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _expandStaffBookingFilters(tester);

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Facility'), findsOneWidget);
      expect(
        find.byKey(const Key('staffBookingFacilityTypeFilter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('staffBookingFacilityLocationFilter')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('staffBookingSearchField')), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.byKey(const Key('staffBookingClearFilters')), findsNothing);
      expect(
        find.byKey(const Key('staffBookingCollapsedClearFilters')),
        findsNothing,
      );
    });

    testWidgets('staff review status filter shows matching requests', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [
                _sampleBooking(),
                _sampleBooking(
                  bookingId: 'booking-2',
                  facilityId: 'facility-2',
                  facilityName: 'Computer Lab B',
                  status: bookingStatusApproved,
                ),
              ],
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _expandStaffBookingFilters(tester);
      await tester.tap(
        find.byKey(const Key('staffBookingStatusFilter_approved')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('staffBookingCollapsedClearFilters')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('staffBookingClearFilters')), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Computer Lab B'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Computer Lab B'), findsOneWidget);
      expect(find.text('Seminar Room A'), findsNothing);
    });

    testWidgets('staff review facility filter narrows requests', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [
                _sampleBooking(),
                _sampleBooking(
                  bookingId: 'booking-2',
                  facilityId: 'facility-2',
                  facilityName: 'Computer Lab B',
                ),
              ],
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _expandStaffBookingFilters(tester);
      await tester.tap(find.text('All facilities'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer Lab B').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Computer Lab B'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Computer Lab B'), findsOneWidget);
      expect(find.text('Seminar Room A'), findsNothing);
    });

    testWidgets('staff review facility type and location filters requests', (
      tester,
    ) async {
      _useTallTestSurface(tester);
      final preferenceStore = _FakeStaffBookingReviewPreferenceStore();
      final service = _FakeFacilityBookingService(
        facilities: [
          _sampleFacility(type: 'Room', location: 'Library Level 2'),
          _sampleFacility(
            facilityId: 'facility-2',
            name: 'Computer Lab B',
            type: 'Lab',
            location: 'Engineering Block',
          ),
          _sampleFacility(
            facilityId: 'unused-facility',
            name: 'Unused Hall',
            type: 'Hall',
            location: 'Main Block',
          ),
        ],
        reviewBookings: [
          _sampleBooking(),
          _sampleBooking(
            bookingId: 'booking-2',
            facilityId: 'facility-2',
            facilityName: 'Computer Lab B',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: service,
            preferenceStore: preferenceStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expandStaffBookingFilters(tester);

      await _selectDropdownOption(
        tester,
        const Key('staffBookingFacilityTypeFilter'),
        'Lab',
      );
      expect(find.text('Lab - 1 shown'), findsOneWidget);
      expect(find.text('Computer Lab B'), findsOneWidget);
      expect(find.text('Seminar Room A'), findsNothing);

      await _selectDropdownOption(
        tester,
        const Key('staffBookingFacilityTypeFilter'),
        'All types',
      );
      await _selectDropdownOption(
        tester,
        const Key('staffBookingFacilityLocationFilter'),
        'Library Level 2',
      );
      expect(find.text('Library Level 2 - 1 shown'), findsOneWidget);
      expect(find.text('Seminar Room A'), findsOneWidget);
      expect(find.text('Computer Lab B'), findsNothing);
      expect(find.text('Hall'), findsNothing);
      expect(find.text('Main Block'), findsNothing);
      expect(service.watchBookingRequestsCallCount, 1);
      expect(service.watchFacilitiesCallCount, 1);
      expect(preferenceStore.savedPreferences, isEmpty);
    });

    testWidgets(
      'staff review metadata filters combine and exclude missing data',
      (tester) async {
        _useTallTestSurface(tester);
        final preferenceStore = _FakeStaffBookingReviewPreferenceStore();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: StaffBookingReviewScreen(
              facilityBookingService: _FakeFacilityBookingService(
                facilities: [
                  _sampleFacility(type: 'Room', location: 'Library Level 2'),
                  _sampleFacility(
                    facilityId: 'facility-2',
                    name: 'Computer Lab B',
                    type: 'Lab',
                    location: 'Engineering Block',
                  ),
                ],
                reviewBookings: [
                  _sampleBooking(),
                  _sampleBooking(
                    bookingId: 'booking-2',
                    facilityId: 'facility-2',
                    facilityName: 'Computer Lab B',
                    studentName: 'Daniel Tan',
                    status: bookingStatusApproved,
                  ),
                  _sampleBooking(
                    bookingId: 'booking-missing',
                    facilityId: 'missing-facility',
                    facilityName: 'Archived Facility',
                  ),
                ],
              ),
              preferenceStore: preferenceStore,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Archived Facility'), findsOneWidget);
        await _expandStaffBookingFilters(tester);
        await _selectDropdownOption(
          tester,
          const ValueKey('staffBookingFacilityFilter_'),
          'Computer Lab B',
        );
        await _selectDropdownOption(
          tester,
          const Key('staffBookingFacilityTypeFilter'),
          'Lab',
        );
        await _selectDropdownOption(
          tester,
          const Key('staffBookingFacilityLocationFilter'),
          'Engineering Block',
        );
        await tester.tap(
          find.byKey(const Key('staffBookingStatusFilter_approved')),
        );
        await tester.pumpAndSettle();
        final searchField = find.byKey(const Key('staffBookingSearchField'));
        await tester.enterText(searchField, 'daniel');
        await tester.pumpAndSettle();

        expect(find.text('Computer Lab B'), findsWidgets);
        expect(find.text('Seminar Room A'), findsNothing);
        expect(find.text('Archived Facility'), findsNothing);
        expect(
          find.text(
            'Approved - Computer Lab B - Lab - Engineering Block - Search: daniel - 1 shown',
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('staffBookingCollapsedClearFilters')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Default view'), findsOneWidget);
        expect(find.text('Seminar Room A'), findsOneWidget);
        expect(find.text('Computer Lab B'), findsOneWidget);
        expect(find.text('Archived Facility'), findsOneWidget);
        expect(find.byKey(const Key('staffBookingSearchField')), findsNothing);
        expect(
          preferenceStore.savedPreferences.last,
          same(StaffBookingReviewPreferences.defaults),
        );
      },
    );

    testWidgets('staff review search matches student email and facility', (
      tester,
    ) async {
      final service = _FakeFacilityBookingService(
        reviewBookings: [
          _sampleBooking(),
          _sampleBooking(
            bookingId: 'booking-2',
            facilityId: 'facility-2',
            facilityName: 'Computer Lab B',
            studentName: 'Daniel Tan',
            studentEmail: 'daniel@example.com',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: service,
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _expandStaffBookingFilters(tester);
      final searchField = find.byKey(const Key('staffBookingSearchField'));
      await tester.tap(searchField);
      await tester.pump();
      await tester.enterText(searchField, 'd');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(searchField, 'daniel@example.com');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Computer Lab B'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Computer Lab B'), findsOneWidget);
      expect(find.text('Seminar Room A'), findsNothing);

      await tester.enterText(searchField, 'seminar');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Seminar Room A'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Seminar Room A'), findsOneWidget);
      expect(find.text('Computer Lab B'), findsNothing);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(service.watchBookingRequestsCallCount, 1);
      expect(service.watchFacilitiesCallCount, 1);
    });

    testWidgets('staff review persisted date range filters requests', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [
                _sampleBooking(requestedDate: DateTime(2026, 5, 25)),
                _sampleBooking(
                  bookingId: 'booking-2',
                  facilityId: 'facility-2',
                  facilityName: 'Computer Lab B',
                  requestedDate: DateTime(2026, 6, 4),
                  startTime: DateTime(2026, 6, 4, 14),
                  endTime: DateTime(2026, 6, 4, 16),
                ),
              ],
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(
              initialPreferences: StaffBookingReviewPreferences(
                fromDate: DateTime(2026, 6, 1),
                toDate: DateTime(2026, 6, 30),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('01/06/2026 to 30/06/2026 - 1 shown'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Computer Lab B'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Computer Lab B'), findsOneWidget);
      expect(find.text('Seminar Room A'), findsNothing);
      await _expandStaffBookingFilters(tester);
      expect(find.text('From: 01/06/2026'), findsOneWidget);
      expect(find.text('To: 30/06/2026'), findsOneWidget);
    });

    testWidgets('staff review sort reorders visible requests', (tester) async {
      _useTallTestSurface(tester);
      final bookings = [
        _sampleBooking(
          facilityName: 'Seminar Room A',
          requestedDate: DateTime(2026, 6, 5),
          startTime: DateTime(2026, 6, 5, 15),
          endTime: DateTime(2026, 6, 5, 16),
          createdAt: DateTime(2026, 6, 1, 8),
        ),
        _sampleBooking(
          bookingId: 'booking-2',
          facilityId: 'facility-2',
          facilityName: 'Computer Lab B',
          studentName: 'Daniel Tan',
          requestedDate: DateTime(2026, 6, 3),
          startTime: DateTime(2026, 6, 3, 9),
          endTime: DateTime(2026, 6, 3, 10),
          createdAt: DateTime(2026, 6, 2, 8),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            key: const Key('defaultSortStaffReview'),
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: bookings,
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Computer Lab B').first).dy,
        lessThan(tester.getTopLeft(find.text('Seminar Room A').first).dy),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            key: const Key('latestSortStaffReview'),
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: bookings,
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(
              initialPreferences: const StaffBookingReviewPreferences(
                sortOption: StaffBookingSortOption.bookingLatest,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('Seminar Room A').first).dy,
        lessThan(tester.getTopLeft(find.text('Computer Lab B').first).dy),
      );
    });

    testWidgets('staff review loads persisted preferences', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [
                _sampleBooking(),
                _sampleBooking(
                  bookingId: 'booking-2',
                  facilityId: 'facility-2',
                  facilityName: 'Computer Lab B',
                  status: bookingStatusApproved,
                ),
              ],
            ),
            preferenceStore: _FakeStaffBookingReviewPreferenceStore(
              initialPreferences: const StaffBookingReviewPreferences(
                statusFilter: StaffBookingStatusFilter.approved,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Approved - 1 shown'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Computer Lab B'),
        160,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Computer Lab B'), findsOneWidget);
      expect(find.text('Seminar Room A'), findsNothing);
    });

    testWidgets('staff review clear filters restores defaults and saves', (
      tester,
    ) async {
      _useTallTestSurface(tester);
      final preferenceStore = _FakeStaffBookingReviewPreferenceStore(
        initialPreferences: const StaffBookingReviewPreferences(
          statusFilter: StaffBookingStatusFilter.approved,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffBookingReviewScreen(
            facilityBookingService: _FakeFacilityBookingService(
              reviewBookings: [
                _sampleBooking(),
                _sampleBooking(
                  bookingId: 'booking-2',
                  facilityId: 'facility-2',
                  facilityName: 'Computer Lab B',
                  status: bookingStatusApproved,
                ),
              ],
            ),
            preferenceStore: preferenceStore,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('staffBookingCollapsedClearFilters')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Seminar Room A'), findsOneWidget);
      expect(find.text('Computer Lab B'), findsOneWidget);
      expect(find.text('Default view'), findsOneWidget);
      expect(find.byKey(const Key('staffBookingSearchField')), findsNothing);
      expect(
        preferenceStore.savedPreferences.last.statusFilter,
        StaffBookingStatusFilter.all,
      );
    });

    testWidgets(
      'staff review filtered empty state is separate from true empty',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: StaffBookingReviewScreen(
              facilityBookingService: _FakeFacilityBookingService(
                reviewBookings: [_sampleBooking()],
              ),
              preferenceStore: _FakeStaffBookingReviewPreferenceStore(
                initialPreferences: const StaffBookingReviewPreferences(
                  searchQuery: 'not found',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('No matching requests'),
          160,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text('No matching requests'), findsOneWidget);
        expect(find.text('No booking requests'), findsNothing);
      },
    );

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
      expect(find.text('No matching facilities'), findsNothing);
      expect(find.byKey(const Key('adminFacilitySearchField')), findsNothing);
    });

    testWidgets('admin facility search is stable and matches facility fields', (
      tester,
    ) async {
      _useTallTestSurface(tester);
      final service = _FakeFacilityBookingService(
        facilities: [
          _sampleFacility(
            facilityId: 'facility-alpha',
            name: 'Alpha Room',
            type: 'Room',
            location: 'West Wing',
          ),
          _sampleFacility(
            facilityId: 'facility-beta',
            name: 'Beta Hall',
            type: 'Hall',
            location: 'North Block',
          ),
          _sampleFacility(
            facilityId: 'facility-gamma',
            name: 'Gamma Lab',
            type: 'Laboratory',
            location: 'East Wing',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminFacilityManagementScreen(facilityBookingService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adminFacilitySearchField')), findsOneWidget);
      expect(find.byKey(const Key('adminFacilitySortFilter')), findsNothing);
      expect(find.text('3 of 3'), findsOneWidget);
      expect(
        _adminFacilityTop(tester, 'facility-alpha'),
        lessThan(_adminFacilityTop(tester, 'facility-beta')),
      );

      final searchField = find.byKey(const Key('adminFacilitySearchField'));
      await tester.tap(searchField);
      await tester.enterText(searchField, 'g');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(searchField, 'laboratory');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('adminFacilityTile_facility-gamma')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-alpha')),
        findsNothing,
      );

      await tester.enterText(searchField, 'east wing');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('adminFacilityTile_facility-gamma')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('editFacility_facility-gamma')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('deleteFacility_facility-gamma')),
        findsOneWidget,
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(service.watchFacilitiesCallCount, 1);
    });

    testWidgets('admin facility filters and sorting combine and clear', (
      tester,
    ) async {
      _useTallTestSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminFacilityManagementScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [
                _sampleFacility(
                  facilityId: 'facility-alpha',
                  name: 'Alpha Room',
                  type: 'Zeta Space',
                  location: 'West Wing',
                ),
                _sampleFacility(
                  facilityId: 'facility-beta',
                  name: 'Beta Hall',
                  type: 'Hall',
                  location: 'North Block',
                ),
                _sampleFacility(
                  facilityId: 'facility-gamma',
                  name: 'Gamma Lab',
                  type: 'Lab',
                  location: 'East Wing',
                  status: facilityStatusUnavailable,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _expandAdminFacilityFilters(tester);

      await _selectDropdownOption(
        tester,
        const Key('adminFacilitySortFilter'),
        'Type A-Z',
      );
      expect(
        _adminFacilityTop(tester, 'facility-beta'),
        lessThan(_adminFacilityTop(tester, 'facility-gamma')),
      );
      expect(
        _adminFacilityTop(tester, 'facility-gamma'),
        lessThan(_adminFacilityTop(tester, 'facility-alpha')),
      );

      await _selectDropdownOption(
        tester,
        const Key('adminFacilitySortFilter'),
        'Location A-Z',
      );
      expect(
        _adminFacilityTop(tester, 'facility-gamma'),
        lessThan(_adminFacilityTop(tester, 'facility-beta')),
      );
      expect(
        _adminFacilityTop(tester, 'facility-beta'),
        lessThan(_adminFacilityTop(tester, 'facility-alpha')),
      );

      await _selectDropdownOption(
        tester,
        const ValueKey('adminFacilityTypeFilter_'),
        'Lab',
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-gamma')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-alpha')),
        findsNothing,
      );
      await _selectDropdownOption(
        tester,
        const ValueKey('adminFacilityTypeFilter_Lab'),
        'All types',
      );
      await _selectDropdownOption(
        tester,
        const ValueKey('adminFacilityLocationFilter_'),
        'East Wing',
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-gamma')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-beta')),
        findsNothing,
      );
      await _selectDropdownOption(
        tester,
        const ValueKey('adminFacilityLocationFilter_East Wing'),
        'All locations',
      );
      await _selectDropdownOption(
        tester,
        const Key('adminFacilityStatusFilter'),
        'Unavailable',
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-gamma')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-alpha')),
        findsNothing,
      );
      await _selectDropdownOption(
        tester,
        const ValueKey('adminFacilityTypeFilter_'),
        'Lab',
      );
      await _selectDropdownOption(
        tester,
        const ValueKey('adminFacilityLocationFilter_'),
        'East Wing',
      );
      expect(find.text('1 of 3'), findsOneWidget);
      expect(
        find.byKey(const Key('adminFacilityTile_facility-gamma')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-alpha')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('adminFacilityClearFilters')));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);
      expect(find.byKey(const Key('adminFacilitySortFilter')), findsNothing);
      expect(
        _adminFacilityTop(tester, 'facility-alpha'),
        lessThan(_adminFacilityTop(tester, 'facility-beta')),
      );
      expect(
        find.byKey(const Key('adminFacilityTile_facility-gamma')),
        findsOneWidget,
      );
    });

    testWidgets('admin facility filtered empty is separate from true empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminFacilityManagementScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [_sampleFacility()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('adminFacilitySearchField')),
        'not found',
      );
      await tester.pumpAndSettle();

      expect(find.text('No matching facilities'), findsOneWidget);
      expect(find.text('No facilities configured'), findsNothing);
      expect(
        find.byKey(const Key('adminFacilityClearFilteredEmpty')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('adminFacilityClearFilteredEmpty')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seminar Room A'), findsOneWidget);
      expect(find.text('No matching facilities'), findsNothing);
    });

    testWidgets('staff slot management shows templates', (tester) async {
      _useTallTestSurface(tester);
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
      expect(
        find.byKey(const Key('staffSlotSelectedFacilityDetail')),
        findsOneWidget,
      );
      expect(find.text('Seminar Room A'), findsOneWidget);
      expect(find.text('Room'), findsOneWidget);
      expect(find.text('Library Level 2'), findsOneWidget);
      expect(find.text('Capacity 40'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('1 configured slot'), findsOneWidget);
      expect(
        find.byKey(const Key('staffSlotSelectedFacilityStatus')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('staffSlotSelectedFacilitySlotCount')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('staffSlotFacilitySearchField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('staffSlotFacilitySortFilter')),
        findsNothing,
      );
      expect(find.byKey(const Key('staffSlotSearchField')), findsNothing);
    });

    testWidgets(
      'staff slot facility search preserves selected slots and streams',
      (tester) async {
        _useTallTestSurface(tester);
        final service = _FakeFacilityBookingService(
          facilities: [
            _sampleFacility(
              facilityId: 'facility-alpha',
              name: 'Alpha Room',
              type: 'Room',
              location: 'West Wing',
            ),
            _sampleFacility(
              facilityId: 'facility-beta',
              name: 'Beta Hall',
              type: 'Hall',
              location: 'North Block',
            ),
            _sampleFacility(
              facilityId: 'facility-gamma',
              name: 'Gamma Lab',
              type: 'Lab',
              location: 'East Wing',
              status: facilityStatusUnavailable,
            ),
          ],
          slotTemplates: [
            _sampleSlotTemplate(
              templateId: 'template-monday',
              facilityId: 'facility-alpha',
              weekday: DateTime.monday,
              startMinutes: 600,
              endMinutes: 660,
            ),
            _sampleSlotTemplate(
              templateId: 'template-friday',
              facilityId: 'facility-alpha',
              weekday: DateTime.friday,
              startMinutes: 540,
              endMinutes: 600,
              status: slotTemplateStatusInactive,
            ),
            _sampleSlotTemplate(
              templateId: 'template-gamma',
              facilityId: 'facility-gamma',
              weekday: DateTime.tuesday,
              startMinutes: 720,
              endMinutes: 780,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: StaffSlotManagementScreen(facilityBookingService: service),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 of 3'), findsOneWidget);
        expect(
          _staffSlotTop(tester, 'template-monday'),
          lessThan(_staffSlotTop(tester, 'template-friday')),
        );

        final searchField = find.byKey(
          const Key('staffSlotFacilitySearchField'),
        );
        await tester.tap(searchField);
        await tester.pump();
        await tester.enterText(searchField, 'g');
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.enterText(searchField, 'gamma');
        await tester.pumpAndSettle();
        expect(find.text('1 of 3'), findsOneWidget);
        expect(
          find.byKey(const Key('staffSlotTemplate_template-monday')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('staffSlotTemplate_template-friday')),
          findsOneWidget,
        );
        expect(find.text('Alpha Room'), findsOneWidget);
        expect(find.text('Room'), findsOneWidget);
        expect(find.text('West Wing'), findsOneWidget);
        expect(find.text('Capacity 40'), findsOneWidget);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('2 configured slots'), findsOneWidget);
        expect(service.watchFacilitiesCallCount, 1);
        expect(service.watchSlotTemplateCallCounts['facility-alpha'], 1);

        await tester.tap(find.byKey(const Key('slotFacilityDropdown')));
        await tester.pumpAndSettle();
        expect(find.text('Alpha Room (Selected)'), findsWidgets);
        expect(find.text('Gamma Lab'), findsOneWidget);
        expect(find.text('Beta Hall'), findsNothing);
        await tester.tap(find.text('Gamma Lab'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('staffSlotTemplate_template-gamma')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('staffSlotTemplate_template-monday')),
          findsNothing,
        );
        expect(find.text('Gamma Lab'), findsOneWidget);
        expect(find.text('Lab'), findsOneWidget);
        expect(find.text('East Wing'), findsOneWidget);
        expect(find.text('Capacity 40'), findsOneWidget);
        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('1 configured slot'), findsOneWidget);
        expect(service.watchSlotTemplateCallCounts['facility-gamma'], 1);

        await tester.enterText(searchField, 'not found');
        await tester.pumpAndSettle();
        expect(find.text('No matching facilities'), findsOneWidget);
        expect(find.text('No Slots'), findsNothing);
        expect(
          find.byKey(const Key('staffSlotTemplate_template-gamma')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('staffSlotSelectedFacilityDetail')),
          findsOneWidget,
        );
        expect(find.text('Gamma Lab'), findsOneWidget);
        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('1 configured slot'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('staffSlotFacilityClearFilters')),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 of 3'), findsOneWidget);
        expect(
          find.byKey(const Key('staffSlotFacilitySortFilter')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('staffSlotTemplate_template-gamma')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('slotFacilityDropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alpha Room').last);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('staffSlotTemplate_template-monday')),
          findsOneWidget,
        );
        expect(find.text('Alpha Room'), findsOneWidget);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('2 configured slots'), findsOneWidget);
        expect(service.watchSlotTemplateCallCounts['facility-alpha'], 1);
      },
    );

    testWidgets('staff slot facility filters and sorting narrow choices', (
      tester,
    ) async {
      _useTallTestSurface(tester);
      final service = _FakeFacilityBookingService(
        facilities: [
          _sampleFacility(
            facilityId: 'facility-alpha',
            name: 'Alpha Room',
            type: 'Zeta Space',
            location: 'Zeta Wing',
          ),
          _sampleFacility(
            facilityId: 'facility-beta',
            name: 'Beta Hall',
            type: 'Hall',
            location: 'North Block',
          ),
          _sampleFacility(
            facilityId: 'facility-delta',
            name: 'Delta Room',
            type: 'Room',
            location: 'West Wing',
          ),
          _sampleFacility(
            facilityId: 'facility-gamma',
            name: 'Gamma Lab',
            type: 'Lab',
            location: 'East Wing',
            status: facilityStatusUnavailable,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffSlotManagementScreen(facilityBookingService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Beta Hall',
        'Delta Room',
        'Gamma Lab',
      ]);

      await _expandStaffSlotFacilityFilters(tester);
      await _selectStaffSlotFacilityFilter(
        tester,
        const Key('staffSlotFacilitySortFilter'),
        'Type A-Z',
      );
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Beta Hall',
        'Gamma Lab',
        'Delta Room',
      ]);

      await _selectStaffSlotFacilityFilter(
        tester,
        const Key('staffSlotFacilitySortFilter'),
        'Location A-Z',
      );
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Gamma Lab',
        'Beta Hall',
        'Delta Room',
      ]);

      await _selectStaffSlotFacilityFilter(
        tester,
        const Key('staffSlotFacilityTypeFilter_'),
        'Lab',
      );
      expect(find.text('1 of 4'), findsOneWidget);
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Gamma Lab',
      ]);

      await _selectStaffSlotFacilityFilter(
        tester,
        const Key('staffSlotFacilityTypeFilter_Lab'),
        'All types',
      );
      await _selectStaffSlotFacilityFilter(
        tester,
        const Key('staffSlotFacilityLocationFilter_'),
        'East Wing',
      );
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Gamma Lab',
      ]);

      await _selectStaffSlotFacilityFilter(
        tester,
        const Key('staffSlotFacilityLocationFilter_East Wing'),
        'All locations',
      );
      await _selectStaffSlotFacilityFilter(
        tester,
        const Key('staffSlotFacilityStatusFilter'),
        'Unavailable',
      );
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Gamma Lab',
      ]);

      await tester.tap(find.byKey(const Key('staffSlotFacilityClearFilters')));
      await tester.pumpAndSettle();
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Beta Hall',
        'Delta Room',
        'Gamma Lab',
      ]);
      expect(
        find.byKey(const Key('staffSlotFacilitySortFilter')),
        findsNothing,
      );
    });

    testWidgets('staff slot facility search matches type and location', (
      tester,
    ) async {
      _useTallTestSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StaffSlotManagementScreen(
            facilityBookingService: _FakeFacilityBookingService(
              facilities: [
                _sampleFacility(
                  facilityId: 'facility-alpha',
                  name: 'Alpha Room',
                ),
                _sampleFacility(
                  facilityId: 'facility-gamma',
                  name: 'Gamma Lab',
                  type: 'Laboratory',
                  location: 'East Wing',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('staffSlotFacilitySearchField'));
      await tester.enterText(searchField, 'laboratory');
      await tester.pumpAndSettle();
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Gamma Lab',
      ]);

      await tester.enterText(searchField, 'east wing');
      await tester.pumpAndSettle();
      expect(_staffSlotFacilityChoices(tester), [
        'Alpha Room (Selected)',
        'Gamma Lab',
      ]);
    });

    testWidgets(
      'staff slot management keeps selected facility no slots state',
      (tester) async {
        _useTallTestSurface(tester);
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

        expect(find.text('No Slots'), findsOneWidget);
        expect(find.text('No matching facilities'), findsNothing);
        expect(
          find.byKey(const Key('staffSlotSelectedFacilityDetail')),
          findsOneWidget,
        );
        expect(find.text('0 configured slots'), findsOneWidget);
        expect(
          find.byKey(const Key('staffSlotFacilitySearchField')),
          findsOneWidget,
        );
      },
    );

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

void _useTallTestSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _expandStaffBookingFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('staffBookingFilterToggle')));
  await tester.pumpAndSettle();
}

Future<void> _expandAdminFacilityFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('adminFacilityFilterToggle')));
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownOption(
  WidgetTester tester,
  Key dropdownKey,
  String option,
) async {
  await tester.tap(find.byKey(dropdownKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _expandStudentFacilityFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('studentFacilityFilterToggle')));
  await tester.pumpAndSettle();
}

Future<void> _expandStaffSlotFacilityFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('staffSlotFacilityFilterToggle')));
  await tester.pumpAndSettle();
}

Future<void> _selectStaffSlotFacilityFilter(
  WidgetTester tester,
  Key key,
  String option,
) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

List<String> _staffSlotFacilityChoices(WidgetTester tester) {
  final dropdown = tester.widget<DropdownButton<String>>(
    find.descendant(
      of: find.byKey(const Key('slotFacilityDropdown')),
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<String>,
      ),
    ),
  );
  return dropdown.items!
      .map((item) => (item.child as Text).data!)
      .toList(growable: false);
}

double _staffSlotTop(WidgetTester tester, String templateId) {
  return tester.getTopLeft(find.byKey(Key('staffSlotTemplate_$templateId'))).dy;
}

double _adminFacilityTop(WidgetTester tester, String facilityId) {
  return tester.getTopLeft(find.byKey(Key('adminFacilityTile_$facilityId'))).dy;
}

Facility _sampleFacility({
  String facilityId = 'facility-1',
  String name = 'Seminar Room A',
  String type = 'Room',
  String location = 'Library Level 2',
  String status = facilityStatusAvailable,
  int capacity = 40,
}) {
  final now = DateTime(2026, 5, 25, 8);
  return Facility(
    facilityId: facilityId,
    name: name,
    type: type,
    location: location,
    capacity: capacity,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

FacilityBooking _sampleBooking({
  String bookingId = 'booking-1',
  String? slotOccurrenceId,
  String facilityId = 'facility-1',
  String facilityName = 'Seminar Room A',
  String studentName = 'Aina Rahman',
  String studentEmail = 'aina@example.com',
  DateTime? requestedDate,
  DateTime? startTime,
  DateTime? endTime,
  String status = bookingStatusPending,
  DateTime? createdAt,
}) {
  final savedRequestedDate = requestedDate ?? DateTime(2026, 5, 25);
  final savedStartTime = startTime ?? DateTime(2026, 5, 25, 9);
  final savedEndTime = endTime ?? DateTime(2026, 5, 25, 10);
  final savedCreatedAt = createdAt ?? DateTime(2026, 5, 25, 8);
  return FacilityBooking(
    bookingId: bookingId,
    slotOccurrenceId: slotOccurrenceId ?? bookingId,
    facilityId: facilityId,
    templateId: 'template-1',
    facilityName: facilityName,
    studentId: 'student-1',
    studentName: studentName,
    studentEmail: studentEmail,
    requestedDate: savedRequestedDate,
    startTime: savedStartTime,
    endTime: savedEndTime,
    status: status,
    reviewedBy: status == bookingStatusPending ? null : 'staff-1',
    reviewedAt: status == bookingStatusPending
        ? null
        : DateTime(2026, 5, 25, 8, 30),
    createdAt: savedCreatedAt,
    updatedAt: savedCreatedAt,
  );
}

FacilitySlotTemplate _sampleSlotTemplate({
  String templateId = 'template-1',
  String facilityId = 'facility-1',
  String slotMode = slotModeWeekly,
  DateTime? slotDate,
  int? weekday = DateTime.monday,
  int startMinutes = 540,
  int endMinutes = 600,
  String status = slotTemplateStatusActive,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 5, 25, 8);
  return FacilitySlotTemplate(
    templateId: templateId,
    facilityId: facilityId,
    slotMode: slotMode,
    slotDate: slotDate,
    weekday: weekday,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    status: status,
    createdBy: 'staff-1',
    createdAt: now,
    updatedAt: updatedAt ?? now,
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
    this.studentBookingsStream,
    this.reviewBookings = const <FacilityBooking>[],
    this.slotTemplates = const <FacilitySlotTemplate>[],
    this.reservations = const <FacilitySlotReservation>[],
    this.capacities = const <FacilitySlotCapacity>[],
    this.submitError,
  });

  final List<Facility> facilities;
  final List<FacilityBooking> studentBookings;
  final Stream<List<FacilityBooking>>? studentBookingsStream;
  final List<FacilityBooking> reviewBookings;
  final List<FacilitySlotTemplate> slotTemplates;
  final List<FacilitySlotReservation> reservations;
  final List<FacilitySlotCapacity> capacities;
  final Object? submitError;
  final approvedBookingIds = <String>[];
  final cancelledBookingIds = <String>[];
  final submittedSlotIds = <String>[];
  int watchAvailableFacilitiesCallCount = 0;
  int watchCurrentStudentBookingsCallCount = 0;
  int watchBookingRequestsCallCount = 0;
  int watchFacilitiesCallCount = 0;
  final watchSlotTemplateCallCounts = <String, int>{};

  @override
  Stream<List<Facility>> watchAvailableFacilities() {
    watchAvailableFacilitiesCallCount++;
    return Stream.value(
      facilities
          .where((facility) => facility.status == facilityStatusAvailable)
          .toList(),
    );
  }

  @override
  Stream<List<Facility>> watchFacilities() {
    watchFacilitiesCallCount++;
    return Stream.value(facilities);
  }

  @override
  Stream<List<FacilityBooking>> watchCurrentStudentBookings() {
    watchCurrentStudentBookingsCallCount++;
    return studentBookingsStream ?? Stream.value(studentBookings);
  }

  @override
  Stream<List<FacilityBooking>> watchBookingRequests() {
    watchBookingRequestsCallCount++;
    return Stream.value(reviewBookings);
  }

  @override
  Stream<List<FacilitySlotTemplate>> watchSlotTemplatesForFacility(
    String facilityId,
  ) {
    watchSlotTemplateCallCounts[facilityId] =
        (watchSlotTemplateCallCounts[facilityId] ?? 0) + 1;
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

class _FakeStaffBookingReviewPreferenceStore
    implements StaffBookingReviewPreferenceStore {
  _FakeStaffBookingReviewPreferenceStore({
    StaffBookingReviewPreferences initialPreferences =
        StaffBookingReviewPreferences.defaults,
  }) : _preferences = initialPreferences;

  StaffBookingReviewPreferences _preferences;
  final savedPreferences = <StaffBookingReviewPreferences>[];

  @override
  Future<StaffBookingReviewPreferences> load() async {
    return _preferences;
  }

  @override
  Future<void> save(StaffBookingReviewPreferences preferences) async {
    _preferences = preferences;
    savedPreferences.add(preferences);
  }
}
