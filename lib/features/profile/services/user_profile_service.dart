import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firebase_collections.dart';
import '../models/app_user.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseCollections.users);

  Future<void> createProfile(AppUser user) {
    final now = DateTime.now();
    return _users
        .doc(user.uid)
        .set(
          user.copyWith(updatedAt: now).toMap()
            ..['createdAt'] = user.createdAt ?? now,
        );
  }

  Future<AppUser?> getProfile(String uid) async {
    final snapshot = await _users.doc(uid).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return AppUser.fromMap(snapshot.data()!);
  }

  Stream<AppUser?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return AppUser.fromMap(data);
    });
  }

  Future<void> updateAllowedProfileFields({
    required String uid,
    String? name,
    String? matricNumber,
    String? staffId,
  }) {
    final updates = <String, dynamic>{'updatedAt': DateTime.now()};

    if (name != null) {
      updates['name'] = name;
    }
    if (matricNumber != null) {
      updates['matricNumber'] = matricNumber;
    }
    if (staffId != null) {
      updates['staffId'] = staffId;
    }

    return _users.doc(uid).update(updates);
  }

  Future<void> syncEmailVerified({
    required String uid,
    required bool emailVerified,
  }) {
    return _users.doc(uid).update({
      'emailVerified': emailVerified,
      'updatedAt': DateTime.now(),
    });
  }
}
