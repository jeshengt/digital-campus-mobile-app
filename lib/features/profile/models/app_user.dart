import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/user_role.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.matricNumber,
    this.staffId,
    this.emailVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? matricNumber;
  final String? staffId;
  final bool emailVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRole.fromValue(data['role'] as String?),
      matricNumber: data['matricNumber'] as String?,
      staffId: data['staffId'] as String?,
      emailVerified: data['emailVerified'] as bool? ?? false,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.value,
      'matricNumber': matricNumber,
      'staffId': staffId,
      'emailVerified': emailVerified,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  AppUser copyWith({
    String? name,
    String? matricNumber,
    String? staffId,
    bool? emailVerified,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email,
      role: role,
      matricNumber: matricNumber ?? this.matricNumber,
      staffId: staffId ?? this.staffId,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
