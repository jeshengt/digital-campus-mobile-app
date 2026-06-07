import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utmgo/app/routes/app_routes.dart';
import 'package:utmgo/app/theme/app_theme.dart';
import 'package:utmgo/features/admin/screens/admin_dashboard_screen.dart';
import 'package:utmgo/features/bus_tracking/models/bus_location.dart';
import 'package:utmgo/features/bus_tracking/models/bus_route_point.dart';
import 'package:utmgo/features/bus_tracking/models/campus_bus.dart';
import 'package:utmgo/features/bus_tracking/screens/admin_bus_management_screen.dart';
import 'package:utmgo/features/bus_tracking/screens/bus_tracking_map_screen.dart';
import 'package:utmgo/features/bus_tracking/screens/driver_bus_broadcast_screen.dart';
import 'package:utmgo/features/bus_tracking/services/bus_admin_service.dart';
import 'package:utmgo/features/bus_tracking/services/bus_tracking_service.dart';
import 'package:utmgo/features/bus_tracking/utils/bus_admin_validation.dart';
import 'package:utmgo/features/bus_tracking/utils/bus_tracking_helpers.dart';
import 'package:utmgo/features/driver/screens/driver_dashboard_screen.dart';
import 'package:utmgo/features/lecturer/screens/lecturer_dashboard_screen.dart';
import 'package:utmgo/features/profile/models/app_user.dart';
import 'package:utmgo/features/student/screens/student_dashboard_screen.dart';
import 'package:utmgo/models/user_role.dart';

