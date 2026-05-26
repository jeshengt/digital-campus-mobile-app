import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../../../models/user_role.dart';
import '../../profile/models/app_user.dart';
import '../models/campus_bus.dart';

abstract class BusAdminService {
  Stream<List<CampusBus>> watchBuses();

  Stream<List<AppUser>> watchDrivers();

  Future<CampusBus> createBus(CampusBus bus);

  Future<void> updateBus({
    required CampusBus currentBus,
    required CampusBus updatedBus,
  });

  Future<void> assignDrivers({
    required CampusBus bus,
    required List<String> driverIds,
  });

  Future<void> deleteBus(CampusBus bus);
}

class FirebaseBusAdminService implements BusAdminService {
  FirebaseBusAdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _buses =>
      _firestore.collection(FirebaseCollections.buses);

  CollectionReference<Map<String, dynamic>> get _locations =>
      _firestore.collection(FirebaseCollections.busLocations);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseCollections.users);

  @override
  Stream<List<CampusBus>> watchBuses() {
    return _buses.snapshots().map((snapshot) {
      final buses = snapshot.docs
          .map((doc) => CampusBus.fromMap(doc.data(), documentId: doc.id))
          .toList();
      buses.sort((a, b) => a.routeName.compareTo(b.routeName));
      return buses;
    });
  }

  @override
  Stream<List<AppUser>> watchDrivers() {
    return _users
        .where('role', isEqualTo: UserRole.driver.value)
        .snapshots()
        .map((snapshot) {
          final drivers = snapshot.docs
              .map((doc) => AppUser.fromMap(doc.data()))
              .toList();
          drivers.sort((a, b) => a.name.compareTo(b.name));
          return drivers;
        });
  }

  @override
  Future<CampusBus> createBus(CampusBus bus) async {
    final doc = bus.busId.trim().isEmpty ? _buses.doc() : _buses.doc(bus.busId);
    final savedBus = bus.copyWith(busId: doc.id, driverIds: const <String>[]);
    await doc.set(savedBus.toMap());
    return savedBus;
  }

  @override
  Future<void> updateBus({
    required CampusBus currentBus,
    required CampusBus updatedBus,
  }) async {
    final savedBus = updatedBus.copyWith(driverIds: currentBus.driverIds);
    final batch = _firestore.batch();
    batch.set(_buses.doc(savedBus.busId), savedBus.toMap());

    if (currentBus.status != savedBus.status) {
      final locationDoc = _locations.doc(savedBus.busId);
      final locationSnapshot = await locationDoc.get();
      if (locationSnapshot.exists) {
        batch.update(locationDoc, {
          'driverId': savedBus.driverId,
          'isBroadcasting': false,
          'updatedAt': DateTime.now(),
        });
      }
    }

    await batch.commit();
  }

  @override
  Future<void> assignDrivers({
    required CampusBus bus,
    required List<String> driverIds,
  }) async {
    final normalizedDriverIds = _normalizeDriverIds(driverIds);
    if (_sameDriverIds(bus.driverIds, normalizedDriverIds)) {
      return;
    }

    final batch = _firestore.batch();
    batch.update(_buses.doc(bus.busId), {'driverIds': normalizedDriverIds});

    final locationDoc = _locations.doc(bus.busId);
    final locationSnapshot = await locationDoc.get();
    if (locationSnapshot.exists) {
      batch.update(locationDoc, {
        'driverId': normalizedDriverIds.isEmpty
            ? ''
            : normalizedDriverIds.first,
        'isBroadcasting': false,
        'updatedAt': DateTime.now(),
      });
    }

    await batch.commit();
  }

  static List<String> _normalizeDriverIds(List<String> driverIds) {
    final seen = <String>{};
    final normalized = <String>[];

    for (final driverId in driverIds) {
      final trimmed = driverId.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }

      seen.add(trimmed);
      normalized.add(trimmed);
    }

    return normalized;
  }

  static bool _sameDriverIds(List<String> first, List<String> second) {
    if (first.length != second.length) {
      return false;
    }

    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> deleteBus(CampusBus bus) async {
    final batch = _firestore.batch();
    batch.delete(_buses.doc(bus.busId));
    batch.delete(_locations.doc(bus.busId));
    await batch.commit();
  }
}
