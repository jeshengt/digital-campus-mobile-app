import 'bus_route_point.dart';

class CampusBus {
  const CampusBus({
    required this.busId,
    required this.routeName,
    this.driverIds = const <String>[],
    required this.status,
    this.startName,
    this.endName,
    this.routePoints = const <BusRoutePoint>[],
  });

  final String busId;
  final String routeName;
  final List<String> driverIds;
  final String status;
  final String? startName;
  final String? endName;
  final List<BusRoutePoint> routePoints;

  bool get hasRouteGeometry => routePoints.length >= 2;

  BusRoutePoint? get destinationPoint {
    if (routePoints.isEmpty) {
      return null;
    }

    return routePoints.last;
  }

  String get driverId => driverIds.isEmpty ? '' : driverIds.first;

  bool isAssignedTo(String driverId) {
    return driverIds.contains(driverId);
  }

  CampusBus copyWith({
    String? busId,
    String? routeName,
    List<String>? driverIds,
    String? status,
    String? startName,
    String? endName,
    List<BusRoutePoint>? routePoints,
  }) {
    return CampusBus(
      busId: busId ?? this.busId,
      routeName: routeName ?? this.routeName,
      driverIds: driverIds ?? this.driverIds,
      status: status ?? this.status,
      startName: startName ?? this.startName,
      endName: endName ?? this.endName,
      routePoints: routePoints ?? this.routePoints,
    );
  }

  factory CampusBus.fromMap(Map<String, dynamic> data, {String? documentId}) {
    final rawRoutePoints = data['routePoints'];
    final routePoints = rawRoutePoints is List
        ? rawRoutePoints
              .whereType<Map>()
              .map(
                (point) =>
                    BusRoutePoint.fromMap(Map<String, dynamic>.from(point)),
              )
              .toList()
        : const <BusRoutePoint>[];
    final rawDriverIds = data['driverIds'];
    final driverIds = rawDriverIds is List
        ? rawDriverIds
              .whereType<String>()
              .map((id) => id.trim())
              .where((id) => id.isNotEmpty)
              .toList()
        : _legacyDriverIds(data['driverId']);

    return CampusBus(
      busId: data['busId'] as String? ?? documentId ?? '',
      routeName: data['routeName'] as String? ?? 'Campus route',
      driverIds: driverIds,
      status: data['status'] as String? ?? 'inactive',
      startName: data['startName'] as String?,
      endName: data['endName'] as String?,
      routePoints: routePoints,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'busId': busId,
      'routeName': routeName,
      'driverIds': driverIds,
      'status': status,
      'startName': startName,
      'endName': endName,
      'routePoints': routePoints.map((point) => point.toMap()).toList(),
    };
  }

  static List<String> _legacyDriverIds(Object? value) {
    if (value is! String) {
      return const <String>[];
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
  }
}
