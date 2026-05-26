import 'package:cloud_firestore/cloud_firestore.dart';

class BusLocation {
  const BusLocation({
    required this.busId,
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.isBroadcasting,
    required this.updatedAt,
  });

  final String busId;
  final String driverId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final bool isBroadcasting;
  final DateTime updatedAt;

  factory BusLocation.fromMap(Map<String, dynamic> data, {String? documentId}) {
    return BusLocation(
      busId: data['busId'] as String? ?? documentId ?? '',
      driverId: data['driverId'] as String? ?? '',
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      speed: _readDouble(data['speed']),
      heading: _readDouble(data['heading']),
      isBroadcasting: data['isBroadcasting'] as bool? ?? false,
      updatedAt:
          _readDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'isBroadcasting': isBroadcasting,
      'updatedAt': updatedAt,
    };
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0;
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
