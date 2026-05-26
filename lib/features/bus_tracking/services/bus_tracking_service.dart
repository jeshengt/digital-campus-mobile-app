import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../models/bus_location.dart';
import '../models/campus_bus.dart';
import '../utils/bus_admin_validation.dart';

class BusPosition {
  const BusPosition({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
  });

  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
}

abstract class BusLocationProvider {
  Future<BusPosition> getCurrentPosition();
}

class GeolocatorBusLocationProvider implements BusLocationProvider {
  const GeolocatorBusLocationProvider();

  @override
  Future<BusPosition> getCurrentPosition() async {
    final isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      throw const AppException('Location services are turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const AppException('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const AppException(
        'Location permission is permanently denied. Enable it in settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    return BusPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed.isFinite && position.speed > 0 ? position.speed : 0,
      heading: position.heading.isFinite && position.heading >= 0
          ? position.heading
          : 0,
    );
  }
}

abstract class BusTrackingService {
  Stream<List<CampusBus>> watchVisibleBuses();

  Stream<List<CampusBus>> watchAssignedBuses();

  Stream<List<BusLocation>> watchLiveLocations();

  Stream<BusLocation?> watchBusLocation(String busId);

  Future<void> publishLocation({
    required CampusBus bus,
    required BusPosition position,
  });

  Future<void> stopBroadcast(CampusBus bus);
}

class FirebaseBusTrackingService implements BusTrackingService {
  FirebaseBusTrackingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _buses =>
      _firestore.collection(FirebaseCollections.buses);

  CollectionReference<Map<String, dynamic>> get _locations =>
      _firestore.collection(FirebaseCollections.busLocations);

  @override
  Stream<List<CampusBus>> watchVisibleBuses() {
    _requireCurrentUser();

    return _buses.snapshots().map((snapshot) {
      final buses = snapshot.docs
          .map((doc) => CampusBus.fromMap(doc.data(), documentId: doc.id))
          .toList();
      buses.sort((a, b) => a.routeName.compareTo(b.routeName));
      return buses;
    });
  }

  @override
  Stream<List<CampusBus>> watchAssignedBuses() {
    final driver = _requireCurrentUser();

    return _buses.snapshots().map((snapshot) {
      final buses = snapshot.docs
          .map((doc) => CampusBus.fromMap(doc.data(), documentId: doc.id))
          .where((bus) => bus.isAssignedTo(driver.uid))
          .toList();
      buses.sort((a, b) => a.routeName.compareTo(b.routeName));
      return buses;
    });
  }

  @override
  Stream<List<BusLocation>> watchLiveLocations() {
    _requireCurrentUser();

    return _locations.where('isBroadcasting', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final locations = snapshot.docs
          .map((doc) => BusLocation.fromMap(doc.data(), documentId: doc.id))
          .where((location) => location.isBroadcasting)
          .toList();
      locations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return locations;
    });
  }

  @override
  Stream<BusLocation?> watchBusLocation(String busId) {
    _requireCurrentUser();

    return _locations.doc(busId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return BusLocation.fromMap(data, documentId: snapshot.id);
    });
  }

  @override
  Future<void> publishLocation({
    required CampusBus bus,
    required BusPosition position,
  }) async {
    final driver = _requireCurrentUser();
    if (!bus.isAssignedTo(driver.uid)) {
      throw const AppException('This bus is not assigned to your account.');
    }
    if (bus.status != busStatusActive) {
      throw const AppException('This bus route is inactive.');
    }

    final location = BusLocation(
      busId: bus.busId,
      driverId: driver.uid,
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      heading: position.heading,
      isBroadcasting: true,
      updatedAt: DateTime.now(),
    );

    await _locations.doc(bus.busId).set(location.toMap());
  }

  @override
  Future<void> stopBroadcast(CampusBus bus) async {
    final driver = _requireCurrentUser();
    if (!bus.isAssignedTo(driver.uid)) {
      throw const AppException('This bus is not assigned to your account.');
    }

    await _locations.doc(bus.busId).update({
      'isBroadcasting': false,
      'updatedAt': DateTime.now(),
    });
  }

  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AppException('You must be signed in to use bus tracking.');
    }

    return user;
  }
}
