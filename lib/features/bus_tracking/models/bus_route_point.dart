class BusRoutePoint {
  const BusRoutePoint({
    required this.latitude,
    required this.longitude,
    this.name,
  });

  final double latitude;
  final double longitude;
  final String? name;

  factory BusRoutePoint.fromMap(Map<String, dynamic> data) {
    return BusRoutePoint(
      latitude: _readDouble(data['latitude']) ?? _readDouble(data['lat']) ?? 0,
      longitude:
          _readDouble(data['longitude']) ?? _readDouble(data['lng']) ?? 0,
      name: data['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (name != null && name!.trim().isNotEmpty) 'name': name,
    };
  }

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }
}
