import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../attendance/models/attendance_record.dart';
import '../../attendance/models/attendance_session.dart';
import '../../booking/models/facility.dart';
import '../../booking/models/facility_booking.dart';
import '../../bus_tracking/models/bus_location.dart';
import '../../bus_tracking/models/campus_bus.dart';
import '../../profile/models/app_user.dart';
import '../models/system_analytics_snapshot.dart';

abstract class SystemAnalyticsService {
  Stream<SystemAnalyticsSnapshot> watchSystemAnalytics();
}

class FirebaseSystemAnalyticsService implements SystemAnalyticsService {
  FirebaseSystemAnalyticsService({
    FirebaseFirestore? firestore,
    DateTime Function()? now,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseCollections.users);

  CollectionReference<Map<String, dynamic>> get _attendanceSessions =>
      _firestore.collection(FirebaseCollections.attendanceSessions);

  CollectionReference<Map<String, dynamic>> get _attendanceRecords =>
      _firestore.collection(FirebaseCollections.attendanceRecords);

  CollectionReference<Map<String, dynamic>> get _facilities =>
      _firestore.collection(FirebaseCollections.facilities);

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirebaseCollections.bookings);

  CollectionReference<Map<String, dynamic>> get _buses =>
      _firestore.collection(FirebaseCollections.buses);

  CollectionReference<Map<String, dynamic>> get _busLocations =>
      _firestore.collection(FirebaseCollections.busLocations);

  @override
  Stream<SystemAnalyticsSnapshot> watchSystemAnalytics() {
    late final StreamController<SystemAnalyticsSnapshot> controller;
    final subscriptions = <StreamSubscription<dynamic>>[];

    List<AppUser>? users;
    List<AttendanceSession>? attendanceSessions;
    List<AttendanceRecord>? attendanceRecords;
    List<Facility>? facilities;
    List<FacilityBooking>? bookings;
    List<CampusBus>? buses;
    List<BusLocation>? busLocations;

    void emitIfReady() {
      if (controller.isClosed ||
          users == null ||
          attendanceSessions == null ||
          attendanceRecords == null ||
          facilities == null ||
          bookings == null ||
          buses == null ||
          busLocations == null) {
        return;
      }

      controller.add(
        buildSystemAnalyticsSnapshot(
          users: users!,
          attendanceSessions: attendanceSessions!,
          attendanceRecords: attendanceRecords!,
          facilities: facilities!,
          bookings: bookings!,
          buses: buses!,
          busLocations: busLocations!,
          now: _now(),
        ),
      );
    }

    void listenTo<T>(Stream<List<T>> stream, void Function(List<T>) save) {
      subscriptions.add(
        stream.listen((items) {
          save(items);
          emitIfReady();
        }, onError: controller.addError),
      );
    }

    controller = StreamController<SystemAnalyticsSnapshot>(
      onListen: () {
        listenTo(_watchUsers(), (items) => users = items);
        listenTo(
          _watchAttendanceSessions(),
          (items) => attendanceSessions = items,
        );
        listenTo(
          _watchAttendanceRecords(),
          (items) => attendanceRecords = items,
        );
        listenTo(_watchFacilities(), (items) => facilities = items);
        listenTo(_watchBookings(), (items) => bookings = items);
        listenTo(_watchBuses(), (items) => buses = items);
        listenTo(_watchBusLocations(), (items) => busLocations = items);
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }

  Stream<List<AppUser>> _watchUsers() {
    return _users.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
    });
  }

  Stream<List<AttendanceSession>> _watchAttendanceSessions() {
    return _attendanceSessions.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceSession.fromMap(doc.data()))
          .toList();
    });
  }

  Stream<List<AttendanceRecord>> _watchAttendanceRecords() {
    return _attendanceRecords.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data()))
          .toList();
    });
  }

  Stream<List<Facility>> _watchFacilities() {
    return _facilities.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Facility.fromMap(doc.data(), documentId: doc.id))
          .toList();
    });
  }

  Stream<List<FacilityBooking>> _watchBookings() {
    return _bookings.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FacilityBooking.fromMap(doc.data(), documentId: doc.id))
          .toList();
    });
  }

  Stream<List<CampusBus>> _watchBuses() {
    return _buses.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CampusBus.fromMap(doc.data(), documentId: doc.id))
          .toList();
    });
  }

  Stream<List<BusLocation>> _watchBusLocations() {
    return _busLocations.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BusLocation.fromMap(doc.data(), documentId: doc.id))
          .toList();
    });
  }
}
