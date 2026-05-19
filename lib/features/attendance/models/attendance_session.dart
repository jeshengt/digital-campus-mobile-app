import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  const AttendanceSession({
    required this.sessionId,
    required this.lecturerId,
    required this.courseCode,
    required this.requiresLocation,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadius,
    required this.qrCodeValue,
    required this.startTime,
    required this.expiryTime,
    required this.status,
    required this.createdAt,
  });

  final String sessionId;
  final String lecturerId;
  final String courseCode;
  final bool requiresLocation;
  final double? latitude;
  final double? longitude;
  final double? geofenceRadius;
  final String qrCodeValue;
  final DateTime startTime;
  final DateTime? expiryTime;
  final String status;
  final DateTime createdAt;

  bool get isActive {
    return status == 'active' &&
        (expiryTime == null || expiryTime!.isAfter(DateTime.now()));
  }

  factory AttendanceSession.fromMap(Map<String, dynamic> data) {
    final latitude = _readNullableDouble(data['latitude']);
    final longitude = _readNullableDouble(data['longitude']);
    final radius = _readNullableDouble(data['geofenceRadius']);

    return AttendanceSession(
      sessionId: data['sessionId'] as String? ?? '',
      lecturerId: data['lecturerId'] as String? ?? '',
      courseCode: data['courseCode'] as String? ?? '',
      requiresLocation:
          data['requiresLocation'] as bool? ??
          (latitude != null && longitude != null && radius != null),
      latitude: latitude,
      longitude: longitude,
      geofenceRadius: radius,
      qrCodeValue: data['qrCodeValue'] as String? ?? '',
      startTime:
          _readDate(data['startTime']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiryTime: _readDate(data['expiryTime']),
      status: data['status'] as String? ?? 'inactive',
      createdAt:
          _readDate(data['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'lecturerId': lecturerId,
      'courseCode': courseCode,
      'requiresLocation': requiresLocation,
      'latitude': latitude,
      'longitude': longitude,
      'geofenceRadius': geofenceRadius,
      'qrCodeValue': qrCodeValue,
      'startTime': startTime,
      'expiryTime': expiryTime,
      'status': status,
      'createdAt': createdAt,
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