void main() {
  group('Bus tracking models', () {
    test('maps bus route data', () {
      const bus = CampusBus(
        busId: 'bus-1',
        routeName: 'Kolej Loop',
        driverIds: ['driver-1', 'driver-2'],
        status: 'active',
        startName: 'Library',
        endName: 'Kolej Rahman Putra',
        routePoints: [
          BusRoutePoint(latitude: 1.5583, longitude: 103.6371),
          BusRoutePoint(latitude: 1.5601, longitude: 103.6402),
        ],
      );

      final parsed = CampusBus.fromMap(bus.toMap());

      expect(parsed.busId, 'bus-1');
      expect(parsed.routeName, 'Kolej Loop');
      expect(parsed.driverIds, ['driver-1', 'driver-2']);
      expect(parsed.isAssignedTo('driver-2'), isTrue);
      expect(parsed.hasRouteGeometry, isTrue);
      expect(parsed.destinationPoint?.latitude, 1.5601);
    });

    test('copies bus route data for admin edits', () {
      final updated = _sampleBus().copyWith(
        routeName: 'Updated Loop',
        routePoints: const [
          BusRoutePoint(latitude: 1.5583, longitude: 103.6371),
          BusRoutePoint(latitude: 1.5610, longitude: 103.6410),
        ],
      );

      expect(updated.busId, 'bus-1');
      expect(updated.routeName, 'Updated Loop');
      expect(updated.routePoints.last.longitude, 103.6410);
    });

    test('maps live bus location data', () {
      final now = DateTime(2026, 5, 24, 14, 30);
      final location = BusLocation(
        busId: 'bus-1',
        driverId: 'driver-1',
        latitude: 1.5583,
        longitude: 103.6371,
        speed: 5,
        heading: 90,
        isBroadcasting: true,
        updatedAt: now,
      );

      final parsed = BusLocation.fromMap(location.toMap());

      expect(parsed.busId, 'bus-1');
      expect(parsed.speed, 5);
      expect(parsed.isBroadcasting, isTrue);
      expect(parsed.updatedAt, now);
    });
  });

  group('Bus tracking helpers', () {
    test('formats local straight-line ETA without paid routing APIs', () {
      final location = BusLocation(
        busId: 'bus-1',
        driverId: 'driver-1',
        latitude: 1.5583,
        longitude: 103.6371,
        speed: 5,
        heading: 90,
        isBroadcasting: true,
        updatedAt: DateTime(2026, 5, 24, 14, 30),
      );
      const destination = BusRoutePoint(latitude: 1.5593, longitude: 103.6371);

      final eta = estimateEta(location: location, destination: destination);

      expect(eta, isNotNull);
      expect(eta!.inSeconds, greaterThan(10));
      expect(formatEta(eta), isNot('ETA unavailable'));
      expect(formatEta(null), 'ETA unavailable');
    });

    test('formats bus update time with seconds', () {
      expect(formatUpdatedAt(DateTime(2026, 5, 24, 14, 3, 7)), '14:03:07');
    });

    test('validates admin bus drafts', () {
      expect(
        validateCampusBusDraft(
          routeName: '',
          routePoints: _sampleBus().routePoints,
        ),
        'Route name is required',
      );
      expect(
        validateCampusBusDraft(
          routeName: 'Kolej Loop',
          routePoints: _sampleBus().routePoints,
        ),
        isNull,
      );
      expect(
        validateCampusBusDraft(
          routeName: 'Kolej Loop',
          routePoints: const [
            BusRoutePoint(latitude: 1.5583, longitude: 103.6371),
          ],
        ),
        'Add at least 2 route points',
      );
    });
  });

  group('Bus tracking routes and screens', () {
    test('registers bus tracking routes', () {
      final routes = AppRoutes.routes(isFirebaseReady: true);

      expect(routes.containsKey(AppRoutes.adminBusManagement), isTrue);
      expect(routes.containsKey(AppRoutes.busTrackingMap), isTrue);
      expect(routes.containsKey(AppRoutes.driverBusBroadcast), isTrue);
    });

    testWidgets('admin dashboard opens bus management route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
            AppRoutes.adminBusManagement: (_) =>
                const Scaffold(body: Text('Bus management route opened')),
          },
          initialRoute: AppRoutes.adminDashboard,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bus Routes'));
      await tester.pumpAndSettle();

      expect(find.text('Bus management route opened'), findsOneWidget);
    });

    testWidgets('student dashboard opens bus tracking route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.studentDashboard: (_) => const StudentDashboardScreen(),
            AppRoutes.busTrackingMap: (_) =>
                const Scaffold(body: Text('Bus map route opened')),
          },
          initialRoute: AppRoutes.studentDashboard,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track Buses'));
      await tester.pumpAndSettle();

      expect(find.text('Bus map route opened'), findsOneWidget);
    });

    testWidgets('lecturer dashboard opens bus tracking route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.lecturerDashboard: (_) => const LecturerDashboardScreen(),
            AppRoutes.busTrackingMap: (_) =>
                const Scaffold(body: Text('Bus map route opened')),
          },
          initialRoute: AppRoutes.lecturerDashboard,
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track Buses'));
      await tester.pumpAndSettle();

      expect(find.text('Bus map route opened'), findsOneWidget);
    });

    testWidgets('driver dashboard opens broadcast route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.driverDashboard: (_) => const DriverDashboardScreen(),
            AppRoutes.driverBusBroadcast: (_) =>
                const Scaffold(body: Text('Broadcast route opened')),
          },
          initialRoute: AppRoutes.driverDashboard,
        ),
      );

      await tester.tap(find.text('Broadcast Bus Location'));
      await tester.pumpAndSettle();

      expect(find.text('Broadcast route opened'), findsOneWidget);
    });

    testWidgets('driver dashboard hides unused route telemetry card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          routes: {
            AppRoutes.driverDashboard: (_) => const DriverDashboardScreen(),
          },
          initialRoute: AppRoutes.driverDashboard,
        ),
      );

      expect(find.text('Broadcast Bus Location'), findsOneWidget);
      expect(find.text('Route telemetry'), findsNothing);
    });

    testWidgets('bus map shows empty bus state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BusTrackingMapScreen(
            busTrackingService: _FakeBusTrackingService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No buses yet'), findsOneWidget);
    });

    testWidgets('bus map shows no live buses when routes exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BusTrackingMapScreen(
            busTrackingService: _FakeBusTrackingService(buses: [_sampleBus()]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Campus shuttle map'), findsOneWidget);
      expect(find.text('No live buses'), findsOneWidget);
      expect(find.text('Kolej Loop'), findsWidgets);
      expect(find.byKey(const Key('busMapLocateButton')), findsOneWidget);
      expect(find.byKey(const Key('busTrackingMapPanel')), findsOneWidget);
      expect(find.byKey(const Key('busRouteDropdown')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('busRouteDropdown'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('busTrackingMapPanel'))).dy,
        ),
      );
    });

    testWidgets('bus map shows live bus count when a driver broadcasts', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BusTrackingMapScreen(
            busTrackingService: _FakeBusTrackingService(
              buses: [_sampleBus()],
              locations: [_sampleLocation()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 live bus now'), findsOneWidget);
      expect(find.byKey(const Key('busRouteDropdown')), findsOneWidget);
      expect(find.text('Kolej Loop - Live'), findsOneWidget);
      expect(find.text('14:30:00'), findsOneWidget);
    });

    testWidgets('bus map route dropdown changes selected route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BusTrackingMapScreen(
            busTrackingService: _FakeBusTrackingService(
              buses: [_sampleBus(), _sampleSecondBus()],
              locations: [_sampleLocation()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('busTrackingMapPanel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('busRouteDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engineering Shuttle - Offline').last);
      await tester.pumpAndSettle();

      expect(find.text('Engineering Shuttle - Offline'), findsOneWidget);
    });

    testWidgets('bus map draws only the selected route line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BusTrackingMapScreen(
            busTrackingService: _FakeBusTrackingService(
              buses: [_sampleBus(), _sampleSecondBus()],
              locations: [_sampleLocation()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      var routeLayer = _busRoutePolylineLayer(tester);
      expect(routeLayer.polylines, hasLength(1));
      expect(
        routeLayer.polylines.single.points.first.latitude,
        _sampleBus().routePoints.first.latitude,
      );

      await tester.tap(find.byKey(const Key('busRouteDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engineering Shuttle - Offline').last);
      await tester.pumpAndSettle();

      routeLayer = _busRoutePolylineLayer(tester);
      expect(routeLayer.polylines, hasLength(1));
      expect(
        routeLayer.polylines.single.points.first.latitude,
        _sampleSecondBus().routePoints.first.latitude,
      );
    });

    testWidgets('bus map draws only the selected live bus marker', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BusTrackingMapScreen(
            busTrackingService: _FakeBusTrackingService(
              buses: [_sampleBus(), _sampleSecondBus()],
              locations: [_sampleLocation(), _sampleSecondLocation()],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      var markerLayer = _busMarkerLayer(tester);
      expect(markerLayer.markers, hasLength(1));
      expect(
        markerLayer.markers.single.point.latitude,
        _sampleLocation().latitude,
      );

      await tester.tap(find.byKey(const Key('busRouteDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engineering Shuttle - Live').last);
      await tester.pumpAndSettle();

      markerLayer = _busMarkerLayer(tester);
      expect(markerLayer.markers, hasLength(1));
      expect(
        markerLayer.markers.single.point.latitude,
        _sampleSecondLocation().latitude,
      );
    });

    testWidgets('bus map can show user current location', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BusTrackingMapScreen(
            busTrackingService: _FakeBusTrackingService(
              buses: [_sampleBus()],
              locations: [_sampleLocation()],
            ),
            locationProvider: const _FakeBusLocationProvider(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('busMapLocateButton')));
      await tester.pumpAndSettle();

      expect(find.text('You are here'), findsOneWidget);
      expect(find.byIcon(Icons.person_pin_circle_rounded), findsOneWidget);
    });

    testWidgets('driver broadcast starts with assigned bus', (tester) async {
      final service = _FakeBusTrackingService(buses: [_sampleBus()]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DriverBusBroadcastScreen(
            busTrackingService: service,
            locationProvider: const _FakeBusLocationProvider(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('driverBroadcastToggleButton')),
        300,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driverBroadcastToggleButton')));
      await tester.pump();

      expect(service.publishedBusId, 'bus-1');
      expect(service.publishCount, 1);
      await tester.pump(busBroadcastInterval);
      expect(service.publishCount, 2);
      expect(find.text('Location broadcasting started.'), findsOneWidget);
    });

    testWidgets('driver broadcast shows route map and current location', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DriverBusBroadcastScreen(
            busTrackingService: _FakeBusTrackingService(
              buses: [_sampleBus()],
              locations: [_sampleLocation()],
            ),
            locationProvider: const _FakeBusLocationProvider(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Route map'), findsOneWidget);
      expect(find.byKey(const Key('driverBroadcastMap')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('driverLocateButton')),
        300,
      );
      await tester.pumpAndSettle();
      expect(find.text('Current location unavailable'), findsOneWidget);

      await tester.tap(find.byKey(const Key('driverLocateButton')));
      await tester.pumpAndSettle();

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('1.55830, 103.63710'), findsNothing);
      expect(find.byKey(const Key('driverLocateButton')), findsOneWidget);
      expect(find.text('Current location updated.'), findsOneWidget);
    });

    testWidgets('admin bus management allows route setup without drivers', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(
            busAdminService: _FakeBusAdminService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No buses configured'), findsOneWidget);
      expect(find.byKey(const Key('addBusButton')), findsOneWidget);
    });

    testWidgets('admin create form shows route-first fields and map picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(
            busAdminService: _FakeBusAdminService(drivers: [_sampleDriver()]),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addBusButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assignDriverDropdown')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('adminBusRouteMap')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('adminBusRouteMap')), findsOneWidget);
      expect(find.byKey(const Key('adminRouteLocateButton')), findsOneWidget);
    });

    testWidgets('admin route point picker adds, undoes, and clears points', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(
            busAdminService: _FakeBusAdminService(drivers: [_sampleDriver()]),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addBusButton')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('adminBusRouteMap')));
      await tester.pumpAndSettle();

      await _tapAdminRouteMap(tester);
      await tester.pumpAndSettle();
      await _tapAdminRouteMap(tester);
      await tester.pumpAndSettle();

      expect(find.text('2 route points added'), findsOneWidget);

      await tester.tap(find.byKey(const Key('undoRoutePointButton')));
      await tester.pumpAndSettle();

      expect(find.text('1 route point added'), findsOneWidget);

      await tester.tap(find.byKey(const Key('clearRoutePointsButton')));
      await tester.pumpAndSettle();

      expect(find.text('0 route points added'), findsOneWidget);
    });

    testWidgets('admin save creates a bus route', (tester) async {
      final service = _FakeBusAdminService(drivers: [_sampleDriver()]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(busAdminService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('addBusButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('busRouteNameField')),
        'Library Loop',
      );
      await tester.ensureVisible(find.byKey(const Key('adminBusRouteMap')));
      await tester.pumpAndSettle();
      await _tapAdminRouteMap(tester);
      await tester.pumpAndSettle();
      await _tapAdminRouteMap(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('saveBusButton')));
      await tester.tap(find.byKey(const Key('saveBusButton')));
      await tester.pumpAndSettle();

      expect(service.createdBus?.routeName, 'Library Loop');
      expect(service.createdBus?.driverIds, isEmpty);
      expect(service.createdBus?.routePoints.length, 2);
      expect(find.text('Bus route added.'), findsOneWidget);
    });

    testWidgets('admin edit preserves existing driver assignment', (
      tester,
    ) async {
      final service = _FakeBusAdminService(
        drivers: [_sampleDriver()],
        buses: [_sampleBus()],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(busAdminService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit bus route'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('busRouteNameField')),
        'Updated Library Loop',
      );
      await tester.ensureVisible(find.byKey(const Key('saveBusButton')));
      await tester.tap(find.byKey(const Key('saveBusButton')));
      await tester.pumpAndSettle();

      expect(service.updatedBus?.routeName, 'Updated Library Loop');
      expect(service.updatedBus?.driverIds, ['driver-1']);
      expect(find.text('Bus route updated.'), findsOneWidget);
    });

    testWidgets('admin assign driver flow updates route assignment', (
      tester,
    ) async {
      final service = _FakeBusAdminService(
        drivers: [_sampleDriver()],
        buses: [_sampleBus().copyWith(driverIds: const <String>[])],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(busAdminService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Assign drivers'));
      await tester.pumpAndSettle();

      expect(find.text('Assign drivers'), findsOneWidget);
      expect(find.text('Current assignment'), findsOneWidget);
      expect(find.text('Unassigned drivers'), findsWidgets);

      await tester.tap(find.byKey(const Key('assignDriverOption_driver-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveDriverAssignmentButton')));
      await tester.pumpAndSettle();

      expect(service.assignedBusId, 'bus-1');
      expect(service.assignedDriverIds, ['driver-1']);
      expect(find.text('Driver assignments updated.'), findsOneWidget);
    });

    testWidgets('admin can assign multiple drivers to a route', (tester) async {
      final service = _FakeBusAdminService(
        drivers: [_sampleDriver(), _sampleSecondDriver()],
        buses: [_sampleBus().copyWith(driverIds: const <String>[])],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(busAdminService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Assign drivers'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assignDriverOption_driver-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('assignDriverOption_driver-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveDriverAssignmentButton')));
      await tester.pumpAndSettle();

      expect(service.assignedBusId, 'bus-1');
      expect(service.assignedDriverIds, ['driver-1', 'driver-2']);
    });

    testWidgets('admin can unassign a driver from a route', (tester) async {
      final service = _FakeBusAdminService(
        drivers: [_sampleDriver()],
        buses: [_sampleBus()],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(busAdminService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Assign drivers'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clearDriverAssignmentsOption')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveDriverAssignmentButton')));
      await tester.pumpAndSettle();

      expect(service.assignedBusId, 'bus-1');
      expect(service.assignedDriverIds, isEmpty);
    });

    testWidgets('admin assign driver flow handles empty driver list', (
      tester,
    ) async {
      final service = _FakeBusAdminService(buses: [_sampleBus()]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(busAdminService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Assign drivers'));
      await tester.pumpAndSettle();

      expect(find.text('No drivers available'), findsOneWidget);
      expect(
        find.byKey(const Key('assignDriverOption_driver-1')),
        findsNothing,
      );
    });

    testWidgets('admin delete removes bus and live location state', (
      tester,
    ) async {
      final service = _FakeBusAdminService(
        drivers: [_sampleDriver()],
        buses: [_sampleBus()],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminBusManagementScreen(busAdminService: service),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete bus route'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDeleteBusButton')));
      await tester.pumpAndSettle();

      expect(service.deletedBusId, 'bus-1');
      expect(service.deletedLocationBusId, 'bus-1');
      expect(find.text('Bus route deleted.'), findsOneWidget);
    });
  });
}

PolylineLayer<Object> _busRoutePolylineLayer(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is PolylineLayer<Object>,
  );
  expect(finder, findsOneWidget);
  return tester.widget<PolylineLayer<Object>>(finder);
}

MarkerLayer _busMarkerLayer(WidgetTester tester) {
  final finder = find.byWidgetPredicate((widget) => widget is MarkerLayer);
  expect(finder, findsOneWidget);
  return tester.widget<MarkerLayer>(finder);
}

Future<void> _tapAdminRouteMap(WidgetTester tester) async {
  final mapFinder = find.byKey(const Key('adminBusRouteMap'));
  await tester.ensureVisible(mapFinder);
  await tester.pumpAndSettle();
  final topLeft = tester.getTopLeft(mapFinder);
  await tester.tapAt(topLeft + const Offset(120, 120));
}

CampusBus _sampleBus() {
  return const CampusBus(
    busId: 'bus-1',
    routeName: 'Kolej Loop',
    driverIds: ['driver-1'],
    status: 'active',
    startName: 'Library',
    endName: 'Kolej Rahman Putra',
    routePoints: [
      BusRoutePoint(latitude: 1.5583, longitude: 103.6371),
      BusRoutePoint(latitude: 1.5601, longitude: 103.6402),
    ],
  );
}

CampusBus _sampleSecondBus() {
  return const CampusBus(
    busId: 'bus-2',
    routeName: 'Engineering Shuttle',
    driverIds: ['driver-2'],
    status: 'active',
    startName: 'Engineering',
    endName: 'Library',
    routePoints: [
      BusRoutePoint(latitude: 1.5612, longitude: 103.6411),
      BusRoutePoint(latitude: 1.5634, longitude: 103.6428),
    ],
  );
}

BusLocation _sampleLocation() {
  return BusLocation(
    busId: 'bus-1',
    driverId: 'driver-1',
    latitude: 1.5583,
    longitude: 103.6371,
    speed: 5,
    heading: 90,
    isBroadcasting: true,
    updatedAt: DateTime(2026, 5, 24, 14, 30),
  );
}

BusLocation _sampleSecondLocation() {
  return BusLocation(
    busId: 'bus-2',
    driverId: 'driver-2',
    latitude: 1.5612,
    longitude: 103.6411,
    speed: 4,
    heading: 120,
    isBroadcasting: true,
    updatedAt: DateTime(2026, 5, 24, 14, 31),
  );
}

AppUser _sampleDriver() {
  return const AppUser(
    uid: 'driver-1',
    name: 'Aina Driver',
    email: 'driver@example.com',
    role: UserRole.driver,
    emailVerified: true,
  );
}

AppUser _sampleSecondDriver() {
  return const AppUser(
    uid: 'driver-2',
    name: 'Bala Driver',
    email: 'driver2@example.com',
    role: UserRole.driver,
    emailVerified: true,
  );
}

class _FakeBusTrackingService implements BusTrackingService {
  _FakeBusTrackingService({
    this.buses = const <CampusBus>[],
    this.locations = const <BusLocation>[],
  });

  final List<CampusBus> buses;
  final List<BusLocation> locations;
  String? publishedBusId;
  String? stoppedBusId;
  int publishCount = 0;

  @override
  Future<void> publishLocation({
    required CampusBus bus,
    required BusPosition position,
  }) async {
    publishedBusId = bus.busId;
    publishCount += 1;
  }

  @override
  Future<void> stopBroadcast(CampusBus bus) async {
    stoppedBusId = bus.busId;
  }

  @override
  Stream<List<CampusBus>> watchAssignedBuses() {
    return Stream.value(buses);
  }

  @override
  Stream<BusLocation?> watchBusLocation(String busId) {
    for (final location in locations) {
      if (location.busId == busId) {
        return Stream.value(location);
      }
    }

    return Stream.value(null);
  }

  @override
  Stream<List<BusLocation>> watchLiveLocations() {
    return Stream.value(locations);
  }

  @override
  Stream<List<CampusBus>> watchVisibleBuses() {
    return Stream.value(buses);
  }
}

class _FakeBusLocationProvider implements BusLocationProvider {
  const _FakeBusLocationProvider();

  @override
  Future<BusPosition> getCurrentPosition() async {
    return const BusPosition(
      latitude: 1.5583,
      longitude: 103.6371,
      speed: 5,
      heading: 90,
    );
  }
}

class _FakeBusAdminService implements BusAdminService {
  _FakeBusAdminService({
    this.drivers = const <AppUser>[],
    this.buses = const <CampusBus>[],
  });

  final List<AppUser> drivers;
  final List<CampusBus> buses;
  CampusBus? createdBus;
  CampusBus? updatedBus;
  String? assignedBusId;
  List<String>? assignedDriverIds;
  String? deletedBusId;
  String? deletedLocationBusId;

  @override
  Future<void> assignDrivers({
    required CampusBus bus,
    required List<String> driverIds,
  }) async {
    assignedBusId = bus.busId;
    assignedDriverIds = driverIds;
  }

  @override
  Future<CampusBus> createBus(CampusBus bus) async {
    createdBus = bus.copyWith(busId: 'created-bus');
    return createdBus!;
  }

  @override
  Future<void> deleteBus(CampusBus bus) async {
    deletedBusId = bus.busId;
    deletedLocationBusId = bus.busId;
  }

  @override
  Future<void> updateBus({
    required CampusBus currentBus,
    required CampusBus updatedBus,
  }) async {
    this.updatedBus = updatedBus;
  }

  @override
  Stream<List<CampusBus>> watchBuses() {
    return Stream.value(buses);
  }

  @override
  Stream<List<AppUser>> watchDrivers() {
    return Stream.value(drivers);
  }
}
