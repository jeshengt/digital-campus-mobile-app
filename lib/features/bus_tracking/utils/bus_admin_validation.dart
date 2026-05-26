import '../models/bus_route_point.dart';

const busStatusActive = 'active';
const busStatusInactive = 'inactive';
const allowedBusStatuses = [busStatusActive, busStatusInactive];

String? validateCampusBusDraft({
  required String routeName,
  required List<BusRoutePoint> routePoints,
}) {
  if (routeName.trim().isEmpty) {
    return 'Route name is required';
  }

  if (routePoints.length < 2) {
    return 'Add at least 2 route points';
  }

  return null;
}
