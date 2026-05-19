import 'package:geolocator/geolocator.dart';

import '../../core/errors/app_exception.dart';
import '../../features/attendance/utils/attendance_helpers.dart';

class CampusPosition {
  const CampusPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

abstract class AttendanceLocationProvider {
  Future<CampusPosition> getCurrentPosition();

  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  });
}

class GeolocatorAttendanceLocationProvider
    implements AttendanceLocationProvider {
  const GeolocatorAttendanceLocationProvider();

  @override
  Future<CampusPosition> getCurrentPosition() async {
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

    return CampusPosition(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return distanceBetweenMeters(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      endLatitude: endLatitude,
      endLongitude: endLongitude,
    );
  }
}
