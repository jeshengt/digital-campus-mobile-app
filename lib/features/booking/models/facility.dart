import 'package:cloud_firestore/cloud_firestore.dart';

class Facility {
  const Facility({
    required this.facilityId,
    required this.name,
    required this.type,
    required this.location,
    required this.capacity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String facilityId;
  final String name;
  final String type;
  final String location;
  final int capacity;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Facility copyWith({
    String? facilityId,
    String? name,
    String? type,
    String? location,
    int? capacity,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Facility(
      facilityId: facilityId ?? this.facilityId,
      name: name ?? this.name,
      type: type ?? this.type,
      location: location ?? this.location,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Facility.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return Facility(
      facilityId: data['facilityId'] as String? ?? documentId ?? '',
      name: data['name'] as String? ?? '',
      type: data['type'] as String? ?? '',
      location: data['location'] as String? ?? '',
      capacity: (data['capacity'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'unavailable',
      createdAt:
          _readDate(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'facilityId': facilityId,
      'name': name,
      'type': type,
      'location': location,
      'capacity': capacity,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
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
