import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.recordId,
    required this.sessionId,
    required this.courseCode,
    required this.studentId,
    required this.studentName,
    required this.scannedAt,
    required this.locationValidated,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.status,
    required this.remarks,
  });

  final String recordId;
  final String sessionId;
  final String courseCode;
  final String studentId;
  final String studentName;
  final DateTime scannedAt;
  final bool locationValidated;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final String status;
  final String remarks;

  factory AttendanceRecord.fromMap(Map<String, dynamic> data) {
    final distanceMeters = _readNullableDouble(data['distanceMeters']);

    return AttendanceRecord(
      recordId: data['recordId'] as String? ?? '',
      sessionId: data['sessionId'] as String? ?? '',
      courseCode: data['courseCode'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      scannedAt:
          _readDate(data['scannedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      locationValidated:
          data['locationValidated'] as bool? ?? distanceMeters != null,
      latitude: _readNullableDouble(data['latitude']),
      longitude: _readNullableDouble(data['longitude']),
      distanceMeters: distanceMeters,
      status: data['status'] as String? ?? 'pending',
      remarks: data['remarks'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'sessionId': sessionId,
      'courseCode': courseCode,
      'studentId': studentId,
      'studentName': studentName,
      'scannedAt': scannedAt,
      'locationValidated': locationValidated,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'status': status,
      'remarks': remarks,
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

  static double? _readNullableDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }
}
