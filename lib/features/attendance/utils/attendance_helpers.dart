import 'dart:math';

const attendanceStatusActive = 'active';
const attendanceStatusClosed = 'closed';
const attendanceRecordStatusPresent = 'present';
const attendanceDefaultRadiusMeters = 100.0;
const attendanceDefaultDurationMinutes = 15;

String generateAttendanceQrToken({
  required String sessionId,
  DateTime? now,
  Random? random,
}) {
  final effectiveNow = now ?? DateTime.now();
  final effectiveRandom = random ?? Random.secure();
  final randomPart = List.generate(
    4,
    (_) => effectiveRandom.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0'),
  ).join();

  return 'utmgo-att:$sessionId:${effectiveNow.microsecondsSinceEpoch}:$randomPart';
}

String normalizeQrCodeValue(String value) {
  return value.trim();
}

String? sessionIdFromAttendanceQr(String value) {
  final normalizedQr = normalizeQrCodeValue(value);
  final parts = normalizedQr.split(':');
  if (parts.length != 4 || parts.first != 'utmgo-att') {
    return null;
  }

  final sessionId = parts[1].trim();
  if (sessionId.isEmpty || sessionId.contains('/')) {
    return null;
  }

  return sessionId;
}

String? validateRequiredText(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label is required';
  }

  return null;
}

String? validatePositiveDouble(String? value, String label) {
  final requiredError = validateRequiredText(value, label);
  if (requiredError != null) {
    return requiredError;
  }

  final parsed = double.tryParse(value!.trim());
  if (parsed == null || parsed <= 0) {
    return 'Enter a valid $label';
  }

  return null;
}

String? validateLatitude(String? value) {
  final requiredError = validateRequiredText(value, 'Latitude');
  if (requiredError != null) {
    return requiredError;
  }

  final parsed = double.tryParse(value!.trim());
  if (parsed == null || parsed < -90 || parsed > 90) {
    return 'Enter a latitude from -90 to 90';
  }

  return null;
}

String? validateLongitude(String? value) {
  final requiredError = validateRequiredText(value, 'Longitude');
  if (requiredError != null) {
    return requiredError;
  }

  final parsed = double.tryParse(value!.trim());
  if (parsed == null || parsed < -180 || parsed > 180) {
    return 'Enter a longitude from -180 to 180';
  }

  return null;
}

bool isSessionActive({
  required String status,
  required DateTime? expiryTime,
  DateTime? now,
}) {
  return status == attendanceStatusActive &&
      (expiryTime == null || expiryTime.isAfter(now ?? DateTime.now()));
}

bool isInsideGeofence({
  required double distanceMeters,
  required double radiusMeters,
}) {
  return distanceMeters <= radiusMeters;
}

String attendanceRecordId({
  required String sessionId,
  required String studentId,
}) {
  return '${sessionId}_$studentId';
}

double distanceBetweenMeters({
  required double startLatitude,
  required double startLongitude,
  required double endLatitude,
  required double endLongitude,
}) {
  const earthRadiusMeters = 6371000.0;
  final startLatRadians = _toRadians(startLatitude);
  final endLatRadians = _toRadians(endLatitude);
  final deltaLat = _toRadians(endLatitude - startLatitude);
  final deltaLon = _toRadians(endLongitude - startLongitude);

  final a =
      sin(deltaLat / 2) * sin(deltaLat / 2) +
      cos(startLatRadians) *
          cos(endLatRadians) *
          sin(deltaLon / 2) *
          sin(deltaLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusMeters * c;
}

double _toRadians(double degrees) {
  return degrees * pi / 180;
}
