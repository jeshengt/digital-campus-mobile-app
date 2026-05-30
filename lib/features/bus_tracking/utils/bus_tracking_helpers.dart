import 'package:latlong2/latlong.dart';

import '../models/bus_location.dart';
import '../models/bus_route_point.dart';

const campusDefaultLatitude = 1.5583;
const campusDefaultLongitude = 103.6371;
const busBroadcastInterval = Duration(seconds: 10);
const fallbackBusSpeedMetersPerSecond = 4.17;

double distanceToPointMeters({
  required BusLocation location,
  required BusRoutePoint point,
}) {
  return const Distance().as(
    LengthUnit.Meter,
    LatLng(location.latitude, location.longitude),
    LatLng(point.latitude, point.longitude),
  );
}

Duration? estimateEta({
  required BusLocation location,
  required BusRoutePoint? destination,
}) {
  if (destination == null) {
    return null;
  }

  final meters = distanceToPointMeters(location: location, point: destination);
  final speed = location.speed >= 1
      ? location.speed
      : fallbackBusSpeedMetersPerSecond;
  final seconds = (meters / speed).round();

  return Duration(seconds: seconds);
}

String formatEta(Duration? eta) {
  if (eta == null) {
    return 'ETA unavailable';
  }

  final minutes = eta.inMinutes;
  if (minutes < 1) {
    return 'Arriving soon';
  }

  if (minutes < 60) {
    return '$minutes min';
  }

  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${remainingMinutes}m';
}

String formatUpdatedAt(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
